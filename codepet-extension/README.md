# Codepet VS Code Extension

Your pixel-art coding pet lives in your editor. Tracks coding sessions, scans code in real-time, auto-fixes TypeScript errors, and maps your skills across 4 kingdoms.

Built by [MURROR](https://murror.app).

**Compatible with:** VS Code, Cursor, Windsurf, VSCodium, and any VS Code fork.

---

## Quick Start (End Users)

### Install from VSIX

1. Download or build the `.vsix` file (see [Build from Source](#build-from-source) below)
2. Open your editor (VS Code / Cursor / Windsurf / VSCodium)
3. Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux)
4. Type **"Install from VSIX"** and select it
5. Browse to the `.vsix` file and click Install
6. Reload the window when prompted

### CLI Install (Alternative)

```bash
# VS Code
code --install-extension codepet-0.9.3.vsix

# Cursor
cursor --install-extension codepet-0.9.3.vsix

# Windsurf
windsurf --install-extension codepet-0.9.3.vsix

# VSCodium
codium --install-extension codepet-0.9.3.vsix
```

### First Launch

After installing, you'll see the Codepet paw icon in the activity bar (left sidebar). Click it to open the dashboard. Your pet will greet you with a welcome screen.

---

## Features

### Real-Time Code Scanner
Scans your code as you type and on every save. Detects issues like `console.log` left in code, `var` instead of `let/const`, empty catch blocks, magic numbers, nested ternaries, debugger statements, TODO/FIXME comments, and more. Supports JavaScript, TypeScript, Python, Swift, Go, Rust, and HTML.

### Fix Engine (90+ TypeScript Error Codes)
When the scanner detects TypeScript compiler errors, Codepet knows how to fix them. Click **Fix** on any finding, or click **Auto-fix All** to fix every issue at once — no manual selection required.

Fix strategies include adding type annotations, casting arguments, renaming duplicates, initializing variables, adding non-null assertions, suppressing with `@ts-ignore`, and more. Each error code maps to a context-aware strategy (e.g., unused imports get `@ts-ignore`, not underscore-prefix).

### Sidebar Dashboard
Shows your pet's mood, today's coding stats (time, commits, lines, bugs fixed), language breakdown, skill progress across 4 kingdoms, session timeline, and a live event feed.

### Pet Reactions
Your pet reacts to what you do — celebrates when you fix bugs, gets concerned when errors pile up, and cheers when you hit streaks.

### Session Tracking
Automatically tracks coding sessions with idle detection. Summarizes your work when you take a break.

### Cloud Sync (macOS)
If you have the Codepet macOS app installed, the extension auto-links with your account, syncing your pet name, progress, and stats via Firestore.

---

## Build from Source (Developers)

### Prerequisites

- Node.js >= 18
- npm

### Build

```bash
cd codepet-extension
npm install
npm run build
```

### Package as VSIX

```bash
npx @vscode/vsce package --no-dependencies
```

This generates `codepet-0.9.3.vsix` in the current directory.

### Run Tests

```bash
npm test
```

Runs the full integration test suite (build verification, manifest checks, MCP data parsing, VSIX packaging, entrypoint verification). 37 tests, no VS Code instance required.

### Watch Mode (Development)

```bash
npm run watch
```

Recompiles on every file change. Pair with the **Extension Development Host** in VS Code (`F5`) to test live.

---

## Commands

| Command | Description |
|---------|-------------|
| `Codepet: Open Dashboard` | Open the sidebar dashboard |
| `Codepet: Show Today's Summary` | Show your daily coding summary |
| `Codepet: Show Welcome Screen` | Show the personalized welcome greeting |
| `Codepet: Fix Issue at Line` | Fix a pattern-based code issue at the current line |
| `Codepet: Fix TypeScript Diagnostic` | Fix a TypeScript compiler error using the fix engine |
| `Codepet: Toggle Code Scanner Notifications` | Turn scanner notifications on/off |
| `Codepet: Sync to Cloud Now` | Force sync session data to Firestore |
| `Codepet: Refresh Data` | Refresh MCP data from disk |

---

## Settings

All settings are under `codepet.*` in your editor settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `codepet.petName` | Nova | Your pet's name |
| `codepet.userName` | *(blank)* | Your name (shown in welcome greeting) |
| `codepet.scanOnType` | true | Scan code as you type (disable for scan-on-save only) |
| `codepet.scanNotifications` | true | Show popup notifications for scanner findings |
| `codepet.showWelcome` | true | Show welcome screen on editor open |
| `codepet.autoLinkApp` | true | Auto-link with the Codepet macOS app |
| `codepet.syncIntervalSeconds` | 30 | How often to sync data to Firestore |
| `codepet.breakReminderMinutes` | 60 | Minutes before your pet reminds you to take a break (0 = off) |
| `codepet.idleTimeoutMinutes` | 5 | Minutes of inactivity before session summary |
| `codepet.mcpDataDir` | *(blank)* | Custom path to `.codepet/` data directory |

---

## Project Structure

```
codepet-extension/
├── src/
│   ├── core/
│   │   ├── code-scanner.ts      # Real-time pattern + diagnostic scanner
│   │   ├── fix-engine.ts        # Context-aware TypeScript error fixer
│   │   ├── ts-error-codes.ts    # Knowledge base: 90+ TS error codes → fix strategies
│   │   ├── pet-reactions.ts     # Pet mood and reaction engine
│   │   ├── file-watcher.ts      # MCP data file watcher
│   │   ├── session-tracker.ts   # Coding session tracking with idle detection
│   │   └── trigger-engine.ts    # Event trigger system
│   ├── services/
│   │   └── cloud-sync.ts        # Firestore cloud sync + macOS app integration
│   ├── ui/
│   │   ├── sidebar-provider.ts  # Sidebar webview dashboard
│   │   ├── status-bar.ts        # Status bar widget
│   │   └── welcome-panel.ts     # Welcome screen panel
│   └── extension.ts             # Main entry point
├── media/                        # SVG character sprites + icons
├── test/                         # Integration tests
├── package.json
└── tsconfig.json
```

---

## Troubleshooting

**Extension doesn't appear in sidebar:** Reload the window (`Cmd+Shift+P` → "Reload Window"). Check that the extension is enabled in the Extensions panel.

**Scanner not detecting TypeScript errors:** Make sure your project has a `tsconfig.json` and the TypeScript language server is running. The scanner bridges VS Code's built-in diagnostics.

**Cloud sync shows "Unauthenticated":** Sign in to the Codepet macOS app first. The extension reads your credentials from the app's UserDefaults. This only works on macOS.

**Auto-fix All doesn't fix everything:** Some fixes require the TypeScript language server to reprocess the file. The sidebar rescans automatically after fixes — give it 1-2 seconds.

---

## License

MIT — see the root [LICENSE](../LICENSE) file.
