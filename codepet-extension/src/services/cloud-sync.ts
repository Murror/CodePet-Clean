/**
 * CloudSync — Live data bridge between VS Code extension and Codepet macOS app
 *
 * AUTO-DETECTS the user's Codepet account by reading the macOS app's
 * UserDefaults plist (com.murror.codepet.plist). No manual config needed —
 * if the Codepet app is installed and logged in, the extension syncs automatically.
 *
 * Data flow:
 *   Extension → Firestore ← macOS app (both read/write the same Firestore path)
 *
 * Firestore structure:
 *   users/{uid}/
 *     extensions/{platform}/
 *       session: { codingMinutes, edits, filesEdited, linesAdded, ... }
 *       scanner: { cleanScore, errors, warnings, cleanFiles, totalFiles }
 *       meta: { lastSyncAt, editorName, editorVersion, petName, platform }
 *     extensionHistory/{date}_{platform}/
 *       { ...daily aggregate stats }
 *
 * macOS app plist keys used:
 *   cp_currentUserId  — Firebase UID
 *   cp_displayName    — User's display name
 *   cp_streak         — Current streak count
 *   cp_petMood        — Pet mood
 *   cp_totalXP        — Total XP
 */

import * as vscode from "vscode";
import * as https from "https";

// ───── Types ─────

export interface SyncSessionData {
  codingMinutes: number;
  totalEdits: number;
  filesEdited: number;
  linesAdded: number;
  linesRemoved: number;
  currentBranch: string;
  topLanguage: string;
  languageBreakdown: Record<string, number>;
  isIdle: boolean;
}

export interface SyncScannerData {
  averageCleanScore: number;
  totalErrors: number;
  totalWarnings: number;
  cleanFiles: number;
  totalFiles: number;
  topIssue: string | null;
}

/** Data read from the macOS app's UserDefaults */
export interface AppAccountInfo {
  uid: string;
  displayName: string;
  streak: number;
  petMood: string;
  totalXP: number;
  activeChar: string;
}

// Codepet macOS app Firebase config (from GoogleService-Info.plist)
const FIREBASE_PROJECT_ID = "devpet-8f4b1";
const FIREBASE_API_KEY = "AIzaSyCl1Eyl5WD2ggVlLBGU-l3SefdTZreDoJ8";
// The macOS app's actual bundle ID is app.murror.codepet;
// older installs may still have data under com.murror.codepet
const APP_BUNDLE_IDS = ["app.murror.codepet", "com.murror.codepet"];

// ───── CloudSync class ─────

export class CloudSync implements vscode.Disposable {
  private disposables: vscode.Disposable[] = [];
  private syncTimer: ReturnType<typeof setInterval> | undefined;
  private platform: string;
  private pendingSession: SyncSessionData | null = null;
  private pendingScanner: SyncScannerData | null = null;
  private isSyncing = false;
  private outputChannel: vscode.OutputChannel;

  // Account data read from macOS app
  private _accountInfo: AppAccountInfo | null = null;

  constructor(outputChannel: vscode.OutputChannel) {
    this.outputChannel = outputChannel;
    this.platform = this.detectPlatform();

    // Auto-detect account from macOS app on startup
    this.detectAppAccount();
  }

  // ───── Public API ─────

  /** The detected account from the macOS app, or null if not found */
  get accountInfo(): AppAccountInfo | null {
    return this._accountInfo;
  }

  /** Whether we have a linked account */
  get isConfigured(): boolean {
    return this._accountInfo !== null;
  }

  /** The user's display name from the macOS app (cleaned of encoding artifacts) */
  get userName(): string {
    const raw = this._accountInfo?.displayName ?? "";
    // defaults read outputs escaped unicode like \352 or \U01b0 for non-ASCII chars
    // If the name has escape sequences, it's garbled — return empty so fallback kicks in
    if (/\\[0-9]|\\u|\\U/.test(raw)) return "";
    return raw;
  }

  /** The user's active pet character from the macOS app */
  get petName(): string {
    return this._accountInfo?.activeChar ?? "";
  }

