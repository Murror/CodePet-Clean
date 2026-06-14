#!/bin/bash
# Patches the live hook scripts on your machine with the optimized versions.
# Run once: bash ~/Downloads/CodePet-Clean/patch-hooks.sh

set -e

# === log-prompt.sh — NEVER filter by length ===
cat > ~/.codepet/hooks/log-prompt.sh << 'HOOK'
#!/bin/bash
# CRITICAL: Never filter prompts by length. Short prompts like "continue",
# "go ahead", "yes", "ok" are valid turn boundaries. Dropping them causes
# all subsequent tool events to be orphaned.
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
if [ -z "$PROMPT" ]; then exit 0; fi

SESSION=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if command -v jq >/dev/null 2>&1; then
    jq -nc --arg t "$TIME" --arg s "$SESSION" --arg c "$CWD" --arg p "$PROMPT" \
        '{time:$t, type:"prompt", session_id:$s, cwd:$c, text:$p}' >> "$HOME/.codepet/events.jsonl"
else
    echo "{\"time\":\"$TIME\",\"type\":\"prompt\",\"session_id\":\"$SESSION\",\"cwd\":\"$CWD\",\"text\":\"$(echo "$PROMPT" | sed 's/"/\\"/g')\"}" >> "$HOME/.codepet/events.jsonl"
fi
HOOK

# === log-tool.sh — denylist instead of allowlist ===
cat > ~/.codepet/hooks/log-tool.sh << 'HOOK'
#!/bin/bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
SESSION=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Bash commands to SKIP — high-frequency read-only noise.
# Everything else is captured. The app-side isReadOnlyBash does
# fine-grained filtering; the hook just needs to avoid flooding.
BASH_DENYLIST="^(cat |head |tail |less |more |wc |file |stat |pwd|echo |printf |which |whoami|type |man |help |true|false|:|test )"

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
        FIRST_CMD=$(echo "$CMD" | head -c 120)
        # Skip only known-noisy read-only commands
        if echo "$FIRST_CMD" | grep -qE "$BASH_DENYLIST"; then exit 0; fi
        TEXT="Bash: $(echo "$FIRST_CMD" | head -c 80)"
        ;;
    Read|Glob|Grep)
        # Read-only tools — capture lightly for context
        PATH_=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.pattern // empty' 2>/dev/null)
        TEXT="$TOOL $(echo "$PATH_" | head -c 60)"
        ;;
    *)
        # Unknown/future tools — capture with tool name
        TEXT="$TOOL"
        ;;
esac

if [ -z "$TEXT" ]; then exit 0; fi

if command -v jq >/dev/null 2>&1; then
    jq -nc --arg t "$TIME" --arg s "$SESSION" --arg c "$CWD" --arg tn "$TOOL" --arg p "$PATH_" --arg tx "$TEXT" \
        '{time:$t, type:"tool", session_id:$s, cwd:$c, tool_name:$tn, path:$p, text:$tx}' >> "$HOME/.codepet/events.jsonl"
else
    echo "{\"time\":\"$TIME\",\"type\":\"tool\",\"session_id\":\"$SESSION\",\"text\":\"$(echo "$TEXT" | sed 's/"/\\"/g')\"}" >> "$HOME/.codepet/events.jsonl"
fi
HOOK

chmod +x ~/.codepet/hooks/log-prompt.sh ~/.codepet/hooks/log-tool.sh
echo "✅ Hooks patched! Changes take effect on the next Claude Code prompt."
