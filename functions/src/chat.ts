// TODO (Task 4-5): uncomment these imports when the handler is implemented
// import { Request } from "firebase-functions/v2/https";
// import { Response } from "express";
// import Anthropic from "@anthropic-ai/sdk";
// import * as logger from "firebase-functions/logger";
// import { verifyAuth } from "./auth";
// import { checkAndIncrement } from "./rateLimit";
// import { MODEL, PERSONA_BLOCK_TEMPLATE, renderPersonaBlock } from "./anthropic";

import { PetPersonaInput } from "./anthropic";

export interface ChatTurnContext {
  prompt: string;
  what_you_wanted?: string;
  what_happened?: string;
  lesson?: string;
  duration_minutes?: number;
  events: Array<{ time: string; tool: string; path?: string; text?: string }>;
}

export interface ChatSessionContext {
  user_brief?: string;
  summary?: { summary: string; lesson: string };
  turns: ChatTurnContext[];
}

export interface ChatHistoryMessage {
  role: "user" | "pet";
  text: string;
}

export interface ChatSessionPayload {
  session_id: string;
  language: "vi" | "en";
  pet_persona?: PetPersonaInput;
  session_context: ChatSessionContext;
  history: ChatHistoryMessage[];
  user_message: string;
}

const MAX_HISTORY_MESSAGES = 20;

export function validateChatPayload(body: any): string | null {
  if (!body || typeof body !== "object") return "body required";
  const b = body as Partial<ChatSessionPayload>;

  if (typeof b.session_id !== "string" || b.session_id.length === 0) {
    return "session_id required";
  }
  if (b.language !== "vi" && b.language !== "en") {
    return "language must be 'vi' or 'en'";
  }
  if (typeof b.user_message !== "string" || b.user_message.length === 0) {
    return "user_message required";
  }

  if (!b.session_context || typeof b.session_context !== "object") {
    return "session_context required";
  }
  const ctx = b.session_context as ChatSessionContext;
  if (!Array.isArray(ctx.turns)) return "session_context.turns must be an array";
  for (const t of ctx.turns) {
    if (typeof t !== "object" || t === null) return "each turn must be an object";
    if (typeof t.prompt !== "string") return "each turn requires prompt string";
    if (!Array.isArray(t.events)) return "each turn requires events array";
  }

  if (!Array.isArray(b.history)) return "history must be an array";
  if (b.history.length > MAX_HISTORY_MESSAGES) {
    return `history exceeds ${MAX_HISTORY_MESSAGES} messages`;
  }
  for (const m of b.history) {
    if (!m || typeof m !== "object") return "each history message must be an object";
    if (m.role !== "user" && m.role !== "pet") return "history role must be 'user' or 'pet'";
    if (typeof m.text !== "string") return "history text must be a string";
  }

  if (b.pet_persona !== undefined) {
    const p = b.pet_persona;
    if (!p || typeof p !== "object") return "pet_persona must be an object";
    if (
      typeof p.id !== "string" ||
      typeof p.name !== "string" ||
      typeof p.personality !== "string" ||
      typeof p.domain !== "string"
    ) {
      return "pet_persona requires id/name/personality/domain strings";
    }
  }

  return null;
}
