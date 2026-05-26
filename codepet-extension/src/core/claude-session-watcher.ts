/**
 * ClaudeSessionWatcher — Reads Claude Code conversation transcripts in real-time
 *
 * Claude Code stores every conversation as JSONL files in:
 *   ~/.claude/projects/{project-path-hash}/{session-id}.jsonl
 *
 * This watcher:
 *   1. Finds the most recent JSONL file across all Claude project dirs
 *   2. Polls every 5s for file changes
 *   3. Parses user + assistant messages
 *   4. Performs deep conversation analysis (decisions, uncertainties, gaps)
 *   5. Fires context updates + insights to the CompanionService
 *
 * The watcher does NOT generate questions — it provides rich context
 * so the CompanionService can think about what to ask.
 */

import * as vscode from "vscode";
import { homedir } from "os";
import { join } from "path";
import {
  existsSync,
  readdirSync,
  readFileSync,
  statSync,
} from "fs";

// ───── Types ─────

export interface QuestionWithOptions {
  question: string;
  options: string[];
  allowCustom?: boolean;
}

/** Raw conversation exchange — one user message + Claude's response */
export interface ConversationExchange {
  userMessage: string;
  assistantResponse: string;
  timestamp?: string;
}

/** Deep analysis of the Claude conversation */
export interface ConversationAnalysis {
  /** What is being built — extracted from the full conversation arc */
  coreIdea: string;
  /** Key decisions Claude made or suggested (e.g., "using Supabase for auth") */
  decisionsMade: string[];
  /** Things the user seems uncertain about (questions asked, "not sure", "maybe") */
  uncertainties: string[];
  /** Things Claude is doing that the user hasn't validated (jumped to code, picked a stack) */
  unvalidatedChoices: string[];
  /** Product-thinking gaps — things nobody discussed yet */
  gaps: string[];
  /** What Claude is currently working on / last action */
  currentFocus: string;
  /** The overall phase: exploring, deciding, building, debugging, polishing */
  phase: "exploring" | "deciding" | "building" | "debugging" | "polishing";
  /** Tech topics detected */
  topics: string[];
  /** Files mentioned as created/modified */
  filesReferenced: string[];
  /** Questions Claude is asking the user — extracted from the latest assistant message */
  claudeQuestions: string[];
  /** Whether Claude is waiting for user input (last message is from assistant with questions) */
  isWaitingForUser: boolean;
}

export interface ClaudeSessionContext {
  conversationBuffer: string[];
  userPrompts: string[];
  assistantResponses: string[];
  exchanges: ConversationExchange[];
  analysis: ConversationAnalysis;
  filesCreated: string[];
  filesModified: string[];
  topics: string[];
  isActive: boolean;
  lastActivityAt: number;
  projectSummary: string;
}

export interface SessionInsight {
  type: "new_session" | "conversation_update" | "phase_change";
  summary: string;
  details: string;
  analysis: ConversationAnalysis;
  /** Kept for backwards compat — companion service generates its own now */
  suggestedQuestions: string[];
  deepQuestions?: QuestionWithOptions[];
}

// ───── JSONL Parsing ─────

interface ConversationMessage {
  role: "user" | "assistant";
  text: string;
  timestamp?: string;
}

function parseJsonlFile(filePath: string, maxLines: number = 300): ConversationMessage[] {
  const messages: ConversationMessage[] = [];
  try {
    const content = readFileSync(filePath, "utf-8");
    const lines = content.split("\n").filter((l) => l.trim());
    const recentLines = lines.slice(-maxLines);

    for (const line of recentLines) {
      try {
        const obj = JSON.parse(line);

        // User / Human messages
        const isUser =
          obj.type === "human" ||
          obj.type === "user" ||
          obj.message?.role === "human" ||
          obj.message?.role === "user";

        if (isUser && obj.message?.content) {
          let text = "";
          if (typeof obj.message.content === "string") {
            text = obj.message.content;
          } else if (Array.isArray(obj.message.content)) {
            for (const block of obj.message.content) {
              if (block.type === "text" && block.text) {
                text += block.text + " ";
              } else if (typeof block === "string") {
                text += block + " ";
              }
            }
            text = text.trim();
          }
          if (text.length > 3) {
            messages.push({ role: "user", text, timestamp: obj.timestamp });
          }
        }

        // Assistant messages
        const isAssistant =
          obj.type === "assistant" ||
          obj.message?.role === "assistant";

        if (isAssistant && obj.message?.content) {
          if (Array.isArray(obj.message.content)) {
            for (const block of obj.message.content) {
              if (block.type === "text" && block.text) {
                messages.push({ role: "assistant", text: block.text, timestamp: obj.timestamp });
                break;
              }
            }
          } else if (typeof obj.message.content === "string" && obj.message.content.length > 3) {
            messages.push({ role: "assistant", text: obj.message.content, timestamp: obj.timestamp });
          }
        }
      } catch { /* skip */ }
    }
  } catch { /* file read error */ }
  return messages;
}

