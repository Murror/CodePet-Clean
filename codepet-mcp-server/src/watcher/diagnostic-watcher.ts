/**
 * DiagnosticWatcher — Real-time file system watcher for coding errors
 *
 * This is the core engine that makes Codepet's USP work across ALL platforms.
 * It watches a project directory for file changes, runs the appropriate linter
 * or compiler when a file is saved, parses the output, and emits structured
 * diagnostic events that any client (extension, CLI, web) can consume.
 *
 * Architecture:
 *   File saved → debounced watcher → detect language → run linter → parse errors
 *     → compare with previous state → emit events (new errors, resolved errors)
 *       → auto-fix engine suggests/applies fixes
 *
 * Platform-agnostic: works with any editor that saves to disk.
 * Language-agnostic: pluggable linter runners for any language.
 */

import { watch as fsWatch, existsSync, statSync } from "node:fs";
import { readFile, readdir } from "node:fs/promises";
import { execSync } from "node:child_process";
import { join, extname, basename, relative, resolve } from "node:path";
import { EventEmitter } from "node:events";

// ───── Types ─────

export interface Diagnostic {
  severity: "error" | "warning" | "info";
  message: string;
  file: string;
  line: number;
  column: number;
  source: string; // "tsc", "swiftc", "pyright", "eslint", etc.
  code?: string;  // "TS2345", "E0001", etc.
  fixable: boolean;
  suggestedFix?: SuggestedFix;
}

export interface SuggestedFix {
  description: string;       // Human-readable: "Add missing return type"
  replacement?: string;      // Direct text replacement
  lineRange?: { start: number; end: number };
  confidence: "high" | "medium" | "low";
}

export interface DiagnosticEvent {
  type: "error_detected" | "error_resolved" | "file_clean" | "fix_applied";
  timestamp: string;
  file: string;
  language: string;
  diagnostics: Diagnostic[];
  newErrors: Diagnostic[];     // Errors that just appeared
  resolvedErrors: Diagnostic[]; // Errors that were fixed since last run
  totalErrors: number;
  totalWarnings: number;
}

export interface WatcherConfig {
  rootPath: string;
  debounceMs?: number;      // Default: 500ms
  ignorePaths?: string[];   // Glob patterns to ignore
  enableAutoFix?: boolean;  // Default: false (suggest only)
  languages?: string[];     // Limit to specific languages (default: all detected)
}

// ───── Language Detection ─────

const LANG_BY_EXT: Record<string, string> = {
  ".ts": "typescript", ".tsx": "typescript", ".js": "javascript", ".jsx": "javascript",
  ".swift": "swift", ".py": "python", ".rs": "rust", ".go": "go",
  ".java": "java", ".kt": "kotlin", ".c": "c", ".cpp": "cpp", ".h": "c",
  ".rb": "ruby", ".php": "php", ".dart": "dart", ".cs": "csharp",
};

// Files/dirs to always ignore
const DEFAULT_IGNORE = [
  "node_modules", ".git", "dist", "build", ".next", "__pycache__",
  ".swiftpm", ".build", "target", "Pods", "DerivedData", ".cache",
  "vendor", "venv", ".venv",
];

// ───── Linter Runners ─────

export interface LinterRunner {
  name: string;
  language: string;
  /** Check if this linter is available in the project */
  detect(rootPath: string): boolean;
  /** Run the linter and return raw output */
  run(rootPath: string, changedFile?: string): string;
  /** Parse raw output into structured diagnostics */
  parse(output: string, rootPath: string): Diagnostic[];
}

