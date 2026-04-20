/**
 * Resource Registry — registers all MCP resources
 *
 * Resources are read-only endpoints that AI clients can subscribe to
 * for ongoing context. Unlike tools (which are invoked), resources
 * are data the client can pull at any time.
 *
 * Phase 1 resources:
 *   codepet://project/summary   → last scan_project result
 *   codepet://user/profile      → pet name, skills, streak, preferences
 *   codepet://missions/active   → current learning missions based on activity
 *
 * Phase 2 resources:
 *   codepet://skills/progress   → skill tree progress mapped from coding activity
 *
 * Phase 3 resources:
 *   codepet://summary/today     → today's daily summary with pet reaction
 */

import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { SessionLogger } from "../logger/session-logger.js";
import { mapActivityToSkills, SKILL_TREE } from "../skills/skill-map.js";

interface UserProfile {
  petName: string;
  petCharacter: string;
  level: number;
  streak: number;
  totalCodingHours: number;
  skills: Record<string, number>;
  joinedDate: string;
}

interface Mission {
  id: string;
  title: string;
  description: string;
  type: "daily" | "weekly" | "skill";
  progress: number;
  target: number;
  reward: { coins: number; xp: number };
  kingdom?: string;
}

function generateMissions(logger: SessionLogger): Mission[] {
  const todayEvents = logger.getEventsForDate();
  const stats = logger.getEventStats();

  const missions: Mission[] = [];

  // Daily mission: commit streak
  const gitEvents = todayEvents.filter((e) => e.type === "git");
  missions.push({
    id: "daily_commits",
    title: "Ship It!",
    description: "Make at least 3 commits today",
    type: "daily",
    progress: Math.min(gitEvents.length, 3),
    target: 3,
    reward: { coins: 10, xp: 25 },
  });

  // Daily mission: fix errors
  const errorFixed = todayEvents.filter(
    (e) => e.type === "diagnostic" && e.action === "clean"
  );
  missions.push({
    id: "daily_bugfix",
    title: "Bug Squasher",
    description: "Resolve all compiler errors in a diagnostic run",
    type: "daily",
    progress: errorFixed.length > 0 ? 1 : 0,
    target: 1,
    reward: { coins: 15, xp: 30 },
  });

  // Weekly mission: explore files
  const fileEvents = todayEvents.filter(
    (e) => e.type === "tool_call" && e.action === "get_file_content"
  );
  const uniqueFiles = new Set(fileEvents.map((e) => e.file).filter(Boolean));
  missions.push({
    id: "weekly_explore",
    title: "Code Explorer",
    description: "Work with files across 5 different directories this week",
    type: "weekly",
    progress: Math.min(uniqueFiles.size, 5),
    target: 5,
    reward: { coins: 30, xp: 75 },
    kingdom: "Mystic Grove",
  });

  // Skill mission: based on error patterns
  const learningEvents = todayEvents.filter((e) => e.type === "learning");
  missions.push({
    id: "skill_debug",
    title: "Debugging Apprentice",
    description: "Encounter and resolve 5 different error types",
    type: "skill",
    progress: Math.min(learningEvents.length, 5),
    target: 5,
    reward: { coins: 25, xp: 50 },
    kingdom: "Molten Forge",
  });

  return missions;
}

