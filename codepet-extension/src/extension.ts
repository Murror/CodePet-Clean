/**
 * Codepet Extension — Entry point
 *
 * Works on: VS Code, Cursor, Windsurf, VSCodium, and any VS Code fork.
 * Activates the Codepet sidebar, status bar, session tracker,
 * file watcher, trigger engine, and real-time code scanner.
 */

import * as vscode from "vscode";
import { FileWatcher } from "./core/file-watcher.js";
import { SessionTracker } from "./core/session-tracker.js";
import { TriggerEngine } from "./core/trigger-engine.js";
import { CodeScanner } from "./core/code-scanner.js";
import { PetReactionEngine } from "./core/pet-reactions.js";
import * as fixEngine from "./core/fix-engine.js";
import { StatusBar } from "./ui/status-bar.js";
import { SidebarProvider } from "./ui/sidebar-provider.js";
import { WelcomePanel } from "./ui/welcome-panel.js";
import type { WelcomeStats } from "./ui/welcome-panel.js";
import { CloudSync } from "./services/cloud-sync.js";
import { LessonService } from "./services/lesson-service.js";

let fileWatcher: FileWatcher;
let sessionTracker: SessionTracker;
let triggerEngine: TriggerEngine;
let codeScanner: CodeScanner;
let petReactions: PetReactionEngine;
let statusBar: StatusBar;
let cloudSync: CloudSync;
let lessonService: LessonService;