/** TypeScript — tsc --noEmit */
const typescriptRunner: LinterRunner = {
  name: "tsc",
  language: "typescript",
  detect(rootPath) {
    // Only detect if tsconfig exists (package.json alone isn't enough — could be JS-only)
    if (!existsSync(join(rootPath, "tsconfig.json"))) return false;
    // Check that tsc is available (local or global)
    const hasLocal = existsSync(join(rootPath, "node_modules", ".bin", "tsc"));
    const hasGlobal = commandExists("tsc");
    return hasLocal || hasGlobal;
  },
  run(rootPath) {
    // Prefer local tsc, fall back to global
    const localTsc = join(rootPath, "node_modules", ".bin", "tsc");
    const cmd = existsSync(localTsc)
      ? `"${localTsc}" --noEmit --pretty false 2>&1`
      : "npx tsc --noEmit --pretty false 2>&1";
    return safeExec(cmd, { cwd: rootPath, timeout: 30000 });
  },
  parse(output, rootPath) {
    const diagnostics: Diagnostic[] = [];
    for (const line of output.split("\n")) {
      const m = line.match(/^(.+?)\((\d+),(\d+)\):\s+(error|warning)\s+(TS\d+):\s+(.+)$/);
      if (m) {
        diagnostics.push({
          severity: m[4] as "error" | "warning",
          file: resolve(rootPath, m[1]),
          line: parseInt(m[2]), column: parseInt(m[3]),
          code: m[5], message: m[6],
          source: "tsc", fixable: isFixable("tsc", m[5], m[6]),
        });
      }
    }
    return diagnostics;
  },
};

/** Swift — swift build or swiftc */
const swiftRunner: LinterRunner = {
  name: "swiftc",
  language: "swift",
  detect(rootPath) {
    // Check for Swift project markers
    try {
      const entries = require("fs").readdirSync(rootPath);
      const hasProject = entries.some((e: string) =>
        e.endsWith(".xcodeproj") || e.endsWith(".xcworkspace") || e === "Package.swift"
      );
      if (!hasProject) return false;
    } catch { return false; }
    // Verify swift or xcodebuild is available
    return commandExists("swift") || commandExists("xcodebuild");
  },
  run(rootPath) {
    // Try swift build first (for SPM projects), fall back to xcodebuild
    const cmds: string[] = [];
    if (commandExists("swift")) cmds.push("swift build 2>&1");
    if (commandExists("xcodebuild")) cmds.push("xcodebuild -quiet 2>&1");

    for (const cmd of cmds) {
      const out = safeExec(cmd, { cwd: rootPath, timeout: 60000 });
      if (out.includes("error:") || out.includes("warning:")) return out;
      if (out === "") return ""; // clean compile
    }
    return "";
  },
  parse(output, rootPath) {
    const diagnostics: Diagnostic[] = [];
    for (const line of output.split("\n")) {
      const m = line.match(/^(.+?\.swift):(\d+):(\d+):\s+(error|warning|note):\s+(.+)$/);
      if (m) {
        diagnostics.push({
          severity: m[4] === "note" ? "info" : m[4] as "error" | "warning",
          file: m[1].startsWith("/") ? m[1] : resolve(rootPath, m[1]),
          line: parseInt(m[2]), column: parseInt(m[3]),
          message: m[5], source: "swiftc",
          fixable: isFixable("swiftc", undefined, m[5]),
        });
      }
    }
    return diagnostics;
  },
};

/** Python — pyright or mypy or python -m py_compile */
const pythonRunner: LinterRunner = {
  name: "python",
  language: "python",
  detect(rootPath) {
    const hasProject = existsSync(join(rootPath, "pyproject.toml"))
      || existsSync(join(rootPath, "setup.py"))
      || existsSync(join(rootPath, "requirements.txt"));
    if (!hasProject) return false;
    // Need at least one Python checker available
    return commandExists("pyright") || commandExists("mypy") || commandExists("python3") || commandExists("python");
  },
  run(rootPath, changedFile) {
    // Prefer pyright (fast), fall back to mypy, then py_compile for single files
    const cmds: string[] = [];
    if (changedFile) {
      const py = commandExists("python3") ? "python3" : "python";
      cmds.push(`${py} -m py_compile "${changedFile}" 2>&1`);
    } else {
      if (commandExists("pyright")) cmds.push("pyright --outputjson 2>&1");
      if (commandExists("mypy")) cmds.push("mypy . 2>&1");
    }

    for (const cmd of cmds) {
      const out = safeExec(cmd, { cwd: rootPath, timeout: 30000 });
      if (out.length > 0) return out;
    }
    return "";
  },
  parse(output, rootPath) {
    const diagnostics: Diagnostic[] = [];
    for (const line of output.split("\n")) {
      // file.py:10:5 - error: message
      const m = line.match(/^(.+?):(\d+):(\d+)\s*[-–]\s*(error|warning|information):\s+(.+)$/);
      if (m) {
        diagnostics.push({
          severity: m[4] === "information" ? "info" : m[4] as "error" | "warning",
          file: m[1].startsWith("/") ? m[1] : resolve(rootPath, m[1]),
          line: parseInt(m[2]), column: parseInt(m[3]),
          message: m[5], source: "pyright",
          fixable: isFixable("pyright", undefined, m[5]),
        });
      }
      // Generic: file.py:10: error: message
      const m2 = line.match(/^(.+?\.py):(\d+):\s+(error|warning):\s+(.+)$/);
      if (!m && m2) {
        diagnostics.push({
          severity: m2[3] as "error" | "warning",
          file: m2[1].startsWith("/") ? m2[1] : resolve(rootPath, m2[1]),
          line: parseInt(m2[2]), column: 1,
          message: m2[4], source: "python",
          fixable: false,
        });
      }
    }
    return diagnostics;
  },
};