  /** Start periodic syncing */
  start(intervalSeconds: number = 30): void {
    if (this.syncTimer) clearInterval(this.syncTimer);

    this.syncTimer = setInterval(() => {
      this.flush();
    }, intervalSeconds * 1000);

    if (this._accountInfo) {
      this.outputChannel.appendLine(
        `[CloudSync] Linked to Codepet account: ${this._accountInfo.displayName} (${this._accountInfo.uid.substring(0, 8)}...)`
      );
      this.outputChannel.appendLine(
        `[CloudSync] Syncing every ${intervalSeconds}s → Firestore (platform: ${this.platform})`
      );
    } else {
      this.outputChannel.appendLine(
        `[CloudSync] Codepet macOS app not detected — cloud sync disabled. Install the app and sign in to enable.`
      );
    }
  }

  /** Queue session data for next sync */
  updateSession(data: SyncSessionData): void {
    this.pendingSession = data;
  }

  /** Queue scanner data for next sync */
  updateScanner(data: SyncScannerData): void {
    this.pendingScanner = data;
  }

  /** Force an immediate sync */
  async flush(): Promise<void> {
    if (!this._accountInfo) return;
    if (this.isSyncing) return;
    if (!this.pendingSession && !this.pendingScanner) return;
    // Don't write zero session data — it would overwrite previous session's stats
    if (this.pendingSession && this.pendingSession.codingMinutes === 0 && this.pendingSession.totalEdits === 0) {
      this.pendingSession = null;
      if (!this.pendingScanner) return;
    }

    this.isSyncing = true;

    try {
      const docPath = `users/${this._accountInfo.uid}/extensions/${this.platform}`;
      const petName =
        vscode.workspace.getConfiguration("codepet").get<string>("petName") ??
        this._accountInfo.activeChar ??
        "Nova";

      const payload: Record<string, any> = {
        meta: {
          lastSyncAt: new Date().toISOString(),
          editorName: vscode.env.appName,
          editorVersion: vscode.version,
          extensionVersion: "0.4.0",
          petName,
          platform: this.platform,
          displayName: this._accountInfo.displayName,
        },
      };

      if (this.pendingSession) {
        payload.session = {
          ...this.pendingSession,
          sessionDate: new Date().toISOString().split("T")[0], // YYYY-MM-DD for staleness checks
        };
        this.pendingSession = null;
      }

      if (this.pendingScanner) {
        payload.scanner = this.pendingScanner;
        this.pendingScanner = null;
      }

      await this.firestoreSet(docPath, payload);

      // Also write daily history
      const today = new Date().toISOString().split("T")[0];
      const historyPath = `users/${this._accountInfo.uid}/extensionHistory/${today}_${this.platform}`;
      await this.firestoreSet(historyPath, {
        ...payload,
        date: today,
      });

      this.outputChannel.appendLine(
        `[CloudSync] Synced (${Object.keys(payload).filter((k) => k !== "meta").join(", ")})`
      );
    } catch (err: any) {
      this.outputChannel.appendLine(
        `[CloudSync] Sync failed: ${err.message ?? err}`
      );
    } finally {
      this.isSyncing = false;
    }
  }

  /** Read yesterday's stats from Firestore (for welcome panel) */
  async getYesterdayStats(): Promise<{
    codingMinutes: number;
    linesAdded: number;
    commits: number;
    cleanScore: number;
  } | null> {
    if (!this._accountInfo) return null;

    try {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const dateStr = yesterday.toISOString().split("T")[0];
      const path = `users/${this._accountInfo.uid}/extensionHistory/${dateStr}_${this.platform}`;
      const data = await this.firestoreGet(path);

      if (!data) return null;

      return {
        codingMinutes: data.session?.codingMinutes ?? 0,
        linesAdded: data.session?.linesAdded ?? 0,
        commits: 0,
        cleanScore: data.scanner?.averageCleanScore ?? 100,
      };
    } catch {
      return null;
    }
  }

  /** Get streak days from the macOS app's cached data */
  async getStreakDays(): Promise<number> {
    return this._accountInfo?.streak ?? 0;
  }

