/**
 * Skill Tree Mapping — Maps coding activity to Codepet's 16 skills
 *
 * 4 Kingdoms × 4 Skills each:
 *
 * Tier 1 — The Molten Forge (Foundations)
 *   prompt-clarity, error-reading, tool-basics, code-judgment
 *
 * Tier 2 — The Frozen Spire (Context & Structure)
 *   context-setting, rules-files, documentation, file-structure
 *
 * Tier 3 — The Eternal Garden (Advanced)
 *   tool-switching, scope-mgmt, design-system, iteration
 *
 * Tier 4 — The Mystic Grove (Expert)
 *   personas, context-windows, architecture, second-brain
 *
 * Each coding activity (tool calls, git actions, diagnostics, file reads)
 * contributes XP to relevant skills based on what the developer is doing.
 */

import type { StoredEvent } from "../logger/session-logger.js";

export interface SkillDefinition {
  id: string;
  name: string;
  icon: string;
  kingdom: string;
  tier: number;
  nodeType: "lesson" | "challenge" | "boss";
}

export interface SkillProgress extends SkillDefinition {
  xp: number;
  level: number;
  maxLevel: number;
  xpProgress: number;      // XP toward next level
  xpToNextLevel: number;   // XP remaining for next level
}

// XP required per level: 0→1: 50, 1→2: 100, 2→3: 200, 3→4: 400, 4→5: 800
const XP_PER_LEVEL = [50, 100, 200, 400, 800];

function xpToLevel(xp: number): { level: number; progress: number; remaining: number } {
  let remaining = xp;
  for (let lvl = 0; lvl < XP_PER_LEVEL.length; lvl++) {
    if (remaining < XP_PER_LEVEL[lvl]) {
      return { level: lvl, progress: remaining, remaining: XP_PER_LEVEL[lvl] - remaining };
    }
    remaining -= XP_PER_LEVEL[lvl];
  }
  return { level: 5, progress: 0, remaining: 0 }; // Max level
}

// ─── Skill Tree Definition (mirrors SkillData.swift) ───

export const SKILL_TREE: SkillDefinition[] = [
  // Tier 1 — The Molten Forge
  { id: "prompt-clarity", name: "Prompt Clarity", icon: "✏️", kingdom: "The Molten Forge", tier: 1, nodeType: "lesson" },
  { id: "error-reading", name: "Error Reading", icon: "🔍", kingdom: "The Molten Forge", tier: 1, nodeType: "lesson" },
  { id: "tool-basics", name: "Tool Basics", icon: "🛠️", kingdom: "The Molten Forge", tier: 1, nodeType: "challenge" },
  { id: "code-judgment", name: "Code Judgment", icon: "⚖️", kingdom: "The Molten Forge", tier: 1, nodeType: "boss" },

  // Tier 2 — The Frozen Spire
  { id: "context-setting", name: "Context Setting", icon: "🎯", kingdom: "The Frozen Spire", tier: 2, nodeType: "lesson" },
  { id: "rules-files", name: "AI Rules Files", icon: "📏", kingdom: "The Frozen Spire", tier: 2, nodeType: "lesson" },
  { id: "documentation", name: "Documentation", icon: "📄", kingdom: "The Frozen Spire", tier: 2, nodeType: "challenge" },
  { id: "file-structure", name: "Project Structure", icon: "📁", kingdom: "The Frozen Spire", tier: 2, nodeType: "boss" },

  // Tier 3 — The Eternal Garden
  { id: "tool-switching", name: "Tool Switching", icon: "🔄", kingdom: "The Eternal Garden", tier: 3, nodeType: "lesson" },
  { id: "scope-mgmt", name: "Scope Mgmt", icon: "📦", kingdom: "The Eternal Garden", tier: 3, nodeType: "challenge" },
  { id: "design-system", name: "Design System", icon: "🎨", kingdom: "The Eternal Garden", tier: 3, nodeType: "lesson" },
  { id: "iteration", name: "Prompt Iteration", icon: "🔁", kingdom: "The Eternal Garden", tier: 3, nodeType: "boss" },

  // Tier 4 — The Mystic Grove
  { id: "personas", name: "User Personas", icon: "🧩", kingdom: "The Mystic Grove", tier: 4, nodeType: "lesson" },
  { id: "context-windows", name: "Context Windows", icon: "🧠", kingdom: "The Mystic Grove", tier: 4, nodeType: "challenge" },
  { id: "architecture", name: "AI Architecture", icon: "🏗️", kingdom: "The Mystic Grove", tier: 4, nodeType: "lesson" },
  { id: "second-brain", name: "Second Brain", icon: "💡", kingdom: "The Mystic Grove", tier: 4, nodeType: "boss" },
];

// ─── Activity → Skill XP Mapping Rules ───

interface XPRule {
  skillId: string;
  xp: number;
  match: (event: StoredEvent) => boolean;
}

