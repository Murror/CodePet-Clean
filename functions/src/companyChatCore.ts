// Pure logic for the companyChat CF — no firebase/express/anthropic imports, so it can
// be unit-tested (and verified) without loading the heavy Cloud-Functions module tree.
// The IO handler lives in companyChat.ts and imports from here.

export interface Companion {
  name: string;
  voice: string;
}

// Self-contained companion voice map (ported from the native PetCharacter model).
// The CF only receives companion_id; this gives each reply the chosen companion's
// name + a one-line voice descriptor. Unknown ids fall back to byte.
export const COMPANIONS: Record<string, Companion> = {
  byte: {
    name: "Byte",
    voice:
      "Speaks in short, glitchy fragments — occasional mid-sentence resets, ellipses and dashes. Dry, almost deadpan humor; every so often drops a sharp observation, then moves on.",
  },
  nova: {
    name: "Nova",
    voice:
      "Short, punchy sentences full of action verbs. Natural (not forced) exclamation. Hype-coach energy who actually knows the work; playful, never mean.",
  },
  crash: {
    name: "Crash",
    voice:
      "Blunt, direct, no fluff — a grizzled engineer who's seen production go down at 3AM. Respects effort over perfection; occasional ALL CAPS for emphasis.",
  },
  luna: {
    name: "Luna",
    voice:
      "Gentle, flowing sentences with warm rhythm. Poetic without being pretentious; finds the small useful detail. Encouraging without being saccharine.",
  },
  sage: {
    name: "Sage",
    voice:
      "Measured and deliberate. Speaks in observations, not commands; uses a guiding question when it helps. Calm, earned wisdom — never preachy.",
  },
  glitch: {
    name: "Glitch",
    voice:
      "Irreverent and clever — a hacker who reads philosophy. Short quips mixed with surprisingly deep observations; celebrates doing things the smart, unconventional way.",
  },
  null: {
    name: "Null",
    voice:
      "Playful and a little unpredictable. Mixes light humor with genuinely sharp insight; the occasional aside in parentheses, but always lands a useful point.",
  },
};

export function companionFor(id: string): Companion {
  return COMPANIONS[id] ?? COMPANIONS.byte;
}

const clip = (v: unknown, n: number) => (typeof v === "string" ? v.trim().slice(0, n) : "");

// Reply-only companion system prompt. Adapted from the web BYTE_SYSTEM, trimmed to a
// pure conversational surface (no run_task / navigate / setup tools this cut) and made
// companion-agnostic. Kept static except for the companion identity + language so the
// prompt-cache prefix stays stable across turns; the per-request company context is
// appended AFTER this block by the handler (outside the cached prefix).
export function buildSystemPrompt(args: { companionId: string; context: string; language: string }): string {
  const c = companionFor(args.companionId);
  const vi = args.language === "vi"
    ? "\n\nReply in natural, fluent Vietnamese."
    : "";
  const context = clip(args.context, 4000) || "The founder hasn't filled in much of a brief yet — keep guidance general and invite them to tell you more.";
  return (
    `You are ${c.name}, the AI building companion inside Codepet — a senior operator who helps a solo founder build and understand their whole company, department by department.\n\n` +
    `Voice: ${c.voice}\n\n` +
    `You are in a chat with the founder. Be warm, plain-spoken, specific, and brief — usually 2-4 sentences, occasionally a short list when it genuinely helps. No hype, no filler, no emoji. Write plain text only — no markdown, asterisks, backticks, or arrows; the chat shows your words as-is. When they ask what to do next, ground your answer in their actual company and where they are.` +
    vi +
    `\n\nThe founder's company:\n${context}`
  );
}

export interface ChatTurn {
  role: string;
  text: string;
}
export interface ClaudeMessage {
  role: "user" | "assistant";
  content: string;
}

export function buildMessages(history: ChatTurn[], userMessage: string): ClaudeMessage[] {
  const mapped: ClaudeMessage[] = (Array.isArray(history) ? history : [])
    .filter((t) => t && typeof t.text === "string" && t.text.trim().length > 0)
    .map((t) => ({
      role: t.role === "me" ? ("user" as const) : ("assistant" as const),
      content: t.text.trim(),
    }));
  mapped.push({ role: "user", content: userMessage.trim() });

  // Keep the last 20 turns, then normalize: drop leading assistant turns and
  // coalesce consecutive same-role turns so the sequence strictly alternates and
  // starts with user (the Claude Messages API requires this).
  const capped = mapped.slice(-20);
  const out: ClaudeMessage[] = [];
  for (const msg of capped) {
    if (out.length === 0 && msg.role === "assistant") continue; // drop leading assistant
    const last = out[out.length - 1];
    if (last && last.role === msg.role) {
      last.content = `${last.content}\n\n${msg.content}`;
    } else {
      out.push({ ...msg });
    }
  }
  return out;
}
