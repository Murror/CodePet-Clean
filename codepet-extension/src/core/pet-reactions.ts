/**
 * PetReactions — Personality-driven messaging system for Codepet
 *
 * Each of the 8 Codepet characters has a distinct voice and reacts differently
 * to code quality findings. This module translates raw scan results into
 * empathetic, encouraging messages that follow two core philosophies:
 *
 * Atomic Habits:
 *   - Identity-based: "You're a developer who writes clean code" (not "you should fix this")
 *   - Non-judgmental: Like the Habits Scorecard — observe without blame
 *   - Two-Minute Rule: Suggestions are tiny, immediate, actionable
 *   - Satisfying: Celebrate clean code to close the reward loop
 *
 * Thinking in Systems:
 *   - Tight feedback loops: React immediately to code changes
 *   - Resilience: Multiple paths to improvement, no single "right way"
 *   - Leverage points: Target the developer's self-image (highest leverage)
 *   - Avoid system traps: Don't create dependency on external validation
 */

import type { ScanResult, ScanSummary, CodeFinding } from "./code-scanner.js";

// ───── Character Personalities ─────

export interface PetPersonality {
  name: string;
  emoji: string;
  trait: string; // one-word personality descriptor
  errorStyle: "gentle" | "curious" | "playful" | "wise" | "direct";
  celebrationStyle: "enthusiastic" | "calm" | "quirky" | "warm" | "proud";
}

const PERSONALITIES: Record<string, PetPersonality> = {
  byte: {
    name: "Byte",
    emoji: "🤖",
    trait: "analytical",
    errorStyle: "curious",
    celebrationStyle: "calm",
  },
  nova: {
    name: "Nova",
    emoji: "🌟",
    trait: "encouraging",
    errorStyle: "gentle",
    celebrationStyle: "enthusiastic",
  },
  crash: {
    name: "Crash",
    emoji: "💥",
    trait: "bold",
    errorStyle: "direct",
    celebrationStyle: "enthusiastic",
  },
  luna: {
    name: "Luna",
    emoji: "🌙",
    trait: "thoughtful",
    errorStyle: "wise",
    celebrationStyle: "warm",
  },
  sage: {
    name: "Sage",
    emoji: "🌿",
    trait: "patient",
    errorStyle: "wise",
    celebrationStyle: "calm",
  },
  glitch: {
    name: "Glitch",
    emoji: "⚡",
    trait: "energetic",
    errorStyle: "playful",
    celebrationStyle: "quirky",
  },
  zero: {
    name: "Zero",
    emoji: "🔮",
    trait: "mysterious",
    errorStyle: "curious",
    celebrationStyle: "proud",
  },
  null: {
    name: "Null",
    emoji: "👻",
    trait: "witty",
    errorStyle: "playful",
    celebrationStyle: "quirky",
  },
};

// ───── Reaction types ─────

export type ReactionMood = "worried" | "curious" | "happy" | "proud" | "sleepy" | "neutral";

export interface PetReaction {
  mood: ReactionMood;
  emoji: string;
  message: string;
  detail?: string; // longer explanation for sidebar
  actionLabel?: string; // e.g. "Fix this"
}

// ───── Message templates by style ─────

// Error messages — things are broken
const ERROR_MESSAGES: Record<PetPersonality["errorStyle"], string[]> = {
  gentle: [
    "Hmm, I noticed something on line {line}... {message}",
    "Something doesn't look quite right here — {message}",
    "Don't worry, but there might be an issue: {message}",
    "I think this might need a second look — {message}",
  ],
  curious: [
    "Interesting... line {line} has something unusual: {message}",
    "I'm curious about this one — {message}",
    "Wait, what's happening on line {line}? {message}",
    "That's unexpected — {message}. What do you think?",
  ],
  playful: [
    "Oops! Looks like line {line} is having a moment — {message}",
    "Found a little gremlin on line {line}: {message}",
    "Uh oh, something's being sneaky here — {message}",
    "Plot twist on line {line}! {message}",
  ],
  wise: [
    "A small thing to consider on line {line}: {message}",
    "Experience tells me this might cause trouble later — {message}",
    "Worth pausing on this one: {message}",
    "This is a common pattern that can lead to bugs — {message}",
  ],
  direct: [
    "Heads up — line {line}: {message}",
    "Found an issue: {message}",
    "This needs fixing — {message}",
    "Line {line} has a problem: {message}",
  ],
};