/** ESLint runner — for JS/TS projects with ESLint configured */
const eslintRunner: LinterRunner = {
  name: "eslint",
  language: "javascript",
  detect(rootPath) {
    const hasConfig = existsSync(join(rootPath, ".eslintrc.json"))
      || existsSync(join(rootPath, ".eslintrc.js"))
      || existsSync(join(rootPath, ".eslintrc.yml"))
      || existsSync(join(rootPath, "eslint.config.js"))
      || existsSync(join(rootPath, "eslint.config.mjs"));
    if (!hasConfig) return false;
    // Check that eslint is available locally
    return existsSync(join(rootPath, "node_modules", ".bin", "eslint")) || commandExists("eslint");
  },
  run(rootPath, changedFile) {
    const target = changedFile ? `"${changedFile}"` : ".";
    const localEslint = join(rootPath, "node_modules", ".bin", "eslint");
    const cmd = existsSync(localEslint)
      ? `"${localEslint}" ${target} --format json 2>&1`
      : `npx eslint ${target} --format json 2>&1`;
    return safeExec(cmd, { cwd: rootPath, timeout: 30000 });
  },
  parse(output, rootPath) {
    const diagnostics: Diagnostic[] = [];
    try {
      const results = JSON.parse(output);
      for (const result of results) {
        for (const msg of result.messages ?? []) {
          diagnostics.push({
            severity: msg.severity === 2 ? "error" : "warning",
            file: result.filePath,
            line: msg.line ?? 1, column: msg.column ?? 1,
            code: msg.ruleId ?? undefined,
            message: msg.message,
            source: "eslint",
            fixable: !!msg.fix,
            suggestedFix: msg.fix ? {
              description: `Auto-fix: ${msg.ruleId}`,
              confidence: "high",
            } : undefined,
          });
        }
      }
    } catch {
      // ESLint output wasn't valid JSON — parse as text
    }
    return diagnostics;
  },
};

// ───── Helper: check if a command exists ─────

function commandExists(cmd: string): boolean {
  try {
    execSync(`which ${cmd} 2>/dev/null || where ${cmd} 2>/dev/null`, {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
      timeout: 5000,
    });
    return true;
  } catch {
    return false;
  }
}

function safeExec(cmd: string, opts: { cwd: string; timeout?: number }): string {
  try {
    return execSync(cmd, {
      cwd: opts.cwd,
      encoding: "utf-8",
      timeout: opts.timeout ?? 30000,
      stdio: ["pipe", "pipe", "pipe"],
    });
  } catch (err: unknown) {
    const e = err as { stdout?: string; stderr?: string; message?: string };
    const out = (e.stdout ?? "") + (e.stderr ?? "");
    // If the command itself wasn't found, return empty
    if (e.message?.includes("ENOENT") || e.message?.includes("not found") || e.message?.includes("command not found")) {
      return "";
    }
    return out;
  }
}

// All registered runners
const ALL_RUNNERS: LinterRunner[] = [
  typescriptRunner, swiftRunner, pythonRunner, eslintRunner,
];

// ───── Fixability Detection ─────

