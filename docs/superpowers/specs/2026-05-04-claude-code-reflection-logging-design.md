# Claude Code → Reflection Auto-Logging

**Date:** 2026-05-04
**Status:** Spec — pending implementation plan

## Problem

CodePet's Reflection tab (`codepet/Views/Reflection/`) has `EventSource.claudeCode` already defined as a captured event source, but no mechanism exists to actually capture user activity from Claude Code sessions. Today the Reflection tab shows mock data only.

We want: when the user works with Claude Code on any project, the **decision moments** of that session automatically appear in CodePet's Reflection tab.

## Non-goals

- Not capturing every tool call (Read/Grep/Glob/LS are noise).
- Not capturing AI responses verbatim — Reflection is about user's decisions, not AI output.
- Not enriching events with `trigger` classification or pet `context` narrative — those fields stay `nil` in MVP and become a v1.1 enrichment pass.
- Not patching the user's `~/.claude/settings.json` automatically — install is a one-time manual step.

## Architecture

```
┌─────────────────┐    JSONL append    ┌──────────────────────┐
│  Claude Code    │ ─────────────────> │ ~/.codepet/          │
│  (hooks)        │                    │   events.jsonl       │
└─────────────────┘                    └──────────────────────┘
                                                  │
                                                  │ poll 1.5s
                                                  v
                                       ┌──────────────────────┐
                                       │  CodePet macOS app   │
                                       │  ReflectionEventStore│
                                       │  → ReflectionTab     │
                                       └──────────────────────┘
```

Two components, fully decoupled by a JSONL file at `~/.codepet/events.jsonl`:

1. **Hook layer** (Claude Code side) — three shell scripts triggered by `UserPromptSubmit` and `PostToolUse` hooks. Each script reads the hook's stdin JSON, applies a decision filter, and appends a single JSON line to the events file. Independent of CodePet.app — events queue up even when the app is closed.

2. **Reader layer** (CodePet side) — a `ReflectionEventStore` `ObservableObject` that polls the events file every 1.5s, parses new lines, maps them to `CapturedEvent`, and exposes them via `@Published var events`. The Reflection tab reads from this store instead of mock data.

## Decision filter

The Reflection feature is about reflecting on **decisions**, not raw activity. Every event captured must represent either user intent or a state change.

| Hook | When to log | Why this is a decision |
|------|-------------|------------------------|
| `UserPromptSubmit` | Prompt length ≥ 10 chars | User expressing intent. Skip "yeah", "ok", "d", "go ahead" — those are confirmations, not decisions. |
| `PostToolUse` (`Edit` / `Write` / `NotebookEdit`) | Always | Code being modified — the canonical decision moment. |
| `PostToolUse` (`Bash`) | Command matches mutating allowlist (see below) | `git commit`, installs, builds, deploys are decisions. `ls`, `cat`, `git status` are exploration. |
| `PostToolUse` (others: `Read`, `Grep`, `Glob`, `LS`, `WebFetch`, etc.) | Skip entirely | Pure exploration / context-gathering. |
| `Stop` | Not used in MVP | Has no natural text content. |

**Bash allowlist regex:**
```
^(git commit|git push|git merge|git rebase|git tag|npm install|npm run|pip install|brew install|xcodebuild|swift build|swift test|fastlane|rm |mv |mkdir |make |docker |kubectl )
```

Expected event volume per 1-hour session: ~10–15 prompts + ~5–10 file modifications + ~2–5 mutating Bash = **~20–30 entries**, vs. 200+ if every tool call were logged.

## Hook layer

### Files

```
~/.codepet/
├── hooks/
│   ├── log-prompt.sh        # UserPromptSubmit handler
│   └── log-tool.sh          # PostToolUse handler
└── events.jsonl             # Append-only event log
```

The setup script that creates the above lives in the CodePet repo at
`scripts/install-reflection-hooks.sh` and is run manually by the user once.

### `~/.claude/settings.json` additions