// ───── Project Path Discovery ─────

function getClaudeProjectDirs(): string[] {
  const claudeDir = join(homedir(), ".claude", "projects");
  if (!existsSync(claudeDir)) return [];
  try {
    return readdirSync(claudeDir)
      .map((d) => join(claudeDir, d))
      .filter((d) => { try { return statSync(d).isDirectory(); } catch { return false; } });
  } catch { return []; }
}

function findLatestJsonl(dir: string): string | null {
  try {
    const files = readdirSync(dir)
      .filter((f) => f.endsWith(".jsonl"))
      .map((f) => ({ path: join(dir, f), mtime: statSync(join(dir, f)).mtimeMs }))
      .sort((a, b) => b.mtime - a.mtime);
    return files.length > 0 ? files[0].path : null;
  } catch { return null; }
}

function findMostRecentSession(): string | null {
  const dirs = getClaudeProjectDirs();
  let best: { path: string; mtime: number } | null = null;
  for (const dir of dirs) {
    const jsonl = findLatestJsonl(dir);
    if (jsonl) {
      try {
        const mtime = statSync(jsonl).mtimeMs;
        if (!best || mtime > best.mtime) best = { path: jsonl, mtime };
      } catch { /* skip */ }
    }
  }
  return best?.path ?? null;
}

// ───── Deep Conversation Analysis ─────

const TECH_KEYWORDS = [
  "react", "next.js", "nextjs", "vue", "svelte", "angular", "html", "css", "tailwind",
  "typescript", "javascript", "python", "swift", "rust", "go",
  "api", "rest", "graphql", "websocket", "database", "sql", "postgres", "firebase", "supabase",
  "stripe", "auth", "authentication", "login", "signup",
  "component", "hook", "state", "redux", "zustand",
  "server", "client", "ssr", "ssg", "deploy", "docker", "vercel",
  "landing page", "dashboard", "form", "chart", "animation",
  "agent", "mcp", "llm", "ai", "model", "prompt",
  "mvp", "product", "startup", "saas", "marketplace",
];

/** Check if a message is internal system noise (codepet instructions, file paths, etc.) */
function isSystemNoise(msg: string): boolean {
  const lower = msg.toLowerCase();
  return (
    /^(\/|~\/|\.\/|\.\.\/)/.test(msg) ||              // Starts with file path
    lower.includes("/var/folders") ||                   // macOS temp paths
    lower.includes("/tmp/codepet") ||                   // Our temp files
    lower.includes("codepet-brief") ||                  // Our brief file
    (lower.includes("read the file") && lower.includes("it contains")) || // Our send-to-claude instruction
    (lower.includes("project brief") && lower.includes("please confirm")) || // Our formatted prompts
    (lower.includes("project constitution") && lower.includes("please confirm")) ||
    lower.includes("please confirm you understand, then") || // Constitution/plan suffix
    msg.trim().length < 5                               // Too short to be meaningful
  );
}

