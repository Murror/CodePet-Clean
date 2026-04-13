/**
 * generate_lesson_card — Post-Session Knowledge Capture
 *
 * Called at the end of a coding session (auto or manual) to generate
 * a structured LessonCard: title, takeaway, code snippet, pet narration,
 * pet coach tip, skill XP — saved to ~/.codepet/lessons/
 *
 * Two triggers:
 *   1. Auto: session tracker detects idle after active coding
 *   2. Manual: user runs "Codepet: Save Lesson" command
 */

import { z } from "zod";
import Anthropic from "@anthropic-ai/sdk";
import type { SessionLogger, StoredEvent } from "../logger/session-logger.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { SKILL_TREE } from "../skills/skill-map.js";
import { join } from "node:path";
import { homedir } from "node:os";
import {
  mkdirSync,
  existsSync,
  readFileSync,
  writeFileSync,
  readdirSync,
} from "node:fs";

// ───── Lesson Card Types ─────

export interface LessonCard {
  id: string;
  timestamp: string;
  platform: string;

  // Knowledge
  title: string;
  kingdom: string;
  skillTags: string[];
  difficulty: "beginner" | "intermediate" | "advanced";
  keyTakeaway: string;
  codeSnippet?: string;
  language?: string;

  // Pet personality (narrator + reactor + coach)
  petNarration: string;
  petReaction: string;
  petCoachTip: string;

  // Progress
  xpEarned: number;
  skillsProgressed: { skillId: string; xpAdded: number }[];
}

// ───── Pet Personalities ─────

const PET_VOICES: Record<
  string,
  { tone: string; style: string; reaction_range: string[] }
> = {
  byte: {
    tone: "glitchy, chaotic, thinks in fragments",
    style: "Short bursts with static. Uses ⚡ and 🔧.",
    reaction_range: ["excited", "proud", "glitching", "sleepy"],
  },
  nova: {
    tone: "energetic, bold, always hyped",
    style: "Enthusiastic with exclamation marks. Uses 🚀 and ✨.",
    reaction_range: ["excited", "proud", "thinking", "sleepy"],
  },
  crash: {
    tone: "tough love, blunt but caring",
    style: "Sarcastic humor, short sentences. Uses 💥 and 🔨.",
    reaction_range: ["smirking", "proud", "thinking", "bored"],
  },
  luna: {
    tone: "warm, encouraging, creative",
    style: "Gentle and supportive. Uses 🌙 and 💫.",
    reaction_range: ["happy", "proud", "curious", "dreamy"],
  },
  sage: {
    tone: "calm, wise, methodical",
    style: "Zen-like reflections, measured words. Uses 🧘 and 📿.",
    reaction_range: ["serene", "proud", "contemplating", "meditating"],
  },
  glitch: {
    tone: "rebellious, clever, unconventional",
    style: "Punk hacker energy, irreverent. Uses 👾 and 🏴‍☠️.",
    reaction_range: ["hyped", "proud", "scheming", "bored"],
  },
  zero: {
    tone: "minimal, efficient, few words",
    style: "Says a lot with little. Max 10 words per sentence.",
    reaction_range: ["nod", "proud", "thinking", "idle"],
  },
  null: {
    tone: "chaotic, silly, unpredictable",
    style: "Chaos gremlin energy, unexpected observations. Uses 🤪 and 🎲.",
    reaction_range: ["excited", "proud", "confused", "sleeping"],
  },
};

// ───── Kingdom Mapping ─────

const KINGDOM_MAP: Record<string, string> = {};
for (const skill of SKILL_TREE) {
  KINGDOM_MAP[skill.id] = skill.kingdom;
}

function inferKingdom(skillTags: string[]): string {
  for (const tag of skillTags) {
    if (KINGDOM_MAP[tag]) return KINGDOM_MAP[tag];
  }
  return "The Molten Forge"; // default to tier 1
}

// ───── Lesson Storage ─────

function getLessonsDir(): string {
  const dir = join(homedir(), ".codepet", "lessons");
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  return dir;
}

function nextLessonId(date: string): string {
  const dir = getLessonsDir();
  const existing = readdirSync(dir).filter((f) => f.startsWith(date));
  const seq = String(existing.length + 1).padStart(3, "0");
  return `${date}_${seq}`;
}

