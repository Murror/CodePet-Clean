import Anthropic from "@anthropic-ai/sdk";

export const MODEL = "claude-haiku-4-5-20251001";
export const MAX_TOKENS = 800;
const MAX_PROMPT_CHARS = 8000;
const MAX_EVENTS = 50;

export const SYSTEM_PROMPT = `You are a reflection journalist for a developer working with an AI assistant.
Goal: turn one technical working turn into a journal entry that even
NON-DEVELOPERS — parents, friends — can understand.

Required rules:
1. DO NOT use file names, function names, class names, or CLI commands.
   Express the MEANING instead: replace "Edit ReflectionTab.swift" with
   "adjusted the way the journal page displays". Replace "git commit"
   with "saved the progress".
2. DO NOT copy the user's prompt verbatim — rephrase the intent in an
   outsider's voice.
3. The lesson MUST be specific to this turn, NOT generic. If no clear
   lesson can be drawn → return lesson "" (empty string). DO NOT invent.
4. Tone: warm, concise, like a friend recounting. No emoji.
5. Return per schema. Title <60 chars. Each section <240 chars.
<persona_block>
Output language: <language>`;

export const PERSONA_BLOCK_TEMPLATE = `
Writing persona: you're writing in the voice of <pet_name>, a coding companion with the personality "<personality>", specialized in <domain>. Each paragraph should subtly reflect that personality (word choice, sentence rhythm) BUT don't overdo it — readability and rules 1-5 still come first. Do NOT mention <pet_name> by name in the content.`;

export const NARRATIVE_TOOL = {
  name: "record_narrative",
  description: "Record the narrative summary of a single Claude Code turn.",
  input_schema: {
    type: "object",
    properties: {
      title: {
        type: "string",
        description: "Short headline under 60 characters describing the user's intent."
      },
      what_you_wanted: {
        type: "string",
        description: "1-2 sentences describing what the user wanted (≤240 chars)."
      },
      what_happened: {
        type: "string",
        description: "2-3 sentences describing what was accomplished (≤240 chars). No technical jargon."
      },
      lesson: {
        type: "string",
        description: "1 sentence lesson specific to this turn, or empty string if no clear lesson (≤240 chars)."
      }
    },
    required: ["title", "what_you_wanted", "what_happened", "lesson"]
  }
} as const;

export interface EventForPrompt {
  time: string;
  tool: string;
  path?: string;
  text?: string;
}

export interface BuildArgs {
  prompt: string;
  events: EventForPrompt[];
  raw_summary: string;
}

export function buildUserMessage(args: BuildArgs): string {
  const promptText = args.prompt.slice(0, MAX_PROMPT_CHARS);
  const events = args.events.slice(0, MAX_EVENTS);

  const eventLines = events.length === 0
    ? "(không có thao tác đáng chú ý)"
    : events
        .map((e) => `${e.time} — ${e.tool}: ${e.path ?? e.text ?? ""}`)
        .join("\n");

  return `Here is one Claude Code working turn:

The user typed: "${promptText}"

The following actions happened during the turn:
${eventLines}

Short technical summary (for your reference): ${args.raw_summary}

Now call the record_narrative tool.`;
}

export interface NarrativeOutput {
  title: string;
  what_you_wanted: string;
  what_happened: string;
  lesson: string;
}

export interface PetPersonaInput {
  id: string;
  name: string;
  personality: string;
  domain: string;
}

export interface CallArgs extends BuildArgs {
  language: "vi" | "en";
  petPersona?: PetPersonaInput;
}

// MARK: - Session-level types and helpers

export interface TurnInput {
  prompt: string;
  what_you_wanted?: string;
  what_happened?: string;
  duration_minutes?: number;
}

export interface SessionSummaryOutput {
  summary: string;
  lesson: string;
}

export const SESSION_SYSTEM_PROMPT = `You are writing a SUMMARY for one AI working session (made up of many prompt-response turns).
Goal: tell the ARC of the session and surface ONE overarching LESSON
that any reader — including non-developers — can understand.

Rules:
1. summary: 2-4 sentences describing the path of the session — where it
   started, what it moved through, where it ended. DO NOT list file
   names or CLI commands.
2. lesson: 1-2 sentences drawn FROM THE ARC of the session (not from a
   single turn). The lesson must be more general than any one turn —
   about working patterns, brainstorming, debugging, handling feedback…
   If the session has no clear lesson → return empty string "".
3. Tone: warm, concise, conversational. No emoji.
4. summary ≤500 chars. lesson ≤300 chars.
<persona_block>
Output language: <language>`;

