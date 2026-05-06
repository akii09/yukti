---
name: smart
description: Run the full Yukti pipeline for a CODE CHANGE task (add/fix/refactor) — explore (Haiku), plan (Opus), confirm, implement (Sonnet), review (Opus). Saves ~50-60% cost vs always-Opus while preserving quality. NOT for analysis/comparison/explanation — use plain Claude Code for those.
context: fork
agent: smart-orchestrator
---

You are running the full Yukti pipeline for the following task:

$ARGUMENTS

Follow your system prompt's pipeline exactly. Begin with **Step 0 (classify the request)** — `/yukti:smart` is only for concrete code changes. If the request is an analysis, comparison, explanation, or pure debugging question, refuse politely with a suggested alternative and stop. If it is a code change, continue to Step 1 (explore). Never skip the user-confirmation step after the planner produces a plan. Never do the work yourself — delegate every step to the right specialist subagent via the Agent tool.
