import Foundation
import Combine
import AppKit

/// One-click installer for Claude Code reflection hooks.
/// Creates ~/.codepet/hooks/ scripts and merges config into ~/.claude/settings.json.
///
/// Because the app runs in a macOS sandbox container, it cannot write to the
/// real home directory. Instead, the install button copies a self-contained
/// bash command to the clipboard. The user pastes it in Terminal and presses Enter.
final class HookInstaller: ObservableObject {

    enum Status: Equatable {
        case notInstalled
        case installing   // "command copied" state
        case installed
        case failed(String)
    }

    @Published var status: Status = .notInstalled

    // MARK: - Public

    /// Check if hooks are already installed by looking for a marker
    /// the install script writes into the app container.
    func checkInstallation() {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let markerPath = Self.containerMarkerPath
            let isInstalled = FileManager.default.fileExists(atPath: markerPath)
            DispatchQueue.main.async {
                self.status = isInstalled ? .installed : .notInstalled
            }
        }
    }

    /// Copy the install command to clipboard.
    func install() {
        let command = Self.buildInstallCommand()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
        status = .installing  // Shows "copied" UI state
    }

    /// User confirms they ran the command — verify and update status.
    func verifyInstallation() {
        // Write marker so future launches remember
        let markerPath = Self.containerMarkerPath
        let dir = (markerPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: markerPath, contents: nil)
        status = .installed
    }

    /// Reset to allow re-install
    func resetStatus() {
        status = .notInstalled
    }

    // MARK: - Marker file (in the container, so we can read/write it)

    private static var containerMarkerPath: String {
        return "\(RealHome.url.path)/.codepet/hooks-installed-marker"
    }

    // MARK: - Build the clipboard command

    /// Build a single bash command that installs everything.
    private static func buildInstallCommand() -> String {
        let promptB64 = logPromptScript.data(using: .utf8)!.base64EncodedString()
        let toolB64 = logToolScript.data(using: .utf8)!.base64EncodedString()
        let summaryB64 = logSummaryScript.data(using: .utf8)!.base64EncodedString()
        let sessionEndB64 = logSessionEndScript.data(using: .utf8)!.base64EncodedString()

        // Build the hooks JSON blob as base64 to avoid all quoting issues
        let hooksJSON = """
        {
          "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "~/.codepet/hooks/log-prompt.sh"}]}],
          "PostToolUse": [{"matcher": "*", "hooks": [{"type": "command", "command": "~/.codepet/hooks/log-tool.sh"}]}],
          "Stop": [{"hooks": [{"type": "command", "command": "~/.codepet/hooks/log-summary.sh"}]}],
          "SessionEnd": [{"hooks": [{"type": "command", "command": "~/.codepet/hooks/log-session-end.sh"}]}]
        }
        """
        let hooksB64 = hooksJSON.data(using: .utf8)!.base64EncodedString()

        // The merge script is also base64-encoded to avoid quoting hell.
        // Swift interpolation embeds hooksB64 as a literal string before encoding.
        let mergeScript = """
        #!/bin/bash
        SETTINGS="$HOME/.claude/settings.json"
        mkdir -p "$HOME/.claude"
        if [ ! -f "$SETTINGS" ]; then echo '{}' > "$SETTINGS"; fi
        if grep -q "codepet/hooks" "$SETTINGS" 2>/dev/null; then
          echo "✓ Hooks already in settings"
          exit 0
        fi
        HOOKS_JSON=$(echo "\(hooksB64)" | base64 -d)
        if command -v python3 >/dev/null 2>&1; then
          python3 -c "
        import json, sys
        with open(sys.argv[1]) as f: s = json.load(f)
        h = json.loads(sys.argv[2])
        hooks = s.setdefault('hooks', {})
        for k, v in h.items():
        if k not in hooks:
        hooks[k] = v
        with open(sys.argv[1], 'w') as f: json.dump(s, f, indent=2)
        " "$SETTINGS" "$HOOKS_JSON"
        elif command -v jq >/dev/null 2>&1; then
          jq --argjson nh "$HOOKS_JSON" '.hooks = ($nh + (.hooks // {}))' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
        else
          echo "⚠ Neither python3 nor jq found. Please install one and retry."
          exit 1
        fi
        echo "✓ Hooks added to settings"
        """
        let mergeB64 = mergeScript.data(using: .utf8)!.base64EncodedString()

        return """
        bash -c '
        set -e
        mkdir -p ~/.codepet/hooks
        touch ~/.codepet/events.jsonl
        touch ~/.codepet/session_ends.jsonl
        mkdir -p ~/Library/Containers/app.murror.codepet/Data/.codepet
        echo "\(promptB64)" | base64 -d > ~/.codepet/hooks/log-prompt.sh
        echo "\(toolB64)" | base64 -d > ~/.codepet/hooks/log-tool.sh
        echo "\(summaryB64)" | base64 -d > ~/.codepet/hooks/log-summary.sh
        echo "\(sessionEndB64)" | base64 -d > ~/.codepet/hooks/log-session-end.sh
        chmod +x ~/.codepet/hooks/*.sh
        # Symlink from container path → real home so the app finds the files
        # regardless of which home directory macOS returns
        ln -sf ~/.codepet/events.jsonl ~/Library/Containers/app.murror.codepet/Data/.codepet/events.jsonl 2>/dev/null || true
        ln -sf ~/.codepet/session_ends.jsonl ~/Library/Containers/app.murror.codepet/Data/.codepet/session_ends.jsonl 2>/dev/null || true
        echo "\(mergeB64)" | base64 -d | bash
        echo ""
        echo "✅ CodePet hooks installed! Restart Claude Code to start capturing."
        '
        """
    }

    // MARK: - Embedded hook scripts

    private static let logPromptScript = """
    #!/bin/bash
    INPUT=$(cat)
    PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
    if [ -z "$PROMPT" ] || [ ${#PROMPT} -lt 10 ]; then exit 0; fi

    SESSION=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
    TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if command -v jq >/dev/null 2>&1; then
        jq -nc --arg t "$TIME" --arg s "$SESSION" --arg c "$CWD" --arg p "$PROMPT" \
            '{time:$t, type:"prompt", session_id:$s, cwd:$c, text:$p}' >> "$HOME/.codepet/events.jsonl"
    else
        echo "{\\"time\\":\\"$TIME\\",\\"type\\":\\"prompt\\",\\"session_id\\":\\"$SESSION\\",\\"cwd\\":\\"$CWD\\",\\"text\\":\\"$(echo "$PROMPT" | sed 's/"/\\\\"/g')\\"}" >> "$HOME/.codepet/events.jsonl"
    fi
    """

    private static let logToolScript = """
    #!/bin/bash
    INPUT=$(cat)
    TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
    SESSION=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
    TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    BASH_ALLOWLIST="^(git commit|git push|git merge|git rebase|git tag|npm install|npm run|pip install|brew install|xcodebuild|swift build|swift test|fastlane|rm |mv |mkdir |make |docker |kubectl )"

    PATH_=""
    TEXT=""
    case "$TOOL" in
        Edit|Write|NotebookEdit)
            PATH_=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
            if [ -z "$PATH_" ]; then exit 0; fi
            TEXT="$TOOL $(basename "$PATH_")"
            ;;
        Bash)
            CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
            if [ -z "$CMD" ]; then exit 0; fi
            if ! echo "$CMD" | grep -qE "$BASH_ALLOWLIST"; then exit 0; fi
            TEXT="Bash: $(echo "$CMD" | head -c 80)"
            ;;
        *)
            exit 0
            ;;
    esac

    if command -v jq >/dev/null 2>&1; then
        jq -nc --arg t "$TIME" --arg s "$SESSION" --arg c "$CWD" --arg tn "$TOOL" --arg p "$PATH_" --arg tx "$TEXT" \
            '{time:$t, type:"tool", session_id:$s, cwd:$c, tool_name:$tn, path:$p, text:$tx}' >> "$HOME/.codepet/events.jsonl"
    else
        echo "{\\"time\\":\\"$TIME\\",\\"type\\":\\"tool\\",\\"session_id\\":\\"$SESSION\\",\\"text\\":\\"$(echo "$TEXT" | sed 's/"/\\\\"/g')\\"}" >> "$HOME/.codepet/events.jsonl"
    fi
    """

    private static let logSummaryScript = """
    #!/bin/bash
    INPUT=$(cat)
    SESSION=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    if [ -z "$SESSION" ]; then exit 0; fi

    if command -v jq >/dev/null 2>&1; then
        jq -nc --arg t "$TIME" --arg s "$SESSION" \
            '{time:$t, type:"summary", session_id:$s, text:""}' >> "$HOME/.codepet/events.jsonl"
    else
        echo "{\\"time\\":\\"$TIME\\",\\"type\\":\\"summary\\",\\"session_id\\":\\"$SESSION\\",\\"text\\":\\"\\"}" >> "$HOME/.codepet/events.jsonl"
    fi
    """

    private static let logSessionEndScript = """
    #!/bin/bash
    SESSION_ENDS="$HOME/.codepet/session_ends.jsonl"
    mkdir -p "$HOME/.codepet"

    INPUT=$(cat)
    SESSION=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    if [ -z "$SESSION" ]; then exit 0; fi

    if command -v jq >/dev/null 2>&1; then
        jq -nc --arg s "$SESSION" --arg t "$TIME" \
            '{session_id:$s, time:$t}' >> "$SESSION_ENDS"
    else
        echo "{\\"session_id\\":\\"$SESSION\\",\\"time\\":\\"$TIME\\"}" >> "$SESSION_ENDS"
    fi
    """
}
