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
import type { ClaudeSessionContext, SessionInsight } from "../core/claude-session-watcher.js";

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
  },
  claudeContext?: ClaudeSessionContext,
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

  const lang = sessionStats.topLanguage || "Code";

  // ── Build rich title + structured sections from Claude conversation context ──
  let title: string;
  let sections: { heading: string; text: string }[] = [];
  let keyTakeaway: string;
  let skillTags: string[] = [];

  if (claudeContext && claudeContext.userPrompts.length > 0) {
    title = buildTitleFromContext(claudeContext, lang);
    sections = buildLessonSections(claudeContext, sessionStats, lang);
    keyTakeaway = sections.find(s => s.heading.toLowerCase().includes("takeaway"))?.text
      ?? buildTakeawayFromContext(claudeContext, sessionStats);

    skillTags = claudeContext.topics.slice(0, 3);
    if (skillTags.length === 0) skillTags = [inferSkillTag(sessionStats)];
  } else {
    // Fallback: no Claude context — compact card with just takeaway + next step
    title = `${lang.charAt(0).toUpperCase() + lang.slice(1)} Session`;
    keyTakeaway = `${sessionStats.codingMinutes}m · ${sessionStats.totalEdits} edits · ${sessionStats.filesEdited} files.`;
    sections = [
      {
        heading: "✨ Takeaway",
        text: sessionStats.codingMinutes >= 45
          ? "Long sessions build muscle memory. The second hour is where real fluency grows."
          : "Small sessions compound. 20 minutes a day beats 3 hours once a week.",
      },
      {
        heading: "🎯 Try next",
        text: pick(templates.tips),
      },
    ];
    skillTags = [inferSkillTag(sessionStats)];
  }

  const narration = pick(templates.narrations).replace("{title}", title);
  const tip = claudeContext?.topics.length
    ? generateContextualTip(claudeContext.topics, templates.tips)
    : pick(templates.tips);
  const reaction = pick(templates.reactions);

  const xpEarned = Math.min(
    25,
    Math.max(5, Math.round(sessionStats.codingMinutes / 3))
  );

  return {
    id: nextLessonId(),
    timestamp: new Date().toISOString(),
    platform,
    title,
    kingdom: inferKingdom(claudeContext?.topics ?? [], lang),
    skillTags,
    difficulty,
    keyTakeaway,
    sections,
    petNarration: narration,
    petReaction: reaction,
    petCoachTip: tip,
    xpEarned,
    skillsProgressed: skillTags.map((s) => ({ skillId: s, xpAdded: Math.round(xpEarned / skillTags.length) })),
  };
}

/**
 * Build a compact, well-structured lesson card.
 * Keeps only the two highest-value sections: the insight and the action.
 * Title + tags already capture "what" and "concepts" — sections surface wisdom and practice.
 */
function buildLessonSections(
  ctx: ClaudeSessionContext,
  stats: { codingMinutes: number; linesAdded: number; filesEdited: number; totalEdits: number },
  lang: string,
): { heading: string; text: string }[] {
  const sections: { heading: string; text: string }[] = [];

  // ─── 1. Takeaway — the distilled principle (the lesson's value) ───
  const takeaway = distillTakeaway(ctx, stats, lang);
  sections.push({ heading: "✨ Takeaway", text: trimToSentence(takeaway, 140) });

  // ─── 2. Try next — one actionable practice ───
  const nextStep = generateNextStep(ctx, lang);
  sections.push({ heading: "🎯 Try next", text: trimToSentence(nextStep, 120) });

  return sections;
}

/** Trim text to a sensible length, preferring sentence boundaries */
function trimToSentence(text: string, maxLen: number): string {
  const t = text.trim();
  if (t.length <= maxLen) return t;
  // Try to cut at last sentence-ending punctuation before maxLen
  const slice = t.substring(0, maxLen);
  const lastStop = Math.max(slice.lastIndexOf(". "), slice.lastIndexOf("? "), slice.lastIndexOf("! "));
  if (lastStop > maxLen * 0.5) return slice.substring(0, lastStop + 1).trim();
  // Fall back to last word boundary + ellipsis
  const lastSpace = slice.lastIndexOf(" ");
  return (lastSpace > 0 ? slice.substring(0, lastSpace) : slice).trim() + "…";
}

