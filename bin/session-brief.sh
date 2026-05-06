#!/usr/bin/env bash
# Yukti: SessionStart hook — emit a project brief as `additionalContext`.
#
# Runs on Claude Code session start. Surfaces facts Claude Code doesn't
# already auto-load (CLAUDE.md and built-in auto memory cover convention
# and decision history; this fills in branch / git state / in-flight task /
# memory-mechanism status).
#
# Output: a single JSON object on stdout per the SessionStart hook contract:
#   { "hookSpecificOutput": { "hookEventName": "SessionStart",
#                             "additionalContext": "..." } }
#
# Silent on the happy path if there's nothing meaningful to surface (e.g.
# non-git directory with no state file). Never blocks the session.

set -euo pipefail

# Read the hook input but don't depend on its content (we use cwd / env).
INPUT="$(cat 2>/dev/null || true)"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# Skip output if disabled via project config.
CONFIG_FILE="$PROJECT_DIR/.claude/yukti-config.json"
if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
  ENABLED=$(jq -r '.briefEnabled // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
  if [ "$ENABLED" = "false" ]; then
    exit 0
  fi
fi

# Build the brief, line by line. Each subsection is silent if it has nothing
# meaningful to add — keeping the brief tight on small projects.
# DATA_LINES counts only the substantive bullets (lines starting with `**`),
# used to decide whether to emit anything at all.
BRIEF=""
DATA_LINES=0
add_line() {
  if [ -z "$BRIEF" ]; then
    BRIEF="$1"
  else
    BRIEF="$BRIEF
$1"
  fi
}
add_data_line() {
  add_line "$1"
  DATA_LINES=$((DATA_LINES + 1))
}

add_line "## Yukti — session brief"
add_line ""

# --- Git state -----------------------------------------------------------
IS_GIT_REPO="false"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IS_GIT_REPO="true"
fi

if [ "$IS_GIT_REPO" = "true" ]; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "(detached)")
  MOD_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  AHEAD_BEHIND=$(git status -sb 2>/dev/null | head -1 | sed 's/^## //')
  add_data_line "**Branch**: \`$BRANCH\`  ·  uncommitted changes: $MOD_COUNT"
  if [ -n "${AHEAD_BEHIND:-}" ]; then
    add_data_line "**Tracking**: $AHEAD_BEHIND"
  fi

  RECENT=$(git log --oneline -5 2>/dev/null || true)
  if [ -n "$RECENT" ]; then
    add_line ""
    add_data_line "**Recent commits**:"
    while IFS= read -r line; do
      add_line "  - $line"
    done <<< "$RECENT"
  fi
fi

# --- In-flight Yukti task ------------------------------------------------
STATE_FILE="$PROJECT_DIR/.claude/.yukti-state.json"
if [ -f "$STATE_FILE" ] && command -v jq >/dev/null 2>&1; then
  LAST_TASK=$(jq -r '.lastTask // empty' "$STATE_FILE" 2>/dev/null)
  CURRENT_PHASE=$(jq -r '.currentPhase // empty' "$STATE_FILE" 2>/dev/null)
  LAST_UPDATED=$(jq -r '.lastUpdated // empty' "$STATE_FILE" 2>/dev/null)
  if [ -n "$LAST_TASK" ] && [ "$CURRENT_PHASE" != "complete" ] && [ -n "$CURRENT_PHASE" ]; then
    add_line ""
    add_data_line "**In-flight Yukti task**: \`$CURRENT_PHASE\` — $LAST_TASK"
    if [ -n "$LAST_UPDATED" ]; then
      add_line "  (last updated: $LAST_UPDATED)"
    fi
    add_line "  Resume with \`/yukti:smart continue\` or clear with \`/yukti:status reset\`."
  fi
fi

# --- Memory mechanisms ---------------------------------------------------
MEMORY_NOTES=""
# CLAUDE.md is auto-loaded by Claude Code; mention if present.
if [ -f "$PROJECT_DIR/CLAUDE.md" ] || [ -f "$PROJECT_DIR/.claude/CLAUDE.md" ]; then
  MEMORY_NOTES="CLAUDE.md (auto-loaded)"
fi

# Built-in auto memory: in Claude Code 2.1.59+ defaults on at
# ~/.claude/projects/<derived>/memory/MEMORY.md. We don't know the exact
# derivation rule; just say "enabled by default" if no opt-out env var.
if [ "${CLAUDE_CODE_DISABLE_AUTO_MEMORY:-0}" != "1" ]; then
  if [ -n "$MEMORY_NOTES" ]; then
    MEMORY_NOTES="$MEMORY_NOTES  ·  auto memory (built-in)"
  else
    MEMORY_NOTES="auto memory (built-in)"
  fi
fi

# claude-mem detection (heuristic: presence of common claude-mem files).
if [ -d "$HOME/.claude-mem" ] || [ -f "$PROJECT_DIR/.claude/claude-mem-config.json" ]; then
  if [ -n "$MEMORY_NOTES" ]; then
    MEMORY_NOTES="$MEMORY_NOTES  ·  claude-mem (detected)"
  else
    MEMORY_NOTES="claude-mem (detected)"
  fi
fi

if [ -n "$MEMORY_NOTES" ]; then
  add_line ""
  add_line "**Memory**: $MEMORY_NOTES"
  # Memory line alone isn't enough to emit — only useful alongside other data.
fi

# --- Emit -----------------------------------------------------------------
# If we have nothing substantive to surface (no git, no state, no CLAUDE.md),
# stay silent. Memory mention alone isn't worth the context tokens.
if [ "$DATA_LINES" -lt 1 ]; then
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg context "$BRIEF" \
    '{ hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: $context } }'
else
  # Plain stdout still works as a SessionStart context contribution per the
  # documented contract — we just lose the structured wrapper.
  printf '%s\n' "$BRIEF"
fi
