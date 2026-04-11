/**
 * CodeScanner — Real-time code analysis engine (Grammarly model)
 *
 * Watches document changes and file saves, runs lightweight pattern-based
 * analysis, and bridges VS Code's built-in diagnostics. Produces three
 * tiers of findings that the pet character can react to:
 *
 *   🔴 Error    — Something is broken (syntax, type, missing import)
 *   🟡 Warning  — Could be improved (unused var, complexity, deprecated API)
 *   🟢 Clean    — Code looks good! (positive reinforcement)
 *
 * Design philosophy (Atomic Habits):
 *   - "Make it Obvious" — surface invisible code issues the way a Habits Scorecard
 *     surfaces unconscious behaviors. No judgment, just awareness.
 *   - "Make it Easy" — each suggestion is tiny and actionable (Two-Minute Rule).
 *   - "Make it Satisfying" — green checks on clean code close the reward loop.
 *
 * Design philosophy (Thinking in Systems):
 *   - Tight feedback loop — near-zero delay between writing code and seeing results.
 *   - Balancing loop — errors push toward fixes; clean code reinforces good patterns.
 */

import * as vscode from "vscode";

// ───── Types ─────

export type FindingSeverity = "error" | "warning" | "clean";

export interface CodeFinding {
  severity: FindingSeverity;
  line: number;
  column: number;
  endLine?: number;
  endColumn?: number;
  message: string;
  code: string; // e.g. "unused-variable", "missing-semicolon"
  source: "pattern" | "diagnostics"; // our scan vs VS Code built-in
  language: string;
  suggestion?: string; // one-liner fix hint
  autoFixable?: boolean;
}

export interface ScanResult {
  uri: string;
  language: string;
  findings: CodeFinding[];
  errorCount: number;
  warningCount: number;
  cleanScore: number; // 0–100, percentage of "clean" lines
  timestamp: number;
}

export interface ScanSummary {
  totalErrors: number;
  totalWarnings: number;
  cleanFiles: number;
  totalFiles: number;
  averageCleanScore: number;
  topIssue: string | null;
}

// ───── Language-specific patterns ─────

interface PatternRule {
  id: string;
  severity: FindingSeverity;
  pattern: RegExp;
  exclude?: RegExp; // if this matches the line, skip the finding
  message: string;
  suggestion?: string;
  languages: string[]; // which languages this applies to
}