const XP_RULES: XPRule[] = [
  // ── Tier 1: Foundations ──

  // Prompt Clarity: XP for every tool call (you're prompting AI)
  { skillId: "prompt-clarity", xp: 2, match: (e) => e.type === "tool_call" },

  // Error Reading: XP for encountering and resolving errors
  { skillId: "error-reading", xp: 5, match: (e) => e.type === "learning" && e.action === "error_encountered" },
  { skillId: "error-reading", xp: 10, match: (e) => e.type === "diagnostic" && e.action === "clean" },

  // Tool Basics: XP for using different tools
  { skillId: "tool-basics", xp: 3, match: (e) => e.type === "tool_call" && e.action === "scan_project" },
  { skillId: "tool-basics", xp: 3, match: (e) => e.type === "tool_call" && e.action === "get_git_context" },
  { skillId: "tool-basics", xp: 3, match: (e) => e.type === "tool_call" && e.action === "get_diagnostics" },
  { skillId: "tool-basics", xp: 3, match: (e) => e.type === "tool_call" && e.action === "get_file_content" },

  // Code Judgment: XP for reviewing code (reading files) and fixing errors
  { skillId: "code-judgment", xp: 3, match: (e) => e.type === "tool_call" && e.action === "get_file_content" },
  { skillId: "code-judgment", xp: 8, match: (e) =>
    e.type === "diagnostic" && (e.metadata?.resolvedErrors as number) > 0
  },

  // ── Tier 2: Context & Structure ──

  // Context Setting: XP for scanning projects (understanding context)
  { skillId: "context-setting", xp: 10, match: (e) => e.type === "tool_call" && e.action === "scan_project" },

  // Rules Files: XP for reading config/rules files
  { skillId: "rules-files", xp: 5, match: (e) => {
    const file = e.file ?? "";
    return e.type === "tool_call" && e.action === "get_file_content" &&
      (/\.(eslintrc|prettierrc|editorconfig|cursorrules)/i.test(file) ||
       /CLAUDE\.md|\.cursor\/rules/i.test(file));
  }},

  // Documentation: XP for reading/writing docs
  { skillId: "documentation", xp: 3, match: (e) => {
    const file = e.file ?? "";
    return e.type === "tool_call" && e.action === "get_file_content" &&
      /\.(md|txt|rst|doc)$/i.test(file);
  }},

  // Project Structure: XP for scanning and exploring project structure
  { skillId: "file-structure", xp: 5, match: (e) => e.type === "tool_call" && e.action === "scan_project" },
  { skillId: "file-structure", xp: 2, match: (e) => e.type === "tool_call" && e.action === "get_file_content" },

  // ── Tier 3: Advanced ──

  // Tool Switching: XP when using multiple different tools in a session
  { skillId: "tool-switching", xp: 5, match: (e) => e.type === "tool_call" && e.action === "get_learning_context" },

  // Scope Management: XP for git context (understanding scope of changes)
  { skillId: "scope-mgmt", xp: 3, match: (e) => e.type === "git" && e.action === "commit" },

  // Design System: XP for reading style/design files
  { skillId: "design-system", xp: 5, match: (e) => {
    const file = e.file ?? "";
    return e.type === "tool_call" && e.action === "get_file_content" &&
      /\.(css|scss|less|styled|theme)/i.test(file);
  }},

  // Iteration: XP for repeated diagnostic cycles (iterate until clean)
  { skillId: "iteration", xp: 5, match: (e) => e.type === "diagnostic" },

  // ── Tier 4: Expert ──

  // Context Windows: XP for reading large files or many files
  { skillId: "context-windows", xp: 3, match: (e) =>
    e.type === "tool_call" && e.action === "get_file_content" &&
    ((e.metadata?.totalLines as number) ?? 0) > 200
  },

  // Architecture: XP for scanning project and exploring structure files
  { skillId: "architecture", xp: 5, match: (e) => e.type === "tool_call" && e.action === "scan_project" },
  { skillId: "architecture", xp: 3, match: (e) => {
    const file = e.file ?? "";
    return e.type === "tool_call" && e.action === "get_file_content" &&
      /(config|setup|index|main|app)\./i.test(file);
  }},

  // Second Brain: XP for checking learning context (meta-learning)
  { skillId: "second-brain", xp: 10, match: (e) => e.type === "tool_call" && e.action === "get_learning_context" },

  // Personas: XP for reading test/spec files (understanding users)
  { skillId: "personas", xp: 3, match: (e) => {
    const file = e.file ?? "";
    return e.type === "tool_call" && e.action === "get_file_content" &&
      /\.(test|spec|e2e)\./i.test(file);
  }},
];

/**
 * Map a set of session events to skill XP progress.
 * Returns the full skill tree with XP and level data.
 */
export function mapActivityToSkills(events: StoredEvent[]): SkillProgress[] {
  // Accumulate XP per skill
  const xpMap = new Map<string, number>();
  for (const skill of SKILL_TREE) {
    xpMap.set(skill.id, 0);
  }

  for (const event of events) {
    for (const rule of XP_RULES) {
      if (rule.match(event)) {
        xpMap.set(rule.skillId, (xpMap.get(rule.skillId) ?? 0) + rule.xp);
      }
    }
  }

  // Build progress array
  return SKILL_TREE.map((skill) => {
    const xp = xpMap.get(skill.id) ?? 0;
    const { level, progress, remaining } = xpToLevel(xp);
    return {
      ...skill,
      xp,
      level,
      maxLevel: 5,
      xpProgress: progress,
      xpToNextLevel: remaining,
    };
  });
}