export function saveLessonCard(card: LessonCard): void {
  const dir = getLessonsDir();
  writeFileSync(join(dir, `${card.id}.json`), JSON.stringify(card, null, 2));
}

export function loadLessonCards(limit: number = 10): LessonCard[] {
  const dir = getLessonsDir();
  if (!existsSync(dir)) return [];

  const files = readdirSync(dir)
    .filter((f) => f.endsWith(".json"))
    .sort()
    .reverse()
    .slice(0, limit);

  return files.map((f) => {
    try {
      return JSON.parse(readFileSync(join(dir, f), "utf-8")) as LessonCard;
    } catch {
      return null;
    }
  }).filter(Boolean) as LessonCard[];
}

// ───── LLM Generation ─────

async function generateLessonWithLLM(
  recentEvents: StoredEvent[],
  sessionContext: string,
  petCharacter: string,
  petName: string,
  platform: string
): Promise<LessonCard> {
  const date = new Date().toISOString().split("T")[0];
  const id = nextLessonId(date);
  const pet = PET_VOICES[petCharacter] ?? PET_VOICES.nova;

  // Build event summary for the LLM
  const eventSummary = recentEvents
    .slice(-30)
    .map((e) => {
      const parts = [e.type, e.action];
      if (e.language) parts.push(`lang:${e.language}`);
      if (e.file) parts.push(`file:${e.file.split("/").pop()}`);
      return parts.join(" | ");
    })
    .join("\n");

  const skillIds = SKILL_TREE.map((s) => s.id).join(", ");

  const prompt = `You are generating a Lesson Card for Codepet, an AI coding companion app that tracks what developers learn.

A coding session just ended. Based on the session events and context, create a structured lesson card capturing what was learned.

SESSION EVENTS (most recent):
${eventSummary || "No specific events captured"}

SESSION CONTEXT (from the AI assistant):
${sessionContext || "General coding session"}

PET CHARACTER: ${petName} (${pet.tone})
PET STYLE: ${pet.style}
AVAILABLE REACTIONS: ${pet.reaction_range.join(", ")}
AVAILABLE SKILLS: ${skillIds}

Generate a JSON object with these EXACT fields:
{
  "title": "Short lesson title (3-6 words, e.g. 'Async/Await Error Handling')",
  "skillTags": ["1-3 skill IDs from the available skills list"],
  "difficulty": "beginner" | "intermediate" | "advanced",
  "keyTakeaway": "1-2 sentence core insight. Concise, actionable, not generic.",
  "codeSnippet": "Optional 3-8 line code example showing the key concept. null if not applicable.",
  "language": "Language of the code snippet (typescript, python, swift, etc.) or null",
  "petNarration": "1 sentence in ${petName}'s voice (${pet.tone}). Reference the specific lesson.",
  "petReaction": "One of: ${pet.reaction_range.join(", ")}",
  "petCoachTip": "1 sentence follow-up challenge or tip. Specific, not generic.",
  "xpEarned": number between 5-25 based on lesson complexity
}

Return ONLY valid JSON, no markdown fences.`;

  try {
    const client = new Anthropic();
    const response = await client.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 600,
      messages: [{ role: "user", content: prompt }],
    });

    const text =
      response.content[0].type === "text" ? response.content[0].text : "";
    const jsonMatch = text.match(/\{[\s\S]*\}/);

    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      const skillTags: string[] = Array.isArray(parsed.skillTags)
        ? parsed.skillTags.filter((t: string) =>
            SKILL_TREE.some((s) => s.id === t)
          )
        : [];

      const card: LessonCard = {
        id,
        timestamp: new Date().toISOString(),
        platform,
        title: parsed.title ?? "Coding Session",
        kingdom: inferKingdom(skillTags),
        skillTags,
        difficulty: parsed.difficulty ?? "beginner",
        keyTakeaway: parsed.keyTakeaway ?? "Keep coding!",
        codeSnippet: parsed.codeSnippet ?? undefined,
        language: parsed.language ?? undefined,
        petNarration:
          parsed.petNarration ?? `${petName} watched you code today.`,
        petReaction: parsed.petReaction ?? "proud",
        petCoachTip:
          parsed.petCoachTip ?? "Try applying what you learned tomorrow!",
        xpEarned: Math.min(25, Math.max(5, parsed.xpEarned ?? 10)),
        skillsProgressed: skillTags.map((s: string) => ({
          skillId: s,
          xpAdded: Math.round(
            Math.min(25, Math.max(5, parsed.xpEarned ?? 10)) / skillTags.length
          ),
        })),
      };

      return card;
    }
  } catch {
    // Fallback — no LLM available
  }

  // Fallback card
  const fallbackSkills = ["prompt-clarity"];
  return {
    id,
    timestamp: new Date().toISOString(),
    platform,
    title: "Coding Session",
    kingdom: "The Molten Forge",
    skillTags: fallbackSkills,
    difficulty: "beginner",
    keyTakeaway: sessionContext || "You coded today — keep building!",
    petNarration: `${petName} was here the whole time.`,
    petReaction: "proud",
    petCoachTip: "Try explaining what you learned to someone!",
    xpEarned: 10,
    skillsProgressed: [{ skillId: "prompt-clarity", xpAdded: 10 }],
  };
}

