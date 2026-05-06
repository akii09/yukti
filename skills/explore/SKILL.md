---
name: explore
description: Locate the minimum set of files relevant to a task. Returns a precise file list with confidence rating. Runs on Haiku (cheap, fast). Use when you need to know which files to touch before planning or implementing.
context: fork
agent: explorer
---

Locate the files needed for this task:

$ARGUMENTS

Follow your system prompt rules. Return only the structured file list — no preamble, no explanation. Stay under 10 tool calls.