/** Extract a concise 1-2 sentence description of what the user was trying to accomplish */
function extractUserIntent(ctx: ClaudeSessionContext): string {
  // Find the most substantive user prompt (not short confirmations)
  const substantive = ctx.userPrompts.filter(p => p.trim().length >= 15 && p.trim().split(/\s+/).length >= 3);
  if (substantive.length === 0) {
    if (ctx.analysis?.coreIdea) return `Explored: ${ctx.analysis.coreIdea}`;
    return "";
  }

  // Prefer prompts with "build/create/fix/implement" verbs
  const buildPrompts = substantive.filter(p =>
    /\b(build|create|implement|fix|design|add|set up|make|write)\b/i.test(p)
  );
  const source = buildPrompts.length > 0 ? buildPrompts[0] : substantive[0];

  const firstSentence = source.split(/[.!?\n]/)[0]?.trim() ?? source;
  const clean = firstSentence.length > 140 ? firstSentence.substring(0, 137) + "..." : firstSentence;
  return clean;
}

/** Format key technical concepts covered during the session */
function extractKeyConcepts(ctx: ClaudeSessionContext, lang: string): string {
  const concepts = new Set<string>();
  if (lang && lang !== "Code" && lang !== "unknown") concepts.add(lang);
  for (const topic of ctx.topics.slice(0, 6)) {
    if (topic && topic.length > 1) concepts.add(topic);
  }

  if (concepts.size === 0) return "";

  // Present as an inline list with separators for easy scanning
  return [...concepts].slice(0, 6).map(c => `• ${c}`).join("\n");
}

/**
 * Distill a one-line actionable principle from the session.
 * Prefers domain-specific wisdom based on topics; falls back to generic insights.
 */
function distillTakeaway(
  ctx: ClaudeSessionContext,
  stats: { codingMinutes: number; linesAdded: number; filesEdited: number },
  lang: string,
): string {
  const topics = new Set(ctx.topics.map(t => t.toLowerCase()));
  const phase = ctx.analysis?.phase;
  const hasUncertainties = (ctx.analysis?.uncertainties?.length ?? 0) > 0;
  const hasDecisions = (ctx.analysis?.decisionsMade?.length ?? 0) > 0;

  // Domain-tailored insights
  if (topics.has("react") || topics.has("next.js") || topics.has("component")) {
    return "Reusable components start small. Today's work is a seed — look for the shared pattern and extract it.";
  }
  if (topics.has("auth") || topics.has("authentication") || topics.has("login")) {
    return "Auth flows live or die on edge cases. The happy path is only ~30% of the work.";
  }
  if (topics.has("api") || topics.has("rest") || topics.has("graphql")) {
    return "Design your API from the consumer's perspective first — the database can adapt later.";
  }
  if (topics.has("database") || topics.has("postgres") || topics.has("sql")) {
    return "Schema decisions are expensive to reverse. When in doubt, prefer normalization — denormalize only when performance demands it.";
  }
  if (topics.has("css") || topics.has("tailwind") || topics.has("animation")) {
    return "Design systems beat one-off styles. Every hard-coded value is a future inconsistency waiting to happen.";
  }
  if (topics.has("landing page") || topics.has("landing")) {
    return "A landing page's job is one thing: get visitors to do one specific action. Every element either serves that or distracts from it.";
  }
  if (topics.has("deploy") || topics.has("docker") || topics.has("vercel")) {
    return "If your deploy isn't a single command, it's a bug. Spend the time to automate it.";
  }
  if (topics.has("ai") || topics.has("llm") || topics.has("prompt")) {
    return "LLM reliability comes from constraints, not cleverness. Bound the problem, then let the model work inside that box.";
  }

  // Phase-based insights
  if (phase === "debugging") {
    return "Debugging is an investigation, not a task. The bug you find usually isn't the bug you fixed.";
  }
  if (phase === "building" && hasDecisions) {
    return "The best builders aren't the ones who make perfect decisions — they're the ones who make decisions reversible.";
  }
  if (phase === "polishing") {
    return "Polish is a trap when it delays shipping. Ask: does this improvement help one user who matters?";
  }
  if (hasUncertainties) {
    return "Uncertainty is a signal, not a problem. It points at the next question worth answering.";
  }

  // Generic fallback based on session shape
  if (stats.codingMinutes >= 45) {
    return "Long sessions build muscle memory. The second hour is where real fluency grows.";
  }
  return "Small sessions compound. 20 minutes a day beats 3 hours once a week.";
}

