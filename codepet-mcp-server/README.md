# Codepet MCP Server

A local MCP server that captures coding context, tracks developer sessions, and powers daily insights. Compatible with **Claude Code**, **Cursor**, **VS Code**, **Windsurf**, and any MCP-compliant client.

Built by [MURROR](https://murror.app).

---

## Quick Start

### 1. Install

```bash
cd codepet-mcp-server
npm install
npm run build
```

### 2. Connect to Your Editor

**Claude Code** — add to `~/.claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "codepet": {
      "command": "node",
      "args": ["/full/path/to/codepet-mcp-server/dist/index.js"]
    }
  }
}
```

**Cursor** — add to `.cursor/mcp.json` in your project root:
```json
{
  "servers": {
    "codepet": {
      "command": "node",
      "args": ["/full/path/to/codepet-mcp-server/dist/index.js"]
    }
  }
}
```

**VS Code / Windsurf** — add to `.vscode/mcp.json` in your project root:
```json
{
  "servers": {
    "codepet": {
      "command": "node",
      "args": ["/full/path/to/codepet-mcp-server/dist/index.js"]
    }
  }
}
```

Replace `/full/path/to/` with the actual path on your machine.

### 3. Verify It Works

Once connected, ask your AI assistant:

> "Scan my project and tell me what I'm working with"

If Codepet responds with your project structure, languages, and dependencies — you're all set.

### 4. Test with Inspector (Optional)

```bash
npm run inspect
```

Opens the MCP Inspector — a browser-based UI to test all tools and resources interactively.

---

## Features Overview

| What | How |
|------|-----|
| Scan your project structure | Ask AI: "What am I working with?" |
| See recent git activity | Ask AI: "What did I commit today?" |
| Check for build errors | Ask AI: "Are there any compiler errors?" |
| Read any file with metadata | Ask AI: "Show me src/index.ts" |
| Track skill progress | Ask AI: "How are my skills progressing?" |
| Generate daily summary | Ask AI: "Generate my daily coding summary" |

---

## Phase 1 — Context Capture

### Tools
| Tool | Description |
|------|-------------|
| `scan_project` | Detect languages, frameworks, structure, and dependencies |
| `get_git_context` | Recent commits, diffs, branch info, activity patterns |
| `get_diagnostics` | Compiler errors, lint warnings, error→fix tracking |

### Resources
| URI | Description |
|-----|-------------|
| `codepet://project/summary` | Cached project fingerprint |
| `codepet://user/profile` | Pet name, level, streak, skills |
| `codepet://missions/active` | Contextual learning missions |

## Phase 2 — Learning & Skill Mapping

### Tools
| Tool | Description |
|------|-------------|
| `get_file_content` | Read file with language detection, line ranges, and metadata |
| `get_learning_context` | Aggregated learning progress: error patterns, streaks, skill tree XP, recommendations |

### Resources
| URI | Description |
|-----|-------------|
| `codepet://skills/progress` | Skill tree progress mapped from coding activity (16 skills, 4 kingdoms) |

### Skill Tree Mapping
Coding activity is automatically mapped to Codepet's 16 skills across 4 kingdoms:

| Kingdom | Tier | Skills |
|---------|------|--------|
| The Molten Forge | 1 — Foundations | Prompt Clarity, Error Reading, Tool Basics, Code Judgment |
| The Frozen Spire | 2 — Context & Structure | Context Setting, AI Rules Files, Documentation, Project Structure |
| The Eternal Garden | 3 — Advanced | Tool Switching, Scope Mgmt, Design System, Prompt Iteration |
| The Mystic Grove | 4 — Expert | User Personas, Context Windows, AI Architecture, Second Brain |

Each skill has 5 levels. XP is earned automatically based on what you do — reading files, fixing errors, exploring projects, and using different tools all contribute to different skills.

## Phase 3 — Daily Summaries + macOS App Integration

### Tools
| Tool | Description |
|------|-------------|
| `generate_daily_summary` | LLM-powered daily summary with stats, narrative, and in-character pet reaction |

### Resources
| URI | Description |
|-----|-------------|
| `codepet://summary/today` | Today's daily summary (call `generate_daily_summary` to create) |

### macOS App Integration
The Codepet macOS app reads `~/.codepet/` data via `MCPBridgeService.swift`:
- Polls every 30s for new events, summaries, and skill progress
- Merges real coding XP into the app's progression system (with double-count prevention)
- Updates pet mood and energy based on daily coding activity
- Available as `@EnvironmentObject` throughout the SwiftUI view hierarchy

### Session Logger
Every tool call is automatically logged to `~/.codepet/` as JSON files, organized by date. This data powers daily summaries and skill tracking.

## Setup

```bash
cd codepet-mcp-server
npm install
npm run build
```

### Add to Claude Code
```json
// ~/.claude/claude_desktop_config.json
{
  "mcpServers": {
    "codepet": {
      "command": "node",
      "args": ["/path/to/codepet-mcp-server/dist/index.js"]
    }
  }
}
```

### Add to Cursor / VS Code
```json
// .cursor/mcp.json or .vscode/mcp.json
{
  "servers": {
    "codepet": {
      "command": "node",
      "args": ["/path/to/codepet-mcp-server/dist/index.js"]
    }
  }
}
```

## Usage

Once connected, the AI client can call tools naturally:

> "Scan my project and tell me what I'm working with"
> → calls `scan_project`

> "What did I commit today?"
> → calls `get_git_context`

> "Are there any build errors?"
> → calls `get_diagnostics`

> "Show me the contents of src/index.ts"
> → calls `get_file_content`

> "How am I progressing on my skills?"
> → calls `get_learning_context`

## Data Storage

All data is stored locally in `~/.codepet/`:

```
~/.codepet/
├── events/
│   └── 2026-04-07.json    # Today's tool call events
├── summaries/
│   └── 2026-04-07.json    # Generated daily summaries
└── profile.json            # User profile + cached project data
```

## Roadmap

- ~~**Phase 1**: `scan_project`, `get_git_context`, `get_diagnostics` tools + resources~~ ✅
- ~~**Phase 2**: `get_file_content`, `get_learning_context` tools + skill tree mapping~~ ✅
- ~~**Phase 3**: Daily summary generation (LLM-powered), Codepet macOS app integration~~ ✅
- **Future**: SQLite backend (better-sqlite3), real-time file watching, pet evolution

---

## Troubleshooting

**"Server not found" or tools don't appear:** Make sure you ran `npm run build` and the path in your config points to `dist/index.js` (not `src/index.ts`). The path must be absolute.

**No data in `~/.codepet/`:** The server only writes data when tools are called. Ask your AI to run `scan_project` or `get_git_context` to generate the first events.

**Daily summary is empty:** Run `generate_daily_summary` — it creates the summary on demand. It needs at least a few tool calls logged in today's events file to produce meaningful output.

**macOS app doesn't show MCP data:** The macOS app polls `~/.codepet/` every 30 seconds. Make sure the MCP server has been used at least once today so event files exist. Check the Xcode console for `[MCPBridge]` log messages.

**Permission errors on `~/.codepet/`:** The server creates this directory automatically. If it fails, create it manually: `mkdir -p ~/.codepet/events ~/.codepet/summaries`

---

## License

MIT — see the root [LICENSE](../LICENSE) file.
