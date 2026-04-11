/**
 * AutoFixEngine — Pattern-based code fixes powered by Byte
 *
 * This engine takes a Diagnostic and attempts to generate a fix without
 * needing an AI model. It uses known patterns for common errors across
 * TypeScript, Swift, Python, and other languages.
 *
 * Two modes:
 *   1. Suggest — returns the fix but doesn't apply it (default)
 *   2. Apply   — reads the file, applies the fix, writes it back
 *
 * For errors that can't be pattern-matched, it returns a structured
 * request that can be sent to an AI model (Claude) for a fix.
 */

import { readFileSync, writeFileSync } from "node:fs";
import type { Diagnostic, SuggestedFix } from "./diagnostic-watcher.js";

// ───── Types ─────

export interface FixResult {
  applied: boolean;
  diagnostic: Diagnostic;
  fix: SuggestedFix | null;
  /** If we can't fix it locally, this is a prompt for an AI model */
  aiFixRequest?: AiFixRequest;
  /** Byte's reaction to this error */
  petReaction: string;
}

export interface AiFixRequest {
  language: string;
  filePath: string;
  errorMessage: string;
  errorCode?: string;
  errorLine: number;
  surroundingCode: string; // 5 lines before + error line + 5 lines after
  instruction: string;     // What we want the AI to do
}

// ───── Fix Patterns ─────

interface FixPattern {
  match: (d: Diagnostic) => boolean;
  fix: (d: Diagnostic, fileLines: string[]) => SuggestedFix | null;
}

const TYPESCRIPT_FIXES: FixPattern[] = [
  // TS1005: ';' expected
  {
    match: (d) => d.source === "tsc" && d.code === "TS1005" && d.message.includes("';'"),
    fix: (d, lines) => {
      const line = lines[d.line - 1];
      if (!line) return null;
      return {
        description: "Add missing semicolon",
        replacement: line.trimEnd() + ";",
        lineRange: { start: d.line, end: d.line },
        confidence: "high",
      };
    },
  },

  // TS6133: Variable declared but never used
  {
    match: (d) => d.source === "tsc" && d.code === "TS6133",
    fix: (d, lines) => {
      const line = lines[d.line - 1];
      if (!line) return null;
      // Prefix unused variable with underscore
      const nameMatch = d.message.match(/'(\w+)' is declared but/);
      if (nameMatch) {
        const varName = nameMatch[1];
        return {
          description: `Prefix unused variable '${varName}' with underscore`,
          replacement: line.replace(new RegExp(`\\b${varName}\\b`), `_${varName}`),
          lineRange: { start: d.line, end: d.line },
          confidence: "high",
        };
      }
      return null;
    },
  },

  // TS2552: Cannot find name 'X'. Did you mean 'Y'?
  {
    match: (d) => d.source === "tsc" && d.code === "TS2552",
    fix: (d, lines) => {
      const line = lines[d.line - 1];
      if (!line) return null;
      const m = d.message.match(/Cannot find name '(\w+)'. Did you mean '(\w+)'/);
      if (m) {
        return {
          description: `Replace '${m[1]}' with '${m[2]}'`,
          replacement: line.replace(new RegExp(`\\b${m[1]}\\b`), m[2]),
          lineRange: { start: d.line, end: d.line },
          confidence: "high",
        };
      }
      return null;
    },
  },

  // TS7006: Parameter implicitly has 'any' type
  {
    match: (d) => d.source === "tsc" && d.code === "TS7006",
    fix: (d, lines) => {
      const line = lines[d.line - 1];
      if (!line) return null;
      const nameMatch = d.message.match(/Parameter '(\w+)' implicitly/);
      if (nameMatch) {
        const param = nameMatch[1];
        // Add ': any' type annotation (user should refine later)
        const replaced = line.replace(
          new RegExp(`(\\b${param})(\\s*[,\\)])`),
          `$1: any$2`
        );
        if (replaced !== line) {
          return {
            description: `Add 'any' type to parameter '${param}' (refine later)`,
            replacement: replaced,
            lineRange: { start: d.line, end: d.line },
            confidence: "medium",
          };
        }
      }
      return null;
    },
  },
];

const SWIFT_FIXES: FixPattern[] = [
  // Missing return in closure/function
  {
    match: (d) => d.source === "swiftc" && d.message.toLowerCase().includes("missing return"),
    fix: (d, lines) => ({
      description: "This function is missing a return statement",
      confidence: "low", // AI should handle the actual return value
    }),
  },

  // Force unwrap warning
  {
    match: (d) => d.source === "swiftc" && d.message.toLowerCase().includes("force unwrap"),
    fix: (d, lines) => {
      const line = lines[d.line - 1];
      if (!line) return null;
      // Replace ! with ?? defaultValue or if-let
      if (line.includes("!")) {
        return {
          description: "Replace force unwrap (!) with optional binding or nil coalescing",
          replacement: line.replace(/(\w+)!/g, "$1 ?? <#default#>"),
          lineRange: { start: d.line, end: d.line },
          confidence: "medium",
        };
      }
      return null;
    },
  },

  // Expected ')' or '}'
  {
    match: (d) => d.source === "swiftc" && /expected '[)}]'/.test(d.message),
    fix: (d, lines) => {
      const line = lines[d.line - 1];
      if (!line) return null;
      const missing = d.message.includes("')'") ? ")" : "}";
      return {
        description: `Add missing '${missing}'`,
        replacement: line.trimEnd() + missing,
        lineRange: { start: d.line, end: d.line },
        confidence: "medium",
      };
    },
  },
];