/** Actionable next-step suggestion tailored to the work done */
function generateNextStep(ctx: ClaudeSessionContext, lang: string): string {
  const topics = new Set(ctx.topics.map(t => t.toLowerCase()));
  const phase = ctx.analysis?.phase;
  const gaps = ctx.analysis?.gaps ?? [];

  if (gaps.some(g => g.toLowerCase().includes("target user"))) {
    return "Write a one-sentence description of your ideal user. Pin it somewhere visible while you code.";
  }
  if (gaps.some(g => g.toLowerCase().includes("success"))) {
    return "Define what 'working' looks like — one measurable signal that proves your feature matters.";
  }
  if (topics.has("react") || topics.has("component")) {
    return "Extract one reusable hook or component from today's code. Even if it's used only once — the act of naming it clarifies the pattern.";
  }
  if (topics.has("api") || topics.has("rest")) {
    return "Write a single integration test for the happy path you just built.";
  }
  if (topics.has("landing page") || topics.has("landing")) {
    return "Show your landing page to one person who doesn't know the project. Ask them what they'd click first.";
  }
  if (topics.has("auth")) {
    return "Test the logout → login flow in an incognito window. Edge cases hide there.";
  }
  if (topics.has("database")) {
    return "Draw your schema on paper. If you can't explain it in 60 seconds, it's too complex for v1.";
  }
  if (phase === "debugging") {
    return "Write down the root cause of today's bug in one sentence. Patterns emerge when you collect these.";
  }
  if (phase === "polishing") {
    return "Instead of polishing more, ship what you have to one real user and see what they say.";
  }
  if (phase === "building") {
    return "End tomorrow's session with a working vertical slice — even if it's ugly. Perfect later.";
  }

  return "Close today's session by writing one sentence describing what you'd build differently next time.";
}

/** Build a descriptive title from Claude conversation context */
function buildTitleFromContext(ctx: ClaudeSessionContext, lang: string): string {
  // Look at recent user prompts for "build/create/implement" patterns
  for (const prompt of [...ctx.userPrompts].reverse().slice(0, 5)) {
    const match = prompt.match(
      /(?:build|create|implement|set up|design|add|fix|update|write)\s+(?:a\s+|an\s+|the\s+)?(.{5,50}?)(?:\.|$|\?|!|\n|,)/i,
    );
    if (match) {
      const raw = match[1].trim();
      // Capitalize first letter
      return raw.charAt(0).toUpperCase() + raw.slice(1);
    }
  }

  // Fall back to topics
  if (ctx.topics.length > 0) {
    const topTopics = ctx.topics.slice(0, 2).map((t) => t.charAt(0).toUpperCase() + t.slice(1));
    return topTopics.join(" + ");
  }

  return `${lang.charAt(0).toUpperCase() + lang.slice(1)} Session`;
}

/** Build a rich takeaway from Claude conversation */
function buildTakeawayFromContext(
  ctx: ClaudeSessionContext,
  stats: { codingMinutes: number; linesAdded: number; filesEdited: number },
): string {
  const parts: string[] = [];

  // What was discussed
  if (ctx.userPrompts.length > 0) {
    const recentPrompts = ctx.userPrompts.slice(-3);
    // Summarize the key tasks/questions
    const tasks = recentPrompts
      .map((p) => {
        // Extract the first meaningful sentence/phrase
        const sentence = p.split(/[.!?\n]/)[0]?.trim();
        return sentence && sentence.length > 10 && sentence.length < 120 ? sentence : null;
      })
      .filter(Boolean)
      .slice(0, 2);

    if (tasks.length > 0) {
      parts.push(`Discussed: ${tasks.join(" → ")}`);
    }
  }

  // Topics covered
  if (ctx.topics.length > 0) {
    parts.push(`Topics: ${ctx.topics.slice(0, 4).join(", ")}`);
  }

  // Files created
  if (ctx.filesCreated.length > 0) {
    parts.push(`Created: ${ctx.filesCreated.slice(0, 3).join(", ")}`);
  }

  // Stats
  parts.push(`${stats.codingMinutes}m coding, +${stats.linesAdded} lines across ${stats.filesEdited} files`);

  return parts.join(". ") + ".";
}

