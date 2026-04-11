/**
 * FileWatcher — Monitors ~/.codepet/ for MCP server data changes
 *
 * Watches for:
 *   - events/YYYY-MM-DD.json changes (new tool calls)
 *   - summaries/YYYY-MM-DD.json changes (daily summary generated)
 *   - profile.json changes (skill progress updated)
 *
 * Emits typed events so the sidebar, status bar, and trigger engine
 * can all react to new data.
 */

import * as vscode from "vscode";
import { homedir } from "node:os";
import { join } from "node:path";
import {
  existsSync,
  readFileSync,
  readdirSync,
  watch as fsWatch,
  type FSWatcher,
} from "node:fs";

// ───── Data types (mirrors MCP server models) ─────

export interface MCPDailySummary {
  date: string;
  totalCodingMinutes: number;
  linesAdded: number;
  linesRemoved: number;
  commits: number;
  aiSessions: number;
  errorsFixed: number;
  languageBreakdown: Record<string, number>;
  skillsTracked: Record<string, number>;
  topFiles: string[];
  petReaction?: string;
}

export interface MCPSkillProgress {
  id: string;
  name: string;
  icon: string;
  kingdom: string;
  tier: number;
  xp: number;
  level: number;
  maxLevel: number;
  xpProgress: number;
  xpToNextLevel: number;
}

export interface MCPSessionEvent {
  id: number;
  timestamp: string;
  type: string;
  action: string;
  project?: string;
  language?: string;
  file?: string;
  metadata?: Record<string, unknown>;
}

// ───── FileWatcher class ─────

export class FileWatcher implements vscode.Disposable {
  private codepetDir: string;
  private watchers: FSWatcher[] = [];
  private refreshInterval: NodeJS.Timeout | undefined;

  // Current data state
  private _todaySummary: MCPDailySummary | null = null;
  private _todayEvents: MCPSessionEvent[] = [];
  private _skillProgress: MCPSkillProgress[] = [];
  private _isConnected = false;
  private _activeDaysCount = 0;

  // Event emitters
  private _onDataChanged = new vscode.EventEmitter<void>();
  readonly onDataChanged = this._onDataChanged.event;

  private _onSummaryGenerated = new vscode.EventEmitter<MCPDailySummary>();
  readonly onSummaryGenerated = this._onSummaryGenerated.event;

  private _onNewEvents = new vscode.EventEmitter<MCPSessionEvent[]>();
  readonly onNewEvents = this._onNewEvents.event;

  // Getters
  get todaySummary() { return this._todaySummary; }
  get todayEvents() { return this._todayEvents; }
  get skillProgress() { return this._skillProgress; }
  get isConnected() { return this._isConnected; }
  get activeDaysCount() { return this._activeDaysCount; }

  get totalSkillXP(): number {
    return this._skillProgress.reduce((sum, s) => sum + s.xp, 0);
  }

  constructor() {
    const config = vscode.workspace.getConfiguration("codepet");
    const customDir = config.get<string>("mcpDataDir");
    this.codepetDir = customDir && customDir.length > 0
      ? customDir
      : join(homedir(), ".codepet");

    this.refresh();
    this.startWatching();
  }

  private todayString(): string {
    return new Date().toISOString().split("T")[0];
  }

  // ───── File system watching ─────

  private startWatching(): void {
    const config = vscode.workspace.getConfiguration("codepet");
    const intervalSec = config.get<number>("periodicRefreshSeconds") ?? 30;

    // Periodic refresh as a reliable fallback
    this.refreshInterval = setInterval(() => this.refresh(), intervalSec * 1000);

    // Also watch specific directories if they exist
    try {
      const eventsDir = join(this.codepetDir, "events");
      const summariesDir = join(this.codepetDir, "summaries");

      if (existsSync(eventsDir)) {
        const w = fsWatch(eventsDir, () => this.refresh());
        this.watchers.push(w);
      }

      if (existsSync(summariesDir)) {
        const w = fsWatch(summariesDir, () => {
          const prevSummary = this._todaySummary;
          this.refresh();
          if (this._todaySummary && !prevSummary) {
            this._onSummaryGenerated.fire(this._todaySummary);
          }
        });
        this.watchers.push(w);
      }

      const profilePath = join(this.codepetDir, "profile.json");
      if (existsSync(profilePath)) {
        const w = fsWatch(profilePath, () => this.refresh());
        this.watchers.push(w);
      }
    } catch {
      // Directory doesn't exist yet — rely on periodic refresh
    }
  }

  // ───── Data loading ─────

  refresh(): void {
    const wasConnected = this._isConnected;
    this._isConnected = existsSync(this.codepetDir);

    if (!this._isConnected) {
      this._todaySummary = null;
      this._todayEvents = [];
      this._skillProgress = [];
      this._activeDaysCount = 0;
      if (wasConnected) {
        this._onDataChanged.fire();
      }
      return;
    }

    const prevEventCount = this._todayEvents.length;

    this.loadTodaySummary();
    this.loadTodayEvents();
    this.loadSkillProgress();
    this.loadActiveDays();

    // Fire events
    this._onDataChanged.fire();

    if (this._todayEvents.length > prevEventCount) {
      const newEvents = this._todayEvents.slice(prevEventCount);
      this._onNewEvents.fire(newEvents);
    }
  }

  private loadTodaySummary(): void {
    // ONLY load today's summary — never fall back to old dates.
    // Stale data from previous days was being seeded into the session tracker,
    // making it look like the user had 3h of coding time on a fresh restart.
    const todayPath = join(this.codepetDir, "summaries", `${this.todayString()}.json`);
    if (existsSync(todayPath)) {
      try {
        this._todaySummary = JSON.parse(readFileSync(todayPath, "utf-8"));
        return;
      } catch { /* fall through */ }
    }

    this._todaySummary = null;
  }

  private loadTodayEvents(): void {
    const path = join(this.codepetDir, "events", `${this.todayString()}.json`);
    if (!existsSync(path)) {
      this._todayEvents = [];
      return;
    }
    try {
      this._todayEvents = JSON.parse(readFileSync(path, "utf-8"));
    } catch {
      this._todayEvents = [];
    }
  }

  private loadSkillProgress(): void {
    const profilePath = join(this.codepetDir, "profile.json");
    if (!existsSync(profilePath)) {
      this._skillProgress = [];
      return;
    }
    try {
      const profile = JSON.parse(readFileSync(profilePath, "utf-8"));
      if (Array.isArray(profile.skill_progress)) {
        this._skillProgress = profile.skill_progress;
      }
    } catch {
      this._skillProgress = [];
    }
  }

  private loadActiveDays(): void {
    const eventsDir = join(this.codepetDir, "events");
    if (!existsSync(eventsDir)) {
      this._activeDaysCount = 0;
      return;
    }
    try {
      this._activeDaysCount = readdirSync(eventsDir)
        .filter((f) => f.endsWith(".json")).length;
    } catch {
      this._activeDaysCount = 0;
    }
  }

  dispose(): void {
    if (this.refreshInterval) clearInterval(this.refreshInterval);
    for (const w of this.watchers) w.close();
    this._onDataChanged.dispose();
    this._onSummaryGenerated.dispose();
    this._onNewEvents.dispose();
  }
}
