/**
 * SidebarProvider — Renders the Codepet dashboard in a VS Code sidebar webview
 *
 * Shows:
 *   - Pet widget with mood/reaction
 *   - Today's coding stats (time, commits, lines, bugs fixed)
 *   - Language breakdown bar
 *   - Skill progress bars (4 kingdoms)
 *   - Session timeline
 *   - Trigger event feed
 *
 * Communicates with the webview via postMessage.
 */

import * as vscode from "vscode";
import type { FileWatcher } from "../core/file-watcher.js";
import type { SessionTracker } from "../core/session-tracker.js";
import type { TriggerEngine, TriggerEvent } from "../core/trigger-engine.js";
import type { CodeScanner } from "../core/code-scanner.js";
import type { PetReactionEngine } from "../core/pet-reactions.js";
import * as fixEngine from "../core/fix-engine.js";

export class SidebarProvider implements vscode.WebviewViewProvider {
  public static readonly viewType = "codepet.dashboard";

  private view?: vscode.WebviewView;
  private disposables: vscode.Disposable[] = [];
  private liveTimer: NodeJS.Timeout | undefined; // ticks every 10s to update coding time display
  private lastSummarySig = ""; // tracks overall scan summary to avoid re-rendering identical data
  private pendingWelcome: { greeting: string; userName: string; petName: string } | null = null;
  private resolvedPetName: string = "Nova"; // set from extension.ts to stay consistent
  private userProfile: { totalXP: number; userLevel: number; streak: number; completedLessons: string[] } | null = null;
  private isCloudLinked: boolean = false; // whether the macOS app account is detected

  constructor(
    private extensionUri: vscode.Uri,
    private fileWatcher: FileWatcher,
    private sessionTracker: SessionTracker,
    private triggerEngine: TriggerEngine,
    private codeScanner?: CodeScanner,
    private petReactions?: PetReactionEngine
  ) {}

  /** Set the resolved pet name (from macOS app or config) so the sidebar stays consistent */
  setPetName(name: string): void {
    this.resolvedPetName = name;
  }

  /** Set whether the macOS app account is linked (for connection badge) */
  setCloudLinked(linked: boolean): void {
    this.isCloudLinked = linked;
  }

  /** Force a UI refresh (e.g., after seeding session data from cloud) */
  pushRefresh(): void {
    this.pushUpdate();
  }

  /** Set user profile data from Firestore (links with macOS app) */
  setUserProfile(profile: { totalXP: number; userLevel: number; streak: number; completedLessons: string[] }): void {
    this.userProfile = profile;
    if (this.view) {
      this.view.webview.postMessage({
        type: "profile",
        data: {
          totalXP: profile.totalXP,
          userLevel: profile.userLevel,
          streak: profile.streak,
          lessonsCompleted: profile.completedLessons.length,
        },
      });
    }
  }

  /** Set today's aggregate stats from Firestore cloud (same data macOS app shows) */
  setCloudStats(stats: {
    codingMinutes: number;
    totalEdits: number;
    filesEdited: number;
    linesAdded: number;
    linesRemoved: number;
    topLanguage: string;
    languageBreakdown: Record<string, number>;
    cleanScore: number;
  }): void {
    if (this.view) {
      this.view.webview.postMessage({
        type: "cloud_stats",
        data: stats,
      });
    }
  }

  /** Set the welcome greeting to show in the sidebar banner */
  setWelcomeGreeting(greeting: string, userName: string, petName: string): void {
    this.pendingWelcome = { greeting, userName, petName };
    // If view is already resolved, force-refresh the HTML so the banner appears
    if (this.view) {
      this.view.webview.html = this.getHtml(this.view.webview, this.pendingWelcome);
    }
  }

