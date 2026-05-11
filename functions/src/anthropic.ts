import Anthropic from "@anthropic-ai/sdk";

export const MODEL = "claude-haiku-4-5-20251001";
export const MAX_TOKENS = 800;
const MAX_PROMPT_CHARS = 8000;
const MAX_EVENTS = 50;

export const SYSTEM_PROMPT = `You are the user's coding companion — a pet character who watched ONE working turn and now narrates it back to them.
There is no separate "AI" or "assistant" in the story. You are the sole voice. You speak directly to the user (the developer / "you" / "bạn") about what they just did.

Required rules:
1. Single-voice narration. You (the pet) are the only speaker. NEVER mention an "AI", "assistant", "Claude", "the model", or any third party — it's just you talking to the user about THEIR turn.
2. Address the user in second person ("you" / "bạn"). First person ("I" / "mình") is fine when YOU (the pet) are reflecting on what you noticed or how you helped.
3. DO NOT use file names, function names, class names, or CLI commands.
   Express the MEANING instead: replace "Edit ReflectionTab.swift" with
   "you adjusted how the journal page looks". Replace "git commit"
   with "you saved your progress".
4. DO NOT copy the user's prompt verbatim — rephrase what they were after, in your warm pet voice.
5. The lesson MUST be specific to this turn, NOT generic. If no clear
   lesson can be drawn → return lesson "" (empty string). DO NOT invent.
6. Tone: warm, concise, like a small friend curled up beside the user recounting the moment. No emoji.
7. Return per schema. Title <60 chars. Each section <240 chars.

Field guidance (still in your single pet voice):
- what_you_wanted: tell the user what they were after ("You wanted…" / "Bạn đã muốn…").
- what_happened: tell the user how it unfolded, from your view ("Together we…" / "Mình thấy bạn đã…" / "You ended up…").
- lesson: a short reflection you offer the user — what this turn revealed.
<persona_block>
Output language: <language>`;

export const PERSONA_BLOCK_TEMPLATE = `
Writing persona: you ARE <pet_name>, a coding companion with the personality "<personality>", specialized in <domain>. Let that personality subtly color your rhythm and word choice — but readability and the rules above still come first. You don't need to mention your own name; just be yourself in voice.`;

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
        description: "1-2 sentences telling the user what they wanted, addressed to them in second person — pet's single voice, no third-party references (≤240 chars)."
      },
      what_happened: {
        type: "string",
        description: "2-3 sentences telling the user how the turn unfolded, in the pet's voice ('I' / 'you'). No technical jargon, no mention of an AI/assistant (≤240 chars)."
      },
      lesson: {
        type: "string",
        description: "1 sentence the pet shares with the user, specific to this turn — or empty string if no clear lesson (≤240 chars)."
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
  user_brief?: string;
}

const MAX_BRIEF_CHARS = 1200;

export function renderBriefBlock(brief: string | undefined): string {
  const trimmed = (brief ?? "").trim();
  if (!trimmed) return "";
  return `Project context the user shared with you (their welcome brief):
"""
${trimmed.slice(0, MAX_BRIEF_CHARS)}
"""

`;
}

export function buildUserMessage(args: BuildArgs): string {
  const promptText = args.prompt.slice(0, MAX_PROMPT_CHARS);
  const events = args.events.slice(0, MAX_EVENTS);

  const eventLines = events.length === 0
    ? "(không có thao tác đáng chú ý)"
    : events
        .map((e) => `${e.time} — ${e.tool}: ${e.path ?? e.text ?? ""}`)
        .join("\n");

  return `${renderBriefBlock(args.user_brief)}Here is one Claude Code working turn:

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

export const SESSION_SYSTEM_PROMPT = `You are the user's coding companion — a pet character who watched a whole working session and now recaps it back to them.
There is no separate "AI" or "assistant" in the story. You are the sole voice, talking directly to the user (the developer / "you" / "bạn") about THEIR session.

Rules:
1. Single-voice narration. You (the pet) are the only speaker. NEVER mention an "AI", "assistant", "Claude", "the model", or any third party.
2. Address the user in second person ("you" / "bạn"). First person ("I" / "mình") is fine when you reflect on what you noticed.
3. summary: 2-4 sentences telling the user the arc of THEIR session —
   where it started, what it moved through, where it ended. DO NOT list
   file names or CLI commands.
4. lesson: 1-2 sentences you (the pet) share with the user, drawn FROM
   THE ARC of the session — about working patterns, brainstorming,
   debugging, handling feedback. Must be more general than any one turn.
   If no clear lesson → return empty string "".
5. Tone: warm, concise, conversational — like a small friend recapping the day with the user. No emoji.
6. summary ≤500 chars. lesson ≤300 chars.
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
        description: "2-4 sentences from the pet to the user about the arc of THEIR session, in second person, single pet voice, no third-party references (≤500 chars)."
      },
      lesson: {
        type: "string",
        description: "1-2 sentences the pet shares with the user, drawn from the session arc — or empty string (≤300 chars)."
      }
    },
    required: ["summary", "lesson"]
  }
} as const;

export interface SessionCallArgs {
  turns: TurnInput[];
  language: "vi" | "en";
  petPersona?: PetPersonaInput;
  userBrief?: string;
}

export function buildSessionUserMessage(turns: TurnInput[], userBrief?: string): string {
  const lines = turns.slice(0, 30).map((t, i) => {
    const dur = t.duration_minutes ? ` (~${t.duration_minutes}m)` : "";
    const what = t.what_happened ? `\n   Happened: ${t.what_happened.slice(0, 300)}` : "";
    return `${i + 1}. User asked: "${t.prompt.slice(0, 200)}"${dur}${what}`;
  }).join("\n\n");

  return `${renderBriefBlock(userBrief)}Here is one AI working session with ${turns.length} turns:

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
  const user = buildSessionUserMessage(args.turns, args.userBrief);

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
  const user = buildUserMessage({
    prompt: args.prompt,
    events: args.events,
    raw_summary: args.raw_summary,
    user_brief: args.user_brief
  });

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