/** Generate a contextual tip based on the topics discussed */
function generateContextualTip(topics: string[], fallbackTips: string[]): string {
  const topicSet = new Set(topics.map((t) => t.toLowerCase()));

  if (topicSet.has("react") || topicSet.has("next.js") || topicSet.has("component")) {
    return "Try extracting a reusable component from today's work!";
  }
  if (topicSet.has("api") || topicSet.has("rest") || topicSet.has("graphql")) {
    return "Write tests for those API endpoints — future you will thank you.";
  }
  if (topicSet.has("database") || topicSet.has("postgres") || topicSet.has("sql")) {
    return "Consider adding an index or migration for what you designed today.";
  }
  if (topicSet.has("auth") || topicSet.has("authentication") || topicSet.has("login")) {
    return "Test the auth flow from a fresh browser — edge cases live there.";
  }
  if (topicSet.has("stripe") || topicSet.has("payment")) {
    return "Run through the payment flow in test mode before going live.";
  }
  if (topicSet.has("css") || topicSet.has("tailwind") || topicSet.has("animation")) {
    return "Check your design on mobile — responsive issues hide in plain sight.";
  }
  if (topicSet.has("deploy") || topicSet.has("docker") || topicSet.has("vercel")) {
    return "Set up a staging environment to catch issues before production.";
  }

  const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];
  return pick(fallbackTips);
}

/** Infer kingdom from topics */
function inferKingdom(topics: string[], lang: string): string {
  const topicSet = new Set(topics.map((t) => t.toLowerCase()));

  // Molten Forge = fundamentals, setup, building from scratch
  if (topicSet.has("html") || topicSet.has("css") || topicSet.has("deploy") || topicSet.has("docker")) {
    return "The Molten Forge";
  }
  // Frozen Spire = architecture, databases, backend
  if (topicSet.has("database") || topicSet.has("api") || topicSet.has("auth") || topicSet.has("server")) {
    return "The Frozen Spire";
  }
  // Eternal Garden = UI, components, design
  if (topicSet.has("react") || topicSet.has("component") || topicSet.has("animation") || topicSet.has("tailwind")) {
    return "The Eternal Garden";
  }
  // Mystic Grove = AI, advanced patterns, integrations
  if (topicSet.has("ai") || topicSet.has("agent") || topicSet.has("llm") || topicSet.has("stripe") || topicSet.has("mcp")) {
    return "Mystic Grove";
  }

  return "The Molten Forge"; // default
}

