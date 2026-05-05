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

Ngôn ngữ output: <language>`;

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

export interface CallArgs extends BuildArgs {
  language: "vi" | "en";
}

/**
 * Calls Claude Haiku with tool use enforced. Returns parsed narrative or
 * throws on malformed response / SDK error.
 */
export async function callAnthropic(
  client: Anthropic,
  args: CallArgs
): Promise<NarrativeOutput> {
  const system = SYSTEM_PROMPT.replace("<language>", args.language === "vi" ? "Tiếng Việt" : "English");
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