// Warning messages — things could be better
const WARNING_MESSAGES: Record<PetPersonality["errorStyle"], string[]> = {
  gentle: [
    "Just a thought — {message}. {suggestion}",
    "This works, but maybe... {suggestion}",
    "No rush, but when you get a chance: {message}",
    "A small improvement idea: {suggestion}",
  ],
  curious: [
    "What if we tried something different here? {suggestion}",
    "I wonder if there's a better way — {message}",
    "Have you considered: {suggestion}",
    "Interesting choice here. {suggestion}",
  ],
  playful: [
    "Not a big deal, but check this out — {suggestion}",
    "Your code called, it wants a tiny makeover: {suggestion}",
    "Spotted something fun to improve: {suggestion}",
    "Quick win alert! {suggestion}",
  ],
  wise: [
    "A pattern worth evolving: {message}. {suggestion}",
    "Small things compound. {suggestion}",
    "Future-you will thank you for this: {suggestion}",
    "One small change here creates ripple effects: {suggestion}",
  ],
  direct: [
    "Consider: {suggestion}",
    "Quick fix: {message}. {suggestion}",
    "Improvement: {suggestion}",
    "This could be better — {suggestion}",
  ],
};

// Clean/celebration messages — code is great!
const CLEAN_MESSAGES: Record<PetPersonality["celebrationStyle"], string[]> = {
  enthusiastic: [
    "This is looking amazing! Clean code everywhere!",
    "Zero issues! You're on fire today!",
    "Your code is sparkling! Keep this energy going!",
    "No problems found — you're building something great!",
  ],
  calm: [
    "Clean code. Nice and steady.",
    "Looking solid. No issues to report.",
    "Everything checks out. Good, consistent work.",
    "All clear. Your system is working well.",
  ],
  quirky: [
    "Your code is so clean I could eat off it... if I ate code.",
    "Zero bugs! I'm almost bored. Almost.",
    "Flawless! I tried to find something wrong and... nope.",
    "Is this code or poetry? I genuinely can't tell.",
  ],
  warm: [
    "Beautiful work. Every line tells me you care about quality.",
    "This feels good to read. Clean, thoughtful code.",
    "You should feel proud of this — it's well-crafted.",
    "The kind of code that makes your future self smile.",
  ],
  proud: [
    "Impressive. Not a single issue in this file.",
    "This is the code of someone who takes their craft seriously.",
    "Pristine. You've earned this clean score.",
    "Excellence in every line. This is what mastery looks like.",
  ],
};

// Summary messages — overall session health
const SUMMARY_GOOD: string[] = [
  "Your code health is strong today — {cleanScore}% clean across {totalFiles} files.",
  "{cleanFiles} out of {totalFiles} files are completely clean. Your habits are compounding.",
  "Clean score: {cleanScore}%. Every line of clean code is a vote for the developer you're becoming.",
  "Looking healthy! {cleanScore}% clean. Small improvements, big results over time.",
];

const SUMMARY_IMPROVING: string[] = [
  "Found {totalWarnings} things to improve across {totalFiles} files. Each fix makes the whole system stronger.",
  "{totalWarnings} small improvements available. Think of each one as a 1% gain.",
  "Some room to grow — {totalWarnings} suggestions waiting. No rush, pick the easiest one first.",
  "Your code is {cleanScore}% clean. A few tweaks and you'll be even higher.",
];

const SUMMARY_NEEDS_ATTENTION: string[] = [
  "{totalErrors} errors need attention. Start with just one — the Two-Minute Rule says that's enough.",
  "Some things need fixing, but don't be overwhelmed. Pick the smallest error and start there.",
  "Your pet notices {totalErrors} errors. Let's tackle them one at a time — that's how systems improve.",
  "{totalErrors} issues found. Remember: debugging isn't failing, it's learning. Each fix builds your skill.",
];

// ───── Main reaction generator ─────

export class PetReactionEngine {
  private petKey: string;

  constructor(petName: string = "nova") {
    this.petKey = petName.toLowerCase();
  }

  setPet(petName: string): void {
    this.petKey = petName.toLowerCase();
  }

  get personality(): PetPersonality {
    return PERSONALITIES[this.petKey] ?? PERSONALITIES.nova;
  }

