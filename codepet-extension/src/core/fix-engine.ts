/**
 * Fix Engine — Context-Aware Error Fix Application
 * ──────────────────────────────────────────────────
 * Takes a TypeScript error code + document context, looks up the fix
 * strategy from the knowledge base, applies context overrides, and
 * generates the WorkspaceEdit to fix it.
 *
 * Safety features:
 *   - Import/export line detection (never mangle import tokens)
 *   - Anti-stacking guard (never add @ts-ignore above existing @ts-ignore)
 *   - Underscore-prefix guard (never stack _ on already-prefixed names)
 *   - Declaration vs expression context detection
 */

import * as vscode from "vscode";
import {
  getErrorKnowledge,
  FALLBACK_STRATEGY,
  type FixStrategy,
  type CodeContext,
  type ErrorKnowledge,
} from "./ts-error-codes";

// ───── Fix Request: everything the engine needs ─────

export interface FixRequest {
  doc: vscode.TextDocument;
  line: number;
  startChar: number;
  endLine: number;
  endChar: number;
  tsCode: number;
  message: string;
}

// ───── Fix Result: what the engine returns ─────

export interface FixResult {
  edit: vscode.WorkspaceEdit;
  description: string;
  success: boolean;
}

// ───── Context Detection ─────

function detectContexts(doc: vscode.TextDocument, line: number, identText: string): Set<CodeContext> {
  const contexts = new Set<CodeContext>();
  const lineText = doc.lineAt(line).text;

  // Import line: import X from Y, const X = require(Y), require(Y)
  if (/^\s*(import\s|const\s+\w+\s*=\s*require\s*\(|require\s*\()/.test(lineText)) {
    contexts.add("import-line");
  }

  // Export line: export { X, Y, Z }
  if (/^\s*export\s*\{/.test(lineText)) {
    contexts.add("export-line");
  }

  // Already prefixed with underscore
  if (identText.startsWith("_")) {
    contexts.add("already-prefixed");
  }

  // Return statement
  if (lineText.trim().startsWith("return ")) {
    contexts.add("return-statement");
  }

  // No type annotation on variable declaration (let x = null)
  if (/^\s*(let|var|const)\s+\w+\s*=\s*(null|undefined)\s*;/.test(lineText)) {
    contexts.add("no-type-annotation");
  }

  return contexts;
}

// ───── Anti-Stacking Guard ─────

function hasIgnoreNearby(doc: vscode.TextDocument, targetLine: number): boolean {
  for (let i = 1; i <= 3 && targetLine - i >= 0; i++) {
    const above = doc.lineAt(targetLine - i).text;
    if (above.includes("@ts-ignore") || above.includes("@ts-expect-error")) {
      return true;
    }
    // Stop at real code (not comments or blank lines)
    if (above.trim() !== "" && !above.trim().startsWith("//")) break;
  }
  return false;
}

// ───── Resolve Strategy: apply context overrides ─────

function resolveStrategy(knowledge: ErrorKnowledge | undefined, contexts: Set<CodeContext>): FixStrategy {
  if (!knowledge) return FALLBACK_STRATEGY;

  // Check context overrides (first match wins)
  if (knowledge.contextOverrides) {
    for (const override of knowledge.contextOverrides) {
      if (contexts.has(override.when)) {
        return override.strategy;
      }
    }
  }

  return knowledge.strategy;
}

// ───── Extract message groups ─────

function extractMessageGroups(message: string, pattern?: RegExp): string[] {
  if (!pattern) return [];
  const match = message.match(pattern);
  return match ? match.slice(1) : [];
}

// ───── The Fix Engine ─────

export function applyFix(req: FixRequest): FixResult {
  const { doc, line: diagLine, tsCode, message } = req;
  const lineText = doc.lineAt(diagLine).text;
  const indent = lineText.match(/^(\s*)/)?.[1] ?? "";
  const diagRange = new vscode.Range(req.line, req.startChar, req.endLine, req.endChar);
  let identText = doc.getText(diagRange);

  // If range is empty/zero (sidebar didn't have range data), extract name from message
  if (!identText || identText.trim() === "") {
    const nameFromMsg = message.match(/'([^']+?)'/);
    if (nameFromMsg) {
      identText = nameFromMsg[1];
    }
  }

  const edit = new vscode.WorkspaceEdit();
  let description = "";

  // Look up knowledge
  const knowledge = getErrorKnowledge(tsCode);
  const contexts = detectContexts(doc, diagLine, identText);
  const strategy = resolveStrategy(knowledge, contexts);
  const groups = extractMessageGroups(message, knowledge?.messagePattern);

  // ── Import-line global guard ──
  // For import lines, MOST strategies should become @ts-ignore
  // Only allow: add-module-ignore, ts-ignore, remove-stale-directive
  const safeImportStrategies = new Set(["ts-ignore", "add-module-ignore", "remove-stale-directive", "remove-line"]);
  const effectiveStrategy = (contexts.has("import-line") && !safeImportStrategies.has(strategy.type))
    ? { type: "ts-ignore" as const, reason: `TS${tsCode} on import line` }
    : strategy;

  // ── Apply the strategy ──
  switch (effectiveStrategy.type) {

    case "ts-ignore": {
      if (!hasIgnoreNearby(doc, diagLine)) {
        const reason = effectiveStrategy.reason ?? `TS${tsCode}`;
        edit.insert(doc.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — ${reason}\n`);
        description = `Added @ts-ignore for TS${tsCode}`;
      } else {
        // @ts-ignore already exists — the diagnostic is likely stale (already suppressed)
        // Mark as success so the caller knows to just rescan
        description = `Already suppressed: TS${tsCode}`;
      }
      break;
    }

    case "add-module-ignore": {
      if (!hasIgnoreNearby(doc, diagLine)) {
        const moduleName = groups[0] ?? "module";
        edit.insert(doc.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — module '${moduleName}' not installed locally\n`);
        description = `Added @ts-ignore for module '${moduleName}'`;
      } else {
        description = `Already suppressed: module import`;
      }
      break;
    }

    case "remove-line": {
      edit.delete(doc.uri, new vscode.Range(diagLine, 0, diagLine + 1, 0));
      description = `Removed broken line`;
      break;
    }

    case "remove-stale-directive": {
      edit.delete(doc.uri, new vscode.Range(diagLine, 0, diagLine + 1, 0));
      description = `Removed stale directive`;
      break;
    }

    case "remove-from-list": {
      const nameToRemove = groups[0] ?? identText;
      if (nameToRemove) {
        let newLine = lineText;
        // Remove "name, " (item followed by comma)
        newLine = newLine.replace(new RegExp(`\\b${escapeRegex(nameToRemove)}\\b,\\s*`), "");
        if (newLine === lineText) {
          // Remove ", name" (comma before item)
          newLine = newLine.replace(new RegExp(`,\\s*\\b${escapeRegex(nameToRemove)}\\b`), "");
        }
        if (newLine !== lineText) {
          edit.replace(doc.uri, new vscode.Range(diagLine, 0, diagLine, lineText.length), newLine);
          description = `Removed '${nameToRemove}' from list`;
        } else {
          // Last item — remove entire line
          edit.delete(doc.uri, new vscode.Range(diagLine, 0, diagLine + 1, 0));
          description = `Removed empty export/import line`;
        }
      }
      break;
    }

    case "prefix-underscore": {
      if (identText && !identText.startsWith("_")) {
        // If diagRange is zero-width (name came from message), find it in the line
        const rangeIsZero = req.startChar === 0 && req.endChar === 0;
        if (rangeIsZero) {
          const idx = lineText.indexOf(identText);
          if (idx >= 0) {
            const replaceRange = new vscode.Range(diagLine, idx, diagLine, idx + identText.length);
            edit.replace(doc.uri, replaceRange, `_${identText}`);
            description = `Prefixed unused: _${identText}`;
          }
        } else {
          edit.replace(doc.uri, diagRange, `_${identText}`);
          description = `Prefixed unused: _${identText}`;
        }
      } else if (identText) {
        // Already prefixed with _ — try @ts-ignore first
        if (!hasIgnoreNearby(doc, diagLine)) {
          edit.insert(doc.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — '${identText}' intentionally unused\n`);
          description = `Added @ts-ignore for unused '${identText}'`;
        } else {
          // @ts-ignore already present — remove the @ts-ignore AND the declaration line
          // (both lines: the directive above + the unused declaration)
          // Find the @ts-ignore line above
          let ignoreLineIdx = -1;
          for (let i = 1; i <= 3 && diagLine - i >= 0; i++) {
            const above = doc.lineAt(diagLine - i).text;
            if (above.includes("@ts-ignore") || above.includes("@ts-expect-error")) {
              ignoreLineIdx = diagLine - i;
              break;
            }
            if (above.trim() !== "" && !above.trim().startsWith("//")) break;
          }
          if (ignoreLineIdx >= 0) {
            // Delete both the @ts-ignore line and the declaration line
            edit.delete(doc.uri, new vscode.Range(ignoreLineIdx, 0, diagLine + 1, 0));
            description = `Removed unused '${identText}' and its @ts-ignore`;
          } else {
            // Just remove the declaration
            edit.delete(doc.uri, new vscode.Range(diagLine, 0, diagLine + 1, 0));
            description = `Removed unused declaration: ${identText}`;
          }
        }
      }
      break;
    }

    case "add-type-annotation": {
      if (identText) {
        const rangeIsZero = req.startChar === 0 && req.endChar === 0;
        if (rangeIsZero) {
          // Find the identifier in the line and insert : any after it
          // For function params: function foo(name, age) → function foo(name: any, age: any)
          // For variables: let x = ... → let x: any = ...
          const idx = lineText.indexOf(identText);
          if (idx >= 0) {
            const afterIdent = idx + identText.length;
            // Check if there's already a type annotation
            const afterText = lineText.substring(afterIdent);
            if (!afterText.match(/^\s*:/)) {
              edit.insert(doc.uri, new vscode.Position(diagLine, afterIdent), ": any");
              description = `Added type: ${identText}: any`;
            }
          }
        } else {
          edit.insert(doc.uri, new vscode.Position(req.endLine, req.endChar), ": any");
          description = `Added type: ${identText}: any`;
        }
      }
      break;
    }

    case "cast-as-any": {
      if (identText) {
        edit.replace(doc.uri, diagRange, `(${identText} as any)`);
        description = `Cast: (${identText} as any)`;
      }
      break;
    }

    case "add-non-null-assert": {
      if (identText) {
        edit.replace(doc.uri, diagRange, `${identText}!`);
        description = `Non-null assertion: ${identText}!`;
      }
      break;
    }

    case "change-type": {
      // TS2322: Type 'X' is not assignable to type 'Y'
      const [fromType] = groups;
      if (fromType) {
        // Case 1: Variable with type annotation — const x: string = 42;
        const typeAnnotationMatch = lineText.match(/:\s*(\w+)\s*=/);
        if (typeAnnotationMatch && typeAnnotationMatch.index !== undefined) {
          const colonIdx = lineText.indexOf(":", typeAnnotationMatch.index);
          const afterColon = lineText.substring(colonIdx + 1);
          const typeOffset = afterColon.match(/^\s*/)![0].length;
          const typeStart = colonIdx + 1 + typeOffset;
          const typeEnd = typeStart + typeAnnotationMatch[1].length;
          edit.replace(doc.uri, new vscode.Range(diagLine, typeStart, diagLine, typeEnd), fromType);
          description = `Changed type: ${typeAnnotationMatch[1]} → ${fromType}`;
        }
        // Case 2: Return statement — handled by context override
        // Case 3: No type annotation (null-inferred) — handled by context override
        // Fallback: @ts-ignore
        else if (!description) {
          if (!hasIgnoreNearby(doc, diagLine)) {
            edit.insert(doc.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — type mismatch\n`);
            description = `Added @ts-ignore for type mismatch`;
          }
        }
      }
      break;
    }

    case "fix-return-type": {
      // Search upward for function declaration with return type
      for (let s = diagLine; s >= Math.max(0, diagLine - 30); s--) {
        const funcLine = doc.lineAt(s).text;
        const retTypeMatch = funcLine.match(/\)\s*:\s*(\w+)\s*\{?\s*$/);
        if (retTypeMatch && retTypeMatch.index !== undefined) {
          const colonIdx = funcLine.indexOf(":", retTypeMatch.index + 1);
          const afterColon = funcLine.substring(colonIdx + 1);
          const typeOffset = afterColon.match(/^\s*/)![0].length;
          const typeStart = colonIdx + 1 + typeOffset;
          const typeEnd = typeStart + retTypeMatch[1].length;
          const newType = groups[0] ?? "any";
          edit.replace(doc.uri, new vscode.Range(s, typeStart, s, typeEnd), newType);
          description = `Changed return type: ${retTypeMatch[1]} → ${newType}`;
          break;
        }
        if (s < diagLine && /^\s*(function|class|const\s+\w+\s*=|export)\b/.test(funcLine)) break;
      }
      if (!description) {
        // Fallback: @ts-ignore
        if (!hasIgnoreNearby(doc, diagLine)) {
          edit.insert(doc.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — return type mismatch\n`);
          description = `Added @ts-ignore for return type`;
        }
      }
      break;
    }

    case "search-fix-declaration": {
      // TS2322 on assignment to null-inferred variable: add : any to declaration
      const assignVarMatch = lineText.match(/^\s*(\w+)\s*=/);
      if (assignVarMatch) {
        const varName = assignVarMatch[1];
        for (let s = diagLine - 1; s >= Math.max(0, diagLine - 50); s--) {
          const declLine = doc.lineAt(s).text;
          const declMatch = declLine.match(new RegExp(`(var|let|const)\\s+${escapeRegex(varName)}\\s*=\\s*(null|undefined)`));
          if (declMatch && declMatch.index !== undefined) {
            const nameStart = declLine.indexOf(varName, declMatch.index);
            edit.insert(doc.uri, new vscode.Position(s, nameStart + varName.length), ": any");
            description = `Added type: ${varName}: any`;
            break;
          }
        }
      }
      if (!description) {
        if (!hasIgnoreNearby(doc, diagLine)) {
          edit.insert(doc.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — type mismatch\n`);
          description = `Added @ts-ignore for type mismatch`;
        }
      }
      break;
    }

    case "cast-argument": {
      // TS2345: Argument type mismatch — cast as target type
      const [, targetType] = groups;
      if (targetType && identText) {
        edit.replace(doc.uri, diagRange, `(${identText} as ${targetType})`);
        description = `Cast argument: (${identText} as ${targetType})`;
      }
      break;
    }

    case "cast-object": {
      // TS2339: Property doesn't exist — cast object as any
      const beforeDot = lineText.substring(0, req.startChar);
      const objMatch = beforeDot.match(/(\w+)\.\s*$/);
      if (objMatch && objMatch.index !== undefined) {
        edit.replace(doc.uri,
          new vscode.Range(diagLine, objMatch.index, diagLine, objMatch.index + objMatch[1].length),
          `(${objMatch[1]} as any)`
        );
        description = `Cast: (${objMatch[1]} as any).${identText}`;
      }
      break;
    }

    case "fix-typo": {
      // TS2552: Did you mean 'Y'?
      const suggestedName = groups[1] ?? groups[2]; // groups[2] for TS2551
      if (suggestedName && identText) {
        edit.replace(doc.uri, diagRange, suggestedName);
        description = `Fixed typo: ${identText} → ${suggestedName}`;
      }
      break;
    }

    case "rename-duplicate": {
      // TS2451: Rename by appending _1
      const varName = groups[0] ?? identText;
      if (varName) {
        const varIdx = lineText.indexOf(varName);
        if (varIdx >= 0) {
          edit.replace(doc.uri, new vscode.Range(diagLine, varIdx, diagLine, varIdx + varName.length), `${varName}_1`);
          description = `Renamed duplicate: ${varName} → ${varName}_1`;
        }
      }
      break;
    }

    case "init-variable": {
      // TS2454: Variable used before assigned — find declaration and add initializer
      const varName = groups[0];
      if (varName) {
        let fixed = false;
        for (let s = diagLine - 1; s >= Math.max(0, diagLine - 50); s--) {
          const declLine = doc.lineAt(s).text;
          // Match: let varName: Type; or let varName;
          const declMatch = declLine.match(new RegExp(`(let|var|const)\\s+${escapeRegex(varName)}\\s*(:\\s*\\w+)?\\s*;`));
          if (declMatch) {
            const semiIdx = declLine.lastIndexOf(";");
            if (semiIdx >= 0) {
              edit.replace(doc.uri, new vscode.Range(s, semiIdx, s, semiIdx + 1), " = undefined as any;");
              description = `Initialized: ${varName} = undefined`;
              fixed = true;
            }
            break;
          }
        }
        if (!fixed && !hasIgnoreNearby(doc, diagLine)) {
          edit.insert(doc.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — variable used before assignment\n`);
          description = `Added @ts-ignore for '${varName}'`;
        }
      }
      break;
    }

    case "replace-line": {
      // TS2456: Circular type alias — replace with type X = any
      const aliasName = groups[0];
      if (aliasName) {
        edit.replace(doc.uri, new vscode.Range(diagLine, 0, diagLine, lineText.length), `${indent}type ${aliasName} = any;`);
        description = `Fixed circular type: type ${aliasName} = any`;
      }
      break;
    }
  }

  return {
    edit,
    description,
    success: description !== "",
  };
}

// ───── Regex escape helper ─────

function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
