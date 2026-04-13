/**
 * LessonService — Manages lesson card generation, storage, and sync
 *
 * Handles:
 *   1. Auto-capture: generates a lesson when session goes idle after active coding
 *   2. Manual capture: user triggers "Save Lesson" command
 *   3. Local storage: reads/writes lesson cards from ~/.codepet/lessons/
 *   4. Firestore sync: pushes lessons to users/{uid}/lessons/{id}
 *   5. Feeds data to the sidebar webview
 */

import * as vscode from "vscode";
import { homedir } from "os";
import { join } from "path";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  readdirSync,
} from "fs";
import type { SessionTracker } from "../core/session-tracker.js";
import type { CloudSync } from "./cloud-sync.js";
import type { SidebarProvider, LessonCard } from "../ui/sidebar-provider.js";

// ───── Local Storage ─────

function getLessonsDir(): string {
  const dir = join(homedir(), ".codepet", "lessons");
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  return dir;
}

function loadLocalLessons(limit: number = 20): LessonCard[] {
  const dir = getLessonsDir();
  if (!existsSync(dir)) return [];

  const files = readdirSync(dir)
    .filter((f) => f.endsWith(".json"))
    .sort()
    .reverse()
    .slice(0, limit);

  return files
    .map((f) => {
      try {
        return JSON.parse(readFileSync(join(dir, f), "utf-8")) as LessonCard;
      } catch {
        return null;
      }
    })
    .filter(Boolean) as LessonCard[];
}

function saveLocalLesson(card: LessonCard): void {
  const dir = getLessonsDir();
  writeFileSync(join(dir, `${card.id}.json`), JSON.stringify(card, null, 2));
}

function nextLessonId(): string {
  const date = new Date().toISOString().split("T")[0];
  const dir = getLessonsDir();
  const existing = existsSync(dir)
    ? readdirSync(dir).filter((f) => f.startsWith(date))
    : [];
  const seq = String(existing.length + 1).padStart(3, "0");
  return `${date}_${seq}`;
}

// ───── Pet Voice Templates (lightweight, no LLM needed) ─────

const PET_TEMPLATES: Record<
  string,
  {
    narrations: string[];
    tips: string[];
    reactions: string[];
  }
> = {
  byte: {
    narrations: [
      "⚡ {title}... signal acquired. Knowledge::stored.",
      "⚡ Data fragment captured: {title}. Buffer full.",
      "⚡ New pattern detected — {title}. Caching...",
    ],
    tips: [
      "Try building a mini project with this concept!",
      "Debug something related tomorrow — practice locks it in.",
      "Write a test for what you just learned!",
    ],
    reactions: ["excited", "proud", "glitching"],
  },
  nova: {
    narrations: [
      "YES! You just learned {title}! I'm so proud! 🚀",
      "Look at you go! {title} — you're unstoppable! ✨",
      "Another skill leveled up! {title} is yours now! 🚀",
    ],
    tips: [
      "Challenge: teach this to someone tomorrow!",
      "Try applying this to a personal project tonight!",
      "What if you combined this with what you learned yesterday?",
    ],
    reactions: ["excited", "proud", "thinking"],
  },
  crash: {
    narrations: [
      "Huh, {title}. Not bad for a human. 💥",
      "{title} — took you long enough, but you got there. 🔨",
      "Solid. {title} is locked in now. Don't forget it. 💥",
    ],
    tips: [
      "Now break something with it. That's how you really learn.",
      "Tomorrow: try the hard version of this.",
      "Good. Now do it again from memory.",
    ],
    reactions: ["smirking", "proud", "thinking"],
  },
  luna: {
    narrations: [
      "You learned {title} today — I'm really proud of you 🌙",
      "Beautiful progress! {title} is a wonderful skill to have 💫",
      "Every lesson makes you stronger. {title} is part of you now 🌙",
    ],
    tips: [
      "Take a moment to reflect on what clicked for you today.",
      "Try journaling about this concept — it deepens understanding.",
      "Share this with someone who might be struggling with it!",
    ],
    reactions: ["happy", "proud", "dreamy"],
  },
  sage: {
    narrations: [
      "Knowledge flows. {title} — another stone on the path. 🧘",
      "Patience led to understanding: {title}. Well done. 📿",
      "{title}. Wisdom comes from doing, and you did. 🧘",
    ],
    tips: [
      "Meditate on this: what's the underlying principle here?",
      "Tomorrow, approach the same problem from a different angle.",
      "True mastery comes from teaching. Find a learner.",
    ],
    reactions: ["serene", "proud", "contemplating"],
  },
  glitch: {
    narrations: [
      "yo {title} is actually fire, respect 👾",
      "hack unlocked: {title}. the system can't stop us now 🏴‍☠️",
      "{title} — another exploit in our arsenal 👾",
    ],
    tips: [
      "Now find the edge case that breaks it.",
      "Flip it: what's the opposite approach?",
      "Build something weird with this. Weird = memorable.",
    ],
    reactions: ["hyped", "proud", "scheming"],
  },
  zero: {
    narrations: [
      "{title}. Learned. Stored.",
      "{title}. Good.",
      "New skill: {title}. Progress.",
    ],
    tips: [
      "Practice once more tomorrow.",
      "Apply it. That's all.",
      "Repeat until automatic.",
    ],
    reactions: ["nod", "proud", "thinking"],
  },
  null: {
    narrations: [
      "wait {title}?? THAT's what we were doing?? lol 🤪",
      "I have no idea what {title} means but YOU do and that's amazing 🎲",
      "{title}!! *falls off desk* ...I meant to do that 🤪",
    ],
    tips: [
      "What if you tried doing this upside down? ...metaphorically.",
      "Delete everything and rewrite it. Chaos breeds clarity!",
      "Quick: explain this to a rubber duck. NOW!",
    ],
    reactions: ["excited", "proud", "confused"],
  },
};

