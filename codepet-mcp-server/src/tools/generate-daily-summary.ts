/**
 * generate_daily_summary — LLM-Powered Daily Summary
 *
 * Aggregates session events for a given day, computes raw stats,
 * then calls the Anthropic API to generate a natural language summary
 * and an in-character pet reaction.
 *
 * Saves the result via logger.saveDailySummary() and returns it.
 */

import { z } from "zod";
import Anthropic from "@anthropic-ai/sdk";
import type { SessionLogger, StoredEvent, DailySummary } from "../logger/session-logger.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { mapActivityToSkills } from "../skills/skill-map.js";

// Pet personalities for in-character reactions
const PET_PERSONALITIES: Record<string, { name: string; personality: string }> = {
  byte: { name: "Byte", personality: "glitchy, chaotic, thinks in fragments — speaks in short bursts with static" },
  nova: { name: "Nova", personality: "energetic, bold, moves fast — always hyped and encouraging" },
  crash: { name: "Crash", personality: "tough love, breaks things to learn — blunt but caring" },
  luna: { name: "Luna", personality: "warm, encouraging, creative — gentle and supportive" },
  sage: { name: "Sage", personality: "calm, wise, methodical — zen-like and reflective" },
  glitch: { name: "Glitch", personality: "rebellious, clever, unconventional — punk hacker energy" },
  zero: { name: "Zero", personality: "minimal, efficient, few words — says a lot with little" },
  null: { name: "Null", personality: "chaotic, silly, unpredictable — chaos gremlin energy" },
};

interface RawStats {
  totalEvents: number;
  totalCodingMinutes: number;
  linesAdded: number;
  linesRemoved: number;
  commits: number;
  aiSessions: number;
  errorsFound: number;
  errorsFixed: number;
  languageBreakdown: Record<string, number>;
  topFiles: string[];
  skillsTracked: Record<string, number>;
}

function computeRawStats(events: StoredEvent[]): RawStats {
  if (events.length === 0) {
    return {
      totalEvents: 0,
      totalCodingMinutes: 0,
      linesAdded: 0,
      linesRemoved: 0,
      commits: 0,
      aiSessions: 0,
      errorsFound: 0,
      errorsFixed: 0,
      languageBreakdown: {},
      topFiles: [],
      skillsTracked: {},
    };
  }

  // Estimate coding time from event timestamp spread
  const timestamps = events.map((e) => new Date(e.timestamp).getTime()).sort();
  const firstEvent = timestamps[0];
  const lastEvent = timestamps[timestamps.length - 1];
  const totalCodingMinutes = Math.round((lastEvent - firstEvent) / 60000);

  // Git stats
  let linesAdded = 0;
  let linesRemoved = 0;
  let commits = 0;

  for (const event of events) {
    if (event.type === "git" && event.action === "commit") {
      commits++;
    }
    if (event.type === "tool_call" && event.action === "get_git_context") {
      linesAdded += (event.metadata?.linesAdded as number) ?? 0;
      linesRemoved += (event.metadata?.linesRemoved as number) ?? 0;
    }
  }

  // AI sessions (tool calls)
  const aiSessions = events.filter((e) => e.type === "tool_call").length;

  // Errors
  const errorsFound = events.filter(
    (e) => e.type === "diagnostic" && e.action === "errors_found"
  ).length;
  const errorsFixed = events.filter(
    (e) => e.type === "diagnostic" && e.action === "clean"
  ).length;

  // Language breakdown
  const languageBreakdown: Record<string, number> = {};
  for (const event of events) {
    if (event.language) {
      languageBreakdown[event.language] = (languageBreakdown[event.language] ?? 0) + 1;
    }
  }

  // Top files
  const fileCounts = new Map<string, number>();
  for (const event of events) {
    if (event.file) {
      fileCounts.set(event.file, (fileCounts.get(event.file) ?? 0) + 1);
    }
  }
  const topFiles = Array.from(fileCounts.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([file]) => file);

  // Skill XP from mapping
  const skillProgress = mapActivityToSkills(events);
  const skillsTracked: Record<string, number> = {};
  for (const skill of skillProgress) {
    if (skill.xp > 0) {
      skillsTracked[skill.id] = skill.xp;
    }
  }

  return {
    totalEvents: events.length,
    totalCodingMinutes,
    linesAdded,
    linesRemoved,
    commits,
    aiSessions,
    errorsFound,
    errorsFixed,
    languageBreakdown,
    topFiles,
    skillsTracked,
  };
}

