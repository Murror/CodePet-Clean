/**
 * Session Logger — JSON file-backed event store
 *
 * Every MCP tool call, resource access, and significant event is logged here.
 * This data powers the daily insights dashboard and skill progression tracking.
 *
 * Storage layout (~/.codepet/):
 *   events/YYYY-MM-DD.json  — daily event arrays
 *   profile.json             — persistent user profile & cached data
 *   summaries/YYYY-MM-DD.json — generated daily summaries
 *
 * NOTE: This implementation uses JSON files for zero native dependencies.
 * For production, swap in better-sqlite3 for better query performance —
 * the interface stays identical. On macOS, `npm install` will compile
 * better-sqlite3 natively without issues.
 */

import { homedir } from "node:os";
import { join } from "node:path";
import {
  mkdirSync,
  existsSync,
  readFileSync,
  writeFileSync,
} from "node:fs";

export interface SessionEvent {
  type: "tool_call" | "resource_access" | "git" | "diagnostic" | "learning" | "server";
  action: string;
  project?: string;
  language?: string;
  file?: string;
  metadata?: Record<string, unknown>;
}

export interface StoredEvent extends SessionEvent {
  id: number;
  timestamp: string;
}

export interface DailySummary {
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

function todayString(): string {
  return new Date().toISOString().split("T")[0];
}

export class SessionLogger {
  private dataDir: string;
  private eventsDir: string;
  private summariesDir: string;
  private profilePath: string;
  private nextId: number;

  constructor(dataDir?: string) {
    this.dataDir = dataDir ?? join(homedir(), ".codepet");
    this.eventsDir = join(this.dataDir, "events");
    this.summariesDir = join(this.dataDir, "summaries");
    this.profilePath = join(this.dataDir, "profile.json");

    // Ensure directories exist
    for (const dir of [this.dataDir, this.eventsDir, this.summariesDir]) {
      if (!existsSync(dir)) {
        mkdirSync(dir, { recursive: true });
      }
    }

    // Initialize profile if needed
    if (!existsSync(this.profilePath)) {
      writeFileSync(this.profilePath, JSON.stringify({}, null, 2));
    }

    // Determine next event ID from today's events
    const todayEvents = this.readEventsFile(todayString());
    this.nextId = todayEvents.length > 0
      ? Math.max(...todayEvents.map((e) => e.id)) + 1
      : 1;
  }

  // ───── File helpers ─────

  private eventsFilePath(date: string): string {
    return join(this.eventsDir, `${date}.json`);
  }

  private summaryFilePath(date: string): string {
    return join(this.summariesDir, `${date}.json`);
  }

  private readEventsFile(date: string): StoredEvent[] {
    const path = this.eventsFilePath(date);
    if (!existsSync(path)) return [];
    try {
      return JSON.parse(readFileSync(path, "utf-8")) as StoredEvent[];
    } catch {
      return [];
    }
  }

  private writeEventsFile(date: string, events: StoredEvent[]): void {
    writeFileSync(this.eventsFilePath(date), JSON.stringify(events, null, 2));
  }

  private readProfile(): Record<string, unknown> {
    try {
      return JSON.parse(readFileSync(this.profilePath, "utf-8"));
    } catch {
      return {};
    }
  }

  private writeProfile(profile: Record<string, unknown>): void {
    writeFileSync(this.profilePath, JSON.stringify(profile, null, 2));
  }

  // ───── Public API (same interface as SQLite version) ─────

  /**
   * Log a session event. Called automatically by every tool.
   */
  logEvent(event: SessionEvent): void {
    const date = todayString();
    const events = this.readEventsFile(date);

    const stored: StoredEvent = {
      id: this.nextId++,
      timestamp: new Date().toISOString(),
      ...event,
    };

    events.push(stored);
    this.writeEventsFile(date, events);
  }

  /**
   * Get all events for a specific date (defaults to today).
   */
  getEventsForDate(date?: string): StoredEvent[] {
    return this.readEventsFile(date ?? todayString());
  }

  /**
   * Get event counts grouped by type for a date range.
   */
  getEventStats(since?: string): Record<string, number> {
    const events = this.readEventsFile(since ?? todayString());
    const stats: Record<string, number> = {};
    for (const event of events) {
      stats[event.type] = (stats[event.type] ?? 0) + 1;
    }
    return stats;
  }

  /**
   * Store or update a user profile value.
   */
  setProfileValue(key: string, value: unknown): void {
    const profile = this.readProfile();
    profile[key] = value;
    this.writeProfile(profile);
  }

  /**
   * Get a user profile value.
   */
  getProfileValue<T = unknown>(key: string): T | null {
    const profile = this.readProfile();
    return (profile[key] as T) ?? null;
  }

  /**
   * Store a daily summary.
   */
  saveDailySummary(summary: DailySummary): void {
    writeFileSync(
      this.summaryFilePath(summary.date),
      JSON.stringify(summary, null, 2)
    );
  }

  /**
   * Get a daily summary.
   */
  getDailySummary(date?: string): DailySummary | null {
    const path = this.summaryFilePath(date ?? todayString());
    if (!existsSync(path)) return null;
    try {
      return JSON.parse(readFileSync(path, "utf-8")) as DailySummary;
    } catch {
      return null;
    }
  }

  /**
   * Close — no-op for JSON file logger (included for interface compat).
   */
  close(): void {
    // No-op for file-based storage
  }
}