  /** Read the user's profile from Firestore (same data macOS app shows) */
  async getUserProfile(): Promise<{
    totalXP: number;
    userLevel: number;
    streak: number;
    completedLessons: string[];
    activeChar: string;
    displayName: string;
  } | null> {
    if (!this._accountInfo) return null;

    try {
      const path = `users/${this._accountInfo.uid}`;
      const data = await this.firestoreGet(path);
      if (!data) return null;

      return {
        totalXP: data.totalXP ?? 0,
        userLevel: data.userLevel ?? 1,
        streak: data.streak ?? 0,
        completedLessons: data.completedLessons ?? [],
        activeChar: data.activeChar ?? "byte",
        displayName: data.displayName ?? "",
      };
    } catch {
      return null;
    }
  }

  /** Read today's extension session data from Firestore (same data macOS app shows) */
  async getTodayExtensionStats(): Promise<{
    codingMinutes: number;
    totalEdits: number;
    filesEdited: number;
    linesAdded: number;
    linesRemoved: number;
    topLanguage: string;
    languageBreakdown: Record<string, number>;
    cleanScore: number;
    totalErrors: number;
    totalWarnings: number;
  } | null> {
    if (!this._accountInfo) return null;

    try {
      const path = `users/${this._accountInfo.uid}/extensions/${this.platform}`;
      const data = await this.firestoreGet(path);
      if (!data) return null;

      // Only return stats if they're from today — never seed stale data.
      // If sessionDate is missing (old data written before this field existed), reject it too.
      const today = new Date().toISOString().split("T")[0];
      const sessionDate = data.session?.sessionDate ?? "";
      if (sessionDate !== today) return null;

      return {
        codingMinutes: data.session?.codingMinutes ?? 0,
        totalEdits: data.session?.totalEdits ?? 0,
        filesEdited: data.session?.filesEdited ?? 0,
        linesAdded: data.session?.linesAdded ?? 0,
        linesRemoved: data.session?.linesRemoved ?? 0,
        topLanguage: data.session?.topLanguage ?? "",
        languageBreakdown: data.session?.languageBreakdown ?? {},
        cleanScore: data.scanner?.averageCleanScore ?? 100,
        totalErrors: data.scanner?.totalErrors ?? 0,
        totalWarnings: data.scanner?.totalWarnings ?? 0,
      };
    } catch {
      return null;
    }
  }

  /** Re-detect the macOS app account (call if user signs in/out of app) */
  refreshAccount(): void {
    this.detectAppAccount();
  }

  // ───── macOS App Account Detection ─────

  /**
   * Reads the Codepet macOS app's UserDefaults plist to get:
   *   - Firebase UID (cp_currentUserId)
   *   - Display name (cp_displayName)
   *   - Streak, XP, pet mood, active character
   *
   * macOS stores UserDefaults at:
   *   ~/Library/Preferences/com.murror.codepet.plist
   *
   * We use `defaults read` to extract values (works without sandbox issues).
   */
  private detectAppAccount(): void {
    try {
      // Read the Firebase UID from UserDefaults (uses plist parsing, not `defaults read`)
      const uid = this.readDefault("cp_currentUserId");
      if (!uid) {
        this._accountInfo = null;
        this.outputChannel.appendLine(
          `[CloudSync] cp_currentUserId not found — is the macOS app signed in?`
        );
        return;
      }

      // Read all the user data we need
      const displayName = this.readDefault("cp_displayName") ?? "";
      const streak = parseInt(this.readDefault("cp_streak") ?? "0", 10);
      const petMood = this.readDefault("cp_petMood") ?? "happy";
      const totalXP = parseInt(this.readDefault("cp_totalXP") ?? "0", 10);
      const activeChar = this.readDefault("cp_activeChar") ?? "nova";

      this._accountInfo = {
        uid,
        displayName,
        streak,
        petMood,
        totalXP,
        activeChar,
      };

      this.outputChannel.appendLine(
        `[CloudSync] Detected Codepet account: "${displayName}" (uid: ${uid.substring(0, 8)}..., pet: ${activeChar}, streak: ${streak})`
      );
    } catch (err: any) {
      this._accountInfo = null;
      this.outputChannel.appendLine(
        `[CloudSync] Could not detect Codepet app: ${err.message ?? err}`
      );
    }
  }

