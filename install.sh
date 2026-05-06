#!/usr/bin/env bash
# Yukti: fallback installer
#
# Copies the plugin's agents, skills, and hooks into the current project's
# .claude/ directory. Use this when you can't install via the plugin marketplace
# (e.g. private repos, older Claude Code versions, CI environments).
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/akii09/yukti/main/install.sh | bash
#
# Or from a local clone:
#   ./install.sh

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/akii09/yukti/main"
REPO_GIT="https://github.com/akii09/yukti.git"

PROJECT_DIR="${1:-$(pwd)}"
TARGET="$PROJECT_DIR/.claude"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "error: $PROJECT_DIR is not a directory" >&2
  exit 1
fi

echo "==> Installing Yukti into $TARGET"

mkdir -p "$TARGET/agents" "$TARGET/skills" "$TARGET/hooks" "$TARGET/bin"

# Determine source: if running from a clone, copy locally; else fetch from GitHub
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd 2>/dev/null || true)"
if [ -n "${SCRIPT_DIR:-}" ] && [ -d "$SCRIPT_DIR/agents" ]; then
  echo "==> Copying from local clone: $SCRIPT_DIR"
  cp -R "$SCRIPT_DIR/agents/." "$TARGET/agents/"
  cp -R "$SCRIPT_DIR/skills/." "$TARGET/skills/"
  cp -R "$SCRIPT_DIR/hooks/." "$TARGET/hooks/"
  cp -R "$SCRIPT_DIR/bin/." "$TARGET/bin/"
else
  echo "==> Fetching from $REPO_GIT (shallow clone)"
  TMP=$(mktemp -d -t yukti.XXXXXX)
  trap 'rm -rf "$TMP"' EXIT
  git clone --depth=1 "$REPO_GIT" "$TMP" >/dev/null 2>&1
  cp -R "$TMP/agents/." "$TARGET/agents/"
  cp -R "$TMP/skills/." "$TARGET/skills/"
  cp -R "$TMP/hooks/." "$TARGET/hooks/"
  cp -R "$TMP/bin/." "$TARGET/bin/"
fi

chmod +x "$TARGET/bin/"*.sh

# Patch hooks.json for the fallback layout: ${CLAUDE_PLUGIN_ROOT} doesn't exist
# in non-plugin installs, so we rewrite paths to use $CLAUDE_PROJECT_DIR.
if [ -f "$TARGET/hooks/hooks.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    TMPF=$(mktemp)
    jq '
      walk(
        if type == "string" then
          gsub("\\$\\{CLAUDE_PLUGIN_ROOT\\}"; "$CLAUDE_PROJECT_DIR/.claude")
        else .
        end
      )
    ' "$TARGET/hooks/hooks.json" > "$TMPF"
    mv "$TMPF" "$TARGET/hooks/hooks.json"
  else
    # Fallback to sed if jq is unavailable
    sed -i.bak 's|\${CLAUDE_PLUGIN_ROOT}|$CLAUDE_PROJECT_DIR/.claude|g' "$TARGET/hooks/hooks.json"
    rm -f "$TARGET/hooks/hooks.json.bak"
  fi
fi

# Merge hooks into project settings.json (don't overwrite existing hooks)
SETTINGS_FILE="$TARGET/settings.json"
HOOKS_JSON="$TARGET/hooks/hooks.json"

if command -v jq >/dev/null 2>&1; then
  if [ -f "$SETTINGS_FILE" ]; then
    echo "==> Merging hooks into existing $SETTINGS_FILE"
    TMPF=$(mktemp)
    jq -s '.[0] as $existing | .[1] as $new | $existing * {hooks: (($existing.hooks // {}) + $new)}' \
      "$SETTINGS_FILE" "$HOOKS_JSON" > "$TMPF"
    mv "$TMPF" "$SETTINGS_FILE"
  else
    echo "==> Creating $SETTINGS_FILE with hooks"
    jq -n --slurpfile hooks "$HOOKS_JSON" '{hooks: $hooks[0]}' > "$SETTINGS_FILE"
  fi
else
  echo "warning: jq not found; please manually copy $HOOKS_JSON into $SETTINGS_FILE under the 'hooks' key" >&2
fi

# Create default yukti-config.json if missing
CONFIG_FILE="$TARGET/yukti-config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  cat > "$CONFIG_FILE" <<'JSON'
{
  "capReadLines": 500,
  "stopHookEnabled": true,
  "verifyCommand": null,
  "briefEnabled": true
}
JSON
  echo "==> Created default config at $CONFIG_FILE"
fi

cat <<EOF

==> Yukti installed successfully

Files placed:
  $TARGET/agents/         (5 specialist subagents)
  $TARGET/skills/         (6 skills: smart, explore, plan, implement, review, status)
  $TARGET/hooks/          (PreToolUse, SessionStart, Stop hook configs)
  $TARGET/bin/            (cap-read, session-brief, stop-verify scripts)
  $TARGET/yukti-config.json  (per-project config — edit as needed)

Skills are namespaced. Note: in the fallback (non-plugin) install, skills are
project-local and invoked WITHOUT the plugin namespace prefix:
  /smart <task>           (full pipeline)
  /explore <task>         (find files only — Haiku)
  /plan <task>            (produce plan — Opus)
  /implement <phase>      (apply one phase — Sonnet)
  /review                 (review diff — Opus)
  /status [reset]         (project state brief; 'reset' clears in-flight task)

If you used the marketplace install instead, prefix skills with the plugin
namespace, e.g. /yukti:smart.

A session brief auto-injects on Claude Code start (branch, git status,
in-flight task). Disable via "briefEnabled": false in $TARGET/yukti-config.json.

To remove: delete $TARGET/agents, $TARGET/skills, $TARGET/hooks, $TARGET/bin,
and remove the hook entries from $SETTINGS_FILE.

EOF