function analyzeConversation(messages: ConversationMessage[]): ConversationAnalysis {
  const rawUserMsgs = messages.filter((m) => m.role === "user").map((m) => m.text);
  // Filter out system noise (codepet internal messages, file paths, etc.)
  const userMsgs = rawUserMsgs.filter(msg => !isSystemNoise(msg));
  const assistantMsgs = messages.filter((m) => m.role === "assistant").map((m) => m.text);
  const allText = messages.map((m) => m.text).join(" ");
  const allLower = allText.toLowerCase();

  // ── Core idea ──
  let coreIdea = "a new project";
  for (const msg of [...userMsgs].reverse()) {
    const match = msg.match(
      /(?:build|create|develop|make|implement|set up|design|launch|want|need)\s+(?:a\s+|an\s+|the\s+|me\s+)?(.{10,120}?)(?:\.|$|\?|!|\n)/i,
    );
    if (match) {
      const idea = match[1].trim();
      // Don't accept file paths as core ideas
      if (!idea.includes("/") && !idea.includes("\\") && !idea.toLowerCase().includes("codepet-brief")) {
        coreIdea = idea;
        break;
      }
    }
  }
  if (coreIdea === "a new project") {
    const longest = [...userMsgs].sort((a, b) => b.length - a.length)[0] ?? "";
    if (longest.length > 20) coreIdea = longest.substring(0, 100) + (longest.length > 100 ? "..." : "");
  }

  // ── Decisions Claude made/suggested ──
  const decisionsMade: string[] = [];
  const decisionPatterns = [
    /(?:i'?ll|let me|i will|going to|let's)\s+(use|create|set up|implement|add|build|install)\s+(.{5,80}?)(?:\.|$|\n)/gi,
    /(?:using|chose|picked|selected|went with)\s+(.{5,60}?)(?:\s+(?:for|because|since|as)|\.|\n|$)/gi,
    /(?:the best|recommended|suggest)\s+(?:approach|option|choice|way)\s+(?:is|would be)\s+(.{5,80}?)(?:\.|$|\n)/gi,
  ];
  for (const msg of assistantMsgs.slice(-5)) {
    for (const pattern of decisionPatterns) {
      pattern.lastIndex = 0;
      for (const match of msg.matchAll(pattern)) {
        const decision = (match[2] ?? match[1] ?? "").trim();
        if (decision.length > 4 && decision.length < 100 && !decisionsMade.includes(decision)) {
          decisionsMade.push(decision);
        }
      }
    }
  }

  // ── Uncertainties — things the user isn't sure about ──
  const uncertainties: string[] = [];
  const uncertainPatterns = [
    /(?:not sure|unsure|don'?t know|maybe|should i|which one|or should)\s+(.{5,80}?)(?:\?|\.|$|\n)/gi,
    /(?:what do you think|what would you recommend|better to)\s+(.{5,80}?)(?:\?|\.|$|\n)/gi,
    /(?:hmm|idk|i think|possibly)\s+(.{5,60}?)(?:\.|$|\n)/gi,
  ];
  for (const msg of userMsgs.slice(-5)) {
    for (const pattern of uncertainPatterns) {
      pattern.lastIndex = 0;
      for (const match of msg.matchAll(pattern)) {
        const item = match[1].trim();
        if (item.length > 4 && !uncertainties.includes(item)) uncertainties.push(item);
      }
    }
  }

  // ── Unvalidated choices — Claude jumped ahead without user confirming ──
  const unvalidatedChoices: string[] = [];
  // If Claude wrote code or created files without the user explicitly asking for that specific approach
  const codeActions = [
    /(?:I'?ll create|creating|let me (?:create|write|set up))\s+(.{5,80}?)(?:\.|$|\n)/gi,
    /(?:I'?ve (?:created|set up|added|installed))\s+(.{5,80}?)(?:\.|$|\n)/gi,
  ];
  for (const msg of assistantMsgs.slice(-3)) {
    for (const pattern of codeActions) {
      pattern.lastIndex = 0;
      for (const match of msg.matchAll(pattern)) {
        const action = match[1].trim();
        // Check if user explicitly asked for this
        const userAsked = userMsgs.some((u) => u.toLowerCase().includes(action.toLowerCase().substring(0, 20)));
        if (!userAsked && action.length > 4) {
          unvalidatedChoices.push(action);
        }
      }
    }
  }

  // ── Product-thinking gaps ──
  const gaps: string[] = [];
  const hasTargetUser = allLower.includes("user") && (allLower.includes("target") || allLower.includes("audience") || allLower.includes("customer"));
  const hasProblem = allLower.includes("problem") || allLower.includes("pain point") || allLower.includes("pain");
  const hasSuccess = allLower.includes("success") || allLower.includes("metric") || allLower.includes("kpi") || allLower.includes("measure");
  const hasScope = allLower.includes("mvp") || allLower.includes("scope") || allLower.includes("v1") || allLower.includes("done");

  if (!hasTargetUser) gaps.push("No target user defined — who specifically needs this?");
  if (!hasProblem) gaps.push("No problem statement — what pain does this solve?");
  if (!hasSuccess) gaps.push("No success metric — how will you know it worked?");
  if (!hasScope) gaps.push("No scope definition — what does 'done' look like for v1?");

  // If Claude jumped straight to code without any product discussion
  if (gaps.length >= 3 && assistantMsgs.some((m) => m.includes("```") || m.includes("file") || m.includes("create"))) {
    gaps.push("Claude jumped to building before validating the idea");
  }

  // ── Current focus ──
  const lastAssistant = assistantMsgs[assistantMsgs.length - 1] ?? "";
  const lastUser = userMsgs[userMsgs.length - 1] ?? "";
  let currentFocus = lastUser.substring(0, 100);
  if (lastAssistant.includes("```")) {
    currentFocus = "Writing code";
    const fileMatch = lastAssistant.match(/(?:creating?|writing?|file:?)\s+[`"]?([\/\w\-\.]+\.\w{1,8})[`"]?/i);
    if (fileMatch) currentFocus += ` (${fileMatch[1]})`;
  }

  // ── Phase detection ──
  let phase: ConversationAnalysis["phase"] = "exploring";
  if (lastAssistant.includes("```") || allLower.includes("created") || allLower.includes("implemented")) {
    phase = "building";
  }
  if (allLower.includes("error") || allLower.includes("bug") || allLower.includes("fix") || allLower.includes("doesn't work")) {
    phase = "debugging";
  }
  if (allLower.includes("tweak") || allLower.includes("polish") || allLower.includes("style") || allLower.includes("pixel")) {
    phase = "polishing";
  }
  if (uncertainties.length > 1 || allLower.includes("which") || allLower.includes("option")) {
    phase = "deciding";
  }
  // If very early in conversation, it's exploring
  if (messages.length < 4) phase = "exploring";

  // ── Topics ──
  const topics = TECH_KEYWORDS.filter((kw) => allLower.includes(kw));

  // ── Files ──
  const filesReferenced: string[] = [];
  const filePattern = /(?:created?|wrote?|updated?|modified?|file:?)\s*[`"]?([\/\w\-\.]+\.\w{1,8})[`"]?/gi;
  for (const match of allText.matchAll(filePattern)) {
    const file = match[1];
    if (!filesReferenced.includes(file)) filesReferenced.push(file);
  }

  // ── Claude's questions — extract from the last assistant message ──
  const claudeQuestions: string[] = [];
  const lastAssistantMsg = assistantMsgs[assistantMsgs.length - 1] ?? "";
  // Match numbered questions (1. What..., 2. How...) and standalone questions
  const numberedQPattern = /\d+\.\s+(.{10,200}\?)/g;
  for (const match of lastAssistantMsg.matchAll(numberedQPattern)) {
    claudeQuestions.push(match[1].trim());
  }
  // Also match standalone questions if no numbered ones found
  if (claudeQuestions.length === 0) {
    const standaloneQPattern = /(?:^|\n)\s*(.{15,200}\?)\s*(?:\n|$)/g;
    for (const match of lastAssistantMsg.matchAll(standaloneQPattern)) {
      const q = match[1].trim();
      // Filter out rhetorical/filler questions
      if (!q.toLowerCase().startsWith("how can i help") && !q.toLowerCase().startsWith("shall i")) {
        claudeQuestions.push(q);
      }
    }
  }
  // Also catch "Want to..." prompts (common Claude pattern)
  const wantToPattern = /(?:Want to|Do you want to|Would you like to|Shall I)\s+(.{5,100}\?)/gi;
  for (const match of lastAssistantMsg.matchAll(wantToPattern)) {
    const q = match[0].trim();
    if (!claudeQuestions.includes(q)) claudeQuestions.push(q);
  }

  // ── Is Claude waiting for user input? ──
  const lastMessage = messages[messages.length - 1];
  const isWaitingForUser = lastMessage?.role === "assistant" && claudeQuestions.length > 0;

  return {
    coreIdea,
    decisionsMade,
    uncertainties: uncertainties.slice(0, 5),
    unvalidatedChoices: unvalidatedChoices.slice(0, 5),
    gaps,
    currentFocus,
    phase,
    topics,
    filesReferenced,
    claudeQuestions: claudeQuestions.slice(0, 5),
    isWaitingForUser,
  };
}

// ───── Build Conversation Exchanges ─────

function buildExchanges(messages: ConversationMessage[]): ConversationExchange[] {
  const exchanges: ConversationExchange[] = [];
  for (let i = 0; i < messages.length; i++) {
    if (messages[i].role === "user") {
      const next = messages[i + 1];
      exchanges.push({
        userMessage: messages[i].text,
        assistantResponse: next?.role === "assistant" ? next.text : "",
        timestamp: messages[i].timestamp,
      });
    }
  }
  return exchanges;
}

// ───── ClaudeSessionWatcher Class ─────

export class ClaudeSessionWatcher implements vscode.Disposable {
  private disposables: vscode.Disposable[] = [];
  private sessionContext: ClaudeSessionContext;
  private pollTimer: NodeJS.Timeout | undefined;
  private watchedFile: string | null = null;
  private lastFileSize = 0;
  private lastMessageCount = 0;
  private insightCooldown = 0;
  private lastPhase: ConversationAnalysis["phase"] | null = null;

  private _onInsight = new vscode.EventEmitter<SessionInsight>();
  readonly onInsight = this._onInsight.event;

  private _onContextUpdate = new vscode.EventEmitter<ClaudeSessionContext>();
  readonly onContextUpdate = this._onContextUpdate.event;

  private outputChannel: vscode.OutputChannel;

  constructor(outputChannel?: vscode.OutputChannel) {
    this.outputChannel = outputChannel ?? vscode.window.createOutputChannel("Codepet Watcher");
    this.sessionContext = this.freshContext();

    this.pollTimer = setInterval(() => this.poll(), 5000);
    setTimeout(() => this.poll(), 8000);

    const projectDirs = getClaudeProjectDirs();
    this.outputChannel.appendLine(`[ClaudeWatcher] Initialized — found ${projectDirs.length} Claude project dir(s)`);
    for (const dir of projectDirs.slice(0, 5)) {
      this.outputChannel.appendLine(`[ClaudeWatcher]   → ${dir}`);
    }
  }

  get context(): ClaudeSessionContext {
    return { ...this.sessionContext };
  }

  get hasActiveSession(): boolean {
    return this.sessionContext.userPrompts.length > 0;
  }

  // ───── Polling ─────

  private poll(): void {
    const latestFile = findMostRecentSession();
    if (!latestFile) return;

    try {
      const stat = statSync(latestFile);
      const currentSize = stat.size;

      if (latestFile !== this.watchedFile || currentSize > this.lastFileSize) {
        const isNew = latestFile !== this.watchedFile;
        this.watchedFile = latestFile;
        this.lastFileSize = currentSize;

        if (isNew) {
          this.outputChannel.appendLine(`[ClaudeWatcher] Found session file: ${latestFile}`);
          this.lastPhase = null;
        }

        this.parseSession(latestFile);
      }
    } catch { /* file access error */ }
  }

  private parseSession(filePath: string): void {
    const messages = parseJsonlFile(filePath);

    this.outputChannel.appendLine(
      `[ClaudeWatcher] Parsed ${filePath.split("/").pop()}: ${messages.length} messages (prev: ${this.lastMessageCount})`
    );

    if (messages.length === 0) return;

    const userPrompts = messages.filter((m) => m.role === "user").map((m) => m.text);
    const assistantResponses = messages.filter((m) => m.role === "assistant").map((m) => m.text);

    this.outputChannel.appendLine(
      `[ClaudeWatcher] ${userPrompts.length} user, ${assistantResponses.length} assistant`
    );

    // ── Deep analysis ──
    const analysis = analyzeConversation(messages);
    const exchanges = buildExchanges(messages);

    this.outputChannel.appendLine(
      `[ClaudeWatcher] Analysis — phase: ${analysis.phase}, decisions: ${analysis.decisionsMade.length}, gaps: ${analysis.gaps.length}, uncertainties: ${analysis.uncertainties.length}, claudeQs: ${analysis.claudeQuestions.length}, waitingForUser: ${analysis.isWaitingForUser}`
    );
    if (analysis.claudeQuestions.length > 0) {
      for (const q of analysis.claudeQuestions) {
        this.outputChannel.appendLine(`[ClaudeWatcher]   Q: ${q.substring(0, 80)}`);
      }
    }

    // ── Update context ──
    this.sessionContext = {
      conversationBuffer: messages.slice(-20).map((m) => `${m.role}: ${m.text.substring(0, 300)}`),
      userPrompts,
      assistantResponses,
      exchanges: exchanges.slice(-10),
      analysis,
      filesCreated: analysis.filesReferenced,
      filesModified: [],
      topics: analysis.topics,
      isActive: true,
      lastActivityAt: Date.now(),
      projectSummary: `Building: ${analysis.coreIdea}. Phase: ${analysis.phase}. ${analysis.gaps.length} product gaps.`,
    };

    this._onContextUpdate.fire(this.sessionContext);

    // ── Fire insight ──
    const isFirstDetection = this.lastMessageCount === 0 && messages.length > 0;
    const hasNewMessages = messages.length > this.lastMessageCount && this.lastMessageCount > 0;
    const phaseChanged = this.lastPhase !== null && this.lastPhase !== analysis.phase;

    if (isFirstDetection || hasNewMessages) {
      const newMessages = hasNewMessages ? messages.slice(this.lastMessageCount) : [];
      const hasNewAssistant = isFirstDetection
        ? userPrompts.length > 0
        : newMessages.some((m) => m.role === "assistant");

      // Use shorter cooldown (10s) when Claude is asking questions — the user is waiting
      const cooldownMs = analysis.isWaitingForUser ? 10000 : 30000;

      if (hasNewAssistant && Date.now() > this.insightCooldown) {
        this.insightCooldown = Date.now() + cooldownMs;

        const insightType = isFirstDetection ? "new_session"
          : phaseChanged ? "phase_change"
          : "conversation_update";

        const insight: SessionInsight = {
          type: insightType,
          summary: `${analysis.phase}: ${analysis.coreIdea.substring(0, 60)}`,
          details: analysis.coreIdea,
          analysis,
          suggestedQuestions: [],
        };

        this._onInsight.fire(insight);
        this.outputChannel.appendLine(
          `[ClaudeWatcher] Fired ${insightType} insight (cooldown: ${cooldownMs/1000}s) — claudeQs: ${analysis.claudeQuestions.length}, core: ${analysis.coreIdea.substring(0, 50)}`
        );
        // Only update lastMessageCount when we successfully fire
        this.lastPhase = analysis.phase;
        this.lastMessageCount = messages.length;
      } else {
        // DON'T update lastMessageCount — we want to retry on next poll
        this.outputChannel.appendLine(
          `[ClaudeWatcher] Queued insight — cooldown remaining: ${Math.max(0, Math.round((this.insightCooldown - Date.now()) / 1000))}s, hasNewAssistant: ${hasNewAssistant}, msgs: ${messages.length}`
        );
        this.lastPhase = analysis.phase;
        // Keep lastMessageCount unchanged so we retry next poll
      }
    } else {
      // No new messages of interest — still update tracking
      this.lastPhase = analysis.phase;
      this.lastMessageCount = messages.length;
    }
  }

  private freshContext(): ClaudeSessionContext {
    return {
      conversationBuffer: [],
      userPrompts: [],
      assistantResponses: [],
      exchanges: [],
      analysis: {
        coreIdea: "",
        decisionsMade: [],
        uncertainties: [],
        unvalidatedChoices: [],
        gaps: [],
        currentFocus: "",
        phase: "exploring",
        topics: [],
        filesReferenced: [],
        claudeQuestions: [],
        isWaitingForUser: false,
      },
      filesCreated: [],
      filesModified: [],
      topics: [],
      isActive: false,
      lastActivityAt: 0,
      projectSummary: "",
    };
  }

  resetSession(): void {
    this.sessionContext = this.freshContext();
    this.lastMessageCount = 0;
    this.lastFileSize = 0;
    this.lastPhase = null;
  }

  dispose(): void {
    if (this.pollTimer) clearInterval(this.pollTimer);
    this._onInsight.dispose();
    this._onContextUpdate.dispose();
    for (const d of this.disposables) d.dispose();
  }
}
