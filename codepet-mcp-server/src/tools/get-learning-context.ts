/**
 * get_learning_context — Learning Progress Aggregator
 *
 * Aggregates learning data from session events to build a picture of
 * the developer's coding journey: error patterns they've encountered,
 * skills they're practicing, languages they're using, and progress
 * mapped to Codepet's skill tree.
 *
 * Data captured → session logger:
 *   - Learning context retrieval event
 *   - Skill mapping updates
 */

import { z } from "zod";
import type { SessionLogger, StoredEvent } from "../logger/session-logger.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { SKILL_TREE, mapActivityToSkills, type SkillProgress } from "../skills/skill-map.js";

interface ErrorPattern {
  code: string;
  message: string;
  count: number;
  lastSeen: string;
  resolved: boolean;
}

interface LanguageActivity {
  language: string;
  filesAccessed: number;
  diagnosticRuns: number;
  errorsEncountered: number;
}

interface LearningContext {
  period: { from: string; to: string; days: number };
  activity: {
    totalEvents: number;
    toolCalls: number;
    gitActions: number;
    diagnosticRuns: number;
    learningMoments: number;
    filesExplored: number;
  };
  errorPatterns: ErrorPattern[];
  languages: LanguageActivity[];
  skills: SkillProgress[];
  streaks: {
    currentStreak: number;
    longestStreak: number;
    activeDays: string[];
  };
  recommendations: string[];
}

function getDateRange(days: number): string[] {
  const dates: string[] = [];
  const now = new Date();
  for (let i = 0; i < days; i++) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    dates.push(d.toISOString().split("T")[0]);
  }
  return dates;
}

function buildErrorPatterns(events: StoredEvent[]): ErrorPattern[] {
  const patterns = new Map<
    string,
    { code: string; message: string; count: number; lastSeen: string; resolved: boolean }
  >();

  for (const event of events) {
    if (event.type === "learning" && event.action === "error_encountered") {
      const code = (event.metadata?.code as string) ?? "unknown";
      const message = (event.metadata?.message as string) ?? event.action;
      const key = `${code}:${message}`;

      const existing = patterns.get(key);
      if (existing) {
        existing.count++;
        existing.lastSeen = event.timestamp;
      } else {
        patterns.set(key, {
          code,
          message,
          count: 1,
          lastSeen: event.timestamp,
          resolved: false,
        });
      }
    }

    // Mark errors as resolved when a clean diagnostic follows
    if (event.type === "diagnostic" && event.action === "clean") {
      for (const pattern of patterns.values()) {
        if (!pattern.resolved && pattern.lastSeen < event.timestamp) {
          pattern.resolved = true;
        }
      }
    }
  }

  return Array.from(patterns.values()).sort((a, b) => b.count - a.count);
}

function buildLanguageActivity(events: StoredEvent[]): LanguageActivity[] {
  const languages = new Map<
    string,
    { filesAccessed: number; diagnosticRuns: number; errorsEncountered: number }
  >();

  for (const event of events) {
    const lang = event.language;
    if (!lang) continue;

    if (!languages.has(lang)) {
      languages.set(lang, { filesAccessed: 0, diagnosticRuns: 0, errorsEncountered: 0 });
    }
    const entry = languages.get(lang)!;

    if (event.type === "tool_call" && event.action === "get_file_content") {
      entry.filesAccessed++;
    }
    if (event.type === "diagnostic") {
      entry.diagnosticRuns++;
      if (event.action === "errors_found") {
        entry.errorsEncountered += (event.metadata?.errors as number) ?? 1;
      }
    }
  }

  return Array.from(languages.entries())
    .map(([language, data]) => ({ language, ...data }))
    .sort((a, b) => b.filesAccessed - a.filesAccessed);
}

function calculateStreaks(activeDays: string[]): {
  currentStreak: number;
  longestStreak: number;
} {
  if (activeDays.length === 0) return { currentStreak: 0, longestStreak: 0 };

  const sorted = [...activeDays].sort();
  let currentStreak = 1;
  let longestStreak = 1;
  let tempStreak = 1;

  // Check if today is active for current streak
  const today = new Date().toISOString().split("T")[0];
  const yesterday = new Date(Date.now() - 86400000).toISOString().split("T")[0];
  const lastActive = sorted[sorted.length - 1];
  const isCurrentlyActive = lastActive === today || lastActive === yesterday;

  for (let i = 1; i < sorted.length; i++) {
    const prev = new Date(sorted[i - 1]);
    const curr = new Date(sorted[i]);
    const diffDays = (curr.getTime() - prev.getTime()) / 86400000;

    if (diffDays === 1) {
      tempStreak++;
      longestStreak = Math.max(longestStreak, tempStreak);
    } else {
      tempStreak = 1;
    }
  }

  // Current streak = streak ending on last active day (only if recent)
  if (isCurrentlyActive) {
    currentStreak = tempStreak;
  } else {
    currentStreak = 0;
  }

  return { currentStreak, longestStreak };
}

