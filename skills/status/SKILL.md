---
name: status
description: Show a Yukti session brief on demand — current branch, uncommitted changes, recent commits, in-flight Yukti task (if any), and which memory mechanisms are active. Same content the SessionStart hook injects automatically; this skill lets you re-fetch mid-session. Also accepts `reset` as an argument to clear the in-flight Yukti task state.
allowed-tools: Bash, Read
---

# /yukti:status

User invoked `/yukti:status` with these arguments (may be empty):

$ARGUMENTS

# What to do

If `$ARGUMENTS` contains the word `reset` (case-insensitive), **clear the in-flight Yukti task state**:

```bash
!`bash -c '
  PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  STATE_FILE="$PROJECT_DIR/.claude/.yukti-state.json"
  if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE" && echo "Yukti: in-flight task state cleared ($STATE_FILE)"
  else
    echo "Yukti: no in-flight task state to clear (no $STATE_FILE)"
  fi
'`
```

Otherwise, **show the brief** by running the same logic the SessionStart hook uses, inline (so the skill works regardless of whether the install is marketplace-style or fallback-style):

```bash
!`bash -c '
set -u
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

echo "## Yukti — session brief"
echo ""

# Git state
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "(detached)")
  MOD_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d " ")
  AHEAD_BEHIND=$(git status -sb 2>/dev/null | head -1 | sed "s/^## //")
  echo "**Branch**: \`$BRANCH\`  ·  uncommitted changes: $MOD_COUNT"
  if [ -n "$AHEAD_BEHIND" ]; then
    echo "**Tracking**: $AHEAD_BEHIND"
  fi
  RECENT=$(git log --oneline -5 2>/dev/null || true)
  if [ -n "$RECENT" ]; then
    echo ""
    echo "**Recent commits**:"
    echo "$RECENT" | sed "s/^/  - /"
  fi
fi

# In-flight Yukti task
STATE_FILE="$PROJECT_DIR/.claude/.yukti-state.json"
if [ -f "$STATE_FILE" ] && command -v jq >/dev/null 2>&1; then
  LAST_TASK=$(jq -r ".lastTask // empty" "$STATE_FILE" 2>/dev/null)
  CURRENT_PHASE=$(jq -r ".currentPhase // empty" "$STATE_FILE" 2>/dev/null)
  LAST_UPDATED=$(jq -r ".lastUpdated // empty" "$STATE_FILE" 2>/dev/null)
  if [ -n "$LAST_TASK" ] && [ "$CURRENT_PHASE" != "complete" ] && [ -n "$CURRENT_PHASE" ]; then
    echo ""
    echo "**In-flight Yukti task**: \`$CURRENT_PHASE\` — $LAST_TASK"
    if [ -n "$LAST_UPDATED" ]; then
      echo "  (last updated: $LAST_UPDATED)"
    fi
  fi
fi

# Memory mechanisms
NOTES=""
if [ -f "$PROJECT_DIR/CLAUDE.md" ] || [ -f "$PROJECT_DIR/.claude/CLAUDE.md" ]; then
  NOTES="CLAUDE.md (auto-loaded)"
fi
if [ "${CLAUDE_CODE_DISABLE_AUTO_MEMORY:-0}" != "1" ]; then
  NOTES="${NOTES:+$NOTES  ·  }auto memory (built-in)"
fi
if [ -d "$HOME/.claude-mem" ] || [ -f "$PROJECT_DIR/.claude/claude-mem-config.json" ]; then
  NOTES="${NOTES:+$NOTES  ·  }claude-mem (detected)"
fi
if [ -n "$NOTES" ]; then
  echo ""
  echo "**Memory**: $NOTES"
fi
'`
```

Display the output of whichever branch ran — do not add commentary. The user wants the read-out, not your interpretation.
