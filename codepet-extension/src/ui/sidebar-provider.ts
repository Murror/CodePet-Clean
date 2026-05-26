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

/** Lesson Card — matches the MCP server's LessonCard type */
export interface LessonCard {
  id: string;
  timestamp: string;
  platform: string;
  title: string;
  kingdom: string;
  skillTags: string[];
  difficulty: "beginner" | "intermediate" | "advanced";
  keyTakeaway: string;
  codeSnippet?: string;
  language?: string;
  petNarration: string;
  petReaction: string;
  petCoachTip: string;
  xpEarned: number;
  skillsProgressed: { skillId: string; xpAdded: number }[];
  /** Product-thinking sections for daily recap cards */
  sections?: { heading: string; text: string }[];
  /** Date string for display (e.g., "Mon, Apr 13") */
  dateLabel?: string;
  /** Type of lesson card */
  cardType?: "session" | "daily-recap";
}

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
  private lessonFeed: LessonCard[] = []; // cached lesson cards for the feed
  private companionWatchingMsg: string = ""; // current watching status message
  private companionMessageQueue: any[] = []; // queued messages for when webview isn't ready yet

  /** Callbacks for companion chat — set by CompanionService */
  public onCompanionMessage?: (text: string, attachments?: any[]) => void;
  public onCompanionClear?: () => void;
  public onAttachmentPin?: (attachId: string, pinned: boolean) => void;
  public onAttachmentRemove?: (attachId: string) => void;
  public onAttachmentAdded?: (attachment: { id: string; type: string; name: string; content: string }) => void;

  /** Transcribe an audio blob (base64 data URL) to text. Returns transcript or throws. */
  public transcribeAudio?: (audioDataUrl: string, mimeType: string, durationSec: number) => Promise<string>;

  /** Native recording hooks (wired in extension.ts using ffmpeg/sox) */
  public nativeRecordDetect?: () => Promise<"ffmpeg" | "sox" | null>;
  public nativeRecordStart?: () => Promise<void>;
  public nativeRecordStop?: () => Promise<{ audioDataUrl: string; mimeType: string; durationSec: number }>;
  public nativeRecordAbort?: () => void;

  /** ElevenLabs TTS (for voice chat mode) — returns an audio data URL. */
  public ttsSpeak?: (text: string) => Promise<string>;

  /** Post an arbitrary message to the webview (used for transcription status). */
  public postMessageToWebview(msg: any): void {
    if (this.view) this.view.webview.postMessage(msg);
  }

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

  /** Push lesson cards to the webview feed */
  pushLessonFeed(lessons: LessonCard[]): void {
    this.lessonFeed = lessons;
    if (this.view) {
      this.view.webview.postMessage({
        type: "lesson_feed",
        data: { lessons },
      });
    }
  }

  /** Add a single new lesson card to the feed (prepends) */
  addLessonCard(card: LessonCard): void {
    this.lessonFeed.unshift(card);
    if (this.lessonFeed.length > 20) this.lessonFeed.pop();
    if (this.view) {
      this.view.webview.postMessage({
        type: "lesson_new",
        data: card,
      });
    }
  }

  /** Post a watching status update to the webview */
  postWatchingStatus(active: boolean, message?: string): void {
    this.companionWatchingMsg = active ? (message ?? "Watching your coding session...") : "";
    // Also send via direct message (may or may not work depending on webview state)
    if (this.view) {
      this.view.webview.postMessage({
        type: "companion_watching",
        data: { active, message: this.companionWatchingMsg },
      });
    }
  }

  /** Post a companion message to the webview (queues if webview not ready) */
  postCompanionMessage(msg: { role: string; text: string; timestamp: string; options?: string[]; allowCustom?: boolean }): void {
    if (this.view) {
      this.view.webview.postMessage({
        type: "companion_message",
        data: msg,
      });
    } else {
      // Queue the message — will be flushed when webview resolves
      this.companionMessageQueue.push(msg);
    }
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

    // Force-refresh HTML whenever the sidebar becomes visible
    // This ensures layout changes (like input position) take effect even with caching
    this.disposables.push(
      webviewView.onDidChangeVisibility(() => {
        if (webviewView.visible) {
          webviewView.webview.html = this.getHtml(webviewView.webview, this.pendingWelcome ?? undefined);
        }
      })
    );

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
          case "saveLesson":
            vscode.commands.executeCommand("codepet.saveLesson");
            break;
          case "companionMessage":
            if (msg.text && this.onCompanionMessage) {
              this.onCompanionMessage(msg.text, msg.attachments);
            }
            break;
          case "attachRequest":
            await this.handleAttachRequest(msg.type);
            break;
          case "attachUrl":
            await this.handleAttachUrl(msg.url);
            break;
          case "attachTogglePin":
            if (this.onAttachmentPin) {
              this.onAttachmentPin(msg.attachId, msg.pinned);
            }
            break;
          case "voiceMessage": {
            const dur = typeof msg.duration === "number" ? msg.duration : 0;
            // If a transcriber is wired, use it; otherwise fall back to a placeholder.
            if (this.transcribeAudio && typeof msg.audioData === "string") {
              this.postMessageToWebview({ command: "voiceTranscribing" });
              try {
                const transcript = await this.transcribeAudio(
                  msg.audioData,
                  msg.mimeType || "audio/webm",
                  dur
                );
                const clean = (transcript || "").trim();
                if (clean) {
                  this.postMessageToWebview({ command: "voiceTranscriptDone", text: clean });
                  if (this.onCompanionMessage) this.onCompanionMessage(clean);
                } else {
                  this.postMessageToWebview({
                    command: "voiceTranscriptError",
                    message: "No speech detected",
                  });
                }
              } catch (err: any) {
                const message = (err && err.message) ? String(err.message) : String(err);
                this.postMessageToWebview({ command: "voiceTranscriptError", message });
                vscode.window.showWarningMessage(`Codepet voice: ${message}`);
              }
            } else if (this.onCompanionMessage) {
              this.onCompanionMessage(
                `🎙 [Voice note recorded · ${dur.toFixed(1)}s — set your OpenAI key with the "Codepet: Set OpenAI API Key" command to enable live transcription.]`
              );
            }
            break;
          }
          case "nativeRecordStart": {
            if (!this.nativeRecordStart || !this.nativeRecordDetect) {
              this.postMessageToWebview({
                command: "voiceTranscriptError",
                message: "Native recording not wired.",
              });
              break;
            }
            const tool = await this.nativeRecordDetect();
            if (!tool) {
              this.postMessageToWebview({
                command: "voiceTranscriptError",
                message: "No recorder found",
                installHint: true,
              });
              break;
            }
            try {
              await this.nativeRecordStart();
              this.postMessageToWebview({ command: "nativeRecordStarted", tool });
            } catch (err: any) {
              const message = (err && err.message) ? String(err.message) : String(err);
              this.postMessageToWebview({ command: "voiceTranscriptError", message });
            }
            break;
          }
          case "nativeRecordStop": {
            if (!this.nativeRecordStop) {
              this.postMessageToWebview({
                command: "voiceTranscriptError",
                message: "Native recording not wired.",
              });
              break;
            }
            try {
              this.postMessageToWebview({ command: "voiceTranscribing" });
              const rec = await this.nativeRecordStop();
              if (!this.transcribeAudio) {
                this.postMessageToWebview({
                  command: "voiceTranscriptError",
                  message: "No transcription key set.",
                });
                break;
              }
              const transcript = await this.transcribeAudio(
                rec.audioDataUrl,
                rec.mimeType,
                rec.durationSec
              );
              const clean = (transcript || "").trim();
              if (clean) {
                // Post voiceTranscriptDone FIRST so the webview sets up suppression
                // before the companion_message echo (from onCompanionMessage) arrives.
                this.postMessageToWebview({ command: "voiceTranscriptDone", text: clean });
                if (this.onCompanionMessage) this.onCompanionMessage(clean);
              } else {
                this.postMessageToWebview({
                  command: "voiceTranscriptError",
                  message: "No speech detected",
                });
              }
            } catch (err: any) {
              const message = (err && err.message) ? String(err.message) : String(err);
              this.postMessageToWebview({ command: "voiceTranscriptError", message });
              vscode.window.showWarningMessage(`Codepet voice: ${message}`);
            }
            break;
          }
          case "nativeRecordAbort": {
            if (this.nativeRecordAbort) this.nativeRecordAbort();
            break;
          }
          case "ttsRequest": {
            if (!this.ttsSpeak || typeof msg.text !== "string" || !msg.text.trim()) {
              this.postMessageToWebview({ command: "ttsError", message: "TTS unavailable" });
              break;
            }
            try {
              const audioDataUrl = await this.ttsSpeak(msg.text);
              this.postMessageToWebview({
                command: "ttsReady",
                audioDataUrl,
                requestId: msg.requestId,
              });
            } catch (err: any) {
              const message = (err && err.message) ? String(err.message) : String(err);
              this.postMessageToWebview({
                command: "ttsError",
                message,
                requestId: msg.requestId,
              });
            }
            break;
          }
          case "attachRemove":
            if (this.onAttachmentRemove) {
              this.onAttachmentRemove(msg.attachId);
            }
            break;
          case "runCommand":
            if (typeof msg.commandId === "string") {
              try {
                await vscode.commands.executeCommand(msg.commandId);
              } catch (e) {
                // swallow — command may not be registered yet
              }
            }
            break;
          case "clearCompanion":
            if (this.onCompanionClear) {
              this.onCompanionClear();
            }
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
            // Flush any queued companion messages
            if (this.companionMessageQueue.length > 0) {
              for (const queuedMsg of this.companionMessageQueue) {
                this.view?.webview.postMessage({
                  type: "companion_message",
                  data: queuedMsg,
                });
              }
              this.companionMessageQueue = [];
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
        // Companion watching status — sent with every update so it survives webview refreshes
        companionWatching: this.companionWatchingMsg || null,
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
   * Handle attachment request from webview — opens file picker, image picker, etc.
   */
  private async handleAttachRequest(type: string): Promise<void> {
    const fs = await import("fs");

    if (type === "file") {
      // Open file picker scoped to workspace
      const uris = await vscode.window.showOpenDialog({
        canSelectFiles: true,
        canSelectFolders: false,
        canSelectMany: true,
        openLabel: "Attach to Byte",
        filters: {
          "All files": ["*"],
          "Code": ["ts", "tsx", "js", "jsx", "py", "swift", "html", "css", "json", "md"],
          "Documents": ["pdf", "txt", "md", "csv"],
        },
      });
      if (!uris || uris.length === 0) return;

      for (const uri of uris) {
        const name = uri.fsPath.split("/").pop() ?? uri.fsPath;
        const id = "file_" + Date.now() + "_" + Math.random().toString(36).substring(2, 6);
        let content = "";
        try {
          const stat = fs.statSync(uri.fsPath);
          if (stat.size > 500_000) {
            content = `[File too large: ${name} (${(stat.size / 1024).toFixed(0)}KB) — only first 500KB read]`;
            content += fs.readFileSync(uri.fsPath, "utf-8").substring(0, 500_000);
          } else {
            content = fs.readFileSync(uri.fsPath, "utf-8");
          }
        } catch {
          content = `[Could not read file: ${name}]`;
        }

        // Send to webview for preview
        this.view?.webview.postMessage({ type: "attachment_added", data: { id, type: "file", name } });
        // Notify companion service
        if (this.onAttachmentAdded) {
          this.onAttachmentAdded({ id, type: "file", name, content });
        }
      }
    }

    if (type === "image") {
      const uris = await vscode.window.showOpenDialog({
        canSelectFiles: true,
        canSelectFolders: false,
        canSelectMany: true,
        openLabel: "Attach Image",
        filters: {
          "Images": ["png", "jpg", "jpeg", "gif", "svg", "webp"],
        },
      });
      if (!uris || uris.length === 0) return;

      for (const uri of uris) {
        const name = uri.fsPath.split("/").pop() ?? uri.fsPath;
        const id = "img_" + Date.now() + "_" + Math.random().toString(36).substring(2, 6);
        let content = "";
        try {
          // For images, store the path — Byte will reference it
          content = `[Image: ${name}] Path: ${uri.fsPath}`;
        } catch {
          content = `[Could not read image: ${name}]`;
        }

        this.view?.webview.postMessage({ type: "attachment_added", data: { id, type: "image", name } });
        if (this.onAttachmentAdded) {
          this.onAttachmentAdded({ id, type: "image", name, content });
        }
      }
    }

    if (type === "knowledge") {
      const uris = await vscode.window.showOpenDialog({
        canSelectFiles: true,
        canSelectFolders: false,
        canSelectMany: true,
        openLabel: "Add Knowledge Doc",
        filters: {
          "Documents": ["pdf", "md", "txt", "doc", "docx", "csv"],
          "All files": ["*"],
        },
      });
      if (!uris || uris.length === 0) return;

      for (const uri of uris) {
        const name = uri.fsPath.split("/").pop() ?? uri.fsPath;
        const id = "doc_" + Date.now() + "_" + Math.random().toString(36).substring(2, 6);
        let content = "";
        try {
          const stat = fs.statSync(uri.fsPath);
          if (stat.size > 500_000) {
            content = fs.readFileSync(uri.fsPath, "utf-8").substring(0, 500_000);
          } else {
            content = fs.readFileSync(uri.fsPath, "utf-8");
          }
        } catch {
          content = `[Could not read: ${name}]`;
        }

        this.view?.webview.postMessage({ type: "attachment_added", data: { id, type: "knowledge", name } });
        if (this.onAttachmentAdded) {
          this.onAttachmentAdded({ id, type: "knowledge", name, content });
        }
      }
    }

    if (type === "url") {
      // Prompt user to enter a URL in the input box
      this.view?.webview.postMessage({ type: "attachment_url_prompt" });
    }
  }

  /**
   * Handle URL attachment — fetch the URL content
   */
  private async handleAttachUrl(url: string): Promise<void> {
    if (!url || !url.match(/^https?:\/\//)) return;

    const name = url.length > 50 ? url.substring(0, 50) + "..." : url;
    const id = "url_" + Date.now() + "_" + Math.random().toString(36).substring(2, 6);

    // Show in preview immediately
    this.view?.webview.postMessage({ type: "attachment_added", data: { id, type: "url", name } });

    // Notify companion service with the URL (it can fetch later if needed)
    if (this.onAttachmentAdded) {
      this.onAttachmentAdded({ id, type: "url", name: url, content: `[URL: ${url}] — Content will be fetched when referenced.` });
    }
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
    const petNameCap = this.resolvedPetName.charAt(0).toUpperCase() + this.resolvedPetName.slice(1);

    return /*html*/ `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta http-equiv="Content-Security-Policy"
    content="default-src 'none';
      img-src ${webview.cspSource} data: blob:;
      style-src ${webview.cspSource} 'unsafe-inline';
      script-src 'nonce-${nonce}';
      media-src ${webview.cspSource} blob: data:;
      connect-src ${webview.cspSource} blob: data:;" />
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
      overflow: hidden;
    }
    .card-title {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.6px;
      color: var(--vscode-descriptionForeground);
      margin-bottom: 8px;
    }
    /* ───── Per-section title accents (coordinated vibrant palette) ───── */
    .card-title.ct-lavender {
      background: linear-gradient(135deg, #C8BDFF 0%, #A89BF2 55%, #7B6BD8 100%);
      -webkit-background-clip: text;
              background-clip: text;
      color: transparent;
      text-shadow: 0 0 24px rgba(168, 155, 242, 0.15);
    }
    .card-title.ct-pink {
      background: linear-gradient(135deg, #FFB3E6 0%, #F06EC7 55%, #C94BA7 100%);
      -webkit-background-clip: text;
              background-clip: text;
      color: transparent;
    }
    .card-title.ct-teal {
      background: linear-gradient(135deg, #7DF5C2 0%, #34D399 55%, #10B981 100%);
      -webkit-background-clip: text;
              background-clip: text;
      color: transparent;
    }
    .card-title.ct-amber {
      background: linear-gradient(135deg, #FFE29A 0%, #F5B547 55%, #D98A1F 100%);
      -webkit-background-clip: text;
              background-clip: text;
      color: transparent;
    }
    .card-title.ct-violet {
      background: linear-gradient(135deg, #E6C6FF 0%, #C084FC 55%, #9333EA 100%);
      -webkit-background-clip: text;
              background-clip: text;
      color: transparent;
    }
    .card-title.ct-cyan {
      background: linear-gradient(135deg, #A6EEFF 0%, #60D8F2 55%, #22A8C8 100%);
      -webkit-background-clip: text;
              background-clip: text;
      color: transparent;
    }

    /* ───── Lesson Feed (Swipeable Cards) ───── */
    .lesson-feed-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;
    }
    .lesson-count {
      font-size: 10px;
      color: var(--vscode-descriptionForeground);
      opacity: 0.7;
    }

    /* Swipe container */
    .lesson-swipe-container {
      position: relative;
      overflow: hidden;
      border-radius: 10px;
      margin-bottom: 8px;
    }
    .lesson-swipe-track {
      display: flex;
      transition: transform 0.35s cubic-bezier(0.25, 0.1, 0.25, 1);
      will-change: transform;
    }
    .lesson-swipe-track.dragging {
      transition: none;
    }

    /* Remove the outer wrapper border on the Lesson Feed section — save space,
       let the inner lesson card stand alone */
    #lesson-feed-section {
      border: none !important;
      background: transparent !important;
      padding: 0 !important;
    }
    #lesson-feed-section .lesson-feed-header {
      padding: 0 4px 8px;
    }

    /* Individual swipe card — glassmorphic gradient */
    .lesson-card {
      position: relative;
      min-width: 100%;
      max-width: 100%;
      box-sizing: border-box;
      background:
        radial-gradient(120% 80% at 0% 0%, rgba(168, 155, 242, 0.18) 0%, transparent 55%),
        radial-gradient(120% 90% at 100% 100%, rgba(236, 72, 153, 0.12) 0%, transparent 60%),
        linear-gradient(155deg, rgba(48, 36, 96, 0.92) 0%, rgba(26, 20, 54, 0.96) 60%, rgba(16, 12, 36, 0.98) 100%);
      border: 1px solid rgba(168, 155, 242, 0.18);
      border-radius: 18px;
      padding: 18px 16px 16px;
      flex-shrink: 0;
      box-shadow:
        0 10px 28px -12px rgba(83, 74, 183, 0.55),
        inset 0 1px 0 rgba(255, 255, 255, 0.06);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      overflow: hidden;
    }
    .lesson-card::before {
      content: "";
      position: absolute;
      inset: 0;
      border-radius: 18px;
      padding: 1px;
      background: linear-gradient(135deg, rgba(168, 155, 242, 0.45), rgba(123, 107, 216, 0) 40%, rgba(236, 72, 153, 0.25) 100%);
      -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
      -webkit-mask-composite: xor;
              mask-composite: exclude;
      pointer-events: none;
    }

    /* Date label */
    .lesson-date-label {
      font-size: 10px;
      font-weight: 500;
      color: #8b8b9e;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 8px;
    }

    /* Card type badge — vibrant pill */
    .lesson-type-badge {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      font-size: 9px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 999px;
      text-transform: uppercase;
      letter-spacing: 0.6px;
      margin-bottom: 12px;
      box-shadow: 0 4px 12px -4px rgba(0, 0, 0, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.12);
    }
    .lesson-type-badge.daily-recap {
      background: linear-gradient(135deg, #8B7BE8 0%, #534AB7 100%);
      color: #fff;
    }
    .lesson-type-badge.session {
      background: linear-gradient(135deg, #34d399 0%, #059669 100%);
      color: #fff;
    }

    /* Title */
    .lesson-title {
      font-size: 14px;
      font-weight: 700;
      color: #e8e6f0;
      margin-bottom: 12px;
      line-height: 1.3;
    }

    /* Sections — compact inline layout */
    .lesson-section {
      margin-bottom: 6px;
    }
    .lesson-section-heading {
      font-size: 9px;
      font-weight: 700;
      color: #A89BF2;
      text-transform: uppercase;
      letter-spacing: 0.6px;
      margin-bottom: 2px;
    }
    .lesson-section-text {
      font-size: 11.5px;
      color: #c4c0d8;
      line-height: 1.45;
      white-space: pre-wrap;
    }

    /* Tighter divider between sections */
    .lesson-section + .lesson-section {
      padding-top: 6px;
      border-top: 1px solid transparent;
      border-image: linear-gradient(90deg, transparent 0%, rgba(168, 155, 242, 0.25) 50%, transparent 100%) 1;
    }

    /* When a card has structured sections, the pet narration footer is redundant — hide it */
    .lesson-card:has(.lesson-section) .lesson-pet-section {
      display: none;
    }
    /* Compact the lesson card container itself */
    .lesson-card {
      padding: 12px 14px !important;
    }
    .lesson-title {
      font-size: 14px !important;
      margin-bottom: 8px !important;
    }

    /* Legacy fields (takeaway, snippet, pet) — still supported */
    .lesson-takeaway {
      font-size: 12px;
      color: #c4c0d8;
      line-height: 1.5;
      margin-bottom: 10px;
    }
    .lesson-snippet {
      background: #12121f;
      border: 1px solid rgba(123, 107, 216, 0.15);
      border-radius: 6px;
      padding: 10px;
      font-family: var(--vscode-editor-font-family);
      font-size: 11px;
      line-height: 1.4;
      overflow-x: auto;
      margin-bottom: 10px;
      white-space: pre;
      color: #c4c0d8;
    }
    .lesson-snippet-lang {
      font-size: 9px;
      color: #8b8b9e;
      text-transform: uppercase;
      margin-bottom: 4px;
    }
    .lesson-pet-section {
      border-top: 1px solid rgba(123, 107, 216, 0.1);
      padding-top: 10px;
      margin-top: 6px;
    }
    .lesson-pet-narration {
      font-size: 11px;
      font-style: italic;
      color: #c4c0d8;
      opacity: 0.85;
      margin-bottom: 4px;
    }
    .lesson-pet-reaction {
      display: inline-block;
      font-size: 12px;
      margin-right: 4px;
    }
    .lesson-coach-tip {
      font-size: 10px;
      color: #e3b341;
      margin-top: 4px;
    }

    /* Footer */
    .lesson-footer {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 8px;
      padding-top: 6px;
      border-top: 1px solid rgba(123, 107, 216, 0.1);
      font-size: 10px;
      color: #8b8b9e;
    }
    .lesson-xp {
      font-weight: 600;
      color: #4ADE80;
    }
    .lesson-tags {
      display: flex;
      gap: 4px;
      flex-wrap: wrap;
    }

    /* Swipe dot indicators */
    .lesson-swipe-dots {
      display: flex;
      justify-content: center;
      gap: 6px;
      padding: 8px 0 2px;
    }
    .lesson-swipe-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: rgba(123, 107, 216, 0.25);
      transition: all 0.25s ease;
      cursor: pointer;
    }
    .lesson-swipe-dot.active {
      background: #7b6bd8;
      transform: scale(1.3);
    }

    /* Empty state */
    .lesson-empty {
      font-size: 11px;
      color: #8b8b9e;
      text-align: center;
      padding: 16px 8px;
    }
    .lesson-tag {
      font-size: 9px;
      font-weight: 600;
      padding: 3px 9px;
      border-radius: 999px;
      background: linear-gradient(135deg, rgba(168, 155, 242, 0.22), rgba(123, 107, 216, 0.12));
      color: #d7d0ff;
      border: 1px solid rgba(168, 155, 242, 0.28);
      letter-spacing: 0.2px;
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06);
    }
    .lesson-tag:nth-child(3n+2) {
      background: linear-gradient(135deg, rgba(236, 72, 153, 0.22), rgba(168, 85, 247, 0.12));
      color: #ffd1e8;
      border-color: rgba(236, 72, 153, 0.32);
    }
    .lesson-tag:nth-child(3n+3) {
      background: linear-gradient(135deg, rgba(52, 211, 153, 0.22), rgba(20, 184, 166, 0.12));
      color: #b7f7dd;
      border-color: rgba(52, 211, 153, 0.32);
    }
    .save-lesson-btn {
      width: 100%;
      padding: 11px;
      margin-top: 6px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.3px;
      background: linear-gradient(135deg, #A89BF2 0%, #7B6BD8 45%, #534AB7 100%);
      color: #fff;
      border: none;
      border-radius: 14px;
      cursor: pointer;
      transition: transform 0.15s ease, box-shadow 0.2s ease, opacity 0.2s;
      box-shadow:
        0 8px 20px -8px rgba(123, 107, 216, 0.75),
        inset 0 1px 0 rgba(255, 255, 255, 0.18);
    }
    .save-lesson-btn:hover {
      opacity: 0.95;
      transform: translateY(-1px);
      box-shadow:
        0 12px 24px -8px rgba(123, 107, 216, 0.9),
        inset 0 1px 0 rgba(255, 255, 255, 0.22);
    }
    .save-lesson-btn:active { transform: translateY(0); }
    .lesson-empty {
      text-align: center;
      font-size: 11px;
      color: var(--vscode-descriptionForeground);
      padding: 12px;
      opacity: 0.6;
    }

    /* ───── Companion Chat ───── */
    /* ═══ Codepet Companion — Modern Purple Theme ═══ */
    /* Palette: #7B6BD8 (primary purple), #534AB7 (deep purple), #A89BF2 (light purple) */

    .companion-section {
      display: flex;
      flex-direction: column;
      gap: 10px;
      overflow: visible;
      position: relative;
      background: linear-gradient(165deg, rgba(123, 107, 216, 0.04) 0%, rgba(83, 74, 183, 0.02) 40%, transparent 100%);
      border-radius: 14px;
      padding: 4px;
    }
    .companion-section::before {
      content: "";
      position: absolute;
      top: -40px;
      right: -30px;
      width: 180px;
      height: 180px;
      background: radial-gradient(circle, rgba(168, 155, 242, 0.12) 0%, transparent 65%);
      pointer-events: none;
      z-index: 0;
    }
    .companion-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      order: 0;
      padding: 6px 10px;
      position: relative;
      z-index: 2;
      cursor: pointer;
      border-radius: 12px;
      transition: background 0.2s ease;
    }
    .companion-header:hover {
      background: rgba(168, 155, 242, 0.06);
    }
    .companion-header-title-group {
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .companion-header-chevron {
      width: 14px;
      height: 14px;
      color: #A89BF2;
      transform: rotate(-90deg);
      transition: transform 0.3s cubic-bezier(0.22, 1, 0.36, 1);
      flex-shrink: 0;
    }
    .companion-section.expanded .companion-header-chevron {
      transform: rotate(0deg);
    }
    .companion-section .companion-header .card-title {
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 1.2px;
      background: linear-gradient(90deg, #A89BF2 0%, #7B6BD8 100%);
      -webkit-background-clip: text;
      background-clip: text;
      -webkit-text-fill-color: transparent;
      margin-bottom: 0;
    }
    /* ───── Collapsible state: hide messages + input when not expanded ───── */
    .companion-section:not(.expanded) .companion-messages,
    .companion-section:not(.expanded) .companion-attach-preview,
    .companion-section:not(.expanded) .companion-input-row {
      max-height: 0;
      opacity: 0;
      margin: 0;
      padding-top: 0;
      padding-bottom: 0;
      overflow: hidden;
      pointer-events: none;
      border-width: 0;
      transition:
        max-height 0.4s cubic-bezier(0.22, 1, 0.36, 1),
        opacity 0.3s ease,
        padding 0.35s ease,
        margin 0.35s ease,
        border-width 0.3s ease;
    }
    .companion-section.expanded .companion-messages,
    .companion-section.expanded .companion-attach-preview,
    .companion-section.expanded .companion-input-row {
      transition:
        max-height 0.5s cubic-bezier(0.22, 1, 0.36, 1),
        opacity 0.35s ease 0.08s,
        padding 0.4s ease,
        margin 0.4s ease,
        border-width 0.35s ease;
    }
    /* ═══ Ask Codepet dock — fixed at bottom of sidebar, JS computes exact expand height ═══ */
    .companion-section {
      position: fixed;
      left: 12px;
      right: 12px;
      bottom: 12px;
      z-index: 20;
      /* Default cap — JS sets the exact height when expanded */
      max-height: 320px;
      overflow: hidden;
      background: linear-gradient(165deg, rgba(30, 20, 60, 0.98) 0%, rgba(18, 12, 38, 0.99) 100%);
      border: 1px solid rgba(168, 155, 242, 0.22);
      border-radius: 16px;
      box-shadow:
        0 -10px 32px -8px rgba(8, 6, 18, 0.75),
        0 14px 32px -16px rgba(83, 74, 183, 0.4);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
    }
    /* Reserve bottom padding so the lesson feed's last content isn't hidden behind the collapsed dock */
    body {
      padding-bottom: 80px;
    }
    /* When expanded: messages area sized to fit inside the 320px dock.
       320px dock - 45px header - 48px input - 30px padding = ~197px for messages. */
    .companion-section.expanded .companion-messages {
      max-height: 195px;
      opacity: 1;
    }
    .companion-section.expanded {
      border-color: rgba(168, 155, 242, 0.32);
    }
    .companion-section.expanded .companion-input-row {
      opacity: 1;
      max-height: 200px;
      /* padding restored via original .companion-input-row rule */
    }
    /* Clear button should only be visible when expanded */
    .companion-section:not(.expanded) .companion-clear-btn {
      display: none;
    }
    @media (prefers-reduced-motion: reduce) {
      .companion-section .companion-messages,
      .companion-section .companion-input-row,
      .companion-section .companion-attach-preview,
      .companion-header-chevron {
        transition: none !important;
      }
    }
    .companion-messages {
      max-height: 180px;
      overflow-y: auto;
      overflow-x: hidden;
      display: flex;
      flex-direction: column;
      gap: 8px;
      padding: 6px 2px;
      order: 1;
      position: relative;
      z-index: 1;
    }
    .companion-messages::-webkit-scrollbar { width: 4px; }
    .companion-messages::-webkit-scrollbar-thumb {
      background: rgba(123, 107, 216, 0.3);
      border-radius: 4px;
    }
    .companion-messages::-webkit-scrollbar-thumb:hover {
      background: rgba(123, 107, 216, 0.5);
    }
    .companion-msg {
      padding: 10px 14px;
      border-radius: 18px;
      font-size: 12px;
      line-height: 1.55;
      max-width: 88%;
      word-wrap: break-word;
      overflow-wrap: break-word;
      white-space: pre-wrap;
      box-sizing: border-box;
      animation: msg-fade-in 0.25s ease-out;
      position: relative;
    }
    @keyframes msg-fade-in {
      from { opacity: 0; transform: translateY(4px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .companion-msg strong {
      font-weight: 700;
      color: #C8BDFF;
    }
    .companion-msg em {
      color: #A89BF2;
      font-style: italic;
    }
    .companion-msg-user {
      background: linear-gradient(135deg, #7B6BD8 0%, #534AB7 100%);
      color: #FFFFFF;
      align-self: flex-end;
      border-bottom-right-radius: 6px;
      box-shadow: 0 4px 14px rgba(83, 74, 183, 0.25), inset 0 1px 0 rgba(255, 255, 255, 0.1);
      font-weight: 500;
    }
    .companion-msg-pet {
      background: rgba(255, 255, 255, 0.04);
      color: var(--vscode-foreground);
      align-self: flex-start;
      border-bottom-left-radius: 6px;
      border: 1px solid rgba(168, 155, 242, 0.12);
      backdrop-filter: blur(8px);
      box-shadow: 0 6px 18px -8px rgba(0, 0, 0, 0.5), inset 0 1px 0 rgba(255, 255, 255, 0.04);
    }
    .companion-msg-pet strong {
      color: #A89BF2;
    }
    /* Rotating bubble tints — lavender → peach → mint → pink (course-card palette) */
    .companion-msg-pet.tint-lavender {
      background:
        radial-gradient(120% 90% at 0% 0%, rgba(168, 155, 242, 0.22) 0%, transparent 55%),
        linear-gradient(155deg, rgba(123, 107, 216, 0.16) 0%, rgba(255, 255, 255, 0.035) 100%);
      border-color: rgba(168, 155, 242, 0.28);
    }
    .companion-msg-pet.tint-lavender strong { color: #C8BDFF; }
    .companion-msg-pet.tint-lavender em     { color: #A89BF2; }

    .companion-msg-pet.tint-peach {
      background:
        radial-gradient(120% 90% at 0% 0%, rgba(245, 181, 71, 0.22) 0%, transparent 55%),
        linear-gradient(155deg, rgba(245, 181, 71, 0.14) 0%, rgba(255, 255, 255, 0.035) 100%);
      border-color: rgba(245, 181, 71, 0.28);
    }
    .companion-msg-pet.tint-peach strong { color: #FFD58A; }
    .companion-msg-pet.tint-peach em     { color: #F5B547; }

    .companion-msg-pet.tint-mint {
      background:
        radial-gradient(120% 90% at 0% 0%, rgba(52, 211, 153, 0.22) 0%, transparent 55%),
        linear-gradient(155deg, rgba(52, 211, 153, 0.14) 0%, rgba(255, 255, 255, 0.035) 100%);
      border-color: rgba(52, 211, 153, 0.3);
    }
    .companion-msg-pet.tint-mint strong { color: #9FF3D1; }
    .companion-msg-pet.tint-mint em     { color: #34D399; }

    .companion-msg-pet.tint-pink {
      background:
        radial-gradient(120% 90% at 0% 0%, rgba(236, 110, 199, 0.22) 0%, transparent 55%),
        linear-gradient(155deg, rgba(236, 110, 199, 0.14) 0%, rgba(255, 255, 255, 0.035) 100%);
      border-color: rgba(236, 110, 199, 0.3);
    }
    .companion-msg-pet.tint-pink strong { color: #FFB3E6; }
    .companion-msg-pet.tint-pink em     { color: #F06EC7; }
    .companion-msg-pet p {
      margin: 4px 0;
    }
    .companion-msg-pet ul, .companion-msg-pet ol {
      margin: 4px 0 4px 16px;
      padding: 0;
    }
    .companion-msg-pet li {
      margin: 2px 0;
    }
    .companion-thinking {
      font-size: 11px;
      color: var(--vscode-descriptionForeground);
      opacity: 0.7;
      padding: 6px 10px;
      font-style: italic;
    }
    .companion-attach-bar {
      display: none;
    }
    .companion-plus-btn {
      background: rgba(168, 155, 242, 0.08);
      border: 1px solid rgba(168, 155, 242, 0.15);
      color: #A89BF2;
      font-size: 16px;
      cursor: pointer;
      width: 26px;
      height: 26px;
      padding: 0;
      border-radius: 50%;
      line-height: 1;
      flex-shrink: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s ease;
    }
    .companion-plus-btn:hover {
      color: #C8BDFF;
      background: rgba(168, 155, 242, 0.18);
      border-color: rgba(168, 155, 242, 0.3);
      transform: rotate(90deg);
    }
    /* (composer-row wrapper removed — vc-btn now sits inside input-row directly) */

    /* ───── Mic ↔ Send shared slot (swap based on input state) ───── */
    .mic-send-slot {
      position: relative;
      width: 30px;
      height: 30px;
      flex-shrink: 0;
    }
    .mic-send-slot > .companion-mic-btn,
    .mic-send-slot > .companion-send-btn {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      transition: opacity 0.22s ease, transform 0.28s cubic-bezier(0.34, 1.56, 0.64, 1);
    }
    /* Default (empty input): mic visible, send hidden */
    .companion-input-row:not(.has-text) .mic-send-slot > .companion-send-btn {
      opacity: 0;
      transform: translate(-50%, -50%) scale(0.5) rotate(-20deg);
      pointer-events: none;
    }
    /* Typing: send visible, mic hidden */
    .companion-input-row.has-text .mic-send-slot > .companion-mic-btn {
      opacity: 0;
      transform: translate(-50%, -50%) scale(0.5) rotate(20deg);
      pointer-events: none;
    }
    /* Hover on send keeps the centered transform */
    .mic-send-slot > .companion-send-btn:hover {
      transform: translate(-50%, -50%) translateY(-1px);
    }
    .mic-send-slot > .companion-send-btn:active {
      transform: translate(-50%, -50%) translateY(0) scale(0.95);
    }
    .mic-send-slot > .companion-mic-btn:hover {
      transform: translate(-50%, -50%) scale(1.12);
    }
    .mic-send-slot > .companion-mic-btn:active {
      transform: translate(-50%, -50%) scale(1.04);
    }

    /* ───── Voice Icon — Glowing Aurora Ring ───── */
    .companion-mic-btn {
      position: relative;
      background: radial-gradient(circle at 50% 55%, #1a1430 0%, #0c0822 100%);
      border: 1px solid rgba(140, 180, 255, 0.15);
      color: #ffffff;
      cursor: pointer;
      width: 28px;
      height: 28px;
      padding: 0;
      border-radius: 50%;
      line-height: 1;
      flex-shrink: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1),
                  box-shadow 0.3s ease,
                  border-color 0.3s ease;
      isolation: isolate;
      z-index: 0;
    }
    .companion-mic-btn .mic-icon {
      width: 13px;
      height: 13px;
      transition: transform 0.3s ease, filter 0.3s ease;
      filter: drop-shadow(0 0 2px rgba(200, 220, 255, 0.5));
    }
    /* Aurora ring — purple → cyan gradient with blur + slow rotation */
    .companion-mic-btn::before {
      content: "";
      position: absolute;
      inset: -4px;
      border-radius: 50%;
      background: conic-gradient(from 140deg,
        #8B5CF6 0deg,
        #A78BFA 55deg,
        transparent 110deg,
        transparent 215deg,
        #22D3EE 285deg,
        #67E8F9 340deg,
        #8B5CF6 360deg);
      filter: blur(4px);
      opacity: 0.75;
      transition: opacity 0.3s ease, filter 0.3s ease, inset 0.3s ease;
      z-index: -2;
      animation: mic-ring-rotate 6s linear infinite;
    }
    /* Outer soft bloom */
    .companion-mic-btn::after {
      content: "";
      position: absolute;
      inset: -8px;
      border-radius: 50%;
      background: conic-gradient(from 140deg,
        rgba(139, 92, 246, 0.55) 0deg,
        rgba(167, 139, 250, 0.45) 55deg,
        transparent 110deg,
        transparent 215deg,
        rgba(34, 211, 238, 0.55) 285deg,
        rgba(103, 232, 249, 0.45) 340deg,
        rgba(139, 92, 246, 0.55) 360deg);
      filter: blur(9px);
      opacity: 0.6;
      z-index: -3;
      animation: mic-ring-rotate 6s linear infinite;
      pointer-events: none;
    }
    .companion-mic-btn:hover {
      transform: scale(1.12);
      border-color: rgba(180, 210, 255, 0.35);
      box-shadow:
        0 0 18px 2px rgba(139, 92, 246, 0.45),
        0 0 22px 4px rgba(34, 211, 238, 0.35);
    }
    .companion-mic-btn:hover .mic-icon {
      transform: scale(1.05);
      filter: drop-shadow(0 0 4px rgba(200, 220, 255, 0.9));
    }
    .companion-mic-btn:hover::before {
      opacity: 1;
      filter: blur(3px);
      animation-duration: 3s;
    }
    .companion-mic-btn:hover::after {
      opacity: 0.95;
      filter: blur(12px);
      animation-duration: 3s;
    }
    .companion-mic-btn:active {
      transform: scale(1.04);
      transition-duration: 0.08s;
    }
    @keyframes mic-ring-rotate {
      to { transform: rotate(360deg); }
    }
    .companion-mic-btn.recording {
      color: #fff;
      background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
      border-color: transparent;
      box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.3);
      animation: pulse-mic 1.2s infinite;
    }
    @keyframes pulse-mic {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }

    /* ═════════ Voice Chat entry button (next to mic) ═════════ */
    .companion-vc-btn {
      position: relative;
      width: 28px;
      height: 28px;
      padding: 0;
      border-radius: 50%;
      background: radial-gradient(circle at 50% 55%, rgba(52, 211, 153, 0.22), rgba(16, 185, 129, 0.08));
      border: 1px solid rgba(52, 211, 153, 0.38);
      color: #9FF3D1;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      transition: transform 0.2s cubic-bezier(0.34,1.56,0.64,1), box-shadow 0.2s ease, background 0.2s;
    }
    .companion-vc-btn:hover {
      transform: scale(1.1);
      color: #B6F5DD;
      background: radial-gradient(circle at 50% 55%, rgba(52, 211, 153, 0.4), rgba(16, 185, 129, 0.12));
      box-shadow: 0 0 16px 2px rgba(52, 211, 153, 0.45);
    }
    .companion-vc-btn.active {
      color: #fff;
      background: linear-gradient(135deg, #34D399 0%, #10B981 100%);
      border-color: transparent;
      box-shadow: 0 0 0 3px rgba(52, 211, 153, 0.3), 0 0 18px 2px rgba(52, 211, 153, 0.5);
      animation: pulse-mic 1.4s infinite;
    }
    /* Waveform idle animation — bars subtly pulse to read as "voice" */
    .companion-vc-btn .vc-waveform line {
      transform-origin: center;
      transform-box: fill-box;
    }
    .companion-vc-btn .vc-waveform line:nth-child(1) { animation: cp-vc-bar 1.1s ease-in-out infinite; animation-delay: 0.0s; }
    .companion-vc-btn .vc-waveform line:nth-child(2) { animation: cp-vc-bar 1.1s ease-in-out infinite; animation-delay: 0.15s; }
    .companion-vc-btn .vc-waveform line:nth-child(3) { animation: cp-vc-bar 1.1s ease-in-out infinite; animation-delay: 0.3s; }
    .companion-vc-btn .vc-waveform line:nth-child(4) { animation: cp-vc-bar 1.1s ease-in-out infinite; animation-delay: 0.45s; }
    @keyframes cp-vc-bar {
      0%, 100% { transform: scaleY(0.45); }
      50%      { transform: scaleY(1); }
    }
    .companion-vc-btn:hover .vc-waveform line {
      animation-duration: 0.6s;
    }
    @media (prefers-reduced-motion: reduce) {
      .companion-vc-btn .vc-waveform line { animation: none !important; }
    }

    /* ═════════ Inline Voice-Record Capsule (in composer) ═════════ */
    .voice-capsule {
      display: none;
      align-items: center;
      gap: 8px;
      flex: 1;
      min-width: 0;
      padding: 5px 6px 5px 12px;
      border-radius: 999px;
      background:
        radial-gradient(110% 140% at 0% 0%, rgba(168,155,242,0.22), transparent 60%),
        linear-gradient(135deg, rgba(123,107,216,0.18), rgba(42,30,85,0.55));
      border: 1px solid rgba(168,155,242,0.45);
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.06), 0 4px 12px -4px rgba(83,74,183,0.35);
    }
    .companion-input-row.recording .voice-capsule { display: flex; }
    .companion-input-row.recording > .companion-plus-btn,
    .companion-input-row.recording > .companion-input,
    .companion-input-row.recording > .companion-char-count,
    .companion-input-row.recording > .mic-send-slot,
    .companion-input-row.recording > .companion-vc-btn { display: none; }

    .vc-pulse {
      width: 9px; height: 9px; border-radius: 50%;
      background: #F87171;
      animation: vc-dot-pulse 1.2s ease-in-out infinite;
      flex-shrink: 0;
      box-shadow: 0 0 8px rgba(248, 113, 113, 0.65);
    }
    @keyframes vc-dot-pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50%      { opacity: 0.45; transform: scale(0.82); }
    }
    .vc-timer {
      font-size: 11px;
      font-weight: 600;
      color: #E6DEFF;
      font-variant-numeric: tabular-nums;
      min-width: 32px;
      flex-shrink: 0;
      letter-spacing: 0.3px;
    }
    .vc-wave {
      flex: 1;
      display: flex;
      align-items: center;
      gap: 2px;
      height: 18px;
      overflow: hidden;
      min-width: 0;
    }
    .vc-wave span {
      width: 2px;
      border-radius: 1px;
      background: linear-gradient(180deg, #E6DEFF 0%, #A89BF2 60%, #7B6BD8 100%);
      height: 10%;
      transition: height 0.08s cubic-bezier(0.4,0,0.2,1);
      flex-shrink: 0;
    }
    .vc-btn {
      width: 26px; height: 26px;
      border-radius: 50%;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      border: 1px solid transparent;
      flex-shrink: 0;
      transition: transform 0.15s ease, filter 0.15s ease, box-shadow 0.2s ease;
    }
    .vc-btn:hover { transform: scale(1.08); }
    .vc-btn.cancel {
      background: rgba(255,255,255,0.08);
      border-color: rgba(255,255,255,0.14);
      color: #D7D0FF;
    }
    .vc-btn.cancel:hover { background: rgba(255,255,255,0.14); color: #fff; }
    .vc-btn.send {
      background: linear-gradient(135deg, #34D399 0%, #10B981 100%);
      color: #fff;
      box-shadow: 0 4px 12px -4px rgba(16, 185, 129, 0.55), inset 0 1px 0 rgba(255,255,255,0.18);
    }
    .vc-btn.send:hover { filter: brightness(1.08); }

    /* ═════════ Voice Message Bubble (in chat) ═════════ */
    .companion-msg.companion-msg-voice {
      padding: 10px 12px;
      background:
        radial-gradient(120% 100% at 0% 0%, rgba(168,155,242,0.28), transparent 55%),
        linear-gradient(135deg, rgba(123,107,216,0.28), rgba(83,74,183,0.2));
      border: 1px solid rgba(168,155,242,0.42);
      border-radius: 18px;
      border-bottom-right-radius: 6px;
      align-self: flex-end;
      max-width: 88%;
      color: #fff;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .vb-player {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .vb-play {
      width: 28px; height: 28px;
      border-radius: 50%;
      background: linear-gradient(135deg, #E6DEFF 0%, #A89BF2 60%, #7B6BD8 100%);
      color: #1E1848;
      border: none;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      box-shadow: 0 4px 10px -3px rgba(83,74,183,0.6), inset 0 1px 0 rgba(255,255,255,0.35);
      transition: transform 0.15s ease, filter 0.15s ease;
    }
    .vb-play:hover { transform: scale(1.08); filter: brightness(1.06); }
    .vb-play svg { width: 12px; height: 12px; }
    .vb-wave {
      flex: 1;
      display: flex;
      align-items: center;
      gap: 2px;
      height: 20px;
      min-width: 0;
      overflow: hidden;
      cursor: pointer;
    }
    .vb-wave span {
      width: 2px;
      border-radius: 1px;
      background: linear-gradient(180deg, #E6DEFF, #A89BF2);
      flex-shrink: 0;
      opacity: 0.85;
      transition: opacity 0.2s;
    }
    .vb-wave span.played { opacity: 0.4; }
    .vb-duration {
      font-size: 10px;
      font-weight: 600;
      color: #D7D0FF;
      font-variant-numeric: tabular-nums;
      flex-shrink: 0;
      letter-spacing: 0.3px;
    }
    .vb-transcript {
      font-size: 11.5px;
      color: #FFFFFF;
      opacity: 0.9;
      line-height: 1.4;
      padding: 0 2px;
    }

    /* ═════════ Listening Mode Overlay ═════════ */
    .voice-overlay {
      position: absolute;
      inset: 0;
      border-radius: inherit;
      background:
        radial-gradient(120% 80% at 50% 0%, rgba(139, 92, 246, 0.25) 0%, transparent 55%),
        radial-gradient(100% 70% at 50% 100%, rgba(34, 211, 238, 0.18) 0%, transparent 60%),
        linear-gradient(180deg, rgba(14, 10, 32, 0.94) 0%, rgba(8, 6, 22, 0.98) 100%);
      backdrop-filter: blur(22px);
      -webkit-backdrop-filter: blur(22px);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: flex-start;
      gap: 6px;
      padding: 8px 10px 10px;
      opacity: 0;
      pointer-events: none;
      transform: scale(0.98);
      transition: opacity 0.28s ease, transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
      z-index: 20;
      overflow: hidden;
    }
    .voice-overlay.active {
      opacity: 1;
      pointer-events: none; /* background lets clicks pass through to composer below */
      transform: scale(1);
    }
    /* Re-enable interactivity on the overlay's interactive children */
    .voice-overlay.active > * { pointer-events: auto; }

    .voice-overlay-top {
      flex-shrink: 0;
      width: 100%;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      z-index: 2;
      min-height: 24px;
    }
    .voice-status {
      font-size: 10.5px;
      font-weight: 600;
      letter-spacing: 0.3px;
      background: linear-gradient(135deg, #E6DEFF 0%, #C8BDFF 55%, #A89BF2 100%);
      -webkit-background-clip: text;
              background-clip: text;
      color: transparent;
      display: inline-flex;
      align-items: baseline;
      gap: 2px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      max-width: calc(100% - 34px);
    }
    .voice-ellipsis {
      display: inline-flex;
      gap: 2px;
      margin-left: 3px;
    }
    .voice-ellipsis span {
      color: #A89BF2;
      animation: voice-dot 1.3s ease-in-out infinite;
    }
    .voice-ellipsis span:nth-child(2) { animation-delay: 0.18s; }
    .voice-ellipsis span:nth-child(3) { animation-delay: 0.36s; }
    @keyframes voice-dot {
      0%, 60%, 100% { opacity: 0.25; transform: translateY(0); }
      30%           { opacity: 1;    transform: translateY(-1px); }
    }
    .voice-close-btn {
      width: 20px;
      height: 20px;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.14);
      color: #D7D0FF;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: background 0.18s, color 0.18s, transform 0.18s;
    }
    .voice-close-btn:hover {
      background: rgba(255, 255, 255, 0.12);
      color: #fff;
      transform: rotate(90deg);
    }

    /* ───── Orb ───── */
    .voice-orb-wrap {
      flex: 1 1 auto;
      min-height: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      width: 100%;
      position: relative;
      padding: 4px 0;
    }
    .voice-orb {
      --orb-scale: 1;
      --orb-size: clamp(50px, 16vh, 72px);
      position: relative;
      width: var(--orb-size);
      height: var(--orb-size);
      display: flex;
      align-items: center;
      justify-content: center;
      transform: scale(var(--orb-scale));
      transition: transform 0.12s cubic-bezier(0.4, 0, 0.2, 1);
    }
    /* Core soft blob */
    .orb-core {
      position: absolute;
      inset: 18%;
      border-radius: 50%;
      background:
        radial-gradient(circle at 30% 30%, #F0B4FF 0%, #A78BFA 35%, #6366F1 70%, #312E81 100%);
      filter: blur(2px);
      box-shadow:
        inset 0 0 40px rgba(255, 255, 255, 0.25),
        0 0 60px rgba(167, 139, 250, 0.55);
      animation: orb-core-breathe 3.6s ease-in-out infinite;
    }
    @keyframes orb-core-breathe {
      0%, 100% { transform: scale(1); filter: blur(2px) hue-rotate(0deg); }
      50%      { transform: scale(1.04); filter: blur(3px) hue-rotate(20deg); }
    }
    /* Concentric glowing rings */
    .orb-ring {
      position: absolute;
      inset: 0;
      border-radius: 50%;
      filter: blur(8px);
      opacity: 0.8;
      mix-blend-mode: screen;
    }
    .orb-ring-a {
      background: conic-gradient(from 0deg,
        #F472B6 0deg, #A78BFA 90deg, transparent 180deg,
        transparent 270deg, #22D3EE 340deg, #F472B6 360deg);
      animation: orb-ring-spin 8s linear infinite;
    }
    .orb-ring-b {
      inset: 8%;
      background: conic-gradient(from 180deg,
        #22D3EE 0deg, transparent 90deg,
        #C084FC 200deg, transparent 300deg, #22D3EE 360deg);
      animation: orb-ring-spin-reverse 10s linear infinite;
      opacity: 0.6;
    }
    .orb-ring-c {
      inset: -6%;
      background: radial-gradient(circle at 50% 50%, transparent 55%, rgba(167, 139, 250, 0.35) 68%, transparent 78%);
      filter: blur(12px);
      animation: orb-core-breathe 3.6s ease-in-out infinite;
    }
    .orb-shimmer {
      position: absolute;
      inset: 22%;
      border-radius: 50%;
      background: radial-gradient(circle at 35% 30%, rgba(255, 255, 255, 0.65) 0%, rgba(255, 255, 255, 0) 35%);
      mix-blend-mode: screen;
      animation: orb-shimmer-move 5s ease-in-out infinite;
    }
    @keyframes orb-ring-spin { to { transform: rotate(360deg); } }
    @keyframes orb-ring-spin-reverse { to { transform: rotate(-360deg); } }
    @keyframes orb-shimmer-move {
      0%, 100% { transform: translate(0, 0); opacity: 0.85; }
      50%      { transform: translate(4%, 3%); opacity: 1; }
    }

    /* ───── Waveform — hidden for a cleaner compact layout ───── */
    .voice-waveform {
      display: none;
    }
    .voice-waveform span {
      display: inline-block;
      width: 3px;
      height: 20%;
      border-radius: 2px;
      background: linear-gradient(180deg, #A89BF2 0%, #7B6BD8 50%, #22D3EE 100%);
      box-shadow: 0 0 6px rgba(168, 155, 242, 0.45);
      transition: height 0.08s cubic-bezier(0.4, 0, 0.2, 1);
      transform-origin: center;
      animation: wave-idle 1.6s ease-in-out infinite;
    }
    .voice-waveform span:nth-child(3n+2) { animation-delay: 0.12s; }
    .voice-waveform span:nth-child(3n+3) { animation-delay: 0.24s; }
    @keyframes wave-idle {
      0%, 100% { height: 18%; opacity: 0.55; }
      50%      { height: 32%; opacity: 0.9; }
    }
    .voice-waveform.active span { animation: none; }

    /* ───── Transcript ───── */
    .voice-transcript {
      flex-shrink: 0;
      width: 100%;
      min-height: 0;
      max-height: 44px;
      overflow-y: auto;
      text-align: center;
      padding: 2px 6px;
      font-size: 11px;
      line-height: 1.3;
      color: #FFFFFF;
      font-weight: 500;
      letter-spacing: 0.1px;
      z-index: 2;
      text-shadow: 0 1px 10px rgba(0, 0, 0, 0.35);
    }
    .voice-transcript-placeholder {
      color: rgba(215, 208, 255, 0.55);
      font-weight: 400;
      font-style: italic;
    }
    .voice-transcript .vt-interim {
      color: rgba(215, 208, 255, 0.7);
      font-weight: 400;
    }
    .voice-transcript::-webkit-scrollbar { width: 3px; }
    .voice-transcript::-webkit-scrollbar-thumb {
      background: rgba(168, 155, 242, 0.3);
      border-radius: 2px;
    }

    /* ───── Bottom controls ───── */
    .voice-controls {
      flex-shrink: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      padding-top: 2px;
      z-index: 2;
    }
    .voice-ctrl-btn {
      border: none;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      transition: transform 0.18s ease, box-shadow 0.2s ease, background 0.2s ease;
    }
    .voice-ctrl-primary {
      --mic-scale: 1;
      --mic-glow:
        0 0 0 3px rgba(168, 155, 242, 0.22),
        0 0 16px 4px rgba(168, 155, 242, 0.18),
        0 8px 20px -8px rgba(83, 74, 183, 0.55);
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: radial-gradient(circle at 35% 30%, #C8BDFF 0%, #7B6BD8 55%, #534AB7 100%);
      color: #FFFFFF;
      box-shadow: var(--mic-glow);
      transform: scale(var(--mic-scale));
      transition: box-shadow 0.08s linear, transform 0.08s linear, background 0.2s ease;
      position: relative;
    }
    .voice-ctrl-primary::before {
      content: "";
      position: absolute;
      inset: -14px;
      border-radius: 50%;
      background: radial-gradient(circle at center, rgba(168, 155, 242, 0.35) 0%, transparent 65%);
      opacity: calc((var(--mic-scale) - 1) * 2.2);
      pointer-events: none;
      transition: opacity 0.1s linear;
      z-index: -1;
    }
    .voice-ctrl-primary:hover { filter: brightness(1.08); }
    .voice-ctrl-primary:active { transform: scale(calc(var(--mic-scale) * 0.96)); }
    .voice-ctrl-primary.paused {
      background: radial-gradient(circle at 35% 30%, #34D399 0%, #10B981 55%, #047857 100%);
    }
    .voice-ctrl-secondary {
      width: 28px;
      height: 28px;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.14);
      color: #D7D0FF;
    }
    .voice-ctrl-secondary:hover {
      background: rgba(255, 255, 255, 0.12);
      color: #FFFFFF;
      transform: scale(1.05);
    }
    .voice-ctrl-secondary:active { transform: scale(0.95); }
    /* Error state */
    .voice-overlay.error .orb-core { background: radial-gradient(circle at 30% 30%, #FCA5A5 0%, #EF4444 70%, #7F1D1D 100%); }
    .voice-overlay.error .voice-status { color: #FCA5A5; background: none; -webkit-background-clip: border-box; background-clip: border-box; }
    /* Transcribing state — pulse orb faster, hide waveform + controls */
    .voice-overlay.transcribing .voice-waveform { opacity: 0.35; }
    .voice-overlay.transcribing .voice-controls { opacity: 0.5; pointer-events: none; }
    .voice-overlay.transcribing .orb-core { animation-duration: 1.4s; }
    .voice-overlay.transcribing .orb-ring-a { animation-duration: 3s; }
    .voice-overlay.transcribing .orb-ring-b { animation-duration: 4s; }
    .companion-attach-menu {
      display: none;
      position: absolute;
      bottom: 100%;
      left: 0;
      margin-bottom: 6px;
      background: var(--vscode-menu-background, var(--vscode-dropdown-background, #252526));
      border: 1px solid var(--vscode-menu-border, var(--vscode-dropdown-border, #454545));
      border-radius: 8px;
      padding: 4px;
      z-index: 100;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
      min-width: 160px;
    }
    .companion-attach-menu.visible {
      display: block;
    }
    .companion-attach-menu-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 10px;
      border-radius: 10px;
      cursor: pointer;
      font-size: 12px;
      color: var(--vscode-menu-foreground, var(--vscode-foreground));
      transition: background 0.18s ease, transform 0.18s ease;
      border: none;
      background: none;
      width: 100%;
      text-align: left;
    }
    .companion-attach-menu-item:hover {
      background: rgba(168, 155, 242, 0.08);
      transform: translateX(2px);
    }
    .companion-attach-menu-item:hover .ai-tile {
      transform: scale(1.06);
    }
    .companion-attach-menu-icon {
      font-size: 14px;
      width: 20px;
      text-align: center;
    }
    /* ───── Attachment icon tiles (rotating palette to match chat bubbles) ───── */
    .ai-tile {
      width: 28px;
      height: 28px;
      min-width: 28px;
      border-radius: 9px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border: 1px solid transparent;
      transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06);
    }
    .ai-tile svg {
      width: 14px;
      height: 14px;
      transition: filter 0.2s ease;
    }
    .ai-lavender {
      background: linear-gradient(135deg, rgba(200, 189, 255, 0.28) 0%, rgba(123, 107, 216, 0.14) 100%);
      border-color: rgba(168, 155, 242, 0.45);
      color: #E6DEFF;
    }
    .ai-lavender svg { filter: drop-shadow(0 0 6px rgba(168, 155, 242, 0.55)); }
    .ai-peach {
      background: linear-gradient(135deg, rgba(255, 213, 138, 0.3) 0%, rgba(245, 181, 71, 0.14) 100%);
      border-color: rgba(245, 181, 71, 0.5);
      color: #FFE5B4;
    }
    .ai-peach svg { filter: drop-shadow(0 0 6px rgba(245, 181, 71, 0.55)); }
    .ai-mint {
      background: linear-gradient(135deg, rgba(159, 243, 209, 0.3) 0%, rgba(52, 211, 153, 0.14) 100%);
      border-color: rgba(52, 211, 153, 0.5);
      color: #B8F5DD;
    }
    .ai-mint svg { filter: drop-shadow(0 0 6px rgba(52, 211, 153, 0.55)); }
    .ai-pink {
      background: linear-gradient(135deg, rgba(255, 179, 230, 0.3) 0%, rgba(236, 110, 199, 0.14) 100%);
      border-color: rgba(236, 110, 199, 0.5);
      color: #FFD1EC;
    }
    .ai-pink svg { filter: drop-shadow(0 0 6px rgba(236, 110, 199, 0.55)); }
    .companion-attach-menu-label {
      flex: 1;
    }
    .companion-attach-menu-hint {
      font-size: 10px;
      color: var(--vscode-descriptionForeground);
      opacity: 0.7;
    }
    .companion-attach-preview {
      display: none;
      padding: 6px 8px;
      background: var(--vscode-input-background);
      border: 1px solid var(--vscode-input-border, rgba(255,255,255,0.1));
      border-radius: 8px;
      margin-bottom: 4px;
      font-size: 11px;
      color: var(--vscode-descriptionForeground);
      order: 2;
      max-height: 120px;
      overflow-y: auto;
    }
    .companion-attach-preview.visible {
      display: block;
    }
    .companion-attach-item {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 3px 0;
      justify-content: space-between;
    }
    .companion-attach-item-info {
      display: flex;
      align-items: center;
      gap: 5px;
      min-width: 0;
      flex: 1;
    }
    .companion-attach-item-name {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .companion-attach-item-actions {
      display: flex;
      gap: 4px;
      flex-shrink: 0;
    }
    .companion-attach-pin {
      background: none;
      border: none;
      color: var(--vscode-descriptionForeground);
      cursor: pointer;
      font-size: 11px;
      padding: 2px 4px;
      border-radius: 4px;
      opacity: 0.6;
    }
    .companion-attach-pin:hover { opacity: 1; }
    .companion-attach-pin.pinned {
      color: var(--vscode-charts-yellow, #e2c541);
      opacity: 1;
    }
    .companion-attach-remove {
      background: none;
      border: none;
      color: var(--vscode-descriptionForeground);
      cursor: pointer;
      font-size: 13px;
      padding: 0 3px;
      opacity: 0.5;
    }
    .companion-attach-remove:hover { opacity: 1; color: var(--vscode-errorForeground); }
    .companion-input-row {
      display: flex;
      gap: 6px;
      align-items: center;
      order: 3;
      position: relative;
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(168, 155, 242, 0.15);
      border-radius: 22px;
      padding: 6px 6px 6px 10px;
      transition: all 0.2s ease;
      z-index: 1;
    }
    .companion-input-row:focus-within {
      border-color: rgba(168, 155, 242, 0.5);
      background: rgba(255, 255, 255, 0.05);
      box-shadow: 0 0 0 3px rgba(123, 107, 216, 0.1);
    }
    .companion-input {
      flex: 1;
      background: transparent;
      color: var(--vscode-input-foreground);
      border: none !important;
      outline: none !important;
      box-shadow: none !important;
      padding: 6px 4px;
      font-size: 12.5px;
      font-family: inherit;
      resize: none;
      min-height: 20px;
      max-height: 80px;
      line-height: 1.5;
      -webkit-appearance: none;
      appearance: none;
    }
    .companion-input:focus,
    .companion-input:focus-visible,
    .companion-input:active {
      outline: none !important;
      border: none !important;
      box-shadow: none !important;
    }
    .companion-input::placeholder {
      color: rgba(168, 155, 242, 0.5);
    }
    .companion-char-count {
      display: none;
      font-size: 9px;
      color: var(--vscode-descriptionForeground);
      opacity: 0.5;
      position: absolute;
      right: 50px;
      bottom: 2px;
      pointer-events: none;
    }
    .companion-char-count.near-limit {
      opacity: 0.8;
      color: var(--vscode-editorWarning-foreground, #cca700);
    }
    .companion-char-count.at-limit {
      opacity: 1;
      color: var(--vscode-errorForeground, #f44747);
    }
    .companion-send-btn {
      background: linear-gradient(135deg, #7B6BD8 0%, #534AB7 100%);
      color: #FFFFFF;
      border: none;
      border-radius: 50%;
      width: 30px;
      height: 30px;
      padding: 0;
      cursor: pointer;
      font-size: 14px;
      font-weight: 600;
      flex-shrink: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 2px 8px rgba(83, 74, 183, 0.4);
      transition: all 0.2s ease;
    }
    .companion-send-btn:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 12px rgba(83, 74, 183, 0.55);
    }
    .companion-send-btn:active {
      transform: translateY(0);
    }
    .companion-empty {
      text-align: center;
      font-size: 11.5px;
      color: rgba(168, 155, 242, 0.6);
      padding: 20px 16px;
      line-height: 1.6;
      background: radial-gradient(ellipse at center, rgba(168, 155, 242, 0.04) 0%, transparent 70%);
      border-radius: 12px;
    }
    .companion-clear-btn {
      background: rgba(168, 155, 242, 0.06);
      border: 1px solid transparent;
      color: rgba(168, 155, 242, 0.5);
      font-size: 10px;
      font-weight: 500;
      cursor: pointer;
      padding: 3px 10px;
      border-radius: 12px;
      letter-spacing: 0.3px;
      transition: all 0.2s ease;
    }
    .companion-clear-btn:hover {
      color: #C8BDFF;
      background: rgba(168, 155, 242, 0.12);
      border-color: rgba(168, 155, 242, 0.2);
    }
    .companion-watching {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 11px;
      color: #A89BF2;
      padding: 7px 12px;
      background: linear-gradient(90deg, rgba(123, 107, 216, 0.1) 0%, rgba(168, 155, 242, 0.05) 100%);
      border: 1px solid rgba(168, 155, 242, 0.15);
      border-radius: 20px;
      animation: watching-pulse 2.5s ease-in-out infinite;
    }
    .companion-watching .dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #A89BF2;
      box-shadow: 0 0 8px rgba(168, 155, 242, 0.6);
      animation: dot-blink 1.5s ease-in-out infinite;
    }
    @keyframes watching-pulse {
      0%, 100% { opacity: 0.7; }
      50% { opacity: 1; }
    }
    .companion-options {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      margin-top: 10px;
      padding-bottom: 4px;
      width: 100%;
      animation: msg-fade-in 0.3s ease-out;
    }
    .companion-option-btn {
      background: rgba(168, 155, 242, 0.08);
      color: #A89BF2;
      border: 1px solid rgba(168, 155, 242, 0.2);
      border-radius: 20px;
      padding: 6px 14px;
      font-size: 11.5px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s ease;
      white-space: normal;
      word-break: break-word;
      max-width: 100%;
    }
    .companion-option-btn:hover {
      background: linear-gradient(135deg, rgba(123, 107, 216, 0.25) 0%, rgba(83, 74, 183, 0.25) 100%);
      color: #FFFFFF;
      border-color: rgba(168, 155, 242, 0.5);
      transform: translateY(-1px);
      box-shadow: 0 2px 8px rgba(83, 74, 183, 0.25);
    }
    .companion-option-btn:active {
      transform: translateY(0);
    }
    .companion-option-other {
      background: transparent;
      border-style: dashed;
      opacity: 0.7;
    }
    .companion-option-other:hover {
      opacity: 1;
      background: rgba(255,255,255,0.04);
    }
    @keyframes dot-blink {
      0%, 100% { opacity: 0.3; }
      50% { opacity: 1; }
    }

    /* ───── Codepet Welcome Banner — Hero Card ───── */
    .cp-welcome {
      position: relative;
      display: grid;
      grid-template-columns: 1fr auto;
      grid-template-areas:
        "chip close"
        "title close"
        "sub close";
      column-gap: 6px;
      row-gap: 1px;
      padding: 6px 10px 7px;
      margin-bottom: 8px;
      border-radius: 10px;
      overflow: hidden;
      background:
        radial-gradient(120% 110% at 0% 0%, rgba(168, 155, 242, 0.38) 0%, transparent 55%),
        radial-gradient(120% 110% at 100% 100%, rgba(236, 110, 199, 0.25) 0%, transparent 60%),
        linear-gradient(155deg, rgba(52, 38, 108, 0.95) 0%, rgba(28, 20, 62, 0.96) 55%, rgba(14, 10, 32, 0.98) 100%);
      border: 1px solid rgba(168, 155, 242, 0.3);
      box-shadow:
        0 14px 32px -14px rgba(83, 74, 183, 0.65),
        inset 0 1px 0 rgba(255, 255, 255, 0.07);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      animation: cp-welcome-in 0.48s cubic-bezier(0.34, 1.56, 0.64, 1) both;
    }
    @keyframes cp-welcome-in {
      from { opacity: 0; transform: translateY(-8px) scale(0.98); }
      to   { opacity: 1; transform: translateY(0) scale(1); }
    }
    /* Decorative orbs in the corners (from references) */
    .cp-welcome::after {
      content: "";
      position: absolute;
      width: 44px;
      height: 44px;
      right: -16px;
      bottom: -18px;
      border-radius: 50%;
      background: radial-gradient(circle at 35% 35%, rgba(236, 110, 199, 0.38), rgba(168, 85, 247, 0.14) 60%, transparent 80%);
      filter: blur(4px);
      pointer-events: none;
      z-index: 0;
    }
    .cp-welcome::before {
      content: "";
      position: absolute;
      inset: 0;
      border-radius: inherit;
      padding: 1px;
      background: linear-gradient(135deg, rgba(200, 189, 255, 0.6), rgba(123, 107, 216, 0) 45%, rgba(236, 110, 199, 0.45) 100%);
      -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
      -webkit-mask-composite: xor;
              mask-composite: exclude;
      pointer-events: none;
      z-index: 1;
    }
    .cp-welcome > * { position: relative; z-index: 2; }

    .cp-welcome-chip {
      grid-area: chip;
      justify-self: start;
      font-size: 7px;
      font-weight: 800;
      letter-spacing: 1px;
      padding: 1px 6px;
      border-radius: 999px;
      background: linear-gradient(135deg, rgba(168, 155, 242, 0.32), rgba(123, 107, 216, 0.12));
      border: 1px solid rgba(168, 155, 242, 0.55);
      color: #E6DEFF;
      text-shadow: 0 0 10px rgba(168, 155, 242, 0.45);
    }
    .cp-welcome-text { display: contents; }
    .cp-welcome-title {
      grid-area: title;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.1px;
      line-height: 1.2;
      background: linear-gradient(135deg, #FFFFFF 0%, #E6DEFF 55%, #C8BDFF 100%);
      -webkit-background-clip: text;
              background-clip: text;
      color: transparent;
      position: relative;
    }
    /* Underline removed for a more compact banner */
    .cp-welcome-title::after { display: none; }
    .cp-welcome-sub {
      grid-area: sub;
      font-size: 9.5px;
      color: #BDB4DB;
      opacity: 0.82;
      line-height: 1.3;
    }
    .cp-welcome-close {
      grid-area: close;
      align-self: start;
      flex-shrink: 0;
      width: 16px;
      height: 16px;
      align-self: center;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.14);
      color: #D7D0FF;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: background 0.18s ease, color 0.18s ease, transform 0.18s ease;
    }
    .cp-welcome-close:hover {
      background: rgba(255, 255, 255, 0.14);
      color: #fff;
      transform: rotate(90deg);
    }
    /* Inline primary CTA — fully rounded purple gradient pill */
    .cp-welcome-cta {
      grid-area: cta;
      margin-top: 4px;
      padding: 10px 14px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.2px;
      border-radius: 999px;
      border: 1px solid rgba(200, 189, 255, 0.4);
      background: linear-gradient(135deg, #A89BF2 0%, #7B6BD8 55%, #534AB7 100%);
      color: #FFFFFF;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      box-shadow:
        0 10px 24px -10px rgba(83, 74, 183, 0.8),
        inset 0 1px 0 rgba(255, 255, 255, 0.18);
      transition: transform 0.18s ease, box-shadow 0.2s ease, filter 0.2s ease;
    }
    .cp-welcome-cta:hover {
      transform: translateY(-1px);
      filter: brightness(1.06);
      box-shadow:
        0 14px 28px -10px rgba(83, 74, 183, 0.95),
        inset 0 1px 0 rgba(255, 255, 255, 0.22);
    }
    .cp-welcome-cta:active { transform: translateY(0); }
    .cp-welcome-cta svg {
      width: 14px;
      height: 14px;
      transition: transform 0.18s ease;
    }
    .cp-welcome-cta:hover svg { transform: translateX(2px); }

    /* ───── Pet Widget — Vibrant Hero Dashboard Card ───── */
    /* Layered radial gradients: hot pink + cyan + lavender + amber accents */
    .pet-widget {
      position: relative;
      text-align: center;
      padding: 22px 16px 20px;
      border-radius: 22px !important;
      background:
        radial-gradient(58% 40% at 18% 18%, rgba(168, 85, 247, 0.55) 0%, transparent 70%),
        radial-gradient(55% 45% at 85% 20%, rgba(236, 72, 153, 0.42) 0%, transparent 70%),
        radial-gradient(55% 40% at 15% 85%, rgba(34, 211, 238, 0.30) 0%, transparent 70%),
        radial-gradient(60% 40% at 88% 88%, rgba(251, 146, 60, 0.28) 0%, transparent 75%),
        radial-gradient(80% 55% at 50% 50%, rgba(123, 107, 216, 0.20) 0%, transparent 75%),
        linear-gradient(160deg, rgba(62, 42, 130, 0.95) 0%, rgba(40, 25, 92, 0.96) 45%, rgba(24, 16, 60, 0.98) 100%) !important;
      border: 1px solid rgba(200, 189, 255, 0.28) !important;
      box-shadow:
        0 20px 50px -18px rgba(168, 85, 247, 0.55),
        0 10px 24px -14px rgba(236, 72, 153, 0.30),
        inset 0 1px 0 rgba(255, 255, 255, 0.10) !important;
      overflow: hidden !important;
    }
    /* Gradient hairline border — now rainbow-ish */
    .pet-widget::after {
      content: "";
      position: absolute;
      inset: 0;
      border-radius: 22px;
      padding: 1px;
      background: linear-gradient(135deg,
        rgba(200, 189, 255, 0.75) 0%,
        rgba(236, 72, 153, 0.55) 30%,
        rgba(168, 85, 247, 0) 55%,
        rgba(34, 211, 238, 0.55) 80%,
        rgba(251, 146, 60, 0.5) 100%);
      -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
      -webkit-mask-composite: xor;
              mask-composite: exclude;
      pointer-events: none;
      z-index: 2;
    }
    /* Floating decorative blobs — slow ambient drift, purely cosmetic */
    .pet-widget > .pet-blob {
      position: absolute;
      border-radius: 50%;
      pointer-events: none;
      filter: blur(14px);
      opacity: 0.55;
      z-index: 0;
      mix-blend-mode: screen;
    }
    .pet-widget > .pet-blob.b1 {
      width: 80px; height: 80px;
      top: -18px; left: 28%;
      background: radial-gradient(circle, #F472B6 0%, rgba(244, 114, 182, 0) 70%);
      animation: cp-blob-drift-a 14s ease-in-out infinite;
    }
    .pet-widget > .pet-blob.b2 {
      width: 70px; height: 70px;
      bottom: -14px; left: -12px;
      background: radial-gradient(circle, #22D3EE 0%, rgba(34, 211, 238, 0) 70%);
      animation: cp-blob-drift-b 17s ease-in-out infinite;
    }
    .pet-widget > .pet-blob.b3 {
      width: 60px; height: 60px;
      top: 42%; right: -12px;
      background: radial-gradient(circle, #FBBF24 0%, rgba(251, 191, 36, 0) 70%);
      animation: cp-blob-drift-c 19s ease-in-out infinite;
      opacity: 0.45;
    }
    .pet-widget > .pet-blob.b4 {
      width: 50px; height: 50px;
      bottom: 38%; left: 52%;
      background: radial-gradient(circle, #A78BFA 0%, rgba(167, 139, 250, 0) 70%);
      animation: cp-blob-drift-d 22s ease-in-out infinite;
      opacity: 0.5;
    }
    @keyframes cp-blob-drift-a {
      0%, 100% { transform: translate(0, 0) scale(1); }
      33%      { transform: translate(12px, 18px) scale(1.12); }
      66%      { transform: translate(-8px, 10px) scale(0.92); }
    }
    @keyframes cp-blob-drift-b {
      0%, 100% { transform: translate(0, 0) scale(1); }
      40%      { transform: translate(14px, -10px) scale(1.18); }
      80%      { transform: translate(-6px, -16px) scale(0.88); }
    }
    @keyframes cp-blob-drift-c {
      0%, 100% { transform: translate(0, 0) scale(1); }
      50%      { transform: translate(-16px, 8px) scale(1.15); }
    }
    @keyframes cp-blob-drift-d {
      0%, 100% { transform: translate(0, 0) scale(1); }
      50%      { transform: translate(10px, -14px) scale(1.1); }
    }
    /* Tiny sparkle dots scattered across the card — like the reference confetti */
    .pet-widget > .pet-sparkle {
      position: absolute;
      width: 4px;
      height: 4px;
      border-radius: 50%;
      pointer-events: none;
      z-index: 1;
      opacity: 0.75;
      animation: cp-sparkle-twinkle 3s ease-in-out infinite;
    }
    .pet-widget > .pet-sparkle.s1 { top: 26%;  left: 18%; background: #FBCFE8; animation-delay: 0.0s; }
    .pet-widget > .pet-sparkle.s2 { top: 20%;  right: 22%; background: #A5F3FC; animation-delay: 0.7s; width: 3px; height: 3px; }
    .pet-widget > .pet-sparkle.s3 { top: 72%;  left: 22%; background: #FDE68A; animation-delay: 1.2s; }
    .pet-widget > .pet-sparkle.s4 { bottom: 24%; right: 18%; background: #DDD6FE; animation-delay: 1.9s; width: 5px; height: 5px; }
    .pet-widget > .pet-sparkle.s5 { top: 50%;  left: 8%; background: #FCA5A5; animation-delay: 2.3s; width: 3px; height: 3px; }
    @keyframes cp-sparkle-twinkle {
      0%, 100% { opacity: 0.25; transform: scale(0.8); }
      50%      { opacity: 1;    transform: scale(1.2); }
    }
    @media (prefers-reduced-motion: reduce) {
      .pet-widget > .pet-blob, .pet-widget > .pet-sparkle { animation: none !important; }
    }
    /* Corner icon-button cluster (replaces old toolbar) */
    .pet-widget-actions {
      position: absolute;
      top: 12px;
      right: 12px;
      display: flex;
      gap: 6px;
      z-index: 4;
    }
    .pet-widget-icon-btn {
      width: 28px;
      height: 28px;
      padding: 0;
      border-radius: 50%;
      background: rgba(168, 155, 242, 0.10);
      border: 1px solid rgba(168, 155, 242, 0.28);
      color: #C8BDFF;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      transition: transform 0.2s cubic-bezier(0.34, 1.56, 0.64, 1),
                  background 0.2s ease,
                  border-color 0.2s ease,
                  color 0.2s ease;
    }
    .pet-widget-icon-btn:hover {
      background: linear-gradient(135deg, rgba(123, 107, 216, 0.35), rgba(168, 155, 242, 0.2));
      border-color: rgba(168, 155, 242, 0.55);
      color: #FFFFFF;
      transform: translateY(-1px);
    }
    .pet-widget-icon-btn[data-action="refresh"]:hover svg { animation: cp-spin-once 0.6s cubic-bezier(0.34, 1.56, 0.64, 1); }
    .pet-widget-icon-btn[data-action="openSettings"]:hover svg { animation: cp-cog-turn 1.4s linear infinite; }
    .pet-widget-icon-btn:active { transform: translateY(0) scale(0.95); }
    .pet-widget-icon-btn svg {
      width: 13px;
      height: 13px;
      pointer-events: none;  /* clicks pass through to the button */
    }
    .pet-widget-icon-btn svg * { pointer-events: none; }
    @keyframes cp-spin-once { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
    @keyframes cp-cog-turn { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

    .pet-avatar {
      position: relative;
      width: 96px;
      height: 108px;
      margin: 18px auto 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 2;
      cursor: pointer;
      /* Walk-like bounce: hop + settle + sway, 2.6s cycle */
      animation: cp-pet-hop 2.6s cubic-bezier(0.45, 0, 0.55, 1) infinite;
      transition: transform 0.25s ease;
    }
    .pet-avatar:hover {
      animation-play-state: paused;
      transform: scale(1.08) translateY(-2px);
    }
    .pet-avatar[aria-expanded="true"] {
      /* Subtle ring hint when stats are revealed */
      filter: drop-shadow(0 0 10px rgba(168, 155, 242, 0.6));
    }
    /* "Tap me" hint — ABOVE the avatar, only visible on hover */
    .pet-tap-hint {
      position: absolute;
      left: 50%;
      bottom: calc(100% - 14px);  /* sits close to the character's head */
      transform: translateX(-50%) translateY(4px);
      background: linear-gradient(135deg, rgba(168, 155, 242, 0.3), rgba(236, 72, 153, 0.2));
      border: 1px solid rgba(200, 189, 255, 0.5);
      color: #E6DEFF;
      font-size: 8px;
      font-weight: 700;
      letter-spacing: 0.6px;
      padding: 2px 9px;
      border-radius: 999px;
      white-space: nowrap;
      text-transform: uppercase;
      backdrop-filter: blur(6px);
      -webkit-backdrop-filter: blur(6px);
      opacity: 0;
      pointer-events: none;
      z-index: 4;
      transition: opacity 0.2s ease, transform 0.22s cubic-bezier(0.34, 1.56, 0.64, 1);
    }
    /* Reveal on hover (or keyboard focus) of the character */
    .pet-avatar-wrap:hover .pet-tap-hint,
    .pet-avatar:hover + .pet-tap-hint,
    .pet-avatar-wrap:focus-within .pet-tap-hint {
      opacity: 1;
      transform: translateX(-50%) translateY(0);
    }
    /* Small decorative arrow pointing down to the character */
    .pet-tap-hint::after {
      content: "";
      position: absolute;
      left: 50%;
      top: 100%;
      transform: translateX(-50%);
      border: 4px solid transparent;
      border-top-color: rgba(168, 155, 242, 0.5);
    }
    /* Hide entirely when stats are revealed */
    .pet-widget.stats-shown .pet-tap-hint {
      display: none;
    }
    @media (prefers-reduced-motion: reduce) {
      .pet-tap-hint { transition: none !important; }
    }
    .pet-avatar-wrap {
      position: relative;
      display: inline-block;
      width: 100%;
    }
    /* Walk-hop cycle — lift → peak → land → squash → rise (inspired by Duolingo-style character walks) */
    @keyframes cp-pet-hop {
      0%   { transform: translateY(0)     scaleY(1)    scaleX(1); }
      20%  { transform: translateY(-7px)  scaleY(1.03) scaleX(0.98); }
      35%  { transform: translateY(-9px)  scaleY(1.04) scaleX(0.97); }
      55%  { transform: translateY(-2px)  scaleY(1)    scaleX(1); }
      68%  { transform: translateY(2px)   scaleY(0.93) scaleX(1.05); }  /* squash on landing */
      82%  { transform: translateY(0)     scaleY(1.02) scaleX(0.99); }
      100% { transform: translateY(0)     scaleY(1)    scaleX(1); }
    }

    /* Soft pulsing glow halo — echoes the hop but slower, more ambient */
    .pet-avatar::before {
      content: "";
      position: absolute;
      inset: -18px -6px -2px -6px;
      background: radial-gradient(60% 55% at 50% 55%, rgba(168, 155, 242, 0.55) 0%, rgba(123, 107, 216, 0.22) 45%, transparent 75%);
      filter: blur(6px);
      z-index: -1;
      animation: cp-pet-halo 5.2s ease-in-out infinite;
    }
    @keyframes cp-pet-halo {
      0%, 100% { opacity: 0.7;  transform: scale(1); }
      35%      { opacity: 1;    transform: scale(1.1); }
      70%      { opacity: 0.85; transform: scale(1.04); }
    }

    /* Image has its own expressive layer: head tilt + periodic peek/look-around */
    .pet-avatar img {
      width: 100%;
      height: 100%;
      object-fit: contain;
      image-rendering: pixelated;
      image-rendering: -moz-crisp-edges;
      image-rendering: crisp-edges;
      filter: drop-shadow(0 6px 14px rgba(83, 74, 183, 0.55));
      position: relative;
      z-index: 1;
      transform-origin: center bottom;
      /* Two stacked animations: subtle head sway (all the time) + periodic peek (longer loop) */
      animation:
        cp-pet-sway 3.4s ease-in-out infinite,
        cp-pet-peek 11s ease-in-out infinite;
    }

    /* Gentle head tilt — left/right sway, like the owl's head-bob */
    @keyframes cp-pet-sway {
      0%, 100% { transform: rotate(-1.6deg); }
      50%      { transform: rotate(1.6deg); }
    }

    /* Periodic peek/look-around — briefly tilts bigger then returns to normal sway.
       Only "active" during a small window; rest of the time it's neutral-pass-through. */
    @keyframes cp-pet-peek {
      0%, 85%, 100% { filter: drop-shadow(0 6px 14px rgba(83, 74, 183, 0.55)); }
      88%           { transform: translateX(-4px) rotate(-6deg); }
      92%           { transform: translateX(4px)  rotate(5deg); }
      96%           { transform: translateX(0)    rotate(0deg); }
    }

    /* Click to cheer — a proper jump-flip bounce */
    .pet-avatar:active img {
      animation: cp-pet-cheer 0.65s cubic-bezier(0.34, 1.56, 0.64, 1);
    }
    @keyframes cp-pet-cheer {
      0%   { transform: translateY(0)    rotate(0deg)  scale(1); }
      25%  { transform: translateY(-14px) rotate(-8deg) scale(1.06); }
      50%  { transform: translateY(-18px) rotate(6deg)  scale(1.08); }
      75%  { transform: translateY(-6px)  rotate(-3deg) scale(1.02); }
      100% { transform: translateY(0)    rotate(0deg)  scale(1); }
    }

    @media (prefers-reduced-motion: reduce) {
      .pet-avatar, .pet-avatar img, .pet-avatar::before { animation: none !important; }
    }
    .pet-name {
      position: relative;
      z-index: 3;
      font-size: 20px;
      font-weight: 800;
      letter-spacing: 0.2px;
      background: linear-gradient(135deg, #FFFFFF 0%, #FBCFE8 35%, #C8BDFF 70%, #A5F3FC 100%);
      -webkit-background-clip: text;
              background-clip: text;
      color: transparent;
      text-shadow: 0 0 28px rgba(236, 72, 153, 0.25);
    }
    .pet-reaction {
      position: relative;
      z-index: 3;
      font-size: 12.5px;
      color: #DCD1FF;
      margin-top: 6px;
      font-style: italic;
      opacity: 0.98;
      text-shadow: 0 1px 6px rgba(24, 16, 60, 0.6);
    }
    .connection-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 10px;
      font-weight: 600;
      padding: 5px 11px 5px 9px;
      border-radius: 999px;
      margin-top: 12px;
      letter-spacing: 0.2px;
      box-shadow: 0 6px 16px -6px rgba(0, 0, 0, 0.5), inset 0 1px 0 rgba(255, 255, 255, 0.08);
    }
    .connection-badge::before {
      content: "";
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: currentColor;
      box-shadow: 0 0 8px currentColor;
      animation: badge-pulse 2.2s ease-in-out infinite;
    }
    @keyframes badge-pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50%      { opacity: 0.55; transform: scale(0.9); }
    }
    .connected {
      background: linear-gradient(135deg, rgba(52, 211, 153, 0.22) 0%, rgba(16, 185, 129, 0.12) 100%);
      border: 1px solid rgba(52, 211, 153, 0.45);
      color: #6EE7B7;
    }
    .disconnected {
      background: linear-gradient(135deg, rgba(248, 81, 73, 0.2) 0%, rgba(220, 38, 38, 0.1) 100%);
      border: 1px solid rgba(248, 81, 73, 0.45);
      color: #FCA5A5;
    }

    /* ───── Embedded Stats Reveal — inside the dashboard pet widget ───── */
    .pet-widget-stats {
      position: relative;
      z-index: 3;
      max-height: 0;
      opacity: 0;
      margin-top: 0;
      overflow: hidden;
      pointer-events: none;
      transition:
        max-height 0.65s cubic-bezier(0.22, 1, 0.36, 1),
        opacity 0.38s ease,
        margin-top 0.55s cubic-bezier(0.22, 1, 0.36, 1);
    }
    .pet-widget.stats-shown .pet-widget-stats {
      max-height: 280px;
      opacity: 1;
      margin-top: 16px;
      pointer-events: auto;
    }
    /* Tiny label above the chip grid, teal to echo the palette */
    .pet-widget-stats-label {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      font-size: 9px;
      font-weight: 700;
      letter-spacing: 1.6px;
      text-transform: uppercase;
      color: #67F3C8;
      margin-bottom: 8px;
      text-shadow: 0 0 12px rgba(52, 211, 153, 0.35);
      opacity: 0;
      transform: translateY(-4px);
      transition: opacity 0.35s ease 0.08s, transform 0.35s ease 0.08s;
    }
    .pet-widget.stats-shown .pet-widget-stats-label {
      opacity: 1;
      transform: translateY(0);
    }
    .pws-dot {
      display: inline-block;
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #34D399;
      box-shadow: 0 0 8px rgba(52, 211, 153, 0.7);
      animation: cp-pws-pulse 2s ease-in-out infinite;
    }
    @keyframes cp-pws-pulse {
      0%, 100% { opacity: 1;   transform: scale(1); }
      50%      { opacity: 0.5; transform: scale(0.75); }
    }
    .pws-sync {
      font-size: 8px;
      opacity: 0.55;
      margin-left: 4px;
      color: #B6F5DD;
    }
    .pet-widget-stats-meta {
      margin-top: 10px;
      font-size: 10px;
      color: #BDB4DB;
      opacity: 0.7;
      text-align: center;
      display: flex;
      justify-content: center;
      gap: 10px;
    }
    .pet-widget-stats-meta span:empty { display: none; }
    .pet-widget-stats-meta:empty { display: none; }
    /* Stat chips start hidden, stagger-reveal */
    .pet-widget-stats .stat-chip {
      opacity: 0;
      transform: translateY(22px) scale(0.85) rotate(-1deg);
      transition:
        opacity 0.5s cubic-bezier(0.22, 1, 0.36, 1),
        transform 0.6s cubic-bezier(0.34, 1.56, 0.64, 1);
    }
    .pet-widget.stats-shown .pet-widget-stats .stat-chip {
      opacity: 1;
      transform: translateY(0) scale(1) rotate(0deg);
    }
    .pet-widget.stats-shown .pet-widget-stats .stat-chip:nth-child(1) { transition-delay: 0.18s; }
    .pet-widget.stats-shown .pet-widget-stats .stat-chip:nth-child(2) { transition-delay: 0.28s; }
    .pet-widget.stats-shown .pet-widget-stats .stat-chip:nth-child(3) { transition-delay: 0.38s; }
    .pet-widget.stats-shown .pet-widget-stats .stat-chip:nth-child(4) { transition-delay: 0.48s; }

    /* When stats shown: pet shrinks + lifts to make room; name/reaction shrink too */
    .pet-widget .pet-avatar-wrap,
    .pet-widget .pet-avatar,
    .pet-widget .pet-name,
    .pet-widget .pet-reaction {
      transition: transform 0.5s cubic-bezier(0.22, 1, 0.36, 1),
                  font-size 0.4s ease,
                  margin 0.4s ease,
                  opacity 0.3s ease;
    }
    .pet-widget.stats-shown .pet-avatar {
      transform: scale(0.72) translateY(-4px);
    }
    .pet-widget.stats-shown .pet-name {
      font-size: 15px;
    }
    .pet-widget.stats-shown .pet-reaction {
      font-size: 10.5px;
      opacity: 0.72;
      margin-top: 2px;
    }

    @media (prefers-reduced-motion: reduce) {
      .pet-widget-stats,
      .pet-widget-stats .stat-chip,
      .pet-widget-stats-label,
      .pet-widget .pet-avatar,
      .pet-widget .pet-name,
      .pet-widget .pet-reaction {
        transition: none !important;
      }
    }

    /* ───── Stats Grid — Warm Pastel Gradients ───── */
    /* Palette: soft purples + warm pink/peach tones for warmth at the bottom of the sidebar */
    .stats-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
    }
    .stat-chip {
      position: relative;
      border-radius: 16px;
      padding: 14px 10px;
      text-align: center;
      overflow: hidden;
      border: 1px solid rgba(255, 255, 255, 0.08);
      transition: transform 0.2s ease, box-shadow 0.2s ease;
    }
    .stat-chip:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(123, 107, 216, 0.25);
    }
    /* Each chip gets a unique warm gradient */
    .stats-grid .stat-chip:nth-child(1) {
      background: linear-gradient(135deg, #C8A6F5 0%, #F5B3D4 100%);
    }
    .stats-grid .stat-chip:nth-child(2) {
      background: linear-gradient(135deg, #F5B3D4 0%, #FFCBA4 100%);
    }
    .stats-grid .stat-chip:nth-child(3) {
      background: linear-gradient(135deg, #FFCBA4 0%, #F4E5B0 100%);
    }
    .stats-grid .stat-chip:nth-child(4) {
      background: linear-gradient(135deg, #A89BF2 0%, #C8A6F5 100%);
    }
    /* Soft glow inside each chip */
    .stat-chip::before {
      content: "";
      position: absolute;
      top: -30%;
      left: -20%;
      width: 140%;
      height: 140%;
      background: radial-gradient(circle at 30% 20%, rgba(255, 255, 255, 0.35) 0%, transparent 55%);
      pointer-events: none;
    }
    .stat-value {
      position: relative;
      font-size: 20px;
      font-weight: 800;
      color: #2D2664;
      text-shadow: 0 1px 0 rgba(255, 255, 255, 0.4);
      z-index: 1;
    }
    .stat-label {
      position: relative;
      font-size: 9.5px;
      color: rgba(45, 38, 100, 0.75);
      text-transform: uppercase;
      letter-spacing: 0.6px;
      font-weight: 600;
      margin-top: 2px;
      z-index: 1;
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

    /* ───── Event Feed — Gradient Pills ───── */
    .event-item {
      padding: 9px 12px;
      margin-bottom: 6px;
      font-size: 11.5px;
      background: linear-gradient(135deg, rgba(168, 155, 242, 0.08) 0%, rgba(245, 179, 212, 0.05) 100%);
      border: 1px solid rgba(168, 155, 242, 0.12);
      border-left: 3px solid transparent;
      border-image: linear-gradient(to bottom, #A89BF2, #F5B3D4) 1;
      border-radius: 10px;
      position: relative;
      transition: all 0.2s ease;
    }
    .event-item:last-child { margin-bottom: 0; }
    .event-item:hover {
      background: linear-gradient(135deg, rgba(168, 155, 242, 0.14) 0%, rgba(245, 179, 212, 0.1) 100%);
      border-color: rgba(168, 155, 242, 0.25);
    }
    .event-type {
      font-weight: 700;
      margin-right: 4px;
      color: #C8BDFF;
    }
    .event-time {
      font-size: 10px;
      color: rgba(168, 155, 242, 0.6);
      float: right;
      font-weight: 500;
    }

    /* ───── Toolbar — Glass chips ───── */
    .toolbar {
      display: flex;
      gap: 8px;
      margin: 10px 0 12px;
    }
    .toolbar button {
      flex: 1;
      padding: 9px 10px;
      font-size: 11.5px;
      font-weight: 600;
      letter-spacing: 0.2px;
      background:
        linear-gradient(135deg, rgba(168, 155, 242, 0.14) 0%, rgba(123, 107, 216, 0.06) 100%);
      color: #D7D0FF;
      border: 1px solid rgba(168, 155, 242, 0.22);
      border-radius: 12px;
      cursor: pointer;
      transition: transform 0.18s ease, background 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease, color 0.2s ease;
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.05);
    }
    .toolbar button:hover {
      background:
        linear-gradient(135deg, rgba(200, 189, 255, 0.26) 0%, rgba(123, 107, 216, 0.14) 100%);
      border-color: rgba(200, 189, 255, 0.45);
      color: #FFFFFF;
      transform: translateY(-1px);
      box-shadow:
        0 8px 18px -8px rgba(123, 107, 216, 0.6),
        inset 0 1px 0 rgba(255, 255, 255, 0.1);
    }
    .toolbar button:active {
      transform: translateY(0);
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
  <!-- Codepet Welcome Banner (in-sidebar hero) -->
  <div id="welcome-banner" class="cp-welcome">
    <span class="cp-welcome-chip">HELLO</span>
    <div class="cp-welcome-title">${welcome ? (welcome.greeting + ', ' + welcome.userName) : 'Welcome'}</div>
    <div class="cp-welcome-sub">${welcome ? (welcome.petName + ' is ready to code with you.') : 'Codepet is ready to code with you.'}</div>
    <button data-action="dismissWelcome" class="cp-welcome-close" aria-label="Dismiss welcome">
      <svg viewBox="0 0 24 24" width="9" height="9" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="5" x2="19" y2="19"/><line x1="19" y1="5" x2="5" y2="19"/></svg>
    </button>
  </div>

  <!-- Pet Widget -->
  <div class="card pet-widget" id="pet-section">
    <!-- Floating ambient blobs -->
    <span class="pet-blob b1"></span>
    <span class="pet-blob b2"></span>
    <span class="pet-blob b3"></span>
    <span class="pet-blob b4"></span>
    <!-- Sparkle dots -->
    <span class="pet-sparkle s1"></span>
    <span class="pet-sparkle s2"></span>
    <span class="pet-sparkle s3"></span>
    <span class="pet-sparkle s4"></span>
    <span class="pet-sparkle s5"></span>
    <div class="pet-widget-actions">
      <button class="pet-widget-icon-btn" data-action="refresh" title="Refresh" aria-label="Refresh">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M3 12a9 9 0 0 1 15.5-6.3L21 8"/>
          <path d="M21 3v5h-5"/>
          <path d="M21 12a9 9 0 0 1-15.5 6.3L3 16"/>
          <path d="M3 21v-5h5"/>
        </svg>
      </button>
      <button class="pet-widget-icon-btn" data-action="openSettings" title="Settings" aria-label="Settings">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <circle cx="12" cy="12" r="3"/>
          <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
        </svg>
      </button>
    </div>
    <div class="pet-avatar-wrap">
      <span class="pet-tap-hint" id="pet-tap-hint">Tap for stats</span>
      <div class="pet-avatar" id="pet-avatar-toggle" role="button" tabindex="0" aria-expanded="false" aria-controls="pet-widget-stats" title="Tap to see today's coding stats"><img id="pet-avatar-img" src="${initialAvatarUri}" alt="${this.resolvedPetName}" /></div>
    </div>
    <div class="pet-name" id="pet-name">${this.resolvedPetName}</div>
    <div class="pet-reaction" id="pet-reaction">"Ready to code together!"</div>
    <div id="connection-badge" style="display:none;"></div>

    <!-- Embedded Today's Coding stats — revealed on pet click -->
    <div class="pet-widget-stats" id="pet-widget-stats" aria-hidden="true">
      <div class="pet-widget-stats-label">
        <span class="pws-dot"></span>
        Today's coding
        <span id="sync-badge" class="pws-sync" style="display:none;">synced</span>
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
      <div class="pet-widget-stats-meta">
        <span id="branch-info">—</span>
        <span id="idle-status"></span>
      </div>
    </div>
  </div>

  <!-- Lesson Feed -->
  <div class="card" id="lesson-feed-section">
    <div class="lesson-feed-header">
      <div class="card-title ct-pink" style="margin-bottom:0;">Lesson Feed</div>
      <span class="lesson-count" id="lesson-count"></span>
    </div>
    <div class="lesson-swipe-container" id="lesson-swipe-container">
      <div class="lesson-swipe-track" id="lesson-swipe-track">
        <!-- Cards rendered here by JS -->
      </div>
    </div>
    <div class="lesson-swipe-dots" id="lesson-swipe-dots"></div>
    <div id="lesson-feed-empty">
      <div class="lesson-empty">Keep coding with Claude — your lessons will appear here automatically.</div>
    </div>
  </div>

  <!-- Ask Codepet — Companion Chat -->
  <div class="card companion-section" id="companion-section">
    <div class="companion-header" id="companion-header" style="order:0;" role="button" tabindex="0" aria-expanded="false" aria-controls="companion-messages">
      <div class="companion-header-title-group">
        <svg class="companion-header-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <polyline points="6 9 12 15 18 9"></polyline>
        </svg>
        <div class="card-title ct-lavender" style="margin-bottom:0;">Ask Codepet</div>
      </div>
      <button class="companion-clear-btn" data-action="clearCompanion">clear</button>
    </div>
    <div class="companion-messages" id="companion-messages" style="order:1;">
      <div class="companion-empty">Ask me anything about your code!<br>Try: "Summarize my session" or "How should I build this?"</div>
    </div>
    <div class="companion-attach-preview" id="companion-attach-preview" style="order:2;"></div>
    <div class="companion-input-row" id="companion-input-row" style="order:3;">
      <button class="companion-plus-btn" id="companion-plus-btn" title="Attach files, images, URLs, or docs">+</button>
      <div class="companion-attach-menu" id="companion-attach-menu">
        <button class="companion-attach-menu-item" data-attach="file">
          <span class="companion-attach-menu-icon ai-tile ai-lavender" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"></path><polyline points="14 3 14 8 19 8"></polyline><line x1="9" y1="13" x2="15" y2="13"></line><line x1="9" y1="17" x2="15" y2="17"></line></svg>
          </span>
          <span class="companion-attach-menu-label">File</span>
          <span class="companion-attach-menu-hint">from project</span>
        </button>
        <button class="companion-attach-menu-item" data-attach="image">
          <span class="companion-attach-menu-icon ai-tile ai-peach" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2.5"></rect><circle cx="9" cy="11" r="1.6"></circle><path d="M21 16l-5-5-8 8"></path></svg>
          </span>
          <span class="companion-attach-menu-label">Image</span>
          <span class="companion-attach-menu-hint">screenshot</span>
        </button>
        <button class="companion-attach-menu-item" data-attach="url">
          <span class="companion-attach-menu-icon ai-tile ai-mint" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.07 0l2.83-2.83a5 5 0 0 0-7.07-7.07L11 5"></path><path d="M14 11a5 5 0 0 0-7.07 0L4.1 13.83a5 5 0 0 0 7.07 7.07L13 19"></path></svg>
          </span>
          <span class="companion-attach-menu-label">URL</span>
          <span class="companion-attach-menu-hint">paste link</span>
        </button>
        <button class="companion-attach-menu-item" data-attach="knowledge">
          <span class="companion-attach-menu-icon ai-tile ai-pink" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5V4.5A2.5 2.5 0 0 1 6.5 2z"></path><line x1="9" y1="7" x2="16" y2="7"></line><line x1="9" y1="11" x2="14" y2="11"></line></svg>
          </span>
          <span class="companion-attach-menu-label">Knowledge</span>
          <span class="companion-attach-menu-hint">docs, PDFs</span>
        </button>
      </div>
      <textarea class="companion-input" id="companion-input" placeholder="Reply..." rows="1" maxlength="500"></textarea>
      <span class="companion-char-count" id="companion-char-count"></span>

      <!-- Inline voice-record capsule — replaces composer row while recording -->
      <div class="voice-capsule" id="voice-capsule" aria-hidden="true">
        <span class="vc-pulse" aria-hidden="true"></span>
        <span class="vc-timer" id="vc-timer">0:00</span>
        <div class="vc-wave" id="vc-wave">
          <span></span><span></span><span></span><span></span><span></span><span></span>
          <span></span><span></span><span></span><span></span><span></span><span></span>
          <span></span><span></span><span></span><span></span><span></span><span></span>
          <span></span><span></span><span></span><span></span><span></span><span></span>
          <span></span><span></span><span></span><span></span><span></span><span></span>
          <span></span><span></span>
        </div>
        <button class="vc-btn cancel" id="vc-cancel" title="Cancel">
          <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="5" x2="19" y2="19"/><line x1="19" y1="5" x2="5" y2="19"/></svg>
        </button>
        <button class="vc-btn send" id="vc-send" title="Send voice message">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </button>
      </div>

      <div class="mic-send-slot" id="mic-send-slot">
        <button class="companion-mic-btn" id="companion-mic-btn" title="Record voice message" aria-label="Record voice message"><svg class="mic-icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="3" width="6" height="11" rx="3"></rect><path d="M5 11a7 7 0 0 0 14 0"></path><line x1="12" y1="18" x2="12" y2="22"></line><line x1="9" y1="22" x2="15" y2="22"></line></svg></button>
        <button class="companion-send-btn" id="companion-send-btn" data-action="sendCompanion" aria-label="Send message">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="12" y1="19" x2="12" y2="5"></line><polyline points="5 12 12 5 19 12"></polyline></svg>
        </button>
      </div>
      <!-- Voice chat button sits INSIDE the input pill, next to the mic -->
      <button class="companion-vc-btn" id="companion-vc-btn" title="Voice chat with Codepet" aria-label="Voice chat with Codepet"><svg class="vc-waveform" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" aria-hidden="true"><line x1="6" y1="10" x2="6" y2="14"></line><line x1="10" y1="7" x2="10" y2="17"></line><line x1="14" y1="5" x2="14" y2="19"></line><line x1="18" y1="9" x2="18" y2="15"></line></svg></button>
    </div>

    <!-- ═══ Listening Mode Overlay (full-screen inside companion card) ═══ -->
    <div class="voice-overlay" id="voice-overlay" aria-hidden="true">
      <div class="voice-overlay-top">
        <span class="voice-status" id="voice-status">Listening<span class="voice-ellipsis"><span>.</span><span>.</span><span>.</span></span></span>
        <button class="voice-close-btn" id="voice-cancel-btn" aria-label="Cancel">
          <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="5" x2="19" y2="19"/><line x1="19" y1="5" x2="5" y2="19"/></svg>
        </button>
      </div>

      <div class="voice-orb-wrap">
        <div class="voice-orb" id="voice-orb">
          <div class="orb-core"></div>
          <div class="orb-ring orb-ring-a"></div>
          <div class="orb-ring orb-ring-b"></div>
          <div class="orb-ring orb-ring-c"></div>
          <div class="orb-shimmer"></div>
        </div>
      </div>

      <!-- Live waveform (24 bars, heights driven by analyser) -->
      <div class="voice-waveform" id="voice-waveform" aria-hidden="true">
        <span></span><span></span><span></span><span></span><span></span><span></span>
        <span></span><span></span><span></span><span></span><span></span><span></span>
        <span></span><span></span><span></span><span></span><span></span><span></span>
        <span></span><span></span><span></span><span></span><span></span><span></span>
      </div>

      <div class="voice-transcript" id="voice-transcript">
        <span class="voice-transcript-placeholder">Go ahead, I'm listening…</span>
      </div>

      <div class="voice-controls">
        <button class="voice-ctrl-btn voice-ctrl-secondary" id="voice-restart-btn" title="Clear and restart">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-3.5-7.1"/><polyline points="21 3 21 9 15 9"/></svg>
        </button>
        <button class="voice-ctrl-btn voice-ctrl-primary" id="voice-mic-toggle" title="Pause / Resume">
          <svg class="vm-ico-mic" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="3" width="6" height="11" rx="3"></rect><path d="M5 11a7 7 0 0 0 14 0"></path><line x1="12" y1="18" x2="12" y2="22"></line><line x1="9" y1="22" x2="15" y2="22"></line></svg>
          <svg class="vm-ico-pause" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="display:none"><line x1="9" y1="5" x2="9" y2="19"/><line x1="15" y1="5" x2="15" y2="19"/></svg>
        </button>
        <button class="voice-ctrl-btn voice-ctrl-secondary" id="voice-done-btn" title="Send transcript">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
        </button>
      </div>
    </div>
  </div>

  <!-- Today's Coding stats now live INSIDE the pet widget (revealed by pet click) -->
  <div id="session-stats-card" style="display:none;" aria-hidden="true"></div>

  <!-- Language Breakdown (merged into main view) -->
  <div class="card" id="lang-card" style="display:none;">
    <div class="card-title ct-amber">Languages</div>
    <div class="lang-bar" id="lang-bar"></div>
    <div class="lang-legend" id="lang-legend"></div>
  </div>

  <!-- Skills -->
  <div class="card" id="skills-section" style="display:none;">
    <div class="card-title ct-violet">Skill Progress</div>
    <div id="skills-list"></div>
  </div>

  <!-- Activity Feed removed per redesign — keep hidden stub for JS refs below -->
  <div id="feed-section" style="display:none;">
    <div id="event-feed"></div>
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
      if (msg.type === 'lesson_feed') renderLessonFeed(msg.data.lessons);
      if (msg.type === 'lesson_new') prependLesson(msg.data);
      if (msg.type === 'companion_message') appendCompanionMessage(msg.data);
      if (msg.type === 'companion_clear') clearCompanionChat();
      if (msg.type === 'companion_watching') updateWatchingStatus(msg.data);
      if (msg.type === 'attachment_added') addAttachmentPreview(msg.data);
      if (msg.type === 'attachment_url_prompt') showUrlInput();

      // ───── Voice transcription status (from extension host) ─────
      if (msg.command === 'voiceTranscribing') {
        // Inline-recording mode: user pressed the mic button and then ✓ Done.
        // The composer capsule is handling the wait state — do NOT open the
        // full-screen voice-chat overlay (it would be a jarring mode switch).
        if (window.__pendingVoiceBubble) {
          // Intentionally do nothing — wait for voiceTranscriptDone to swap the
          // capsule back to the composer and render the voice bubble in-chat.
        } else {
          var overlayEl = document.getElementById('voice-overlay');
          var statusEl2 = document.getElementById('voice-status');
          var transcriptEl2 = document.getElementById('voice-transcript');
          if (overlayEl) overlayEl.classList.add('active', 'transcribing');
          if (statusEl2) statusEl2.textContent = 'Transcribing…';
          if (transcriptEl2) transcriptEl2.innerHTML = '<span class="voice-transcript-placeholder">Sending to Whisper…</span>';
        }
      }
      if (msg.command === 'voiceTranscriptDone') {
        // Two paths depending on mode:
        //  - Inline recording mode → render voice bubble in chat, restore composer
        //  - Voice chat mode → let __voiceChatOnPetReply handle the TTS step when reply arrives
        var pending = window.__pendingVoiceBubble;
        if (pending) {
          window.__pendingVoiceBubble = null;
          // Arm the suppression BEFORE the host's user-echo arrives
          if (msg.text && msg.text.trim()) {
            window.__suppressNextUserEcho = msg.text.trim();
          }
          renderVoiceBubble({
            transcript: msg.text || '',
            durationSec: pending.durationSec || 0,
            levels: pending.levels || []
          });
          // Restore composer and reset inline state
          var inputRow = document.getElementById('companion-input-row');
          if (inputRow) inputRow.classList.remove('recording');
          if (window.__voiceOverlay) window.__voiceOverlay.resetState();
        } else {
          // Voice chat mode — overlay stays open; TTS handler takes over
          // (the pet reply bubble will trigger __voiceChatOnPetReply from appendCompanionMessage)
        }
        var overlayEl2 = document.getElementById('voice-overlay');
        if (overlayEl2 && !overlayEl2.classList.contains('chat-mode')) {
          overlayEl2.classList.remove('active', 'transcribing', 'error');
        }
      }
      if (msg.command === 'ttsReady') {
        if (window.__voiceChatPlayTts) window.__voiceChatPlayTts(msg.audioDataUrl);
      }
      if (msg.command === 'ttsError') {
        console.warn('[Codepet voice] TTS error:', msg.message);
        // Fall back to listening again without speaking
        if (window.__voiceChatOnPetReply) window.__voiceChatOnPetReply('');
      }
      if (msg.command === 'nativeRecordStarted') {
        if (window.__voiceOverlay) window.__voiceOverlay.confirmStarted(msg.tool);
      }
      if (msg.command === 'voiceLevel') {
        if (window.__voiceOverlay) window.__voiceOverlay.applyLevel(msg.level);
      }
      if (msg.command === 'voiceTranscriptError') {
        // If this was an inline recording, don't open the voice-chat overlay.
        // Just clean up the capsule state and let the user try again.
        var wasInline = !!window.__pendingVoiceBubble;
        if (wasInline) {
          window.__pendingVoiceBubble = null;
          var inputRowErr = document.getElementById('companion-input-row');
          if (inputRowErr) inputRowErr.classList.remove('recording');
          if (window.__voiceOverlay) window.__voiceOverlay.resetState();
          // Surface the error quietly via a pet message in the chat (host will also log)
          console.warn('[Codepet voice] Inline transcription error:', msg.message || 'unknown');
          return;
        }
        var overlayEl3 = document.getElementById('voice-overlay');
        var statusEl3 = document.getElementById('voice-status');
        var transcriptEl3 = document.getElementById('voice-transcript');
        if (window.__voiceOverlay) window.__voiceOverlay.resetState();
        if (overlayEl3) overlayEl3.classList.add('active', 'error');
        if (overlayEl3) overlayEl3.classList.remove('transcribing');
        var errMsg = String(msg.message || 'Transcription failed');
        if (statusEl3) statusEl3.textContent = errMsg;

        // Install hint when ffmpeg/sox is missing — show the exact brew command (persistent, don't auto-dismiss)
        if (msg.installHint && transcriptEl3) {
          transcriptEl3.innerHTML =
            '<div style="font-size:12px;color:#E6DEFF;margin-bottom:8px;">' +
              'Install a recorder with Homebrew (one-time):' +
            '</div>' +
            '<code style="display:block;padding:8px 12px;border-radius:8px;margin-bottom:8px;' +
              'background:rgba(0,0,0,0.45);border:1px solid rgba(168,155,242,0.35);' +
              'color:#C8BDFF;font-family:var(--vscode-editor-font-family);font-size:11px;' +
              'cursor:pointer;user-select:all;" ' +
              'title="Click to copy" id="voice-copy-brew">' +
              'brew install ffmpeg' +
            '</code>' +
            '<div style="font-size:10px;color:#8F8BAC;">After installing, reload the Cursor window and try again.</div>';
          var cb = document.getElementById('voice-copy-brew');
          if (cb) cb.addEventListener('click', function() {
            try { navigator.clipboard.writeText('brew install ffmpeg'); cb.textContent = 'Copied ✓'; setTimeout(function(){ cb.textContent = 'brew install ffmpeg'; }, 1200); } catch(e){}
          });
          // Don't auto-dismiss the install hint — user needs time to read it
          return;
        }
        // Missing STT key → actionable button (accepts any provider phrasing)
        else if (/No STT key|No OpenAI key|No Deepgram key|No ElevenLabs key/i.test(errMsg) && transcriptEl3) {
          transcriptEl3.innerHTML =
            '<div style="display:flex;gap:6px;flex-wrap:wrap;justify-content:center;">' +
              '<button data-cpkey="codepet.setElevenLabsKey" class="voice-key-btn">Set ElevenLabs</button>' +
              '<button data-cpkey="codepet.setDeepgramKey" class="voice-key-btn">Set Deepgram</button>' +
              '<button data-cpkey="codepet.setOpenAIKey" class="voice-key-btn">Set OpenAI</button>' +
            '</div>' +
            '<style>.voice-key-btn{' +
              'padding:6px 10px;border-radius:999px;font-size:11px;font-weight:600;' +
              'background:linear-gradient(135deg,#A89BF2,#7B6BD8);color:#fff;' +
              'border:1px solid rgba(200,189,255,0.4);cursor:pointer;}</style>';
          var btns = transcriptEl3.querySelectorAll('button[data-cpkey]');
          btns.forEach(function(b) {
            b.addEventListener('click', function() {
              vscode.postMessage({ command: 'runCommand', commandId: b.getAttribute('data-cpkey') });
              if (overlayEl3) overlayEl3.classList.remove('active', 'error');
            });
          });
        } else {
          if (transcriptEl3) transcriptEl3.innerHTML = '';
          setTimeout(function() {
            if (overlayEl3) overlayEl3.classList.remove('active', 'error');
          }, 3500);
        }
      }
    });

    // ───── Attachment system ─────
    var pendingAttachments = [];

    function addAttachmentPreview(data) {
      var preview = document.getElementById('companion-attach-preview');
      if (!preview) return;
      preview.classList.add('visible');

      var iconMap = { file: '📎', image: '📷', url: '🔗', knowledge: '📄' };
      var icon = iconMap[data.type] || '📎';
      var id = data.id || ('attach_' + Date.now());

      pendingAttachments.push({ id: id, type: data.type, name: data.name, pinned: false });

      var item = document.createElement('div');
      item.className = 'companion-attach-item';
      item.dataset.attachId = id;
      item.innerHTML = '<div class="companion-attach-item-info">'
        + '<span>' + icon + '</span>'
        + '<span class="companion-attach-item-name" title="' + escapeHtml(data.name) + '">' + escapeHtml(data.name) + '</span>'
        + '</div>'
        + '<div class="companion-attach-item-actions">'
        + '<button class="companion-attach-pin" data-attach-id="' + id + '" title="Pin as project context">📌</button>'
        + '<button class="companion-attach-remove" data-attach-id="' + id + '" title="Remove">×</button>'
        + '</div>';
      preview.appendChild(item);
    }

    function showUrlInput() {
      var input = document.getElementById('companion-input');
      if (input) {
        input.placeholder = 'Paste a URL and press Enter...';
        input.focus();
        input.dataset.urlMode = 'true';
      }
    }

    // ───── Signal that the webview is ready to receive messages ─────
    // This triggers a fresh data push from the extension side, ensuring
    // scan results aren't lost due to early postMessage calls.
    vscode.postMessage({ command: 'webviewReady' });

    // ───── Force chat input to bottom of companion section ─────
    (function() {
      var section = document.getElementById('companion-section');
      var inputRow = document.getElementById('companion-input-row');
      if (section && inputRow) {
        section.appendChild(inputRow); // move to end of parent
      }
    })();

    // ───── Welcome Banner — auto-dismiss after 1s, animated exit on X click ─────
    function dismissWelcome() {
      const banner = document.getElementById('welcome-banner');
      if (!banner || banner.dataset.dismissing === 'true') return;
      banner.dataset.dismissing = 'true';
      // Smooth exit animation: fade + slide up + slight scale-down
      banner.style.transition = 'opacity 0.4s cubic-bezier(0.4, 0, 0.2, 1), transform 0.4s cubic-bezier(0.4, 0, 0.2, 1), margin 0.4s cubic-bezier(0.4, 0, 0.2, 1), max-height 0.4s cubic-bezier(0.4, 0, 0.2, 1)';
      banner.style.maxHeight = banner.offsetHeight + 'px';
      // Force reflow so the initial max-height is picked up before we animate to 0
      void banner.offsetHeight;
      banner.style.opacity = '0';
      banner.style.transform = 'translateY(-12px) scale(0.96)';
      banner.style.maxHeight = '0';
      banner.style.marginBottom = '0';
      banner.style.paddingTop = '0';
      banner.style.paddingBottom = '0';
      setTimeout(() => { banner.style.display = 'none'; }, 420);
    }

    // Auto-dismiss welcome banner after 1s (feels like a brief greeting flash)
    const initBanner = document.getElementById('welcome-banner');
    if (initBanner && initBanner.style.display !== 'none') {
      setTimeout(() => { dismissWelcome(); }, 1000);
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

      // ───── Companion watching status (piggybacks on updateUI) ─────
      if (d.companionWatching) {
        updateWatchingStatus({ active: true, message: d.companionWatching });
      }

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

      if (action === 'focusCompanion') {
        dismissWelcome();
        var ci = document.getElementById('companion-input');
        if (ci) { ci.focus(); ci.scrollIntoView({ behavior: 'smooth', block: 'center' }); }
        return;
      }

      if (action === 'refresh') {
        vscode.postMessage({ command: 'refresh' });
        return;
      }

      if (action === 'saveLesson') {
        e.stopPropagation();
        vscode.postMessage({ command: 'saveLesson' });
        return;
      }

      if (action === 'sendCompanion') {
        e.stopPropagation();
        sendCompanionMessage();
        return;
      }

      // ── Attachment buttons ──
      var attachType = target.dataset ? target.dataset.attach : null;
      if (attachType) {
        e.stopPropagation();
        vscode.postMessage({ command: 'attachRequest', type: attachType });
        return;
      }

      // ── Attachment pin/unpin ──
      if (target.classList && target.classList.contains('companion-attach-pin')) {
        e.stopPropagation();
        var attachId = target.dataset.attachId;
        var isPinned = target.classList.contains('pinned');
        target.classList.toggle('pinned');
        target.textContent = isPinned ? '📌' : '📌';
        target.title = isPinned ? 'Pin as project context' : 'Pinned as project context';
        vscode.postMessage({ command: 'attachTogglePin', attachId: attachId, pinned: !isPinned });
        return;
      }

      // ── Attachment remove ──
      if (target.classList && target.classList.contains('companion-attach-remove')) {
        e.stopPropagation();
        var removeId = target.dataset.attachId;
        var item = target.closest('.companion-attach-item');
        if (item) { item.remove(); }
        var preview = document.getElementById('companion-attach-preview');
        if (preview && preview.children.length === 0) { preview.classList.remove('visible'); }
        vscode.postMessage({ command: 'attachRemove', attachId: removeId });
        return;
      }

      if (action === 'clearCompanion') {
        e.stopPropagation();
        vscode.postMessage({ command: 'clearCompanion' });
        const container = document.getElementById('companion-messages');
        if (container) container.innerHTML = '<div class="companion-empty">Ask me anything about your code!<br>Try: "Summarize my session" or "How should I build this?"</div>';
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

    // ───── Lesson Feed Rendering ─────
    const KINGDOM_ICONS = {
      'The Molten Forge': '🔥', 'The Frozen Spire': '🏔️',
      'The Eternal Garden': '🌿', 'The Mystic Grove': '🔮',
    };
    const REACTION_EMOJIS = {
      excited: '🤩', proud: '😊', thinking: '🤔', sleepy: '😴',
      happy: '😄', curious: '🧐', dreamy: '💭', confused: '😵‍💫',
      serene: '🧘', contemplating: '📿', meditating: '🕊️',
      hyped: '🔥', scheming: '👾', bored: '😒',
      nod: '👍', idle: '💤', smirking: '😏',
      glitching: '⚡', sleeping: '😴',
    };

    let lessonCards = [];

    var currentSwipeIndex = 0;

    function renderLessonFeed(lessons) {
      lessonCards = lessons || [];
      var track = document.getElementById('lesson-swipe-track');
      var dots = document.getElementById('lesson-swipe-dots');
      var emptyEl = document.getElementById('lesson-feed-empty');
      var countEl = document.getElementById('lesson-count');
      var container = document.getElementById('lesson-swipe-container');
      if (!track) return;

      if (lessonCards.length === 0) {
        track.innerHTML = '';
        if (dots) dots.innerHTML = '';
        if (emptyEl) emptyEl.style.display = '';
        if (container) container.style.display = 'none';
        if (countEl) countEl.textContent = '';
        return;
      }

      if (emptyEl) emptyEl.style.display = 'none';
      if (container) container.style.display = '';
      if (countEl) countEl.textContent = lessonCards.length + ' lesson' + (lessonCards.length !== 1 ? 's' : '');

      var maxCards = Math.min(lessonCards.length, 10);
      track.innerHTML = '';
      for (var i = 0; i < maxCards; i++) {
        track.innerHTML += renderLessonCard(lessonCards[i]);
      }

      // Render dot indicators — only show if there's more than one card to swipe between
      if (dots) {
        dots.innerHTML = '';
        if (maxCards <= 1) {
          dots.style.display = 'none';
        } else {
          dots.style.display = '';
        }
        for (var d = 0; d < maxCards; d++) {
          var dot = document.createElement('div');
          dot.className = 'lesson-swipe-dot' + (d === 0 ? ' active' : '');
          dot.dataset.index = d;
          dot.addEventListener('click', function(e) {
            swipeToCard(parseInt(e.target.dataset.index));
          });
          dots.appendChild(dot);
        }
      }

      currentSwipeIndex = 0;
      updateSwipePosition(false);
      initSwipeGestures();
    }

    function swipeToCard(index) {
      var track = document.getElementById('lesson-swipe-track');
      if (!track) return;
      var total = track.children.length;
      if (index < 0) index = 0;
      if (index >= total) index = total - 1;
      currentSwipeIndex = index;
      updateSwipePosition(true);
    }

    function updateSwipePosition(animate) {
      var track = document.getElementById('lesson-swipe-track');
      var dots = document.querySelectorAll('.lesson-swipe-dot');
      if (!track) return;
      if (!animate) track.classList.add('dragging');
      else track.classList.remove('dragging');
      track.style.transform = 'translateX(-' + (currentSwipeIndex * 100) + '%)';
      if (!animate) {
        requestAnimationFrame(function() { track.classList.remove('dragging'); });
      }
      // Update dots
      for (var i = 0; i < dots.length; i++) {
        dots[i].classList.toggle('active', i === currentSwipeIndex);
      }
    }

    function initSwipeGestures() {
      var container = document.getElementById('lesson-swipe-container');
      var track = document.getElementById('lesson-swipe-track');
      if (!container || !track || container.dataset.swipeInit === '1') return;
      container.dataset.swipeInit = '1';

      var startX = 0, startY = 0, diffX = 0, isDragging = false, isHorizontal = null;

      // ── Trackpad / mouse wheel (main input on macOS) ──
      var wheelAccum = 0;
      var wheelTimer = null;
      var wheelLocked = false;

      container.addEventListener('wheel', function(e) {
        // Use deltaX for horizontal swipe; fall back to deltaY if no horizontal movement
        var dx = Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY;
        if (dx === 0) return;

        e.preventDefault();
        e.stopPropagation();

        // Debounce: accumulate scroll, then fire once settled
        if (wheelLocked) return;
        wheelAccum += dx;

        if (wheelTimer) clearTimeout(wheelTimer);
        wheelTimer = setTimeout(function() {
          if (Math.abs(wheelAccum) > 30) {
            wheelLocked = true;
            if (wheelAccum > 0) {
              swipeToCard(currentSwipeIndex + 1);
            } else {
              swipeToCard(currentSwipeIndex - 1);
            }
            // Prevent rapid multi-swipe — lock for 400ms
            setTimeout(function() { wheelLocked = false; }, 400);
          }
          wheelAccum = 0;
          wheelTimer = null;
        }, 80);
      }, { passive: false });

      // ── Touch events (mobile / touchscreen) ──
      container.addEventListener('touchstart', function(e) {
        startX = e.touches[0].clientX;
        startY = e.touches[0].clientY;
        diffX = 0;
        isDragging = true;
        isHorizontal = null;
        track.classList.add('dragging');
      }, { passive: true });

      container.addEventListener('touchmove', function(e) {
        if (!isDragging) return;
        var dx = e.touches[0].clientX - startX;
        var dy = e.touches[0].clientY - startY;
        if (isHorizontal === null) {
          isHorizontal = Math.abs(dx) > Math.abs(dy);
        }
        if (!isHorizontal) return;
        e.preventDefault();
        diffX = dx;
        var baseOffset = currentSwipeIndex * container.offsetWidth;
        track.style.transform = 'translateX(' + (-baseOffset + diffX) + 'px)';
      }, { passive: false });

      container.addEventListener('touchend', function() {
        if (!isDragging) return;
        isDragging = false;
        track.classList.remove('dragging');
        var threshold = container.offsetWidth * 0.25;
        if (diffX < -threshold) swipeToCard(currentSwipeIndex + 1);
        else if (diffX > threshold) swipeToCard(currentSwipeIndex - 1);
        else updateSwipePosition(true);
      }, { passive: true });

      // ── Mouse click-drag (fallback) ──
      container.addEventListener('mousedown', function(e) {
        startX = e.clientX;
        diffX = 0;
        isDragging = true;
        isHorizontal = true;
        track.classList.add('dragging');
        e.preventDefault();
      });

      document.addEventListener('mousemove', function(e) {
        if (!isDragging) return;
        diffX = e.clientX - startX;
        var baseOffset = currentSwipeIndex * container.offsetWidth;
        track.style.transform = 'translateX(' + (-baseOffset + diffX) + 'px)';
      });

      document.addEventListener('mouseup', function() {
        if (!isDragging) return;
        isDragging = false;
        track.classList.remove('dragging');
        var threshold = container.offsetWidth * 0.25;
        if (diffX < -threshold) swipeToCard(currentSwipeIndex + 1);
        else if (diffX > threshold) swipeToCard(currentSwipeIndex - 1);
        else updateSwipePosition(true);
      });

      // ── Keyboard arrows (accessibility) ──
      container.setAttribute('tabindex', '0');
      container.addEventListener('keydown', function(e) {
        if (e.key === 'ArrowRight') { swipeToCard(currentSwipeIndex + 1); e.preventDefault(); }
        if (e.key === 'ArrowLeft') { swipeToCard(currentSwipeIndex - 1); e.preventDefault(); }
      });
    }

    function prependLesson(card) {
      lessonCards.unshift(card);
      if (lessonCards.length > 20) lessonCards.pop();
      renderLessonFeed(lessonCards);
      // Flash the new card border
      var track = document.getElementById('lesson-swipe-track');
      if (track && track.firstElementChild) {
        track.firstElementChild.style.borderColor = '#7B6BD8';
        setTimeout(function() {
          track.firstElementChild.style.borderColor = '';
          track.firstElementChild.style.transition = 'border-color 0.5s';
        }, 2000);
      }
    }

    function renderLessonCard(card) {
      var html = '<div class="lesson-card">';

      // Date label (if present)
      if (card.dateLabel) {
        html += '<div class="lesson-date-label">' + escapeHtml(card.dateLabel) + '</div>';
      }

      // Card type badge
      if (card.cardType) {
        var badgeText = card.cardType === 'daily-recap' ? '📋 Daily Recap' : '⚡ Session';
        html += '<span class="lesson-type-badge ' + card.cardType + '">' + badgeText + '</span>';
      }

      // Title
      html += '<div class="lesson-title">' + escapeHtml(card.title) + '</div>';

      // Product-thinking sections (new format)
      if (card.sections && card.sections.length > 0) {
        for (var s = 0; s < card.sections.length; s++) {
          html += '<div class="lesson-section">';
          html += '<div class="lesson-section-heading">' + escapeHtml(card.sections[s].heading) + '</div>';
          html += '<div class="lesson-section-text">' + escapeHtml(card.sections[s].text) + '</div>';
          html += '</div>';
        }
      } else {
        // Fallback: legacy card format
        if (card.keyTakeaway) {
          html += '<div class="lesson-takeaway">' + escapeHtml(card.keyTakeaway) + '</div>';
        }
        if (card.codeSnippet) {
          html += '<div class="lesson-snippet-lang">' + (card.language || '') + '</div>';
          html += '<div class="lesson-snippet">' + escapeHtml(card.codeSnippet) + '</div>';
        }
      }

      // Pet section (if present)
      if (card.petNarration) {
        var reactionEmoji = REACTION_EMOJIS[card.petReaction] || '😊';
        html += '<div class="lesson-pet-section">';
        html += '<div class="lesson-pet-narration">';
        html += '<span class="lesson-pet-reaction">' + reactionEmoji + '</span>';
        html += escapeHtml(card.petNarration);
        html += '</div>';
        if (card.petCoachTip) {
          html += '<div class="lesson-coach-tip">💡 ' + escapeHtml(card.petCoachTip) + '</div>';
        }
        html += '</div>';
      }

      // Footer
      html += '<div class="lesson-footer">';
      html += '<span class="lesson-xp">+' + (card.xpEarned || 0) + ' XP</span>';
      if (card.skillTags && card.skillTags.length > 0) {
        html += '<div class="lesson-tags">';
        for (var t = 0; t < Math.min(card.skillTags.length, 3); t++) {
          html += '<span class="lesson-tag">#' + card.skillTags[t] + '</span>';
        }
        html += '</div>';
      }
      html += '</div>';

      html += '</div>';
      return html;
    }

    // ───── Companion Chat ─────
    function sendCompanionMessage() {
      const input = document.getElementById('companion-input');
      if (!input) return;
      const text = input.value.trim();
      if (!text) return;

      // Check if in URL mode
      if (input.dataset.urlMode === 'true') {
        input.dataset.urlMode = '';
        input.placeholder = 'Ask Codepet anything...';
        if (text.match(/^https?:\\/\\//)) {
          vscode.postMessage({ command: 'attachUrl', url: text });
          input.value = '';
          input.style.height = 'auto';
          return;
        }
      }

      input.value = '';
      input.style.height = 'auto';
      // Reset mic ↔ send state (input is empty now)
      var _inputRow = document.getElementById('companion-input-row');
      if (_inputRow) _inputRow.classList.remove('has-text');

      // Include any pending attachments with the message
      var attachments = pendingAttachments.slice();
      pendingAttachments = [];
      var preview = document.getElementById('companion-attach-preview');
      if (preview) { preview.innerHTML = ''; preview.classList.remove('visible'); }

      vscode.postMessage({ command: 'companionMessage', text: text, attachments: attachments });
    }

    // Enter to send (Shift+Enter for newline)
    const companionInput = document.getElementById('companion-input');
    if (companionInput) {
      companionInput.addEventListener('keydown', function(e) {
        // IME guard — don't submit while composing (Vietnamese/Chinese/Japanese/Korean IMEs).
        // During composition, Enter confirms the candidate character, it is NOT a submit.
        if (e.isComposing || e.keyCode === 229) return;
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          sendCompanionMessage();
        }
      });
      // Auto-resize textarea + character counter + mic/send slot swap
      var charCount = document.getElementById('companion-char-count');
      var inputRow = document.getElementById('companion-input-row');
      function updateMicSendState() {
        if (!inputRow) return;
        var hasText = companionInput.value.trim().length > 0;
        inputRow.classList.toggle('has-text', hasText);
      }
      companionInput.addEventListener('input', function() {
        this.style.height = 'auto';
        this.style.height = Math.min(this.scrollHeight, 80) + 'px';
        // Swap mic ↔ send based on whether there's text
        updateMicSendState();
        // Update character counter
        if (charCount) {
          var len = this.value.length;
          var max = 500;
          if (len > max * 0.7) {
            charCount.style.display = 'block';
            charCount.textContent = len + '/' + max;
            charCount.className = 'companion-char-count' + (len >= max ? ' at-limit' : len > max * 0.85 ? ' near-limit' : '');
          } else {
            charCount.style.display = 'none';
          }
        }
      });
      // Also reset to mic after sending (input gets cleared externally)
      // Observe value changes by polling on blur/focus for safety
      companionInput.addEventListener('blur', updateMicSendState);
      companionInput.addEventListener('focus', updateMicSendState);
      // Initial state
      updateMicSendState();
    }

    // ───── Ask Codepet header: click to expand/collapse the chat ─────
    (function() {
      var header = document.getElementById('companion-header');
      var section = document.getElementById('companion-section');
      var messages = document.getElementById('companion-messages');
      if (!header || !section) return;

      /**
       * Dynamically size the expanded chat to fit EXACTLY in the space between
       * the bottom of the Lesson Feed card and the bottom of the sidebar viewport.
       * This guarantees no overlap with the lesson feed regardless of viewport height.
       */
      function sizeChatToAvailableSpace() {
        if (!section.classList.contains('expanded')) {
          section.style.maxHeight = '';
          if (messages) messages.style.maxHeight = '';
          return;
        }
        // Compute the space between the lesson card bottom and the sidebar bottom,
        // and size the chat to fit WITHIN that space — never covering the lesson card.
        var viewportH = window.innerHeight;
        var lessonBottom = 0;
        var lessonCard = document.querySelector('.lesson-card');
        var lessonFeed = document.getElementById('lesson-feed-section');
        if (lessonCard) {
          lessonBottom = lessonCard.getBoundingClientRect().bottom;
        } else if (lessonFeed) {
          lessonBottom = lessonFeed.getBoundingClientRect().bottom;
        } else {
          lessonBottom = viewportH * 0.5;
        }
        var topGap = 10;
        var bottomGap = 12;
        var available = viewportH - lessonBottom - topGap - bottomGap;
        // Clamp: min 200px for usability, max 320px to match template proportion.
        var height = Math.max(200, Math.min(320, available));
        section.style.maxHeight = height + 'px';
        if (messages) {
          messages.style.maxHeight = Math.max(80, height - 125) + 'px';
        }
      }

      function setExpanded(on) {
        if (on) {
          section.classList.add('expanded');
          header.setAttribute('aria-expanded', 'true');
          sizeChatToAvailableSpace();
          setTimeout(function() {
            if (messages) messages.scrollTop = messages.scrollHeight;
          }, 540);
        } else {
          section.classList.remove('expanded');
          header.setAttribute('aria-expanded', 'false');
          section.style.maxHeight = '';
          if (messages) messages.style.maxHeight = '';
        }
      }

      header.addEventListener('click', function(e) {
        if (e.target && e.target.closest && e.target.closest('.companion-clear-btn')) return;
        setExpanded(!section.classList.contains('expanded'));
      });
      header.addEventListener('keydown', function(e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          setExpanded(!section.classList.contains('expanded'));
        }
      });

      // Recompute size on resize / scroll (lesson feed's on-screen position changes)
      window.addEventListener('resize', sizeChatToAvailableSpace);
      window.addEventListener('scroll', sizeChatToAvailableSpace, { passive: true });
    })();

    // ───── Pet Avatar: tap to reveal today's coding stats (embedded in dashboard) ─────
    (function() {
      var petToggle = document.getElementById('pet-avatar-toggle');
      var petWidget = document.getElementById('pet-section');
      var statsWrap = document.getElementById('pet-widget-stats');
      var tapHint = document.getElementById('pet-tap-hint');
      if (!petToggle || !petWidget) return;
      function setRevealed(on) {
        if (on) {
          petWidget.classList.add('stats-shown');
          petToggle.setAttribute('aria-expanded', 'true');
          if (statsWrap) statsWrap.setAttribute('aria-hidden', 'false');
          if (tapHint) tapHint.textContent = 'Hide stats';
        } else {
          petWidget.classList.remove('stats-shown');
          petToggle.setAttribute('aria-expanded', 'false');
          if (statsWrap) statsWrap.setAttribute('aria-hidden', 'true');
          if (tapHint) tapHint.textContent = 'Tap for stats';
        }
      }
      petToggle.addEventListener('click', function(e) {
        e.stopPropagation();
        setRevealed(!petWidget.classList.contains('stats-shown'));
      });
      petToggle.addEventListener('keydown', function(e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          setRevealed(!petWidget.classList.contains('stats-shown'));
        }
      });
    })();

    // ───── + Button: toggle attach menu ─────
    var plusBtn = document.getElementById('companion-plus-btn');
    var attachMenu = document.getElementById('companion-attach-menu');
    if (plusBtn && attachMenu) {
      plusBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        attachMenu.classList.toggle('visible');
      });
      // Close menu when clicking outside
      document.addEventListener('click', function(e) {
        if (attachMenu && !attachMenu.contains(e.target) && e.target !== plusBtn) {
          attachMenu.classList.remove('visible');
        }
      });
      // Handle menu item clicks
      attachMenu.addEventListener('click', function(e) {
        var item = e.target.closest('.companion-attach-menu-item');
        if (item && item.dataset.attach) {
          vscode.postMessage({ command: 'attachRequest', type: item.dataset.attach });
          attachMenu.classList.remove('visible');
        }
      });
    }

    // ═════════ Voice UX ═════════
    // Two modes:
    //   1) Inline recording — click mic → capsule in composer row, with live waveform.
    //      Send (✓) transcribes and creates a voice-message bubble in the chat.
    //      Cancel (✕) aborts cleanly.
    //   2) Voice chat — click the green chat button → full overlay.
    //      Continuous listen-speak loop with ElevenLabs TTS for Codepet's replies.
    //
    // Both modes share the same native recorder (ffmpeg/sox in Node) because
    // Cursor's webview iframe Permissions-Policy blocks direct microphone access.
    (function initVoice() {
      var micBtn    = document.getElementById('companion-mic-btn');
      var vcBtn     = document.getElementById('companion-vc-btn');
      var inputRow  = document.getElementById('companion-input-row');
      var capsule   = document.getElementById('voice-capsule');
      var vcTimer   = document.getElementById('vc-timer');
      var vcWave    = document.getElementById('vc-wave');
      var vcCancel  = document.getElementById('vc-cancel');
      var vcSend    = document.getElementById('vc-send');

      // Overlay (for voice chat mode only)
      var overlay       = document.getElementById('voice-overlay');
      var statusEl      = document.getElementById('voice-status');
      var orbEl         = document.getElementById('voice-orb');
      var transcriptEl  = document.getElementById('voice-transcript');
      var cancelBtn     = document.getElementById('voice-cancel-btn');
      var restartBtn    = document.getElementById('voice-restart-btn');
      var doneBtn       = document.getElementById('voice-done-btn');
      var toggleBtn     = document.getElementById('voice-mic-toggle');
      var waveformEl    = document.getElementById('voice-waveform');

      // Shared state
      var mode = 'idle'; // 'idle' | 'inline' | 'chat-listen' | 'chat-transcribing' | 'chat-speaking'
      var isRecording = false;
      var timerInterval = 0;
      var recordStartedAt = 0;
      var levelHistory = []; // captured levels for the voice bubble waveform
      var ttsAudio = null;

      // ── Helpers ──
      function formatTime(sec) {
        var s = Math.max(0, Math.floor(sec));
        var m = Math.floor(s / 60);
        var ss = s % 60;
        return m + ':' + (ss < 10 ? '0' + ss : ss);
      }

      function startTimer() {
        recordStartedAt = Date.now();
        if (vcTimer) vcTimer.textContent = '0:00';
        if (statusEl) statusEl.dataset.elapsed = '0';
        if (timerInterval) clearInterval(timerInterval);
        timerInterval = setInterval(function() {
          var elapsed = (Date.now() - recordStartedAt) / 1000;
          if (vcTimer && mode === 'inline') vcTimer.textContent = formatTime(elapsed);
        }, 250);
      }
      function stopTimer() {
        if (timerInterval) { clearInterval(timerInterval); timerInterval = 0; }
      }

      // ── Inline capsule waveform (scrolls from right) ──
      var inlineHistory = null;
      function ensureInlineHistory() {
        var bars = vcWave ? vcWave.querySelectorAll('span') : [];
        if (!bars.length) return;
        if (!inlineHistory || inlineHistory.length !== bars.length) {
          inlineHistory = new Array(bars.length).fill(0);
        }
      }
      function applyInlineLevel(level) {
        if (!vcWave) return;
        ensureInlineHistory();
        if (!inlineHistory) return;
        inlineHistory.shift();
        inlineHistory.push(level);
        var bars = vcWave.querySelectorAll('span');
        for (var i = 0; i < bars.length; i++) {
          var v = inlineHistory[i];
          bars[i].style.height = (10 + v * 82).toFixed(0) + '%';
        }
      }
      function resetInlineWave() {
        inlineHistory = null;
        if (!vcWave) return;
        var bars = vcWave.querySelectorAll('span');
        for (var i = 0; i < bars.length; i++) bars[i].style.height = '';
      }

      // ── Overlay waveform / orb (voice chat mode) ──
      var overlayHistory = null;
      function applyOverlayLevel(level) {
        if (orbEl) orbEl.style.setProperty('--orb-scale', (1 + level * 0.38).toFixed(3));
        if (toggleBtn) {
          var glow1 = 3 + level * 18;
          var glow2 = 14 + level * 34;
          var glowA = 0.15 + level * 0.65;
          toggleBtn.style.setProperty('--mic-scale', (1 + level * 0.22).toFixed(3));
          toggleBtn.style.setProperty('--mic-glow',
            '0 0 0 ' + glow1.toFixed(1) + 'px rgba(168, 155, 242, ' + glowA.toFixed(2) + '), ' +
            '0 0 ' + glow2.toFixed(0) + 'px 6px rgba(168, 155, 242, ' + (glowA * 0.7).toFixed(2) + '), ' +
            '0 10px 26px -8px rgba(83, 74, 183, ' + (0.45 + level * 0.4).toFixed(2) + ')'
          );
        }
        if (waveformEl) {
          waveformEl.classList.add('active');
          var bars = waveformEl.querySelectorAll('span');
          if (!overlayHistory || overlayHistory.length !== bars.length) {
            overlayHistory = new Array(bars.length).fill(0);
          }
          overlayHistory.shift();
          overlayHistory.push(level);
          for (var i = 0; i < bars.length; i++) {
            var v = overlayHistory[i];
            bars[i].style.height = (8 + v * 85).toFixed(0) + '%';
          }
        }
      }
      function resetOverlayVisuals() {
        overlayHistory = null;
        if (waveformEl) {
          waveformEl.classList.remove('active');
          var bars = waveformEl.querySelectorAll('span');
          for (var i = 0; i < bars.length; i++) bars[i].style.height = '';
        }
        if (toggleBtn) {
          toggleBtn.style.removeProperty('--mic-scale');
          toggleBtn.style.removeProperty('--mic-glow');
        }
        if (orbEl) orbEl.style.removeProperty('--orb-scale');
      }

      // Expose hooks for outer window message listener (existing code dispatches here)
      window.__voiceOverlay = {
        confirmStarted: function(tool) {
          isRecording = true;
          if (mode === 'inline') {
            if (inputRow) inputRow.classList.add('recording');
          } else if (mode === 'chat-listen') {
            if (statusEl) statusEl.innerHTML = 'Listening<span class="voice-ellipsis"><span>.</span><span>.</span><span>.</span></span>';
          }
          startTimer();
        },
        applyLevel: function(level) {
          if (!isRecording) return;
          var v = Math.max(0, Math.min(1, level || 0));
          levelHistory.push(v);
          if (mode === 'inline') applyInlineLevel(v);
          else if (mode === 'chat-listen') applyOverlayLevel(v);
        },
        freezeForTranscribing: function() {
          isRecording = false;
          stopTimer();
        },
        resetState: function() {
          isRecording = false;
          stopTimer();
          resetInlineWave();
          resetOverlayVisuals();
          if (inputRow) inputRow.classList.remove('recording');
          mode = 'idle';
        }
      };

      // ── Inline recording flow (primary mic button) ──
      function startInlineRecording() {
        if (mode !== 'idle') return;
        mode = 'inline';
        levelHistory = [];
        resetInlineWave();
        vscode.postMessage({ command: 'nativeRecordStart' });
      }
      function cancelInlineRecording() {
        vscode.postMessage({ command: 'nativeRecordAbort' });
        if (window.__voiceOverlay) window.__voiceOverlay.resetState();
      }
      function sendInlineRecording() {
        if (!isRecording) return;
        if (window.__voiceOverlay) window.__voiceOverlay.freezeForTranscribing();
        // Keep capsule visible briefly with a "sending" look via keeping .recording on
        // (we'll restore when voiceTranscriptDone or voiceTranscriptError arrives)
        window.__pendingVoiceBubble = {
          durationSec: (Date.now() - recordStartedAt) / 1000,
          levels: levelHistory.slice()
        };
        vscode.postMessage({ command: 'nativeRecordStop' });
      }

      // ── Voice chat flow (second button) ──
      function openVoiceChat() {
        if (mode !== 'idle') return;
        if (!overlay) return;
        mode = 'chat-listen';
        levelHistory = [];
        overlay.classList.add('active', 'chat-mode');
        overlay.classList.remove('error', 'transcribing');
        overlay.setAttribute('aria-hidden', 'false');
        if (vcBtn) vcBtn.classList.add('active');
        if (statusEl) statusEl.innerHTML = 'Starting<span class="voice-ellipsis"><span>.</span><span>.</span><span>.</span></span>';
        if (transcriptEl) transcriptEl.innerHTML = '';
        vscode.postMessage({ command: 'nativeRecordStart' });
      }
      function closeVoiceChat() {
        stopTimer();
        if (isRecording) {
          vscode.postMessage({ command: 'nativeRecordAbort' });
        }
        if (ttsAudio) { try { ttsAudio.pause(); ttsAudio.src = ''; } catch(e){} ttsAudio = null; }
        resetOverlayVisuals();
        if (overlay) {
          overlay.classList.remove('active', 'error', 'transcribing', 'chat-mode');
          overlay.setAttribute('aria-hidden', 'true');
        }
        if (vcBtn) vcBtn.classList.remove('active');
        isRecording = false;
        mode = 'idle';
      }
      function chatFinishTurn() {
        // Stop listening → transcribe → send to Codepet → wait for reply → TTS → loop
        if (mode !== 'chat-listen' || !isRecording) return;
        mode = 'chat-transcribing';
        if (window.__voiceOverlay) window.__voiceOverlay.freezeForTranscribing();
        if (overlay) overlay.classList.add('transcribing');
        if (statusEl) statusEl.innerHTML = 'Transcribing<span class="voice-ellipsis"><span>.</span><span>.</span><span>.</span></span>';
        vscode.postMessage({ command: 'nativeRecordStop' });
      }
      // Called when Codepet's text reply arrives (from outer appendCompanionMessage hook)
      window.__voiceChatOnPetReply = function(text) {
        if (mode !== 'chat-transcribing' && mode !== 'chat-speaking') return;
        if (!text) { chatListenAgain(); return; }
        mode = 'chat-speaking';
        if (statusEl) statusEl.innerHTML = 'Codepet<span class="voice-ellipsis"><span>.</span><span>.</span><span>.</span></span>';
        vscode.postMessage({ command: 'ttsRequest', text: text, requestId: Date.now() });
      };
      window.__voiceChatPlayTts = function(audioDataUrl) {
        if (mode !== 'chat-speaking') return;
        try {
          if (ttsAudio) { try { ttsAudio.pause(); } catch(e){} }
          ttsAudio = new Audio(audioDataUrl);
          ttsAudio.onended = function() {
            if (mode === 'chat-speaking') chatListenAgain();
          };
          ttsAudio.onerror = function() {
            console.warn('[Codepet voice] TTS audio failed to play');
            if (mode === 'chat-speaking') chatListenAgain();
          };
          ttsAudio.play().catch(function(){ chatListenAgain(); });
        } catch(e) {
          console.error('[Codepet voice] TTS play exception:', e);
          chatListenAgain();
        }
      };
      function chatListenAgain() {
        if (mode === 'idle') return;
        mode = 'chat-listen';
        resetOverlayVisuals();
        if (overlay) overlay.classList.remove('transcribing');
        if (statusEl) statusEl.innerHTML = 'Listening<span class="voice-ellipsis"><span>.</span><span>.</span><span>.</span></span>';
        if (transcriptEl) transcriptEl.innerHTML = '';
        vscode.postMessage({ command: 'nativeRecordStart' });
      }

      // ── Wire up DOM events ──
      if (micBtn) {
        micBtn.addEventListener('click', function() {
          if (mode === 'inline') return;
          if (mode === 'idle') startInlineRecording();
        });
      }
      if (vcCancel) vcCancel.addEventListener('click', cancelInlineRecording);
      if (vcSend)   vcSend.addEventListener('click', sendInlineRecording);

      if (vcBtn) {
        vcBtn.addEventListener('click', function() {
          if (mode === 'idle') openVoiceChat();
          else if (mode.indexOf('chat') === 0) closeVoiceChat();
        });
      }
      if (cancelBtn)  cancelBtn.addEventListener('click', closeVoiceChat);
      if (doneBtn)    doneBtn.addEventListener('click', chatFinishTurn);
      if (toggleBtn)  toggleBtn.addEventListener('click', chatFinishTurn);
      if (restartBtn) restartBtn.addEventListener('click', function() {
        if (mode === 'chat-listen' && isRecording) {
          vscode.postMessage({ command: 'nativeRecordAbort' });
          levelHistory = [];
          setTimeout(function() { vscode.postMessage({ command: 'nativeRecordStart' }); }, 100);
        }
      });
      if (overlay) {
        overlay.addEventListener('click', function(e) {
          if (e.target === overlay && mode.indexOf('chat') === 0) closeVoiceChat();
        });
      }
    })();

    function appendCompanionMessage(data) {
      const container = document.getElementById('companion-messages');
      if (!container) return;

      // Suppress plain text echo when we've just rendered the same text as a voice bubble.
      // This prevents a voice bubble + a text bubble showing up for the same utterance.
      if (data && data.role === 'user' && window.__suppressNextUserEcho && data.text) {
        if (data.text.trim() === String(window.__suppressNextUserEcho).trim()) {
          window.__suppressNextUserEcho = null;
          return;
        }
      }

      // Remove empty state if present
      const empty = container.querySelector('.companion-empty');
      if (empty) empty.remove();

      // Remove any existing option buttons (previous question answered)
      var oldOptions = container.querySelectorAll('.companion-options');
      oldOptions.forEach(function(el) { el.remove(); });

      const div = document.createElement('div');
      div.className = 'companion-msg companion-msg-' + data.role;

      // Alternate pet bubbles through a 4-tint palette (lavender → peach → mint → pink)
      if (data.role === 'pet') {
        var petTints = ['tint-lavender', 'tint-peach', 'tint-mint', 'tint-pink'];
        var existingPetCount = container.querySelectorAll('.companion-msg-pet').length;
        div.classList.add(petTints[existingPetCount % petTints.length]);
      }

      if (data.role === 'pet') {
        // Parse simple markdown: **bold**, bullet points, line breaks
        let html = data.text
          .replace(/&/g, '&amp;')
          .replace(/</g, '&lt;')
          .replace(/>/g, '&gt;')
          .replace(/\\*\\*(.+?)\\*\\*/g, '<strong>$1</strong>')
          .replace(/^[•\\-] (.+)$/gm, '<li>$1</li>')
          .replace(/(<li>.*<\\/li>)/s, '<ul>$1</ul>')
          .replace(/\\n/g, '<br>');
        div.innerHTML = html;
      } else {
        div.textContent = data.text;
      }

      container.appendChild(div);

      // In voice-chat mode, whenever a pet reply lands, forward it to the TTS flow
      if (data.role === 'pet' && window.__voiceChatOnPetReply) {
        try { window.__voiceChatOnPetReply(data.text || ''); } catch (e) {}
      }

      // Render clickable option buttons if present
      if (data.options && data.options.length > 0) {
        var optionsDiv = document.createElement('div');
        optionsDiv.className = 'companion-options';

        data.options.forEach(function(opt) {
          var btn = document.createElement('button');
          btn.className = 'companion-option-btn';
          btn.textContent = opt;
          btn.addEventListener('click', function() {
            // Disable all option buttons to prevent double-click
            var allBtns = optionsDiv.querySelectorAll('.companion-option-btn');
            allBtns.forEach(function(b) { b.disabled = true; b.style.opacity = '0.5'; });
            vscode.postMessage({ command: 'companionMessage', text: opt });
          });
          optionsDiv.appendChild(btn);
        });

        // "Other" button for custom typing
        if (data.allowCustom) {
          var otherBtn = document.createElement('button');
          otherBtn.className = 'companion-option-btn companion-option-other';
          otherBtn.textContent = 'Other...';
          otherBtn.addEventListener('click', function() {
            var input = document.getElementById('companion-input');
            if (input) { input.focus(); input.placeholder = 'Type your answer...'; }
          });
          optionsDiv.appendChild(otherBtn);
        }

        container.appendChild(optionsDiv);
      }

      // Scroll after a tiny delay to ensure DOM has rendered
      setTimeout(function() {
        container.scrollTop = container.scrollHeight;
      }, 50);
    }

    /**
     * Render a voice-message bubble (user side).
     * { transcript, durationSec, levels: number[] (0..1) }
     * We don't embed the audio itself — showing an informative waveform + transcript
     * keeps bubble DOM light. The transcript is also sent to Codepet via
     * sendCompanionMessage so the chat continues normally.
     */
    function renderVoiceBubble(opts) {
      var container = document.getElementById('companion-messages');
      if (!container) return;
      var empty = container.querySelector('.companion-empty');
      if (empty) empty.remove();

      var wrap = document.createElement('div');
      wrap.className = 'companion-msg companion-msg-user companion-msg-voice';

      // Downsample levels to 32 bars for the static waveform
      var levels = Array.isArray(opts.levels) ? opts.levels : [];
      var targetBars = 32;
      var bars = [];
      if (levels.length === 0) {
        for (var i = 0; i < targetBars; i++) bars.push(0.1);
      } else if (levels.length <= targetBars) {
        // Pad with low values on the left if short
        var pad = targetBars - levels.length;
        for (var p = 0; p < pad; p++) bars.push(0.06);
        for (var j = 0; j < levels.length; j++) bars.push(Math.max(0, Math.min(1, levels[j])));
      } else {
        var step = levels.length / targetBars;
        for (var b = 0; b < targetBars; b++) {
          var s = Math.floor(b * step);
          var e = Math.floor((b + 1) * step);
          var peak = 0;
          for (var k = s; k < e; k++) if (levels[k] > peak) peak = levels[k];
          bars.push(peak);
        }
      }

      var waveHtml = '';
      for (var w = 0; w < bars.length; w++) {
        var h = Math.round(12 + bars[w] * 82); // 12..94%
        waveHtml += '<span style="height:' + h + '%"></span>';
      }

      var m = Math.floor((opts.durationSec || 0) / 60);
      var s = Math.floor((opts.durationSec || 0) % 60);
      var durText = m + ':' + (s < 10 ? '0' + s : s);

      wrap.innerHTML =
        '<div class="vb-player">' +
          '<button class="vb-play" aria-label="Play voice message (transcript only)" title="Voice messages show transcript only in this version" disabled>' +
            '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5v14l11-7z"/></svg>' +
          '</button>' +
          '<div class="vb-wave" aria-hidden="true">' + waveHtml + '</div>' +
          '<span class="vb-duration">' + durText + '</span>' +
        '</div>' +
        (opts.transcript ? ('<div class="vb-transcript">"' + escapeHtml(opts.transcript) + '"</div>') : '');

      container.appendChild(wrap);
      container.scrollTop = container.scrollHeight;
      // The host has already called onCompanionMessage(transcript) to trigger the
      // AI response, so we don't post companionMessage here. We only flag the
      // incoming user-echo to be suppressed (voice bubble replaces text bubble).
      if (opts.transcript && opts.transcript.trim()) {
        window.__suppressNextUserEcho = opts.transcript.trim();
      }
    }

    function clearCompanionChat() {
      const container = document.getElementById('companion-messages');
      if (container) {
        container.innerHTML = '<div class="companion-empty">Ask me anything about your code!<br>Try: "Summarize my session" or "How should I build this?"</div>';
      }
    }

    function updateWatchingStatus(data) {
      // Show watching status as an Activity Feed item instead of in the chat
      if (data.active && data.message) {
        const feed = document.getElementById('event-feed');
        if (!feed) return;

        // Remove previous watching item if exists
        const existing = feed.querySelector('.watching-item');
        if (existing) existing.remove();

        // Remove empty state
        const empty = feed.querySelector('.empty-state');
        if (empty) empty.remove();

        const now = new Date();
        const time = now.getHours().toString().padStart(2,'0') + ':' + now.getMinutes().toString().padStart(2,'0');

        const div = document.createElement('div');
        div.className = 'event-item watching-item';
        div.style.background = 'rgba(59, 130, 246, 0.06)';
        div.style.borderLeft = '2px solid #3b82f6';
        div.style.paddingLeft = '10px';
        div.innerHTML = '<span class="event-time">' + time + '</span>'
          + '<span class="event-type">👀 ' + data.message + '</span>';

        // Insert at top of feed
        feed.insertBefore(div, feed.firstChild);
      }
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
