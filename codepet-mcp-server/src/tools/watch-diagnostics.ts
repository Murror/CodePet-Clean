/**
 * watch_diagnostics & auto_fix — Real-time diagnostic tools
 *
 * These MCP tools expose the DiagnosticWatcher and AutoFixEngine
 * to any MCP-compliant client (Claude Code, Cursor, VS Code, etc.)
 *
 * Tools:
 *   - watch_diagnostics: Start/stop/query the real-time file watcher
 *   - auto_fix: Attempt to fix a specific error (pattern-based or AI-assisted)
 */

import { z } from "zod";
import { resolve, basename } from "node:path";
import { existsSync } from "node:fs";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { SessionLogger } from "../logger/session-logger.js";
import { DiagnosticWatcher, type DiagnosticEvent, type Diagnostic } from "../watcher/diagnostic-watcher.js";
import { AutoFixEngine, type FixResult } from "../watcher/auto-fix-engine.js";

// Singleton watcher (one per server instance)
let activeWatcher: DiagnosticWatcher | null = null;
const recentEvents: DiagnosticEvent[] = []; // ring buffer of last 50 events
const MAX_EVENTS = 50;

const fixEngine = new AutoFixEngine();

function pushEvent(event: DiagnosticEvent): void {
  recentEvents.unshift(event);
  if (recentEvents.length > MAX_EVENTS) recentEvents.pop();
}

