#!/usr/bin/env node

/**
 * Codepet MCP Server — Phase 3
 *
 * A local MCP server that captures coding context and tracks developer sessions.
 * Compatible with Claude Code, Cursor, VS Code, Windsurf, and any MCP client.
 *
 * Tools (Phase 1):
 *   - scan_project      → project fingerprint (languages, structure, frameworks)
 *   - get_git_context    → recent commits, diffs, branch info, stats
 *   - get_diagnostics    → compiler errors, lint warnings from project tooling
 *
 * Tools (Phase 2):
 *   - get_file_content   → read file with language detection and metadata
 *   - get_learning_context → aggregated learning progress, error patterns, skill mapping
 *
 * Resources (Phase 1):
 *   - codepet://project/summary   → cached project overview
 *   - codepet://user/profile      → persistent user/pet profile
 *   - codepet://missions/active   → contextual learning missions
 *
 * Resources (Phase 2):
 *   - codepet://skills/progress   → skill tree progress from coding activity
 *
 * Tools (Phase 3):
 *   - generate_daily_summary → LLM-powered daily summary with pet reaction
 *
 * Resources (Phase 3):
 *   - codepet://summary/today     → today's daily summary
 *
 * Session Logger:
 *   Every tool call is logged to ~/.codepet/ as JSON for daily summaries.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerTools } from "./tools/index.js";
import { registerResources } from "./resources/index.js";
import { SessionLogger } from "./logger/session-logger.js";

async function main() {
  const server = new McpServer({
    name: "codepet-mcp-server",
    version: "0.3.0",
  });

  // Initialize the session logger (SQLite)
  const logger = new SessionLogger();

  // Register all tools
  registerTools(server, logger);

  // Register all resources
  registerResources(server, logger);

  // Connect via stdio transport
  const transport = new StdioServerTransport();
  await server.connect(transport);

  // Log server start
  logger.logEvent({
    type: "server",
    action: "start",
    metadata: { version: "0.3.0", transport: "stdio" },
  });

  console.error("[codepet-mcp] Server started successfully");
}

main().catch((error) => {
  console.error("[codepet-mcp] Fatal error:", error);
  process.exit(1);
});
