/**
 * StatusBar — Compact live coding stats in the VS Code status bar
 *
 * Shows: 🌟 Nova | 2h 15m | 3 commits | Lv2
 * Clicking opens the Codepet sidebar panel.
 */

import * as vscode from "vscode";
import type { FileWatcher } from "../core/file-watcher.js";
import type { SessionTracker } from "../core/session-tracker.js";

export class StatusBar implements vscode.Disposable {
  private static instance: StatusBar | undefined; // singleton guard against duplicates
  private statusItem: vscode.StatusBarItem;
  private disposables: vscode.Disposable[] = [];
  private updateTimer: NodeJS.Timeout | undefined;
  private resolvedPetName: string = "Nova";

  /** Set the pet name from the macOS app account */
  setPetName(name: string): void {
    this.resolvedPetName = name;
    this.update();
  }

  constructor(
    private fileWatcher: FileWatcher,
    private sessionTracker: SessionTracker
  ) {
    // Dispose any previous instance to prevent duplicate status bar items
    if (StatusBar.instance) {
      StatusBar.instance.dispose();
    }
    StatusBar.instance = this;

    this.statusItem = vscode.window.createStatusBarItem(
      vscode.StatusBarAlignment.Left,
      100
    );
    this.statusItem.command = "codepet.dashboard.focus";
    this.statusItem.tooltip = "Codepet — Click to open dashboard";

    // Update on data changes
    this.disposables.push(
      this.fileWatcher.onDataChanged(() => this.update())
    );
    this.disposables.push(
      this.sessionTracker.onSessionUpdate(() => this.update())
    );

    // Update every 10s for real-time timer display
    this.updateTimer = setInterval(() => this.update(), 10_000);

    this.update();
    this.statusItem.show();
  }

  private update(): void {
    const petName = this.resolvedPetName;
    const stats = this.sessionTracker.stats;
    const summary = this.fileWatcher.todaySummary;

    const parts: string[] = [`$(star-full) ${petName}`];

    // Coding time — only live session data, no MCP fallback
    const codingTime = this.sessionTracker.codingTimeFormatted;
    if (codingTime !== "0m") {
      parts.push(codingTime);
    }

    // Edits from session
    if (stats.totalEdits > 0) {
      parts.push(`${stats.totalEdits} edits`);
    }

    // Files from session
    if (stats.filesEdited.size > 0) {
      parts.push(`${stats.filesEdited.size} files`);
    }

    // Idle indicator
    if (stats.isIdle && stats.codingMinutes > 0) {
      parts.push("💤");
    }

    this.statusItem.text = parts.join(" | ");

    // Color based on connection status
    if (!this.fileWatcher.isConnected) {
      this.statusItem.backgroundColor = new vscode.ThemeColor(
        "statusBarItem.warningBackground"
      );
      this.statusItem.tooltip = "Codepet — MCP server not detected. Run codepet-mcp-server to connect.";
    } else {
      this.statusItem.backgroundColor = undefined;
      this.statusItem.tooltip = "Codepet — Click to open dashboard";
    }
  }

  dispose(): void {
    if (this.updateTimer) clearInterval(this.updateTimer);
    this.statusItem.dispose();
    for (const d of this.disposables) d.dispose();
  }
}
