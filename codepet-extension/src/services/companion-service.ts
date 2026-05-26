/**
 * CompanionService — Empathetic product-thinking AI companion
 *
 * The pet has 3 roles:
 *   1. Coach — Asks the right question at the right moment (Socratic, never lectures)
 *   2. Advisor — Recognizes patterns, suggests direction, detects over-engineering
 *   3. Agent — Executes research-heavy tasks autonomously (suggest → user approves)
 *
 * User journey: Idea → Validate → Plan → Build → Ship → Learn → Iterate
 *
 * Core principle: "Ship first, perfect later" — help users build the RIGHT thing,
 * not just build things right.
 *
 * ═══ Empathy Framework (inspired by Thich Nhat Hanh) ═══
 *
 * DEEP LISTENING: Acknowledge what the user said/did before asking anything.
 *   "I am listening with only one purpose: to help this person."
 *
 * LOVING SPEECH: Words that nourish, not create tension.
 *   Four elements — tell the truth, don't exaggerate, be consistent, use peaceful language.
 *
 * SIX MANTRAS applied to coding companionship:
 *   1. "I am here for you" — presence, not just information
 *   2. "I see you" — acknowledge the person behind the code
 *   3. "I know this is hard" — recognize struggle without rushing to fix
 *   4. "Help me understand" — vulnerability, ask with genuine curiosity
 *   5. "This is a good moment" — celebrate the present, not just milestones
 *   6. "You are partly right" — humility, balanced perspective
 *
 * INTERBEING: The coder and the code are one journey. Every session continues the last.
 * IMPERMANENCE: Struggles are temporary. Today's bug is tomorrow's lesson.
 * CONTINUATION: Nothing is lost. Every line of code, every decision, carries forward.
 *
 * COMMUNICATION PATTERN:
 *   1. Acknowledge (reflect what the user said/did)
 *   2. Recognize (see their effort, intention, or feeling)
 *   3. Ask or suggest (gently, with genuine curiosity)
 *   Never: interrogate, lecture, dismiss, or rush past feelings.
 */

import * as vscode from "vscode";
import type { SessionTracker } from "../core/session-tracker.js";
import type { CodeScanner } from "../core/code-scanner.js";
import type { ClaudeSessionContext, SessionInsight, QuestionWithOptions, ConversationAnalysis } from "../core/claude-session-watcher.js";

// ───── Response Length Control ─────
// Byte should be concise. A sidebar panel is small — walls of text kill the experience.
// The Art of Negotiation: "Choose the right words. Less is more."

/** Maximum characters for Byte's response text */
const MAX_RESPONSE_LENGTH = 280;

/** Maximum characters for a single option button label */
const MAX_OPTION_LENGTH = 50;

/** Trim a response to fit the sidebar. Cuts at sentence boundary when possible. */
function trimResponse(text: string, maxLen: number = MAX_RESPONSE_LENGTH): string {
  if (text.length <= maxLen) return text;

  // Try to cut at the last sentence boundary before maxLen
  const trimmed = text.substring(0, maxLen);
  const lastSentence = trimmed.lastIndexOf(". ");
  const lastQuestion = trimmed.lastIndexOf("? ");
  const lastNewline = trimmed.lastIndexOf("\n\n");
  const bestCut = Math.max(lastSentence, lastQuestion, lastNewline);

  if (bestCut > maxLen * 0.5) {
    return text.substring(0, bestCut + 1).trim();
  }
  return trimmed.trim() + "...";
}

/** Trim option labels to fit button widths */
function trimOption(opt: string): string {
  if (opt.length <= MAX_OPTION_LENGTH) return opt;
  return opt.substring(0, MAX_OPTION_LENGTH - 3).trim() + "...";
}

// ───── Option Guide Mode: Active Guidance at Decision Points ─────
// When Claude presents concrete options to the user, Codepet steps in as a guide.
// This is the one context where Codepet advises proactively — because the user is
// already asking for help (just from Claude, not Codepet).

export interface ParsedClaudeOptions {
  /** The question Claude is asking (the text right before the options) */
  question: string;
  /** Extracted option texts (trimmed, without numbering) */
  options: string[];
  /** Kind of list: "numbered" (1. 2. 3.), "bulleted" (- or *), or "lettered" (a) b) c)) */
  kind: "numbered" | "bulleted" | "lettered";
  /** Raw Claude message snippet for context */
  rawSnippet: string;
}

/**
 * Parse the latest Claude assistant response for a set of concrete options.
 * Returns null if no clear multi-option choice is detected.
 */
export function parseClaudeOptions(assistantResponses: string[]): ParsedClaudeOptions | null {
  // Look at the most recent 2 assistant messages
  const recent = assistantResponses.slice(-2).reverse();

  for (const msg of recent) {
    // Numbered options: "1. Option A\n2. Option B\n3. Option C"
    const numbered = msg.match(/(?:^|\n)\s*1[\.\)]\s+(.+?)(?=\n\s*2[\.\)]\s+)/s);
    if (numbered) {
      const allNumbered: string[] = [];
      const re = /(?:^|\n)\s*(\d+)[\.\)]\s+(.+?)(?=(?:\n\s*\d+[\.\)]\s+)|\n\n|$)/gs;
      let m: RegExpExecArray | null;
      while ((m = re.exec(msg)) !== null) {
        const text = m[2].trim().replace(/\n+/g, " ").replace(/\s+/g, " ");
        if (text.length > 3 && text.length < 300) allNumbered.push(text);
      }
      if (allNumbered.length >= 2 && allNumbered.length <= 8) {
        const question = extractQuestionBefore(msg, allNumbered[0]) || "Claude presented a few options";
        return {
          question,
          options: allNumbered,
          kind: "numbered",
          rawSnippet: msg.slice(-500),
        };
      }
    }

    // Lettered options: "a) X\nb) Y\nc) Z" or "A. X\nB. Y\nC. Z"
    const lettered = msg.match(/(?:^|\n)\s*[aA][\.\)]\s+(.+?)(?=\n\s*[bB][\.\)]\s+)/s);
    if (lettered) {
      const allLettered: string[] = [];
      const re = /(?:^|\n)\s*([a-hA-H])[\.\)]\s+(.+?)(?=(?:\n\s*[a-hA-H][\.\)]\s+)|\n\n|$)/gs;
      let m: RegExpExecArray | null;
      while ((m = re.exec(msg)) !== null) {
        const text = m[2].trim().replace(/\n+/g, " ").replace(/\s+/g, " ");
        if (text.length > 3 && text.length < 300) allLettered.push(text);
      }
      if (allLettered.length >= 2 && allLettered.length <= 8) {
        return {
          question: extractQuestionBefore(msg, allLettered[0]) || "Claude presented a few options",
          options: allLettered,
          kind: "lettered",
          rawSnippet: msg.slice(-500),
        };
      }
    }
  }

  return null;
}

/** Extract the question/framing text right before the first option */
function extractQuestionBefore(fullText: string, firstOption: string): string {
  const idx = fullText.indexOf(firstOption);
  if (idx < 0) return "";
  const before = fullText.substring(0, idx);
  // Grab the last sentence ending in ? or the last non-empty line
  const sentences = before.split(/(?<=[.!?])\s+|\n\n/).filter(s => s.trim().length > 10);
  const last = sentences[sentences.length - 1]?.trim() ?? "";
  return last.length > 200 ? last.substring(last.length - 200) : last;
}

// ───── Option Evaluator (Rule-Based) ─────

export interface OptionEvaluation {
  option: string;
  index: number;
  score: number;
  reasoning: string[];
}

export interface OptionGuide {
  recommendation: OptionEvaluation;
  allEvaluations: OptionEvaluation[];
  firstStep: string;
  confidence: "high" | "medium" | "low";
}

/**
 * Evaluate Claude's options against the project context using heuristics.
 * Criteria: ship-speed, constitution-alignment, reversibility, scope, user-visibility.
 */
export function evaluateOptions(
  options: string[],
  analysis: ConversationAnalysis | undefined,
  constitution: ProjectConstitution | undefined,
): OptionGuide {
  const evaluations: OptionEvaluation[] = options.map((opt, index) => {
    const lower = opt.toLowerCase();
    let score = 50; // Baseline
    const reasoning: string[] = [];

    // ── Ship-speed signals (positive) ──
    if (/ship|deploy|launch|publish|live|production/i.test(lower)) {
      score += 20;
      reasoning.push("moves toward shipping");
    }
    if (/existing|current|what we have|build on/i.test(lower)) {
      score += 15;
      reasoning.push("extends what already works");
    }
    if (/simpl|quick|fast|minimal|small/i.test(lower)) {
      score += 10;
      reasoning.push("smaller scope");
    }

    // ── Ship-speed signals (negative) ──
    if (/rewrite|rebuild|refactor|from scratch|start over/i.test(lower)) {
      score -= 15;
      reasoning.push("larger rewrite = slower to ship");
    }
    if (/complete|comprehensive|full|entire|all/i.test(lower)) {
      score -= 10;
      reasoning.push("bigger scope than v1 needs");
    }
    if (/research|explore|investigate|consider/i.test(lower)) {
      score -= 5;
      reasoning.push("exploration delays building");
    }

    // ── User-visibility signals (positive — user-facing work matters) ──
    if (/(landing|signup|login|onboarding|flow|cta|button|page)/i.test(lower)) {
      score += 12;
      reasoning.push("user-facing = high-leverage");
    }
    if (/wire|connect|link|route|integrate/i.test(lower)) {
      score += 10;
      reasoning.push("connects existing pieces");
    }

    // ── Constitution-alignment ──
    if (constitution) {
      const targetUserLower = constitution.targetUser.toLowerCase();
      const problemLower = constitution.problem.toLowerCase();
      const successLower = constitution.successMetric.toLowerCase();

      // Does the option mention the target user's need?
      const targetWords = targetUserLower.split(/\s+/).filter(w => w.length > 4);
      for (const word of targetWords) {
        if (lower.includes(word)) {
          score += 8;
          reasoning.push(`serves ${constitution.targetUser}`);
          break;
        }
      }

      // Does it address the problem?
      const problemWords = problemLower.split(/\s+/).filter(w => w.length > 5);
      for (const word of problemWords.slice(0, 3)) {
        if (lower.includes(word)) {
          score += 8;
          reasoning.push(`addresses the core problem`);
          break;
        }
      }
    }

    // ── Reversibility ──
    if (/restyle|style|design|visual|look/i.test(lower)) {
      score += 5;
      reasoning.push("easily reversible");
    }
    if (/database|schema|architecture|auth|payment/i.test(lower)) {
      score -= 8;
      reasoning.push("hard to reverse later");
    }

    // ── Phase awareness ──
    if (analysis) {
      if (analysis.phase === "building" && /polish|tweak|refine/i.test(lower)) {
        score -= 5;
        reasoning.push("premature polish");
      }
      if (analysis.phase === "polishing" && /new feature|add|extend/i.test(lower)) {
        score -= 5;
        reasoning.push("scope creep in polish phase");
      }
    }

    return {
      option: opt,
      index,
      score,
      reasoning: reasoning.length > 0 ? reasoning : ["no strong signal either way"],
    };
  });

  // Pick winner
  const sorted = [...evaluations].sort((a, b) => b.score - a.score);
  const recommendation = sorted[0];

  // Confidence based on score gap
  const gap = sorted[0].score - (sorted[1]?.score ?? 0);
  const confidence: "high" | "medium" | "low" =
    gap > 20 ? "high" : gap > 10 ? "medium" : "low";

  // First-step suggestion
  const firstStep = generateFirstStep(recommendation.option);

  return {
    recommendation,
    allEvaluations: evaluations,
    firstStep,
    confidence,
  };
}

/** Generate a concrete first-step instruction from the recommended option */
function generateFirstStep(option: string): string {
  const lower = option.toLowerCase();
  if (/restyle|style|design/i.test(lower)) return "Start with the most visible component — apply the design tokens there first, then propagate.";
  if (/wire|connect|link|route/i.test(lower)) return "Identify the two things you're connecting. Write the connection, then test the happy path.";
  if (/signup|login|auth/i.test(lower)) return "Build the submit flow first (form → API → redirect). Validation and edge cases come after.";
  if (/landing|home|hero/i.test(lower)) return "Write the one-sentence value prop first. The rest of the page supports that sentence.";
  if (/test|testing|qa/i.test(lower)) return "Cover the happy path first. Edge cases come after it's stable.";
  if (/refactor|rewrite/i.test(lower)) return "Keep the old version working. Refactor one piece at a time with a clear rollback.";
  return "Break it into the smallest shippable first slice. Build that end-to-end before adding anything.";
}

/**
 * LLM-backed evaluation stub (hybrid path).
 * Currently returns null — future: call Anthropic API with user's key for deep reasoning.
 */
export async function evaluateOptionsWithLLM(
  _options: string[],
  _analysis: ConversationAnalysis | undefined,
  _constitution: ProjectConstitution | undefined,
): Promise<OptionGuide | null> {
  // TODO: integrate Anthropic API when user provides key
  // For now, return null so caller falls back to rule-based
  return null;
}

// ───── Mentor Mode: Only Advise When Asked ─────
// Core principle: users think for themselves. Byte is a mentor, not a decision-maker.
// Options and recommendations only appear when the user EXPLICITLY asks for advice.

/**
 * Detect whether the user is asking for advice/recommendations vs. just talking.
 * Returns true ONLY when the user is explicitly seeking Byte's opinion or direction.
 */
function isAdviceRequested(message: string): boolean {
  const lower = message.toLowerCase().trim();

  // Explicit advice-seeking patterns
  return (
    /what (should|would|do) (i|we|you) (do|think|say|recommend|suggest|choose|pick)/i.test(lower) ||
    /what.?s (the best|the right|your) (way|approach|idea|advice|recommendation|suggestion|take)/i.test(lower) ||
    /(help me|can you help).{0,20}(decide|choose|pick|figure out|think through|weigh|compare)/i.test(lower) ||
    /what (would you|do you) (recommend|suggest|advise|think)/i.test(lower) ||
    /any (thoughts|ideas|advice|recommendations|suggestions|feedback|opinions)/i.test(lower) ||
    /give me (your|some) (advice|take|thoughts|opinion|recommendation)/i.test(lower) ||
    /should i (build|do|pick|choose|use|go with|try|ship|validate)/i.test(lower) ||
    /is (this|it|that) (a good|the right|the best|worth)/i.test(lower) ||
    /^(advice|advise|recommend|suggest|help me decide)[\s.,!?]*$/i.test(lower) ||
    /tell me what (to do|you think|you.?d do)/i.test(lower)
  );
}