function generateRecommendations(
  errorPatterns: ErrorPattern[],
  languages: LanguageActivity[],
  skills: SkillProgress[],
  totalEvents: number
): string[] {
  const recs: string[] = [];

  // Recurring errors
  const recurring = errorPatterns.filter((e) => e.count >= 3 && !e.resolved);
  if (recurring.length > 0) {
    recs.push(
      `You've hit "${recurring[0].message}" ${recurring[0].count} times — the "Error Reading" skill in Molten Forge covers this pattern.`
    );
  }

  // Low-progress skills
  const lowSkills = skills.filter((s) => s.level < 2 && s.xpProgress > 0);
  if (lowSkills.length > 0) {
    recs.push(
      `Keep practicing "${lowSkills[0].name}" — you're ${lowSkills[0].xpToNextLevel} XP from leveling up!`
    );
  }

  // Encourage exploration
  if (languages.length === 1) {
    recs.push(
      "Try exploring a project in a different language to unlock cross-language skills."
    );
  }

  // Low activity
  if (totalEvents < 5) {
    recs.push(
      "Use your AI tools more often — each session earns XP toward your skill tree!"
    );
  }

  // Encourage diagnostics
  const diagRuns = languages.reduce((sum, l) => sum + l.diagnosticRuns, 0);
  if (diagRuns === 0 && totalEvents > 10) {
    recs.push(
      "Try running diagnostics on your project — fixing errors is the fastest way to level up Error Reading."
    );
  }

  return recs;
}

export function registerGetLearningContext(
  server: McpServer,
  logger: SessionLogger
): void {
  server.tool(
    "get_learning_context",
    "Get aggregated learning progress: error patterns, language activity, skill tree progress, streaks, and personalized recommendations.",
    {
      days: z
        .number()
        .int()
        .min(1)
        .max(90)
        .optional()
        .describe("Number of days to look back (default: 7, max: 90)"),
    },
    async ({ days }) => {
      const lookbackDays = days ?? 7;
      const dates = getDateRange(lookbackDays);

      // Gather all events across the date range
      const allEvents: StoredEvent[] = [];
      const activeDays: string[] = [];

      for (const date of dates) {
        const dayEvents = logger.getEventsForDate(date);
        if (dayEvents.length > 0) {
          activeDays.push(date);
          allEvents.push(...dayEvents);
        }
      }

      // Compute aggregates
      const toolCalls = allEvents.filter((e) => e.type === "tool_call").length;
      const gitActions = allEvents.filter((e) => e.type === "git").length;
      const diagnosticRuns = allEvents.filter((e) => e.type === "diagnostic").length;
      const learningMoments = allEvents.filter((e) => e.type === "learning").length;
      const uniqueFiles = new Set(allEvents.filter((e) => e.file).map((e) => e.file)).size;

      const errorPatterns = buildErrorPatterns(allEvents);
      const languages = buildLanguageActivity(allEvents);
      const streakData = calculateStreaks(activeDays);

      // Map activity to skill tree
      const skills = mapActivityToSkills(allEvents);

      // Save skill progress to profile
      logger.setProfileValue("skill_progress", skills);

      const recommendations = generateRecommendations(
        errorPatterns,
        languages,
        skills,
        allEvents.length
      );

      const result: LearningContext = {
        period: {
          from: dates[dates.length - 1],
          to: dates[0],
          days: lookbackDays,
        },
        activity: {
          totalEvents: allEvents.length,
          toolCalls,
          gitActions,
          diagnosticRuns,
          learningMoments,
          filesExplored: uniqueFiles,
        },
        errorPatterns: errorPatterns.slice(0, 10), // Top 10
        languages,
        skills,
        streaks: {
          currentStreak: streakData.currentStreak,
          longestStreak: streakData.longestStreak,
          activeDays: activeDays.sort(),
        },
        recommendations,
      };

      // Log event
      logger.logEvent({
        type: "tool_call",
        action: "get_learning_context",
        metadata: {
          days: lookbackDays,
          totalEvents: allEvents.length,
          activeDays: activeDays.length,
          skillsMapped: skills.length,
        },
      });

      return {
        content: [
          { type: "text" as const, text: JSON.stringify(result, null, 2) },
        ],
      };
    }
  );
}
