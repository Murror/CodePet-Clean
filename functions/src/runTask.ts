import { Request } from "firebase-functions/v2/https";
import { Response } from "express";
import Anthropic from "@anthropic-ai/sdk";
import * as logger from "firebase-functions/logger";
import { verifyAuth } from "./auth";
import { checkAndIncrement } from "./rateLimit";
import { buildRunTaskPrompt, coerceDeliverable } from "./runTaskCore";

const RUN_MODEL = "claude-opus-4-8";

let _client: Anthropic | null = null;
function client(): Anthropic {
  if (!_client) {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");
    _client = new Anthropic({ apiKey });
  }
  return _client;
}

const RECORD_TOOL = {
  name: "record_deliverable",
  description: "Record the finished deliverable produced for this task.",
  input_schema: {
    type: "object",
    properties: {
      kind: { type: "string", description: "The deliverable kind that best fits what was produced." },
      title: { type: "string", description: "A short, clear title for the deliverable." },
      body: { type: "string", description: "The full deliverable content, written as markdown." },
    },
    required: ["kind", "title", "body"],
  },
} as const;

interface RunTaskRequestBody {
  company_id?: string | null;
  language?: string;
  companion_id?: string;
  context?: string;
  task_id?: string;
  task_title?: string;
  task_detail?: string;
}

export async function handleRunTask(req: Request, res: Response): Promise<void> {
  if (req.method !== "POST") { res.status(405).json({ error: "method_not_allowed" }); return; }
  const auth = await verifyAuth(req.headers.authorization);
  if (!auth) { res.status(401).json({ error: "invalid_token" }); return; }

  const body = (req.body ?? {}) as RunTaskRequestBody;
  const taskTitle = typeof body.task_title === "string" ? body.task_title.trim() : "";
  if (!taskTitle) { res.status(400).json({ error: "invalid_payload", detail: "task_title required" }); return; }

  const limit = await checkAndIncrement(auth.uid);
  if (!limit.allowed) {
    res.status(429).json({ error: "daily_limit_reached", reset_at: limit.resetAt.toISOString(), limit: limit.limit });
    return;
  }

  const prompt = buildRunTaskPrompt({
    companionId: typeof body.companion_id === "string" ? body.companion_id : "byte",
    language: body.language === "vi" ? "vi" : "en",
    context: typeof body.context === "string" ? body.context : "",
    taskTitle,
    taskDetail: typeof body.task_detail === "string" ? body.task_detail : "",
  });

  try {
    const response = await client().messages.create({
      model: RUN_MODEL,
      max_tokens: 3000,
      system: "You produce real, finished work product for a solo founder's company — never a plan to do the work, the work itself.",
      tools: [RECORD_TOOL as any],
      tool_choice: { type: "tool", name: "record_deliverable" },
      messages: [{ role: "user", content: prompt }],
    });
    const block = response.content.find((b) => b.type === "tool_use") as any;
    const deliverable = coerceDeliverable(block?.input, taskTitle);
    if (!deliverable) { res.status(502).json({ error: "generation_failed" }); return; }
    res.status(200).json(deliverable);
  } catch (err) {
    logger.error("runTask failed", { uid: auth.uid, err: String(err) });
    res.status(502).json({ error: "generation_failed" });
  }
}