const PATTERN_RULES: PatternRule[] = [
  // ── JavaScript / TypeScript ──
  {
    id: "console-log",
    severity: "warning",
    pattern: /\bconsole\.log\s*\(/,
    message: "console.log left in code",
    suggestion: "Remove or replace with a proper logger before shipping",
    languages: ["javascript", "typescript", "javascriptreact", "typescriptreact"],
  },
  {
    id: "var-declaration",
    severity: "warning",
    pattern: /\bvar\s+\w+/,
    message: "'var' used instead of 'let' or 'const'",
    suggestion: "Use 'const' for values that don't change, 'let' for ones that do",
    languages: ["javascript", "typescript", "javascriptreact", "typescriptreact"],
  },
  {
    id: "todo-comment",
    severity: "warning",
    pattern: /\/\/\s*TODO\b/i,
    message: "TODO comment found",
    suggestion: "Track this in your issue tracker so it doesn't get forgotten",
    languages: ["javascript", "typescript", "javascriptreact", "typescriptreact", "swift", "python", "go", "rust", "java", "c", "cpp"],
  },
  {
    id: "fixme-comment",
    severity: "warning",
    pattern: /\/\/\s*FIXME\b/i,
    message: "FIXME comment found — something needs attention",
    suggestion: "This marks a known issue. Consider fixing it now while context is fresh",
    languages: ["javascript", "typescript", "javascriptreact", "typescriptreact", "swift", "python", "go", "rust", "java", "c", "cpp"],
  },
  {
    id: "empty-catch",
    severity: "warning",
    pattern: /catch\s*\([^)]*\)\s*\{\s*\}/,
    message: "Empty catch block — errors are being silently swallowed",
    suggestion: "At minimum, log the error so you can debug issues later",
    languages: ["javascript", "typescript", "javascriptreact", "typescriptreact", "java"],
  },
  {
    id: "triple-equals",
    severity: "warning",
    pattern: /[^!=]==[^=]/,
    message: "Loose equality (==) used instead of strict equality (===)",
    suggestion: "Use === to avoid unexpected type coercion",
    languages: ["javascript", "javascriptreact"],
  },
  {
    id: "loose-inequality",
    severity: "warning",
    pattern: /[^!]!=[^=]/,
    message: "Loose inequality (!=) used instead of strict inequality (!==)",
    suggestion: "Use !== to avoid unexpected type coercion",
    languages: ["javascript", "javascriptreact"],
  },
  {
    id: "magic-number",
    severity: "warning",
    pattern: /(?:if|while|for|return)\s*\(.*\b(?:[2-9]\d{2,}|[1-9]\d{3,})\b/,
    message: "Magic number detected in logic",
    suggestion: "Extract to a named constant for clarity",
    languages: ["javascript", "typescript", "javascriptreact", "typescriptreact", "swift", "python", "java"],
  },
  {
    id: "nested-ternary",
    severity: "warning",
    pattern: /\?[^:]*\?/,
    message: "Nested ternary — can be hard to read",
    suggestion: "Consider using if/else or extracting into a helper function",
    languages: ["javascript", "typescript", "javascriptreact", "typescriptreact"],
  },
  {
    id: "any-type",
    severity: "warning",
    pattern: /:\s*any\b/,
    // Don't flag bare declarations like "let x: any;" — those need the annotation
    // (e.g. added by TS7043 fix). Only flag : any on assignments, params, return types.
    exclude: /^\s*(let|var|const)\s+\w+\s*:\s*any\s*[;=]/,
    message: "TypeScript 'any' type used — defeats type safety",
    suggestion: "Try a more specific type, or 'unknown' if the type is truly dynamic",
    languages: ["typescript", "typescriptreact"],
  },
  {
    id: "debugger-statement",
    severity: "error",
    pattern: /^\s*debugger\s*;?\s*$/,
    message: "debugger statement left in code",
    suggestion: "Remove before committing — this will pause execution in browsers",
    languages: ["javascript", "typescript", "javascriptreact", "typescriptreact"],
  },

  // ── Python ──
  {
    id: "python-print",
    severity: "warning",
    pattern: /\bprint\s*\(/,
    message: "print() left in code",
    suggestion: "Use logging module for production code",
    languages: ["python"],
  },
  {
    id: "python-bare-except",
    severity: "warning",
    pattern: /\bexcept\s*:/,
    message: "Bare except catches everything, including KeyboardInterrupt",
    suggestion: "Catch specific exceptions: except ValueError:",
    languages: ["python"],
  },
  {
    id: "python-todo",
    severity: "warning",
    pattern: /#\s*TODO\b/i,
    message: "TODO comment found",
    suggestion: "Track this in your issue tracker",
    languages: ["python"],
  },
  {
    id: "python-pass-only",
    severity: "warning",
    pattern: /^\s*pass\s*$/,
    message: "Empty pass block — placeholder left behind?",
    suggestion: "Implement the logic or add a comment explaining why it's empty",
    languages: ["python"],
  },

  // ── Swift ──
  {
    id: "swift-force-unwrap",
    severity: "warning",
    pattern: /\w+!/,
    message: "Force unwrap (!) can crash if value is nil",
    suggestion: "Use 'if let' or 'guard let' for safe unwrapping",
    languages: ["swift"],
  },
  {
    id: "swift-print",
    severity: "warning",
    pattern: /\bprint\s*\(/,
    message: "print() left in code",
    suggestion: "Use os_log or a Logger for production builds",
    languages: ["swift"],
  },
  {
    id: "swift-force-cast",
    severity: "warning",
    pattern: /\bas!\s/,
    message: "Force cast (as!) can crash at runtime",
    suggestion: "Use 'as?' for conditional casting",
    languages: ["swift"],
  },

  // ── Go ──
  {
    id: "go-fmt-println",
    severity: "warning",
    pattern: /\bfmt\.Println\s*\(/,
    message: "fmt.Println left in code",
    suggestion: "Use structured logging (log/slog) for production",
    languages: ["go"],
  },
  {
    id: "go-ignored-error",
    severity: "warning",
    pattern: /,\s*_\s*:?=\s*\w+\.\w+\(/,
    message: "Error return value ignored",
    suggestion: "Handle the error or explicitly document why it's safe to ignore",
    languages: ["go"],
  },

  // ── Rust ──
  {
    id: "rust-unwrap",
    severity: "warning",
    pattern: /\.unwrap\s*\(\s*\)/,
    message: ".unwrap() can panic at runtime",
    suggestion: "Use match, if let, or the ? operator for safer error handling",
    languages: ["rust"],
  },

  // ── HTML ──
  {
    id: "html-inline-style",
    severity: "warning",
    pattern: /style\s*=\s*"/,
    message: "Inline style found",
    suggestion: "Move to a CSS class for better maintainability",
    languages: ["html"],
  },
  {
    id: "html-missing-alt",
    severity: "warning",
    pattern: /<img\s+(?![^>]*\balt\s*=)[^>]*>/,
    message: "Image missing alt attribute — accessibility issue",
    suggestion: "Add alt=\"description\" for screen readers",
    languages: ["html"],
  },
];

// ── Positive patterns (things we celebrate) ──

interface CleanPattern {
  id: string;
  pattern: RegExp;
  message: string;
  languages: string[];
}

const CLEAN_PATTERNS: CleanPattern[] = [
  {
    id: "error-handling",
    pattern: /\btry\s*\{[\s\S]*?\bcatch\b/,
    message: "Good error handling",
    languages: ["javascript", "typescript", "javascriptreact", "typescriptreact", "java", "swift"],
  },
  {
    id: "jsdoc-comment",
    pattern: /\/\*\*[\s\S]*?\*\//,
    message: "Well-documented code",
    languages: ["javascript", "typescript", "javascriptreact", "typescriptreact"],
  },
  {
    id: "const-usage",
    pattern: /\bconst\s+\w+/,
    message: "Immutable binding — good practice",
    languages: ["javascript", "typescript", "javascriptreact", "typescriptreact"],
  },
  {
    id: "guard-clause",
    pattern: /^\s*(?:if|guard)\s*.*\breturn\b/,
    message: "Nice guard clause — early returns keep code flat",
    languages: ["javascript", "typescript", "swift", "go", "rust"],
  },
  {
    id: "type-annotation",
    pattern: /:\s*(?:string|number|boolean|Int|Double|String|Bool)\b/,
    message: "Type annotation — makes code self-documenting",
    languages: ["typescript", "typescriptreact", "swift"],
  },
  {
    id: "python-type-hint",
    pattern: /def\s+\w+\([^)]*:\s*\w+/,
    message: "Type hints — great for readability",
    languages: ["python"],
  },
  {
    id: "rust-result-type",
    pattern: /->\s*Result</,
    message: "Result type for explicit error handling",
    languages: ["rust"],
  },
];

// ───── Scanner class ─────

/** A brand-new error that just appeared (wasn't in previous scan) */
export interface NewErrorEvent {
  finding: CodeFinding;
  fileName: string;
  uri: string;
  totalErrors: number;
}

export class CodeScanner implements vscode.Disposable {
  private disposables: vscode.Disposable[] = [];
  private diagnosticCollection: vscode.DiagnosticCollection;
  private scanResults: Map<string, ScanResult> = new Map();
  private debounceTimers: Map<string, ReturnType<typeof setTimeout>> = new Map();
  private lastResultSignatures: Map<string, string> = new Map(); // dedup unchanged scans
  private previousFindings: Map<string, Set<string>> = new Map(); // track known errors per file

  // Events
  private _onScanComplete = new vscode.EventEmitter<ScanResult>();
  readonly onScanComplete = this._onScanComplete.event;

  private _onSummaryChanged = new vscode.EventEmitter<ScanSummary>();
  readonly onSummaryChanged = this._onSummaryChanged.event;

  /** Fires when a NEW error appears that wasn't in the previous scan */
  private _onNewError = new vscode.EventEmitter<NewErrorEvent>();
  readonly onNewError = this._onNewError.event;

  constructor() {
    this.diagnosticCollection = vscode.languages.createDiagnosticCollection("codepet");

    // Scan on file save
    this.disposables.push(
      vscode.workspace.onDidSaveTextDocument((doc) => {
        this.scanDocument(doc);
      })
    );

    // Scan on document change (debounced)
    this.disposables.push(
      vscode.workspace.onDidChangeTextDocument((event) => {
        this.debouncedScan(event.document);
      })
    );

    // Scan active editor on open
    this.disposables.push(
      vscode.window.onDidChangeActiveTextEditor((editor) => {
        if (editor) {
          this.scanDocument(editor.document);
        }
      })
    );

    // NOTE: onDidChangeDiagnostics was removed intentionally.
    // It caused an infinite feedback loop: our scan writes diagnostics →
    // VS Code fires onDidChangeDiagnostics → we scan again → repeat.
    // External diagnostics (ESLint, TypeScript) are already captured during
    // our on-save and on-type scans via vscode.languages.getDiagnostics().

    // Scan whatever is already open
    if (vscode.window.activeTextEditor) {
      this.scanDocument(vscode.window.activeTextEditor.document);
    }
  }

  // ───── Public API ─────

  get summary(): ScanSummary {
    let totalErrors = 0;
    let totalWarnings = 0;
    let cleanFiles = 0;
    let totalCleanScore = 0;
    const issueCounts: Map<string, number> = new Map();

    for (const result of this.scanResults.values()) {
      totalErrors += result.errorCount;
      totalWarnings += result.warningCount;
      totalCleanScore += result.cleanScore;
      if (result.errorCount === 0 && result.warningCount === 0) {
        cleanFiles++;
      }
      for (const f of result.findings) {
        if (f.severity !== "clean") {
          issueCounts.set(f.code, (issueCounts.get(f.code) ?? 0) + 1);
        }
      }
    }

    const totalFiles = this.scanResults.size;
    let topIssue: string | null = null;
    let topCount = 0;
    for (const [code, count] of issueCounts) {
      if (count > topCount) {
        topCount = count;
        topIssue = code;
      }
    }

    return {
      totalErrors,
      totalWarnings,
      cleanFiles,
      totalFiles,
      averageCleanScore: totalFiles > 0 ? Math.round(totalCleanScore / totalFiles) : 100,
      topIssue,
    };
  }

  getResultForUri(uri: string): ScanResult | undefined {
    return this.scanResults.get(uri);
  }

  /** Force a rescan of the active editor (call when sidebar becomes visible) */
  rescanActiveEditor(): void {
    const editor = vscode.window.activeTextEditor;
    if (editor) {
      this.scanDocument(editor.document);
    }
  }

  // ───── Scanning ─────

  private debouncedScan(document: vscode.TextDocument): void {
    const key = document.uri.toString();
    const existing = this.debounceTimers.get(key);
    if (existing) clearTimeout(existing);

    this.debounceTimers.set(
      key,
      setTimeout(() => {
        this.debounceTimers.delete(key);
        this.scanDocument(document);
      }, 1500) // 1.5s debounce for typing
    );
  }

  private scanDocument(document: vscode.TextDocument): void {
    // Skip non-file schemes (output panels, git diffs, etc.)
    if (document.uri.scheme !== "file") return;

    // Skip very large files (> 5000 lines)
    if (document.lineCount > 5000) return;

    const language = document.languageId;
    const text = document.getText();
    const lines = text.split("\n");
    const findings: CodeFinding[] = [];

    // 1. Run our pattern rules
    const applicableRules = PATTERN_RULES.filter((r) =>
      r.languages.includes(language)
    );

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      for (const rule of applicableRules) {
        const match = rule.pattern.exec(line);
        if (match && !(rule.exclude && rule.exclude.test(line))) {
          findings.push({
            severity: rule.severity,
            line: i,
            column: match.index,
            endColumn: match.index + match[0].length,
            message: rule.message,
            code: rule.id,
            source: "pattern",
            language,
            suggestion: rule.suggestion,
          });
        }
      }

      // Check clean patterns (only a sample — don't overwhelm)
      if (findings.filter((f) => f.severity === "clean").length < 5) {
        const applicableClean = CLEAN_PATTERNS.filter((r) =>
          r.languages.includes(language)
        );
        for (const cp of applicableClean) {
          if (cp.pattern.test(line)) {
            findings.push({
              severity: "clean",
              line: i,
              column: 0,
              message: cp.message,
              code: cp.id,
              source: "pattern",
              language,
            });
            break; // one clean finding per line max
          }
        }
      }
    }

    // 2. Bridge VS Code's built-in diagnostics (from ESLint, TypeScript, etc.)
    const builtinDiags = vscode.languages.getDiagnostics(document.uri);
    for (const diag of builtinDiags) {
      // Skip our own diagnostics
      if (diag.source === "codepet") continue;

      // Skip diagnostics on lines that already have @ts-ignore above them
      // (TS may not have reprocessed yet, but the fix is already in place)
      const diagLineNum = diag.range.start.line;
      let alreadySuppressed = false;
      for (let k = 1; k <= 3 && diagLineNum - k >= 0; k++) {
        const aboveLine = lines[diagLineNum - k];
        if (aboveLine && (aboveLine.includes("@ts-ignore") || aboveLine.includes("@ts-expect-error"))) {
          alreadySuppressed = true;
          break;
        }
        if (aboveLine && aboveLine.trim() !== "" && !aboveLine.trim().startsWith("//")) break;
      }
      if (alreadySuppressed) continue;

      findings.push({
        severity:
          diag.severity === vscode.DiagnosticSeverity.Error
            ? "error"
            : "warning",
        line: diag.range.start.line,
        column: diag.range.start.character,
        endLine: diag.range.end.line,
        endColumn: diag.range.end.character,
        message: diag.message,
        code: String(
          typeof diag.code === "number" ? diag.code
            : typeof diag.code === "object" && diag.code !== null ? (diag.code as any).value ?? diag.code
            : diag.code ?? diag.source ?? "builtin"
        ),
        source: "diagnostics",
        language,
      });
    }

    // 3. Calculate clean score
    const issueLines = new Set(
      findings.filter((f) => f.severity !== "clean").map((f) => f.line)
    );
    const totalLines = Math.max(lines.length, 1);
    const cleanScore = Math.round(
      ((totalLines - issueLines.size) / totalLines) * 100
    );

    // 4. Build result
    const result: ScanResult = {
      uri: document.uri.toString(),
      language,
      findings,
      errorCount: findings.filter((f) => f.severity === "error").length,
      warningCount: findings.filter((f) => f.severity === "warning").length,
      cleanScore,
      timestamp: Date.now(),
    };

    // 5. Update our diagnostic collection (only pattern-sourced findings)
    const patternDiags = findings
      .filter((f) => f.source === "pattern" && f.severity !== "clean")
      .map((f) => {
        const range = new vscode.Range(
          f.line,
          f.column,
          f.endLine ?? f.line,
          f.endColumn ?? f.column + 1
        );
        const severity =
          f.severity === "error"
            ? vscode.DiagnosticSeverity.Error
            : vscode.DiagnosticSeverity.Warning;
        const diag = new vscode.Diagnostic(range, f.message, severity);
        diag.source = "codepet";
        diag.code = f.code;
        return diag;
      });

    this.diagnosticCollection.set(document.uri, patternDiags);

    // 6. Detect NEW errors (not in previous scan) — for proactive notifications
    const uriStr = document.uri.toString();
    const currentErrorKeys = new Set(
      findings
        .filter((f) => f.severity === "error" || f.severity === "warning")
        .map((f) => `${f.line}:${f.code}:${f.message}`)
    );
    const prevErrorKeys = this.previousFindings.get(uriStr) ?? new Set();
    const fileName = document.uri.path.split("/").pop() ?? "file";

    // Fire event for each genuinely new error
    for (const f of findings) {
      if (f.severity === "clean") continue;
      const key = `${f.line}:${f.code}:${f.message}`;
      if (!prevErrorKeys.has(key)) {
        this._onNewError.fire({
          finding: f,
          fileName,
          uri: uriStr,
          totalErrors: result.errorCount,
        });
      }
    }
    this.previousFindings.set(uriStr, currentErrorKeys);

    // 7. Store and emit — only if results actually changed
    const sig = `${result.errorCount}:${result.warningCount}:${result.cleanScore}:${result.findings.length}`;
    const prevSig = this.lastResultSignatures.get(result.uri);
    this.scanResults.set(document.uri.toString(), result);

    if (sig !== prevSig) {
      this.lastResultSignatures.set(result.uri, sig);
      this._onScanComplete.fire(result);
      this._onSummaryChanged.fire(this.summary);
    }
  }

  // ───── Disposal ─────

  dispose(): void {
    for (const timer of this.debounceTimers.values()) {
      clearTimeout(timer);
    }
    this.debounceTimers.clear();
    this.diagnosticCollection.dispose();
    this._onScanComplete.dispose();
    this._onSummaryChanged.dispose();
    this._onNewError.dispose();
    for (const d of this.disposables) d.dispose();
  }
}
