/**
 * get_diagnostics — Error & Warning Capture Tool
 *
 * Scans project for compiler errors, lint warnings, test failures,
 * and other diagnostics. Tracks error→fix patterns over time.
 *
 * Supports:
 *   - TypeScript (tsc --noEmit)
 *   - ESLint / Biome
 *   - Swift (via xcodebuild or swift build)
 *   - Python (pyright / mypy)
 *   - Generic: any command that outputs diagnostics
 *
 * Data captured → session logger:
 *   - Error type and count
 *   - Files with errors
 *   - Resolution tracking (error appeared → error gone)
 */

import { z } from "zod";
import { resolve, join, basename } from "node:path";
import { existsSync } from "node:fs";
import { readFile, readdir } from "node:fs/promises";
import { execSync } from "node:child_process";
import type { SessionLogger } from "../logger/session-logger.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

interface Diagnostic {
  severity: "error" | "warning" | "info";
  message: string;
  file?: string;
  line?: number;
  column?: number;
  source: string; // "tsc", "eslint", "swift", "python", etc.
  code?: string; // Error code like "TS2345" or "E0001"
}

interface DiagnosticsResult {
  project: string;
  toolchain: string;
  timestamp: string;
  diagnostics: Diagnostic[];
  summary: {
    errors: number;
    warnings: number;
    info: number;
    filesAffected: string[];
  };
  previousRun?: {
    errors: number;
    warnings: number;
    resolvedErrors: number;
    newErrors: number;
  };
}

/**
 * Detect which diagnostic tools are available for this project.
 */
async function detectToolchain(rootPath: string): Promise<string> {
  // Check for Swift / Xcode project
  try {
    const entries = await readdir(rootPath);
    if (entries.some((e) => e.endsWith(".xcodeproj") || e.endsWith(".xcworkspace"))) {
      return "swift";
    }
  } catch {
    // Ignore
  }

  if (existsSync(join(rootPath, "Package.swift"))) return "swift";
  if (existsSync(join(rootPath, "tsconfig.json"))) return "typescript";
  if (existsSync(join(rootPath, "pyproject.toml")) || existsSync(join(rootPath, "setup.py")))
    return "python";
  if (existsSync(join(rootPath, "Cargo.toml"))) return "rust";
  if (existsSync(join(rootPath, "go.mod"))) return "go";
  if (existsSync(join(rootPath, "package.json"))) return "typescript"; // fallback for JS projects

  return "unknown";
}

/**
 * Parse TypeScript compiler diagnostics.
 */
function parseTypeScriptDiagnostics(output: string): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];
  const lines = output.split("\n");

  for (const line of lines) {
    // Match: src/file.ts(10,5): error TS2345: Argument of type...
    const match = line.match(
      /^(.+?)\((\d+),(\d+)\):\s+(error|warning)\s+(TS\d+):\s+(.+)$/
    );
    if (match) {
      diagnostics.push({
        severity: match[4] as "error" | "warning",
        file: match[1],
        line: parseInt(match[2], 10),
        column: parseInt(match[3], 10),
        code: match[5],
        message: match[6],
        source: "tsc",
      });
    }
  }

  return diagnostics;
}

/**
 * Parse Swift compiler diagnostics.
 */
function parseSwiftDiagnostics(output: string): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];
  const lines = output.split("\n");

  for (const line of lines) {
    // Match: /path/file.swift:10:5: error: message
    const match = line.match(
      /^(.+?\.swift):(\d+):(\d+):\s+(error|warning|note):\s+(.+)$/
    );
    if (match) {
      diagnostics.push({
        severity: match[4] === "note" ? "info" : (match[4] as "error" | "warning"),
        file: match[1],
        line: parseInt(match[2], 10),
        column: parseInt(match[3], 10),
        message: match[5],
        source: "swift",
      });
    }
  }

  return diagnostics;
}

/**
 * Parse generic diagnostics from any command output.
 */
function parseGenericDiagnostics(output: string): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];
  const lines = output.split("\n");

  for (const line of lines) {
    // Try common patterns
    // file:line:col: severity: message
    const match = line.match(
      /^(.+?):(\d+):(\d+):\s+(error|warning|info|note):\s+(.+)$/
    );
    if (match) {
      diagnostics.push({
        severity: match[4] === "note" ? "info" : (match[4] as "error" | "warning"),
        file: match[1],
        line: parseInt(match[2], 10),
        column: parseInt(match[3], 10),
        message: match[5],
        source: "generic",
      });
    }
  }

  return diagnostics;
}

/**
 * Run diagnostics for a specific toolchain.
 */