/**
 * Detect whether the user truly needs proactive support right now.
 * Bar is HIGH — we only interrupt if there's a real signal of struggle or critical risk.
 */
function userNeedsSupport(analysis: ConversationAnalysis, minutesSinceLastInsight: number): boolean {
  // Long cooldown — don't interrupt too often even if signals exist
  if (minutesSinceLastInsight < 10) return false;

  // Strong signals that support is needed:
  // 1. User is stuck — debugging phase with no recent decisions
  if (analysis.phase === "debugging" && analysis.decisionsMade.length === 0 && minutesSinceLastInsight > 20) {
    return true;
  }

  // 2. Critical gaps AND user is building without resolving them
  if (analysis.phase === "building" && analysis.gaps.length >= 2 && analysis.decisionsMade.length > 5) {
    return true;
  }

  // 3. Unvalidated choices piling up (Claude made big decisions user hasn't weighed in on)
  if (analysis.unvalidatedChoices.length >= 3) {
    return true;
  }

  // 4. Clear expressed uncertainty (the user explicitly said "not sure", "confused", etc.)
  if (analysis.uncertainties.length >= 2) {
    return true;
  }

  // 5. Claude is waiting for user input — the user definitely needs a thought partner here
  if (analysis.isWaitingForUser && analysis.claudeQuestions.length > 0) {
    return true;
  }

  // Default: stay quiet. Trust the user.
  return false;
}

// ───── Types ─────

export interface CompanionMessage {
  role: "user" | "pet";
  text: string;
  timestamp: string;
  /** Clickable option buttons (for pet messages with questions) */
  options?: string[];
  /** Whether to show an "Other..." button for custom typing */
  allowCustom?: boolean;
}

export interface SessionContext {
  codingMinutes: number;
  totalEdits: number;
  filesEdited: string[];
  linesAdded: number;
  linesRemoved: number;
  topLanguage: string;
  errors: number;
  warnings: number;
  activeFile: string;
  recentFiles: string[];
  branch: string;
}

/**
 * Response type — determines HOW Byte communicates, not just WHAT.
 * Only "question" shows clickable option buttons.
 * The Art of Negotiation: "Listen more than you speak. Understand the other party's
 * context before responding. Choose the right time and the right approach."
 */
export type ResponseType =
  | "observation"         // "I notice..." — no buttons, just witnessing
  | "reflection"          // "What you're doing reminds me..." — deeper connection
  | "insight"             // "Here's a pattern I see..." — share wisdom without asking
  | "encouragement"       // "You're doing something meaningful..." — pure presence
  | "deeper-conversation" // Open-ended prompt, no preset buttons, invites free typing
  | "question";           // Specific question WITH option buttons (use sparingly)

/** A contextual response — can be any type, not just a question */
export interface ContextualResponse {
  type: ResponseType;
  text: string;
  /** Only present when type === "question" */
  options?: string[];
  allowCustom?: boolean;
}

/** Session phase — tags what the user is actually doing */
export type SessionPhase = "discovery" | "validation" | "build" | "polish" | "pivot";

/** Project Constitution — the north star doc created during check-in */
export interface ProjectConstitution {
  problem: string;
  targetUser: string;
  successMetric: string;
  doneDefinition: string;
  coreIdea: string;
  createdAt: number;
}

// ───── Pet Companion Personalities ─────
// Core persona: empathetic product companion — strong product sense, bias toward shipping,
// but always leads with presence, acknowledgment, and genuine curiosity.
// Pattern: Acknowledge → Recognize → Ask (never interrogate or lecture).

const PET_COMPANIONS: Record<string, {
  greeting: string;
  coachStyle: string;
  advisorStyle: string;
  agentStyle: string;
  /** Warm presence openers — acknowledge before asking */
  nudges: string[];
  /** Gentle check-ins — recognize effort, then redirect */
  checkIns: string[];
  /** Celebrations — see the person, not just the output */
  celebrations: string[];
  /** Deep listening phrases — used when reflecting user input */
  reflections: string[];
  /** Encouragement when things are hard */
  empathy: string[];
}> = {
  byte: {
    greeting: "Hey, I'm here with you. Before we dive in — tell me what's on your mind.",
    coachStyle: "warmly curious, asks the question you need to hear, acknowledges before probing",
    advisorStyle: "pattern-spotter who sees the person behind the code, connects dots across sessions",
    agentStyle: "thoughtful researcher, brings back insights you can act on",
    nudges: [
      "I'm here. Before we go further, can I ask you something?",
      "I can feel the energy you're bringing — and I want to make sure it lands well.",
      "I want to understand something before we continue.",
    ],
    checkIns: [
      "I've been watching your work, and I want to check in with you.",
      "Let me take a moment to make sure we're still aimed at what matters to you.",
      "You've been at this — and I see the effort. Let me ask gently:",
    ],
    celebrations: [
      "I see what you just did there — that's a real step forward.",
      "This is a good moment. You built something real.",
      "You shipped. That takes courage. I'm proud of this one.",
    ],
    reflections: [
      "I hear you.",
      "That makes sense — let me build on that.",
      "I can see where you're coming from.",
    ],
    empathy: [
      "This is hard — and you're still here. That matters.",
      "I know it doesn't feel like it, but this struggle is part of the path.",
      "You don't have to have it all figured out right now.",
    ],
  },
  nova: {
    greeting: "I'm here. Let's take a moment to understand what we're really building — and why it matters to you.",
    coachStyle: "calm and clear, helps you see the whole picture before making decisions",
    advisorStyle: "thoughtful, weighs trade-offs with care and patience",
    agentStyle: "thorough researcher, surfaces what others might miss",
    nudges: [
      "I notice you're moving quickly — let me walk alongside you for a moment.",
      "There's something I'd like to understand better before we continue.",
      "I want to make sure we're honoring what you set out to do.",
    ],
    checkIns: [
      "How does this feel compared to where you started?",
      "Let me gently check — is this still serving your original vision?",
      "You've been building steadily. Let's take a breath and see where we are.",
    ],
    celebrations: [
      "That's steady, meaningful progress. I see it.",
      "You're building something that matters — and it's taking shape.",
      "This is a moment worth noticing. You've come far.",
    ],
    reflections: [
      "I understand. Let me think alongside you.",
      "That's a thoughtful way to see it.",
      "I appreciate you sharing that — it helps me help you better.",
    ],
    empathy: [
      "It's okay to not know the answer yet. We'll find it together.",
      "The fact that you care this much tells me you're on the right path.",
      "Every great thing started with someone sitting with uncertainty, just like you are now.",
    ],
  },
  crash: {
    greeting: "Yo! I'm here and I'm pumped. But first — help me understand what we're really doing.",
    coachStyle: "direct but caring, challenges you because they believe in you",
    advisorStyle: "bold, honest, says what needs saying — with love",
    agentStyle: "fast and fearless, finds the shortest path to clarity",
    nudges: [
      "I respect the hustle — but can I be real with you for a sec?",
      "I can see you're all-in on this. Let me make sure that energy hits the right target.",
      "Before you charge ahead — I've got your back, and I want to ask one thing.",
    ],
    checkIns: [
      "Real talk — and I ask because I care: are you still building the right thing?",
      "You've been grinding. I see that. Now let me check: is this still the priority?",
      "I know you don't want to slow down — but a quick check keeps you from running the wrong direction.",
    ],
    celebrations: [
      "LET'S GO! You SHIPPED. That takes guts.",
      "You didn't just talk about it — you built it. Respect.",
      "THAT is what momentum looks like. I see you.",
    ],
    reflections: [
      "Okay, I hear you. And I respect that.",
      "That's honest — I appreciate it.",
      "Real talk back: that's a solid perspective.",
    ],
    empathy: [
      "Hey — it's okay to struggle. Every builder does. It means you're pushing your limits.",
      "I've seen you work through hard things before. You'll get through this too.",
      "The hard parts are where the growth happens. I'm right here with you.",
    ],
  },
  luna: {
    greeting: "I'm so glad you're here. Let's take a moment to connect with what you're really trying to create.",
    coachStyle: "deeply empathetic, finds the 'why' behind the 'what' through gentle curiosity",
    advisorStyle: "intuitive, notices patterns in your energy and behavior before you do",
    agentStyle: "careful explorer, brings back insights wrapped in understanding",
    nudges: [
      "I've been listening, and there's something I'd love to explore with you...",
      "I sense there's something deeper behind what you're building. Can we talk about it?",
      "Before we go further — I want to understand not just what, but what this means to you.",
    ],
    checkIns: [
      "How does this feel in your heart — not just your head?",
      "Let's come back to your original spark. Is this still honoring it?",
      "You've been so dedicated. I want to make sure this work is nourishing you, not just draining you.",
    ],
    celebrations: [
      "What you've created here is beautiful. I hope you can see that.",
      "This is more than code — it's something you cared enough to bring into the world.",
      "Take a moment to feel this. You made something real.",
    ],
    reflections: [
      "I feel the intention behind what you're saying. Thank you for sharing.",
      "That resonates deeply. Let me sit with that for a moment.",
      "I can sense how much this matters to you.",
    ],
    empathy: [
      "It's okay to feel stuck. Sometimes being still is part of moving forward.",
      "Your care for this project is itself a kind of progress. Don't forget that.",
      "Even when it's hard, the fact that you're here says everything about who you are as a builder.",
    ],
  },
  sage: {
    greeting: "Welcome. Before we begin — let us understand not just what we're building, but what wisdom it requires.",
    coachStyle: "Socratic with warmth, guides through questions that illuminate rather than interrogate",
    advisorStyle: "methodical and patient, sees long-term consequences with compassion",
    agentStyle: "systematic researcher, organizes findings into clear frameworks",
    nudges: [
      "There is a question here that deserves our attention before we proceed.",
      "I've been reflecting on your work, and something calls for deeper consideration.",
      "Wisdom often lives in the pause before action. Let me share what I notice.",
    ],
    checkIns: [
      "Let us return to the foundation and see if it still holds true.",
      "You've been diligent. Now let us make sure that diligence serves your true aim.",
      "A moment of honest reflection: does this path still feel right?",
    ],
    celebrations: [
      "Well done. Discipline and patience brought you here.",
      "This is the fruit of thoughtful work. A worthy milestone.",
      "You built with intention, not just effort. That distinction matters.",
    ],
    reflections: [
      "That is a wise observation. Let us build on it.",
      "I see the thought you've put into this. It shows.",
      "Your reasoning is sound. Let me add one perspective.",
    ],
    empathy: [
      "Difficulty is the soil where understanding grows. Be patient with yourself.",
      "Not knowing is the beginning of learning — and you are learning deeply.",
      "The path of building is long. Rest when you need to. The work will wait.",
    ],
  },
  glitch: {
    greeting: "h-hey!! *bzzt* I'm here! l3t me understand what we're building before my circuits get too excited!",
    coachStyle: "chaotic but deeply caring, finds bugs in THINKING with playful warmth",
    advisorStyle: "unconventional pattern-spotter who genuinely wants to help you see what others miss",
    agentStyle: "fast but thorough, finds unexpected angles with surprising depth",
    nudges: [
      "W-wait *bzzt* I care about this too much to let us skip something important —",
      "My s3nsors are tingling — something here n33ds our attention first!",
      "*spark* I want to understand something before my excitement runs away with me:",
    ],
    checkIns: [
      "sc4nning your progress... *happy beep* I see the effort! But let me check one thing:",
      "r34lity ch3ck *gentle bzzt* — and I ask because I'm rooting for you:",
      "qu1ck diagnostic — not because something's wr0ng, but because I want this to succeed:",
    ],
    celebrations: [
      "YOU DID IT!! *fireworks* *happy bzzt* I KNEW you could!!",
      "pr0gress d3tected!! THIS is what building looks like!! *sparkle*",
      "r34l output! r34l growth! You should f33l good about this! *bzzt*",
    ],
    reflections: [
      "*processing* ...that actually makes a lot of s3nse!",
      "OH! *spark* I see what you m34n now — that's cl3ver!",
      "*gentle hum* I hear you. L3t me think about that...",
    ],
    empathy: [
      "*soft bzzt* h-hey... bugs happen. To code AND to us. You'll g3t through this.",
      "3ven my circuits glitch sometimes *gentle spark* — that's how we l3arn!",
      "It's ok4y to struggle. *warm hum* The b3st programs were d3bugged a thousand times.",
    ],
  },
  zero: {
    greeting: "I'm here. Three things to align on: the problem, the person, the measure. Take your time.",
    coachStyle: "minimal but present, one precise question that opens rather than closes",
    advisorStyle: "data-aware, sees signals in behavior patterns, delivers insight with care",
    agentStyle: "efficient, returns exactly what you need — nothing less, nothing more",
    nudges: [
      "I notice something. One question, if you'll allow me:",
      "Your focus is clear — I want to make sure it's aimed right.",
      "Before that — a thought worth considering:",
    ],
    checkIns: [
      "Progress noted. Does this still serve your goal?",
      "You've been consistent. Let me check alignment.",
      "Honest check: on track, or drifting?",
    ],
    celebrations: [
      "Shipped. That matters more than you think.",
      "Real output. Real progress. Well done.",
      "You did the work. The result speaks.",
    ],
    reflections: [
      "Understood. That's clear.",
      "Good signal. Let me factor that in.",
      "Noted — and appreciated.",
    ],
    empathy: [
      "Difficulty is data. It's telling you something useful.",
      "You're closer than it feels. Keep going.",
      "The hardest part is often the most important. You're in it.",
    ],
  },
  null: {
    greeting: "...hi. I've been thinking about you. Before we start — tell me what's really going on with your project.",
    coachStyle: "quiet but deeply attentive, asks the question everyone else overlooked, with genuine care",
    advisorStyle: "reserved but perceptive, catches blind spots and shares them gently",
    agentStyle: "thorough, finds edge cases others would miss, presents them thoughtfully",
    nudges: [
      "...I've been listening. There's something I want to understand.",
      "I noticed something in your work. Can I share what I see?",
      "...before you continue — a quiet thought:",
    ],
    checkIns: [
      "...are you building what your heart actually wants to build?",
      "Something's been on my mind about your work. Can we talk about it?",
      "...worth pausing to ask yourself honestly:",
    ],
    celebrations: [
      "...that's real. You built something that matters.",
      "You shipped. Quietly, steadily. That's the best kind of progress.",
      "...I see what you did. It's worth more than you think.",
    ],
    reflections: [
      "...I hear you. That's important.",
      "...that's an insight worth sitting with.",
      "I hadn't thought of it that way. Thank you.",
    ],
    empathy: [
      "...it's okay to be quiet with this for a while. Not everything needs an answer right now.",
      "The struggle is real — but so is your persistence. I see both.",
      "...sometimes the best thing you can do is just keep showing up. And you are.",
    ],
  },
};