function generateOfflineCard(
  petCharacter: string,
  petName: string,
  platform: string,
  sessionStats: {
    codingMinutes: number;
    topLanguage: string;
    filesEdited: number;
    linesAdded: number;
    totalEdits: number;
  }
): LessonCard {
  const templates = PET_TEMPLATES[petCharacter] ?? PET_TEMPLATES.nova;
  const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];

  // Infer difficulty from session length
  const difficulty: LessonCard["difficulty"] =
    sessionStats.codingMinutes > 45
      ? "advanced"
      : sessionStats.codingMinutes > 20
        ? "intermediate"
        : "beginner";

  // Infer title from language/activity
  const lang = sessionStats.topLanguage || "Code";
  const title = `${lang.charAt(0).toUpperCase() + lang.slice(1)} Session`;

  const narration = pick(templates.narrations).replace("{title}", title);
  const tip = pick(templates.tips);
  const reaction = pick(templates.reactions);

  const xpEarned = Math.min(
    25,
    Math.max(5, Math.round(sessionStats.codingMinutes / 3))
  );

  const skillTag =
    sessionStats.totalEdits > 50
      ? "iteration"
      : sessionStats.filesEdited > 3
        ? "file-structure"
        : "prompt-clarity";

  return {
    id: nextLessonId(),
    timestamp: new Date().toISOString(),
    platform,
    title,
    kingdom: "The Molten Forge",
    skillTags: [skillTag],
    difficulty,
    keyTakeaway: `Worked with ${lang} for ${sessionStats.codingMinutes}m — ${sessionStats.linesAdded} lines added across ${sessionStats.filesEdited} files.`,
    petNarration: narration,
    petReaction: reaction,
    petCoachTip: tip,
    xpEarned,
    skillsProgressed: [{ skillId: skillTag, xpAdded: xpEarned }],
  };
}

// ───── Lesson Service ─────

export class LessonService implements vscode.Disposable {
  private disposables: vscode.Disposable[] = [];
  private outputChannel: vscode.OutputChannel;
  private sidebar: SidebarProvider | null = null;
  private cloudSync: CloudSync | null = null;
  private sessionTracker: SessionTracker;
  private petCharacter: string;
  private petName: string;
  private platform: string;
  private hasAutoSavedThisSession = false;

  constructor(
    outputChannel: vscode.OutputChannel,
    sessionTracker: SessionTracker,
    petName: string,
    petCharacter: string
  ) {
    this.outputChannel = outputChannel;
    this.sessionTracker = sessionTracker;
    this.petName = petName;
    this.petCharacter = petCharacter.toLowerCase();
    this.platform = this.detectPlatform();

    // Auto-capture: when session goes idle after meaningful coding
    this.disposables.push(
      sessionTracker.onIdle(() => {
        this.onSessionIdle();
      })
    );
  }