```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "hooks": [{ "type": "command", "command": "~/.codepet/hooks/log-prompt.sh" }]
    }],
    "PostToolUse": [{
      "matcher": "*",
      "hooks": [{ "type": "command", "command": "~/.codepet/hooks/log-tool.sh" }]
    }]
  }
}
```

### `log-prompt.sh`

```bash
#!/bin/bash
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt')

# Skip short confirmations
if [ ${#PROMPT} -lt 10 ]; then exit 0; fi

SESSION=$(echo "$INPUT" | jq -r '.session_id')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -nc \
  --arg t "$TIME" --arg s "$SESSION" --arg c "$CWD" --arg p "$PROMPT" \
  '{time:$t, type:"prompt", session_id:$s, cwd:$c, text:$p}' \
  >> ~/.codepet/events.jsonl
```

### `log-tool.sh`

```bash
#!/bin/bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
SESSION=$(echo "$INPUT" | jq -r '.session_id')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

BASH_ALLOWLIST="^(git commit|git push|git merge|git rebase|git tag|npm install|npm run|pip install|brew install|xcodebuild|swift build|swift test|fastlane|rm |mv |mkdir |make |docker |kubectl )"

PATH_=""
case "$TOOL" in
  Edit|Write|NotebookEdit)
    PATH_=$(echo "$INPUT" | jq -r '.tool_input.file_path')
    TEXT="$TOOL $(basename "$PATH_")" ;;
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command')
    if ! echo "$CMD" | grep -qE "$BASH_ALLOWLIST"; then
      exit 0
    fi
    TEXT="Bash: $(echo "$CMD" | head -c 80)" ;;
  *)
    exit 0 ;;
esac

jq -nc \
  --arg t "$TIME" --arg s "$SESSION" --arg c "$CWD" --arg tn "$TOOL" \
  --arg p "$PATH_" --arg tx "$TEXT" \
  '{time:$t, type:"tool", session_id:$s, cwd:$c, tool_name:$tn, path:$p, text:$tx}' \
  >> ~/.codepet/events.jsonl
```

### `scripts/install-reflection-hooks.sh`

A one-time setup script shipped in the CodePet repo:

1. Create `~/.codepet/hooks/` directory.
2. Write `log-prompt.sh` and `log-tool.sh` with executable permission (`chmod +x`).
3. Touch `~/.codepet/events.jsonl` (empty file).
4. Print the snippet the user must paste into `~/.claude/settings.json` under the `hooks` key, with explicit instructions. Do **not** modify settings.json automatically — that file is sensitive and user-owned.

## Event format (JSONL)

Each line is a self-contained JSON object.

**Prompt event:**
```json
{
  "time": "2026-05-04T09:15:23Z",
  "type": "prompt",
  "session_id": "abc123",
  "cwd": "/Users/williamdominich/Documents/Murror/CodePet-Clean",
  "text": "bây giờ tôi muốn tích hợp mcp vào claude code để log..."
}
```

**Tool event (file mutation):**
```json
{
  "time": "2026-05-04T09:15:45Z",
  "type": "tool",
  "session_id": "abc123",
  "cwd": "/Users/williamdominich/Documents/Murror/CodePet-Clean",
  "tool_name": "Edit",
  "path": "/Users/williamdominich/Documents/Murror/CodePet-Clean/codepet/Views/Reflection/ReflectionTab.swift",
  "text": "Edit ReflectionTab.swift"
}
```

**Tool event (Bash mutating):**
```json
{
  "time": "2026-05-04T09:16:02Z",
  "type": "tool",
  "session_id": "abc123",
  "cwd": "/Users/williamdominich/Documents/Murror/CodePet-Clean",
  "tool_name": "Bash",
  "text": "Bash: git commit -m 'Add reflection event reader'"
}
```

| Field | Type | Purpose |
|-------|------|---------|
| `time` | ISO 8601 UTC string | App converts to `HH:MM` local for `CapturedEvent.time` |
| `type` | `"prompt"` \| `"tool"` | Branches display logic |
| `session_id` | string | Group events by session |
| `cwd` | string | Project context for future per-project filtering |
| `text` | string | Pre-formatted display string — maps directly to `CapturedEvent.text` |
| `tool_name` | string (tool only) | For per-tool icon/filter |
| `path` | string (file-mutation tools only) | Full file path for future deeplink |