export function activate(context: vscode.ExtensionContext): void {
  const outputChannel = vscode.window.createOutputChannel("Codepet");
  outputChannel.appendLine("[Codepet] Extension activating...");

  // ───── Core modules ─────
  fileWatcher = new FileWatcher();
  sessionTracker = new SessionTracker();
  triggerEngine = new TriggerEngine(fileWatcher, sessionTracker);

  // ───── Cloud Sync (auto-detects macOS app account) ─────
  cloudSync = new CloudSync(outputChannel);

  // Pet name: prefer macOS app account → fall back to extension setting
  // Capitalize first letter for display (e.g., "byte" → "Byte")
  const rawPetName = cloudSync.petName
    || vscode.workspace.getConfiguration("codepet").get<string>("petName")
    || "Nova";
  const petName = rawPetName.charAt(0).toUpperCase() + rawPetName.slice(1);

  // User name: prefer macOS app account → extension setting → macOS login name → "Coder"
  let userName = cloudSync.userName
    || vscode.workspace.getConfiguration("codepet").get<string>("userName")
    || "";

  // If still empty or has encoding issues, try cleaner approaches
  if (!userName || /\\u|\\[0-9]/.test(userName)) {
    userName = ""; // reset garbled name
    const { execSync } = require("child_process");

    // Try 1: scutil ComputerName → "Monas-MacBook-Air" → "Mona"
    for (const cmd of [
      "/usr/sbin/scutil --get ComputerName 2>/dev/null",
      "scutil --get ComputerName 2>/dev/null",
    ]) {
      if (userName) break;
      try {
        const hostname = execSync(cmd, { encoding: "utf-8", timeout: 2000 }).trim();
        outputChannel.appendLine(`[Codepet] ComputerName: "${hostname}"`);
        const hostMatch = hostname.match(/^(\w+?)s?[-\s]/i);
        if (hostMatch && hostMatch[1].length >= 3) {
          userName = hostMatch[1].charAt(0).toUpperCase() + hostMatch[1].slice(1).toLowerCase();
        }
      } catch { /* try next */ }
    }

    // Try 2: whoami → "monatruong" → "Mona"
    if (!userName) {
      try {
        const whoami = execSync("/usr/bin/whoami 2>/dev/null", { encoding: "utf-8", timeout: 2000 }).trim();
        outputChannel.appendLine(`[Codepet] whoami: "${whoami}"`);
        // Extract first part before common suffixes
        const nameMatch = whoami.match(/^([a-z]{3,})/i);
        if (nameMatch) {
          // Take first 4-6 chars as likely first name
          const raw = nameMatch[1];
          const name = raw.length > 6 ? raw.substring(0, 4) : raw;
          userName = name.charAt(0).toUpperCase() + name.slice(1).toLowerCase();
        }
      } catch { /* ignore */ }
    }
  }
  if (!userName) userName = "Coder";

  if (cloudSync.isConfigured) {
    outputChannel.appendLine(
      `[Codepet] Linked to macOS app — welcome, ${userName}! (pet: ${petName})`
    );
  }

  // ───── Code Scanner (Grammarly-like real-time analysis) ─────
  codeScanner = new CodeScanner();
  petReactions = new PetReactionEngine(petName);

  // ── Gutter decoration for error lines (Byte's paw mark) ──
  const errorGutter = vscode.window.createTextEditorDecorationType({
    gutterIconPath: vscode.Uri.joinPath(context.extensionUri, "media", "codepet-icon.svg"),
    gutterIconSize: "contain",
    overviewRulerColor: "#f85149",
    overviewRulerLane: vscode.OverviewRulerLane.Right,
  });
  const warningGutter = vscode.window.createTextEditorDecorationType({
    gutterIconPath: vscode.Uri.joinPath(context.extensionUri, "media", "codepet-icon.svg"),
    gutterIconSize: "contain",
    overviewRulerColor: "#e3b341",
    overviewRulerLane: vscode.OverviewRulerLane.Right,
  });
  context.subscriptions.push(errorGutter, warningGutter);

  // ── Auto-fixable pattern IDs (must match SidebarProvider.AUTO_FIXABLE) ──
  const AUTO_FIXABLE_CODES = new Set([
    "debugger-statement", "console-log", "python-print", "python-pass-only",
    "swift-print", "go-fmt-println", "var-declaration", "triple-equals",
    "loose-inequality", "any-type", "todo-comment", "fixme-comment",
    "python-todo", "empty-catch", "python-bare-except", "nested-ternary",
    "magic-number", "html-missing-alt",
    "swift-force-unwrap", "swift-force-cast", "rust-unwrap", "go-ignored-error",
  ]);

  // ── Update gutter decorations when scan completes ──
  context.subscriptions.push(
    codeScanner.onScanComplete((result) => {
      const editor = vscode.window.activeTextEditor;
      if (!editor || editor.document.uri.toString() !== result.uri) return;

      const errorRanges: vscode.DecorationOptions[] = [];
      const warningRanges: vscode.DecorationOptions[] = [];

      for (const f of result.findings) {
        if (f.severity === "clean") continue;
        const range = new vscode.Range(f.line, f.column, f.line, f.column + 1);

        // Build hover with fix link for auto-fixable issues
        const isFixable = f.source === "pattern" && AUTO_FIXABLE_CODES.has(f.code);
        let hoverText = `🐾 **${petName}:** ${f.message}`;
        if (f.suggestion) hoverText += `\n\n💡 ${f.suggestion}`;
        if (isFixable) {
          const args = encodeURIComponent(JSON.stringify({ line: f.line, code: f.code, source: f.source }));
          hoverText += `\n\n[🐾 **Auto-fix this**](command:codepet.fixAtLine?${args})`;
        }
        const hoverMessage = new vscode.MarkdownString(hoverText);
        hoverMessage.isTrusted = true;

        const decoration: vscode.DecorationOptions = { range, hoverMessage };
        if (f.severity === "error") {
          errorRanges.push(decoration);
        } else {
          warningRanges.push(decoration);
        }
      }

      editor.setDecorations(errorGutter, errorRanges);
      editor.setDecorations(warningGutter, warningRanges);
    })
  );

  // Clear decorations when switching files
  context.subscriptions.push(
    vscode.window.onDidChangeActiveTextEditor(() => {
      // Decorations auto-clear on editor switch; new scan will re-apply
    })
  );

  // ── CodeAction provider — puts Codepet fixes in the Quick Fix lightbulb menu ──
  // Handles BOTH pattern-based findings AND TypeScript diagnostic errors.
  // Key: uses WorkspaceEdit directly on CodeAction (no command indirection)
  // so VS Code can preview and apply edits reliably.
  const codeActionSelector: vscode.DocumentSelector = [
    { language: "typescript", scheme: "file" },
    { language: "typescriptreact", scheme: "file" },
    { language: "javascript", scheme: "file" },
    { language: "javascriptreact", scheme: "file" },
    { language: "python", scheme: "file" },
    { language: "swift", scheme: "file" },
    { language: "rust", scheme: "file" },
    { language: "go", scheme: "file" },
    { language: "java", scheme: "file" },
    { language: "html", scheme: "file" },
  ];
  context.subscriptions.push(
    vscode.languages.registerCodeActionsProvider(codeActionSelector, {
      provideCodeActions(document, range, actionContext): vscode.CodeAction[] | undefined {
        const startLine = range.start.line;
        const endLine = range.end.line;
        const actions: vscode.CodeAction[] = [];

        outputChannel.appendLine(`[Codepet CodeAction] provideCodeActions called for lines ${startLine}-${endLine}`);

        // ── Part 1: Pattern-based findings from Codepet scanner ──
        const uri = document.uri.toString();
        const scanResult = codeScanner.getResultForUri(uri);
        if (scanResult) {
          const patternLabels: Record<string, string> = {
            "debugger-statement": "Remove debugger statement",
            "console-log": "Remove console.log",
            "python-print": "Remove print()",
            "swift-print": "Remove print()",
            "go-fmt-println": "Remove fmt.Println",
            "python-pass-only": "Remove empty pass",
            "todo-comment": "Remove TODO comment",
            "fixme-comment": "Remove FIXME comment",
            "python-todo": "Remove TODO comment",
            "var-declaration": "Change var → let",
            "triple-equals": "Change == → ===",
            "loose-inequality": "Change != → !==",
            "any-type": "Remove explicit : any annotation",
            "empty-catch": "Add error logging to catch block",
            "python-bare-except": "Add specific exception type",
            "html-missing-alt": "Add alt attribute",
            "swift-force-unwrap": "Replace force unwrap with ?? nil",
            "swift-force-cast": "Change force cast to optional cast",
            "rust-unwrap": "Change .unwrap() to .unwrap_or_default()",
            "go-ignored-error": "Handle ignored error",
          };

          for (const f of scanResult.findings) {
            if (f.severity === "clean") continue;
            if (f.line < startLine || f.line > endLine) continue;
            const isAutoFixable = f.source === "pattern" && AUTO_FIXABLE_CODES.has(f.code);
            if (!isAutoFixable) continue;

            const label = `🐾 ${petName}: ${patternLabels[f.code] ?? "Auto-fix this"}`;
            const action = new vscode.CodeAction(label, vscode.CodeActionKind.QuickFix);
            action.command = {
              command: "codepet.fixAtLine",
              title: label,
              arguments: [{ line: f.line, code: f.code, source: f.source }],
            };
            action.isPreferred = true;
            actions.push(action);
          }
        }

        outputChannel.appendLine(`[Codepet CodeAction] Part 1 found ${actions.length} pattern-based actions`);

        // ── Part 2: TypeScript diagnostic errors — inline WorkspaceEdit fixes ──
        // Use context.diagnostics (the diagnostics VS Code passes for this range)
        // plus a full scan for comprehensive coverage
        const contextDiags = actionContext.diagnostics ?? [];
        const globalDiags = vscode.languages.getDiagnostics(document.uri) ?? [];
        outputChannel.appendLine(`[Codepet CodeAction] context.diagnostics: ${contextDiags.length}, global diagnostics: ${globalDiags.length}`);

        const allDiagnostics = [
          ...contextDiags,
          ...globalDiags.filter(d => d.range.start.line >= startLine && d.range.start.line <= endLine),
        ];
        // Deduplicate by message + line
        const seen = new Set<string>();

        for (const diag of allDiagnostics) {
          if (diag.range.start.line < startLine || diag.range.start.line > endLine) continue;
          const tsCode = typeof diag.code === "number" ? diag.code
            : typeof diag.code === "object" && diag.code !== null ? Number((diag.code as any).value) : 0;
          outputChannel.appendLine(`[Codepet CodeAction] Diag: code=${JSON.stringify(diag.code)}, tsCode=${tsCode}, msg="${diag.message.substring(0, 60)}"`);
          if (!tsCode) continue;

          const dedup = `${tsCode}:${diag.range.start.line}:${diag.range.start.character}`;
          if (seen.has(dedup)) continue;
          seen.add(dedup);

          const lineText = document.lineAt(diag.range.start.line).text;
          const diagLine = diag.range.start.line;
          const msg = diag.message;
          const indent = lineText.match(/^(\s*)/)?.[1] ?? "";

          switch (tsCode) {
            // TS2571/18046/18047/18048: 'X' is of type 'unknown'
            case 2571:
            case 18046:
            case 18047:
            case 18048: {
              const identText = document.getText(diag.range);
              if (identText) {
                const wsEdit = new vscode.WorkspaceEdit();
                wsEdit.replace(document.uri, diag.range, `(${identText} as any)`);
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Add type assertion (${identText} as any)`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                actions.push(action);
              }
              break;
            }

            // TS2322: Type 'X' is not assignable to type 'Y'
            case 2322: {
              const assignMatch = msg.match(/Type '(.+?)' is not assignable to type '(.+?)'/);
              if (assignMatch) {
                const [, fromType, toType] = assignMatch;

                // Case 1: Variable assignment — const x: string = 42;
                const typeAnnotationMatch = lineText.match(/:\s*(\w+)\s*=/);
                if (typeAnnotationMatch && typeAnnotationMatch.index !== undefined) {
                  const colonIdx = lineText.indexOf(":", typeAnnotationMatch.index);
                  const typeStartIdx = colonIdx + lineText.substring(colonIdx + 1).match(/^\s*/)![0].length + 1;
                  const typeEndIdx = typeStartIdx + typeAnnotationMatch[1].length;
                  const wsEdit = new vscode.WorkspaceEdit();
                  wsEdit.replace(document.uri,
                    new vscode.Range(diagLine, typeStartIdx, diagLine, typeEndIdx),
                    fromType
                  );
                  const action = new vscode.CodeAction(
                    `🐾 ${petName}: Change type to '${fromType}'`,
                    vscode.CodeActionKind.QuickFix
                  );
                  action.edit = wsEdit;
                  action.diagnostics = [diag];
                  action.isPreferred = true;
                  actions.push(action);

                  // Also offer cast
                  const semiIndex = lineText.indexOf(";", lineText.indexOf("="));
                  if (semiIndex >= 0) {
                    const wsEdit2 = new vscode.WorkspaceEdit();
                    wsEdit2.insert(document.uri, new vscode.Position(diagLine, semiIndex), ` as ${toType}`);
                    const action2 = new vscode.CodeAction(
                      `🐾 ${petName}: Cast value as ${toType}`,
                      vscode.CodeActionKind.QuickFix
                    );
                    action2.edit = wsEdit2;
                    action2.diagnostics = [diag];
                    actions.push(action2);
                  }
                }
                // Case 2: Return statement — find function declaration and change return type
                else if (lineText.trim().startsWith("return ")) {
                  for (let sl = diagLine - 1; sl >= Math.max(0, diagLine - 30); sl--) {
                    const funcLine = document.lineAt(sl).text;
                    const retTypeMatch = funcLine.match(/\)\s*:\s*(\w+)\s*\{?\s*$/);
                    if (retTypeMatch && retTypeMatch.index !== undefined) {
                      const colonIdx = funcLine.indexOf(":", retTypeMatch.index + 1);
                      const afterColon = funcLine.substring(colonIdx + 1);
                      const typeOff = afterColon.match(/^\s*/)![0].length;
                      const tStart = colonIdx + 1 + typeOff;
                      const tEnd = tStart + retTypeMatch[1].length;
                      const wsEdit = new vscode.WorkspaceEdit();
                      wsEdit.replace(document.uri, new vscode.Range(sl, tStart, sl, tEnd), fromType);
                      const action = new vscode.CodeAction(
                        `🐾 ${petName}: Change return type to '${fromType}'`,
                        vscode.CodeActionKind.QuickFix
                      );
                      action.edit = wsEdit;
                      action.diagnostics = [diag];
                      action.isPreferred = true;
                      actions.push(action);
                      break;
                    }
                    if (/^\s*(function|class|const\s+\w+\s*=|export)\b/.test(funcLine) && sl < diagLine - 1) break;
                  }
                }
              }
              break;
            }

            // TS2345: Argument of type 'X' is not assignable to parameter of type 'Y'
            case 2345: {
              const argMatch = msg.match(/Argument of type '(.+?)' is not assignable to parameter of type '(.+?)'/);
              if (argMatch) {
                const identText = document.getText(diag.range);
                const wsEdit = new vscode.WorkspaceEdit();
                wsEdit.replace(document.uri, diag.range, `(${identText} as ${argMatch[2]})`);
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Cast argument as ${argMatch[2]}`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                actions.push(action);
              }
              break;
            }

            // TS2304: Cannot find name 'X'
            case 2304: {
              const nameMatch = msg.match(/Cannot find name '(.+?)'/);
              if (nameMatch) {
                const varName = nameMatch[1];
                const wsEdit = new vscode.WorkspaceEdit();
                wsEdit.insert(document.uri, new vscode.Position(diagLine, 0), `${indent}let ${varName}: any;\n`);
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Declare '${varName}' as let`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                actions.push(action);
              }
              break;
            }

            // TS2339: Property 'X' does not exist on type 'Y'
            case 2339: {
              const propMatch = msg.match(/Property '(.+?)' does not exist on type '(.+?)'/);
              if (propMatch) {
                const beforeDot = lineText.substring(0, diag.range.start.character);
                const objMatch = beforeDot.match(/(\w+)\.\s*$/);
                if (objMatch && objMatch.index !== undefined) {
                  const wsEdit = new vscode.WorkspaceEdit();
                  wsEdit.replace(document.uri,
                    new vscode.Range(diagLine, objMatch.index, diagLine, objMatch.index + objMatch[1].length),
                    `(${objMatch[1]} as any)`
                  );
                  const action = new vscode.CodeAction(
                    `🐾 ${petName}: Cast '${objMatch[1]}' as any`,
                    vscode.CodeActionKind.QuickFix
                  );
                  action.edit = wsEdit;
                  action.diagnostics = [diag];
                  actions.push(action);
                }
              }
              break;
            }

            // TS7006: Parameter 'x' implicitly has an 'any' type
            case 7006: {
              const paramMatch = msg.match(/Parameter '(.+?)' implicitly has an 'any' type/);
              if (paramMatch) {
                const wsEdit = new vscode.WorkspaceEdit();
                wsEdit.insert(document.uri, new vscode.Position(diag.range.end.line, diag.range.end.character), ": any");
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Add ': any' type to '${paramMatch[1]}'`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                actions.push(action);
              }
              break;
            }

            // TS2552: Cannot find name 'X'. Did you mean 'Y'?
            case 2552: {
              const typoMatch = msg.match(/Cannot find name '(.+?)'. Did you mean '(.+?)'/);
              if (typoMatch) {
                const [, wrongName, rightName] = typoMatch;
                const wsEdit = new vscode.WorkspaceEdit();
                wsEdit.replace(document.uri, diag.range, rightName);
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Fix typo → '${rightName}'`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                action.isPreferred = true;
                actions.push(action);
              }
              break;
            }

            // TS2355/2366: Return type mismatch
            case 2355:
            case 2366: {
              const retMatch = lineText.match(/\):\s*(\w+)/);
              if (retMatch && retMatch.index !== undefined) {
                const colonIdx = lineText.indexOf(":", retMatch.index + 1);
                const afterColon = lineText.substring(colonIdx + 1);
                const typeOffset = afterColon.match(/^\s*/)![0].length;
                const typeStart = colonIdx + 1 + typeOffset;
                const typeEnd = typeStart + retMatch[1].length;
                const wsEdit = new vscode.WorkspaceEdit();
                wsEdit.replace(document.uri, new vscode.Range(diagLine, typeStart, diagLine, typeEnd), "any");
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Change return type to 'any'`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                actions.push(action);
              }
              break;
            }

            // TS2307: Cannot find module
            case 2307: {
              const wsEdit = new vscode.WorkspaceEdit();
              wsEdit.insert(document.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — module not installed locally\n`);
              const modMatch = msg.match(/Cannot find module '(.+?)'/);
              const action = new vscode.CodeAction(
                `🐾 ${petName}: Add @ts-ignore for '${modMatch?.[1] ?? "module"}'`,
                vscode.CodeActionKind.QuickFix
              );
              action.edit = wsEdit;
              action.diagnostics = [diag];
              actions.push(action);
              break;
            }

            // TS2580/2584: Cannot find name 'require'/'console'
            case 2580:
            case 2584: {
              const wsEdit = new vscode.WorkspaceEdit();
              wsEdit.insert(document.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — needs @types/node\n`);
              const nameMatch2 = msg.match(/Cannot find name '(.+?)'/);
              const action = new vscode.CodeAction(
                `🐾 ${petName}: Add @ts-ignore for '${nameMatch2?.[1] ?? "name"}'`,
                vscode.CodeActionKind.QuickFix
              );
              action.edit = wsEdit;
              action.diagnostics = [diag];
              actions.push(action);
              break;
            }

            // TS7005/7015/7031: Variable implicitly has 'any' type
            case 7005:
            case 7015:
            case 7031: {
              const wsEdit = new vscode.WorkspaceEdit();
              wsEdit.insert(document.uri, new vscode.Position(diag.range.end.line, diag.range.end.character), ": any");
              const identT = document.getText(diag.range);
              const action = new vscode.CodeAction(
                `🐾 ${petName}: Add type annotation to '${identT}'`,
                vscode.CodeActionKind.QuickFix
              );
              action.edit = wsEdit;
              action.diagnostics = [diag];
              actions.push(action);
              break;
            }

            // TS18047: 'X' is possibly 'null'
            case 18047: {
              const identT = document.getText(diag.range);
              if (identT) {
                const wsEdit = new vscode.WorkspaceEdit();
                wsEdit.replace(document.uri, diag.range, `${identT}!`);
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Add non-null assertion (${identT}!)`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                actions.push(action);
              }
              break;
            }

            // TS18048: 'X' is possibly 'undefined'
            case 18048: {
              const identT = document.getText(diag.range);
              if (identT) {
                const wsEdit = new vscode.WorkspaceEdit();
                wsEdit.replace(document.uri, diag.range, `${identT}!`);
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Add non-null assertion (${identT}!)`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                actions.push(action);
              }
              break;
            }

            // TS2454: Variable used before being assigned
            case 2454: {
              const wsEdit = new vscode.WorkspaceEdit();
              wsEdit.insert(document.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — variable used before assignment\n`);
              const varMatch = msg.match(/Variable '(.+?)'/);
              const action = new vscode.CodeAction(
                `🐾 ${petName}: Fix '${varMatch?.[1] ?? "variable"}' used before assigned`,
                vscode.CodeActionKind.QuickFix
              );
              action.edit = wsEdit;
              action.diagnostics = [diag];
              actions.push(action);
              break;
            }

            // TS2300: Duplicate identifier
            case 2300: {
              const wsEdit = new vscode.WorkspaceEdit();
              const fullLineRange = new vscode.Range(diagLine, 0, diagLine + 1, 0);
              wsEdit.delete(document.uri, fullLineRange);
              const dupMatch = msg.match(/Duplicate identifier '(.+?)'/);
              const action = new vscode.CodeAction(
                `🐾 ${petName}: Remove duplicate '${dupMatch?.[1] ?? "identifier"}'`,
                vscode.CodeActionKind.QuickFix
              );
              action.edit = wsEdit;
              action.diagnostics = [diag];
              actions.push(action);
              break;
            }

            // TS6133: Declared but never read
            case 6133: {
              const identT = document.getText(diag.range);
              if (identT && !identT.startsWith("_")) {
                // Only prefix if not already prefixed with _
                const wsEdit = new vscode.WorkspaceEdit();
                wsEdit.replace(document.uri, diag.range, `_${identT}`);
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Prefix unused '${identT}' with _`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                actions.push(action);
              } else if (identT) {
                // Already has underscore — add @ts-ignore instead
                const prevLine = diagLine > 0 ? document.lineAt(diagLine - 1).text : "";
                if (!prevLine.includes("@ts-ignore") && !prevLine.includes("@ts-expect-error")) {
                  const wsEdit = new vscode.WorkspaceEdit();
                  wsEdit.insert(document.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — '${identT}' is intentionally unused\n`);
                  const action = new vscode.CodeAction(
                    `🐾 ${petName}: Add @ts-ignore for unused '${identT}'`,
                    vscode.CodeActionKind.QuickFix
                  );
                  action.edit = wsEdit;
                  action.diagnostics = [diag];
                  actions.push(action);
                }
              }
              break;
            }

            // TS2456: Type alias circularly references itself
            case 2456: {
              const circMatch = msg.match(/Type alias '(.+?)' circularly references itself/);
              if (circMatch) {
                const wsEdit = new vscode.WorkspaceEdit();
                const fullLineRange = new vscode.Range(diagLine, 0, diagLine, lineText.length);
                wsEdit.replace(document.uri, fullLineRange, `${indent}type ${circMatch[1]} = any;`);
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Fix circular type '${circMatch[1]}' → any`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                actions.push(action);
              }
              break;
            }

            // TS7043: Variable implicitly has 'any' type (inferred)
            case 7043: {
              const identT = document.getText(diag.range);
              if (identT) {
                const wsEdit = new vscode.WorkspaceEdit();
                wsEdit.insert(document.uri, new vscode.Position(diag.range.end.line, diag.range.end.character), ": any");
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Add type annotation to '${identT}'`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                actions.push(action);
              }
              break;
            }

            // TS1128: Declaration or statement expected
            case 1128: {
              const wsEdit = new vscode.WorkspaceEdit();
              const fullLine = new vscode.Range(diagLine, 0, diagLine + 1, 0);
              wsEdit.delete(document.uri, fullLine);
              const action = new vscode.CodeAction(
                `🐾 ${petName}: Remove broken syntax line`,
                vscode.CodeActionKind.QuickFix
              );
              action.edit = wsEdit;
              action.diagnostics = [diag];
              actions.push(action);
              break;
            }

            // TS2451: Cannot redeclare block-scoped variable
            case 2451: {
              const redeclMatch = msg.match(/Cannot redeclare block-scoped variable '(.+?)'/);
              if (redeclMatch) {
                const wsEdit = new vscode.WorkspaceEdit();
                const varName = redeclMatch[1];
                const varIdx = lineText.indexOf(varName);
                if (varIdx >= 0) {
                  wsEdit.replace(document.uri, new vscode.Range(diagLine, varIdx, diagLine, varIdx + varName.length), `${varName}_1`);
                  const action = new vscode.CodeAction(
                    `🐾 ${petName}: Rename duplicate '${varName}' → '${varName}_1'`,
                    vscode.CodeActionKind.QuickFix
                  );
                  action.edit = wsEdit;
                  action.diagnostics = [diag];
                  actions.push(action);
                }
              }
              break;
            }

            // TS2578/1434: Unused '@ts-expect-error' directive — remove it
            case 2578:
            case 1434: {
              const wsEdit = new vscode.WorkspaceEdit();
              wsEdit.delete(document.uri, new vscode.Range(diagLine, 0, diagLine + 1, 0));
              const action = new vscode.CodeAction(
                `🐾 ${petName}: Remove unused @ts-expect-error`,
                vscode.CodeActionKind.QuickFix
              );
              action.edit = wsEdit;
              action.diagnostics = [diag];
              actions.push(action);
              break;
            }

            // Universal fallback — any unhandled error gets @ts-ignore (not @ts-expect-error!)
            default: {
              // Anti-stacking: check up to 3 lines above for existing suppress comments
              let hasIgnoreNearby = false;
              for (let i = 1; i <= 3 && diagLine - i >= 0; i++) {
                const aboveLine = document.lineAt(diagLine - i).text;
                if (aboveLine.includes("@ts-ignore") || aboveLine.includes("@ts-expect-error")) {
                  hasIgnoreNearby = true;
                  break;
                }
                if (aboveLine.trim() !== "" && !aboveLine.trim().startsWith("//")) break;
              }
              if (!hasIgnoreNearby) {
                const wsEdit = new vscode.WorkspaceEdit();
                wsEdit.insert(document.uri, new vscode.Position(diagLine, 0), `${indent}// @ts-ignore — TS${tsCode}: auto-suppressed by Codepet\n`);
                const action = new vscode.CodeAction(
                  `🐾 ${petName}: Suppress TS${tsCode} error`,
                  vscode.CodeActionKind.QuickFix
                );
                action.edit = wsEdit;
                action.diagnostics = [diag];
                actions.push(action);
              }
              break;
            }
          }
        }

        outputChannel.appendLine(`[Codepet CodeAction] Returning ${actions.length} total actions`);
        return actions.length > 0 ? actions : undefined;
      }
    }, {
      providedCodeActionKinds: [vscode.CodeActionKind.QuickFix],
    })
  );
  outputChannel.appendLine("[Codepet] CodeAction provider registered for TS/JS/Python/Swift/Rust/Go/Java/HTML");

  // ── Hover provider — shows Byte's suggestions with clickable fix links ──
  // Checks BOTH Codepet scanner findings AND VS Code diagnostics.
  context.subscriptions.push(
    vscode.languages.registerHoverProvider({ scheme: "file" }, {
      provideHover(document, position) {
        const line = position.line;
        const parts: string[] = [];

        // ── Part A: Codepet scanner findings ──
        const uri = document.uri.toString();
        const result = codeScanner.getResultForUri(uri);
        if (result) {
          const findings = result.findings.filter(
            f => f.line === line && f.severity !== "clean"
          );

          for (const f of findings) {
            const emoji = f.severity === "error" ? "🔴" : "🟡";
            const isAutoFixable = f.source === "pattern" && AUTO_FIXABLE_CODES.has(f.code);

            let text = `${emoji} **${petName}:** ${f.message}`;
            if (f.suggestion) {
              text += `\n\n💡 ${f.suggestion}`;
            }

            if (isAutoFixable) {
              const args = encodeURIComponent(JSON.stringify({
                line: f.line, code: f.code, source: f.source
              }));
              text += `\n\n[🐾 **Auto-fix this**](command:codepet.fixAtLine?${args})`;
            }

            parts.push(text);
          }
        }

        // ── Part B: VS Code / TypeScript diagnostics ──
        const diagnostics = vscode.languages.getDiagnostics(document.uri);
        const lineDiags = diagnostics.filter(d => d.range.start.line === line);

        for (const diag of lineDiags) {
          const tsCode = typeof diag.code === "number" ? diag.code
            : typeof diag.code === "object" && diag.code !== null ? Number((diag.code as any).value) : 0;

          // Show fix links for ALL diagnostics — Codepet always offers a solution
          if (!tsCode) continue;

          const emoji = diag.severity === vscode.DiagnosticSeverity.Error ? "🔴" : "🟡";
          let text = `${emoji} **${petName}:** ${diag.message}`;

          // Build a direct fix link using codepet.fixTsDiagnostic
          const fixArgs = encodeURIComponent(JSON.stringify({
            line: diag.range.start.line,
            startChar: diag.range.start.character,
            endLine: diag.range.end.line,
            endChar: diag.range.end.character,
            tsCode: tsCode,
            message: diag.message,
          }));
          text += `\n\n[🐾 **Auto-fix this**](command:codepet.fixTsDiagnostic?${fixArgs})`;

          parts.push(text);
        }

        if (parts.length === 0) return null;

        const md = new vscode.MarkdownString(parts.join("\n\n---\n\n"));
        md.isTrusted = true;
        md.supportHtml = true;
        return new vscode.Hover(md);
      }
    })
  );

  // ── Command: fixAtLine — triggered from hover links ──
  context.subscriptions.push(
    vscode.commands.registerCommand("codepet.fixAtLine", async (args: { line: number; code: string; source: string }) => {
      const editor = vscode.window.activeTextEditor;
      if (!editor || !args) return;

      // Delegate to the sidebar provider's smart fix logic
      // For now, implement inline since SidebarProvider is separate
      const doc = editor.document;
      const line = args.line;
      const lineText = doc.lineAt(line).text;
      const indent = lineText.match(/^(\s*)/)?.[1] ?? "";

      const edit = new vscode.WorkspaceEdit();
      const lineRange = doc.lineAt(line).rangeIncludingLineBreak;
      let fixApplied = false;
      let fixDescription = "";

      switch (args.code) {
        case "debugger-statement":
        case "console-log":
        case "python-print":
        case "swift-print":
        case "go-fmt-println":
        case "python-pass-only":
        case "todo-comment":
        case "fixme-comment":
        case "python-todo": {
          edit.delete(doc.uri, lineRange);
          const labels: Record<string, string> = {
            "debugger-statement": "Removed debugger",
            "console-log": "Removed console.log",
            "python-print": "Removed print()",
            "swift-print": "Removed print()",
            "go-fmt-println": "Removed fmt.Println",
            "python-pass-only": "Removed empty pass",
            "todo-comment": "Removed TODO comment",
            "fixme-comment": "Removed FIXME comment",
            "python-todo": "Removed TODO comment",
          };
          fixDescription = labels[args.code] ?? "Removed line";
          fixApplied = true;
          break;
        }

        case "var-declaration": {
          const varMatch = lineText.match(/\bvar\s/);
          if (varMatch && varMatch.index !== undefined) {
            const start = new vscode.Position(line, varMatch.index);
            const end = new vscode.Position(line, varMatch.index + 3);
            edit.replace(doc.uri, new vscode.Range(start, end), "let");
            fixDescription = "Changed var → let";
            fixApplied = true;
          }
          break;
        }

        case "triple-equals": {
          const eqMatch = lineText.match(/([^!=])={2}([^=])/);
          if (eqMatch && eqMatch.index !== undefined) {
            const eqPos = eqMatch.index + 1;
            const start = new vscode.Position(line, eqPos);
            const end = new vscode.Position(line, eqPos + 2);
            edit.replace(doc.uri, new vscode.Range(start, end), "===");
            fixDescription = "Changed == → ===";
            fixApplied = true;
          }
          break;
        }

        case "loose-inequality": {
          const neqMatch = lineText.match(/([^!])!={1}([^=])/);
          if (neqMatch && neqMatch.index !== undefined) {
            const neqPos = neqMatch.index + 1;
            const start = new vscode.Position(line, neqPos);
            const end = new vscode.Position(line, neqPos + 2);
            edit.replace(doc.uri, new vscode.Range(start, end), "!==");
            fixDescription = "Changed != → !==";
            fixApplied = true;
          }
          break;
        }

        case "any-type": {
          const anyMatch = lineText.match(/:\s*any\b/);
          if (anyMatch && anyMatch.index !== undefined) {
            const start = new vscode.Position(line, anyMatch.index);
            const end = new vscode.Position(line, anyMatch.index + anyMatch[0].length);
            edit.replace(doc.uri, new vscode.Range(start, end), "");
            fixDescription = "Removed explicit : any annotation";
            fixApplied = true;
          }
          break;
        }

        case "empty-catch": {
          const catchMatch = lineText.match(/catch\s*\(([^)]*)\)\s*\{\s*\}/);
          if (catchMatch && catchMatch.index !== undefined) {
            const errVar = catchMatch[1].trim() || "err";
            const braceStart = lineText.indexOf("{", catchMatch.index + 5);
            const braceEnd = lineText.indexOf("}", braceStart) + 1;
            const start = new vscode.Position(line, braceStart);
            const end = new vscode.Position(line, braceEnd);
            edit.replace(doc.uri, new vscode.Range(start, end),
              `{\n${indent}  console.error("Error caught:", ${errVar});\n${indent}}`
            );
            fixDescription = "Added error logging to catch";
            fixApplied = true;
          }
          break;
        }

        case "nested-ternary": {
          // Parse the top-level ternary and rewrite as if/else
          // Handles: const x = A ? B : C; where B or C contains another ?
          const assignMatch = lineText.match(/^(\s*)(const|let|var)\s+(\w+)\s*(?::\s*[^=]+?)?\s*=\s*/);
          if (assignMatch) {
            const varKeyword = assignMatch[2];
            const varName = assignMatch[3];
            const exprStart = assignMatch[0].length;
            let expr = lineText.substring(exprStart).replace(/;\s*$/, "");

            // Find top-level ? and : by tracking paren/bracket depth
            let depth = 0;
            let questionIdx = -1;
            let colonIdx = -1;
            for (let i = 0; i < expr.length; i++) {
              const ch = expr[i];
              if (ch === "(" || ch === "[" || ch === "{") depth++;
              else if (ch === ")" || ch === "]" || ch === "}") depth--;
              else if (ch === "?" && depth === 0 && questionIdx === -1) questionIdx = i;
              else if (ch === ":" && depth === 0 && questionIdx !== -1 && colonIdx === -1) colonIdx = i;
            }

            if (questionIdx > 0 && colonIdx > questionIdx) {
              const condition = expr.substring(0, questionIdx).trim();
              let trueExpr = expr.substring(questionIdx + 1, colonIdx).trim();
              let falseExpr = expr.substring(colonIdx + 1).trim();
              // Strip wrapping parens from expressions: (inner ? x : y) → inner ? x : y
              if (trueExpr.startsWith("(") && trueExpr.endsWith(")")) trueExpr = trueExpr.slice(1, -1).trim();
              if (falseExpr.startsWith("(") && falseExpr.endsWith(")")) falseExpr = falseExpr.slice(1, -1).trim();

              // Use let so we can assign in branches
              const useKeyword = varKeyword === "const" ? "let" : varKeyword;
              const replacement =
                `${indent}${useKeyword} ${varName};\n` +
                `${indent}if (${condition}) {\n` +
                `${indent}  ${varName} = ${trueExpr};\n` +
                `${indent}} else {\n` +
                `${indent}  ${varName} = ${falseExpr};\n` +
                `${indent}}\n`;

              edit.replace(doc.uri, new vscode.Range(line, 0, line + 1, 0), replacement);
              fixDescription = "Converted nested ternary to if/else";
              fixApplied = true;
            }
          }
          // Fallback: if not an assignment, just add a comment explaining
          if (!fixApplied) {
            const aboveLine = line > 0 ? doc.lineAt(line - 1).text : "";
            if (!aboveLine.includes("nested ternary")) {
              edit.insert(doc.uri, new vscode.Position(line, 0),
                `${indent}// Consider refactoring: nested ternary below\n`);
              fixDescription = "Added refactor hint for nested ternary";
              fixApplied = true;
            }
          }
          break;
        }

        case "magic-number": {
          // Extract magic number to a named constant above the line
          const numMatch = lineText.match(/\b([2-9]\d{2,}|[1-9]\d{3,})\b/);
          if (numMatch && numMatch.index !== undefined) {
            const num = numMatch[1];
            // Generate a SCREAMING_SNAKE_CASE name based on context
            let constName = "MAGIC_VALUE";
            if (/port/i.test(lineText)) constName = "PORT";
            else if (/timeout/i.test(lineText)) constName = "TIMEOUT_MS";
            else if (/retri|retry/i.test(lineText)) constName = "MAX_RETRIES";
            else if (/size|length|limit|max|min/i.test(lineText)) constName = "LIMIT";
            else if (/width|height/i.test(lineText)) constName = "DIMENSION";
            else if (/delay|interval/i.test(lineText)) constName = "DELAY_MS";
            else if (/status|code/i.test(lineText)) constName = "STATUS_CODE";
            else if (/count/i.test(lineText)) constName = "COUNT";
            else constName = `VALUE_${num}`;

            // Replace the number in the line with the constant name
            const start = new vscode.Position(line, numMatch.index);
            const end = new vscode.Position(line, numMatch.index + num.length);
            edit.replace(doc.uri, new vscode.Range(start, end), constName);
            // Insert the constant declaration above
            edit.insert(doc.uri, new vscode.Position(line, 0), `${indent}const ${constName} = ${num};\n`);
            fixDescription = `Extracted magic number ${num} → ${constName}`;
            fixApplied = true;
          }
          break;
        }

        case "swift-force-unwrap": {
          const m = lineText.match(/(\w+)!/);
          if (m && m.index !== undefined) {
            const start = new vscode.Position(line, m.index);
            const end = new vscode.Position(line, m.index + m[0].length);
            edit.replace(doc.uri, new vscode.Range(start, end), `${m[1]} ?? nil`);
            fixDescription = "Replaced force unwrap with ?? nil";
            fixApplied = true;
          }
          break;
        }

        case "swift-force-cast": {
          const m = lineText.match(/\bas!\s/);
          if (m && m.index !== undefined) {
            const start = new vscode.Position(line, m.index);
            const end = new vscode.Position(line, m.index + 3);
            edit.replace(doc.uri, new vscode.Range(start, end), "as?");
            fixDescription = "Changed force cast to optional cast";
            fixApplied = true;
          }
          break;
        }

        case "rust-unwrap": {
          const m = lineText.match(/\.unwrap\s*\(\s*\)/);
          if (m && m.index !== undefined) {
            const start = new vscode.Position(line, m.index);
            const end = new vscode.Position(line, m.index + m[0].length);
            edit.replace(doc.uri, new vscode.Range(start, end), ".unwrap_or_default()");
            fixDescription = "Changed .unwrap() to .unwrap_or_default()";
            fixApplied = true;
          }
          break;
        }

        case "python-bare-except": {
          const m = lineText.match(/\bexcept\s*:/);
          if (m && m.index !== undefined) {
            const start = new vscode.Position(line, m.index);
            const end = new vscode.Position(line, m.index + m[0].length);
            edit.replace(doc.uri, new vscode.Range(start, end), "except Exception as e:");
            fixDescription = "Added specific exception type";
            fixApplied = true;
          }
          break;
        }

        case "html-missing-alt": {
          const closingBracket = lineText.lastIndexOf(">");
          if (closingBracket > 0) {
            const insertPos = lineText[closingBracket - 1] === "/" ? closingBracket - 1 : closingBracket;
            edit.insert(doc.uri, new vscode.Position(line, insertPos), ' alt=""');
            fixDescription = 'Added alt="" for accessibility';
            fixApplied = true;
          }
          break;
        }
      }

      if (fixApplied) {
        await vscode.workspace.applyEdit(edit);
        vscode.window.showInformationMessage(
          `🐾 Byte fixed it: ${fixDescription}`,
          "Undo"
        ).then((action) => {
          if (action === "Undo") {
            vscode.commands.executeCommand("undo");
          }
        });
      }
    })
  );

  // ── Command: fixTsDiagnostic — powered by Fix Engine + Error Knowledge Base ──
  context.subscriptions.push(
    vscode.commands.registerCommand("codepet.fixTsDiagnostic", async (args: {
      line: number; startChar: number; endLine: number; endChar: number;
      tsCode: number; message: string;
    }) => {
      const editor = vscode.window.activeTextEditor;
      if (!editor || !args) return;

      // ── Use the Fix Engine (data-driven, context-aware) ──
      const result = fixEngine.applyFix({
        doc: editor.document,
        line: args.line,
        startChar: args.startChar,
        endLine: args.endLine,
        endChar: args.endChar,
        tsCode: args.tsCode,
        message: args.message,
      });

      const fixDescription = result.description;
      const edit = result.edit;

      // Legacy switch removed — all fix logic now lives in:
      //   src/core/ts-error-codes.ts  (knowledge base)
      //   src/core/fix-engine.ts      (fix application engine)

      if (fixDescription) {
        await vscode.workspace.applyEdit(edit);
        vscode.window.showInformationMessage(
          `🐾 ${petName} fixed it: ${fixDescription}`,
          "Undo"
        ).then((action) => {
          if (action === "Undo") {
            vscode.commands.executeCommand("undo");
          }
        });
      } else {
        vscode.window.showInformationMessage(
          `🐾 ${petName}: Couldn't auto-fix this one. Try Cmd+. for more options.`
        );
      }
    })
  );

  // ── Command: quickFixAtLine — opens VS Code Quick Fix menu at a specific line ──
  context.subscriptions.push(
    vscode.commands.registerCommand("codepet.quickFixAtLine", async (args: { line: number; col: number }) => {
      const editor = vscode.window.activeTextEditor;
      if (!editor || !args) return;

      const pos = new vscode.Position(args.line, args.col ?? 0);
      editor.selection = new vscode.Selection(pos, pos);
      editor.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);

      // Small delay to let the cursor settle, then open Quick Fix
      setTimeout(() => {
        vscode.commands.executeCommand("editor.action.quickFix");
      }, 100);
    })
  );

  // ── Command: fixDiagnostic — applies TypeScript diagnostic fixes ──
  context.subscriptions.push(
    vscode.commands.registerCommand("codepet.fixDiagnostic", async (args: any) => {
      const editor = vscode.window.activeTextEditor;
      if (!editor || !args) return;

      const doc = editor.document;
      const edit = new vscode.WorkspaceEdit();
      let fixDescription = "";

      switch (args.type) {
        case "type-assertion": {
          // Wrap identifier with (identifier as any)
          const diagRange = new vscode.Range(
            args.range.start.line ?? args.range[0]?.line ?? args.line,
            args.range.start.character ?? args.range[0]?.character ?? 0,
            args.range.end.line ?? args.range[1]?.line ?? args.line,
            args.range.end.character ?? args.range[1]?.character ?? 0,
          );
          const identText = doc.getText(diagRange);
          edit.replace(doc.uri, diagRange, `(${identText} as any)`);
          fixDescription = `Added type assertion: (${identText} as any)`;
          break;
        }

        case "change-type-annotation": {
          // Change : oldType to : fromType (match the actual value)
          const lineText = doc.lineAt(args.line).text;
          const typeMatch = lineText.match(new RegExp(`:\\s*${args.oldAnnotation}\\b`));
          if (typeMatch && typeMatch.index !== undefined) {
            const start = new vscode.Position(args.line, typeMatch.index);
            const end = new vscode.Position(args.line, typeMatch.index + typeMatch[0].length);
            edit.replace(doc.uri, new vscode.Range(start, end), `: ${args.fromType}`);
            fixDescription = `Changed type: ${args.oldAnnotation} → ${args.fromType}`;
          }
          break;
        }

        case "add-cast": {
          // Add "as Type" to the value after = on the line
          const lineText = doc.lineAt(args.line).text;
          const eqIndex = lineText.indexOf("=");
          if (eqIndex >= 0) {
            // Find the semicolon or end of line
            const semiIndex = lineText.indexOf(";", eqIndex);
            const valueEnd = semiIndex >= 0 ? semiIndex : lineText.length;
            const valueStart = eqIndex + 1;
            const rawValue = lineText.substring(valueStart, valueEnd).trim();
            const insertPos = new vscode.Position(args.line, valueEnd);
            edit.insert(doc.uri, insertPos, ` as ${args.toType}`);
            fixDescription = `Added cast: ${rawValue} as ${args.toType}`;
          }
          break;
        }

        case "cast-argument": {
          // Wrap argument with (arg as targetType)
          const diagRange = new vscode.Range(
            args.range.start.line ?? args.line, args.range.start.character ?? 0,
            args.range.end.line ?? args.line, args.range.end.character ?? 0,
          );
          const identText = doc.getText(diagRange);
          edit.replace(doc.uri, diagRange, `(${identText} as ${args.targetType})`);
          fixDescription = `Cast argument: (${identText} as ${args.targetType})`;
          break;
        }

        case "declare-variable": {
          // Insert "let varName: any;" on the line above
          const indent = doc.lineAt(args.line).text.match(/^(\s*)/)?.[1] ?? "";
          const insertPos = new vscode.Position(args.line, 0);
          edit.insert(doc.uri, insertPos, `${indent}let ${args.varName}: any;\n`);
          fixDescription = `Declared: let ${args.varName}: any`;
          break;
        }

        case "cast-object": {
          // Wrap object with (obj as any) — replace "obj." with "(obj as any)."
          const lineText = doc.lineAt(args.line).text;
          const objPattern = new RegExp(`\\b${args.objName}\\.`);
          const objMatch = lineText.match(objPattern);
          if (objMatch && objMatch.index !== undefined) {
            const start = new vscode.Position(args.line, objMatch.index);
            const end = new vscode.Position(args.line, objMatch.index + args.objName.length);
            edit.replace(doc.uri, new vscode.Range(start, end), `(${args.objName} as any)`);
            fixDescription = `Added assertion: (${args.objName} as any)`;
          }
          break;
        }

        case "add-param-type": {
          // Add ": any" after the parameter name
          const diagRange = new vscode.Range(
            args.range.start.line ?? args.line, args.range.start.character ?? 0,
            args.range.end.line ?? args.line, args.range.end.character ?? 0,
          );
          const insertPos = new vscode.Position(diagRange.end.line, diagRange.end.character);
          edit.insert(doc.uri, insertPos, ": any");
          fixDescription = `Added type: ${args.paramName}: any`;
          break;
        }

        case "fix-typo": {
          // Replace wrong name with right name
          const diagRange = new vscode.Range(
            args.range.start.line ?? args.line, args.range.start.character ?? 0,
            args.range.end.line ?? args.line, args.range.end.character ?? 0,
          );
          edit.replace(doc.uri, diagRange, args.rightName);
          fixDescription = `Fixed typo: ${args.wrongName} → ${args.rightName}`;
          break;
        }

        case "change-return-type": {
          // Change return type annotation
          const lineText = doc.lineAt(args.line).text;
          const retMatch = lineText.match(/\):\s*(\w+)/);
          if (retMatch && retMatch.index !== undefined) {
            const colonPos = lineText.indexOf(":", retMatch.index + 1);
            const typeStart = colonPos + 1;
            // Find where the type ends
            const typeText = lineText.substring(typeStart).match(/^\s*(\w+)/);
            if (typeText) {
              const start = new vscode.Position(args.line, typeStart);
              const end = new vscode.Position(args.line, typeStart + typeText[0].length);
              edit.replace(doc.uri, new vscode.Range(start, end), ` ${args.newType}`);
              fixDescription = `Changed return type: ${args.oldType} → ${args.newType}`;
            }
          }
          break;
        }
      }

      if (fixDescription) {
        await vscode.workspace.applyEdit(edit);
        vscode.window.showInformationMessage(
          `🐾 ${petName} fixed it: ${fixDescription}`,
          "Undo"
        ).then((action) => {
          if (action === "Undo") {
            vscode.commands.executeCommand("undo");
          }
        });
      }
    })
  );

  // ── Proactive notification when a NEW error appears ──
  let lastNotifyTime = 0;
  const NOTIFY_COOLDOWN = 5000; // Don't spam: max one notification per 5 seconds

  context.subscriptions.push(
    codeScanner.onNewError((event) => {
      const config = vscode.workspace.getConfiguration("codepet");
      const scanNotifications = config.get<boolean>("scanNotifications") ?? true;
      if (!scanNotifications) return;

      const now = Date.now();
      if (now - lastNotifyTime < NOTIFY_COOLDOWN) return;
      lastNotifyTime = now;

      const emoji = petReactions.personality.emoji;
      const name = petReactions.personality.name;
      const severity = event.finding.severity;
      const line = event.finding.line + 1; // 0-indexed → 1-indexed

      // Different messages based on severity
      const msg = severity === "error"
        ? `${emoji} ${name}: Found an error on line ${line} — ${event.finding.message}`
        : `${emoji} ${name}: Heads up! Line ${line} — ${event.finding.message}`;

      const notifyFn = severity === "error"
        ? vscode.window.showErrorMessage
        : vscode.window.showWarningMessage;

      notifyFn(msg, "Fix It", "Show Details", "Dismiss").then((action) => {
        if (action === "Fix It") {
          // Jump to the error line and trigger quick fix
          const editor = vscode.window.activeTextEditor;
          if (editor) {
            const pos = new vscode.Position(event.finding.line, event.finding.column);
            editor.selection = new vscode.Selection(pos, pos);
            editor.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);
            vscode.commands.executeCommand("editor.action.quickFix");
          }
        } else if (action === "Show Details") {
          vscode.commands.executeCommand("workbench.view.extension.codepet-sidebar").then(
            () => vscode.commands.executeCommand("codepet.dashboard.focus"),
            () => vscode.commands.executeCommand("codepet.dashboard.focus")
          );
        }
      });
    })
  );

  // Log summary changes
  context.subscriptions.push(
    codeScanner.onSummaryChanged((summary) => {
      outputChannel.appendLine(
        `[Codepet Scanner] ${summary.totalErrors} errors, ${summary.totalWarnings} warnings, ${summary.cleanFiles}/${summary.totalFiles} clean files (${summary.averageCleanScore}%)`
      );
    })
  );

  outputChannel.appendLine("[Codepet] Code Scanner initialized — watching for code quality.");

  // ───── Welcome Greeting (compute BEFORE UI registration) ─────
  const hour = new Date().getHours();
  const timeGreeting = hour < 5 ? "Late night coding"
    : hour < 12 ? "Good morning"
    : hour < 17 ? "Good afternoon"
    : hour < 21 ? "Good evening"
    : "Late night coding";

  outputChannel.appendLine(`[Codepet] Welcome: userName="${userName}", pet="${petName}", greeting="${timeGreeting}"`);

  // ───── UI ─────
  statusBar = new StatusBar(fileWatcher, sessionTracker);
  statusBar.setPetName(petName);

  const sidebarProvider = new SidebarProvider(
    context.extensionUri,
    fileWatcher,
    sessionTracker,
    triggerEngine,
    codeScanner,
    petReactions
  );

  // Set the resolved pet name so the sidebar stays consistent with the welcome greeting
  sidebarProvider.setPetName(petName);

  // Set cloud link status
  sidebarProvider.setCloudLinked(cloudSync.isConfigured);

  // Set welcome greeting BEFORE registering the provider,
  // because resolveWebviewView() fires synchronously if sidebar is already visible
  sidebarProvider.setWelcomeGreeting(timeGreeting, userName, petName);

  // Register the webview view provider
  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider(
      SidebarProvider.viewType,
      sidebarProvider,
      { webviewOptions: { retainContextWhenHidden: false } }
    )
  );

  outputChannel.appendLine(
    `[Codepet] Registered view provider: ${SidebarProvider.viewType}`
  );

  // ───── Load user profile + today's stats from Firestore (link data with macOS app) ─────
  if (cloudSync.isConfigured) {
    // Load profile (Level, XP, Streak, Lessons)
    cloudSync.getUserProfile().then((profile) => {
      if (profile) {
        outputChannel.appendLine(
          `[Codepet] Loaded profile: Level ${profile.userLevel}, XP: ${profile.totalXP}, Streak: ${profile.streak}, Lessons: ${profile.completedLessons.length}`
        );
        sidebarProvider.setUserProfile(profile);

        // If Firestore has a displayName we didn't get from UserDefaults, use it
        if (profile.displayName && userName === "Coder") {
          const betterName = profile.displayName.split(" ")[0]; // first name
          sidebarProvider.setWelcomeGreeting(timeGreeting, betterName, petName);
        }
      }
    }).catch((err: any) => {
      outputChannel.appendLine(`[Codepet] Profile load failed: ${err.message ?? err}`);
    });

    // Load today's aggregate session stats (same data macOS app displays)
    cloudSync.getTodayExtensionStats().then((stats) => {
      if (stats && stats.codingMinutes > 0) {
        outputChannel.appendLine(
          `[Codepet] Loaded today's cloud stats: ${stats.codingMinutes}m, +${stats.linesAdded}/-${stats.linesRemoved} lines`
        );
        sidebarProvider.setCloudStats(stats);
      }
    }).catch((err: any) => {
      outputChannel.appendLine(`[Codepet] Cloud stats load failed: ${err.message ?? err}`);
    });
  }

  // ───── Auto-reveal sidebar on startup ─────
  setTimeout(() => {
    vscode.commands.executeCommand("workbench.view.extension.codepet-sidebar").then(
      () => outputChannel.appendLine("[Codepet] Sidebar auto-revealed."),
      () => {
        setTimeout(() => {
          vscode.commands.executeCommand("codepet.dashboard.focus").then(
            () => outputChannel.appendLine("[Codepet] Sidebar focused (retry)."),
            (err: any) => outputChannel.appendLine(`[Codepet] Could not auto-reveal sidebar: ${err}`)
          );
        }, 2000);
      }
    );
  }, 2000);

  // ───── Cloud Sync — feed data & start timer ─────
  // Session tracker starts fresh at 0 every time Cursor opens.
  // It only tracks real-time activity from THIS session — no seeding from
  // MCP or Firestore, which caused stale data to appear on restart.
  outputChannel.appendLine("[Codepet] Session tracker starting fresh — real-time only.");

  // Feed session data to cloud sync on every update — only when there's activity
  context.subscriptions.push(
    sessionTracker.onSessionUpdate(() => {
      const stats = sessionTracker.stats;
      // Don't write zeros to Firestore — it would overwrite previous session data
      if (stats.totalEdits === 0 && stats.codingMinutes === 0) return;
      cloudSync.updateSession({
        codingMinutes: stats.codingMinutes,
        totalEdits: stats.totalEdits,
        filesEdited: stats.filesEdited.size,
        linesAdded: stats.linesAdded,
        linesRemoved: stats.linesRemoved,
        currentBranch: stats.currentBranch ?? "",
        topLanguage: sessionTracker.topLanguage ?? "",
        languageBreakdown: Object.fromEntries(stats.languageBreakdown),
        isIdle: stats.isIdle,
      });
    })
  );

  // Feed scanner data to cloud sync
  context.subscriptions.push(
    codeScanner.onSummaryChanged((summary) => {
      cloudSync.updateScanner({
        averageCleanScore: summary.averageCleanScore,
        totalErrors: summary.totalErrors,
        totalWarnings: summary.totalWarnings,
        cleanFiles: summary.cleanFiles,
        totalFiles: summary.totalFiles,
        topIssue: summary.topIssue,
      });
    })
  );

  // MCP summary data is no longer synced to Firestore as session data.
  // Only real-time session tracker data goes to Firestore — keeps numbers honest.

  // ───── Break Reminders (caring friend messages from Byte) ─────
  const breakMessages = {
    // First reminder (60 min) — gentle nudge
    first: [
      `Hey ${userName}, you've been going strong for an hour! Your eyes deserve a little break — even just looking out the window for a minute helps. ${petName} will be right here waiting.`,
      `${userName}, it's been a whole hour already! Time flies when you're in the zone. How about stretching your legs for a bit? ${petName} could use a breather too.`,
      `One hour of solid focus — that's amazing, ${userName}! But your body needs some love too. Stand up, grab some water, take a deep breath. ${petName}'s not going anywhere.`,
    ],
    // Second reminder (2 hours) — more concerned
    second: [
      `${userName}... two hours straight? I'm proud of your dedication, but I'm also a little worried. Please take 5 minutes — walk around, rest your eyes. You'll come back sharper, I promise.`,
      `Hey ${userName}, ${petName} here — you've been coding for 2 hours without a break. Your wrists, your eyes, your back — they're all asking for a pause. Take care of yourself, okay?`,
      `Two hours in, ${userName}! You're doing incredible work, but the best coders know when to pause. Step away for a few minutes — the code will still be here.`,
    ],
    // Third+ reminder (3+ hours) — urgent but still warm
    deep: [
      `${userName}, this is ${petName} speaking seriously now — ${Math.floor(sessionTracker.liveCodingMinutes / 60)}+ hours without a real break isn't sustainable. Please step away. Your health matters more than any deadline.`,
      `I care about you, ${userName}. You've been at this for over ${Math.floor(sessionTracker.liveCodingMinutes / 60)} hours. Please get up, drink water, maybe eat something. The code can wait — you can't be replaced.`,
      `${userName}... ${petName} is genuinely concerned. Long sessions without breaks lead to burnout and mistakes. Please take at least 10 minutes away from the screen. Do it for both of us.`,
    ],
  };

  context.subscriptions.push(
    sessionTracker.onBreakReminder(({ minutes, streak }) => {
      outputChannel.appendLine(`[Codepet] Break reminder #${streak} at ${minutes}m`);

      // Pick the right message pool based on how many reminders we've sent
      const pool = streak <= 1 ? breakMessages.first
        : streak === 2 ? breakMessages.second
        : breakMessages.deep;

      const message = pool[Math.floor(Math.random() * pool.length)];

      // For 3+ hours, use a warning-level notification
      if (streak >= 3) {
        vscode.window.showWarningMessage(
          `💛 ${message}`,
          "Take a Break",
          "5 More Minutes"
        ).then((action) => {
          if (action === "Take a Break") {
            vscode.window.showInformationMessage(
              `${petName} says: "Thank you, ${userName}! Enjoy your break. I'll keep your place warm. 🌿"`
            );
          }
        });
      } else {
        vscode.window.showInformationMessage(
          `💛 ${message}`,
          "Take a Break",
          "Remind Me Later"
        ).then((action) => {
          if (action === "Take a Break") {
            vscode.window.showInformationMessage(
              `${petName} says: "Good call! Go stretch, grab water, look at something far away for 20 seconds. See you soon! 🌿"`
            );
          }
        });
      }
    })
  );

  // Start cloud sync timer
  const syncInterval =
    vscode.workspace.getConfiguration("codepet").get<number>("syncIntervalSeconds") ?? 30;
  cloudSync.start(syncInterval);
  context.subscriptions.push(cloudSync);

  // ───── Lesson Service (post-session knowledge capture) ─────
  const rawPetChar = cloudSync.petName
    || vscode.workspace.getConfiguration("codepet").get<string>("petName")
    || "nova";
  lessonService = new LessonService(
    outputChannel,
    sessionTracker,
    petName,
    rawPetChar
  );
  lessonService.setSidebar(sidebarProvider);
  lessonService.setCloudSync(cloudSync);

  // Load existing lesson feed
  lessonService.loadAndPushFeed();

  // Reset auto-save flag when user resumes coding
  context.subscriptions.push(
    sessionTracker.onResume(() => {
      lessonService.resetAutoSave();
    })
  );

  // Register "Save Lesson" command
  context.subscriptions.push(
    vscode.commands.registerCommand("codepet.saveLesson", async () => {
      await lessonService.saveLesson();
    })
  );

  context.subscriptions.push(lessonService);

  outputChannel.appendLine("[Codepet] Lesson Feed service started.");

  // ───── Welcome Notification + Panel ─────
  const showWelcomeSetting = vscode.workspace.getConfiguration("codepet").get<boolean>("showWelcome") ?? true;

  if (showWelcomeSetting) {
    // VS Code notification (fire at 500ms)
    setTimeout(() => {
      try {
        outputChannel.appendLine(`[Codepet] Firing welcome notification...`);
        vscode.window.showInformationMessage(
          `${petReactions.personality.emoji} ${timeGreeting}, ${userName}! ${petName} is ready to code with you.`,
          "Open Dashboard"
        ).then((action) => {
          if (action === "Open Dashboard") {
            vscode.commands.executeCommand("codepet.dashboard.focus");
          }
        });
      } catch (e: any) {
        outputChannel.appendLine(`[Codepet] Welcome notification error: ${e.message ?? e}`);
      }
    }, 500);

    // Layer 2: Full welcome panel (webview tab) on first install / version update
    if (WelcomePanel.shouldShow(context)) {
      setTimeout(async () => {
        try {
          let welcomeStats: WelcomeStats = {
            yesterdayCodingMinutes: 0,
            yesterdayLinesAdded: 0,
            yesterdayCommits: 0,
            yesterdayCleanScore: 100,
            streakDays: 0,
          };

          if (cloudSync.isConfigured) {
            try {
              const yesterday = await cloudSync.getYesterdayStats();
              const streak = await cloudSync.getStreakDays();
              if (yesterday) {
                welcomeStats = {
                  yesterdayCodingMinutes: yesterday.codingMinutes,
                  yesterdayLinesAdded: yesterday.linesAdded,
                  yesterdayCommits: yesterday.commits,
                  yesterdayCleanScore: yesterday.cleanScore,
                  streakDays: streak,
                };
              }
            } catch (e: any) {
              outputChannel.appendLine(`[Codepet] Stats load error: ${e.message ?? e}`);
            }
          }

          outputChannel.appendLine(`[Codepet] Creating welcome panel...`);
          WelcomePanel.show(context.extensionUri, petName, userName, welcomeStats);
          WelcomePanel.markShown(context);
          outputChannel.appendLine(`[Codepet] Welcome panel created successfully.`);
        } catch (e: any) {
          outputChannel.appendLine(`[Codepet] Welcome panel error: ${e.message ?? e}`);
        }
      }, 3000);
    }
  }

  // ───── Commands ─────

  // Show summary → focus sidebar
  context.subscriptions.push(
    vscode.commands.registerCommand("codepet.showSummary", () => {
      vscode.commands.executeCommand("codepet.dashboard.focus");
    })
  );

  // Refresh MCP data
  context.subscriptions.push(
    vscode.commands.registerCommand("codepet.refreshData", () => {
      fileWatcher.refresh();
      vscode.window.showInformationMessage("Codepet: Data refreshed ✨");
    })
  );

  // Open dashboard → focus sidebar
  context.subscriptions.push(
    vscode.commands.registerCommand("codepet.openDashboard", () => {
      vscode.commands.executeCommand("codepet.dashboard.focus");
    })
  );

  // Toggle code scanner
  context.subscriptions.push(
    vscode.commands.registerCommand("codepet.toggleScanner", () => {
      const config = vscode.workspace.getConfiguration("codepet");
      const current = config.get<boolean>("scanNotifications") ?? true;
      config.update("scanNotifications", !current, true);
      vscode.window.showInformationMessage(
        `Codepet: Code scanning notifications ${!current ? "enabled" : "disabled"}`
      );
    })
  );

  // Show welcome screen on demand
  context.subscriptions.push(
    vscode.commands.registerCommand("codepet.showWelcome", async () => {
      const currentUserName = cloudSync.userName
        || vscode.workspace.getConfiguration("codepet").get<string>("userName")
        || "Coder";
      let welcomeStats: WelcomeStats = {
        yesterdayCodingMinutes: 0,
        yesterdayLinesAdded: 0,
        yesterdayCommits: 0,
        yesterdayCleanScore: 100,
        streakDays: 0,
      };
      if (cloudSync.isConfigured) {
        try {
          const yesterday = await cloudSync.getYesterdayStats();
          const streak = await cloudSync.getStreakDays();
          if (yesterday) {
            welcomeStats = {
              yesterdayCodingMinutes: yesterday.codingMinutes,
              yesterdayLinesAdded: yesterday.linesAdded,
              yesterdayCommits: yesterday.commits,
              yesterdayCleanScore: yesterday.cleanScore,
              streakDays: streak,
            };
          }
        } catch { /* use defaults */ }
      }
      WelcomePanel.show(context.extensionUri, petName, currentUserName, welcomeStats);
    })
  );

  // Force cloud sync
  context.subscriptions.push(
    vscode.commands.registerCommand("codepet.syncNow", async () => {
      if (!cloudSync.isConfigured) {
        vscode.window.showWarningMessage(
          "Codepet: No Codepet macOS app account detected. Please install the Codepet app and sign in to enable cloud sync."
        );
        return;
      }
      await cloudSync.flush();
      vscode.window.showInformationMessage("Codepet: Synced to cloud!");
    })
  );

  // ───── Register disposables ─────
  context.subscriptions.push(fileWatcher);
  context.subscriptions.push(sessionTracker);
  context.subscriptions.push(triggerEngine);
  context.subscriptions.push(codeScanner);
  context.subscriptions.push(statusBar);
  context.subscriptions.push(outputChannel);

  outputChannel.appendLine("[Codepet] Extension activated successfully!");
  outputChannel.appendLine(
    `[Codepet] Platform: ${vscode.env.appName} ${vscode.version}`
  );
  outputChannel.appendLine(
    `[Codepet] Pet: ${petReactions.personality.name} (${petReactions.personality.trait})`
  );
}

export function deactivate(): void {
  // All disposables are handled via context.subscriptions
}
