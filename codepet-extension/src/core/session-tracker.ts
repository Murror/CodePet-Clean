/**
 * SessionTracker — Tracks editor-level coding activity
 *
 * Monitors VS Code/Cursor events to build a real-time picture of
 * what the user is doing. This supplements MCP server data with
 * editor-native signals that are faster and more granular.
 *
 * Tracks:
 *   - Document edits (language, file, line count)
 *   - File opens/closes
 *   - Active coding time vs. idle time
 *   - Session boundaries (start, pause, resume, end)
 *   - Git branch changes (via .git/HEAD watching)
 */

import * as vscode from "vscode";
import { join } from "node:path";
import { existsSync, readFileSync, watch as fsWatch, type FSWatcher } from "node:fs";

export interface SessionStats {
  startTime: Date;
  lastEditTime: Date;
  totalEdits: number;
  codingMinutes: number;
  filesEdited: Set<string>;
  languageBreakdown: Map<string, number>; // language → edit count
  linesAdded: number;
  linesRemoved: number;
  currentBranch: string | null;
  isIdle: boolean;
}

export class SessionTracker implements vscode.Disposable {
  private disposables: vscode.Disposable[] = [];
  private gitWatcher: FSWatcher | undefined;

  // Session state
  private _stats: SessionStats;
  private idleTimer: NodeJS.Timeout | undefined;
  private codingTimer: NodeJS.Timeout | undefined;
  private lastActiveMinute = 0;
  private activeSessionStart: Date | null = null; // when current active coding period began
  private storedMinutes = 0; // accumulated minutes from previous active periods

  // Events
  private _onIdle = new vscode.EventEmitter<SessionStats>();
  readonly onIdle = this._onIdle.event;

  private _onResume = new vscode.EventEmitter<void>();
  readonly onResume = this._onResume.event;

  private _onBranchChange = new vscode.EventEmitter<{ from: string | null; to: string }>();
  readonly onBranchChange = this._onBranchChange.event;

  private _onSessionUpdate = new vscode.EventEmitter<SessionStats>();
  readonly onSessionUpdate = this._onSessionUpdate.event;

  // Break reminder
  private _onBreakReminder = new vscode.EventEmitter<{ minutes: number; streak: number }>();
  readonly onBreakReminder = this._onBreakReminder.event;
  private lastBreakReminderAt = 0; // codingMinutes when last reminder fired
  private breakReminderCount = 0; // how many reminders sent this session

  get stats(): SessionStats { return this._stats; }

  /** Real-time coding minutes: stored + live elapsed active period */
  get liveCodingMinutes(): number {
    if (this.activeSessionStart) {
      const elapsed = (Date.now() - this.activeSessionStart.getTime()) / 60_000;
      return this.storedMinutes + elapsed;
    }
    return this.storedMinutes;
  }

  get codingTimeFormatted(): string {
    const totalMins = this.liveCodingMinutes;

    if (totalMins < 1 && totalMins > 0) {
      // Sub-minute: show seconds for instant feedback
      const secs = Math.floor(totalMins * 60);
      return `${secs}s`;
    }

    const mins = Math.floor(totalMins);
    if (mins >= 60) {
      const h = Math.floor(mins / 60);
      const m = mins % 60;
      return m > 0 ? `${h}h ${m}m` : `${h}h`;
    }
    return `${mins}m`;
  }

  get topLanguage(): string | null {
    let max = 0;
    let top: string | null = null;
    for (const [lang, count] of this._stats.languageBreakdown) {
      if (count > max) { max = count; top = lang; }
    }
    return top;
  }

  constructor() {
    const now = new Date();
    this._stats = {
      startTime: now,
      lastEditTime: now,
      totalEdits: 0,
      codingMinutes: 0,
      filesEdited: new Set(),
      languageBreakdown: new Map(),
      linesAdded: 0,
      linesRemoved: 0,
      currentBranch: null,
      isIdle: true,
    };

    this.setupEditorListeners();
    this.setupGitWatcher();
    this.startCodingTimer();
    this.detectCurrentBranch();
  }

  // ───── Editor event listeners ─────