function runDiagnosticCommand(
  toolchain: string,
  rootPath: string,
  customCommand?: string
): { output: string; parser: (output: string) => Diagnostic[] } {
  if (customCommand) {
    try {
      const output = execSync(customCommand, {
        cwd: rootPath,
        encoding: "utf-8",
        timeout: 60000,
        stdio: ["pipe", "pipe", "pipe"],
      });
      return { output, parser: parseGenericDiagnostics };
    } catch (err: unknown) {
      // Commands often exit with non-zero when there are errors
      const error = err as { stdout?: string; stderr?: string };
      const output = (error.stdout ?? "") + (error.stderr ?? "");
      return { output, parser: parseGenericDiagnostics };
    }
  }

  const commands: Record<string, { cmd: string; parser: (output: string) => Diagnostic[] }> = {
    typescript: {
      cmd: "npx tsc --noEmit --pretty false 2>&1",
      parser: parseTypeScriptDiagnostics,
    },
    swift: {
      cmd: "swift build 2>&1 || xcodebuild -quiet 2>&1",
      parser: parseSwiftDiagnostics,
    },
    python: {
      cmd: "python -m py_compile **/*.py 2>&1 || pyright 2>&1",
      parser: parseGenericDiagnostics,
    },
    rust: {
      cmd: "cargo check --message-format short 2>&1",
      parser: parseGenericDiagnostics,
    },
    go: {
      cmd: "go vet ./... 2>&1",
      parser: parseGenericDiagnostics,
    },
  };

  const config = commands[toolchain];
  if (!config) {
    return { output: "", parser: parseGenericDiagnostics };
  }

  try {
    const output = execSync(config.cmd, {
      cwd: rootPath,
      encoding: "utf-8",
      timeout: 120000,
      stdio: ["pipe", "pipe", "pipe"],
    });
    return { output, parser: config.parser };
  } catch (err: unknown) {
    const error = err as { stdout?: string; stderr?: string };
    const output = (error.stdout ?? "") + (error.stderr ?? "");
    return { output, parser: config.parser };
  }
}

export function registerGetDiagnostics(server: McpServer, logger: SessionLogger): void {
  server.tool(
    "get_diagnostics",
    "Run project diagnostics to capture compiler errors, lint warnings, and test failures. Tracks error patterns over time to identify struggle points and learning opportunities.",
    {
      path: z
        .string()
        .describe("Absolute path to the project root directory"),
      toolchain: z
        .enum(["auto", "typescript", "swift", "python", "rust", "go"])
        .optional()
        .default("auto")
        .describe("Toolchain to use for diagnostics (default: auto-detect)"),
      command: z
        .string()
        .optional()
        .describe("Custom command to run for diagnostics (overrides toolchain detection)"),
    },
    async ({ path: projectPath, toolchain, command }) => {
      const rootPath = resolve(projectPath);

      if (!existsSync(rootPath)) {
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify({ error: `Path does not exist: ${rootPath}` }),
            },
          ],
        };
      }

      // Auto-detect toolchain if needed
      const detectedToolchain =
        !toolchain || toolchain === "auto"
          ? await detectToolchain(rootPath)
          : toolchain;

      // Run diagnostics
      const { output, parser } = runDiagnosticCommand(
        detectedToolchain,
        rootPath,
        command
      );

      const diagnostics = parser(output);

      // Build summary
      const errors = diagnostics.filter((d) => d.severity === "error");
      const warnings = diagnostics.filter((d) => d.severity === "warning");
      const infos = diagnostics.filter((d) => d.severity === "info");
      const filesAffected = [
        ...new Set(diagnostics.filter((d) => d.file).map((d) => d.file!)),
      ];

      // Compare with previous run
      const previousKey = `diagnostics_${basename(rootPath)}`;
      const previousResult = logger.getProfileValue<{
        errors: number;
        warnings: number;
        errorMessages: string[];
      }>(previousKey);

      let previousRun: DiagnosticsResult["previousRun"];
      if (previousResult) {
        const currentErrorMessages = errors.map((e) => `${e.file}:${e.line}:${e.message}`);
        const prevErrorMessages = previousResult.errorMessages ?? [];

        const resolvedErrors = prevErrorMessages.filter(
          (msg) => !currentErrorMessages.includes(msg)
        ).length;
        const newErrors = currentErrorMessages.filter(
          (msg) => !prevErrorMessages.includes(msg)
        ).length;

        previousRun = {
          errors: previousResult.errors,
          warnings: previousResult.warnings,
          resolvedErrors,
          newErrors,
        };
      }

      // Save current state for next comparison
      logger.setProfileValue(previousKey, {
        errors: errors.length,
        warnings: warnings.length,
        errorMessages: errors.map((e) => `${e.file}:${e.line}:${e.message}`),
      });

      const result: DiagnosticsResult = {
        project: basename(rootPath),
        toolchain: detectedToolchain,
        timestamp: new Date().toISOString(),
        diagnostics,
        summary: {
          errors: errors.length,
          warnings: warnings.length,
          info: infos.length,
          filesAffected,
        },
        previousRun,
      };

      // Log to session logger
      logger.logEvent({
        type: "diagnostic",
        action: errors.length > 0 ? "errors_found" : "clean",
        project: basename(rootPath),
        metadata: {
          toolchain: detectedToolchain,
          errors: errors.length,
          warnings: warnings.length,
          filesAffected,
          resolved: previousRun?.resolvedErrors ?? 0,
          new: previousRun?.newErrors ?? 0,
        },
      });

      // Log individual errors as learning events
      for (const error of errors.slice(0, 5)) {
        logger.logEvent({
          type: "learning",
          action: "error_encountered",
          project: basename(rootPath),
          language: detectedToolchain,
          file: error.file,
          metadata: {
            severity: error.severity,
            message: error.message,
            code: error.code,
            line: error.line,
          },
        });
      }

      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify(result, null, 2),
          },
        ],
      };
    }
  );
}
