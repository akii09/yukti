---
name: smart
description: Run the full Yukti pipeline for a coding task — explore (Haiku), plan (Opus), user-confirm, implement per phase (Sonnet), verify, review (Opus). Saves ~50-60% cost vs always-Opus while preserving quality.
context: fork
agent: smart-orchestrator
---

You are running the full Yukti pipeline for the following task:

$ARGUMENTS

Follow your system prompt's pipeline exactly. Do not skip the user-confirmation step after the planner produces a plan. Do not do the work yourself — delegate every step to the right specialist subagent via the Agent tool.

Begin with Step 1 (explore).
