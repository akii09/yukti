#!/usr/bin/env bash
# Yukti: UserPromptSubmit hook — classify the user's prompt and (if config
# says so) emit an advisory suggesting `/yukti:smart` for code-change tasks.
#
# Default config is "off" — the hook is a no-op unless the user opts in.
# Modes (in `routingHints` config field):
#   "off"      — silent, no advisory ever (default)
#   "advisory" — emit a non-blocking suggestion when the prompt looks like
#                a code-change task. User and main agent are free to ignore.
#   "auto"     — emit a stronger instruction asking the main agent to invoke
#                the smart-orchestrator. Best-effort; depends on the main
#                agent following the hint. NOT a hard auto-route — Claude
#                Code's hook contract doesn't expose that.
#
# Privacy: the hook reads the prompt from stdin to classify it, but writes
# NOTHING about the prompt anywhere. No logs, no scratch files. The only
# effect of the hook is the advisory text emitted this turn — which goes
# back into the conversation, not to any persistent storage.
#
# Coexistence: per Claude Code docs, "all matching hooks run in parallel."
# This hook does not depend on running before or after any other plugin's
# UserPromptSubmit hook. Both contributions reach the main agent.

set -euo pipefail

INPUT="$(cat 2>/dev/null || true)"

if ! command -v jq >/dev/null 2>&1; then
  exit 0  # silent no-op without jq
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_CONFIG="$PROJECT_DIR/.claude/yukti-config.json"
GLOBAL_CONFIG="$HOME/.claude/yukti-global-config.json"

# Resolve mode: project config overrides global; default off.
MODE="off"
if [ -f "$GLOBAL_CONFIG" ]; then
  MODE=$(jq -r '.routingHints // "off"' "$GLOBAL_CONFIG" 2>/dev/null || echo "off")
fi
if [ -f "$PROJECT_CONFIG" ]; then
  P=$(jq -r '.routingHints // empty' "$PROJECT_CONFIG" 2>/dev/null || true)
  if [ -n "$P" ] && [ "$P" != "null" ]; then
    MODE="$P"
  fi
fi

if [ "$MODE" = "off" ]; then
  exit 0
fi

# Validate mode (defensive — unknown values fall back to off rather than
# letting a typo silently activate auto).
case "$MODE" in
  advisory|auto) ;;
  *) exit 0 ;;
esac

PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
if [ -z "$PROMPT" ]; then
  exit 0
fi

# Skip if the user already invoked a Yukti skill — they don't need a hint.
LEAD=$(printf '%s' "$PROMPT" | head -c 30)
case "$LEAD" in
  /yukti:*|"/smart "*|"/plan "*|"/explore "*|"/implement "*|"/review"*|"/status"*) exit 0 ;;
esac

# Length filter — very short prompts are probably conversational acks.
PROMPT_LEN=$(printf '%s' "$PROMPT" | wc -c | tr -d ' ')
if [ "$PROMPT_LEN" -lt 12 ]; then
  exit 0
fi

# Crude classifier — imperative code-change verbs at the start of the prompt.
# Intentionally conservative; misses some valid code-changes (false negatives
# are fine — user just doesn't get a hint), but avoids tripping on questions
# and analysis (false positives cost trust).
FIRST_LC=$(printf '%s' "$PROMPT" | head -c 80 | tr '[:upper:]' '[:lower:]')
IS_CODE_CHANGE="false"
case "$FIRST_LC" in
  "add "*|"fix "*|"refactor "*|"implement "*|"create "*|"remove "*|"rename "*|"update "*|"change "*|"delete "*|"port "*|"migrate "*|"write "*|"build "*|"replace "*)
    IS_CODE_CHANGE="true" ;;
esac

if [ "$IS_CODE_CHANGE" != "true" ]; then
  exit 0
fi

# Question filter — code-change-shaped sentence ending in '?' is usually a question.
case "$PROMPT" in
  *\?) exit 0 ;;
esac

# Compose advisory or auto hint
if [ "$MODE" = "auto" ]; then
  HINT="**Yukti auto-route hint**: this prompt looks like a code-change task. Please process it through the Yukti pipeline now: invoke the \`smart-orchestrator\` agent via the Agent tool with the original prompt below. The pipeline (explore → plan → user-confirm → implement → review) routes each stage to the cheapest model that does the step well. (To turn off this auto behavior, set \`routingHints: \"advisory\"\` or \`\"off\"\` in your yukti-config.json. Note: this is best-effort — Claude Code hooks cannot directly invoke an agent, so it depends on you, the main agent, following this instruction.)"
else
  HINT="**Yukti hint**: this looks like a code-change task. Consider re-invoking with \`/yukti:smart\` (or \`/smart\` on fallback installs) to route through explore → plan → confirm → implement → review and save ~50% cost vs always-Opus. (Turn this hint off with \`routingHints: \"off\"\` in your yukti-config.json.)"
fi

jq -n --arg context "$HINT" '{
  hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: $context }
}'
