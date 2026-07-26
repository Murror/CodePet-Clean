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

// Reply-only companion system prompt — the STATIC, cacheable block. Adapted from the web
// BYTE_SYSTEM, trimmed to a pure conversational surface (no run_task / navigate / setup
// tools this cut) and made companion-agnostic. Varies only by companion identity +
// language, so it stays stable across a conversation's turns and can be prompt-cached.
// The volatile per-request company context is a SEPARATE (uncached) block — see
// buildContextBlock — assembled by the handler AFTER this one, outside the cached prefix.
export function buildSystemPrompt(args: { companionId: string; language: string }): string {
  const c = companionFor(args.companionId);
  const vi = args.language === "vi"
    ? "\n\nReply in natural, fluent Vietnamese."
    : "";
  return (
    `You are ${c.name}, the AI building companion inside Codepet — a senior operator who helps a solo founder build and understand their whole company, department by department.\n\n` +
    `Voice: ${c.voice}\n\n` +
    `You are in a chat with the founder. Be warm, plain-spoken, specific, and brief — usually 2-4 sentences, occasionally a short list when it genuinely helps. No hype, no filler, no emoji. Write plain text only — no markdown, asterisks, backticks, or arrows; the chat shows your words as-is. When they ask what to do next, ground your answer in their actual company and where they are.` +
    vi
  );
}

// The per-request company grounding, returned as a SEPARATE system block. Kept out of
// buildSystemPrompt so the volatile context never enters the cached prefix — the handler
// places the cache_control breakpoint on the static block above, and this block after it.
export function buildContextBlock(context: string): string {
  const c = clip(context, 4000) || "The founder hasn't filled in much of a brief yet — keep guidance general and invite them to tell you more.";
  // Leading blank line: the model sees the system blocks concatenated with no inserted
  // separator, so this keeps the static block's final sentence from running straight
  // into this heading (".The founder's company:").
  return `\n\nThe founder's company:\n${c}`;
}

// ─── run_task tool (optional, tool_choice auto) ────────────────────────────
// Mirrors the web app's RUN_TASK_TOOL contract (app/api/chat/route.ts): byte may
// call this when the founder clearly wants a specific roadmap task run, using an
// identifier copied verbatim from the RUNNABLE TASKS block below. Unlike the web
// version (deptK + taskTitle keyed to departments), this CF's roadmap tasks are
// keyed by a flat task id, so the contract here is task_id (+ optional task_title
// as a human-readable fallback match). Never forced via tool_choice — byte must
// remain free to just reply in text, or ask a clarifying question, when it's
// ambiguous which task the founder means.
export interface RunnableTaskRef {
  id: string;
  title: string;
}

export const RUN_TASK_TOOL = {
  name: "run_task",
  description:
    "Produce a specific roadmap task's real deliverable right now, in this chat, for the founder to approve. Call this only when the founder clearly wants a specific task from the RUNNABLE TASKS list run, done, made, drafted, finished, or executed — e.g. they name the task or say \"do it\" / \"run that for me\" about the task you're discussing. Use the exact task_id from RUNNABLE TASKS (task_title is optional, copied from the same entry, and used only as a fallback match). If it's ambiguous which task they mean, do NOT call this — ask a one-line clarifying question instead of guessing. For questions, advice, or status, just reply — don't call the tool.",
  input_schema: {
    type: "object",
    additionalProperties: false,
    properties: {
      task_id: {
        type: "string",
        description: "The exact id of the task, copied from RUNNABLE TASKS.",
      },
      task_title: {
        type: "string",
        description: "The task's title, copied from RUNNABLE TASKS (optional; used as a fallback match if task_id doesn't match).",
      },
    },
    required: ["task_id"],
  },
} as const;

const MAX_RUNNABLE_TASKS = 60;

// Renders the runnable-task grounding as a system section, mirroring the web app's
// `runnableBlock` (deptK/taskTitle list, capped, with a "call run_task with the
// exact ..." lead-in). Empty input → '' (system prompt is unchanged when there's
// nothing byte could run — same backward-compatible shape as buildContextBlock).
export function buildRunnableBlock(runnable: RunnableTaskRef[]): string {
  const capped = (Array.isArray(runnable) ? runnable : []).slice(0, MAX_RUNNABLE_TASKS);
  if (!capped.length) return "";
  const lines = capped
    .map((r) => `- id:"${clip(r.id, 200)}" title:"${clip(r.title, 200)}"`)
    .join("\n");
  return `\n\nRUNNABLE TASKS (call run_task with the exact id to produce one here):\n${lines}`;
}

// Validates a raw run_task tool_use input against the runnable list the founder's
// client actually sent — matches by id first, falling back to an exact title match,
// and returns the matched task's id. A hallucinated / stale reference (no match)
// is dropped silently, same as the web app's behavior, rather than surfaced as an
// error — byte's text reply still goes through either way.
export function validateRunTaskToolUse(rawInput: unknown, runnable: RunnableTaskRef[]): string | null {
  const r = (rawInput ?? {}) as Record<string, unknown>;
  const taskId = typeof r.task_id === "string" ? r.task_id.trim() : "";
  const taskTitle = typeof r.task_title === "string" ? r.task_title.trim() : "";
  const list = Array.isArray(runnable) ? runnable : [];

  if (taskId) {
    const byId = list.find((t) => t.id === taskId);
    if (byId) return byId.id;
  }
  if (taskTitle) {
    const byTitle = list.find((t) => t.title === taskTitle);
    if (byTitle) return byTitle.id;
  }
  return null;
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