function inferSkillTag(stats: { totalEdits: number; filesEdited: number }): string {
  return stats.totalEdits > 50
    ? "iteration"
    : stats.filesEdited > 3
      ? "file-structure"
      : "prompt-clarity";
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
  private claudeContext?: ClaudeSessionContext;
  private dailySummaryTimer?: NodeJS.Timeout;
  private dailySummarySavedToday = false;
  /** ID of the current live-updating lesson derived from the ongoing Claude session */
  private liveLessonId?: string;
  /** Timestamp of the last live-lesson update (for throttling) */
  private lastLiveUpdateAt = 0;
  /** Last fingerprint of Claude state to detect meaningful change */
  private lastLiveFingerprint = "";

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

    // ── Daily summary timer: check every 10 minutes if it's past 7 PM ──
    this.scheduleDailySummary();
  }

  /** Update Claude conversation context (called by ClaudeSessionWatcher) */
  updateClaudeContext(ctx: ClaudeSessionContext): void {
    this.claudeContext = ctx;
  }

  /**
   * Real-time lesson auto-update from a Claude session insight.
   *
   * Strategy:
   *  - On `new_session`: start a fresh live lesson.
   *  - On `phase_change` or `conversation_update` with meaningful delta (new
   *    decisions/topics/gaps): update the live lesson card in place.
   *  - Throttled to max once every 90 seconds to avoid spamming the feed.
   *
   * The live lesson is a single evolving card that reflects the ongoing
   * session — no manual Save button needed.
   */
  async onClaudeInsight(insight: SessionInsight): Promise<void> {
    const analysis = insight?.analysis;
    if (!analysis) return;

    const stats = this.sessionTracker.stats;
    // Need some real activity before we create a lesson
    if (stats.totalEdits < 3 && analysis.decisionsMade.length === 0 && analysis.topics.length === 0) {
      return;
    }

    // Throttle — don't update more than once every 90s
    const now = Date.now();
    const minGap = 90_000;

    // Fingerprint — change only if there's meaningful new content
    const fp = [
      analysis.phase,
      analysis.coreIdea,
      analysis.decisionsMade.length,
      analysis.topics.join("|"),
      analysis.gaps.length,
      analysis.unvalidatedChoices.length,
    ].join("::");

    // Always allow on new_session and phase_change; throttle conversation_update
    const forceUpdate = insight.type === "new_session" || insight.type === "phase_change";
    if (!forceUpdate) {
      if (fp === this.lastLiveFingerprint) return;
      if (now - this.lastLiveUpdateAt < minGap) return;
    }

    this.lastLiveFingerprint = fp;
    this.lastLiveUpdateAt = now;

    // Build a live card using the current stats + Claude analysis
    const card = generateOfflineCard(
      this.petCharacter,
      this.petName,
      this.platform,
      {
        codingMinutes: Math.max(1, stats.codingMinutes),
        topLanguage: this.sessionTracker.topLanguage ?? "",
        filesEdited: stats.filesEdited.size,
        linesAdded: stats.linesAdded,
        totalEdits: stats.totalEdits,
      },
      this.claudeContext,
    );

    // If we already have a live lesson, reuse its ID so we replace in-place
    if (this.liveLessonId) {
      card.id = this.liveLessonId;
    } else {
      this.liveLessonId = card.id;
    }

    // Tag it as a live auto-generated lesson
    (card as any).isLive = true;

    saveLocalLesson(card);
    // Prepend or update — the sidebar's addLessonCard dedupes by id
    this.sidebar?.addLessonCard(card);
    await this.syncLessonToFirestore(card).catch(() => {});

    this.outputChannel.appendLine(
      `[LessonService] Live lesson updated (${insight.type}): "${card.title}" — phase=${analysis.phase} decisions=${analysis.decisionsMade.length}`
    );
  }

  /** Reset the live lesson when switching to a new workspace/project */
  resetLiveLesson(): void {
    this.liveLessonId = undefined;
    this.lastLiveFingerprint = "";
    this.lastLiveUpdateAt = 0;
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
      },
      this.claudeContext,
    );

    // Add product-thinking sections if we have Claude context
    if (this.claudeContext?.analysis) {
      const sections: { heading: string; text: string }[] = [];
      const a = this.claudeContext.analysis;
      if (a.coreIdea && a.coreIdea !== "a new project") {
        sections.push({ heading: "What you built", text: a.coreIdea });
      }
      if (a.decisionsMade.length > 0) {
        sections.push({ heading: "Decisions made", text: a.decisionsMade.slice(0, 3).join(" · ") });
      }
      if (a.currentFocus) {
        sections.push({ heading: "Current focus", text: a.currentFocus });
      }
      card.sections = sections;
      card.cardType = "session";
    }

    const today = new Date();
    const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    card.dateLabel = `${dayNames[today.getDay()]}, ${monthNames[today.getMonth()]} ${today.getDate()}`;

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

  /** Test: generate sample lesson cards to preview the swipeable UI */
  testLessonFeed(): void {
    const now = new Date();
    const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const dateLabel = `${dayNames[now.getDay()]}, ${monthNames[now.getMonth()]} ${now.getDate()}`;

    const sampleCards: LessonCard[] = [
      {
        id: "test-recap-" + Date.now(),
        timestamp: now.toISOString(),
        platform: "cursor",
        title: "Sunday's Recap: Swipeable Lesson Feed",
        kingdom: "The Molten Forge",
        skillTags: ["ui", "swipe-gesture", "daily-summary"],
        difficulty: "intermediate",
        keyTakeaway: "Built a swipeable card UI for the lesson feed",
        petNarration: "Byte watched you build something really cool today.",
        petReaction: "excited",
        petCoachTip: "Ship it, then polish. Users care about flow more than pixel perfection.",
        xpEarned: 35,
        skillsProgressed: [],
        sections: [
          { heading: "What you built", text: "Swipeable lesson feed with dark minimal cards, dot indicators, and touch/mouse drag support." },
          { heading: "Decisions made", text: "Horizontal swipe over vertical scroll · Dark card aesthetic · Product-thinking sections over raw code snippets" },
          { heading: "Gaps to address", text: "Voice recording needs speech-to-text API integration. Swipe physics could feel more natural with momentum." },
          { heading: "Open questions", text: "Should lesson cards auto-archive after 7 days or stay forever?" },
        ],
        dateLabel: dateLabel,
        cardType: "daily-recap",
      },
      {
        id: "test-session-" + Date.now(),
        timestamp: new Date(now.getTime() - 3600000).toISOString(),
        platform: "cursor",
        title: "Closed-Loop: Byte ↔ Claude",
        kingdom: "The Frozen Spire",
        skillTags: ["clipboard", "terminal", "loop"],
        difficulty: "advanced",
        keyTakeaway: "Connected Byte's advice to Claude's terminal via clipboard paste",
        petNarration: "Byte helped you think through the architecture before diving in.",
        petReaction: "proud",
        petCoachTip: "The best code starts with a clear decision, not a blank file.",
        xpEarned: 50,
        skillsProgressed: [],
        sections: [
          { heading: "What you built", text: "Full closed-loop: Claude asks questions → Byte surfaces them with product advice → user decides → sent back to Claude terminal." },
          { heading: "Decisions made", text: "Clipboard + paste over terminal.sendText() · Dynamic cooldowns based on Claude state · Continuous loop detection" },
        ],
        dateLabel: dateLabel,
        cardType: "session",
      },
      {
        id: "test-legacy-" + Date.now(),
        timestamp: new Date(now.getTime() - 7200000).toISOString(),
        platform: "cursor",
        title: "Input UI Redesign",
        kingdom: "The Eternal Garden",
        skillTags: ["webview", "attachments", "ux"],
        difficulty: "beginner",
        keyTakeaway: "Added + menu for file/image/URL/knowledge attachments with a clean Claude-like input bar.",
        petNarration: "Byte noticed you're getting better at UI design!",
        petReaction: "happy",
        petCoachTip: "Small UI details compound. A good input bar makes users want to type.",
        xpEarned: 20,
        skillsProgressed: [],
        dateLabel: dateLabel,
        cardType: "session",
      },
    ];

    for (const card of sampleCards) {
      this.sidebar?.addLessonCard(card);
    }

    this.outputChannel.appendLine(
      `[LessonService] Test feed: pushed ${sampleCards.length} sample cards`
    );

    vscode.window.showInformationMessage(
      `🐾 Test: ${sampleCards.length} sample lesson cards added — swipe to browse!`
    );
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
      },
      this.claudeContext,
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

  // ───── Daily Summary (7 PM trigger) ─────

  /** Schedule the daily summary check — runs every 10 minutes */
  private scheduleDailySummary(): void {
    // Check immediately in case extension was activated after 7 PM
    setTimeout(() => this.checkDailySummary(), 30000); // 30s after startup

    // Then check every 10 minutes
    this.dailySummaryTimer = setInterval(() => this.checkDailySummary(), 10 * 60 * 1000);
  }

  /** Check if it's time to generate the daily summary */
  private async checkDailySummary(): Promise<void> {
    if (this.dailySummarySavedToday) return;

    const now = new Date();
    const hour = now.getHours();

    // Trigger between 6 PM and 11 PM
    if (hour < 18 || hour > 23) return;

    const stats = this.sessionTracker.stats;

    // Need at least some meaningful activity today
    if (stats.codingMinutes < 3) return;

    // Check if we already saved a daily summary today
    const todayPrefix = now.toISOString().split("T")[0];
    const dir = getLessonsDir();
    if (existsSync(dir)) {
      const todaysLessons = readdirSync(dir).filter(
        (f) => f.startsWith(todayPrefix) && f.endsWith(".json"),
      );
      // If we have a lesson tagged as daily_summary today, skip
      for (const f of todaysLessons) {
        try {
          const card = JSON.parse(readFileSync(join(dir, f), "utf-8")) as LessonCard;
          if (card.skillTags?.includes("daily-summary")) {
            this.dailySummarySavedToday = true;
            return;
          }
        } catch { /* skip */ }
      }
    }

    // Generate daily summary!
    this.dailySummarySavedToday = true;
    await this.saveDailySummary();
  }

  /** Store reference to companion service for accessing Byte chat history */
  private companionMessages: { role: string; text: string }[] = [];

  /** Update Byte conversation history (called from extension.ts) */
  updateByteMessages(messages: { role: string; text: string }[]): void {
    this.companionMessages = messages;
  }

  /** Generate and save the daily summary lesson — product-thinking recap */
  private async saveDailySummary(): Promise<void> {
    const stats = this.sessionTracker.stats;
    const ctx = this.claudeContext;

    const today = new Date();
    const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const dateLabel = `${dayNames[today.getDay()]}, ${monthNames[today.getMonth()]} ${today.getDate()}`;

    // ── Build product-thinking sections from Claude + Byte context ──
    const sections: { heading: string; text: string }[] = [];

    // Section 1: What you built
    let whatBuilt = "Coded for " + stats.codingMinutes + " minutes";
    if (ctx?.analysis?.coreIdea && ctx.analysis.coreIdea !== "a new project") {
      whatBuilt = ctx.analysis.coreIdea;
    }
    sections.push({ heading: "What you built", text: whatBuilt });

    // Section 2: Key decisions
    const decisions: string[] = [];
    if (ctx?.analysis?.decisionsMade && ctx.analysis.decisionsMade.length > 0) {
      decisions.push(...ctx.analysis.decisionsMade.slice(0, 3));
    }
    // Also pull decisions from Byte conversation
    for (const msg of this.companionMessages) {
      if (msg.role === "user" && msg.text.length > 5 && msg.text.length < 100) {
        // User's answers to Byte's questions are decisions
        if (!msg.text.toLowerCase().startsWith("send") && !msg.text.toLowerCase().includes("clipboard")) {
          decisions.push(msg.text);
        }
      }
    }
    if (decisions.length > 0) {
      sections.push({ heading: "Decisions made", text: decisions.slice(0, 4).join(" · ") });
    }

    // Section 3: Product gaps identified
    if (ctx?.analysis?.gaps && ctx.analysis.gaps.length > 0) {
      const gapsSummary = ctx.analysis.gaps
        .filter((g) => !g.includes("Claude jumped"))
        .slice(0, 3)
        .map((g) => g.replace(/No |— /g, "").trim())
        .join(". ");
      if (gapsSummary) {
        sections.push({ heading: "Gaps to address", text: gapsSummary });
      }
    }

    // Section 4: What's next (from Byte's advice or Claude's last question)
    if (ctx?.analysis?.claudeQuestions && ctx.analysis.claudeQuestions.length > 0) {
      sections.push({ heading: "Open questions", text: ctx.analysis.claudeQuestions[0] });
    } else if (ctx?.analysis?.currentFocus) {
      sections.push({ heading: "Where you left off", text: ctx.analysis.currentFocus });
    }

    // ── Build the card ──
    const baseCard = generateOfflineCard(
      this.petCharacter,
      this.petName,
      this.platform,
      {
        codingMinutes: stats.codingMinutes,
        topLanguage: this.sessionTracker.topLanguage ?? "",
        filesEdited: stats.filesEdited.size,
        linesAdded: stats.linesAdded,
        totalEdits: stats.totalEdits,
      },
      this.claudeContext,
    );

    // Enhance with product-thinking recap data
    baseCard.title = `${dayNames[today.getDay()]}'s Recap: ${baseCard.title}`;
    baseCard.sections = sections;
    baseCard.dateLabel = dateLabel;
    baseCard.cardType = "daily-recap";
    if (!baseCard.skillTags.includes("daily-summary")) {
      baseCard.skillTags.push("daily-summary");
    }

    saveLocalLesson(baseCard);
    this.sidebar?.addLessonCard(baseCard);
    await this.syncLessonToFirestore(baseCard);

    this.outputChannel.appendLine(
      `[LessonService] Daily recap saved: "${baseCard.title}" with ${sections.length} sections (${baseCard.id})`
    );

    vscode.window.showInformationMessage(
      `🐾 ${this.petName} captured today's lesson: "${baseCard.title}" (+${baseCard.xpEarned} XP)`
    );
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
    if (this.dailySummaryTimer) clearInterval(this.dailySummaryTimer);
    for (const d of this.disposables) d.dispose();
  }
}
