import { Request } from "firebase-functions/v2/https";
import { Response } from "express";
import Anthropic from "@anthropic-ai/sdk";
import * as logger from "firebase-functions/logger";
import { verifyAuth } from "./auth";
import { checkAndIncrement } from "./rateLimit";
import {
  buildSystemPrompt,
  buildContextBlock,
  buildMessages,
  buildRunnableBlock,
  validateRunTaskToolUse,
  RUN_TASK_TOOL,
  ChatTurn,
  ClaudeMessage,
  RunnableTaskRef,
} from "./companyChatCore";

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
  // Roadmap tasks byte may offer to run via the run_task tool (see companyChatCore).
  // Backward-compatible: omitted entirely by older clients → treated as [] → no tool
  // offered → behavior is byte-for-byte identical to before this field existed.
  runnable?: RunnableTaskRef[];
}

const MAX_RUNNABLE_TASKS = 60;

function parseRunnable(raw: unknown): RunnableTaskRef[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((r) => {
      const o = (r ?? {}) as Record<string, unknown>;
      const id = typeof o.id === "string" ? o.id.trim() : "";
      const title = typeof o.title === "string" ? o.title.trim() : "";
      return id ? { id, title } : null;
    })
    .filter((r): r is RunnableTaskRef => r !== null)
    .slice(0, MAX_RUNNABLE_TASKS);
}

// ─── SSE streaming (opt-in via `Accept: text/event-stream`) ────────────────
// Mirrors chat.ts's handleChatSession stream contract exactly: same StreamEvent
// shape, same `delta`/`done`/`error` SSE frame format (event name + `data:` JSON
// shape), and the same injectable stream-factory test seam — so the native
// client's existing SSEParser (built for chatSession) can parse companyChat's
// stream unchanged. See src/chat.ts for the twin implementation.

// Beyond text/done, the stream can also surface a run_task tool_use block being
// built up incrementally (Anthropic streams a tool call's input as JSON-delta
// fragments across content_block_start → content_block_delta(input_json_delta) →
// content_block_stop). These three variants let the handler accumulate that JSON
// without the stream factory itself needing to know about run_task validation.
type StreamEvent =
  | { type: "text"; text: string }
  | { type: "tool_use_start"; index: number; name: string }
  | { type: "tool_use_delta"; index: number; partial_json: string }
  | { type: "tool_use_stop"; index: number }
  | { type: "done"; usage?: { cache_read_input_tokens?: number; input_tokens?: number; output_tokens?: number } };

