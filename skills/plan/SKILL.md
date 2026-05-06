---
name: plan
description: Produce a phased implementation plan for a task. Reads files, identifies risks, breaks work into small verifiable phases. Runs on Opus. Does NOT write code — produces a plan for review before implementation.
context: fork
agent: planner
---

Produce a phased plan for this task:

$ARGUMENTS

If the user has provided a file list (from a prior `/yukti:explore` call or pasted from the explorer), use it. If not, read the task carefully and identify the files yourself with Grep/Glob before planning.

Follow your system prompt rules. Output the structured plan only — no code, no preamble. Stop after the plan; do not implement.