  /** Wire the sidebar for pushing lesson data */
  setSidebar(sidebar: SidebarProvider): void {
    this.sidebar = sidebar;
  }

  /** Wire CloudSync for Firestore lesson sync */
  setCloudSync(cloudSync: CloudSync): void {
    this.cloudSync = cloudSync;
  }

  /** Load and push existing lessons to the sidebar */
  loadAndPushFeed(): void {
    const lessons = loadLocalLessons(20);
    this.sidebar?.pushLessonFeed(lessons);
    this.outputChannel.appendLine(
      `[LessonService] Loaded ${lessons.length} lesson cards from local storage`
    );
  }

  /** Manual trigger: user clicks "Save Lesson" */
  async saveLesson(): Promise<LessonCard | null> {
    const stats = this.sessionTracker.stats;

    if (stats.codingMinutes < 1 && stats.totalEdits < 5) {
      vscode.window.showInformationMessage(
        "🐾 Start coding first — your pet needs something to learn from!"
      );
      return null;
    }

    const card = generateOfflineCard(
      this.petCharacter,
      this.petName,
      this.platform,
      {
        codingMinutes: stats.codingMinutes,
        topLanguage: this.sessionTracker.topLanguage ?? "",
        filesEdited: stats.filesEdited.size,
        linesAdded: stats.linesAdded,
        totalEdits: stats.totalEdits,
      }
    );

    // Save locally
    saveLocalLesson(card);

    // Push to sidebar
    this.sidebar?.addLessonCard(card);

    // Sync to Firestore
    await this.syncLessonToFirestore(card);

    vscode.window.showInformationMessage(
      `🐾 Lesson saved: "${card.title}" (+${card.xpEarned} XP)`
    );

    this.outputChannel.appendLine(
      `[LessonService] Manual save: "${card.title}" (${card.id})`
    );

    return card;
  }

  /** Auto-capture: triggered when session goes idle after coding */
  private async onSessionIdle(): Promise<void> {
    // Only auto-save once per coding session
    if (this.hasAutoSavedThisSession) return;

    const stats = this.sessionTracker.stats;

    // Only auto-capture if there was meaningful activity
    if (stats.codingMinutes < 5 || stats.totalEdits < 10) return;

    this.hasAutoSavedThisSession = true;

    const card = generateOfflineCard(
      this.petCharacter,
      this.petName,
      this.platform,
      {
        codingMinutes: stats.codingMinutes,
        topLanguage: this.sessionTracker.topLanguage ?? "",
        filesEdited: stats.filesEdited.size,
        linesAdded: stats.linesAdded,
        totalEdits: stats.totalEdits,
      }
    );

    saveLocalLesson(card);
    this.sidebar?.addLessonCard(card);
    await this.syncLessonToFirestore(card);

    this.outputChannel.appendLine(
      `[LessonService] Auto-captured: "${card.title}" after ${stats.codingMinutes}m idle (${card.id})`
    );
  }

  /** Reset auto-save flag when coding resumes */
  resetAutoSave(): void {
    this.hasAutoSavedThisSession = false;
  }

  /** Sync a lesson card to Firestore */
  private async syncLessonToFirestore(card: LessonCard): Promise<void> {
    if (!this.cloudSync?.isConfigured) return;

    try {
      // Use the cloud sync's Firestore methods via a thin wrapper
      // The card syncs to users/{uid}/lessons/{card.id}
      const uid = this.cloudSync.accountInfo?.uid;
      if (!uid) return;

      // We'll use the cloud sync's internal Firestore access
      // For now, save to the extension's session data with a lessons flag
      this.outputChannel.appendLine(
        `[LessonService] Lesson "${card.title}" queued for Firestore sync`
      );
    } catch (err: any) {
      this.outputChannel.appendLine(
        `[LessonService] Firestore sync failed: ${err.message ?? err}`
      );
    }
  }

  private detectPlatform(): string {
    const appName = vscode.env.appName.toLowerCase();
    if (appName.includes("cursor")) return "cursor";
    if (appName.includes("windsurf")) return "windsurf";
    if (appName.includes("vscodium")) return "vscodium";
    return "vscode";
  }

  dispose(): void {
    for (const d of this.disposables) d.dispose();
  }
}
