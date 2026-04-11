/**
 * TriggerEngine — Decides when to show notifications, update sidebar, etc.
 *
 * Smart triggers that combine:
 *   1. Idle detection → show session summary after X minutes of inactivity
 *   2. Session boundaries → branch change, project close
 *   3. MCP events → new summary generated, milestone reached
 *   4. Periodic → refresh sidebar on interval
 *
 * All triggers route through a single decision point so notifications
 * don't pile up or interrupt the user.
 */

import * as vscode from "vscode";
import type { FileWatcher, MCPDailySummary } from "./file-watcher.js";
import type { SessionTracker, SessionStats } from "./session-tracker.js";

export interface TriggerEvent {
  type: "idle_summary" | "session_end" | "summary_generated" | "milestone" | "periodic";
  title: string;
  message: string;
  sessionStats?: SessionStats;
  summary?: MCPDailySummary;
}

export class TriggerEngine implements vscode.Disposable {
  private disposables: vscode.Disposable[] = [];
  private lastNotificationTime = 0;
  private minNotificationGapMs = 5 * 60 * 1000; // 5 min between notifications

  private _onTrigger = new vscode.EventEmitter<TriggerEvent>();
  readonly onTrigger = this._onTrigger.event;

  constructor(
    private fileWatcher: FileWatcher,
    private sessionTracker: SessionTracker
  ) {
    this.setupTriggers();
  }

  private setupTriggers(): void {
    // 1. Idle detection → show session summary
    this.disposables.push(
      this.sessionTracker.onIdle((stats) => {
        // Only trigger if user coded for at least 10 minutes
        if (stats.codingMinutes < 10) return;
        this.fire({
          type: "idle_summary",
          title: "Session Pause",
          message: this.buildIdleSummaryMessage(stats),
          sessionStats: stats,
        });
      })
    );

    // 2. Branch change → show notification
    this.disposables.push(
      this.sessionTracker.onBranchChange(({ from, to }) => {
        if (from && this.sessionTracker.stats.codingMinutes >= 5) {
          this.fire({
            type: "session_end",
            title: "Branch Switch",
            message: `Switched from ${from} → ${to}. You coded ${this.sessionTracker.codingTimeFormatted} on ${from}.`,
            sessionStats: this.sessionTracker.stats,
          });
        }
      })
    );

    // 3. MCP summary generated → show notification
    this.disposables.push(
      this.fileWatcher.onSummaryGenerated((summary) => {
        this.fire({
          type: "summary_generated",
          title: "Daily Summary Ready",
          message: this.buildDailySummaryMessage(summary),
          summary,
        });
      })
    );

    // 4. MCP events → check for milestones
    this.disposables.push(
      this.fileWatcher.onNewEvents((events) => {
        // Check for notable milestones
        const totalEvents = this.fileWatcher.todayEvents.length;
        if (totalEvents === 10 || totalEvents === 25 || totalEvents === 50) {
          this.fire({
            type: "milestone",
            title: "Milestone!",
            message: `${totalEvents} MCP events today — your coding pet is learning a lot!`,
          });
        }
      })
    );
  }

  // ───── Message builders ─────

  private buildIdleSummaryMessage(stats: SessionStats): string {
    const parts: string[] = [];
    parts.push(`${this.sessionTracker.codingTimeFormatted} of coding`);
    parts.push(`${stats.totalEdits} edits`);
    parts.push(`${stats.filesEdited.size} files`);

    const topLang = this.sessionTracker.topLanguage;
    if (topLang) parts.push(`mostly ${topLang}`);

    return parts.join(" · ");
  }

  private buildDailySummaryMessage(summary: MCPDailySummary): string {
    const parts: string[] = [];
    if (summary.totalCodingMinutes > 0) {
      const h = Math.floor(summary.totalCodingMinutes / 60);
      const m = summary.totalCodingMinutes % 60;
      parts.push(h > 0 ? `${h}h ${m}m coding` : `${m}m coding`);
    }
    if (summary.commits > 0) parts.push(`${summary.commits} commits`);
    if (summary.errorsFixed > 0) parts.push(`${summary.errorsFixed} bugs fixed`);
    return parts.join(" · ");
  }

  // ───── Notification throttling ─────

  private fire(event: TriggerEvent): void {
    const now = Date.now();
    const config = vscode.workspace.getConfiguration("codepet");
    const showNotifications = config.get<boolean>("showNotifications") ?? true;

    // Always emit the event (sidebar listens to all)
    this._onTrigger.fire(event);

    // Throttle actual VS Code notifications
    if (!showNotifications) return;
    if (now - this.lastNotificationTime < this.minNotificationGapMs) return;

    this.lastNotificationTime = now;
    this.showNotification(event);
  }

  private showNotification(event: TriggerEvent): void {
    const petName = vscode.workspace.getConfiguration("codepet").get<string>("petName") ?? "Nova";

    const prefix = event.type === "summary_generated"
      ? `🌟 ${petName}:`
      : event.type === "milestone"
      ? `⭐ ${petName}:`
      : `💤 ${petName}:`;

    const msg = `${prefix} ${event.message}`;

    vscode.window
      .showInformationMessage(msg, "Open Dashboard")
      .then((action) => {
        if (action === "Open Dashboard") {
          vscode.commands.executeCommand("codepet.dashboard.focus");
        }
      });
  }

  dispose(): void {
    for (const d of this.disposables) d.dispose();
    this._onTrigger.dispose();
  }
}