  /**
   * Mark the session as active — starts the clock, resets idle timer.
   * Called by ALL activity signals (typing, clicking, scrolling, terminal, etc.)
   */
  private markActive(): void {
    const wasIdle = this._stats.isIdle;
    this._stats.isIdle = false;
    this._stats.lastEditTime = new Date();

    // Start the active session clock on first activity
    if (!this.activeSessionStart) {
      this.activeSessionStart = new Date();
    }

    this.resetIdleTimer();

    if (wasIdle) {
      this._onResume.fire();
      this._onSessionUpdate.fire(this._stats);
    }
  }

  private setupEditorListeners(): void {
    // ── Signal 1: Document text changes (typing / external edits) ──
    this.disposables.push(
      vscode.workspace.onDidChangeTextDocument((e) => {
        if (e.document.uri.scheme !== "file") return;

        this.markActive();
        this._stats.totalEdits++;

        // Track file
        this._stats.filesEdited.add(e.document.uri.fsPath);

        // Track language
        const lang = e.document.languageId;
        this._stats.languageBreakdown.set(
          lang,
          (this._stats.languageBreakdown.get(lang) ?? 0) + 1
        );

        // Track line changes
        for (const change of e.contentChanges) {
          const addedLines = change.text.split("\n").length - 1;
          const removedLines = change.range.end.line - change.range.start.line;
          this._stats.linesAdded += addedLines;
          this._stats.linesRemoved += removedLines;
        }

        this._onSessionUpdate.fire(this._stats);
      })
    );

    // ── Signal 2: Cursor movement / selection (reading code, clicking around) ──
    this.disposables.push(
      vscode.window.onDidChangeTextEditorSelection(() => {
        this.markActive();
      })
    );

    // ── Signal 3: Switching tabs / files ──
    this.disposables.push(
      vscode.window.onDidChangeActiveTextEditor(() => {
        this.markActive();
      })
    );

    // ── Signal 4: Scrolling through code ──
    this.disposables.push(
      vscode.window.onDidChangeTextEditorVisibleRanges(() => {
        this.markActive();
      })
    );

    // ── Signal 5: Terminal activity (using CLI tools, running builds, etc.) ──
    this.disposables.push(
      vscode.window.onDidChangeActiveTerminal(() => {
        this.markActive();
      })
    );
    this.disposables.push(
      vscode.window.onDidOpenTerminal(() => {
        this.markActive();
      })
    );

    // ── Signal 6: File open ──
    this.disposables.push(
      vscode.workspace.onDidOpenTextDocument((doc) => {
        if (doc.uri.scheme === "file") {
          this._stats.filesEdited.add(doc.uri.fsPath);
          this.markActive();
        }
      })
    );

    // ── Signal 7: Window focus ──
    this.disposables.push(
      vscode.window.onDidChangeWindowState((state) => {
        if (state.focused) {
          this.markActive();
        }
        // When losing focus, let the idle timer handle it naturally
      })
    );

    // ── Signal 8: Workspace folder changes (project switch) ──
    this.disposables.push(
      vscode.workspace.onDidChangeWorkspaceFolders(() => {
        this.markActive();
        this.detectCurrentBranch();
      })
    );
  }

  // ───── Idle detection ─────

  private resetIdleTimer(): void {
    if (this.idleTimer) clearTimeout(this.idleTimer);

    const config = vscode.workspace.getConfiguration("codepet");
    const idleMinutes = config.get<number>("idleTimeoutMinutes") ?? 5;

    this.idleTimer = setTimeout(() => {
      // Bank the active coding time before going idle
      if (this.activeSessionStart) {
        const elapsed = (Date.now() - this.activeSessionStart.getTime()) / 60_000;
        this.storedMinutes += elapsed;
        this._stats.codingMinutes = Math.floor(this.storedMinutes);
        this.activeSessionStart = null;
      }
      // Reset break reminder — they're taking a break naturally
      this.lastBreakReminderAt = Math.floor(this.storedMinutes);
      this._stats.isIdle = true;
      this._onIdle.fire(this._stats);
    }, idleMinutes * 60 * 1000);
  }

  // ───── Coding time tracking ─────