  resolveWebviewView(
    webviewView: vscode.WebviewView,
    _context: vscode.WebviewViewResolveContext,
    _token: vscode.CancellationToken
  ): void {
    this.view = webviewView;

    webviewView.webview.options = {
      enableScripts: true,
      localResourceRoots: [this.extensionUri],
    };

    // Rescan BEFORE generating HTML so the scanner has fresh data to embed
    if (this.codeScanner) {
      this.codeScanner.rescanActiveEditor();
    }

    webviewView.webview.html = this.getHtml(webviewView.webview, this.pendingWelcome ?? undefined);

    // Listen for messages from webview
    this.disposables.push(
      webviewView.webview.onDidReceiveMessage(async (msg) => {
        switch (msg.command) {
          case "refresh":
            this.fileWatcher.refresh();
            this.pushUpdate();
            break;
          case "openSettings":
            vscode.commands.executeCommand(
              "workbench.action.openSettings",
              "codepet"
            );
            break;
          case "goToError": {
            // Jump to the error line in the active editor
            const editor = vscode.window.activeTextEditor;
            if (editor && typeof msg.line === "number") {
              const line = Math.max(0, msg.line - 1); // 1-indexed → 0-indexed
              const pos = new vscode.Position(line, msg.column ?? 0);
              editor.selection = new vscode.Selection(pos, pos);
              editor.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);
            }
            break;
          }
          case "applyFix": {
            const editor = vscode.window.activeTextEditor;
            if (editor && typeof msg.line === "number") {
              const line = Math.max(0, msg.line - 1);
              const pos = new vscode.Position(line, msg.column ?? 0);
              editor.selection = new vscode.Selection(pos, pos);
              editor.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);

              // 1. Try Codepet's own smart fix first (pattern-based findings)
              const fixed = await this.applySmartFix(editor, line, msg.code ?? "", msg.source ?? "");
              if (fixed) {
                this.lastSummarySig = "";
                this.forceRescanAndRefresh();
                break;
              }

              // 2. Try VS Code's QUICKFIX code actions only — never refactorings
              try {
                const range = new vscode.Range(pos, pos.translate(0, 1));
                const actions = await vscode.commands.executeCommand<vscode.CodeAction[]>(
                  "vscode.executeCodeActionProvider",
                  editor.document.uri,
                  range
                );

                if (actions && actions.length > 0) {
                  const quickfixes = actions.filter(a => {
                    const kindStr = a.kind?.value ?? "";
                    if (!kindStr.startsWith("quickfix")) return false;
                    if (!a.edit) return false;
                    return true;
                  });

                  const best = quickfixes.find(a => a.isPreferred) ?? quickfixes[0];
                  if (best && best.edit) {
                    await vscode.workspace.applyEdit(best.edit);
                    vscode.window.showInformationMessage(
                      `🐾 Byte fixed it: ${best.title}`,
                      "Undo"
                    ).then((action) => {
                      if (action === "Undo") {
                        vscode.commands.executeCommand("undo");
                        this.forceRescanAndRefresh();
                      }
                    });
                    this.lastSummarySig = "";
                    this.forceRescanAndRefresh();
                    break;
                  }
                }
              } catch {
                // Code action provider failed, continue to fallback
              }

              // 3. Force rescan (maybe the finding is already resolved)
              this.lastSummarySig = "";
              this.forceRescanAndRefresh();
            }
            break;
          }
          case "autoFixAll": {
            const editor = vscode.window.activeTextEditor;
            if (!editor || !this.codeScanner) break;

            const uri = editor.document.uri.toString();
            const result = this.codeScanner.getResultForUri(uri);
            if (!result || result.findings.length === 0) break;

            // Ask permission before bulk auto-fix
            // Include both pattern-based AND diagnostic findings
            const fixable = result.findings.filter(f =>
              f.severity !== "clean" && (
                (f.source === "pattern" && this.canAutoFix(f.code)) ||
                f.source === "diagnostics"
              )
            );

            if (fixable.length === 0) {
              vscode.window.showInformationMessage("🐾 No auto-fixable issues found. Opening quick fix for manual review.");
              vscode.commands.executeCommand("editor.action.quickFix");
              break;
            }

            // Apply all fixes immediately — no confirmation dialog
            // Bottom-to-top so line numbers stay valid
            const sorted = [...fixable].sort((a, b) => b.line - a.line);
            let fixedCount = 0;
            for (const f of sorted) {
              if (f.source === "pattern") {
                const ok = await this.applySmartFix(editor, f.line, f.code, f.source, true);
                if (ok) fixedCount++;
              } else if (f.source === "diagnostics") {
                // Use the fix engine for TS diagnostics
                const r = fixEngine.applyFix({
                  doc: editor.document,
                  line: f.line,
                  startChar: f.column,
                  endLine: f.endLine ?? f.line,
                  endChar: f.endColumn ?? 0,
                  tsCode: parseInt(f.code) || 0,
                  message: f.message,
                });
                if (r.success) {
                  await vscode.workspace.applyEdit(r.edit);
                  fixedCount++;
                }
              }
            }
            const petName = vscode.workspace.getConfiguration("codepet").get<string>("petName") ?? "Byte";
            if (fixedCount > 0) {
              vscode.window.showInformationMessage(
                `🐾 ${petName} fixed ${fixedCount} issue${fixedCount > 1 ? "s" : ""}!`,
                "Undo All"
              ).then((action) => {
                if (action === "Undo All") {
                  for (let i = 0; i < fixedCount; i++) {
                    vscode.commands.executeCommand("undo");
                  }
                  this.lastSummarySig = "";
                  this.forceRescanAndRefresh();
                }
              });
            }
            // Always force rescan after fix-all (clears stale diagnostics)
            this.lastSummarySig = "";
            this.forceRescanAndRefresh();
            break;
          }
          case "fixTsDiagnostic": {
            // Use the fix engine (same as hover-link fixTsDiagnostic command)
            const editor = vscode.window.activeTextEditor;
            if (editor && typeof msg.line === "number") {
              const result = fixEngine.applyFix({
                doc: editor.document,
                line: Math.max(0, msg.line - 1), // sidebar uses 1-based lines
                startChar: msg.startChar ?? 0,
                endLine: Math.max(0, (msg.endLine ?? msg.line) - 1),
                endChar: msg.endChar ?? 0,
                tsCode: msg.tsCode ?? 0,
                message: msg.message ?? "",
              });

              if (result.success) {
                await vscode.workspace.applyEdit(result.edit);
                const petName = vscode.workspace.getConfiguration("codepet").get<string>("petName") ?? "Byte";
                vscode.window.showInformationMessage(
                  `🐾 ${petName} fixed it: ${result.description}`,
                  "Undo"
                ).then((action) => {
                  if (action === "Undo") {
                    vscode.commands.executeCommand("undo");
                    this.forceRescanAndRefresh();
                  }
                });
                this.lastSummarySig = "";
                this.forceRescanAndRefresh();
              } else {
                // Fallback: try VS Code's own quick fixes
                const pos = new vscode.Position(Math.max(0, msg.line - 1), msg.startChar ?? 0);
                editor.selection = new vscode.Selection(pos, pos);
                editor.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);
                try {
                  const range = new vscode.Range(pos, pos.translate(0, 1));
                  const actions = await vscode.commands.executeCommand<vscode.CodeAction[]>(
                    "vscode.executeCodeActionProvider",
                    editor.document.uri,
                    range
                  );
                  const quickfixes = (actions ?? []).filter(a => {
                    const kindStr = a.kind?.value ?? "";
                    return kindStr.startsWith("quickfix") && !!a.edit;
                  });
                  const best = quickfixes.find(a => a.isPreferred) ?? quickfixes[0];
                  if (best && best.edit) {
                    await vscode.workspace.applyEdit(best.edit);
                    const petName = vscode.workspace.getConfiguration("codepet").get<string>("petName") ?? "Byte";
                    vscode.window.showInformationMessage(
                      `🐾 ${petName} fixed it: ${best.title}`,
                      "Undo"
                    ).then((action) => {
                      if (action === "Undo") {
                        vscode.commands.executeCommand("undo");
                        this.forceRescanAndRefresh();
                      }
                    });
                    this.lastSummarySig = "";
                    this.forceRescanAndRefresh();
                    break;
                  }
                } catch { /* ignore */ }

                // No fix available — force rescan to clear stale findings, then inform user
                this.lastSummarySig = "";
                this.forceRescanAndRefresh();
              }
            }
            break;
          }
          case "dismissFinding": {
            // Dismiss a specific finding (hide from sidebar)
            // Could track dismissed findings in workspaceState if needed
            break;
          }
          case "webviewReady": {
            // Webview script has loaded and is ready to receive messages.
            // Push all data now — previous sends during HTML load were likely lost.
            this.lastSummarySig = "";
            this.pushUpdate();
            this.pushScanUpdate();
            if (this.userProfile) {
              this.setUserProfile(this.userProfile);
            }
            break;
          }
        }
      })
    );

    // Push data on changes
    this.disposables.push(
      this.fileWatcher.onDataChanged(() => this.pushUpdate())
    );
    this.disposables.push(
      this.sessionTracker.onSessionUpdate(() => this.pushUpdate())
    );
    this.disposables.push(
      this.triggerEngine.onTrigger((e) => this.pushTriggerEvent(e))
    );

    // Scanner events → update Code Health card (both summary AND per-file findings)
    if (this.codeScanner) {
      this.disposables.push(
        this.codeScanner.onSummaryChanged(() => this.pushScanUpdate())
      );
      // Also refresh on EVERY individual scan complete (findings may change even if totals don't)
      this.disposables.push(
        this.codeScanner.onScanComplete(() => this.pushScanUpdate())
      );
    }

    // When the user switches files, refresh findings cards immediately
    this.disposables.push(
      vscode.window.onDidChangeActiveTextEditor(() => {
        // Small delay to let VS Code diagnostics settle for the new file
        setTimeout(() => this.pushScanUpdate(), 200);
      })
    );

    // When VS Code's built-in diagnostics change (TypeScript, ESLint, etc.), rescan + refresh cards
    // Throttled to avoid rapid-fire updates
    let diagThrottle: NodeJS.Timeout | undefined;
    this.disposables.push(
      vscode.languages.onDidChangeDiagnostics(() => {
        if (diagThrottle) clearTimeout(diagThrottle);
        diagThrottle = setTimeout(() => {
          // Rescan to pick up the new external diagnostics
          if (this.codeScanner) {
            this.codeScanner.rescanActiveEditor();
          }
          this.pushScanUpdate();
        }, 300);
      })
    );

    // Initial push — scan data is already embedded in the HTML (via __initialScan),
    // so we just need to push the live session stats. Delayed retries ensure the
    // webview picks up any diagnostic changes that arrive after initial render.
    this.pushUpdate();
    this.lastSummarySig = ""; // Ensure first postMessage-based update isn't deduped
    setTimeout(() => {
      this.lastSummarySig = "";
      this.pushUpdate();
      this.pushScanUpdate();
    }, 1000);
    setTimeout(() => {
      this.lastSummarySig = "";
      this.pushUpdate();
      this.pushScanUpdate();
    }, 3000);

    // Live timer: refresh the display every 10 seconds so coding time ticks in real-time
    if (this.liveTimer) clearInterval(this.liveTimer);
    this.liveTimer = setInterval(() => this.pushUpdate(), 10_000);

    // Push profile if already loaded
    if (this.userProfile) {
      this.setUserProfile(this.userProfile);
    }
  }

  /** Send full state snapshot to webview */
  private pushUpdate(): void {
    if (!this.view) return;

    const petName = this.resolvedPetName;
    const summary = this.fileWatcher.todaySummary;
    const stats = this.sessionTracker.stats;

    this.view.webview.postMessage({
      type: "update",
      data: {
        petName,
        isConnected: this.fileWatcher.isConnected || this.isCloudLinked,
        isCloudLinked: this.isCloudLinked,
        // Session stats
        codingTime: this.sessionTracker.codingTimeFormatted,
        codingMinutes: stats.codingMinutes,
        totalEdits: stats.totalEdits,
        filesEdited: stats.filesEdited.size,
        linesAdded: stats.linesAdded,
        linesRemoved: stats.linesRemoved,
        isIdle: stats.isIdle,
        currentBranch: stats.currentBranch,
        topLanguage: this.sessionTracker.topLanguage,
        languageBreakdown: Object.fromEntries(stats.languageBreakdown),
        // MCP data
        summary: summary
          ? {
              totalCodingMinutes: summary.totalCodingMinutes,
              linesAdded: summary.linesAdded,
              linesRemoved: summary.linesRemoved,
              commits: summary.commits,
              aiSessions: summary.aiSessions,
              errorsFixed: summary.errorsFixed,
              languageBreakdown: summary.languageBreakdown,
              skillsTracked: summary.skillsTracked,
              petReaction: summary.petReaction,
            }
          : null,
        skillProgress: this.fileWatcher.skillProgress,
        totalSkillXP: this.fileWatcher.totalSkillXP,
        activeDays: this.fileWatcher.activeDaysCount,
        todayEventCount: this.fileWatcher.todayEvents.length,
      },
    });
  }

  /** Send a trigger event to the webview feed */
  private pushTriggerEvent(event: TriggerEvent): void {
    if (!this.view) return;
    this.view.webview.postMessage({
      type: "trigger",
      data: {
        eventType: event.type,
        title: event.title,
        message: event.message,
        timestamp: new Date().toISOString(),
      },
    });
  }

  // ───── Smart Auto-Fix Engine ─────
  // Codepet's own fixes for pattern-based findings. These are safe,
  // deterministic text edits — no AI needed, just good engineering.

  /** Pattern IDs that Codepet can auto-fix */
  private static readonly AUTO_FIXABLE = new Set([
    // ── Remove line ──
    "debugger-statement",
    "console-log",
    "python-print",
    "python-pass-only",
    "swift-print",
    "go-fmt-println",
    // ── Transform ──
    "var-declaration",      // var → let
    "triple-equals",        // == → ===
    "loose-inequality",     // != → !==
    "any-type",             // remove explicit : any annotation
    // ── Smart rewrite ──
    "todo-comment",         // Remove TODO line
    "fixme-comment",        // Remove FIXME line
    "python-todo",          // Remove # TODO line
    "empty-catch",          // Add error logging
    "python-bare-except",   // except: → except Exception as e:
    "nested-ternary",       // Convert to if/else
    "magic-number",         // Extract to named constant
    "html-missing-alt",     // Add empty alt=""
    "swift-force-unwrap",   // x! → x ?? defaultValue
    "swift-force-cast",     // as! Type → as? Type
    "rust-unwrap",          // .unwrap() → .unwrap_or_default()
    "go-ignored-error",     // _, err → handle error
  ]);

  /** Check if a finding code is auto-fixable by Codepet */
  private canAutoFix(code: string): boolean {
    return SidebarProvider.AUTO_FIXABLE.has(code);
  }

  /**
   * Apply a smart fix for a pattern-based finding.
   * Returns true if the fix was applied, false if no fix available.
   */
  private async applySmartFix(
    editor: vscode.TextEditor,
    line: number,
    code: string,
    source: string,
    silent: boolean = false
  ): Promise<boolean> {
    // Only auto-fix our own pattern findings
    if (source !== "pattern" || !this.canAutoFix(code)) {
      return false;
    }

    const doc = editor.document;
    const lineText = doc.lineAt(line).text;
    const indent = lineText.match(/^(\s*)/)?.[1] ?? "";
    let fixApplied = false;
    let fixDescription = "";

    const edit = new vscode.WorkspaceEdit();
    const lineRange = doc.lineAt(line).rangeIncludingLineBreak;

    switch (code) {
      // ═══════ Remove entire line ═══════

      case "debugger-statement": {
        edit.delete(doc.uri, lineRange);
        fixDescription = "Removed debugger statement";
        fixApplied = true;
        break;
      }

      case "console-log": {
        edit.delete(doc.uri, lineRange);
        fixDescription = "Removed console.log";
        fixApplied = true;
        break;
      }

      case "python-print": {
        edit.delete(doc.uri, lineRange);
        fixDescription = "Removed print()";
        fixApplied = true;
        break;
      }

      case "swift-print": {
        edit.delete(doc.uri, lineRange);
        fixDescription = "Removed print()";
        fixApplied = true;
        break;
      }

      case "go-fmt-println": {
        edit.delete(doc.uri, lineRange);
        fixDescription = "Removed fmt.Println";
        fixApplied = true;
        break;
      }

      case "python-pass-only": {
        edit.delete(doc.uri, lineRange);
        fixDescription = "Removed empty pass";
        fixApplied = true;
        break;
      }

      case "todo-comment":
      case "fixme-comment":
      case "python-todo": {
        edit.delete(doc.uri, lineRange);
        fixDescription = "Removed TODO/FIXME comment";
        fixApplied = true;
        break;
      }

      // ═══════ Simple transforms ═══════

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
        // Remove the explicit `: any` annotation — TypeScript will infer the type
        // This is safer than changing to `: unknown` which causes cascading errors
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

      // ═══════ Smart rewrites ═══════

      case "empty-catch": {
        // catch (err) {} → catch (err) { console.error(err); }
        // Find the empty {} after catch
        const catchMatch = lineText.match(/catch\s*\(([^)]*)\)\s*\{\s*\}/);
        if (catchMatch && catchMatch.index !== undefined) {
          const errVar = catchMatch[1].trim() || "err";
          const braceStart = lineText.indexOf("{", catchMatch.index + 5);
          const braceEnd = lineText.indexOf("}", braceStart) + 1;
          const start = new vscode.Position(line, braceStart);
          const end = new vscode.Position(line, braceEnd);
          edit.replace(
            doc.uri,
            new vscode.Range(start, end),
            `{\n${indent}  console.error("Error caught:", ${errVar});\n${indent}}`
          );
          fixDescription = "Added error logging to empty catch";
          fixApplied = true;
        }
        break;
      }

      case "python-bare-except": {
        // except: → except Exception as e:\n    logging.exception(e)
        const exceptMatch = lineText.match(/\bexcept\s*:/);
        if (exceptMatch && exceptMatch.index !== undefined) {
          const start = new vscode.Position(line, exceptMatch.index);
          const end = new vscode.Position(line, exceptMatch.index + exceptMatch[0].length);
          edit.replace(doc.uri, new vscode.Range(start, end), "except Exception as e:");
          // Check if next line is pass or empty — add logging
          if (line + 1 < doc.lineCount) {
            const nextLine = doc.lineAt(line + 1).text.trim();
            if (nextLine === "pass" || nextLine === "") {
              const nextRange = doc.lineAt(line + 1).rangeIncludingLineBreak;
              edit.replace(doc.uri, nextRange, `${indent}    logging.exception(e)\n`);
            }
          }
          fixDescription = "Added specific exception handling";
          fixApplied = true;
        }
        break;
      }

      case "nested-ternary": {
        // Parse top-level ternary and rewrite as if/else
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
          for (let ci = 0; ci < expr.length; ci++) {
            const ch = expr[ci];
            if (ch === "(" || ch === "[" || ch === "{") depth++;
            else if (ch === ")" || ch === "]" || ch === "}") depth--;
            else if (ch === "?" && depth === 0 && questionIdx === -1) questionIdx = ci;
            else if (ch === ":" && depth === 0 && questionIdx !== -1 && colonIdx === -1) colonIdx = ci;
          }

          if (questionIdx > 0 && colonIdx > questionIdx) {
            const condition = expr.substring(0, questionIdx).trim();
            let trueExpr = expr.substring(questionIdx + 1, colonIdx).trim();
            let falseExpr = expr.substring(colonIdx + 1).trim();
            if (trueExpr.startsWith("(") && trueExpr.endsWith(")")) trueExpr = trueExpr.slice(1, -1).trim();
            if (falseExpr.startsWith("(") && falseExpr.endsWith(")")) falseExpr = falseExpr.slice(1, -1).trim();

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
        const numMatch = lineText.match(/\b([2-9]\d{2,}|[1-9]\d{3,})\b/);
        if (numMatch && numMatch.index !== undefined) {
          const num = numMatch[1];
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

          const start = new vscode.Position(line, numMatch.index);
          const end = new vscode.Position(line, numMatch.index + num.length);
          edit.replace(doc.uri, new vscode.Range(start, end), constName);
          edit.insert(doc.uri, new vscode.Position(line, 0), `${indent}const ${constName} = ${num};\n`);
          fixDescription = `Extracted magic number ${num} → ${constName}`;
          fixApplied = true;
        }
        break;
      }

      case "html-missing-alt": {
        // <img src="..." > → <img src="..." alt="" >
        const imgMatch = lineText.match(/<img\s+/);
        if (imgMatch && imgMatch.index !== undefined) {
          // Insert alt="" before the closing >
          const closingBracket = lineText.lastIndexOf(">");
          if (closingBracket > 0) {
            const insertPos = lineText[closingBracket - 1] === "/" ? closingBracket - 1 : closingBracket;
            const pos = new vscode.Position(line, insertPos);
            edit.insert(doc.uri, pos, ' alt=""');
            fixDescription = 'Added alt="" for accessibility';
            fixApplied = true;
          }
        }
        break;
      }

      case "swift-force-unwrap": {
        // variable! → variable ?? <default>
        const unwrapMatch = lineText.match(/(\w+)!/);
        if (unwrapMatch && unwrapMatch.index !== undefined) {
          const varName = unwrapMatch[1];
          const start = new vscode.Position(line, unwrapMatch.index);
          const end = new vscode.Position(line, unwrapMatch.index + unwrapMatch[0].length);
          // Use a sensible default based on context
          edit.replace(doc.uri, new vscode.Range(start, end), `${varName} ?? nil`);
          fixDescription = "Replaced force unwrap with nil coalescing";
          fixApplied = true;
        }
        break;
      }

      case "swift-force-cast": {
        // as! Type → as? Type
        const castMatch = lineText.match(/\bas!\s/);
        if (castMatch && castMatch.index !== undefined) {
          const start = new vscode.Position(line, castMatch.index);
          const end = new vscode.Position(line, castMatch.index + 3); // "as!" is 3 chars
          edit.replace(doc.uri, new vscode.Range(start, end), "as?");
          fixDescription = "Changed force cast to optional cast";
          fixApplied = true;
        }
        break;
      }

      case "rust-unwrap": {
        // .unwrap() → .unwrap_or_default()
        const rustMatch = lineText.match(/\.unwrap\s*\(\s*\)/);
        if (rustMatch && rustMatch.index !== undefined) {
          const start = new vscode.Position(line, rustMatch.index);
          const end = new vscode.Position(line, rustMatch.index + rustMatch[0].length);
          edit.replace(doc.uri, new vscode.Range(start, end), ".unwrap_or_default()");
          fixDescription = "Changed .unwrap() to .unwrap_or_default()";
          fixApplied = true;
        }
        break;
      }

      case "go-ignored-error": {
        // _, _ = something() → result, err := something()\nif err != nil { return err }
        // Simplified: just add a comment flagging it
        const goMatch = lineText.match(/,\s*_\s*(:?=)/);
        if (goMatch && goMatch.index !== undefined) {
          const assignOp = goMatch[1];
          const underscoreStart = lineText.indexOf("_", goMatch.index + 1);
          const start = new vscode.Position(line, underscoreStart);
          const end = new vscode.Position(line, underscoreStart + 1);
          edit.replace(doc.uri, new vscode.Range(start, end), "err");
          // Add error check on next line
          const insertPos = new vscode.Position(line + 1, 0);
          edit.insert(doc.uri, insertPos, `${indent}if err != nil {\n${indent}\treturn err\n${indent}}\n`);
          fixDescription = "Added error handling";
          fixApplied = true;
        }
        break;
      }
    }

    if (fixApplied) {
      await vscode.workspace.applyEdit(edit);
      if (!silent) {
        vscode.window.showInformationMessage(
          `🐾 Byte fixed it: ${fixDescription}`,
          "Undo"
        ).then((action) => {
          if (action === "Undo") {
            vscode.commands.executeCommand("undo");
            this.lastSummarySig = "";
            setTimeout(() => this.pushScanUpdate(), 300);
          }
        });
      }
    }

    return fixApplied;
  }

  /** Send code scanner summary + per-finding cards to webview */
  /**
   * Force a full rescan + sidebar refresh after applying fixes.
   * Delays to give TypeScript time to reprocess diagnostics,
   * then rescans to pick up the cleared diagnostics, then pushes to sidebar.
   */
  private forceRescanAndRefresh(): void {
    // Quick push to show immediate feedback
    this.lastSummarySig = "";
    this.pushScanUpdate();

    // After 500ms: TypeScript has likely reprocessed → rescan to get fresh diagnostics
    setTimeout(() => {
      if (this.codeScanner) {
        this.codeScanner.rescanActiveEditor();
      }
      this.lastSummarySig = "";
      this.pushScanUpdate();
    }, 500);

    // Safety net at 1.5s: rescan again in case TS was slow
    setTimeout(() => {
      if (this.codeScanner) {
        this.codeScanner.rescanActiveEditor();
      }
      this.lastSummarySig = "";
      this.pushScanUpdate();
    }, 1500);
  }

  private pushScanUpdate(): void {
    if (!this.view || !this.codeScanner) return;
    const summary = this.codeScanner.summary;

    // Dedup: skip if the summary AND active file findings haven't changed
    const activeUri = vscode.window.activeTextEditor?.document.uri.toString() ?? "";
    const activeResult = activeUri ? this.codeScanner.getResultForUri(activeUri) : undefined;
    const findingsSig = activeResult
      ? activeResult.findings.filter(f => f.severity !== "clean").map(f => `${f.line}:${f.message}`).join("|")
      : "";
    const sig = `${summary.totalErrors}:${summary.totalWarnings}:${summary.cleanFiles}:${summary.totalFiles}:${activeUri}:${findingsSig}`;
    if (sig === this.lastSummarySig) return;
    this.lastSummarySig = sig;

    let petMessage = "";
    let petMood = "neutral";
    if (this.petReactions) {
      const reaction = this.petReactions.reactToSummary(summary);
      petMessage = reaction.message;
      petMood = reaction.mood;
    }

    // Get individual findings for the active file (Grammarly-style cards)
    // activeUri and activeResult already computed above for dedup
    const findings = activeResult
      ? activeResult.findings
          .filter((f) => f.severity !== "clean")
          .slice(0, 10)
          .map((f) => ({
            severity: f.severity,
            line: f.line + 1, // 0-indexed → 1-indexed for display
            column: f.column,
            message: f.message,
            code: f.code,
            source: f.source,
            suggestion: f.suggestion ?? null,
            autoFixable: (f.source === "pattern" && this.canAutoFix(f.code)),
            // Diagnostic range data for fix engine
            startChar: f.column,
            endLine: (f.endLine ?? f.line) + 1,
            endChar: f.endColumn ?? 0,
          }))
      : [];

    this.view.webview.postMessage({
      type: "scan_update",
      data: {
        totalErrors: summary.totalErrors,
        totalWarnings: summary.totalWarnings,
        cleanFiles: summary.cleanFiles,
        totalFiles: summary.totalFiles,
        averageCleanScore: summary.averageCleanScore,
        topIssue: summary.topIssue,
        petMessage,
        petMood,
        // Grammarly-style: individual findings for active file
        activeFile: activeResult ? activeUri?.split("/").pop() : null,
        findings,
      },
    });
  }


  /** Build the full sidebar HTML */
  private getHtml(webview: vscode.Webview, welcome?: { greeting: string; userName: string; petName: string }): string {
    const nonce = getNonce();

    // Build URIs for all 8 character SVGs
    const charNames = ["byte", "nova", "crash", "luna", "sage", "glitch", "zero", "null"];
    const charUris: Record<string, string> = {};
    for (const name of charNames) {
      const uri = webview.asWebviewUri(
        vscode.Uri.joinPath(this.extensionUri, "media", `char-${name}.svg`)
      );
      charUris[name] = uri.toString();
    }
    const charUrisJson = JSON.stringify(charUris);

    // Pre-compute initial scan data to embed directly in the HTML
    // This bypasses all postMessage timing issues for the first render
    let initialScanJson = "null";
    if (this.codeScanner) {
      const summary = this.codeScanner.summary;
      const activeUri = vscode.window.activeTextEditor?.document.uri.toString() ?? "";
      const activeResult = activeUri ? this.codeScanner.getResultForUri(activeUri) : undefined;

      let petMessage = "";
      let petMood = "neutral";
      if (this.petReactions) {
        const reaction = this.petReactions.reactToSummary(summary);
        petMessage = reaction.message;
        petMood = reaction.mood;
      }

      const findings = activeResult
        ? activeResult.findings
            .filter((f) => f.severity !== "clean")
            .slice(0, 10)
            .map((f) => ({
              severity: f.severity,
              line: f.line + 1,
              column: f.column,
              message: f.message,
              code: f.code,
              source: f.source,
              suggestion: f.suggestion ?? null,
              autoFixable: (f.source === "pattern" && this.canAutoFix(f.code)),
              startChar: f.column,
              endLine: (f.endLine ?? f.line) + 1,
              endChar: f.endColumn ?? 0,
            }))
        : [];

      initialScanJson = JSON.stringify({
        totalErrors: summary.totalErrors,
        totalWarnings: summary.totalWarnings,
        cleanFiles: summary.cleanFiles,
        totalFiles: summary.totalFiles,
        averageCleanScore: summary.averageCleanScore,
        topIssue: summary.topIssue,
        petMessage,
        petMood,
        activeFile: activeResult ? activeUri?.split("/").pop() : null,
        findings,
      });
    }

    const initialPetKey = this.resolvedPetName.toLowerCase();
    const initialAvatarUri = charUris[initialPetKey] || charUris["nova"] || "";

    return /*html*/ `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta http-equiv="Content-Security-Policy"
    content="default-src 'none'; img-src ${webview.cspSource}; style-src ${webview.cspSource} 'unsafe-inline'; script-src 'nonce-${nonce}';" />
  <title>Codepet v0.9.2</title>
  <style>
    /* ───── Reset & Base ───── */
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      background: var(--vscode-sideBar-background);
      padding: 12px;
      overflow-x: hidden;
    }

    /* ───── Welcome Banner ───── */
    .welcome-banner {
      background: linear-gradient(135deg, #7B6BD8 0%, #534AB7 100%);
      border-radius: 8px;
      padding: 14px 16px;
      margin-bottom: 10px;
      color: #fff;
      display: flex;
      align-items: center;
      justify-content: space-between;
      animation: welcomeSlideIn 0.4s ease-out;
      position: relative;
    }
    @keyframes welcomeSlideIn {
      from { opacity: 0; transform: translateY(-10px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .welcome-greeting {
      font-size: 15px;
      font-weight: 700;
      margin-bottom: 2px;
    }
    .welcome-sub {
      font-size: 11px;
      opacity: 0.85;
    }
    .welcome-dismiss {
      background: none;
      border: none;
      color: rgba(255,255,255,0.7);
      font-size: 18px;
      cursor: pointer;
      padding: 4px 8px;
      border-radius: 4px;
      flex-shrink: 0;
    }
    .welcome-dismiss:hover {
      background: rgba(255,255,255,0.15);
      color: #fff;
    }

    /* ───── Cards ───── */
    .card {
      background: var(--vscode-editor-background);
      border: 1px solid var(--vscode-panel-border, #333);
      border-radius: 6px;
      padding: 12px;
      margin-bottom: 10px;
    }
    .card-title {
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: var(--vscode-descriptionForeground);
      margin-bottom: 8px;
    }

    /* ───── Pet Widget ───── */
    .pet-widget {
      text-align: center;
      padding: 16px 12px;
    }
    .pet-avatar {
      width: 80px;
      height: 100px;
      margin: 0 auto 8px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .pet-avatar img {
      width: 100%;
      height: 100%;
      object-fit: contain;
    }
    .pet-name {
      font-size: 16px;
      font-weight: 700;
      color: var(--vscode-foreground);
    }
    .pet-reaction {
      font-size: 12px;
      color: var(--vscode-descriptionForeground);
      margin-top: 4px;
      font-style: italic;
    }
    .connection-badge {
      display: inline-block;
      font-size: 10px;
      padding: 2px 8px;
      border-radius: 10px;
      margin-top: 6px;
    }
    .connected { background: #2ea04333; color: #3fb950; }
    .disconnected { background: #f8514933; color: #f85149; }

    /* ───── Stats Grid ───── */
    .stats-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
    }
    .stat-chip {
      background: var(--vscode-badge-background, #333);
      border-radius: 6px;
      padding: 8px;
      text-align: center;
    }
    .stat-value {
      font-size: 18px;
      font-weight: 700;
      color: var(--vscode-foreground);
    }
    .stat-label {
      font-size: 10px;
      color: var(--vscode-descriptionForeground);
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }

    /* ───── Language Bar ───── */
    .lang-bar-container { margin-top: 8px; }
    .lang-bar {
      height: 8px;
      border-radius: 4px;
      overflow: hidden;
      display: flex;
      background: var(--vscode-badge-background, #333);
    }
    .lang-segment { height: 100%; min-width: 3px; }
    .lang-legend {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      margin-top: 6px;
    }
    .lang-legend-item {
      display: flex;
      align-items: center;
      gap: 4px;
      font-size: 10px;
      color: var(--vscode-descriptionForeground);
    }
    .lang-dot {
      width: 8px;
      height: 8px;
      border-radius: 2px;
    }

    /* ───── Skill Bars ───── */
    .skill-item {
      margin-bottom: 8px;
    }
    .skill-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 3px;
    }
    .skill-name {
      font-size: 11px;
      font-weight: 600;
    }
    .skill-level {
      font-size: 10px;
      color: var(--vscode-descriptionForeground);
    }
    .skill-bar {
      height: 6px;
      background: var(--vscode-badge-background, #333);
      border-radius: 3px;
      overflow: hidden;
    }
    .skill-fill {
      height: 100%;
      border-radius: 3px;
      transition: width 0.3s ease;
    }

    /* ───── Event Feed ───── */
    .event-item {
      padding: 6px 0;
      border-bottom: 1px solid var(--vscode-panel-border, #222);
      font-size: 11px;
    }
    .event-item:last-child { border-bottom: none; }
    .event-type {
      font-weight: 600;
      margin-right: 4px;
    }
    .event-time {
      font-size: 10px;
      color: var(--vscode-descriptionForeground);
      float: right;
    }

    /* ───── Toolbar ───── */
    .toolbar {
      display: flex;
      gap: 6px;
      margin-bottom: 10px;
    }
    .toolbar button {
      flex: 1;
      padding: 6px;
      font-size: 11px;
      background: var(--vscode-button-secondaryBackground);
      color: var(--vscode-button-secondaryForeground);
      border: none;
      border-radius: 4px;
      cursor: pointer;
    }
    .toolbar button:hover {
      background: var(--vscode-button-secondaryHoverBackground);
    }

    /* ───── Empty State ───── */
    .empty-state {
      text-align: center;
      padding: 24px 12px;
      color: var(--vscode-descriptionForeground);
      font-size: 12px;
    }
    .empty-state .icon { font-size: 32px; margin-bottom: 8px; }

    /* ───── Session Info ───── */
    .session-info {
      font-size: 11px;
      color: var(--vscode-descriptionForeground);
      display: flex;
      justify-content: space-between;
      margin-bottom: 4px;
    }

    .idle-badge {
      display: inline-block;
      font-size: 10px;
      padding: 1px 6px;
      border-radius: 8px;
      background: #e3b34133;
      color: #e3b341;
    }

    /* ───── Code Health / Scanner ───── */
    .scan-summary {
      display: flex;
      align-items: center;
      gap: 16px;
    }
    .clean-score-ring {
      width: 64px;
      height: 64px;
      border-radius: 50%;
      border: 4px solid #3fb950;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      transition: border-color 0.3s;
    }
    .clean-score-ring.warning { border-color: #e3b341; }
    .clean-score-ring.error { border-color: #f85149; }
    .clean-score-value {
      font-size: 18px;
      font-weight: 700;
      line-height: 1;
    }
    .clean-score-label {
      font-size: 9px;
      color: var(--vscode-descriptionForeground);
      text-transform: uppercase;
    }
    .scan-stats {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .scan-stat {
      font-size: 11px;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .scan-stat-icon { font-size: 8px; }
    .pet-scan-message {
      margin-top: 10px;
      padding: 8px;
      border-radius: 6px;
      background: var(--vscode-badge-background, #333);
      font-size: 11px;
      display: flex;
      align-items: flex-start;
      gap: 6px;
      line-height: 1.4;
    }
    .pet-scan-mood { font-size: 16px; flex-shrink: 0; }

    /* ───── Grammarly-style Error Cards ───── */
    .findings-list {
      margin-top: 10px;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .findings-file-label {
      font-size: 10px;
      color: var(--vscode-descriptionForeground);
      margin-bottom: 2px;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .finding-card {
      border-radius: 6px;
      padding: 8px 10px;
      cursor: pointer;
      transition: background 0.15s, transform 0.15s, opacity 0.2s;
      border-left: 3px solid transparent;
    }
    .finding-card:hover {
      transform: translateX(2px);
    }
    .finding-card.error {
      background: rgba(248, 81, 73, 0.12);
      border-left-color: #f85149;
    }
    .finding-card.error:hover {
      background: rgba(248, 81, 73, 0.20);
    }
    .finding-card.warning {
      background: rgba(227, 179, 65, 0.12);
      border-left-color: #e3b341;
    }
    .finding-card.warning:hover {
      background: rgba(227, 179, 65, 0.20);
    }
    .finding-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 4px;
    }
    .finding-severity {
      font-size: 10px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.3px;
    }
    .finding-severity.error { color: #f85149; }
    .finding-severity.warning { color: #e3b341; }
    .finding-line {
      font-size: 10px;
      color: var(--vscode-descriptionForeground);
    }
    .finding-message {
      font-size: 11px;
      line-height: 1.4;
      color: var(--vscode-foreground);
      margin-bottom: 4px;
    }
    .finding-suggestion {
      font-size: 10px;
      color: #3fb950;
      line-height: 1.3;
      margin-bottom: 6px;
    }
    .finding-actions {
      display: flex;
      gap: 6px;
    }
    .finding-btn {
      font-size: 10px;
      padding: 3px 10px;
      border-radius: 4px;
      border: none;
      cursor: pointer;
      font-weight: 600;
      transition: background 0.15s;
    }
    .finding-btn-fix {
      background: #238636;
      color: #fff;
    }
    .finding-btn-fix:hover {
      background: #2ea043;
    }
    .finding-card.error .finding-btn-fix {
      background: #da3633;
    }
    .finding-card.error .finding-btn-fix:hover {
      background: #f85149;
    }
    .finding-card.warning .finding-btn-fix {
      background: #9e6a03;
    }
    .finding-card.warning .finding-btn-fix:hover {
      background: #bb8009;
    }
    .finding-btn-dismiss {
      background: transparent;
      color: var(--vscode-descriptionForeground);
      border: 1px solid var(--vscode-panel-border, #444);
    }
    .finding-btn-dismiss:hover {
      background: var(--vscode-list-hoverBackground, #333);
    }
    .finding-btn-goto {
      background: transparent;
      color: var(--vscode-textLink-foreground, #3794ff);
      border: 1px solid var(--vscode-textLink-foreground, #3794ff);
      font-size: 10px;
    }
    .finding-btn-goto:hover {
      background: rgba(55, 148, 255, 0.15);
    }
    .finding-btn-autofix {
      background: #238636 !important;
      color: #fff !important;
      font-weight: 600;
    }
    .finding-btn-autofix:hover {
      background: #2ea043 !important;
    }
    .findings-clean {
      text-align: center;
      padding: 12px;
      color: #3fb950;
      font-size: 12px;
    }
    .finding-nav {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 8px;
      padding-top: 6px;
      border-top: 1px solid var(--vscode-panel-border, #333);
    }
    .finding-nav-info {
      font-size: 10px;
      color: var(--vscode-descriptionForeground);
    }
    .finding-nav-arrows {
      display: flex;
      gap: 4px;
    }
    .finding-nav-btn {
      background: var(--vscode-button-secondaryBackground);
      border: none;
      color: var(--vscode-button-secondaryForeground);
      padding: 2px 8px;
      border-radius: 3px;
      cursor: pointer;
      font-size: 11px;
    }
    .finding-nav-btn:hover {
      background: var(--vscode-button-secondaryHoverBackground);
    }
  </style>
</head>
<body>
  <!-- DIAGNOSTIC: If you see this, v0.9.2 HTML is loaded -->
  <div id="welcome-banner" style="background:linear-gradient(135deg,#7B6BD8,#534AB7);border-radius:8px;padding:14px 16px;margin-bottom:10px;color:#fff;display:flex;align-items:center;justify-content:space-between;">
    <div>
      <div style="font-size:15px;font-weight:700;margin-bottom:2px;">${welcome ? (welcome.greeting + ', ' + welcome.userName + '!') : 'Welcome!'}</div>
      <div style="font-size:11px;opacity:0.85;">${welcome ? (welcome.petName + ' is ready to code with you.') : 'Codepet v0.9.2'}</div>
    </div>
    <button data-action="dismissWelcome" style="background:none;border:none;color:rgba(255,255,255,0.7);font-size:18px;cursor:pointer;padding:4px 8px;">&times;</button>
  </div>

  <!-- Pet Widget -->
  <div class="card pet-widget" id="pet-section">
    <div class="pet-avatar"><img id="pet-avatar-img" src="${initialAvatarUri}" alt="${this.resolvedPetName}" /></div>
    <div class="pet-name" id="pet-name">${this.resolvedPetName}</div>
    <div class="pet-reaction" id="pet-reaction">"Ready to code together!"</div>
    <div class="connection-badge ${this.isCloudLinked ? 'connected' : 'disconnected'}" id="connection-badge">${this.isCloudLinked ? 'Synced with macOS App' : 'Standalone Mode'}</div>
  </div>

  <!-- Toolbar -->
  <div class="toolbar">
    <button data-action="refresh">↻ Refresh</button>
    <button data-action="openSettings">⚙ Settings</button>
  </div>

  <!-- Today's Coding — uses cloud data when available, local session as fallback -->
  <div class="card">
    <div class="card-title">Today's Coding <span id="sync-badge" style="font-size:9px;opacity:0.5;display:none;">synced</span></div>
    <div class="session-info">
      <span id="branch-info">—</span>
      <span id="idle-status"></span>
    </div>
    <div class="stats-grid" id="session-stats">
      <div class="stat-chip">
        <div class="stat-value" id="coding-time">0m</div>
        <div class="stat-label">Coding Time</div>
      </div>
      <div class="stat-chip">
        <div class="stat-value" id="total-edits">0</div>
        <div class="stat-label">Edits</div>
      </div>
      <div class="stat-chip">
        <div class="stat-value" id="files-edited">0</div>
        <div class="stat-label">Files</div>
      </div>
      <div class="stat-chip">
        <div class="stat-value" id="lines-changed">0</div>
        <div class="stat-label">Lines ±</div>
      </div>
    </div>
  </div>

  <!-- Language Breakdown (merged into main view) -->
  <div class="card" id="lang-card" style="display:none;">
    <div class="card-title">Languages</div>
    <div class="lang-bar" id="lang-bar"></div>
    <div class="lang-legend" id="lang-legend"></div>
  </div>

  <!-- Skills -->
  <div class="card" id="skills-section" style="display:none;">
    <div class="card-title">Skill Progress</div>
    <div id="skills-list"></div>
  </div>

  <!-- Code Health (Scanner) — Grammarly-style -->
  <div class="card" id="scan-section">
    <div class="card-title">Code Health</div>
    <div class="scan-summary" id="scan-summary">
      <div class="clean-score-ring" id="clean-score-ring">
        <span class="clean-score-value" id="clean-score-value">—</span>
        <span class="clean-score-label">Clean</span>
      </div>
      <div class="scan-stats">
        <div class="scan-stat">
          <span class="scan-stat-icon" style="color:#f85149;">●</span>
          <span id="scan-errors">0</span> errors
        </div>
        <div class="scan-stat">
          <span class="scan-stat-icon" style="color:#e3b341;">●</span>
          <span id="scan-warnings">0</span> warnings
        </div>
        <div class="scan-stat">
          <span class="scan-stat-icon" style="color:#3fb950;">●</span>
          <span id="scan-clean-files">0</span>/<span id="scan-total-files">0</span> clean
        </div>
      </div>
    </div>
    <div class="pet-scan-message" id="pet-scan-message">
      <span class="pet-scan-mood" id="pet-scan-mood">🌟</span>
      <span id="pet-scan-text">Open a file to start scanning...</span>
    </div>
    <!-- Grammarly-style findings for active file -->
    <div id="findings-container"></div>
  </div>

  <!-- Activity Feed (v0.9.2 — with debug log) -->
  <div class="card" id="feed-section">
    <div class="card-title">Activity Feed</div>
    <div id="event-feed">
      <div class="empty-state">
        <div class="icon">🌟</div>
        v0.9.2 — Start coding to see activity!
      </div>
    </div>
  </div>

  <!-- Debug section removed — no longer needed -->

  <script nonce="${nonce}">
    const vscode = acquireVsCodeApi();
    const PET_CHARS = ${charUrisJson};

    function sendMsg(command) {
      vscode.postMessage({ command });
    }

    // ───── Language colors ─────
    const LANG_COLORS = {
      typescript: '#3178C6', javascript: '#F7DF1E', python: '#3572A5',
      swift: '#F05138', rust: '#DEA584', go: '#00ADD8', java: '#B07219',
      'c++': '#F34B7D', c: '#555555', ruby: '#CC342D', php: '#777BB3',
      html: '#E34C26', css: '#1572B6', json: '#292929', markdown: '#083FA1',
      shell: '#89E051', kotlin: '#A97BFF', dart: '#00B4AB',
    };

    // ───── Skill kingdom colors ─────
    const KINGDOM_COLORS = {
      'Molten Forge': '#F97316', 'Frozen Spire': '#38BDF8',
      'Eternal Garden': '#4ADE80', 'Mystic Grove': '#A78BFA',
    };

    // ───── Event feed (keep last 20) ─────
    const feedEvents = [];

    // ───── Handle messages from extension ─────
    window.addEventListener('message', (e) => {
      const msg = e.data;

      // Debug: log ALL messages received by the webview
      const debugEl = document.getElementById('debug-log');
      if (debugEl) {
        const now = new Date();
        const ts = now.getHours().toString().padStart(2,'0') + ':' + now.getMinutes().toString().padStart(2,'0') + ':' + now.getSeconds().toString().padStart(2,'0');
        const preview = JSON.stringify(msg).substring(0, 120);
        debugEl.innerHTML = '<div>' + ts + ' [' + (msg.type || '?') + '] ' + preview + '</div>' + debugEl.innerHTML;
      }

      if (msg.type === 'update') updateUI(msg.data);
      if (msg.type === 'trigger') addFeedEvent(msg.data);
      if (msg.type === 'scan_update') updateScanUI(msg.data);
      if (msg.type === 'profile') updateProfileUI(msg.data);
      if (msg.type === 'cloud_stats') updateCloudStatsUI(msg.data);
    });

    // ───── Signal that the webview is ready to receive messages ─────
    // This triggers a fresh data push from the extension side, ensuring
    // scan results aren't lost due to early postMessage calls.
    vscode.postMessage({ command: 'webviewReady' });

    // ───── Welcome Banner (server-rendered, just needs dismiss logic) ─────
    function dismissWelcome() {
      const banner = document.getElementById('welcome-banner');
      if (banner) {
        banner.style.opacity = '0';
        banner.style.transform = 'translateY(-10px)';
        banner.style.transition = 'opacity 0.3s, transform 0.3s';
        setTimeout(() => { banner.style.display = 'none'; }, 300);
      }
    }

    // Auto-dismiss welcome banner after 30s (handles both server-rendered and postMessage)
    const initBanner = document.getElementById('welcome-banner');
    if (initBanner && initBanner.style.display !== 'none') {
      setTimeout(() => { dismissWelcome(); }, 30000);
    }

    function updateUI(d) {
      // Pet widget — set character avatar
      const avatarImg = document.getElementById('pet-avatar-img');
      if (avatarImg) {
        const key = (d.petName || 'nova').toLowerCase();
        avatarImg.src = PET_CHARS[key] || PET_CHARS['nova'];
      }
      document.getElementById('pet-name').textContent = d.petName;
      const badge = document.getElementById('connection-badge');
      if (d.isCloudLinked) {
        badge.textContent = 'Synced with macOS App';
        badge.className = 'connection-badge connected';
      } else if (d.isConnected) {
        badge.textContent = 'MCP Connected';
        badge.className = 'connection-badge connected';
      } else {
        badge.textContent = 'Standalone Mode';
        badge.className = 'connection-badge disconnected';
      }

      // Pet reaction
      const reaction = d.summary?.petReaction;
      const reactionEl = document.getElementById('pet-reaction');
      if (d.codingMinutes > 60) {
        reactionEl.textContent = '"You\\'re on fire today! 🔥"';
      } else if (d.codingMinutes > 30) {
        reactionEl.textContent = '"Great progress, keep going!"';
      } else if (d.codingMinutes > 0) {
        reactionEl.textContent = '"Let\\'s build something cool!"';
      } else if (d.isIdle) {
        reactionEl.textContent = '"I\\'m here when you\\'re ready 💤"';
      } else {
        reactionEl.textContent = '"Ready to code together!"';
      }

      // Session stats — ONLY live data from this Cursor session, no MCP/cloud fallback
      const syncBadge = document.getElementById('sync-badge');

      if (d.codingMinutes > 0 || d.totalEdits > 0) {
        if (syncBadge) { syncBadge.style.display = 'inline'; syncBadge.textContent = 'LIVE'; }
      } else {
        if (syncBadge) { syncBadge.style.display = 'none'; }
      }

      document.getElementById('coding-time').textContent = d.codingTime;
      document.getElementById('total-edits').textContent = d.totalEdits;
      document.getElementById('files-edited').textContent = d.filesEdited;
      document.getElementById('lines-changed').textContent =
        (d.linesAdded > 0 || d.linesRemoved > 0)
          ? '+' + d.linesAdded + ' / -' + d.linesRemoved
          : '0';

      // Branch & idle
      const branchEl = document.getElementById('branch-info');
      branchEl.textContent = d.currentBranch ? '⎇ ' + d.currentBranch : '—';
      const idleEl = document.getElementById('idle-status');
      idleEl.innerHTML = d.isIdle && d.codingMinutes > 0
        ? '<span class="idle-badge">💤 Idle</span>'
        : '';

      // Language breakdown card — use session data or MCP fallback
      const langs = (d.languageBreakdown && Object.keys(d.languageBreakdown).length > 0)
        ? d.languageBreakdown
        : (d.summary?.languageBreakdown || {});
      const langKeys = Object.keys(langs);
      const langCard = document.getElementById('lang-card');
      if (langKeys.length > 0) {
        langCard.style.display = 'block';
        const total = langKeys.reduce((s, k) => s + langs[k], 0);
        const bar = document.getElementById('lang-bar');
        const legend = document.getElementById('lang-legend');
        bar.innerHTML = '';
        legend.innerHTML = '';
        langKeys.sort((a, b) => langs[b] - langs[a]);
        for (const lang of langKeys) {
          const pct = (langs[lang] / total * 100).toFixed(1);
          const color = LANG_COLORS[lang.toLowerCase()] || '#888';
          bar.innerHTML += '<div class="lang-segment" style="width:' + pct + '%;background:' + color + '"></div>';
          legend.innerHTML += '<span class="lang-legend-item"><span class="lang-dot" style="background:' + color + '"></span>' + lang + ' ' + pct + '%</span>';
        }
      } else {
        langCard.style.display = 'none';
      }

      // Skills
      const skillsSection = document.getElementById('skills-section');
      const skills = d.skillProgress;
      if (skills && skills.length > 0) {
        skillsSection.style.display = 'block';
        const list = document.getElementById('skills-list');
        list.innerHTML = '';
        for (const sk of skills) {
          const pct = sk.xpToNextLevel > 0
            ? (sk.xpProgress / sk.xpToNextLevel * 100).toFixed(0)
            : 100;
          const color = KINGDOM_COLORS[sk.kingdom] || '#7B6BD8';
          list.innerHTML += '<div class="skill-item">'
            + '<div class="skill-header">'
            + '<span class="skill-name">' + sk.icon + ' ' + sk.name + '</span>'
            + '<span class="skill-level">Lv' + sk.level + '/' + sk.maxLevel + '</span>'
            + '</div>'
            + '<div class="skill-bar"><div class="skill-fill" style="width:' + pct + '%;background:' + color + '"></div></div>'
            + '</div>';
        }
      } else {
        skillsSection.style.display = 'none';
      }
    }

    function addFeedEvent(ev) {
      feedEvents.unshift(ev);
      if (feedEvents.length > 20) feedEvents.pop();

      const feed = document.getElementById('event-feed');
      feed.innerHTML = '';
      for (const fe of feedEvents) {
        const t = new Date(fe.timestamp);
        const time = t.getHours().toString().padStart(2,'0') + ':' + t.getMinutes().toString().padStart(2,'0');
        const icons = {
          idle_summary: '💤', session_end: '⎇', summary_generated: '🌟',
          milestone: '⭐', periodic: '🔄',
        };
        feed.innerHTML += '<div class="event-item">'
          + '<span class="event-time">' + time + '</span>'
          + '<span class="event-type">' + (icons[fe.eventType] || '•') + ' ' + fe.title + '</span>'
          + '<br/>' + fe.message
          + '</div>';
      }
    }
    // ───── Code Health / Scanner UI ─────
    const MOOD_EMOJIS = {
      worried: '😟', curious: '🤔', happy: '😊',
      proud: '🏆', sleepy: '😴', neutral: '🌟',
    };

    let currentFindingIndex = 0;
    let currentFindings = [];

    function updateScanUI(d) {
      document.getElementById('scan-errors').textContent = d.totalErrors;
      document.getElementById('scan-warnings').textContent = d.totalWarnings;
      document.getElementById('scan-clean-files').textContent = d.cleanFiles;
      document.getElementById('scan-total-files').textContent = d.totalFiles;

      const scoreEl = document.getElementById('clean-score-value');
      scoreEl.textContent = d.totalFiles > 0 ? d.averageCleanScore + '%' : '—';

      const ring = document.getElementById('clean-score-ring');
      ring.className = 'clean-score-ring';
      if (d.totalErrors > 0) ring.classList.add('error');
      else if (d.totalWarnings > 3) ring.classList.add('warning');

      if (d.petMessage) {
        document.getElementById('pet-scan-mood').textContent =
          MOOD_EMOJIS[d.petMood] || '🌟';
        document.getElementById('pet-scan-text').textContent = d.petMessage;
      }

      // ───── Grammarly-style findings cards ─────
      const container = document.getElementById('findings-container');
      if (!container) return;

      currentFindings = d.findings || [];

      if (currentFindings.length === 0) {
        if (d.activeFile) {
          container.innerHTML = '<div class="findings-clean">✨ ' + d.activeFile + ' is clean!</div>';
        } else {
          container.innerHTML = '';
        }
        return;
      }

      // Reset index if findings changed
      if (currentFindingIndex >= currentFindings.length) currentFindingIndex = 0;

      renderFindingCards(d.activeFile, currentFindings);
    }

    function renderFindingCards(fileName, findings) {
      const container = document.getElementById('findings-container');
      if (!container) return;

      let html = '<div class="findings-list">';
      if (fileName) {
        html += '<div class="findings-file-label">' + fileName + '</div>';
      }

      // Fix All button when there are multiple findings
      var autoFixCount = findings.filter(function(f) { return f.autoFixable || f.source === 'diagnostics'; }).length;
      if (findings.length > 1 && autoFixCount > 0) {
        html += '<button class="finding-btn finding-btn-fix finding-btn-autofix" data-action="fixAll" style="width:100%;padding:6px;margin-bottom:6px;font-size:11px;">🐾 Auto-fix All (' + autoFixCount + ' fixable)</button>';
      }

      // Show up to 5 findings at a time
      const visible = findings.slice(0, 5);
      for (let i = 0; i < visible.length; i++) {
        const f = visible[i];
        const sev = f.severity;
        html += '<div class="finding-card ' + sev + '" data-action="goto" data-line="' + f.line + '" data-col="' + f.column + '">';
        html += '<div class="finding-header">';
        html += '<span class="finding-severity ' + sev + '">' + sev + '</span>';
        html += '<span class="finding-line">Line ' + f.line + '</span>';
        html += '</div>';
        html += '<div class="finding-message">' + escapeHtml(f.message) + '</div>';

        if (f.suggestion) {
          html += '<div class="finding-suggestion">💡 ' + escapeHtml(f.suggestion) + '</div>';
        }

        html += '<div class="finding-actions">';
        if (f.autoFixable) {
          // Pattern finding with Codepet auto-fix — green button, instant fix
          html += '<button class="finding-btn finding-btn-fix finding-btn-autofix" data-action="fix" data-line="' + f.line + '" data-col="' + f.column + '" data-code="' + escapeHtml(f.code) + '" data-source="' + f.source + '">🐾 Auto-fix</button>';
        } else if (f.source === 'diagnostics') {
          // VS Code diagnostic (TypeScript, ESLint) — Codepet fix engine handles these!
          html += '<button class="finding-btn finding-btn-fix finding-btn-autofix" data-action="fixDiagnostic" data-line="' + f.line + '" data-col="' + f.column + '" data-code="' + escapeHtml(f.code) + '" data-source="' + f.source + '" data-message="' + escapeHtml(f.message) + '" data-start-char="' + (f.startChar || 0) + '" data-end-line="' + (f.endLine || f.line) + '" data-end-char="' + (f.endChar || 0) + '">🐾 Fix</button>';
        } else {
          // Pattern finding we can\'t auto-fix — try VS Code quick fix
          html += '<button class="finding-btn finding-btn-fix" data-action="fix" data-line="' + f.line + '" data-col="' + f.column + '" data-code="' + escapeHtml(f.code) + '" data-source="' + f.source + '">Fix</button>';
        }
        html += '<button class="finding-btn finding-btn-dismiss" data-action="dismiss" data-index="' + i + '">Dismiss</button>';
        html += '</div>';
        html += '</div>';
      }

      // Navigation bar if more than 5
      if (findings.length > 5) {
        html += '<div class="finding-nav">';
        html += '<span class="finding-nav-info">Showing 5 of ' + findings.length + '</span>';
        html += '</div>';
      }

      html += '</div>';
      container.innerHTML = html;
    }

    function escapeHtml(str) {
      return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    // ───── Event delegation for findings (CSP-safe, no inline handlers) ─────
    document.addEventListener('click', function(e) {
      const target = e.target;
      const action = target.dataset ? target.dataset.action : null;

      if (action === 'fix') {
        e.stopPropagation();
        const line = parseInt(target.dataset.line);
        const col = parseInt(target.dataset.col) || 0;
        const code = target.dataset.code || '';
        const source = target.dataset.source || '';
        vscode.postMessage({ command: 'applyFix', line: line, column: col, code: code, source: source });
        return;
      }

      if (action === 'fixDiagnostic') {
        e.stopPropagation();
        var dLine = parseInt(target.dataset.line);
        var dCol = parseInt(target.dataset.col) || 0;
        var dCode = target.dataset.code || '';
        var dMessage = target.dataset.message || '';
        var dStartChar = parseInt(target.dataset.startChar) || 0;
        var dEndLine = parseInt(target.dataset.endLine) || dLine;
        var dEndChar = parseInt(target.dataset.endChar) || 0;
        vscode.postMessage({
          command: 'fixTsDiagnostic',
          line: dLine,
          startChar: dStartChar,
          endLine: dEndLine,
          endChar: dEndChar,
          tsCode: parseInt(dCode) || 0,
          message: dMessage
        });
        return;
      }

      if (action === 'goto') {
        e.stopPropagation();
        var gotoLine = parseInt(target.dataset.line);
        var gotoCol = parseInt(target.dataset.col) || 0;
        if (!isNaN(gotoLine)) {
          vscode.postMessage({ command: 'goToError', line: gotoLine, column: gotoCol });
        }
        return;
      }

      if (action === 'fixAll') {
        e.stopPropagation();
        vscode.postMessage({ command: 'autoFixAll' });
        return;
      }

      if (action === 'dismiss') {
        e.stopPropagation();
        const card = target.closest('.finding-card');
        if (card) {
          card.style.opacity = '0';
          card.style.transform = 'translateX(20px)';
          card.style.transition = 'opacity 0.2s, transform 0.2s';
          setTimeout(function() { card.style.display = 'none'; }, 200);
        }
        vscode.postMessage({ command: 'dismissFinding', index: parseInt(target.dataset.index) });
        return;
      }

      if (action === 'dismissWelcome') {
        dismissWelcome();
        return;
      }

      if (action === 'refresh') {
        vscode.postMessage({ command: 'refresh' });
        return;
      }

      if (action === 'openSettings') {
        vscode.postMessage({ command: 'openSettings' });
        return;
      }

      // Card click → go to error line
      const card = target.closest ? target.closest('.finding-card') : null;
      if (card && card.dataset.action === 'goto') {
        const line = parseInt(card.dataset.line);
        const col = parseInt(card.dataset.col) || 0;
        vscode.postMessage({ command: 'goToError', line: line, column: col });
      }
    });

    // ───── Profile UI (no-op, kept for compatibility) ─────
    function updateProfileUI(d) { }

    // ───── Cloud Stats (disabled — session tracker data is now the single source of truth) ─────
    let hasCloudData = false;
    function updateCloudStatsUI(d) {
      // No-op: Today's Coding card now always shows live session tracker data,
      // which is the same data synced to Firestore → macOS app dashboard.
      hasCloudData = true;
    }

    // NOTE: Per-file scan reactions removed — they caused feed spam.
    // Code Health card (via scan_update) shows all scan data.
    function _scanReactionRemoved() {
    }

    // ───── Embedded initial scan data (bypasses postMessage timing) ─────
    // This data was pre-computed server-side when the HTML was generated,
    // so it's available immediately without waiting for any message roundtrip.
    var __initialScan = ${initialScanJson};
    if (__initialScan && (__initialScan.totalErrors > 0 || __initialScan.totalWarnings > 0 || __initialScan.totalFiles > 0)) {
      updateScanUI(__initialScan);
    }
  </script>
</body>
</html>`;
  }

  private escapeHtml(str: string): string {
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  dispose(): void {
    if (this.liveTimer) clearInterval(this.liveTimer);
    for (const d of this.disposables) d.dispose();
  }
}

function getNonce(): string {
  let text = "";
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  for (let i = 0; i < 32; i++) {
    text += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return text;
}