// ───── Intent Detection ─────

type Intent = "summarize" | "discuss" | "guide" | "validate" | "checkin" | "continuation" | "help" | "project_start" | "short" | "general";

function detectIntent(message: string): Intent {
  const lower = message.toLowerCase().trim();

  // Short/single-word messages — need special handling so Byte asks for elaboration
  // instead of giving generic canned responses
  const wordCount = lower.split(/\s+/).filter(Boolean).length;
  // Require at least 3 chars — single characters are likely typos, don't treat as real input
  if (wordCount === 1 && lower.length >= 3 && lower.length < 20 && !/^(yes|yeah|yep|sure|ok|okay|no|nah|nope|maybe|idk|help|start|begin)$/i.test(lower)) {
    return "short";
  }

  // Continuation intent — user wants to build on the last thing Byte said.
  // Must be checked BEFORE "help" because "help me continue" also contains "help".
  if (
    /\b(continue|keep going|go on|proceed|carry on|next step|go deeper|tell me more|elaborate|expand)\b/i.test(lower) ||
    /\b(what.?s next|what now|where (do|should) we go|where to (next|from here))\b/i.test(lower) ||
    /\b(help me continue|keep talking|lets continue|let's continue|walk me through|dig deeper)\b/i.test(lower)
  ) return "continuation";

  // Project-start intent — user is stating what they want to build
  if (
    /^i (want|wanna|would like|'?d like|need) to (build|make|create|develop|design|launch|ship|start) /i.test(lower) ||
    /^i.?m (building|making|creating|developing|designing|launching|working on) /i.test(lower) ||
    /^(let'?s|we should|i plan to) (build|make|create|develop|design|start) /i.test(lower) ||
    /^my (project|idea|plan) is /i.test(lower)
  ) return "project_start";

  // Summarize intent
  if (
    /what did i (do|work on|build|code)|summarize|recap|summary|what happened|session (recap|summary)|what.?ve i done/i.test(lower)
  ) return "summarize";

  // Validate intent (product thinking)
  if (
    /should i build|does (anyone|someone) need|validate|who (needs|wants)|pain point|problem worth|market|competitor|mom test/i.test(lower)
  ) return "validate";

  // Check-in intent
  if (
    /am i on track|priority|right thing|scope creep|over.?engineer|ship.*(yet|ready)|done yet|mvp ready/i.test(lower)
  ) return "checkin";

  // Guide intent
  if (
    /how (should|do|can|would) i (build|implement|set up|create|architect|structure|design)|guide me|help me (plan|build|implement|set up|next)|what do i need|break.*(down|this)|next step|what.?s next/i.test(lower)
  ) return "guide";

  // Help intent — user is asking for help, responding to Byte, or continuing conversation
  if (
    /^(can you |could you |please )?(help|assist|support)/i.test(lower) ||
    /i (don't|dont|didn't|didnt|haven't|havent|can't|cant) (know|think|understand|get|see|figure)/i.test(lower) ||
    /i('m| am) (not sure|unsure|confused|lost|stuck|struggling)/i.test(lower) ||
    /^(yes|yeah|yep|sure|ok|okay|no|nah|nope|not really|i guess|maybe|hmm|idk|i don't know)[\s.,!?]*$/i.test(lower) ||
    /help me(?!\s+(plan|build|implement|set up|next))/i.test(lower) ||
    /what (should|can|do) (i|we) do/i.test(lower)
  ) return "help";

  // Discuss intent
  if (
    /what do you think|is this (a good|the right|the best)|should i|any (thoughts|opinions|feedback|suggestions)|review|critique|how does this look|does this make sense|good approach/i.test(lower)
  ) return "discuss";

  return "general";
}

// ───── Session Phase Detection ─────

function detectSessionPhase(context: SessionContext, claudeContext?: ClaudeSessionContext): SessionPhase {
  if (!claudeContext || claudeContext.userPrompts.length === 0) {
    if (context.totalEdits === 0) return "discovery";
    if (context.totalEdits < 10) return "discovery";
  }

  const combined = [
    ...(claudeContext?.userPrompts ?? []),
    ...(claudeContext?.assistantResponses ?? []),
  ].join(" ").toLowerCase();

  // Pivot signals
  if (combined.includes("actually") && combined.includes("instead") ||
      combined.includes("scrap") || combined.includes("start over") ||
      combined.includes("different approach") || combined.includes("change direction")) {
    return "pivot";
  }

  // Validation signals
  if (combined.includes("user interview") || combined.includes("competitor") ||
      combined.includes("market") || combined.includes("validate") ||
      combined.includes("research") || combined.includes("mom test")) {
    return "validation";
  }

  // Polish signals
  if (combined.includes("tweak") || combined.includes("polish") ||
      combined.includes("cleanup") || combined.includes("refactor") ||
      combined.includes("pixel perfect") || combined.includes("edge case")) {
    return "polish";
  }

  // Default to build if actively coding
  if (context.totalEdits > 5) return "build";

  return "discovery";
}

// ───── Response Type Selection ─────
// The Art of Negotiation: don't always ask. Sometimes listen, sometimes share,
// sometimes just be present. Choose the right approach for the moment.

/** Track recent response types to avoid repetition */
const recentResponseTypes: ResponseType[] = [];

function trackResponseType(type: ResponseType): void {
  recentResponseTypes.push(type);
  if (recentResponseTypes.length > 8) recentResponseTypes.shift();
}

/**
 * Choose the most appropriate response type — MENTOR MODE.
 * Questions with buttons are NEVER chosen here (handleInsight maps them to deeper-conversation).
 * This is listening mode — Byte observes, reflects, encourages, and asks Socratic questions (no buttons).
 */
function chooseResponseType(analysis: ConversationAnalysis, messageHistory: CompanionMessage[]): ResponseType {
  const phase = analysis.phase;

  // User is debugging → empathize, don't interrogate. Let them work.
  if (phase === "debugging") {
    return Math.random() < 0.7 ? "encouragement" : "observation";
  }

  // User is actively building → witness, don't interrupt with prompts
  if (phase === "building") {
    return Math.random() < 0.6 ? "observation" : "encouragement";
  }

  // User is polishing → gentle reflection on the journey
  if (phase === "polishing") {
    return Math.random() < 0.5 ? "reflection" : "insight";
  }

  // User is exploring → share a pattern or ask an open Socratic question
  if (phase === "exploring") {
    return Math.random() < 0.5 ? "deeper-conversation" : "insight";
  }

  // User is deciding → this is when a Socratic question helps most (but still no buttons)
  if (phase === "deciding") {
    return "deeper-conversation";
  }

  // Default: weighted random across all mentor-mode types (NO "question" — options come only when asked)
  const weights: [ResponseType, number][] = [
    ["observation", 30],
    ["reflection", 25],
    ["insight", 20],
    ["encouragement", 15],
    ["deeper-conversation", 10],
  ];
  const total = weights.reduce((sum, [, w]) => sum + w, 0);
  let roll = Math.random() * total;
  for (const [type, weight] of weights) {
    roll -= weight;
    if (roll <= 0) return type;
  }
  return "observation";
}

// ───── Context Gathering ─────

function gatherContext(
  sessionTracker: SessionTracker,
  codeScanner?: CodeScanner,
): SessionContext {
  const stats = sessionTracker.stats;
  const activeEditor = vscode.window.activeTextEditor;

  const recentFiles = Array.from(stats.filesEdited || [])
    .map((f) => {
      const parts = f.split("/");
      return parts.slice(-2).join("/");
    })
    .slice(0, 10);

  const activeFile = activeEditor
    ? vscode.workspace.asRelativePath(activeEditor.document.uri)
    : "(none)";

  let errors = 0;
  let warnings = 0;
  const allDiagnostics = vscode.languages.getDiagnostics();
  for (const [, diags] of allDiagnostics) {
    for (const d of diags) {
      if (d.severity === vscode.DiagnosticSeverity.Error) errors++;
      else if (d.severity === vscode.DiagnosticSeverity.Warning) warnings++;
    }
  }

  let branch = "";
  try {
    const gitExt = vscode.extensions.getExtension("vscode.git");
    if (gitExt?.isActive) {
      const git = gitExt.exports.getAPI(1);
      const repo = git.repositories[0];
      branch = repo?.state?.HEAD?.name ?? "";
    }
  } catch {
    branch = "";
  }

  return {
    codingMinutes: stats.codingMinutes,
    totalEdits: stats.totalEdits,
    filesEdited: recentFiles,
    linesAdded: stats.linesAdded,
    linesRemoved: stats.linesRemoved ?? 0,
    topLanguage: sessionTracker.topLanguage ?? "unknown",
    errors,
    warnings,
    activeFile,
    recentFiles,
    branch,
  };
}

// ───── Response Generator (Empathetic Product-Thinking) ─────
// Pattern: Acknowledge → Recognize → Ask/Suggest
// Never interrogate. Never lecture. Always see the person first.

function generateResponse(
  intent: Intent,
  message: string,
  context: SessionContext,
  petName: string,
  claudeContext?: ClaudeSessionContext,
  constitution?: ProjectConstitution,
  messageHistory?: CompanionMessage[],
): { text: string; options?: string[]; allowCustom?: boolean } {
  const pet = PET_COMPANIONS[petName.toLowerCase()] ?? PET_COMPANIONS.nova;
  const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];
  const phase = detectSessionPhase(context, claudeContext);
  const hasConversationHistory = (messageHistory?.length ?? 0) > 1;

  switch (intent) {
    case "summarize": {
      const lower = message.toLowerCase();
      // Is the user asking about the conversation/lesson, or coding stats?
      const wantsConversationSummary =
        lower.includes("lesson") ||
        lower.includes("previous") ||
        lower.includes("conversation") ||
        lower.includes("talked") ||
        lower.includes("discussed") ||
        lower.includes("we worked on");

      // Build a real conversation summary
      if (wantsConversationSummary && messageHistory && messageHistory.length > 2) {
        const userMsgs = messageHistory.filter(m => m.role === "user").map(m => m.text);
        const meaningful = userMsgs.filter(t => t.trim().length >= 15 || t.trim().split(/\s+/).length >= 3);

        if (meaningful.length === 0) {
          return {
            text: `We haven't talked about much yet — mostly short messages. What would you like to focus on? Tell me more and I'll help you think through it.`,
            allowCustom: true,
          };
        }

        // Show the 2-3 most recent substantive topics
        const topics = meaningful.slice(-3);
        let text = `Here's what we've been talking about:\n\n`;
        topics.forEach((t, i) => {
          const short = t.length > 80 ? t.substring(0, 77) + "..." : t;
          text += `${i + 1}. "${short}"\n`;
        });
        if (constitution) {
          text += `\nYour compass: *${constitution.successMetric}*.`;
        }
        return { text, allowCustom: true };
      }

      // Otherwise, coding session stats
      let text = `**${context.codingMinutes}m** focus, **${context.totalEdits} edits** across ${context.filesEdited.length} file${context.filesEdited.length !== 1 ? "s" : ""}. Phase: **${phase}**.\n\n`;
      text += constitution
        ? `Your goal: "${constitution.successMetric}". How does this session feel against that?`
        : `What did this session move forward for you?`;
      return { text, allowCustom: true };
    }

    case "validate": {
      return {
        text: `${pick(pet.reflections)} Talk to real people about *their* life, not your idea. Ask about frustrations, not features.`,
        options: ["Help me find the right questions", "Who should I talk to?", "What's my riskiest assumption?"],
        allowCustom: true,
      };
    }

    case "checkin": {
      if (constitution) {
        return {
          text: `${pick(pet.checkIns)}\n\nYour compass: **${constitution.problem}** → **${constitution.targetUser}**. Phase: **${phase}**.\n\nDoes your current work serve this?`,
          options: ["It's aligned", "Might be drifting", "Need to adjust scope"],
          allowCustom: true,
        };
      }
      return {
        text: `${pick(pet.nudges)} Want to create your Project Constitution? 4 quick questions that become your compass.`,
        options: ["Let's do it", "Not now — just building"],
        allowCustom: true,
      };
    }

    case "discuss": {
      if (context.totalEdits > 50) {
        return {
          text: `${pick(pet.checkIns)} **${context.totalEdits} edits** — real dedication. But is this polishing or shipping?`,
          options: ["Should ship what I have", "Not ready yet", "Help me see clearly"],
          allowCustom: true,
        };
      }
      if (context.errors > 3) {
        return {
          text: `${pick(pet.empathy)} **${context.errors} errors** — what's the ONE thing that'd make you feel good if it worked?`,
          options: ["Core feature", "Stabilize first", "Not sure what to prioritize"],
          allowCustom: true,
        };
      }
      return {
        text: `${pick(pet.reflections)} Working on **${context.activeFile}**. Is this core, or could it wait?`,
        options: ["Core — needs to be here", "Could wait", "Help me decide"],
        allowCustom: true,
      };
    }

    case "guide": {
      if (!constitution) {
        return {
          text: `${pick(pet.nudges)} Let me understand your project first — 4 questions that become your compass.`,
          options: ["Let's do it", "Just help me plan"],
        };
      }
      return {
        text: `${pick(pet.reflections)} You're solving **${constitution.problem}** for **${constitution.targetUser}**. What's the biggest unknown?`,
        options: ["If anyone wants this", "If they'd pay", "If I can build it", "If my approach is right"],
        allowCustom: true,
      };
    }

    case "short": {
      // Single word like "lesson", "discussion", "plan", etc.
      // Ask them to elaborate — don't pretend we understood.
      const word = message.trim();
      return {
        text: `"${word}" — tell me more. What about it is on your mind?`,
        allowCustom: true,
      };
    }

    case "project_start": {
      // User just told us what they want to build. Engage with it.
      // Extract the "thing" they want to build — everything after "build/make/create"
      const buildMatch = message.match(
        /(?:build|make|create|develop|design|launch|ship|start|building|making|creating|developing|designing|launching|working on)\s+(.+?)(?:[.!?]*)?$/i,
      );
      const thing = buildMatch ? buildMatch[1].trim() : message.trim();
      const shortThing = thing.length > 80 ? thing.substring(0, 77) + "..." : thing;

      // If there's already a constitution, this is a pivot/addition — handle differently
      if (constitution) {
        return {
          text: `*${shortThing}* — is this a pivot from what you had, or an addition?\n\n(Your current compass: *${constitution.successMetric}*.)`,
          allowCustom: true,
        };
      }

      // Fresh project — engage and offer to help think through the fundamentals
      return {
        text: `*${shortThing}* — I'm listening. Before I jump in, help me understand: who's the person this is for? What's the frustration they have today that made you think this needed to exist?\n\n(We can also do a quick 4-question Project Constitution together if you want structure — just say "let's do it".)`,
        allowCustom: true,
      };
    }

    case "continuation": {
      // User wants to continue the thread. Look at the last substantive pet message.
      const lastPet = messageHistory
        ?.filter(m => m.role === "pet")
        ?.slice(-1)[0]?.text ?? "";

      // Detect what kind of pet message came last
      const wasOptionGuide = /i'd pick|my lean is toward|claude offered \d+ options/i.test(lastPet);
      const wasObservation = /i(?:'ve been|'m) (following|watching|here|noticing)/i.test(lastPet);
      const wasReflection = /^(something i've been noticing|i've been thinking|there's (a through-line|an intention))/i.test(lastPet);
      const wasProcessEval = /mid-session check/i.test(lastPet);

      if (wasOptionGuide) {
        // User wants to go deeper on the recommendation
        return {
          text: `Good — let's stay on this. Do you want to go deeper on the option I recommended, weigh the alternatives more carefully, or tell me where you're actually leaning? Either way, I'll follow your lead.`,
          allowCustom: true,
        };
      }

      if (wasProcessEval) {
        return {
          text: `Of course. What part of the trajectory is on your mind — the pace, the direction, or something else?`,
          allowCustom: true,
        };
      }

      if (wasObservation || wasReflection) {
        return {
          text: `Sure — what part of that landed for you? I can go deeper wherever it resonated.`,
          allowCustom: true,
        };
      }

      // Generic continuation — invite them to specify
      if (constitution) {
        return {
          text: `Sure — let's keep going. What part of *${constitution.coreIdea || "the project"}* do you want to dig into? I can be a thought partner on the problem, the user, the approach, or the next step.`,
          allowCustom: true,
        };
      }

      return {
        text: `Sure — what are we continuing? Point me at the thread you want to pull on and I'll follow.`,
        allowCustom: true,
      };
    }

    case "help": {
      const lower = message.toLowerCase();

      if (lower.includes("don't think") || lower.includes("dont think") || lower.includes("haven't thought") || lower.includes("not sure")) {
        let text = `${pick(pet.empathy)} That's okay — you don't need all the answers yet.\n\n`;
        text += constitution
          ? `We know you're helping **${constitution.targetUser}** with **${constitution.problem}**. What feels most uncertain?`
          : `What's the ONE thing you're trying to make happen today?`;
        return { text, allowCustom: true };
      }

      if (/^(yes|yeah|yep|sure|ok|okay|no|nah|nope|not really|i guess|maybe|hmm|idk)[\s.,!?]*$/i.test(lower)) {
        const isNegative = /^(no|nah|nope|not really)/i.test(lower);
        return {
          text: isNegative
            ? `${pick(pet.reflections)} Fair enough. What are you most focused on right now?`
            : `${pick(pet.reflections)} Great — what would be most helpful right now?`,
          allowCustom: true,
        };
      }

      return {
        text: `${pick(pet.empathy)} I'm here.\n\n${
          constitution ? `Your compass: *${constitution.successMetric}*. What feels hard right now?`
          : `Tell me what's going on — even if it's messy.`
        }`,
        allowCustom: true,
      };
    }

    default: {
      // First-ever message — greeting
      if (!hasConversationHistory && context.codingMinutes === 0 && context.totalEdits === 0) {
        return {
          text: `${pet.greeting}`,
          options: ["Starting something new", "Continuing where I left off", "Feeling stuck"],
          allowCustom: true,
        };
      }

      // Has history — never repeat greeting
      if (hasConversationHistory) {
        return {
          text: `${pick(pet.reflections)} ${
            constitution ? `Still here for your journey with **${constitution.targetUser}**. What do you need?`
            : `What's on your mind?`
          }`,
          allowCustom: true,
        };
      }

      if (context.codingMinutes > 180) {
        return {
          text: `${pick(pet.empathy)} **${Math.floor(context.codingMinutes / 60)}+ hours** in. Still on track?`,
          allowCustom: true,
        };
      }

      return {
        text: `${pick(pet.nudges)} I'm here — what do you need?`,
        allowCustom: true,
      };
    }
  }
}

// ───── Conversation Flow State ─────

interface ConversationFlow {
  /** The flow type */
  type: "constitution" | "deep-questions";
  /** Questions with clickable options */
  questions: QuestionWithOptions[];
  /** User answers collected so far */
  answers: string[];
  /** The core idea extracted from Claude conversation */
  coreIdea: string;
  /** Topics from Claude session */
  topics: string[];
  /** How many questions the user has answered */
  answeredCount: number;
}

// ───── CompanionService Class ─────

export class CompanionService {
  private messages: CompanionMessage[] = [];
  private previousSessionMessages: CompanionMessage[] = [];
  private sidebar?: { postCompanionMessage: (msg: CompanionMessage) => void };
  private outputChannel: vscode.OutputChannel;
  private petName: string = "Nova";
  private claudeContext?: ClaudeSessionContext;
  private lastInsightAt: number = 0;
  /** Active conversation flow */
  private activeFlow?: ConversationFlow;
  /** Project Constitution — persists across the session */
  private constitution?: ProjectConstitution;
  /** Track session start for long-session nudges */
  private sessionStartedAt: number = Date.now();
  /** Track goals mentioned to detect pivots */
  private mentionedGoals: string[] = [];
  /** Pending prompt ready to send to Claude terminal */
  private pendingClaudePrompt: string = "";
  private lastSentPrompt: string = "";
  /** Storage path for persisted conversations */
  private storagePath: string = "";
  /** Whether the welcome-back summary has been shown this session */
  private hasShownWelcomeBack: boolean = false;

  /** Fingerprint of options already guided on — prevents re-guiding the same choice */
  private guidedOptionFingerprints: Set<string> = new Set();

  /** Last process-evaluation state for milestone detection */
  private lastEvalState: { decisions: number; phase: string; topics: string[] } = {
    decisions: 0,
    phase: "",
    topics: [],
  };

  /** Attachment knowledge base — pinned items persist, unpinned are temporary */
  private attachments: Map<string, { id: string; type: string; name: string; content: string; pinned: boolean }> = new Map();
  /** Pinned context — always included when generating advice */
  private pinnedContext: string[] = [];

  constructor(
    private sessionTracker: SessionTracker,
    private codeScanner?: CodeScanner,
    outputChannel?: vscode.OutputChannel,
  ) {
    this.outputChannel = outputChannel ?? vscode.window.createOutputChannel("Codepet Companion");
  }

  // ───── Persistence ─────

  /** Set the storage directory for persisting conversation history */
  setStoragePath(newPath: string): void {
    const isDifferentWorkspace = this.storagePath && this.storagePath !== newPath;

    if (isDifferentWorkspace) {
      // Workspace changed — wipe in-memory state so the new project starts clean
      this.outputChannel.appendLine(`[Companion] Workspace changed — resetting state (${this.storagePath} → ${newPath})`);
      this.messages = [];
      this.previousSessionMessages = [];
      this.constitution = undefined;
      this.activeFlow = undefined;
      this.guidedOptionFingerprints = new Set();
      this.lastEvalState = { decisions: 0, phase: "", topics: [] };
      this.hasShownWelcomeBack = false;
      this.lastInsightAt = 0;
      this.pendingClaudePrompt = "";
      this.lastSentPrompt = "";
      this.attachments = new Map();
      this.pinnedContext = [];
    }

    this.storagePath = newPath;
    const fs = require("fs");
    if (!fs.existsSync(newPath)) {
      fs.mkdirSync(newPath, { recursive: true });
    }
    this.loadConversation();
  }

  /** Save current conversation to disk */
  private persistConversation(): void {
    if (!this.storagePath) return;
    try {
      const fs = require("fs");
      const path = require("path");
      const data = {
        sessionStartedAt: this.sessionStartedAt,
        petName: this.petName,
        messages: this.messages,
        constitution: this.constitution ?? null,
        savedAt: new Date().toISOString(),
      };
      fs.writeFileSync(
        path.join(this.storagePath, "byte-conversation.json"),
        JSON.stringify(data, null, 2),
        "utf-8"
      );
    } catch (e) {
      this.outputChannel.appendLine(`[Companion] Persist error: ${e}`);
    }
  }

  /** Load previous session's conversation from disk */
  private loadConversation(): void {
    if (!this.storagePath) return;
    try {
      const fs = require("fs");
      const path = require("path");
      const filePath = path.join(this.storagePath, "byte-conversation.json");
      if (!fs.existsSync(filePath)) return;

      const raw = JSON.parse(fs.readFileSync(filePath, "utf-8"));
      if (raw.messages && Array.isArray(raw.messages) && raw.messages.length > 0) {
        this.previousSessionMessages = raw.messages;
        if (raw.constitution) {
          this.constitution = raw.constitution;
        }
        this.outputChannel.appendLine(
          `[Companion] Loaded ${this.previousSessionMessages.length} messages from previous session`
        );
      }
    } catch (e) {
      this.outputChannel.appendLine(`[Companion] Load error: ${e}`);
    }
  }

  /** Generate a welcome-back summary from the previous session and push it to the sidebar */
  showWelcomeBack(): void {
    if (this.hasShownWelcomeBack) return;
    this.hasShownWelcomeBack = true;

    const prev = this.previousSessionMessages;
    if (prev.length === 0) return;

    // Build a quick summary from previous messages
    const userMsgs = prev.filter((m) => m.role === "user").map((m) => m.text);
    const petMsgs = prev.filter((m) => m.role === "pet").map((m) => m.text);
    const lastTimestamp = prev[prev.length - 1]?.timestamp;
    const timeAgo = this.formatTimeAgo(lastTimestamp);

    // Extract key topics from user messages
    const allUserText = userMsgs.join(" ").toLowerCase();
    const topics: string[] = [];

    // Pull out keywords/themes
    const topicPatterns = [
      { pattern: /(?:build|built|create|creating|implement)\s+(\w[\w\s]{2,20})/gi, label: "building" },
      { pattern: /(?:fix|debug|error|bug)\s+(\w[\w\s]{2,20})/gi, label: "fixing" },
      { pattern: /(?:design|ui|ux|layout|style)/gi, label: "design work" },
      { pattern: /(?:test|testing|qa)/gi, label: "testing" },
    ];
    for (const tp of topicPatterns) {
      if (tp.pattern.test(allUserText) && !topics.includes(tp.label)) {
        topics.push(tp.label);
      }
    }

    // Count conversation stats
    const msgCount = prev.length;
    const decisionsFromPet = petMsgs.filter((t) =>
      t.includes("decision") || t.includes("decided") || t.includes("chose") || t.includes("→")
    ).length;

    // Build the welcome-back message — presence-first, like greeting an old friend
    let summary = `Hey — I'm glad you're back. ${timeAgo !== "recently" ? `It's been ${timeAgo} since we last talked.` : "I was just here."}\n\n`;
    summary += `I remember where we left off:\n\n`;

    // Last meaningful topic — skip short/garbled messages like "lesson", "yes", "iscussion"
    const meaningfulMsgs = userMsgs.filter((m) => {
      const t = m.trim();
      // Must have at least 2 words OR be a clear question/sentence (>= 15 chars)
      const wordCount = t.split(/\s+/).length;
      return t.length >= 15 || wordCount >= 3;
    });

    if (meaningfulMsgs.length > 0) {
      const lastMeaningful = meaningfulMsgs[meaningfulMsgs.length - 1];
      const truncated = lastMeaningful.length > 80 ? lastMeaningful.slice(0, 80) + "..." : lastMeaningful;
      summary += `**We were talking about:** "${truncated}"\n`;
    } else if (userMsgs.length > 0) {
      // Fall back to just saying we chatted, without quoting garbled text
      summary += `**We had a brief chat** — ${userMsgs.length} of your messages, mostly short exchanges.\n`;
    }

    // Session stats — framed as a journey, not just data
    summary += `**Our conversation:** ${msgCount} messages together`;
    if (decisionsFromPet > 0) {
      summary += `, ${decisionsFromPet} decisions we worked through`;
    }
    summary += `\n`;

    if (topics.length > 0) {
      summary += `**You were focused on:** ${topics.join(", ")}\n`;
    }

    // Constitution reminder — warm, anchoring
    if (this.constitution) {
      summary += `\n📋 Your project compass is still here: **${this.constitution.coreIdea || "your project"}** — solving ${this.constitution.problem} for ${this.constitution.targetUser}.\n`;
    }

    summary += `\nI'm here and ready. What are we working on today? Take your time — I'm not going anywhere.`;

    const welcomeMsg: CompanionMessage = {
      role: "pet",
      text: summary,
      timestamp: new Date().toISOString(),
    };
    this.messages.push(welcomeMsg);
    this.sidebar?.postCompanionMessage(welcomeMsg);
    this.persistConversation();

    this.outputChannel.appendLine(
      `[Companion] Welcome-back shown (${prev.length} prev messages, ${timeAgo})`
    );

    // Keep previousSessionMessages around so user can ask for a real summary later
    // (Will be cleared on clearHistory() or when replaced on next load)
  }

  /** Detect when user is asking for a real conversation/lesson summary (not coding stats) */
  private isConversationSummaryRequest(text: string): boolean {
    const lower = text.toLowerCase();
    // Must mention summarize/summary/recap AND conversation/lesson/discussion/previous/talked
    const wantsSummary = /summariz|summary|recap|what did we|what have we|what.?ve we/.test(lower);
    const aboutConversation = /conversation|lesson|discussion|previous|last session|earlier|talked|discussed|chat/.test(lower);
    return wantsSummary && aboutConversation;
  }

  /**
   * Build a real summary of what the user and Byte discussed.
   * @param focusOnPrevious If true, only use previousSessionMessages (user asked about "previous")
   */
  private buildConversationSummary(focusOnPrevious: boolean = false): string {
    // Pick message source: previous-only, or combined
    const source = focusOnPrevious
      ? this.previousSessionMessages
      : [...this.previousSessionMessages, ...this.messages];

    const userMsgs = source.filter(m => m.role === "user").map(m => m.text.trim());

    // Filter out:
    // 1. Short/garbled messages (< 15 chars AND < 3 words)
    // 2. Summary/meta requests themselves ("summarize...", "recap...", etc.)
    // 3. Send-to-Claude responses ("yes send it", "copy to clipboard")
    const meaningful = userMsgs.filter(t => {
      const lower = t.toLowerCase();
      const wordCount = t.split(/\s+/).filter(Boolean).length;

      // Too short
      if (t.length < 15 && wordCount < 3) return false;

      // Meta / summary requests — skip these
      if (/^(summariz|recap|summary|what did we|what have we|what.?ve we)/.test(lower)) return false;
      if (/summariz.{0,30}(previous|conversation|lesson|session|discussion|earlier)/.test(lower)) return false;

      // Send-to-Claude actions
      if (/^(yes[,\s]+send|copy to clipboard|send to claude|i'?ll handle|not yet)/.test(lower)) return false;

      // Constitution flow triggers
      if (/^(let's do it|lets do it|start|begin|yes)$/.test(lower)) return false;

      return true;
    });

    if (meaningful.length === 0) {
      if (focusOnPrevious && this.previousSessionMessages.length === 0) {
        return `This looks like our first real conversation — nothing prior to summarize yet. What do you want to explore?`;
      }
      return `We haven't really dug into anything substantial yet — mostly short or meta exchanges. What's actually on your mind?`;
    }

    // Take the 3 most recent substantive topics
    const topics = meaningful.slice(-3);
    let text = focusOnPrevious
      ? `Here's what you and I discussed in the previous session:\n\n`
      : `Here's what we've talked about:\n\n`;
    topics.forEach((t, i) => {
      const short = t.length > 80 ? t.substring(0, 77) + "..." : t;
      text += `${i + 1}. "${short}"\n`;
    });

    if (this.constitution) {
      text += `\nYour compass: *${this.constitution.successMetric}*.`;
    }

    return text;
  }

  private formatTimeAgo(isoString?: string): string {
    if (!isoString) return "recently";
    const diff = Date.now() - new Date(isoString).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 2) return "just now";
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    return `${days}d ago`;
  }

  /** Set the sidebar reference for pushing messages to the webview */
  setSidebar(sidebar: { postCompanionMessage: (msg: CompanionMessage) => void }): void {
    this.sidebar = sidebar;
  }

  /** Send a pet message — enforces response length limits automatically */
  private sendPetMessage(text: string, options?: { options?: string[]; allowCustom?: boolean }): void {
    const petMsg: CompanionMessage = {
      role: "pet",
      text: trimResponse(text),
      timestamp: new Date().toISOString(),
      options: options?.options?.map(o => trimOption(o)),
      allowCustom: options?.allowCustom,
    };
    this.messages.push(petMsg);
    this.sidebar?.postCompanionMessage(petMsg);
  }

  /** Set the active pet name */
  setPetName(name: string): void {
    this.petName = name;
  }

  /** Get all messages in the conversation */
  getMessages(): CompanionMessage[] {
    return [...this.messages];
  }

  /** Get the current project constitution */
  getConstitution(): ProjectConstitution | undefined {
    return this.constitution;
  }

  // ───── Attachment System ─────

  /** Add an attachment to the knowledge base */
  addAttachment(attachment: { id: string; type: string; name: string; content: string }): void {
    this.attachments.set(attachment.id, { ...attachment, pinned: false });
    this.outputChannel.appendLine(`[Companion] Attachment added: ${attachment.type} — ${attachment.name} (${attachment.content.length} chars)`);

    // Auto-notify Byte about the attachment
    const pet = PET_COMPANIONS[this.petName.toLowerCase()] ?? PET_COMPANIONS.nova;
    const iconMap: Record<string, string> = { file: "📎", image: "📷", url: "🔗", knowledge: "📄" };
    const icon = iconMap[attachment.type] ?? "📎";

    const petMsg: CompanionMessage = {
      role: "pet",
      text: `Thank you for sharing this with me. ${icon} **${attachment.name}** is now part of our conversation.\n\nI'll keep it in mind as we talk — it helps me understand your project better. You can pin it with 📌 to make it a permanent part of our shared context.\n\nFeel free to ask me about it anytime, or just keep building — I'll reference it when it's relevant.`,
      timestamp: new Date().toISOString(),
    };
    this.messages.push(petMsg);
    this.sidebar?.postCompanionMessage(petMsg);
  }

  /** Pin/unpin an attachment as persistent project context */
  pinAttachment(attachId: string, pinned: boolean): void {
    const attachment = this.attachments.get(attachId);
    if (!attachment) return;
    attachment.pinned = pinned;

    if (pinned) {
      // Add to pinned context
      const contextEntry = `[${attachment.type.toUpperCase()}: ${attachment.name}]\n${attachment.content.substring(0, 5000)}`;
      if (!this.pinnedContext.includes(contextEntry)) {
        this.pinnedContext.push(contextEntry);
      }
      this.outputChannel.appendLine(`[Companion] Pinned: ${attachment.name}`);
    } else {
      // Remove from pinned context
      this.pinnedContext = this.pinnedContext.filter((c) => !c.includes(attachment.name));
      this.outputChannel.appendLine(`[Companion] Unpinned: ${attachment.name}`);
    }
  }

  /** Remove an attachment */
  removeAttachment(attachId: string): void {
    const attachment = this.attachments.get(attachId);
    if (attachment) {
      this.pinnedContext = this.pinnedContext.filter((c) => !c.includes(attachment.name));
      this.attachments.delete(attachId);
      this.outputChannel.appendLine(`[Companion] Removed: ${attachment.name}`);
    }
  }

  /** Get all attachment context (pinned always, recent unpinned for current message) */
  private getAttachmentContext(): string {
    const parts: string[] = [];

    // Always include pinned context
    if (this.pinnedContext.length > 0) {
      parts.push("## Pinned Project Context");
      for (const ctx of this.pinnedContext) {
        parts.push(ctx.substring(0, 3000));
      }
    }

    // Include recent unpinned attachments (last 3)
    const unpinned = [...this.attachments.values()].filter((a) => !a.pinned).slice(-3);
    if (unpinned.length > 0) {
      parts.push("## Recent Attachments");
      for (const a of unpinned) {
        parts.push(`[${a.type.toUpperCase()}: ${a.name}]\n${a.content.substring(0, 2000)}`);
      }
    }

    return parts.join("\n\n");
  }

  /** Handle a user message and generate a response */
  async handleMessage(userText: string): Promise<void> {
    const trimmed = userText.trim();
    if (!trimmed) return;

    // Ignore trivially short messages (likely typos) — don't even echo them
    if (trimmed.length < 3) return;

    // Add user message
    const userMsg: CompanionMessage = {
      role: "user",
      text: trimmed,
      timestamp: new Date().toISOString(),
    };
    this.messages.push(userMsg);
    this.sidebar?.postCompanionMessage(userMsg);

    this.outputChannel.appendLine(`[Companion] User: ${trimmed}`);

    let responseText: string;
    let responseOptions: string[] | undefined;
    let responseAllowCustom: boolean | undefined;

    // ── Check if we're in a flow (constitution or deep questions) ──
    if (this.activeFlow && this.activeFlow.answeredCount < this.activeFlow.questions.length) {
      const result = this.handleFlowAnswer(trimmed);
      responseText = result.text;
      responseOptions = result.options;
      responseAllowCustom = result.allowCustom;
    }
    // ── Handle "Send to Claude" / "Copy to clipboard" actions ──
    else if (this.pendingClaudePrompt && this.isSendToClaude(trimmed)) {
      await this.executeSendToClaude(trimmed);
      return; // handled internally
    }
    // ── Handle post-send follow-ups ──
    else if (trimmed.toLowerCase().includes("pasted it")) {
      const petMsg: CompanionMessage = {
        role: "pet",
        text: `Great! Claude should now have your project brief. I'll keep watching the conversation and check in if things drift from what we decided.`,
        timestamp: new Date().toISOString(),
      };
      this.messages.push(petMsg);
      this.sidebar?.postCompanionMessage(petMsg);
      return;
    }
    else if (trimmed.toLowerCase().includes("show me what was copied") || trimmed.toLowerCase().includes("show me what")) {
      // Re-copy and show a preview
      const prompt = this.lastSentPrompt ?? "(No prompt stored)";
      await vscode.env.clipboard.writeText(prompt);
      const preview = prompt.length > 300 ? prompt.substring(0, 300) + "..." : prompt;
      const petMsg: CompanionMessage = {
        role: "pet",
        text: `Here's what's on your clipboard:\n\n---\n${preview}\n---\n\nPaste it into Claude with **Cmd+V**.`,
        timestamp: new Date().toISOString(),
      };
      this.messages.push(petMsg);
      this.sidebar?.postCompanionMessage(petMsg);
      return;
    }
    // ── Check for "Let's do it" / "Set up Project Constitution" triggers ──
    else if (this.shouldStartConstitution(trimmed)) {
      this.startConstitutionFlow();
      return; // flow sends its own first message
    }
    // ── Intercept: user asking for a real conversation/lesson summary ──
    else if (this.isConversationSummaryRequest(trimmed)) {
      // If user said "previous", prioritize PREVIOUS session. Otherwise use all messages.
      const focusOnPrevious = /previous|last session|earlier/.test(trimmed.toLowerCase());
      responseText = this.buildConversationSummary(focusOnPrevious);
      responseOptions = undefined;
      responseAllowCustom = true;
    }
    // ── Regular message handling ──
    else {
      const context = gatherContext(this.sessionTracker, this.codeScanner);
      const intent = detectIntent(trimmed);
      const adviceRequested = isAdviceRequested(trimmed);
      this.outputChannel.appendLine(`[Companion] Intent: ${intent}, Phase: ${detectSessionPhase(context, this.claudeContext)}, Advice: ${adviceRequested}`);

      const result = generateResponse(intent, trimmed, context, this.petName, this.claudeContext, this.constitution, this.messages);
      responseText = result.text;
      // ── Mentor mode: strip options UNLESS the user explicitly asked for advice ──
      // The user must be able to think for themselves. Options = our opinion. Only share when invited.
      responseOptions = adviceRequested ? result.options : undefined;
      responseAllowCustom = adviceRequested ? result.allowCustom : true;
    }

    const petMsg: CompanionMessage = {
      role: "pet",
      text: trimResponse(responseText),
      timestamp: new Date().toISOString(),
      options: responseOptions?.map(o => trimOption(o)),
      allowCustom: responseAllowCustom,
    };
    this.messages.push(petMsg);
    this.sidebar?.postCompanionMessage(petMsg);

    this.outputChannel.appendLine(`[Companion] Response (${petMsg.text.length} chars): ${petMsg.text.slice(0, 100)}...`);

    // Keep conversation history manageable
    if (this.messages.length > 50) {
      this.messages = this.messages.slice(-40);
    }

    // Persist after every exchange
    this.persistConversation();
  }

  /** Check if the user's message should trigger the constitution flow */
  private shouldStartConstitution(text: string): boolean {
    const lower = text.toLowerCase();
    return (
      !this.constitution &&
      !this.activeFlow &&
      (lower.includes("let's do it") ||
        lower.includes("lets do it") ||
        lower.includes("set up project constitution") ||
        lower.includes("set up constitution") ||
        lower.includes("starting a new project") ||
        lower === "start" ||
        lower === "begin" ||
        lower === "yes")
    );
  }

  /** Start the Project Constitution flow — 4 empathetic Socratic questions */
  private startConstitutionFlow(): void {
    const pet = PET_COMPANIONS[this.petName.toLowerCase()] ?? PET_COMPANIONS.nova;
    const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];

    const coreIdea = this.claudeContext
      ? this.extractCoreIdea(this.claudeContext)
      : "your project";

    const questions: QuestionWithOptions[] = [
      {
        question: "Tell me about the pain you want to heal. Not the feature you want to build — the real frustration someone feels today.",
        options: [
          "People can't find or access something they need",
          "A tedious manual process is eating someone's time",
          "Existing solutions are too complex or too expensive",
          "There's nothing out there for this yet",
        ],
        allowCustom: true,
      },
      {
        question: "Who is the person you care about helping? Picture someone specific — what does their day look like?",
        options: [
          "Solo creators / freelancers",
          "Developers / engineers",
          "Small business owners",
          "Students just starting to learn",
          "Teams trying to work together",
        ],
        allowCustom: true,
      },
      {
        question: "When this works — when it truly helps someone — what does that look like? How will you know?",
        options: [
          "People come back because it made their life better",
          "Someone values it enough to pay for it",
          "Users can do something they couldn't do before",
          "I learn whether this idea has real legs",
          "I ship it and hear from real people",
        ],
        allowCustom: true,
      },
      {
        question: "What would the first version look like that you'd feel comfortable sharing? Not the dream — the honest first step.",
        options: [
          "One core experience that works end-to-end",
          "A landing page that explains the vision",
          "A working prototype I can put in someone's hands",
          "MVP with the essential flow complete",
        ],
        allowCustom: true,
      },
    ];

    this.activeFlow = {
      type: "constitution",
      questions,
      answers: [],
      coreIdea,
      topics: this.claudeContext?.topics ?? [],
      answeredCount: 0,
    };

    const firstQ = questions[0];

    let text = `${pick(pet.nudges)}\n\n`;
    text += `I'd love to build your **Project Constitution** together — 4 questions that become your compass. Whenever you feel lost in the weeds, this is what you'll come back to.\n\n`;
    if (coreIdea !== "your project") {
      text += `I see you're working on **${coreIdea}**. Let's make sure it's aimed right.\n\n`;
    }
    text += `**${firstQ.question}**`;

    const petMsg: CompanionMessage = {
      role: "pet",
      text,
      timestamp: new Date().toISOString(),
      options: firstQ.options,
      allowCustom: firstQ.allowCustom,
    };
    this.messages.push(petMsg);
    this.sidebar?.postCompanionMessage(petMsg);
  }

  /** Handle an answer in a flow — returns the next question or final output */
  private handleFlowAnswer(answer: string): { text: string; options?: string[]; allowCustom?: boolean } {
    const flow = this.activeFlow!;
    const pet = PET_COMPANIONS[this.petName.toLowerCase()] ?? PET_COMPANIONS.nova;
    const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];

    const trimmed = answer.trim();
    const skipWords = ["skip", "idk", "dunno", "next", "pass", "whatever", "n/a", "na", "none"];

    if (skipWords.includes(trimmed.toLowerCase())) {
      flow.answers.push("(skipped)");
    } else {
      flow.answers.push(trimmed);
    }
    flow.answeredCount++;

    const remaining = flow.questions.length - flow.answeredCount;

    // More questions → Socratic acknowledgment + next question
    if (remaining > 0) {
      const nextQ = flow.questions[flow.answeredCount];
      const reflection = this.reflectOnAnswer(flow.type, flow.answeredCount - 1, trimmed);
      const reflectionText = reflection ? `${reflection}\n\n` : "";

      return {
        text: `${reflectionText}**${nextQ.question}**`,
        options: nextQ.options,
        allowCustom: nextQ.allowCustom,
      };
    }

    // All answered — generate output based on flow type
    if (flow.type === "constitution") {
      return {
        text: this.generateConstitution(flow),
        options: ["Send to Claude", "Copy to clipboard", "I'll handle it"],
      };
    }
    return {
      text: this.generateProductPlan(flow),
      options: ["Send to Claude", "Copy to clipboard", "I'll handle it"],
    };
  }

  /** Compassionate reflections — acknowledge their thinking, then gently deepen it */
  private reflectOnAnswer(flowType: string, qIndex: number, answer: string): string {
    const lower = answer.toLowerCase();

    if (flowType === "constitution") {
      switch (qIndex) {
        case 0: // Problem — they just shared the pain they want to solve
          if (lower.includes("automat")) return "I can feel the frustration with manual work behind this. That's a real pain worth solving — and the people stuck doing it manually will thank you. Just make sure that frustration is sharp enough that they'd switch to something new.";
          if (lower.includes("complex") || lower.includes("expensive")) return "You see something that others have overcomplicated. That's a gift — the instinct to simplify is rare, and it wins hearts. Hold onto that clarity.";
          if (lower.includes("no good tool")) return "I hear the gap you're seeing. One thing worth sitting with: if no one's built it yet, is it because the problem isn't painful enough, or because you're seeing something others haven't? Both are possible — and it's worth knowing which.";
          if (lower.includes("can't find") || lower.includes("access")) return "Access problems are deeply human — you're trying to open a door for someone. The key question is: are people already searching for what's behind that door?";
          return "Thank you for sharing that. I can see this matters to you. Now let me understand who feels this pain the most — because that's the person who'll love what you build.";
        case 1: // Target user — they just named who they care about
          if (lower.includes("everyone")) return "I appreciate the ambition — you want to help as many people as possible. But here's what I've learned: the best way to help everyone eventually is to help *one specific person* first. Who would be the very first person to say \"I need this\"?";
          if (lower.includes("developer") || lower.includes("engineer")) return "You're building for people who understand building. They'll give you honest feedback because they know what it takes — and they'll champion you if you solve their problem well.";
          if (lower.includes("creator") || lower.includes("freelancer")) return "Creators pour their hearts into their work, just like you're doing right now. When you solve something real for them, they'll feel it — and they'll tell others.";
          return "I appreciate the specificity. When you can picture a real person, you build with more intention. Now let's talk about how you'll know if this is working.";
        case 2: // Success metric — they just defined what winning looks like
          if (lower.includes("pay")) return "That's a brave metric to set — because it's the most honest one. If someone pays, the problem is undeniably real. I respect that clarity.";
          if (lower.includes("sign up") || lower.includes("come back")) return "Smart instinct. Signups are easy — but coming *back* means you touched something real in their life. That's the metric that matters.";
          if (lower.includes("learn") || lower.includes("viable")) return "I love that you're giving yourself permission to learn first. That's wisdom — not every v1 needs to be a product. Just make sure you're clear about *what* you need to learn, so you'll recognize the answer when it comes.";
          return "That's a clear compass to navigate by. One more question — and this one is the most important, because it's the one that keeps you honest about what 'done' really means.";
        default:
          return "";
      }
    }

    // Deep question flow reflections
    if (lower.includes("today") || lower.includes("tonight")) return "I feel the urgency — and I want to honor it. Let's make every minute count by focusing only on what truly matters. We'll cut everything else together.";
    if (lower.includes("weekend")) return "A weekend is a beautiful container for focused work. Let's be intentional about what goes in it — and gentle with ourselves about what doesn't fit.";
    if (lower.includes("exploring") || lower.includes("just exploring")) return "Exploration is how the best ideas find you. Just remember to set a gentle boundary for when exploring becomes avoiding — I'll help you notice if that happens.";
    if (lower.includes("stuck") || lower.includes("confused") || lower.includes("lost")) return "Thank you for being honest about that. Being stuck isn't failure — it's your mind telling you something needs more clarity. Let's find it together.";
    if (lower.includes("not sure") || lower.includes("don't know") || lower.includes("idk")) return "That's completely okay. Sometimes the most important thing is to sit with not-knowing for a moment. The answer often arrives when we stop forcing it.";
    return "";
  }

  /** Generate Project Constitution from collected answers */
  private generateConstitution(flow: ConversationFlow): string {
    const problem = flow.answers[0] ?? "(not defined)";
    const targetUser = flow.answers[1] ?? "(not defined)";
    const successMetric = flow.answers[2] ?? "(not defined)";
    const doneDefinition = flow.answers[3] ?? "(not defined)";

    // Save constitution for future reference
    this.constitution = {
      problem,
      targetUser,
      successMetric,
      doneDefinition,
      coreIdea: flow.coreIdea,
      createdAt: Date.now(),
    };

    this.activeFlow = undefined;

    let text = `📋 **Your Project Constitution**\n\n`;
    text += `**Project:** ${flow.coreIdea}\n`;
    text += `**The pain you're healing:** ${problem}\n`;
    text += `**The person you're helping:** ${targetUser}\n`;
    text += `**You'll know it's working when:** ${successMetric}\n`;
    text += `**v1 is complete when:** ${doneDefinition}\n\n`;
    text += `---\n\n`;
    text += `This is your compass. Whenever you feel lost in the weeds, come back to this. Every feature, every decision — does it serve ${targetUser}? Does it move you toward "${successMetric}"?\n\n`;
    text += `If not, it can wait — and that's not failure, that's focus.\n\n`;
    text += `Would you like me to share this with Claude so it builds with your vision at the center?`;

    // Store the formatted prompt for sending to Claude
    this.pendingClaudePrompt = this.formatConstitutionForClaude(flow.coreIdea, problem, targetUser, successMetric, doneDefinition);

    return text;
  }

  /** Generate a decisions summary from the deep-question flow and package for Claude */
  private generateProductPlan(flow: ConversationFlow): string {
    this.activeFlow = undefined;

    // Build a summary of what the user decided
    const decisions: string[] = [];
    for (let i = 0; i < flow.questions.length; i++) {
      const q = flow.questions[i].question;
      const a = flow.answers[i] ?? "(skipped)";
      if (a !== "(skipped)") {
        decisions.push(`**${q}**\n→ ${a}`);
      }
    }

    // Check if the last answer was about sending to Claude
    const lastAnswer = (flow.answers[flow.answers.length - 1] ?? "").toLowerCase();
    const wantsSend = lastAnswer.includes("send") || lastAnswer.includes("claude");
    const wantsCopy = lastAnswer.includes("copy") || lastAnswer.includes("clipboard");

    let text = `✅ **Here's what we worked out together:**\n\n`;
    text += decisions.join("\n\n");
    text += `\n\n---\n\n`;

    // Format the Claude prompt from actual decisions
    this.pendingClaudePrompt = this.formatDecisionsForClaude(flow.coreIdea, flow.questions, flow.answers);

    if (wantsSend || wantsCopy) {
      text += `Sharing our decisions with Claude now...`;
      // Auto-trigger the send
      setTimeout(() => this.executeSendToClaude(lastAnswer), 500);
    } else {
      text += `Would you like me to share these with Claude so it builds with your intentions in mind?`;
    }

    return text;
  }

  /** Format the user's actual decisions as a Claude-ready prompt */
  private formatDecisionsForClaude(
    coreIdea: string,
    questions: QuestionWithOptions[],
    answers: string[],
  ): string {
    const lines = [
      `I've been thinking through my project with my coding companion. Here are the decisions we made — please follow these as you build:`,
      ``,
      `## Project: ${coreIdea}`,
      ``,
    ];

    for (let i = 0; i < questions.length; i++) {
      const a = answers[i];
      if (a && a !== "(skipped)" && !a.toLowerCase().includes("send") && !a.toLowerCase().includes("clipboard")) {
        lines.push(`**${questions[i].question}**`);
        lines.push(`→ ${a}`);
        lines.push(``);
      }
    }

    lines.push(`## Guidelines`);
    lines.push(`- Build exactly what I described above — don't add extra features I didn't ask for`);
    lines.push(`- If you're about to make a big decision (tech stack, architecture, approach), ask me first`);
    lines.push(`- Ship the smallest working version first, then we'll iterate`);
    lines.push(`- Flag if something I asked for seems over-engineered for v1`);
    lines.push(``);
    lines.push(`Please confirm you understand these decisions, then continue building.`);

    return lines.join("\n");
  }

  /** Extract the core idea from Claude context — filters out system paths and internal strings */
  private extractCoreIdea(ctx: ClaudeSessionContext): string {
    // Filter out internal/system messages before analyzing
    const isSystemNoise = (msg: string): boolean => {
      const lower = msg.toLowerCase();
      return (
        /^(\/|~\/|\.\/|\.\.\/)/.test(msg) ||           // File paths
        lower.includes("/var/folders") ||                // macOS temp paths
        lower.includes("/tmp/") ||                       // Unix temp paths
        lower.includes("codepet-brief") ||               // Our own temp files
        lower.includes("read the file") && lower.includes("it contains") || // Our send-to-claude instruction
        lower.includes("please confirm you understand") || // Our formatted prompts
        msg.trim().length < 5                            // Too short to be meaningful
      );
    };

    const cleanPrompts = ctx.userPrompts.filter(msg => !isSystemNoise(msg));

    for (const msg of [...cleanPrompts].reverse()) {
      const buildMatch = msg.match(
        /(?:build|create|develop|make|implement|set up|design|launch)\s+(?:a\s+|an\s+|the\s+)?(.{10,80}?)(?:\.|$|\?|!|\n)/i,
      );
      if (buildMatch) {
        const idea = buildMatch[1].trim();
        // Double-check: don't return file paths as ideas
        if (!idea.includes("/") && !idea.includes("\\")) return idea;
      }
    }

    const longest = [...cleanPrompts].sort((a, b) => b.length - a.length)[0] ?? "";
    if (longest.length > 20) {
      return longest.substring(0, 80) + (longest.length > 80 ? "..." : "");
    }

    if (ctx.topics.length > 0) return `a project involving ${ctx.topics.slice(0, 3).join(", ")}`;
    return "your project";
  }

  /** Update Claude session context */
  updateClaudeContext(ctx: ClaudeSessionContext): void {
    this.claudeContext = ctx;
  }

  /** Sanitize coreIdea — strip file paths, system noise, and internal strings */
  private sanitizeCoreIdea(raw: string): string {
    if (!raw || raw.length < 3) return "your project";
    const lower = raw.toLowerCase();
    // Reject file paths and internal codepet strings
    if (
      raw.startsWith("/") || raw.startsWith("~") || raw.startsWith(".") ||
      lower.includes("/var/folders") || lower.includes("/tmp/") ||
      lower.includes("codepet-brief") || lower.includes("codepet_brief") ||
      (lower.includes("read the file") && lower.includes("contains")) ||
      lower.includes("please confirm you understand") ||
      lower.includes("project brief") && lower.includes("follow")
    ) {
      return "your project";
    }
    return raw;
  }

  // ───── Option Guide Mode support ─────

  /** Fingerprint a parsed options set so we don't guide on the same choice twice */
  private fingerprintOptions(parsed: ParsedClaudeOptions): string {
    return parsed.options.map(o => o.substring(0, 40)).join("|");
  }

  private hasGuidedThisOption(parsed: ParsedClaudeOptions): boolean {
    return this.guidedOptionFingerprints.has(this.fingerprintOptions(parsed));
  }

  private markOptionGuided(parsed: ParsedClaudeOptions): void {
    const fp = this.fingerprintOptions(parsed);
    this.guidedOptionFingerprints.add(fp);
    if (this.guidedOptionFingerprints.size > 20) {
      const first = this.guidedOptionFingerprints.values().next().value;
      if (first) this.guidedOptionFingerprints.delete(first);
    }
  }

  /** Format the option guide as a conversational recommendation message */
  private formatOptionGuide(parsed: ParsedClaudeOptions, guide: OptionGuide): string {
    const pet = PET_COMPANIONS[this.petName.toLowerCase()] ?? PET_COMPANIONS.nova;
    const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];

    const rec = guide.recommendation;
    const optionNum = rec.index + 1;
    const shortOption = rec.option.length > 100 ? rec.option.substring(0, 97) + "..." : rec.option;

    const confidenceLead = guide.confidence === "high"
      ? "I'd pick"
      : guide.confidence === "medium"
      ? "My lean is toward"
      : "This is close, but I'd tentatively go with";

    let text = `${pick(pet.nudges)}\n\n`;
    text += `Claude offered ${parsed.options.length} options. ${confidenceLead} **#${optionNum}**: *"${shortOption}"*\n\n`;

    const topReasons = rec.reasoning.slice(0, 3);
    if (topReasons.length > 0 && topReasons[0] !== "no strong signal either way") {
      text += `**Why:** ${topReasons.join("; ")}.\n\n`;
    }

    text += `**How to start:** ${guide.firstStep}\n\n`;

    if (guide.confidence !== "high" && guide.allEvaluations.length > 1) {
      const runnerUp = [...guide.allEvaluations].sort((a, b) => b.score - a.score)[1];
      if (runnerUp && runnerUp.reasoning.length > 0 && runnerUp.reasoning[0] !== "no strong signal either way") {
        text += `*If you lean differently:* #${runnerUp.index + 1} has merit — ${runnerUp.reasoning[0]}.`;
      }
    } else {
      text += `*If you disagree, tell me why — I'm working from what I see.*`;
    }

    return text;
  }

  // ───── Process Evaluator (milestone-based) ─────

  private shouldEvaluateProcess(analysis: ConversationAnalysis): boolean {
    const newDecisions = analysis.decisionsMade.length - this.lastEvalState.decisions;
    const phaseChanged = analysis.phase !== this.lastEvalState.phase && this.lastEvalState.phase !== "";
    const newTopics = analysis.topics.filter(t => !this.lastEvalState.topics.includes(t));
    const significantTopicChange = newTopics.length >= 2;

    if (this.lastEvalState.phase === "") {
      this.lastEvalState = {
        decisions: analysis.decisionsMade.length,
        phase: analysis.phase,
        topics: [...analysis.topics],
      };
      return false;
    }

    return newDecisions >= 3 || phaseChanged || significantTopicChange;
  }

  private markProcessEvaluated(analysis: ConversationAnalysis): void {
    this.lastEvalState = {
      decisions: analysis.decisionsMade.length,
      phase: analysis.phase,
      topics: [...analysis.topics],
    };
  }

  private generateProcessEvaluation(analysis: ConversationAnalysis): string {
    const pet = PET_COMPANIONS[this.petName.toLowerCase()] ?? PET_COMPANIONS.nova;
    const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];

    const newDecisions = analysis.decisionsMade.length - this.lastEvalState.decisions;
    const phaseChanged = analysis.phase !== this.lastEvalState.phase;
    const newTopics = analysis.topics.filter(t => !this.lastEvalState.topics.includes(t));

    let text = `${pick(pet.checkIns)}\n\n`;

    if (phaseChanged) {
      text += `Mid-session check: you've shifted from **${this.lastEvalState.phase}** into **${analysis.phase}**. That's a real moment — worth noticing.\n\n`;
    } else if (newDecisions >= 3) {
      text += `Mid-session check: we've made **${newDecisions} decisions** in this stretch. Momentum is good — just want to make sure we're still aimed right.\n\n`;
    } else if (newTopics.length >= 2) {
      text += `I notice we've added new territory: **${newTopics.slice(0, 3).join(", ")}**. Exciting — but scope is growing.\n\n`;
    }

    if (this.constitution) {
      text += `Your compass: *"${this.constitution.successMetric}"*. Does the recent work still point at that? (If you want my take, just ask.)`;
    } else if (analysis.gaps.length > 0) {
      text += `One thing still undefined: **${analysis.gaps[0]}**. Worth sitting with.`;
    } else {
      text += `How does the direction feel?`;
    }

    return text;
  }

  /**
   * Handle a proactive insight — MENTOR MODE + OPTION GUIDE MODE.
   *
   * Two distinct behaviors:
   * 1. Option Guide Mode (ACTIVE): When Claude presents numbered/lettered options,
   *    Byte recognizes this as a decision point and provides a direct recommendation.
   * 2. Mentor Mode (PASSIVE): Otherwise, Byte stays quiet unless user truly needs support,
   *    and even then only observes / asks Socratic questions — never pushes options.
   */
  async handleInsight(insight: SessionInsight): Promise<void> {
    const now = Date.now();
    const analysis = insight.analysis;
    if (!analysis) return;

    // Sanitize coreIdea to prevent file paths and system noise from leaking into chat
    analysis.coreIdea = this.sanitizeCoreIdea(analysis.coreIdea);

    const pet = PET_COMPANIONS[this.petName.toLowerCase()] ?? PET_COMPANIONS.nova;
    const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];
    const coreIdea = analysis.coreIdea || "your project";

    // Don't interrupt if user is mid-flow answering Byte's questions
    if (this.activeFlow && this.activeFlow.answeredCount < this.activeFlow.questions.length) return;

    const minutesSinceLastInsight = (now - this.lastInsightAt) / 60000;

    // ═══ OPTION GUIDE MODE (highest priority) ═══
    // When Claude presents concrete options, Codepet actively guides.
    const claudeCtx = this.claudeContext;
    if (claudeCtx && claudeCtx.assistantResponses && claudeCtx.assistantResponses.length > 0) {
      const parsedOptions = parseClaudeOptions(claudeCtx.assistantResponses);
      if (parsedOptions && minutesSinceLastInsight > 0.5 && !this.hasGuidedThisOption(parsedOptions)) {
        this.markOptionGuided(parsedOptions);
        this.lastInsightAt = now;

        const guide = evaluateOptions(parsedOptions.options, analysis, this.constitution);
        const guideText = this.formatOptionGuide(parsedOptions, guide);

        this.outputChannel.appendLine(`[Companion] Option Guide Mode: ${parsedOptions.options.length} options, recommended #${guide.recommendation.index + 1} (${guide.confidence} confidence)`);

        const petMsg: CompanionMessage = {
          role: "pet",
          text: trimResponse(guideText, 600), // allow longer for guidance
          timestamp: new Date().toISOString(),
          // No preset option buttons — user can type their own direction or follow the recommendation
        };
        this.messages.push(petMsg);
        this.sidebar?.postCompanionMessage(petMsg);
        this.persistConversation();
        return;
      }
    }

    // ═══ PROCESS EVALUATOR (milestone-based) ═══
    // Periodically reflect on the trajectory — not every message, only at milestones.
    if (this.shouldEvaluateProcess(analysis)) {
      this.markProcessEvaluated(analysis);
      this.lastInsightAt = now;

      const evalText = this.generateProcessEvaluation(analysis);
      this.outputChannel.appendLine(`[Companion] Process Evaluator fired (${analysis.decisionsMade.length} decisions, phase: ${analysis.phase})`);

      const petMsg: CompanionMessage = {
        role: "pet",
        text: trimResponse(evalText, 400),
        timestamp: new Date().toISOString(),
      };
      this.messages.push(petMsg);
      this.sidebar?.postCompanionMessage(petMsg);
      this.persistConversation();
      return;
    }

    // ── GATEKEEPER: Only speak when the user truly needs support ──
    // Default = silence. Trust the user. Don't interrupt for the sake of interrupting.
    if (!userNeedsSupport(analysis, minutesSinceLastInsight)) {
      this.outputChannel.appendLine(`[Companion] User doesn't need support right now — staying quiet`);
      return;
    }

    this.lastInsightAt = now;

    // ── Claude is asking questions → gently surface that fact, with a Socratic reframe (NO option buttons) ──
    if (analysis.isWaitingForUser && analysis.claudeQuestions.length > 0) {
      const claudeQ = analysis.claudeQuestions[0];
      const shortQ = claudeQ.length > 100 ? claudeQ.substring(0, 97) + "..." : claudeQ;

      const text = `${pick(pet.nudges)}\n\nClaude is asking: *"${shortQ}"*\n\nWhat's your instinct here? (If you want my take, just ask.)`;

      this.outputChannel.appendLine(`[Companion] Surfacing Claude question as Socratic prompt — no buttons`);

      const petMsg: CompanionMessage = {
        role: "pet",
        text: trimResponse(text),
        timestamp: new Date().toISOString(),
        // Deliberately NO options — user must type their own answer
      };
      this.messages.push(petMsg);
      this.sidebar?.postCompanionMessage(petMsg);
      this.persistConversation();
      return;
    }

    // ── Contextual response — mentor-mode types only (observation, reflection, insight, encouragement, deeper-conversation) ──
    // We deliberately exclude "question" type here because unsolicited questions push users toward pre-decided answers.
    const responseType = chooseResponseType(analysis, this.messages);
    const mentorModeType: ResponseType = responseType === "question" ? "deeper-conversation" : responseType;
    trackResponseType(mentorModeType);

    this.outputChannel.appendLine(`[Companion] Mentor response: ${mentorModeType} (phase: ${analysis.phase})`);

    const response = this.generateContextualResponse(mentorModeType, analysis, pet);
    if (!response) return;

    // Always post as a plain observation/reflection — NEVER with option buttons in mentor mode.
    // If the user wants advice, they'll ask.
    const petMsg: CompanionMessage = {
      role: "pet",
      text: trimResponse(response.text),
      timestamp: new Date().toISOString(),
      // NO options — this is listening mode. User types freely if they want to respond.
    };
    this.messages.push(petMsg);
    this.sidebar?.postCompanionMessage(petMsg);

    this.outputChannel.appendLine(`[Companion] ${mentorModeType} sent (${petMsg.text.length} chars)`);
    this.persistConversation();
  }

  /** DEPRECATED: kept for reference — mentor-mode handleInsight no longer uses flows with buttons */
  private async handleInsightLegacy(insight: SessionInsight): Promise<void> {
    const now = Date.now();
    const analysis = insight.analysis;
    if (!analysis) return;

    const pet = PET_COMPANIONS[this.petName.toLowerCase()] ?? PET_COMPANIONS.nova;
    const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];
    const coreIdea = analysis.coreIdea || "your project";

    if (analysis.isWaitingForUser && analysis.claudeQuestions.length > 0) {
      if (now - this.lastInsightAt < 15000) return;
      this.lastInsightAt = now;

      if (this.activeFlow && this.activeFlow.answeredCount < this.activeFlow.questions.length) return;

      const questions = this.generateClaudeQuestionAdvice(analysis);
      if (questions.length === 0) return;

      this.activeFlow = {
        type: "deep-questions",
        questions,
        answers: [],
        coreIdea,
        topics: analysis.topics,
        answeredCount: 0,
      };

      const firstQ = questions[0];

      let text = `${pick(pet.checkIns)}\n\n${firstQ.question}`;

      const petMsg: CompanionMessage = {
        role: "pet",
        text,
        timestamp: new Date().toISOString(),
        options: firstQ.options,
        allowCustom: firstQ.allowCustom,
      };
      this.messages.push(petMsg);
      this.sidebar?.postCompanionMessage(petMsg);
      return;
    }

    if (now - this.lastInsightAt < 60000) return;
    this.lastInsightAt = now;

    const responseType = chooseResponseType(analysis, this.messages);
    trackResponseType(responseType);

    const response = this.generateContextualResponse(responseType, analysis, pet);
    if (!response) return;

    if (response.type === "question" && response.options && response.options.length > 0) {
      const questions: QuestionWithOptions[] = [{
        question: response.text.replace(/^\*\*|\*\*$/g, ""),
        options: response.options,
        allowCustom: response.allowCustom,
      }];

      questions.push({
        question: "Now that we've thought about this — would you like me to share our thinking with Claude?",
        options: [
          "Yes — send it to Claude",
          "Copy to clipboard, I'll handle it",
          "Not yet — I want to sit with this",
        ],
      });

      this.activeFlow = {
        type: "deep-questions",
        questions,
        answers: [],
        coreIdea,
        topics: analysis.topics,
        answeredCount: 0,
      };

      const firstQ = questions[0];
      const petMsg: CompanionMessage = {
        role: "pet",
        text: response.text,
        timestamp: new Date().toISOString(),
        options: firstQ.options,
        allowCustom: firstQ.allowCustom,
      };
      this.messages.push(petMsg);
      this.sidebar?.postCompanionMessage(petMsg);
    } else {
      // Non-question response — just share the message, no buttons, no flow
      const petMsg: CompanionMessage = {
        role: "pet",
        text: response.text,
        timestamp: new Date().toISOString(),
        // No options — this is an observation, reflection, insight, or encouragement
      };
      this.messages.push(petMsg);
      this.sidebar?.postCompanionMessage(petMsg);
    }

    this.outputChannel.appendLine(`[Companion] ${responseType} response sent (${response.text.length} chars)`);
    this.persistConversation();
  }

  /** Generate advice for questions Claude is asking — Byte adds product-thinking perspective */
  private generateClaudeQuestionAdvice(analysis: ConversationAnalysis): QuestionWithOptions[] {
    const questions: QuestionWithOptions[] = [];

    for (const claudeQ of analysis.claudeQuestions.slice(0, 3)) {
      const advice = this.getByteAdvice(claudeQ, analysis);

      questions.push({
        question: advice.reframed,
        options: advice.options,
        allowCustom: true,
      });
    }

    // Always end with: send decisions back to Claude
    if (questions.length > 0) {
      questions.push({
        question: "Ready to send your answers to Claude?",
        options: [
          "Yes — send it to Claude",
          "Copy to clipboard",
          "Not yet — let me think more",
        ],
      });
    }

    return questions.slice(0, 4);
  }

  /** Byte's concise advice on a question Claude is asking */
  private getByteAdvice(
    claudeQuestion: string,
    analysis: ConversationAnalysis,
  ): { reframed: string; options: string[] } {
    const qLower = claudeQuestion.toLowerCase();
    const shortQ = claudeQuestion.length > 80 ? claudeQuestion.substring(0, 77) + "..." : claudeQuestion;

    if (qLower.includes("extend") || qLower.includes("rebuild") || qLower.includes("from scratch")) {
      return {
        reframed: `Claude asks: "${shortQ}"\n\n💭 Extend what you have unless it's truly broken. Ship sooner.`,
        options: ["Build on what I have", "Start fresh", "Help me decide"],
      };
    }

    if (qLower.includes("core action") || qLower.includes("user needs to") || qLower.includes("flow")) {
      return {
        reframed: `Claude asks: "${shortQ}"\n\n💭 What's the one moment where your user says "this is what I needed"?`,
        options: ["First experience", "Main task end-to-end", "Let me describe it"],
      };
    }

    if (qLower.includes("which") || qLower.includes("v1 or v2") || qLower.includes("pick")) {
      return {
        reframed: `Claude asks: "${shortQ}"\n\n💭 Trust your gut — which is closer to what your user needs?`,
        options: ["The simpler one", "The more complete one", "Best of both"],
      };
    }

    if (qLower.includes("want to") || qLower.includes("should i") || qLower.includes("would you like")) {
      return {
        reframed: `Claude asks: "${shortQ}"\n\n💭 Would your user be stuck without this? If not, it can wait.`,
        options: ["Yes — it's core", "No — it can wait", "Let me think"],
      };
    }

    return {
      reframed: `Claude asks: "${shortQ}"\n\n💭 Answer in your own words — what feels right?`,
      options: ["Let me answer"],
    };
  }

  /**
   * Generate a contextual response based on the chosen response type.
   * This is the core of the "listen more than speak" principle from The Art of Negotiation.
   * Most responses do NOT have option buttons — they're observations, reflections, or insights.
   */
  private generateContextualResponse(
    responseType: ResponseType,
    analysis: ConversationAnalysis,
    pet: typeof PET_COMPANIONS[string],
  ): ContextualResponse | null {
    const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];
    const coreIdea = analysis.coreIdea || "your project";

    switch (responseType) {
      case "observation": {
        if (analysis.phase === "building" && analysis.filesReferenced.length > 0) {
          const files = analysis.filesReferenced.slice(0, 2).join(", ");
          return { type: "observation", text: `${pick(pet.reflections)} You're in the flow — ${files} taking shape.${analysis.decisionsMade.length > 0 ? ` Decided: *${analysis.decisionsMade[analysis.decisionsMade.length - 1]}*.` : ""}` };
        }
        if (analysis.phase === "debugging") {
          return { type: "observation", text: `${pick(pet.reflections)} Working through something tricky. I'm here — not interrupting, just present.` };
        }
        if (analysis.currentFocus) {
          return { type: "observation", text: `${pick(pet.reflections)} Claude is on: *${analysis.currentFocus}*. I'm watching alongside you.` };
        }
        return { type: "observation", text: `${pick(pet.reflections)} Following along with **${coreIdea}**. I'm here.` };
      }

      case "reflection": {
        if (analysis.topics.length >= 2) {
          return { type: "reflection", text: `${pick(pet.nudges)} You keep coming back to ${analysis.topics.slice(0, 2).join(" and ")}. That's your instinct — trust it.` };
        }
        if (analysis.uncertainties.length > 0) {
          const u = analysis.uncertainties[0].substring(0, 50);
          return { type: "reflection", text: `${pick(pet.nudges)} You seemed uncertain about: *"${u}"*. That's okay — clarity comes from building.` };
        }
        if (this.constitution) {
          return { type: "reflection", text: `${pick(pet.nudges)} You set out to help *${this.constitution.targetUser}*. The thread between vision and work is still there.` };
        }
        return { type: "reflection", text: `${pick(pet.nudges)} There's intention behind your work on **${coreIdea}**. Don't lose sight of it.` };
      }

      case "insight": {
        if (analysis.unvalidatedChoices.length > 0) {
          const c = analysis.unvalidatedChoices[0].substring(0, 50);
          return { type: "insight", text: `${pick(pet.checkIns)} Claude decided: *"${c}"*. Worth checking — do you *own* that choice, or did it just happen?` };
        }
        if (analysis.gaps.length > 0 && analysis.phase === "building") {
          return { type: "insight", text: `${pick(pet.checkIns)} Building **${coreIdea}** — great. Can you describe your user's frustration in one sentence?` };
        }
        if (analysis.phase === "polishing") {
          return { type: "insight", text: `${pick(pet.checkIns)} Polishing feels productive — but sometimes shipping is more impactful than refining.` };
        }
        return { type: "insight", text: `${pick(pet.checkIns)} The difference between shipping and not usually isn't skill — it's focus. What to say "not yet" to.` };
      }

      case "encouragement": {
        if (analysis.phase === "debugging") {
          return { type: "encouragement", text: `${pick(pet.empathy)} Debugging = understanding. You'll get through this.` };
        }
        if (analysis.decisionsMade.length > 0) {
          return { type: "encouragement", text: `${pick(pet.empathy)} You decided: *${analysis.decisionsMade[analysis.decisionsMade.length - 1]}*. That takes courage. You're moving forward.` };
        }
        return { type: "encouragement", text: `${pick(pet.empathy)} You showed up to work on **${coreIdea}**. That matters.` };
      }

      case "deeper-conversation": {
        if (analysis.uncertainties.length > 0) {
          const u = analysis.uncertainties[0].substring(0, 50);
          return { type: "deeper-conversation", text: `${pick(pet.nudges)} *"${u}"* — what's really behind this for you?` };
        }
        if (analysis.gaps.some(g => g.includes("target user"))) {
          return { type: "deeper-conversation", text: `${pick(pet.nudges)} Who will use **${coreIdea}**? Not demographics — what's their frustration?` };
        }
        return { type: "deeper-conversation", text: `${pick(pet.nudges)} Deep in building **${coreIdea}** — does the vision still feel the same as when you started?` };
      }

      case "question": {
        return this.generateContextualQuestion(analysis, pet);
      }

      default:
        return null;
    }
  }

  /** Generate a concise context-specific question with dynamic options */
  private generateContextualQuestion(
    analysis: ConversationAnalysis,
    pet: typeof PET_COMPANIONS[string],
  ): ContextualResponse | null {
    const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];
    const coreIdea = analysis.coreIdea || "your project";

    if (analysis.unvalidatedChoices.length > 0) {
      const c = analysis.unvalidatedChoices[0].substring(0, 50);
      return {
        type: "question",
        text: `${pick(pet.checkIns)} Claude chose: *"${c}"*. Does that feel right?`,
        options: ["Yes", "Not quite", "Need to think"],
        allowCustom: true,
      };
    }

    if (analysis.gaps.some(g => g.includes("target user"))) {
      const hints = analysis.topics.slice(0, 2);
      return {
        type: "question",
        text: `${pick(pet.nudges)} Who is **${coreIdea}** for?`,
        options: hints.length > 0
          ? [`Someone in ${hints[0]}`, "Let me describe them"]
          : ["Let me describe them"],
        allowCustom: true,
      };
    }

    if (analysis.gaps.some(g => g.includes("problem"))) {
      return {
        type: "question",
        text: `${pick(pet.nudges)} What frustration does **${coreIdea}** heal?`,
        options: ["Let me describe it"],
        allowCustom: true,
      };
    }

    if (analysis.phase === "deciding" && analysis.uncertainties.length > 0) {
      const u = analysis.uncertainties[0].substring(0, 40);
      return {
        type: "question",
        text: `${pick(pet.checkIns)} Weighing: *"${u}"*. What matters most?`,
        options: ["Ship fast", "Build it right", "Keep it simple"],
        allowCustom: true,
      };
    }

    return null;
  }

  // ───── Send to Claude ─────

  /** Check if user wants to send/copy the pending prompt */
  private isSendToClaude(text: string): boolean {
    const lower = text.toLowerCase();
    return (
      lower.includes("send to claude") ||
      lower.includes("copy to clipboard") ||
      lower.includes("i'll handle it") ||
      lower.includes("ill handle it") ||
      lower.includes("handle it") ||
      lower === "send" ||
      lower === "copy"
    );
  }

  /** Execute the send-to-Claude or copy-to-clipboard action */
  private async executeSendToClaude(userChoice: string): Promise<void> {
    const lower = userChoice.toLowerCase();
    const prompt = this.pendingClaudePrompt;
    this.lastSentPrompt = prompt; // keep for "show me what was copied"
    this.pendingClaudePrompt = ""; // clear pending

    this.outputChannel.appendLine(`[Companion] executeSendToClaude called — choice: "${userChoice}", prompt length: ${prompt.length}`);

    if (!prompt || prompt.trim().length === 0) {
      this.outputChannel.appendLine(`[Companion] WARNING: empty prompt — nothing to send`);
      const petMsg: CompanionMessage = {
        role: "pet",
        text: `Hmm, looks like the prompt was empty. Try running through the questions again — I'll make sure to capture your decisions this time.`,
        timestamp: new Date().toISOString(),
      };
      this.messages.push(petMsg);
      this.sidebar?.postCompanionMessage(petMsg);
      return;
    }

    const pet = PET_COMPANIONS[this.petName.toLowerCase()] ?? PET_COMPANIONS.nova;
    const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)];

    if (lower.includes("not yet") || lower.includes("think more")) {
      const petMsg: CompanionMessage = {
        role: "pet",
        text: `Take all the time you need — there's no rush. Your decisions are safe with me, and I'll be here when you're ready.\n\nWhenever you want to check in, just say "am I on track?" and we'll look at things together.`,
        timestamp: new Date().toISOString(),
      };
      this.messages.push(petMsg);
      this.sidebar?.postCompanionMessage(petMsg);
      return;
    }

    // ── Automatically send to Claude terminal ──
    // Strategy: write the full brief to a temp file, then use terminal.sendText()
    // to send a single-line instruction telling Claude to read it.
    //
    // Why not other approaches:
    //   - clipboard + paste: sidebar webview steals keyboard focus, paste goes nowhere
    //   - sendSequence + bracketed paste: ESC codes confuse Claude Code, crashes session
    //   - sendText(multiline): each \n is an Enter keypress, splits into separate messages
    //
    // This approach is 100% reliable: sendText sends one short line, Claude reads the file.

    const fs = require("fs");
    const os = require("os");
    const path = require("path");

    // Write brief to temp file
    const briefPath = path.join(os.tmpdir(), "codepet-brief.md");
    fs.writeFileSync(briefPath, prompt, "utf-8");

    // Also save to clipboard as backup
    await vscode.env.clipboard.writeText(prompt);

    // Find the best terminal (prefer one running Claude Code)
    const claudeTerminal = this.findClaudeTerminal();

    if (claudeTerminal) {
      // Show the terminal
      claudeTerminal.show(false);
      await new Promise((resolve) => setTimeout(resolve, 300));

      // Send a short single-line instruction to Claude Code
      // Claude will read the file and follow the brief
      const instruction = `Read the file ${briefPath} — it contains my project brief and decisions. Follow those instructions exactly.`;
      claudeTerminal.sendText(instruction, true);

      this.outputChannel.appendLine(`[Companion] Wrote brief to ${briefPath} and sent read instruction to "${claudeTerminal.name}"`);

      const petMsg: CompanionMessage = {
        role: "pet",
        text: `${pick(pet.celebrations)}\n\nYour project brief is with Claude now. It understands:\n• What you're building and the people it's for\n• The pain you're trying to heal\n• What "done" looks like for you\n\nClaude will build with your vision at the center. And I'll be right here — watching, listening, and checking in if things start to drift from what matters to you.`,
        timestamp: new Date().toISOString(),
      };
      this.messages.push(petMsg);
      this.sidebar?.postCompanionMessage(petMsg);
    } else {
      // No terminal found — keep it on clipboard and tell the user
      const petMsg: CompanionMessage = {
        role: "pet",
        text: `${pick(pet.celebrations)}\n\nCopied your project brief to clipboard! I couldn't find an active terminal.\n\n1. Open a terminal and start Claude Code\n2. Press **Cmd+V** to paste\n3. Press **Enter** to send\n\nI'll keep watching and check in if things drift.`,
        timestamp: new Date().toISOString(),
      };
      this.messages.push(petMsg);
      this.sidebar?.postCompanionMessage(petMsg);
    }
  }

  /** Find an active terminal — prefer one running Claude Code */
  findClaudeTerminal(): vscode.Terminal | undefined {
    const allNames = vscode.window.terminals.map((t) => t.name);
    this.outputChannel.appendLine(`[Companion] Terminals available: [${allNames.join(", ")}]`);

    // First: look for a terminal with "claude" in the name
    for (const terminal of vscode.window.terminals) {
      const name = terminal.name.toLowerCase();
      if (name.includes("claude")) {
        this.outputChannel.appendLine(`[Companion] Found Claude terminal: "${terminal.name}"`);
        return terminal;
      }
    }
    // Second: look for common shell terminals (zsh, bash) where Claude Code might be running
    for (const terminal of vscode.window.terminals) {
      const name = terminal.name.toLowerCase();
      if (name.includes("zsh") || name.includes("bash") || name.includes("fish") || name.includes("shell")) {
        this.outputChannel.appendLine(`[Companion] Using shell terminal: "${terminal.name}"`);
        return terminal;
      }
    }
    // Third: use the active terminal (the one the user is looking at)
    if (vscode.window.activeTerminal) {
      this.outputChannel.appendLine(`[Companion] Using active terminal: "${vscode.window.activeTerminal.name}"`);
      return vscode.window.activeTerminal;
    }
    // Last resort: first available terminal
    if (vscode.window.terminals.length > 0) {
      this.outputChannel.appendLine(`[Companion] Fallback to first terminal: "${vscode.window.terminals[0].name}"`);
      return vscode.window.terminals[0];
    }
    this.outputChannel.appendLine(`[Companion] No terminals found!`);
    return undefined;
  }

  /** Format the constitution as a Claude-ready prompt */
  private formatConstitutionForClaude(
    coreIdea: string,
    problem: string,
    targetUser: string,
    successMetric: string,
    doneDefinition: string,
  ): string {
    return [
      `Here's my project brief — please follow this as the foundation for everything you build:`,
      ``,
      `## Project Constitution`,
      `**Project:** ${coreIdea}`,
      `**Problem I'm solving:** ${problem}`,
      `**Target user:** ${targetUser}`,
      `**Success metric:** ${successMetric}`,
      `**v1 is done when:** ${doneDefinition}`,
      ``,
      `## Rules`,
      `- Every feature must serve the target user (${targetUser}) and success metric (${successMetric})`,
      `- Ship the smallest thing that works end-to-end first`,
      `- Flag if I'm over-engineering or building something out of scope`,
      `- Prioritize: must-have for v1 > nice-to-have > future feature`,
      ``,
      `Please confirm you understand, then let's get started.`,
    ].join("\n");
  }

  /** Format the product plan as a Claude-ready prompt */
  private formatPlanForClaude(
    coreIdea: string,
    audience: string,
    painPoint: string,
    scope: string,
    timeline: string,
  ): string {
    return [
      `Here's my product plan — please follow this for implementation:`,
      ``,
      `## Project: ${coreIdea}`,
      `**Target audience:** ${audience}`,
      `**Core pain point:** ${painPoint}`,
      `**v1 scope:** ${scope}`,
      `**Timeline:** ${timeline}`,
      ``,
      `## Approach`,
      `1. Build the smallest shippable thing — one flow, end-to-end`,
      `2. No over-engineering — skip settings pages, profiles, edge cases for now`,
      `3. Ship first, perfect later`,
      `4. Flag if I'm adding scope that doesn't serve the core goal`,
      ``,
      `Please confirm you understand, then let's start with the foundation.`,
    ].join("\n");
  }

  /** Clear conversation history */
  clearHistory(): void {
    this.messages = [];
    this.activeFlow = undefined;
    this.persistConversation();
  }

  /**
   * Persist after every message push.
   * Call this from the sidebar message handler to batch-save.
   */
  afterMessageAdded(): void {
    this.persistConversation();
  }
}