type StreamFactory = (args: {
  client: Anthropic;
  systemBlocks: Array<{ type: "text"; text: string; cache_control?: { type: "ephemeral" } }>;
  messages: ClaudeMessage[];
  tools?: unknown[];
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
  tools?: unknown[];
}): AsyncIterable<StreamEvent> {
  const stream = args.client.messages.stream({
    model: CHAT_MODEL,
    max_tokens: 1024,
    system: args.systemBlocks as any,
    messages: args.messages.map((m) => ({ role: m.role, content: m.content })),
    ...(args.tools && args.tools.length ? { tools: args.tools as any } : {}),
  });

  for await (const event of stream) {
    if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
      yield { type: "text", text: event.delta.text };
    } else if (event.type === "content_block_delta" && event.delta.type === "input_json_delta") {
      yield { type: "tool_use_delta", index: event.index, partial_json: (event.delta as any).partial_json ?? "" };
    } else if (event.type === "content_block_start" && (event.content_block as any).type === "tool_use") {
      yield { type: "tool_use_start", index: event.index, name: (event.content_block as any).name };
    } else if (event.type === "content_block_stop") {
      yield { type: "tool_use_stop", index: event.index };
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

  const runnable = parseRunnable(body.runnable);

  const staticSystem = buildSystemPrompt({
    companionId: typeof body.companion_id === "string" ? body.companion_id : "byte",
    language: body.language === "vi" ? "vi" : "en",
  });
  // Runnable-task grounding is appended to the volatile context block (not the
  // cached static one) since it's per-request, just like the context itself.
  const contextBlock =
    buildContextBlock(typeof body.context === "string" ? body.context : "") + buildRunnableBlock(runnable);
  const messages = buildMessages(Array.isArray(body.history) ? body.history : [], userMessage);

  // Two system blocks in both paths: the static companion prompt carries the
  // cache_control breakpoint (the pricing spec's cheap-chat lever); the volatile
  // per-request company context is a SEPARATE block AFTER it, so it never enters
  // the cached prefix.
  const systemBlocks: Array<{ type: "text"; text: string; cache_control?: { type: "ephemeral" } }> = [
    { type: "text", text: staticSystem, cache_control: { type: "ephemeral" } },
    { type: "text", text: contextBlock },
  ];

  // The run_task tool is only offered when there's something real to run — an
  // empty runnable list means an empty tools array, i.e. old behavior (older
  // clients that never send `runnable` get no tool at all). NOT forced via
  // tool_choice: byte stays free to reply in plain text, or ask a clarifying
  // question, instead of calling it.
  const tools = runnable.length ? [RUN_TASK_TOOL] : undefined;

  const wantsStream = typeof req.headers.accept === "string" && req.headers.accept.includes("text/event-stream");

  if (!wantsStream) {
    // Existing non-streaming JSON path — response shape now additionally supports
    // a real run_task_id (was hardcoded null); already-deployed native app
    // versions that never send `runnable` still get run_task_id: null unchanged.
    try {
      const response = await client().messages.create({
        model: CHAT_MODEL,
        max_tokens: 1024,
        system: systemBlocks as any,
        messages: messages as any,
        ...(tools ? { tools: tools as any } : {}),
      });
      const reply = response.content
        .filter((b) => b.type === "text")
        .map((b) => (b as { text: string }).text)
        .join("")
        .trim();
      const toolUse = response.content.find(
        (b) => b.type === "tool_use" && (b as any).name === "run_task"
      ) as any;
      const runTaskId = toolUse ? validateRunTaskToolUse(toolUse.input, runnable) : null;
      res.status(200).json({ reply, run_task_id: runTaskId });
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

  // Accumulator for a run_task tool_use block, if byte calls one mid-stream.
  // Only the content-block index currently identified as the run_task call is
  // tracked; any other tool_use / text block indices are ignored here.
  let runTaskIndex: number | null = null;
  let runTaskJson = "";
  let runTaskId: string | null = null;

  try {
    for await (const event of factory({
      client: _streamFactory ? (null as any) : client(),
      systemBlocks,
      messages,
      tools
    })) {
      if (event.type === "text") {
        writeFrame(res, "delta", { text: event.text });
      } else if (event.type === "tool_use_start") {
        if (event.name === "run_task") {
          runTaskIndex = event.index;
          runTaskJson = "";
        }
      } else if (event.type === "tool_use_delta") {
        if (runTaskIndex !== null && event.index === runTaskIndex) {
          runTaskJson += event.partial_json;
        }
      } else if (event.type === "tool_use_stop") {
        if (runTaskIndex !== null && event.index === runTaskIndex) {
          try {
            const parsed = runTaskJson ? JSON.parse(runTaskJson) : {};
            runTaskId = validateRunTaskToolUse(parsed, runnable);
          } catch (parseErr) {
            logger.error("companyChat run_task tool_use JSON parse failed", {
              uid: auth.uid,
              err: String(parseErr)
            });
            runTaskId = null;
          }
          runTaskIndex = null;
        }
      } else if (event.type === "done") {
        const cacheHit = (event.usage?.cache_read_input_tokens ?? 0) > 0;
        // run_task_id is additive on the existing done frame — old clients that
        // don't look for the field are unaffected.
        writeFrame(res, "done", { model: CHAT_MODEL, cache_hit: cacheHit, run_task_id: runTaskId });
      }
    }
  } catch (err) {
    logger.error("companyChat stream failed", { uid: auth.uid, err: String(err) });
    writeFrame(res, "error", { error: "upstream_failure", detail: String(err) });
  } finally {
    res.end();
  }
}