## Reader layer (CodePet)

### New file: `codepet/Managers/ReflectionEventStore.swift`

```swift
@MainActor
final class ReflectionEventStore: ObservableObject {
    @Published private(set) var events: [CapturedEvent] = []

    private let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codepet/events.jsonl")
    private let offsetKey = "cp_reflection_last_offset"
    private var pollTimer: Timer?

    func start() {
        ensureFileExists()
        readNewLines()    // prime with existing events
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.readNewLines() }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func readNewLines() {
        // 1. Open file, seek to lastReadOffset
        // 2. Read to EOF, split on "\n"
        // 3. Decode each line as JSONLEvent (skip malformed, log warning)
        // 4. Map JSONLEvent → CapturedEvent
        // 5. Append to events
        // 6. Persist new offset to UserDefaults
    }

    private func ensureFileExists() { /* create dir + empty file if missing */ }
}

private struct JSONLEvent: Codable {
    let time: String
    let type: String
    let session_id: String
    let cwd: String
    let text: String
    let tool_name: String?
    let path: String?
}
```

### Mapping `JSONLEvent` → `CapturedEvent`

```swift
CapturedEvent(
    time: formatHHmm(jsonl.time),  // e.g. "09:15"
    source: .claudeCode,
    text: jsonl.text,
    aiSummary: nil,                 // Claude Code: not used
    trigger: nil,                   // MVP: nil, enrich in v1.1
    context: nil,                   // MVP: nil, enrich in v1.1
    isManualLog: false
)
```

### App lifecycle integration

In `CodePetApp.swift`:

```swift
@StateObject private var reflectionStore = ReflectionEventStore()

var body: some Scene {
    WindowGroup {
        ContentView()
            .environmentObject(reflectionStore)
            .task { reflectionStore.start() }
    }
}
```

In `ReflectionTab.swift`, replace mock data:

```swift
@EnvironmentObject var reflectionStore: ReflectionEventStore
// use reflectionStore.events instead of the mock array
```

## Edge cases

| Case | Handling |
|------|----------|
| `events.jsonl` missing on app launch | `ensureFileExists()` creates parent dir and empty file. |
| Malformed JSON line | Log via `os.Logger`, skip the line, advance offset, continue. |
| File shrinks (size < lastReadOffset, e.g., user manually deleted) | Reset offset to 0, replay events. |
| File rotation | Out of scope for MVP — file grows unbounded. v1.1: rotate daily into `events-YYYY-MM-DD.jsonl`. |
| Hook fires while app is starting up | Hook is independent; events accumulate in file. App reads them on next poll. |
| Multi-project events | MVP shows all `cwd`s. v1.1: dropdown filter by project. |
| `jq` not installed on user machine | `install-reflection-hooks.sh` checks for `jq` and fails with clear error pointing to `brew install jq`. |
| User declines to paste hook config | App still runs; events array stays empty. Reflection tab shows empty-state copy "Connect Claude Code to start logging — see `scripts/install-reflection-hooks.sh`." |

## Testing strategy

- **Hook scripts**: shell unit tests using sample stdin JSON fixtures, asserting expected JSONL output (or empty exit for filtered events). Run via Bats or simple bash.
- **`ReflectionEventStore`**: Swift unit tests against a temp JSONL file. Cover: prime existing events, incremental read, malformed line, file shrink, file missing.
- **Integration**: manual end-to-end — install hooks, run a Claude Code session, verify events appear in Reflection tab.

## Out of scope (revisit in v1.1)

- AI enrichment pass: classify `trigger` (Scope creep, etc.), generate pet `context` narrative.
- Per-project filtering UI in Reflection tab.
- Daily file rotation for `events.jsonl`.
- DispatchSource-based file watching (replace polling).
- Sync events to Notion via existing Notion MCP for cross-device access.
- Stop hook for "session ended" markers.
