---
name: implement
description: Apply ONE phase of an approved plan to specified files. Edits only, no rewrites, no exploration. Runs on Sonnet. Receives an exact file list, phase description, and verification command. Use after `/yukti:plan` has produced a plan you've approved.
context: fork
agent: implementer
---

Implement the following phase:

$ARGUMENTS

The argument should contain (or reference):
- Phase number and title
- Files in scope for this phase
- Phase description (what changes)
- Verification command for this phase

If any of those are missing from the argument, stop and ask the user to provide the phase details from their approved plan.

Follow your system prompt's 8 hard rules. Make the edits, run verification, report. Stop at the phase boundary — do not start the next phase.
