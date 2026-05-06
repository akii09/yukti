#!/usr/bin/env bash
# Yukti: Stop hook
#
# Best-effort verification when the agent stops. Detects the project's package
# manager and runs typecheck. If it fails, surfaces the error as additionalContext
# so the agent can decide how to proceed. Does NOT hard-block the stop — the
# Stop hook block semantics are not fully documented and we don't want to trap
# users in loops.
#
# Disable by setting `stopHookEnabled: false` in .claude/yukti-config.json.

set -euo pipefail

INPUT="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG_FILE="$PROJECT_DIR/.claude/yukti-config.json"

# Check if disabled
if [ -f "$CONFIG_FILE" ]; then
  ENABLED=$(jq -r '.stopHookEnabled // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
  if [ "$ENABLED" = "false" ]; then
    exit 0
  fi
fi

# Resolve verification command: explicit override > auto-detected
VERIFY_CMD=""
if [ -f "$CONFIG_FILE" ]; then
  OVERRIDE=$(jq -r '.verifyCommand // empty' "$CONFIG_FILE" 2>/dev/null || true)
  if [ -n "$OVERRIDE" ] && [ "$OVERRIDE" != "null" ]; then
    VERIFY_CMD="$OVERRIDE"
  fi
fi

if [ -z "$VERIFY_CMD" ]; then
  cd "$PROJECT_DIR"
  # JS/TS — looks for a `typecheck` script in package.json
  if [ -f "pnpm-lock.yaml" ] && [ -f "package.json" ]; then
    if jq -e '.scripts.typecheck' package.json >/dev/null 2>&1; then
      VERIFY_CMD="pnpm typecheck"
    fi
  elif [ -f "package-lock.json" ] && [ -f "package.json" ]; then
    if jq -e '.scripts.typecheck' package.json >/dev/null 2>&1; then
      VERIFY_CMD="npm run typecheck"
    fi
  elif [ -f "yarn.lock" ] && [ -f "package.json" ]; then
    if jq -e '.scripts.typecheck' package.json >/dev/null 2>&1; then
      VERIFY_CMD="yarn typecheck"
    fi
  # Go — `go vet` is fast (no codegen) and catches common issues
  elif [ -f "go.mod" ] && command -v go >/dev/null 2>&1; then
    VERIFY_CMD="go vet ./..."
  # Rust — `cargo check` is faster than build/test, catches type errors
  elif [ -f "Cargo.toml" ] && command -v cargo >/dev/null 2>&1; then
    VERIFY_CMD="cargo check --quiet"
  # Python — only run a typecheck if the project has a typecheck config
  # (no universal Python typecheck command; we won't guess)
  elif command -v mypy >/dev/null 2>&1 && {
         [ -f "mypy.ini" ] \
      || [ -f ".mypy.ini" ] \
      || { [ -f "pyproject.toml" ] && grep -q '^\[tool\.mypy\]' pyproject.toml 2>/dev/null; }
       }; then
    VERIFY_CMD="mypy ."
  elif [ -f "pyrightconfig.json" ] && command -v pyright >/dev/null 2>&1; then
    VERIFY_CMD="pyright"
  fi
fi

# Nothing to run — exit silently
if [ -z "$VERIFY_CMD" ]; then
  exit 0
fi

# Run verification with a hard timeout
cd "$PROJECT_DIR"
OUTPUT_FILE=$(mktemp -t yukti-verify.XXXXXX)
trap 'rm -f "$OUTPUT_FILE"' EXIT

if timeout 45 sh -c "$VERIFY_CMD" >"$OUTPUT_FILE" 2>&1; then
  exit 0
fi

# Verification failed: report as additionalContext (advisory, non-blocking)
# Truncate output to last 60 lines to avoid blowing context
TAIL_OUTPUT=$(tail -n 60 "$OUTPUT_FILE")

jq -n \
  --arg cmd "$VERIFY_CMD" \
  --arg out "$TAIL_OUTPUT" \
  '{
    hookSpecificOutput: {
      hookEventName: "Stop",
      additionalContext: ("Yukti verification check (advisory): `" + $cmd + "` failed before stop.\n\nLast 60 lines of output:\n```\n" + $out + "\n```\n\nThis is an advisory check — review the failure before considering the task complete.")
    }
  }'