/**
 * Determine if a specific error is auto-fixable based on known patterns.
 * This is the first layer — pattern-based fixes that don't need AI.
 */
function isFixable(source: string, code?: string, message?: string): boolean {
  const msg = (message ?? "").toLowerCase();

  // TypeScript fixable patterns
  if (source === "tsc") {
    if (code === "TS7006") return true;  // Parameter implicitly has 'any' type
    if (code === "TS2304") return true;  // Cannot find name (often a missing import)
    if (code === "TS2345") return true;  // Argument type mismatch
    if (code === "TS1005") return true;  // ';' expected
    if (code === "TS1003") return true;  // Identifier expected
    if (code === "TS2322") return true;  // Type is not assignable
    if (code === "TS6133") return true;  // Declared but never used
    if (code === "TS2552") return true;  // Cannot find name (did you mean...?)
  }

  // Swift fixable patterns
  if (source === "swiftc") {
    if (msg.includes("missing return")) return true;
    if (msg.includes("cannot convert")) return true;
    if (msg.includes("use of unresolved identifier")) return true;
    if (msg.includes("expected ')'")) return true;
    if (msg.includes("expected '}'")) return true;
    if (msg.includes("force unwrap")) return true;
  }

  // General fixable patterns
  if (msg.includes("unused") || msg.includes("never used")) return true;
  if (msg.includes("missing semicolon") || msg.includes("expected ';'")) return true;
  if (msg.includes("missing import") || msg.includes("cannot find")) return true;
  if (msg.includes("expected '}'") || msg.includes("expected ')'")) return true;

  return false;
}

// ───── DiagnosticWatcher Class ─────

export class DiagnosticWatcher extends EventEmitter {
  private watchers: ReturnType<typeof fsWatch>[] = [];
  private debounceTimers = new Map<string, NodeJS.Timeout>();
  private previousDiagnostics = new Map<string, Diagnostic[]>(); // file → last known errors
  private runners: LinterRunner[] = [];
  private config: Required<WatcherConfig>;
  private isRunning = false;

  constructor(config: WatcherConfig) {
    super();
    this.config = {
      rootPath: resolve(config.rootPath),
      debounceMs: config.debounceMs ?? 500,
      ignorePaths: config.ignorePaths ?? DEFAULT_IGNORE,
      enableAutoFix: config.enableAutoFix ?? false,
      languages: config.languages ?? [],
    };
  }

  /** Start watching the project directory */
  start(): void {
    if (this.isRunning) return;
    this.isRunning = true;

    // Detect available linters
    this.runners = ALL_RUNNERS.filter((r) => r.detect(this.config.rootPath));
    const names = this.runners.map((r) => r.name);

    this.emit("started", {
      rootPath: this.config.rootPath,
      detectedLinters: names,
      timestamp: new Date().toISOString(),
    });

    // Watch the root directory recursively
    this.watchDirectory(this.config.rootPath);
  }

  /** Stop watching */
  stop(): void {
    this.isRunning = false;
    for (const w of this.watchers) {
      try { w.close(); } catch { /* ignore */ }
    }
    this.watchers = [];
    for (const timer of this.debounceTimers.values()) {
      clearTimeout(timer);
    }
    this.debounceTimers.clear();
    this.emit("stopped", { timestamp: new Date().toISOString() });
  }

  /** Get current diagnostic state for a file */
  getDiagnosticsForFile(filePath: string): Diagnostic[] {
    return this.previousDiagnostics.get(resolve(filePath)) ?? [];
  }

  /** Get all current diagnostics across the project */
  getAllDiagnostics(): Diagnostic[] {
    const all: Diagnostic[] = [];
    for (const diags of this.previousDiagnostics.values()) {
      all.push(...diags);
    }
    return all;
  }

  /** Run diagnostics manually (for initial scan or force-refresh) */
  async runFullScan(): Promise<DiagnosticEvent[]> {
    const events: DiagnosticEvent[] = [];
    for (const runner of this.runners) {
      try {
        const output = runner.run(this.config.rootPath);
        const diagnostics = runner.parse(output, this.config.rootPath);

        // Group by file
        const byFile = new Map<string, Diagnostic[]>();
        for (const d of diagnostics) {
          const existing = byFile.get(d.file) ?? [];
          existing.push(d);
          byFile.set(d.file, existing);
        }

        // Emit events per file
        for (const [file, fileDiags] of byFile) {
          const event = this.buildEvent(file, runner.language, fileDiags);
          events.push(event);
          this.emit("diagnostics", event);
        }
      } catch (err) {
        this.emit("error", { runner: runner.name, error: err });
      }
    }
    return events;
  }