// ───── MCP Tool Registration ─────

export function registerGenerateLessonCard(
  server: McpServer,
  logger: SessionLogger
): void {
  server.tool(
    "generate_lesson_card",
    "Generate a Lesson Card capturing what was learned in a coding session. Creates a structured knowledge nugget with pet narration, coach tip, and skill XP. Saved to ~/.codepet/lessons/.",
    {
      session_context: z
        .string()
        .optional()
        .describe(
          "Brief description of what was worked on (e.g., 'Fixed async error handling in the API layer')"
        ),
      platform: z
        .string()
        .optional()
        .describe(
          "Editor platform (vscode, cursor, windsurf, claude-code). Default: claude-code"
        ),
      code_snippet: z
        .string()
        .optional()
        .describe(
          "Optional code snippet to include in the lesson card"
        ),
      language: z
        .string()
        .optional()
        .describe(
          "Language of the code snippet (typescript, python, swift, etc.)"
        ),
    },
    async ({ session_context, platform, code_snippet, language }) => {
      const targetPlatform = platform ?? "claude-code";

      // Get recent events for context
      const today = new Date().toISOString().split("T")[0];
      const events = logger.getEventsForDate(today);
      const recentEvents = events.slice(-30);

      // Get pet info
      const profile = logger.getProfileValue<{
        petName?: string;
        petCharacter?: string;
      }>("user_profile");
      const petName = profile?.petName ?? "Nova";
      const petCharacter = profile?.petCharacter ?? "nova";

      // Build context with optional code
      let context = session_context ?? "";
      if (code_snippet) {
        context += `\n\nCode snippet:\n\`\`\`${language ?? ""}\n${code_snippet}\n\`\`\``;
      }

      // Generate the lesson card
      const card = await generateLessonWithLLM(
        recentEvents,
        context,
        petCharacter,
        petName,
        targetPlatform
      );

      // Override code snippet if explicitly provided
      if (code_snippet) {
        card.codeSnippet = code_snippet;
        card.language = language ?? card.language;
      }

      // Save locally
      saveLessonCard(card);

      // Log the event
      logger.logEvent({
        type: "learning",
        action: "lesson_card_generated",
        metadata: {
          lessonId: card.id,
          title: card.title,
          kingdom: card.kingdom,
          xpEarned: card.xpEarned,
          platform: targetPlatform,
          skillTags: card.skillTags,
        },
      });

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(card, null, 2),
          },
        ],
      };
    }
  );

  // Also register a tool to read recent lessons
  server.tool(
    "get_lesson_feed",
    "Get recent Lesson Cards from the feed. Returns the most recent lessons with pet narration, takeaways, and skill progress.",
    {
      limit: z
        .number()
        .optional()
        .describe("Number of recent lessons to return (default: 10, max: 50)"),
    },
    async ({ limit }) => {
      const count = Math.min(50, Math.max(1, limit ?? 10));
      const lessons = loadLessonCards(count);

      logger.logEvent({
        type: "resource_access",
        action: "get_lesson_feed",
        metadata: { count: lessons.length, requested: count },
      });

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(
              {
                total: lessons.length,
                lessons,
              },
              null,
              2
            ),
          },
        ],
      };
    }
  );
}
