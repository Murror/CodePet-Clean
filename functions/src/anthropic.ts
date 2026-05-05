import Anthropic from "@anthropic-ai/sdk";

export const MODEL = "claude-haiku-4-5-20251001";
export const MAX_TOKENS = 800;
const MAX_PROMPT_CHARS = 8000;
const MAX_EVENTS = 50;

export const SYSTEM_PROMPT = `Bạn là người ghi nhật ký phản tỉnh cho 1 lập trình viên đang dùng AI assistant.
Mục tiêu: biến 1 lượt làm việc kỹ thuật thành 1 entry nhật ký mà CHA MẸ
hoặc BẠN BÈ KHÔNG PHẢI DEV cũng đọc hiểu.

Quy tắc bắt buộc:
1. KHÔNG dùng tên file, tên hàm, tên class, tên CLI command. Diễn đạt bằng
   ý nghĩa: thay vì "Edit ReflectionTab.swift" → "chỉnh phần hiển thị trang
   nhật ký". Thay vì "git commit" → "lưu lại tiến độ".
2. KHÔNG sao chép nguyên văn prompt user — diễn đạt lại ý định bằng lời
   của người ngoài cuộc.
3. Bài học PHẢI cụ thể với lượt này, KHÔNG sáo rỗng. Nếu không rút ra
   được bài học rõ → trả lesson "" (empty string), KHÔNG bịa.
4. Tone: ấm áp, gọn, như 1 người bạn đang kể lại. Không dùng emoji.
5. Trả về theo schema. Title <60 ký tự. Mỗi đoạn <240 ký tự.
<persona_block>
Ngôn ngữ output: <language>`;

export const PERSONA_BLOCK_TEMPLATE = `
Persona viết: bạn đang viết với giọng của <pet_name>, một bạn đồng hành coding với tính cách "<personality>", chuyên về <domain>. Mỗi đoạn nên thấp thoáng đặc trưng đó (cách dùng từ, nhịp câu) NHƯNG không lạm dụng — vẫn phải dễ đọc và đúng quy tắc 1-5 ở trên. Đừng nhắc đến tên <pet_name> trong nội dung.`;

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

  return `Đây là 1 lượt làm việc với Claude Code:

User đã gõ: "${promptText}"

Trong lượt đó, các thao tác đã xảy ra:
${eventLines}

Tóm tắt kỹ thuật ngắn (cho bạn tham khảo): ${args.raw_summary}

Hãy gọi tool record_narrative.`;
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

export const SESSION_SYSTEM_PROMPT = `Bạn đang viết bản TÓM TẮT cho 1 phiên làm việc với AI (gồm nhiều lượt prompt-response).
Mục tiêu: kể lại ARC của phiên và rút ra 1 BÀI HỌC tổng quát mà ai đọc cũng hiểu, kể cả người không phải dev.

Quy tắc:
1. summary: 2-4 câu kể lại đường đi của phiên — bắt đầu từ đâu, đi qua những bước nào, kết thúc ở đâu. KHÔNG liệt kê tên file, lệnh CLI.
2. lesson: 1-2 câu rút ra TỪ ARC của phiên (không phải từ 1 turn riêng lẻ). Bài học phải tổng quát hơn từng turn — về pattern làm việc, cách brainstorm, cách debug, cách quản lý feedback... Nếu phiên không có lesson rõ → trả lesson rỗng "".
3. Tone: ấm áp, gọn, như đang nói chuyện. Không emoji.
4. summary ≤500 chars. lesson ≤300 chars.
<persona_block>
Ngôn ngữ output: <language>`;

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
    const dur = t.duration_minutes ? ` (~${t.duration_minutes}p)` : "";
    const what = t.what_happened ? `\n   Đã xảy ra: ${t.what_happened.slice(0, 300)}` : "";
    return `${i + 1}. User hỏi: "${t.prompt.slice(0, 200)}"${dur}${what}`;
  }).join("\n\n");

  return `Đây là 1 phiên làm việc với AI gồm ${turns.length} lượt:

${lines}

Hãy gọi tool record_session_summary để tóm tắt arc + bài học tổng quát của phiên.`;
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