  // ───── Private ─────

  private watchDirectory(dirPath: string): void {
    if (!existsSync(dirPath) || !statSync(dirPath).isDirectory()) return;

    try {
      const watcher = fsWatch(dirPath, { recursive: true }, (eventType, filename) => {
        if (!filename) return;

        const fullPath = join(dirPath, filename);
        const ext = extname(filename);
        const lang = LANG_BY_EXT[ext];

        // Skip non-code files and ignored paths
        if (!lang) return;
        if (this.shouldIgnore(filename)) return;
        if (this.config.languages.length > 0 && !this.config.languages.includes(lang)) return;

        // Debounce: wait for rapid saves to settle
        this.debouncedCheck(fullPath, lang);
      });

      this.watchers.push(watcher);
    } catch (err) {
      this.emit("error", { message: "Failed to watch directory", dirPath, error: err });
    }
  }

  private shouldIgnore(filePath: string): boolean {
    const parts = filePath.split("/");
    return parts.some((p) => this.config.ignorePaths.includes(p));
  }

  private debouncedCheck(filePath: string, language: string): void {
    // Clear existing timer for this file
    const existing = this.debounceTimers.get(filePath);
    if (existing) clearTimeout(existing);

    const timer = setTimeout(() => {
      this.debounceTimers.delete(filePath);
      this.checkFile(filePath, language);
    }, this.config.debounceMs);

    this.debounceTimers.set(filePath, timer);
  }

  private checkFile(filePath: string, language: string): void {
    // Find a runner that handles this language
    const runner = this.runners.find((r) => r.language === language);
    if (!runner) return;

    try {
      // Run the linter (either for the specific file or whole project)
      const output = runner.run(this.config.rootPath, filePath);
      const allDiagnostics = runner.parse(output, this.config.rootPath);

      // Filter to diagnostics for the changed file
      const fileDiags = allDiagnostics.filter((d) => resolve(d.file) === resolve(filePath));

      // Build and emit the event
      const event = this.buildEvent(filePath, language, fileDiags);
      this.emit("diagnostics", event);

      // Update stored state
      this.previousDiagnostics.set(resolve(filePath), fileDiags);
    } catch (err) {
      this.emit("error", { file: filePath, runner: runner.name, error: err });
    }
  }

  private buildEvent(file: string, language: string, currentDiags: Diagnostic[]): DiagnosticEvent {
    const resolvedFile = resolve(file);
    const previousDiags = this.previousDiagnostics.get(resolvedFile) ?? [];

    // Compute diff: what's new vs what's resolved
    const prevKeys = new Set(previousDiags.map((d) => `${d.line}:${d.message}`));
    const currKeys = new Set(currentDiags.map((d) => `${d.line}:${d.message}`));

    const newErrors = currentDiags.filter((d) => !prevKeys.has(`${d.line}:${d.message}`));
    const resolvedErrors = previousDiags.filter((d) => !currKeys.has(`${d.line}:${d.message}`));

    // Update stored state
    this.previousDiagnostics.set(resolvedFile, currentDiags);

    const errors = currentDiags.filter((d) => d.severity === "error");
    const warnings = currentDiags.filter((d) => d.severity === "warning");

    const type: DiagnosticEvent["type"] =
      newErrors.length > 0 ? "error_detected"
      : resolvedErrors.length > 0 ? "error_resolved"
      : currentDiags.length === 0 ? "file_clean"
      : "error_detected";

    return {
      type,
      timestamp: new Date().toISOString(),
      file: relative(this.config.rootPath, resolvedFile),
      language,
      diagnostics: currentDiags,
      newErrors,
      resolvedErrors,
      totalErrors: errors.length,
      totalWarnings: warnings.length,
    };
  }
}
