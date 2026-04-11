/**
 * get_git_context — Git Activity & Context Tool
 *
 * Retrieves recent commits, branch info, diffs, and stats from a git repo.
 * This is the primary data source for daily summaries ("what you built today").
 *
 * Data captured → session logger:
 *   - Commit count, lines added/removed
 *   - Active branch and recent branch switches
 *   - Commit messages and timestamps
 *   - Files changed per commit
 */

import { z } from "zod";
import { resolve } from "node:path";
import { existsSync } from "node:fs";
import { simpleGit, type SimpleGit, type LogResult, type DiffResult } from "simple-git";
import type { SessionLogger } from "../logger/session-logger.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

interface GitContext {
  repository: {
    path: string;
    branch: string;
    remoteBranch?: string;
    isClean: boolean;
    hasUnpushedCommits: boolean;
  };
  recentCommits: Array<{
    hash: string;
    shortHash: string;
    message: string;
    author: string;
    date: string;
    filesChanged: number;
  }>;
  stats: {
    totalCommits: number;
    linesAdded: number;
    linesRemoved: number;
    filesChanged: number;
    uniqueAuthors: string[];
  };
  uncommittedChanges: {
    staged: string[];
    unstaged: string[];
    untracked: string[];
  };
  activity: {
    timeRange: string;
    commitsByHour: Record<string, number>;
    topFiles: Array<{ file: string; changes: number }>;
  };
}

async function getGitContext(
  git: SimpleGit,
  repoPath: string,
  since: string,
  maxCommits: number
): Promise<GitContext> {
  // Current branch
  const branchSummary = await git.branch();
  const currentBranch = branchSummary.current;

  // Status
  const status = await git.status();

  // Recent commits
  const logOptions = [
    `--since=${since}`,
    `--max-count=${maxCommits}`,
    "--format=%H|%h|%s|%an|%aI|%N",
  ];

  let commits: Array<{
    hash: string;
    shortHash: string;
    message: string;
    author: string;
    date: string;
    filesChanged: number;
  }> = [];

  try {
    const log: LogResult = await git.log({
      maxCount: maxCommits,
      "--since": since,
    });

    for (const entry of log.all) {
      // Get per-commit stats
      let filesChanged = 0;
      try {
        const diffStat = await git.diff([
          `${entry.hash}~1..${entry.hash}`,
          "--stat",
        ]);
        filesChanged = (diffStat.match(/\d+ file/)?.[0] ?? "0").replace(
          / file/,
          ""
        ) as unknown as number;
      } catch {
        // First commit or other edge case
      }

      commits.push({
        hash: entry.hash,
        shortHash: entry.hash.substring(0, 7),
        message: entry.message,
        author: entry.author_name,
        date: entry.date,
        filesChanged: Number(filesChanged) || 0,
      });
    }
  } catch {
    // No commits in range or other error
  }

  // Diff stats for the time range
  let linesAdded = 0;
  let linesRemoved = 0;
  let totalFilesChanged = 0;
  const fileChangeCounts = new Map<string, number>();

  try {
    const diffNumstat = await git.diff([
      `HEAD~${Math.min(commits.length, maxCommits)}..HEAD`,
      "--numstat",
    ]);

    for (const line of diffNumstat.split("\n").filter(Boolean)) {
      const [added, removed, file] = line.split("\t");
      if (file && added !== "-") {
        const a = parseInt(added, 10) || 0;
        const r = parseInt(removed, 10) || 0;
        linesAdded += a;
        linesRemoved += r;
        totalFilesChanged++;
        fileChangeCounts.set(file, (fileChangeCounts.get(file) ?? 0) + a + r);
      }
    }
  } catch {
    // Fallback if diff fails
  }

  // Unique authors
  const uniqueAuthors = [...new Set(commits.map((c) => c.author))];

  // Commits by hour
  const commitsByHour: Record<string, number> = {};
  for (const c of commits) {
    const hour = new Date(c.date).getHours().toString().padStart(2, "0") + ":00";
    commitsByHour[hour] = (commitsByHour[hour] ?? 0) + 1;
  }

  // Top files by changes
  const topFiles = Array.from(fileChangeCounts.entries())
    .map(([file, changes]) => ({ file, changes }))
    .sort((a, b) => b.changes - a.changes)
    .slice(0, 10);

  // Check for unpushed commits
  let hasUnpushedCommits = false;
  try {
    const remoteBranch = `origin/${currentBranch}`;
    const unpushed = await git.log([`${remoteBranch}..HEAD`]);
    hasUnpushedCommits = unpushed.total > 0;
  } catch {
    // No remote tracking branch
  }

  return {
    repository: {
      path: repoPath,
      branch: currentBranch,
      isClean: status.isClean(),
      hasUnpushedCommits,
    },
    recentCommits: commits,
    stats: {
      totalCommits: commits.length,
      linesAdded,
      linesRemoved,
      filesChanged: totalFilesChanged,
      uniqueAuthors,
    },
    uncommittedChanges: {
      staged: status.staged,
      unstaged: status.modified,
      untracked: status.not_added,
    },
    activity: {
      timeRange: since,
      commitsByHour,
      topFiles,
    },
  };
}

export function registerGetGitContext(server: McpServer, logger: SessionLogger): void {
  server.tool(
    "get_git_context",
    "Get git repository context including recent commits, branch info, diff stats, and activity patterns. Powers daily summaries of what the user built.",
    {
      path: z
        .string()
        .describe("Absolute path to the git repository root"),
      since: z
        .string()
        .optional()
        .default("24 hours ago")
        .describe("Time range for commit history (e.g., '24 hours ago', '7 days ago', '2026-04-07')"),
      maxCommits: z
        .number()
        .optional()
        .default(50)
        .describe("Maximum number of commits to retrieve (default: 50)"),
    },
    async ({ path: repoPath, since, maxCommits }) => {
      const fullPath = resolve(repoPath);

      if (!existsSync(fullPath)) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({ error: `Path does not exist: ${fullPath}` }),
            },
          ],
        };
      }

      const git: SimpleGit = simpleGit(fullPath);

      // Verify it's a git repo
      const isRepo = await git.checkIsRepo();
      if (!isRepo) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({ error: `Not a git repository: ${fullPath}` }),
            },
          ],
        };
      }

      const context = await getGitContext(
        git,
        fullPath,
        since ?? "24 hours ago",
        maxCommits ?? 50
      );

      // Log to session logger
      logger.logEvent({
        type: "tool_call",
        action: "get_git_context",
        project: fullPath.split("/").pop(),
        metadata: {
          branch: context.repository.branch,
          commits: context.stats.totalCommits,
          linesAdded: context.stats.linesAdded,
          linesRemoved: context.stats.linesRemoved,
          filesChanged: context.stats.filesChanged,
        },
      });

      // Also log each commit as a separate git event (for timeline)
      for (const commit of context.recentCommits) {
        logger.logEvent({
          type: "git",
          action: "commit",
          project: fullPath.split("/").pop(),
          metadata: {
            hash: commit.shortHash,
            message: commit.message,
            author: commit.author,
            filesChanged: commit.filesChanged,
          },
        });
      }

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(context, null, 2),
          },
        ],
      };
    }
  );
}