  // React to a single finding
  reactToFinding(finding: CodeFinding): PetReaction {
    const p = this.personality;

    if (finding.severity === "clean") {
      return {
        mood: "happy",
        emoji: p.emoji,
        message: finding.message,
      };
    }

    if (finding.severity === "error") {
      const templates = ERROR_MESSAGES[p.errorStyle];
      const template = templates[Math.floor(Math.random() * templates.length)];
      return {
        mood: "worried",
        emoji: p.emoji,
        message: this.fillTemplate(template, finding),
        detail: finding.suggestion,
        actionLabel: finding.autoFixable ? "Fix this" : undefined,
      };
    }

    // Warning
    const templates = WARNING_MESSAGES[p.errorStyle];
    const template = templates[Math.floor(Math.random() * templates.length)];
    return {
      mood: "curious",
      emoji: p.emoji,
      message: this.fillTemplate(template, finding),
      detail: finding.suggestion,
    };
  }

  // React to a full scan result (one file)
  reactToScan(result: ScanResult): PetReaction {
    const p = this.personality;

    if (result.errorCount > 0) {
      const topError = result.findings.find((f) => f.severity === "error");
      return {
        mood: "worried",
        emoji: p.emoji,
        message: topError
          ? this.fillTemplate(
              ERROR_MESSAGES[p.errorStyle][0],
              topError
            )
          : `Found ${result.errorCount} issue${result.errorCount > 1 ? "s" : ""} to fix.`,
        detail: `${result.errorCount} error${result.errorCount > 1 ? "s" : ""}, ${result.warningCount} warning${result.warningCount > 1 ? "s" : ""} in this file.`,
      };
    }

    if (result.warningCount > 0) {
      const topWarning = result.findings.find((f) => f.severity === "warning");
      return {
        mood: "curious",
        emoji: p.emoji,
        message: topWarning
          ? this.fillTemplate(
              WARNING_MESSAGES[p.errorStyle][0],
              topWarning
            )
          : `${result.warningCount} thing${result.warningCount > 1 ? "s" : ""} to polish.`,
        detail: `Clean score: ${result.cleanScore}%`,
      };
    }

    // All clean!
    const templates = CLEAN_MESSAGES[p.celebrationStyle];
    return {
      mood: "happy",
      emoji: p.emoji,
      message: templates[Math.floor(Math.random() * templates.length)],
      detail: `Clean score: ${result.cleanScore}%`,
    };
  }

  // React to overall summary (all open files)
  reactToSummary(summary: ScanSummary): PetReaction {
    const p = this.personality;

    if (summary.totalErrors > 0) {
      const templates = SUMMARY_NEEDS_ATTENTION;
      const template = templates[Math.floor(Math.random() * templates.length)];
      return {
        mood: "worried",
        emoji: p.emoji,
        message: this.fillSummaryTemplate(template, summary),
      };
    }

    if (summary.totalWarnings > 3) {
      const templates = SUMMARY_IMPROVING;
      const template = templates[Math.floor(Math.random() * templates.length)];
      return {
        mood: "curious",
        emoji: p.emoji,
        message: this.fillSummaryTemplate(template, summary),
      };
    }

    // Clean!
    if (summary.totalFiles > 0) {
      const templates = SUMMARY_GOOD;
      const template = templates[Math.floor(Math.random() * templates.length)];
      return {
        mood: "proud",
        emoji: p.emoji,
        message: this.fillSummaryTemplate(template, summary),
      };
    }

    return {
      mood: "neutral",
      emoji: p.emoji,
      message: "Open a file and I'll keep an eye on your code quality.",
    };
  }

  // ───── Template helpers ─────

  private fillTemplate(template: string, finding: CodeFinding): string {
    return template
      .replace("{line}", String(finding.line + 1))
      .replace("{message}", finding.message)
      .replace("{suggestion}", finding.suggestion ?? "")
      .replace("{code}", finding.code);
  }

  private fillSummaryTemplate(template: string, summary: ScanSummary): string {
    return template
      .replace("{totalErrors}", String(summary.totalErrors))
      .replace("{totalWarnings}", String(summary.totalWarnings))
      .replace("{cleanFiles}", String(summary.cleanFiles))
      .replace("{totalFiles}", String(summary.totalFiles))
      .replace("{cleanScore}", String(summary.averageCleanScore))
      .replace("{topIssue}", summary.topIssue ?? "none");
  }
}