export function registerResources(server: McpServer, logger: SessionLogger): void {
  // ───── codepet://project/summary ─────
  server.resource(
    "project-summary",
    "codepet://project/summary",
    {
      description:
        "Cached project fingerprint from the last scan_project call. Includes languages, frameworks, structure, and dependencies.",
      mimeType: "application/json",
    },
    async () => {
      const lastScan = logger.getProfileValue("last_project_scan");

      // Log resource access
      logger.logEvent({
        type: "resource_access",
        action: "project_summary",
      });

      if (!lastScan) {
        return {
          contents: [
            {
              uri: "codepet://project/summary",
              mimeType: "application/json",
              text: JSON.stringify({
                status: "no_scan",
                message:
                  "No project has been scanned yet. Call the scan_project tool first.",
              }),
            },
          ],
        };
      }

      return {
        contents: [
          {
            uri: "codepet://project/summary",
            mimeType: "application/json",
            text: JSON.stringify(lastScan, null, 2),
          },
        ],
      };
    }
  );

  // ───── codepet://user/profile ─────
  server.resource(
    "user-profile",
    "codepet://user/profile",
    {
      description:
        "User's Codepet profile including pet info, level, streak, skills, and coding stats.",
      mimeType: "application/json",
    },
    async () => {
      let profile = logger.getProfileValue<UserProfile>("user_profile");

      // Log resource access
      logger.logEvent({
        type: "resource_access",
        action: "user_profile",
      });

      if (!profile) {
        // Create default profile
        profile = {
          petName: "Nova",
          petCharacter: "nova",
          level: 1,
          streak: 0,
          totalCodingHours: 0,
          skills: {},
          joinedDate: new Date().toISOString().split("T")[0],
        };
        logger.setProfileValue("user_profile", profile);
      }

      // Enrich with today's stats
      const todayEvents = logger.getEventsForDate();
      const enriched = {
        ...profile,
        today: {
          events: todayEvents.length,
          toolCalls: todayEvents.filter((e) => e.type === "tool_call").length,
          gitActions: todayEvents.filter((e) => e.type === "git").length,
          diagnosticRuns: todayEvents.filter((e) => e.type === "diagnostic").length,
          learningMoments: todayEvents.filter((e) => e.type === "learning").length,
        },
      };

      return {
        contents: [
          {
            uri: "codepet://user/profile",
            mimeType: "application/json",
            text: JSON.stringify(enriched, null, 2),
          },
        ],
      };
    }
  );

  // ───── codepet://missions/active ─────
  server.resource(
    "active-missions",
    "codepet://missions/active",
    {
      description:
        "Active learning missions generated from the user's coding activity. Missions are contextual goals tied to Codepet's skill tree and kingdoms.",
      mimeType: "application/json",
    },
    async () => {
      // Log resource access
      logger.logEvent({
        type: "resource_access",
        action: "active_missions",
      });

      const missions = generateMissions(logger);

      return {
        contents: [
          {
            uri: "codepet://missions/active",
            mimeType: "application/json",
            text: JSON.stringify(
              {
                generatedAt: new Date().toISOString(),
                missions,
                completedToday: missions.filter((m) => m.progress >= m.target)
                  .length,
                totalActive: missions.length,
              },
              null,
              2
            ),
          },
        ],
      };
    }
  );

  // ───── codepet://skills/progress ─────
  server.resource(
    "skills-progress",
    "codepet://skills/progress",
    {
      description:
        "Skill tree progress mapped from coding activity. Shows XP, level, and progress for all 16 skills across 4 kingdoms.",
      mimeType: "application/json",
    },
    async () => {
      // Log resource access
      logger.logEvent({
        type: "resource_access",
        action: "skills_progress",
      });

      // Gather last 7 days of events for skill mapping
      const allEvents = [];
      const now = new Date();
      for (let i = 0; i < 7; i++) {
        const d = new Date(now);
        d.setDate(d.getDate() - i);
        const date = d.toISOString().split("T")[0];
        allEvents.push(...logger.getEventsForDate(date));
      }

      const skills = mapActivityToSkills(allEvents);

      // Group by kingdom
      const kingdoms = new Map<string, typeof skills>();
      for (const skill of skills) {
        if (!kingdoms.has(skill.kingdom)) {
          kingdoms.set(skill.kingdom, []);
        }
        kingdoms.get(skill.kingdom)!.push(skill);
      }

      const totalXP = skills.reduce((sum, s) => sum + s.xp, 0);
      const avgLevel =
        skills.length > 0
          ? skills.reduce((sum, s) => sum + s.level, 0) / skills.length
          : 0;

      return {
        contents: [
          {
            uri: "codepet://skills/progress",
            mimeType: "application/json",
            text: JSON.stringify(
              {
                generatedAt: new Date().toISOString(),
                period: "last 7 days",
                totalXP,
                averageLevel: Math.round(avgLevel * 10) / 10,
                kingdoms: Object.fromEntries(kingdoms),
                skills,
              },
              null,
              2
            ),
          },
        ],
      };
    }
  );

  // ───── codepet://summary/today ─────
  server.resource(
    "daily-summary",
    "codepet://summary/today",
    {
      description:
        "Today's daily coding summary with stats and pet reaction. Call generate_daily_summary tool first to create it.",
      mimeType: "application/json",
    },
    async () => {
      logger.logEvent({
        type: "resource_access",
        action: "daily_summary",
      });

      const summary = logger.getDailySummary();

      if (!summary) {
        return {
          contents: [
            {
              uri: "codepet://summary/today",
              mimeType: "application/json",
              text: JSON.stringify({
                status: "not_generated",
                message:
                  "No summary for today yet. Call the generate_daily_summary tool to create one.",
              }),
            },
          ],
        };
      }

      return {
        contents: [
          {
            uri: "codepet://summary/today",
            mimeType: "application/json",
            text: JSON.stringify(summary, null, 2),
          },
        ],
      };
    }
  );
}