export function registerWatchDiagnostics(server: McpServer, logger: SessionLogger): void {
  // ───── Tool 1: watch_diagnostics ─────
  server.tool(
    "watch_diagnostics",
    `Real-time diagnostic watcher — monitors your project for errors as you code.
Start the watcher, query current errors, or get a full scan.

Actions:
  - "start": Begin watching a project directory for file changes
  - "stop": Stop the watcher
  - "status": Get current watcher state and recent errors
  - "scan": Run a one-time full diagnostic scan (no persistent watching)

Works with: TypeScript, Swift, Python, ESLint, and any language with a CLI linter.
Platform-agnostic: works with any editor that saves to disk.`,
    {
      action: z
        .enum(["start", "stop", "status", "scan"])
        .describe("What to do: start watching, stop watching, check status, or run a one-time scan"),
      path: z
        .string()
        .optional()
        .describe("Absolute path to the project root (required for 'start' and 'scan')"),
      file: z
        .string()
        .optional()
        .describe("Optional: get diagnostics for a specific file only (with 'status')"),
    },
    async ({ action, path: projectPath, file }) => {
      // ── START ──
      if (action === "start") {
        if (!projectPath) {
          return text({ error: "Path is required to start the watcher" });
        }
        const rootPath = resolve(projectPath);
        if (!existsSync(rootPath)) {
          return text({ error: `Path does not exist: ${rootPath}` });
        }

        // Stop existing watcher if any
        if (activeWatcher) {
          activeWatcher.stop();
        }

        activeWatcher = new DiagnosticWatcher({ rootPath });

        // Subscribe to events
        activeWatcher.on("diagnostics", (event: DiagnosticEvent) => {
          pushEvent(event);

          // Log to session logger for learning tracking
          if (event.newErrors.length > 0) {
            logger.logEvent({
              type: "diagnostic",
              action: "realtime_error_detected",
              project: basename(rootPath),
              file: event.file,
              language: event.language,
              metadata: {
                newErrors: event.newErrors.length,
                totalErrors: event.totalErrors,
                errors: event.newErrors.map((e) => ({
                  message: e.message,
                  code: e.code,
                  line: e.line,
                  fixable: e.fixable,
                })),
              },
            });
          }

          if (event.resolvedErrors.length > 0) {
            logger.logEvent({
              type: "diagnostic",
              action: "realtime_error_resolved",
              project: basename(rootPath),
              file: event.file,
              language: event.language,
              metadata: {
                resolvedErrors: event.resolvedErrors.length,
                remainingErrors: event.totalErrors,
              },
            });
          }
        });

        activeWatcher.start();

        // Run initial full scan
        const events = await activeWatcher.runFullScan();
        const totalErrors = events.reduce((sum, e) => sum + e.totalErrors, 0);
        const totalWarnings = events.reduce((sum, e) => sum + e.totalWarnings, 0);

        return text({
          status: "watching",
          rootPath,
          initialScan: {
            filesScanned: events.length,
            totalErrors,
            totalWarnings,
          },
          message: totalErrors === 0
            ? "All clear! I'll keep an eye on things as you code."
            : `Found ${totalErrors} error(s) and ${totalWarnings} warning(s). I'll track them in real-time.`,
        });
      }

      // ── STOP ──
      if (action === "stop") {
        if (activeWatcher) {
          activeWatcher.stop();
          activeWatcher = null;
          return text({ status: "stopped", message: "Watcher stopped. I'll rest my eyes too." });
        }
        return text({ status: "not_running", message: "No watcher is currently active." });
      }

      // ── STATUS ──
      if (action === "status") {
        if (!activeWatcher) {
          return text({
            status: "not_running",
            recentEvents: recentEvents.slice(0, 10),
            message: "No watcher is running. Use action: 'start' to begin.",
          });
        }

        if (file) {
          const fileDiags = activeWatcher.getDiagnosticsForFile(resolve(file));
          return text({
            status: "watching",
            file,
            diagnostics: fileDiags,
            totalErrors: fileDiags.filter((d) => d.severity === "error").length,
            totalWarnings: fileDiags.filter((d) => d.severity === "warning").length,
          });
        }

        const allDiags = activeWatcher.getAllDiagnostics();
        const errors = allDiags.filter((d) => d.severity === "error");
        const warnings = allDiags.filter((d) => d.severity === "warning");
        const fixable = allDiags.filter((d) => d.fixable);

        return text({
          status: "watching",
          totalErrors: errors.length,
          totalWarnings: warnings.length,
          fixableErrors: fixable.length,
          recentEvents: recentEvents.slice(0, 10),
          errors: errors.slice(0, 20), // Top 20 errors
          message: errors.length === 0
            ? "Everything looks clean right now!"
            : `${errors.length} error(s) active. ${fixable.length} can be auto-fixed.`,
        });
      }

      // ── SCAN ──
      if (action === "scan") {
        if (!projectPath) {
          return text({ error: "Path is required for a scan" });
        }
        const rootPath = resolve(projectPath);
        if (!existsSync(rootPath)) {
          return text({ error: `Path does not exist: ${rootPath}` });
        }

        const tempWatcher = new DiagnosticWatcher({ rootPath });
        tempWatcher.start();
        const events = await tempWatcher.runFullScan();
        tempWatcher.stop();

        const allDiags = events.flatMap((e) => e.diagnostics);
        const errors = allDiags.filter((d) => d.severity === "error");
        const warnings = allDiags.filter((d) => d.severity === "warning");
        const fixable = allDiags.filter((d) => d.fixable);

        logger.logEvent({
          type: "diagnostic",
          action: "full_scan",
          project: basename(rootPath),
          metadata: {
            errors: errors.length,
            warnings: warnings.length,
            fixable: fixable.length,
            filesAffected: [...new Set(allDiags.map((d) => d.file))].length,
          },
        });

        return text({
          project: basename(rootPath),
          totalErrors: errors.length,
          totalWarnings: warnings.length,
          fixableErrors: fixable.length,
          diagnostics: allDiags.slice(0, 30),
          message: errors.length === 0
            ? "Clean scan — no errors found!"
            : `Found ${errors.length} error(s). ${fixable.length} can be auto-fixed.`,
        });
      }

      return text({ error: `Unknown action: ${action}` });
    }
  );

  // ───── Tool 2: auto_fix ─────
  server.tool(
    "auto_fix",
    `Attempt to automatically fix a coding error detected by the diagnostic watcher.

Byte will try a pattern-based fix first (fast, no AI needed).
If the error is too complex, Byte returns a structured AI fix request
that can be sent to Claude for an intelligent fix.

Modes:
  - "suggest": Show the fix without applying it (default, safe)
  - "apply": Apply the fix directly to the file (use with care)
  - "apply_all": Fix all auto-fixable errors in the project`,
    {
      mode: z
        .enum(["suggest", "apply", "apply_all"])
        .optional()
        .default("suggest")
        .describe("Fix mode: suggest (preview), apply (write to file), or apply_all"),
      file: z
        .string()
        .optional()
        .describe("File path to fix errors in (required for suggest/apply)"),
      line: z
        .number()
        .optional()
        .describe("Specific line number to fix (optional, fixes first error if omitted)"),
    },
    async ({ mode, file, line }) => {
      // ── APPLY ALL ──
      if (mode === "apply_all") {
        if (!activeWatcher) {
          return text({ error: "No watcher is running. Start one first with watch_diagnostics." });
        }

        const allDiags = activeWatcher.getAllDiagnostics();
        const fixable = allDiags.filter((d) => d.fixable);

        if (fixable.length === 0) {
          return text({
            message: "No auto-fixable errors found. Everything's looking good!",
            totalErrors: allDiags.filter((d) => d.severity === "error").length,
          });
        }

        const results: FixResult[] = [];
        for (const diag of fixable) {
          const result = fixEngine.apply(diag);
          results.push(result);

          if (result.applied) {
            logger.logEvent({
              type: "diagnostic",
              action: "auto_fix_applied",
              file: diag.file,
              metadata: {
                message: diag.message,
                code: diag.code,
                fix: result.fix?.description,
              },
            });
          }
        }

        const applied = results.filter((r) => r.applied);
        const failed = results.filter((r) => !r.applied);

        return text({
          totalFixable: fixable.length,
          applied: applied.length,
          failed: failed.length,
          fixes: results.map((r) => ({
            file: r.diagnostic.file,
            line: r.diagnostic.line,
            error: r.diagnostic.message,
            fixed: r.applied,
            fix: r.fix?.description,
            petReaction: r.petReaction,
          })),
          message: applied.length > 0
            ? `Fixed ${applied.length} error(s)! ${failed.length > 0 ? `${failed.length} need manual attention.` : "All clean!"}`
            : "Couldn't apply any fixes automatically. They might need a closer look.",
        });
      }

      // ── SUGGEST / APPLY single ──
      if (!file) {
        return text({ error: "File path is required for suggest/apply mode" });
      }

      const filePath = resolve(file);

      // Get diagnostics for this file
      let diagnostics: Diagnostic[];
      if (activeWatcher) {
        diagnostics = activeWatcher.getDiagnosticsForFile(filePath);
      } else {
        return text({ error: "No watcher running. Start one with watch_diagnostics first." });
      }

      if (diagnostics.length === 0) {
        return text({
          file,
          message: "No errors in this file — nice work!",
          petReaction: "This file is sparkling clean!",
        });
      }

      // Find the specific diagnostic to fix
      let target: Diagnostic;
      if (line) {
        const atLine = diagnostics.find((d) => d.line === line);
        if (!atLine) {
          return text({
            error: `No diagnostic found at line ${line}`,
            availableErrors: diagnostics.map((d) => ({ line: d.line, message: d.message })),
          });
        }
        target = atLine;
      } else {
        // Fix the first error (prioritize errors over warnings)
        target = diagnostics.find((d) => d.severity === "error") ?? diagnostics[0];
      }

      const result = mode === "apply"
        ? fixEngine.apply(target)
        : fixEngine.suggest(target);

      if (result.applied) {
        logger.logEvent({
          type: "diagnostic",
          action: "auto_fix_applied",
          file: target.file,
          metadata: {
            message: target.message,
            code: target.code,
            line: target.line,
            fix: result.fix?.description,
          },
        });
      }

      return text({
        file,
        line: target.line,
        error: {
          severity: target.severity,
          message: target.message,
          code: target.code,
          source: target.source,
        },
        fix: result.fix ? {
          description: result.fix.description,
          confidence: result.fix.confidence,
          replacement: result.fix.replacement,
          applied: result.applied,
        } : null,
        aiFixRequest: result.aiFixRequest ?? null,
        petReaction: result.petReaction,
        remainingErrors: diagnostics.length - (result.applied ? 1 : 0),
      });
    }
  );
}

// Helper to format MCP text responses
function text(data: Record<string, unknown>) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }],
  };
}
