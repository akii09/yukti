---
name: explore
description: "[Deprecated as standalone — internal pipeline stage] Locate the minimum set of files relevant to a task. Returns a precise file list. Runs on Haiku. Use /yukti:smart for code-change tasks; the orchestrator invokes the explorer internally. Direct invocation is preserved for power users but may be removed in v0.3."
context: fork
agent: explorer
---

> **Deprecated as a standalone skill.** The `explorer` agent is still actively used by the `smart-orchestrator` as Step 1 of the `/yukti:smart` pipeline — it's not going away. Direct invocation via `/yukti:explore` is preserved for now but is **redundant** for most users:
>
> - For a code-change task, just type `/yukti:smart <task>` — the orchestrator invokes the explorer for you.
> - For a "where is X?" question, plain Claude Code is faster (the smart skill is non-forked; it'll route to direct answer).
>
> Direct `/yukti:explore` is most useful when you specifically want a fresh Haiku-based file scan with no further pipeline. May be removed entirely in v0.3 if usage signal stays low.

Locate the files needed for this task:

$ARGUMENTS

Follow your system prompt rules. Return only the structured file list — no preamble, no explanation. Stay under 10 tool calls.