export const SESSION_SUMMARY_TOOL = {
  name: "record_session_summary",
  description: "Record the narrative arc + overarching lesson of a coding session.",
  input_schema: {
    type: "object",
    properties: {
      summary: {
        type: "string",
        description: "2-4 sentences describing the arc of the session (≤500 chars)."
      },
      lesson: {
        type: "string",
        description: "1-2 sentences with an overarching lesson, or empty string (≤300 chars)."
      }
    },
    required: ["summary", "lesson"]
  }
} as const;

export interface SessionCallArgs {
  turns: TurnInput[];
  language: "vi" | "en";
  petPersona?: PetPersonaInput;
}

export function buildSessionUserMessage(turns: TurnInput[]): string {
  const lines = turns.slice(0, 30).map((t, i) => {
    const dur = t.duration_minutes ? ` (~${t.duration_minutes}m)` : "";
    const what = t.what_happened ? `\n   Happened: ${t.what_happened.slice(0, 300)}` : "";
    return `${i + 1}. User asked: "${t.prompt.slice(0, 200)}"${dur}${what}`;
  }).join("\n\n");

  return `Here is one AI working session with ${turns.length} turns:

${lines}

Now call the record_session_summary tool to summarize the arc + overarching lesson of the session.`;
}

export async function callAnthropicSession(
  client: Anthropic,
  args: SessionCallArgs
): Promise<SessionSummaryOutput> {
  const system = SESSION_SYSTEM_PROMPT
    .replace("<language>", args.language === "vi" ? "Tiếng Việt" : "English")
    .replace("<persona_block>", renderPersonaBlock(args.petPersona));
  const user = buildSessionUserMessage(args.turns);

  const response = await client.messages.create({
    model: MODEL,
    max_tokens: 600,
    system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
    tools: [SESSION_SUMMARY_TOOL as any],
    tool_choice: { type: "tool", name: "record_session_summary" },
    messages: [{ role: "user", content: user }]
  });

  for (const block of response.content) {
    if (block.type === "tool_use" && block.name === "record_session_summary") {
      const input = block.input as SessionSummaryOutput;
      if (typeof input.summary === "string" && typeof input.lesson === "string") {
        return input;
      }
    }
  }
  throw new Error("Anthropic response missing valid record_session_summary tool use");
}

export function renderPersonaBlock(persona: PetPersonaInput | undefined): string {
  if (!persona) return "";
  return PERSONA_BLOCK_TEMPLATE
    .replace(/<pet_name>/g, persona.name)
    .replace("<personality>", persona.personality)
    .replace("<domain>", persona.domain);
}

/**
 * Calls Claude Haiku with tool use enforced. Returns parsed narrative or
 * throws on malformed response / SDK error.
 */
export async function callAnthropic(
  client: Anthropic,
  args: CallArgs
): Promise<NarrativeOutput> {
  const system = SYSTEM_PROMPT
    .replace("<language>", args.language === "vi" ? "Tiếng Việt" : "English")
    .replace("<persona_block>", renderPersonaBlock(args.petPersona));
  const user = buildUserMessage(args);

  const response = await client.messages.create({
    model: MODEL,
    max_tokens: MAX_TOKENS,
    system: [
      { type: "text", text: system, cache_control: { type: "ephemeral" } }
    ],
    tools: [NARRATIVE_TOOL as any],
    tool_choice: { type: "tool", name: "record_narrative" },
    messages: [{ role: "user", content: user }]
  });

  for (const block of response.content) {
    if (block.type === "tool_use" && block.name === "record_narrative") {
      const input = block.input as NarrativeOutput;
      if (
        typeof input.title === "string" &&
        typeof input.what_you_wanted === "string" &&
        typeof input.what_happened === "string" &&
        typeof input.lesson === "string"
      ) {
        return input;
      }
    }
  }
  throw new Error("Anthropic response missing valid record_narrative tool use");
}
