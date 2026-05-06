#!/usr/bin/env bash
# Yukti: PreToolUse hook on Read
#
# Caps Read calls that have no `limit` parameter to prevent accidental
# full-file reads of giant files. User-specified limits pass through unchanged.
#
# Reads stdin JSON, emits JSON with `updatedInput` containing the modified
# tool_input. The cap value is configurable via .claude/yukti-config.json.

set -euo pipefail

# Default cap; overridden by config if present
DEFAULT_CAP=500

# Read stdin payload
INPUT="$(cat)"

# Bail out fast if jq isn't available — don't break the user's session
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Confirm this is a Read tool call (defensive — matcher should already enforce)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
if [ "$TOOL_NAME" != "Read" ]; then
  exit 0
fi

# If a limit is already set, leave the call untouched
EXISTING_LIMIT=$(printf '%s' "$INPUT" | jq -r '.tool_input.limit // empty')
if [ -n "$EXISTING_LIMIT" ]; then
  exit 0
fi

# Resolve cap from project config if present
CAP="$DEFAULT_CAP"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG_FILE="$PROJECT_DIR/.claude/yukti-config.json"
if [ -f "$CONFIG_FILE" ]; then
  CONFIG_CAP=$(jq -r '.capReadLines // empty' "$CONFIG_FILE" 2>/dev/null || true)
  if [ -n "$CONFIG_CAP" ] && [ "$CONFIG_CAP" -gt 0 ] 2>/dev/null; then
    CAP="$CONFIG_CAP"
  fi
fi

# If user has disabled the cap (capReadLines: 0 or negative), skip
if [ "$CAP" -le 0 ] 2>/dev/null; then
  exit 0
fi

# Build the updated tool_input by adding limit:CAP
UPDATED_INPUT=$(printf '%s' "$INPUT" | jq --argjson cap "$CAP" '.tool_input + {limit: $cap}')

# Emit the hook output JSON
jq -n \
  --argjson updated "$UPDATED_INPUT" \
  --argjson cap "$CAP" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      updatedInput: $updated
    },
    systemMessage: ("Yukti: capped Read to " + ($cap | tostring) + " lines (no limit specified). Override by passing limit explicitly.")
  }'
