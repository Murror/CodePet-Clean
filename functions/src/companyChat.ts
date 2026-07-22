import { Request } from "firebase-functions/v2/https";
import { Response } from "express";
import Anthropic from "@anthropic-ai/sdk";
import * as logger from "firebase-functions/logger";
import { verifyAuth } from "./auth";
import { checkAndIncrement } from "./rateLimit";
import { buildSystemPrompt, buildMessages, ChatTurn } from "./companyChatCore";

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

  const system = buildSystemPrompt({
    companionId: typeof body.companion_id === "string" ? body.companion_id : "byte",
    context: typeof body.context === "string" ? body.context : "",
    language: body.language === "vi" ? "vi" : "en",
  });
  const messages = buildMessages(Array.isArray(body.history) ? body.history : [], userMessage);

  try {
    const response = await client().messages.create({
      model: CHAT_MODEL,
      max_tokens: 1024,
      // Prompt-cache the static system block (the pricing spec's cheap-chat lever).
      system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }] as any,
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
}