async function generateSummaryWithLLM(
  stats: RawStats,
  date: string,
  petCharacter: string,
  petName: string
): Promise<{ summary: string; petReaction: string }> {
  const pet = PET_PERSONALITIES[petCharacter] ?? PET_PERSONALITIES.nova;

  const prompt = `You are generating a daily coding summary for a developer who uses Codepet, an AI coding companion app.

Date: ${date}

Raw stats:
- Coding time: ~${stats.totalCodingMinutes} minutes
- Lines added: ${stats.linesAdded}, removed: ${stats.linesRemoved}
- Commits: ${stats.commits}
- AI tool sessions: ${stats.aiSessions}
- Errors found: ${stats.errorsFound}, errors fixed: ${stats.errorsFixed}
- Languages used: ${Object.entries(stats.languageBreakdown).map(([l, c]) => `${l} (${c} events)`).join(", ") || "none tracked"}
- Top files: ${stats.topFiles.join(", ") || "none tracked"}
- Skills earning XP: ${Object.entries(stats.skillsTracked).map(([s, xp]) => `${s} (+${xp})`).join(", ") || "none yet"}

Generate TWO things as JSON:

1. "summary": A 2-3 sentence natural language summary of this day's coding activity. Be specific about what was accomplished. If stats are low/zero, note it's a quiet day.

2. "petReaction": A short (1-2 sentence) in-character reaction from the user's pet "${petName}" who is a ${pet.personality}. Keep it fun, encouraging, and matched to the pet's personality. Reference specific stats when interesting.

Return ONLY valid JSON: {"summary": "...", "petReaction": "..."}`;

  try {
    const client = new Anthropic();
    const response = await client.messages.create({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 300,
      messages: [{ role: "user", content: prompt }],
    });

    const text = response.content[0].type === "text" ? response.content[0].text : "";
    // Extract JSON from response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        summary: parsed.summary ?? "No summary generated.",
        petReaction: parsed.petReaction ?? `${petName} watches quietly.`,
      };
    }
  } catch (error) {
    // If API call fails, generate a basic summary without LLM
    const summaryParts: string[] = [];
    if (stats.totalCodingMinutes > 0) {
      summaryParts.push(`Coded for ~${stats.totalCodingMinutes} minutes`);
    }
    if (stats.commits > 0) {
      summaryParts.push(`made ${stats.commits} commit${stats.commits > 1 ? "s" : ""}`);
    }
    if (stats.errorsFixed > 0) {
      summaryParts.push(`fixed ${stats.errorsFixed} error${stats.errorsFixed > 1 ? "s" : ""}`);
    }
    if (stats.linesAdded > 0) {
      summaryParts.push(`added ${stats.linesAdded} lines`);
    }

    const fallbackSummary =
      summaryParts.length > 0
        ? summaryParts.join(", ") + "."
        : "A quiet day — no coding activity tracked.";

    return {
      summary: fallbackSummary,
      petReaction: `${petName} is here whenever you're ready to code!`,
    };
  }

  return {
    summary: "Summary generation failed.",
    petReaction: `${petName} tilts head curiously.`,
  };
}

function todayString(): string {
  return new Date().toISOString().split("T")[0];
}

export function registerGenerateDailySummary(
  server: McpServer,
  logger: SessionLogger
): void {
  server.tool(
    "generate_daily_summary",
    "Generate an LLM-powered daily coding summary with pet reaction. Aggregates session events, computes stats, and produces a natural language summary.",
    {
      date: z
        .string()
        .optional()
        .describe("Date to summarize (YYYY-MM-DD format, default: today)"),
      force: z
        .boolean()
        .optional()
        .describe("Force regeneration even if a cached summary exists (default: false)"),
    },
    async ({ date, force }) => {
      const targetDate = date ?? todayString();

      // Check for cached summary
      if (!force) {
        const cached = logger.getDailySummary(targetDate);
        if (cached) {
          logger.logEvent({
            type: "tool_call",
            action: "generate_daily_summary",
            metadata: { date: targetDate, cached: true },
          });

          return {
            content: [
              {
                type: "text" as const,
                text: JSON.stringify(
                  { ...cached, source: "cached" },
                  null,
                  2
                ),
              },
            ],
          };
        }
      }

      // Gather events
      const events = logger.getEventsForDate(targetDate);

      if (events.length === 0) {
        const emptySummary: DailySummary = {
          date: targetDate,
          totalCodingMinutes: 0,
          linesAdded: 0,
          linesRemoved: 0,
          commits: 0,
          aiSessions: 0,
          errorsFixed: 0,
          languageBreakdown: {},
          skillsTracked: {},
          topFiles: [],
          petReaction: "No coding activity today — your pet is napping!",
        };

        logger.saveDailySummary(emptySummary);

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify(
                { ...emptySummary, source: "generated", note: "No events found for this date." },
                null,
                2
              ),
            },
          ],
        };
      }

      // Compute raw stats
      const stats = computeRawStats(events);

      // Get pet info from profile
      const profile = logger.getProfileValue<{
        petName?: string;
        petCharacter?: string;
      }>("user_profile");
      const petName = profile?.petName ?? "Nova";
      const petCharacter = profile?.petCharacter ?? "nova";

      // Generate LLM summary
      const { summary: narrativeSummary, petReaction } =
        await generateSummaryWithLLM(stats, targetDate, petCharacter, petName);

      // Build and save the summary
      const dailySummary: DailySummary = {
        date: targetDate,
        totalCodingMinutes: stats.totalCodingMinutes,
        linesAdded: stats.linesAdded,
        linesRemoved: stats.linesRemoved,
        commits: stats.commits,
        aiSessions: stats.aiSessions,
        errorsFixed: stats.errorsFixed,
        languageBreakdown: stats.languageBreakdown,
        skillsTracked: stats.skillsTracked,
        topFiles: stats.topFiles,
        petReaction,
      };

      logger.saveDailySummary(dailySummary);

      // Log the event
      logger.logEvent({
        type: "tool_call",
        action: "generate_daily_summary",
        metadata: {
          date: targetDate,
          cached: false,
          totalEvents: events.length,
          codingMinutes: stats.totalCodingMinutes,
        },
      });

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(
              {
                ...dailySummary,
                narrativeSummary,
                source: "generated",
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