  private startCodingTimer(): void {
    // Sync codingMinutes with live elapsed time every 15 seconds
    // (keeps Firestore writes accurate + triggers UI refreshes)
    this.codingTimer = setInterval(() => {
      if (!this._stats.isIdle && this.activeSessionStart) {
        const prev = this._stats.codingMinutes;
        this._stats.codingMinutes = Math.floor(this.liveCodingMinutes);
        // Fire update so cloud sync and sidebar stay current
        if (this._stats.codingMinutes !== prev) {
          this._onSessionUpdate.fire(this._stats);
        }
        // Break reminder: every 60 minutes of continuous coding
        this.checkBreakReminder();
      }
    }, 15_000);
  }

  /** Check if it's time to nudge the user to take a break */
  private checkBreakReminder(): void {
    const config = vscode.workspace.getConfiguration("codepet");
    const intervalMinutes = config.get<number>("breakReminderMinutes") ?? 60;
    if (intervalMinutes <= 0) return; // disabled

    const currentMinutes = Math.floor(this.liveCodingMinutes);
    const minutesSinceLastReminder = currentMinutes - this.lastBreakReminderAt;

    if (minutesSinceLastReminder >= intervalMinutes) {
      this.breakReminderCount++;
      this.lastBreakReminderAt = currentMinutes;
      this._onBreakReminder.fire({
        minutes: currentMinutes,
        streak: this.breakReminderCount,
      });
    }
  }

  // ───── Git branch detection ─────

  private setupGitWatcher(): void {
    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders?.length) return;

    const gitHead = join(workspaceFolders[0].uri.fsPath, ".git", "HEAD");
    if (!existsSync(gitHead)) return;

    try {
      this.gitWatcher = fsWatch(gitHead, () => {
        const prevBranch = this._stats.currentBranch;
        this.detectCurrentBranch();
        if (this._stats.currentBranch && prevBranch !== this._stats.currentBranch) {
          this._onBranchChange.fire({
            from: prevBranch,
            to: this._stats.currentBranch,
          });
        }
      });
    } catch {
      // Not a git repo
    }
  }

  private detectCurrentBranch(): void {
    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders?.length) return;

    const gitHead = join(workspaceFolders[0].uri.fsPath, ".git", "HEAD");
    if (!existsSync(gitHead)) return;

    try {
      const content = readFileSync(gitHead, "utf-8").trim();
      const match = content.match(/^ref: refs\/heads\/(.+)$/);
      this._stats.currentBranch = match ? match[1] : content.substring(0, 7);
    } catch {
      // Ignore
    }
  }

  // ───── Public API ─────

  /** Seed session stats from cloud data (so we don't restart from zero after a Cursor restart) */
  seedFromCloud(codingMinutes: number, totalEdits: number, linesAdded: number, linesRemoved: number): void {
    // Only seed if current stats are still at zero (fresh start)
    if (this._stats.totalEdits > 0 || this._stats.codingMinutes > 0) return;
    this.storedMinutes = codingMinutes;
    this._stats.codingMinutes = codingMinutes;
    this._stats.totalEdits = totalEdits;
    this._stats.linesAdded = linesAdded;
    this._stats.linesRemoved = linesRemoved;
    this._onSessionUpdate.fire(this._stats);
  }

  /** Reset session stats (e.g., for a new day) */
  resetSession(): void {
    const now = new Date();
    this.storedMinutes = 0;
    this.activeSessionStart = null;
    this._stats = {
      startTime: now,
      lastEditTime: now,
      totalEdits: 0,
      codingMinutes: 0,
      filesEdited: new Set(),
      languageBreakdown: new Map(),
      linesAdded: 0,
      linesRemoved: 0,
      currentBranch: this._stats.currentBranch,
      isIdle: true,
    };
  }

  dispose(): void {
    if (this.idleTimer) clearTimeout(this.idleTimer);
    if (this.codingTimer) clearInterval(this.codingTimer);
    if (this.gitWatcher) this.gitWatcher.close();
    for (const d of this.disposables) d.dispose();
    this._onIdle.dispose();
    this._onResume.dispose();
    this._onBranchChange.dispose();
    this._onSessionUpdate.dispose();
    this._onBreakReminder.dispose();
  }
}
