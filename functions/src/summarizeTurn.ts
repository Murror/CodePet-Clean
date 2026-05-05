import { Request } from "firebase-functions/v2/https";
import { Response } from "express";
import Anthropic from "@anthropic-ai/sdk";
import * as logger from "firebase-functions/logger";
import { verifyAuth } from "./auth";
import { checkAndIncrement } from "./rateLimit";
import { getCached, putCached } from "./cache";
import { callAnthropic, MODEL, EventForPrompt, NarrativeOutput, PetPersonaInput } from "./anthropic";

export interface SummarizePayload {
  turn_id: string;
  session_id: string;
  language: "vi" | "en";
  prompt: string;
  events: EventForPrompt[];
  raw_summary: string;
  pet_persona?: PetPersonaInput;
}

export function validatePayload(body: any): string | null {
  if (!body || typeof body !== "object") return "body required";
  const b = body as Partial<SummarizePayload>;
  if (typeof b.turn_id !== "string" || b.turn_id.length === 0) return "turn_id required";
  if (typeof b.session_id !== "string" || b.session_id.length === 0) return "session_id required";
  if (b.language !== "vi" && b.language !== "en") return "language must be 'vi' or 'en'";
  if (typeof b.prompt !== "string" || b.prompt.length === 0) return "prompt required";
  if (!Array.isArray(b.events)) return "events must be an array";
  if (typeof b.raw_summary !== "string") return "raw_summary required";
  if (b.pet_persona !== undefined) {
    const p = b.pet_persona;
    if (!p || typeof p !== "object") return "pet_persona must be an object";
    if (typeof p.id !== "string" || typeof p.name !== "string"
        || typeof p.personality !== "string" || typeof p.domain !== "string") {
      return "pet_persona requires id/name/personality/domain strings";
    }
  }
  return null;
}

let _anthropic: Anthropic | null = null;
function anthropicClient(): Anthropic {
  if (!_anthropic) {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");
    _anthropic = new Anthropic({ apiKey });
  }
  return _anthropic;
}

export async function handleSummarizeTurn(
  req: Request,
  res: Response
): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }

  const auth = await verifyAuth(req.headers.authorization);
  if (!auth) {
    res.status(401).json({ error: "invalid_token" });
    return;
  }

  const validationError = validatePayload(req.body);
  if (validationError) {
    res.status(400).json({ error: "invalid_payload", detail: validationError });
    return;
  }
  const payload = req.body as SummarizePayload;

  // Cache check first — does NOT consume rate limit.
  const cached = await getCached(auth.uid, payload.turn_id);
  if (cached) {
    res.status(200).json({
      turn_id: payload.turn_id,
      narrative: cached,
      model: cached.model,
      cache_hit: true
    });
    return;
  }

  // Rate limit check.
  const limit = await checkAndIncrement(auth.uid);
  if (!limit.allowed) {
    res.status(429).json({
      error: "daily_limit_reached",
      reset_at: limit.resetAt.toISOString(),
      limit: limit.limit
    });
    return;
  }

  // Anthropic call.
  let narrative: NarrativeOutput;
  try {
    narrative = await callAnthropic(anthropicClient(), {
      prompt: payload.prompt,
      events: payload.events,
      raw_summary: payload.raw_summary,
      language: payload.language,
      petPersona: payload.pet_persona
    });
  } catch (err) {
    logger.error("anthropic call failed", { uid: auth.uid, turn_id: payload.turn_id, err: String(err) });
    res.status(502).json({ error: "upstream_failure" });
    return;
  }

  try {
    await putCached(auth.uid, payload.turn_id, { ...narrative, model: MODEL });
  } catch (err) {
    // Best-effort cache write. Failure here just means the next call for this
    // turn_id will hit Anthropic again (still idempotent for the user — they
    // get a narrative either way). Log and proceed.
    logger.warn("putCached failed; narrative will not be cached", {
      uid: auth.uid,
      turn_id: payload.turn_id,
      err: String(err)
    });
  }

  res.status(200).json({
    turn_id: payload.turn_id,
    narrative,
    model: MODEL,
    cache_hit: false
  });
}
