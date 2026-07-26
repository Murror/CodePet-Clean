import { Request } from "firebase-functions/v2/https";
import { Response } from "express";
import Anthropic from "@anthropic-ai/sdk";
import * as logger from "firebase-functions/logger";
import { verifyAuth } from "./auth";
import { checkAndIncrement } from "./rateLimit";
import { buildSystemPrompt, buildContextBlock, buildMessages, ChatTurn, ClaudeMessage } from "./companyChatCore";

const CHAT_MODEL = "claude-sonnet-5";

let _client: Anthropic | null = null;
function client(): Anthropic {
  if (!_client) {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");
    _client = new Anthropic({ apiKey });
  }
  return _client;
}

interface ChatRequestBody {
  language?: string;
  companion_id?: string;
  context?: string;
  history?: ChatTurn[];
  user_message?: string;
}

// ─── SSE streaming (opt-in via `Accept: text/event-stream`) ────────────────
// Mirrors chat.ts's handleChatSession stream contract exactly: same StreamEvent
// shape, same `delta`/`done`/`error` SSE frame format (event name + `data:` JSON
// shape), and the same injectable stream-factory test seam — so the native
// client's existing SSEParser (built for chatSession) can parse companyChat's
// stream unchanged. See src/chat.ts for the twin implementation.

type StreamEvent =
  | { type: "text"; text: string }
  | { type: "done"; usage?: { cache_read_input_tokens?: number; input_tokens?: number; output_tokens?: number } };

type StreamFactory = (args: {
  client: Anthropic;
  systemBlocks: Array<{ type: "text"; text: string; cache_control?: { type: "ephemeral" } }>;
  messages: ClaudeMessage[];
}) => AsyncIterable<StreamEvent>;

let _streamFactory: StreamFactory | null = null;

export function __setStreamFactoryForTests(factory: () => AsyncIterable<StreamEvent>) {
  _streamFactory = () => factory();
}

export function __resetStreamFactoryForTests() {
  _streamFactory = null;
}

async function* defaultStreamFactory(args: {
  client: Anthropic;
  systemBlocks: Array<{ type: "text"; text: string; cache_control?: { type: "ephemeral" } }>;
  messages: ClaudeMessage[];
}): AsyncIterable<StreamEvent> {
  const stream = args.client.messages.stream({
    model: CHAT_MODEL,
    max_tokens: 1024,
    system: args.systemBlocks as any,
    messages: args.messages.map((m) => ({ role: m.role, content: m.content }))
  });

  for await (const event of stream) {
    if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
      yield { type: "text", text: event.delta.text };
    }
  }

  const final = await stream.finalMessage();
  yield {
    type: "done",
    usage: {
      cache_read_input_tokens: (final.usage as any)?.cache_read_input_tokens ?? 0,
      input_tokens: final.usage?.input_tokens ?? 0,
      output_tokens: final.usage?.output_tokens ?? 0
    }
  };
}

function writeFrame(res: Response, event: string, payload: unknown): void {
  res.write(`event: ${event}\ndata: ${JSON.stringify(payload)}\n\n`);
}

export async function handleCompanyChat(req: Request, res: Response): Promise<void> {
  if (req.method !== "POST") { res.status(405).json({ error: "method_not_allowed" }); return; }
  const auth = await verifyAuth(req.headers.authorization);
  if (!auth) { res.status(401).json({ error: "invalid_token" }); return; }

  const body = (req.body ?? {}) as ChatRequestBody;
  const userMessage = typeof body.user_message === "string" ? body.user_message.trim() : "";
  if (!userMessage) { res.status(400).json({ error: "invalid_payload", detail: "user_message required" }); return; }

  const limit = await checkAndIncrement(auth.uid);
  if (!limit.allowed) {
    res.status(429).json({ error: "daily_limit_reached", reset_at: limit.resetAt.toISOString(), limit: limit.limit });
    return;
  }

  const staticSystem = buildSystemPrompt({
    companionId: typeof body.companion_id === "string" ? body.companion_id : "byte",
    language: body.language === "vi" ? "vi" : "en",
  });
  const contextBlock = buildContextBlock(typeof body.context === "string" ? body.context : "");
  const messages = buildMessages(Array.isArray(body.history) ? body.history : [], userMessage);

  // Two system blocks in both paths: the static companion prompt carries the
  // cache_control breakpoint (the pricing spec's cheap-chat lever); the volatile
  // per-request company context is a SEPARATE block AFTER it, so it never enters
  // the cached prefix.
  const systemBlocks: Array<{ type: "text"; text: string; cache_control?: { type: "ephemeral" } }> = [
    { type: "text", text: staticSystem, cache_control: { type: "ephemeral" } },
    { type: "text", text: contextBlock },
  ];

  const wantsStream = typeof req.headers.accept === "string" && req.headers.accept.includes("text/event-stream");

  if (!wantsStream) {
    // Existing non-streaming JSON path — byte-for-byte unchanged. Already-deployed
    // native app versions rely on this response shape; do not touch it.
    try {
      const response = await client().messages.create({
        model: CHAT_MODEL,
        max_tokens: 1024,
        system: systemBlocks as any,
        messages: messages as any,
      });
      const reply = response.content
        .filter((b) => b.type === "text")
        .map((b) => (b as { text: string }).text)
        .join("")
        .trim();
      res.status(200).json({ reply, run_task_id: null });
    } catch (err) {
      logger.error("companyChat failed", { uid: auth.uid, err: String(err) });
      res.status(502).json({ error: "generation_failed" });
    }
    return;
  }

  // Streaming path — SSE, opted into via `Accept: text/event-stream`. Frame
  // format matches chat.ts's handleChatSession exactly (delta/done/error).
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.status(200);
  if (typeof (res as any).flushHeaders === "function") {
    (res as any).flushHeaders();
  }

  const factory: StreamFactory = _streamFactory ?? defaultStreamFactory;

  try {
    for await (const event of factory({
      client: _streamFactory ? (null as any) : client(),
      systemBlocks,
      messages
    })) {
      if (event.type === "text") {
        writeFrame(res, "delta", { text: event.text });
      } else if (event.type === "done") {
        const cacheHit = (event.usage?.cache_read_input_tokens ?? 0) > 0;
        writeFrame(res, "done", { model: CHAT_MODEL, cache_hit: cacheHit });
      }
    }
  } catch (err) {
    logger.error("companyChat stream failed", { uid: auth.uid, err: String(err) });
    writeFrame(res, "error", { error: "upstream_failure", detail: String(err) });
  } finally {
    res.end();
  }
}
