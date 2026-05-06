#!/usr/bin/env bash
# Yukti: savings read-out.
#
# Prints a human-readable summary of recorded telemetry. Called by the
# /yukti:status skill. Silent (exit 0, no output) if telemetry is off
# or the log doesn't exist.
#
# Privacy: only reads ~/.claude/yukti-telemetry.jsonl which contains
# size buckets and computed costs — never source content.
#
# Usage:
#   yukti-savings-summary.sh [--days N]
#     --days: lookback window in days (default 30)

set -euo pipefail

DAYS=30
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="$2"; shift 2;;
    *) shift;;
  esac
done

LOG_FILE="$HOME/.claude/yukti-telemetry.jsonl"

if [ ! -f "$LOG_FILE" ]; then
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Compute cutoff timestamp (portable: GNU date and BSD date both support -v on Mac for this)
if date -u -v-${DAYS}d +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
  CUTOFF=$(date -u -v-${DAYS}d +%Y-%m-%dT%H:%M:%SZ)
else
  CUTOFF=$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")
fi

# Aggregate
SUMMARY=$(jq -s \
  --arg cutoff "$CUTOFF" \
  --arg days "$DAYS" \
'
  map(select(.ts >= $cutoff)) as $window
  | ($window | length) as $count
  | if $count == 0 then
      { count: 0, days: ($days | tonumber) }
    else
      ($window | map(.total.cost_usd_yukti) | add) as $yukti
      | ($window | map(.total.cost_usd_baseline_opus) | add) as $opus
      | ($window | map(.total.saved_usd) | add) as $saved
      | (if $opus > 0 then (1 - $yukti / $opus) * 100 else 0 end) as $saved_pct
      | ($window | group_by(.task_class) | map({
          class: .[0].task_class,
          count: length,
          yukti: (map(.total.cost_usd_yukti) | add),
          opus:  (map(.total.cost_usd_baseline_opus) | add)
        })) as $by_class
      | {
          count: $count,
          days: ($days | tonumber),
          yukti_total: ($yukti * 100 | round / 100),
          opus_total: ($opus * 100 | round / 100),
          saved_total: ($saved * 100 | round / 100),
          saved_pct: ($saved_pct * 10 | round / 10),
          by_class: $by_class
        }
    end
' "$LOG_FILE")

COUNT=$(printf '%s' "$SUMMARY" | jq -r '.count')

if [ "$COUNT" -eq 0 ]; then
  echo "**Yukti savings**: no logged tasks in the last $DAYS days. (Telemetry on; \`/yukti:smart\` runs will appear here as you use them.)"
  exit 0
fi

echo "**Yukti savings (last $DAYS days)**"
printf '%s' "$SUMMARY" | jq -r '
  "  Tasks run: \(.count)",
  "  Cost (Yukti):       $\(.yukti_total)",
  "  Cost (always-Opus): $\(.opus_total)",
  "  Saved:              $\(.saved_total) (\(.saved_pct)%)"
'
echo ""
echo "  By task class:"
printf '%s' "$SUMMARY" | jq -r '
  .by_class[] |
  "    \(.class): \(.count) tasks  ·  $\((.yukti * 100 | round / 100)) vs $\((.opus * 100 | round / 100)) baseline"
'
