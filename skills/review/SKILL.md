---
name: review
description: Review a recently-applied diff for bugs, regressions, missing tests, and quality issues. Reads the diff first, files only as needed. Runs on Opus. Returns a prioritized P0/P1/P2/P3 issue list and a SHIP/FIX-FIRST/NEEDS-REWORK verdict.
context: fork
agent: reviewer
---

Review the recently-applied changes.

Context from the user (if any):

$ARGUMENTS

Start by running `git diff HEAD~1` to see the change. If there are no recent commits, run `git diff` to review uncommitted changes. Follow your system prompt rules — read the diff first, cite file:line for every issue, give a verdict.