const PYTHON_FIXES: FixPattern[] = [
  // Undefined variable (common typo)
  {
    match: (d) => (d.source === "python" || d.source === "pyright") && d.message.includes("is not defined"),
    fix: () => ({
      description: "Variable is not defined — check for typos or missing import",
      confidence: "low",
    }),
  },

  // Missing import
  {
    match: (d) => (d.source === "python" || d.source === "pyright") && d.message.includes("could not be resolved"),
    fix: (d) => ({
      description: `Module could not be resolved — may need 'pip install' or check import path`,
      confidence: "low",
    }),
  },
];

const ALL_FIX_PATTERNS: FixPattern[] = [
  ...TYPESCRIPT_FIXES,
  ...SWIFT_FIXES,
  ...PYTHON_FIXES,
];

// ───── Pet Reactions ─────

function generatePetReaction(diagnostic: Diagnostic, fixed: boolean): string {
  const severity = diagnostic.severity;
  const fixable = diagnostic.fixable;

  if (fixed) {
    const reactions = [
      "Got it! That one's all cleaned up now.",
      "Fixed! One less thing to worry about.",
      "Done! Your code's looking better already.",
      "Patched that right up for you!",
    ];
    return reactions[Math.floor(Math.random() * reactions.length)];
  }

  if (severity === "error" && fixable) {
    const reactions = [
      "I see what happened — I think I can fix this for you!",
      "Ooh, spotted something! I have a fix ready if you want it.",
      "Found an error, but don't worry — I know how to fix this one.",
    ];
    return reactions[Math.floor(Math.random() * reactions.length)];
  }

  if (severity === "error" && !fixable) {
    const reactions = [
      "This one's tricky — let me show you what's going on.",
      "I spotted an error I'm not sure how to fix automatically. Let's look at it together.",
      "Hmm, this needs a human touch. Here's what I found...",
    ];
    return reactions[Math.floor(Math.random() * reactions.length)];
  }

  // Warning
  const reactions = [
    "Just a heads up — not urgent, but worth a look when you get a chance.",
    "Small thing! This warning won't break anything, but cleaning it up would be nice.",
  ];
  return reactions[Math.floor(Math.random() * reactions.length)];
}

// ───── AutoFixEngine Class ─────

export class AutoFixEngine {
  /** Attempt to generate a fix for a diagnostic */
  suggest(diagnostic: Diagnostic): FixResult {
    // Read the file to get surrounding context
    let fileLines: string[] = [];
    try {
      fileLines = readFileSync(diagnostic.file, "utf-8").split("\n");
    } catch {
      return {
        applied: false,
        diagnostic,
        fix: null,
        petReaction: "I can't read that file right now — is it still there?",
      };
    }

    // Try pattern-based fixes
    for (const pattern of ALL_FIX_PATTERNS) {
      if (pattern.match(diagnostic)) {
        const fix = pattern.fix(diagnostic, fileLines);
        if (fix) {
          return {
            applied: false,
            diagnostic,
            fix,
            petReaction: generatePetReaction(diagnostic, false),
          };
        }
      }
    }

    // No pattern match — generate an AI fix request
    const surroundingCode = this.getSurroundingCode(fileLines, diagnostic.line);
    return {
      applied: false,
      diagnostic,
      fix: null,
      aiFixRequest: {
        language: diagnostic.source,
        filePath: diagnostic.file,
        errorMessage: diagnostic.message,
        errorCode: diagnostic.code,
        errorLine: diagnostic.line,
        surroundingCode,
        instruction: `Fix the ${diagnostic.severity} on line ${diagnostic.line}: "${diagnostic.message}". Return ONLY the corrected code for the affected lines.`,
      },
      petReaction: generatePetReaction(diagnostic, false),
    };
  }

  /** Apply a fix to a file (write mode) */
  apply(diagnostic: Diagnostic): FixResult {
    const suggestion = this.suggest(diagnostic);
    if (!suggestion.fix || !suggestion.fix.replacement || !suggestion.fix.lineRange) {
      return suggestion; // Can't auto-apply
    }

    try {
      const fileContent = readFileSync(diagnostic.file, "utf-8");
      const lines = fileContent.split("\n");

      // Replace the affected line(s)
      const { start, end } = suggestion.fix.lineRange;
      const newLines = suggestion.fix.replacement.split("\n");
      lines.splice(start - 1, end - start + 1, ...newLines);

      writeFileSync(diagnostic.file, lines.join("\n"), "utf-8");

      return {
        applied: true,
        diagnostic,
        fix: suggestion.fix,
        petReaction: generatePetReaction(diagnostic, true),
      };
    } catch (err) {
      return {
        ...suggestion,
        applied: false,
        petReaction: "I tried to fix it but couldn't write to the file. Check permissions?",
      };
    }
  }

  /** Get code context around an error line */
  private getSurroundingCode(lines: string[], errorLine: number): string {
    const start = Math.max(0, errorLine - 6);
    const end = Math.min(lines.length, errorLine + 5);
    const contextLines: string[] = [];

    for (let i = start; i < end; i++) {
      const lineNum = i + 1;
      const marker = lineNum === errorLine ? " >>> " : "     ";
      contextLines.push(`${marker}${lineNum}: ${lines[i]}`);
    }

    return contextLines.join("\n");
  }
}
