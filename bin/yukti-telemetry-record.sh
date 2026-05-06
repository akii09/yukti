#!/usr/bin/env bash
# Yukti: telemetry recorder.
#
# Called by the smart-orchestrator after a pipeline finishes. Reads the
# per-task scratch file (one JSON line per stage, written incrementally
# during the pipeline), aggregates costs, and appends a single record
# to ~/.claude/yukti-telemetry.jsonl.
#
# Opt-in only. If the user's project config sets telemetry != "local",
# this script exits silently — nothing is logged.
#
# PRIVACY INVARIANTS (the orchestrator MUST honor these when populating
# the scratch file; this script also enforces them as a defense in depth):
#   - Task descriptions truncated to 80 chars
#   - Per-stage entries hold ONLY: stage, model, size_bucket
#     (no source content, no file lists, no diffs)
#
# Pricing constants are illustrative May 2026 levels — update from
# anthropic.com/pricing as the project matures.
#
# Usage:
#   yukti-telemetry-record.sh \
#     --task "<short description>" \
#     --task-class "<code-change|plan-only|review-only|file-locate-only>" \
#     --scratch <path/to/scratch.jsonl>

set -euo pipefail

# --- Args ---------------------------------------------------------------
TASK=""
TASK_CLASS=""
SCRATCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --task) TASK="$2"; shift 2;;
    --task-class) TASK_CLASS="$2"; shift 2;;
    --scratch) SCRATCH="$2"; shift 2;;
    *) shift;;
  esac
done

if [ -z "$SCRATCH" ] || [ ! -f "$SCRATCH" ]; then
  exit 0  # nothing to record
fi
if ! command -v jq >/dev/null 2>&1; then
  exit 0  # jq required; silent no-op when absent
fi

# --- Telemetry mode check ------------------------------------------------
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_CONFIG="$PROJECT_DIR/.claude/yukti-config.json"
GLOBAL_CONFIG="$HOME/.claude/yukti-global-config.json"

MODE="off"
if [ -f "$GLOBAL_CONFIG" ]; then
  MODE=$(jq -r '.telemetry // "off"' "$GLOBAL_CONFIG" 2>/dev/null || echo "off")
fi
if [ -f "$PROJECT_CONFIG" ]; then
  PROJECT_MODE=$(jq -r '.telemetry // empty' "$PROJECT_CONFIG" 2>/dev/null || true)
  if [ -n "$PROJECT_MODE" ] && [ "$PROJECT_MODE" != "null" ]; then
    MODE="$PROJECT_MODE"
  fi
fi

if [ "$MODE" != "local" ]; then
  rm -f "$SCRATCH" 2>/dev/null || true
  exit 0
fi

# --- Privacy: truncate task description ---------------------------------
TASK_TRUNC=$(printf '%s' "$TASK" | cut -c 1-80)

# --- Pricing constants (USD per 1M tokens; May 2026 illustrative) ------
# Update from anthropic.com/pricing as needed. Output tokens cost more
# than input on every model; we treat input as 1.5x output volume per
# stage (rough heuristic; varies with prompt caching).
PRICING=$(cat <<'JQ'
{
  "haiku":  { "in_per_m": 0.25, "out_per_m": 1.25 },
  "sonnet": { "in_per_m": 3.00, "out_per_m": 15.00 },
  "opus":   { "in_per_m": 15.00, "out_per_m": 75.00 }
}
JQ
)

# Bucket → output tokens (approximate)
BUCKETS=$(cat <<'JQ'
{
  "small":  750,
  "medium": 1750,
  "large":  3750,
  "xlarge": 7500
}
JQ
)

# --- Aggregate scratch into final record --------------------------------
LOG_FILE="$HOME/.claude/yukti-telemetry.jsonl"
mkdir -p "$HOME/.claude"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build the record. Per stage:
#   tokens_out_est = bucket lookup
#   tokens_in_est  = 1.5 * tokens_out_est (heuristic)
#   cost_usd       = (in*pricing.in + out*pricing.out) / 1e6
# Baseline (always-Opus): same total tokens × Opus pricing.
RECORD=$(jq -s \
  --arg task "$TASK_TRUNC" \
  --arg class "${TASK_CLASS:-unknown}" \
  --arg ts "$NOW" \
  --argjson pricing "$PRICING" \
  --argjson buckets "$BUCKETS" \
'
  def stage_tokens(s):
    ($buckets[s.size_bucket] // $buckets["medium"]) as $out
    | { tokens_in_est: ($out * 1.5 | floor), tokens_out_est: $out };

  def stage_cost(s; t):
    ($pricing[s.model] // $pricing["sonnet"]) as $p
    | ((t.tokens_in_est * $p.in_per_m + t.tokens_out_est * $p.out_per_m) / 1000000);

  map(. + (stage_tokens(.) as $t | { tokens_in_est: $t.tokens_in_est, tokens_out_est: $t.tokens_out_est, cost_usd: (stage_cost(.; $t) * 1000 | round / 1000) })) as $stages

  | ($stages | map(.tokens_in_est) | add // 0) as $total_in
  | ($stages | map(.tokens_out_est) | add // 0) as $total_out
  | ($stages | map(.cost_usd) | add // 0) as $yukti_cost
  | ((($total_in * $pricing.opus.in_per_m + $total_out * $pricing.opus.out_per_m) / 1000000)) as $opus_cost
  | (if $opus_cost > 0 then (1 - $yukti_cost / $opus_cost) * 100 else 0 end) as $saved_pct

  | {
      ts: $ts,
      task: $task,
      task_class: $class,
      stages: $stages,
      total: {
        tokens_in_est: $total_in,
        tokens_out_est: $total_out,
        cost_usd_yukti: ($yukti_cost * 1000 | round / 1000),
        cost_usd_baseline_opus: ($opus_cost * 1000 | round / 1000),
        saved_usd: (($opus_cost - $yukti_cost) * 1000 | round / 1000),
        saved_pct: ($saved_pct * 10 | round / 10)
      }
    }
' "$SCRATCH")

# --- Privacy gate: ensure record has no obvious source-content leakage ---
# Scratch entries should only be {stage, model, size_bucket} — but defense
# in depth: scan the final record for code-shaped patterns and refuse if
# found. (Won't trip on legitimate task descriptions; will trip on someone
# accidentally piping diff content through.)
LEAK=$(printf '%s' "$RECORD" | grep -cE '\b(function|class|import|const|def |let |var )\b' || true)
if [ "$LEAK" -gt 0 ]; then
  echo "yukti-telemetry: source-code patterns detected in record; aborting log write" >&2
  rm -f "$SCRATCH"
  exit 0
fi

# --- Append + cleanup ----------------------------------------------------
printf '%s\n' "$RECORD" | jq -c . >> "$LOG_FILE"
rm -f "$SCRATCH"
