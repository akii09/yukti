---
name: implement
description: "[Deprecated as standalone — internal pipeline stage] Apply ONE phase of an approved plan to specified files. Edits only, no rewrites, no exploration. Runs on Sonnet. Use /yukti:smart for the full code-change pipeline; the orchestrator invokes the implementer per phase. Direct invocation is preserved for power users but may be removed in v0.3."
context: fork
agent: implementer
---

> **Deprecated as a standalone skill.** The `implementer` agent is still actively used by the `smart-orchestrator` as Step 4 of the `/yukti:smart` pipeline — it's not going away. Direct invocation via `/yukti:implement` is preserved for now but is **rarely useful**:
>
> - The implementer requires a phase number, file list, phase description, and verification command — those are produced by the planner during `/yukti:smart`. Without them, you'd have to construct them yourself.
> - For most workflows, `/yukti:smart <task>` is the right entry point.
>
> May be removed entirely in v0.3 if usage signal stays low.

Implement the following phase:

$ARGUMENTS

The argument should contain (or reference):
- Phase number and title
- Files in scope for this phase
- Phase description (what changes)
- Verification command for this phase

If any of those are missing from the argument, stop and ask the user to provide the phase details from their approved plan.

Follow your system prompt's 8 hard rules. Make the edits, run verification, report. Stop at the phase boundary — do not start the next phase.
