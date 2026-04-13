/**
 * Tool Registry — registers all MCP tools
 */

import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { SessionLogger } from "../logger/session-logger.js";
import { registerScanProject } from "./scan-project.js";
import { registerGetGitContext } from "./get-git-context.js";
import { registerGetDiagnostics } from "./get-diagnostics.js";
import { registerGetFileContent } from "./get-file-content.js";
import { registerGetLearningContext } from "./get-learning-context.js";
import { registerGenerateDailySummary } from "./generate-daily-summary.js";
import { registerWatchDiagnostics } from "./watch-diagnostics.js";
import { registerGenerateLessonCard } from "./generate-lesson-card.js";

export function registerTools(server: McpServer, logger: SessionLogger): void {
  // Phase 1
  registerScanProject(server, logger);
  registerGetGitContext(server, logger);
  registerGetDiagnostics(server, logger);

  // Phase 2
  registerGetFileContent(server, logger);
  registerGetLearningContext(server, logger);

  // Phase 3
  registerGenerateDailySummary(server, logger);

  // Phase 4 — Real-time diagnostics & auto-fix
  registerWatchDiagnostics(server, logger);

  // Phase 5 — Lesson Feed (post-session knowledge capture)
  registerGenerateLessonCard(server, logger);
}