  /**
   * Read all UserDefaults from the macOS app's plist file.
   * Returns a Map of key→value strings.
   *
   * Strategy: Convert the binary plist to XML with plutil, then parse key/value pairs.
   * This is 100% reliable inside VS Code/Cursor — no dependency on `defaults` command.
   */
  private plistCache: Map<string, string> | null = null;

  private loadPlist(): Map<string, string> {
    if (this.plistCache) return this.plistCache;

    const { execSync } = require("child_process");
    const os = require("os");
    const pathMod = require("path");
    const fs = require("fs");
    const homedir = os.homedir();
    const prefsDir = pathMod.join(homedir, "Library", "Preferences");

    // Find the plist file — try all known names
    const plistNames = [
      ...APP_BUNDLE_IDS.map((id: string) => `${id}.plist`),
      "codepet.plist",
    ];

    this.plistCache = new Map();

    for (const plistName of plistNames) {
      const plistPath = pathMod.join(prefsDir, plistName);
      if (!fs.existsSync(plistPath)) continue;

      this.outputChannel.appendLine(`[CloudSync] Found plist: ${plistPath}`);

      try {
        // Convert binary plist → XML and read stdout
        const xml = execSync(
          `/usr/bin/plutil -convert xml1 -o - "${plistPath}"`,
          { encoding: "utf-8", timeout: 5000 }
        );

        // Parse simple key/string pairs from the XML
        // Format: <key>cp_currentUserId</key>\n\t<string>Ma9fVAP...</string>
        const keyRegex = /<key>([^<]+)<\/key>\s*<(string|integer|real)>([^<]*)<\/\2>/g;
        let match;
        while ((match = keyRegex.exec(xml)) !== null) {
          this.plistCache.set(match[1], match[3]);
        }

        // Also handle <true/> and <false/> booleans
        const boolRegex = /<key>([^<]+)<\/key>\s*<(true|false)\/>/g;
        while ((match = boolRegex.exec(xml)) !== null) {
          this.plistCache.set(match[1], match[2] === "true" ? "1" : "0");
        }

        this.outputChannel.appendLine(
          `[CloudSync] Parsed ${this.plistCache.size} keys from ${plistName}`
        );

        // If we found cp_ keys, this is the right file — stop searching
        if (this.plistCache.has("cp_currentUserId")) {
          this.outputChannel.appendLine(
            `[CloudSync] Found cp_currentUserId in ${plistName}`
          );
          break;
        }
      } catch (err: any) {
        this.outputChannel.appendLine(
          `[CloudSync] Failed to parse ${plistName}: ${err.message ?? err}`
        );
      }
    }

    if (this.plistCache.size === 0) {
      this.outputChannel.appendLine(
        `[CloudSync] No Codepet plist found in ${prefsDir}. Tried: ${plistNames.join(", ")}`
      );

      // Last resort: try `defaults read` as a fallback
      for (const bundleId of APP_BUNDLE_IDS) {
        try {
          const result = execSync(
            `/usr/bin/defaults read ${bundleId} cp_currentUserId 2>/dev/null`,
            { encoding: "utf-8", timeout: 3000, env: { ...process.env, HOME: homedir } }
          ).trim();
          if (result) {
            this.outputChannel.appendLine(`[CloudSync] defaults read fallback found UID: ${result.substring(0, 8)}...`);
            this.plistCache.set("cp_currentUserId", result);
            // Read other keys too
            for (const key of ["cp_displayName", "cp_activeChar", "cp_streak", "cp_petMood", "cp_totalXP"]) {
              try {
                const val = execSync(
                  `/usr/bin/defaults read ${bundleId} ${key} 2>/dev/null`,
                  { encoding: "utf-8", timeout: 3000, env: { ...process.env, HOME: homedir } }
                ).trim();
                if (val) this.plistCache.set(key, val);
              } catch { /* skip */ }
            }
            break;
          }
        } catch { /* try next */ }
      }
    }

    return this.plistCache;
  }

  private readDefault(key: string): string | null {
    const cache = this.loadPlist();
    return cache.get(key) ?? null;
  }

  // ───── Firestore REST API ─────
  // Uses the Firebase REST API with API key auth (no user token needed for
  // writes to the user's own document, if Firestore rules allow it).
  // For production, the macOS app should write an auth token to a shared
  // location; for MVP, we use API key + UID-scoped writes.

  private async firestoreSet(
    docPath: string,
    data: Record<string, any>
  ): Promise<void> {
    const url =
      `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}` +
      `/databases/(default)/documents/${docPath}?key=${FIREBASE_API_KEY}`;

    const firestoreDoc = this.toFirestoreDocument(data);
    await this.httpRequest("PATCH", url, firestoreDoc, {});
  }

  private async firestoreGet(
    docPath: string
  ): Promise<Record<string, any> | null> {
    const url =
      `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}` +
      `/databases/(default)/documents/${docPath}?key=${FIREBASE_API_KEY}`;

    try {
      const response = await this.httpRequest("GET", url, null, {});
      return this.fromFirestoreDocument(JSON.parse(response));
    } catch {
      return null;
    }
  }

  // ───── Firestore document conversion ─────

  private toFirestoreDocument(data: Record<string, any>): any {
    return { fields: this.toFirestoreFields(data) };
  }

  private toFirestoreFields(obj: Record<string, any>): any {
    const fields: any = {};
    for (const [key, value] of Object.entries(obj)) {
      fields[key] = this.toFirestoreValue(value);
    }
    return fields;
  }

  private toFirestoreValue(value: any): any {
    if (value === null || value === undefined) return { nullValue: null };
    if (typeof value === "string") return { stringValue: value };
    if (typeof value === "number") {
      return Number.isInteger(value)
        ? { integerValue: String(value) }
        : { doubleValue: value };
    }
    if (typeof value === "boolean") return { booleanValue: value };
    if (Array.isArray(value)) {
      return { arrayValue: { values: value.map((v) => this.toFirestoreValue(v)) } };
    }
    if (typeof value === "object") {
      return { mapValue: { fields: this.toFirestoreFields(value) } };
    }
    return { stringValue: String(value) };
  }

  private fromFirestoreDocument(doc: any): Record<string, any> | null {
    if (!doc || !doc.fields) return null;
    return this.fromFirestoreFields(doc.fields);
  }

  private fromFirestoreFields(fields: any): Record<string, any> {
    const result: Record<string, any> = {};
    for (const [key, value] of Object.entries(fields)) {
      result[key] = this.fromFirestoreValue(value as any);
    }
    return result;
  }

  private fromFirestoreValue(value: any): any {
    if ("stringValue" in value) return value.stringValue;
    if ("integerValue" in value) return parseInt(value.integerValue, 10);
    if ("doubleValue" in value) return value.doubleValue;
    if ("booleanValue" in value) return value.booleanValue;
    if ("nullValue" in value) return null;
    if ("arrayValue" in value) {
      return (value.arrayValue.values || []).map((v: any) => this.fromFirestoreValue(v));
    }
    if ("mapValue" in value) {
      return this.fromFirestoreFields(value.mapValue.fields || {});
    }
    return null;
  }

  // ───── HTTP helper ─────

  private httpRequest(
    method: string,
    url: string,
    body: any,
    headers: Record<string, string>
  ): Promise<string> {
    return new Promise((resolve, reject) => {
      const urlObj = new URL(url);
      const options: https.RequestOptions = {
        hostname: urlObj.hostname,
        path: urlObj.pathname + urlObj.search,
        method,
        headers: {
          "Content-Type": "application/json",
          ...headers,
        },
      };

      const req = https.request(options, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            resolve(data);
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${data.substring(0, 200)}`));
          }
        });
      });

      req.on("error", reject);
      req.setTimeout(10000, () => {
        req.destroy();
        reject(new Error("Request timed out"));
      });

      if (body) req.write(JSON.stringify(body));
      req.end();
    });
  }

  // ───── Helpers ─────

  private detectPlatform(): string {
    const appName = vscode.env.appName.toLowerCase();
    if (appName.includes("cursor")) return "cursor";
    if (appName.includes("windsurf")) return "windsurf";
    if (appName.includes("vscodium")) return "vscodium";
    return "vscode";
  }

  dispose(): void {
    if (this.syncTimer) clearInterval(this.syncTimer);
    this.flush().catch(() => {});
    for (const d of this.disposables) d.dispose();
  }
}
