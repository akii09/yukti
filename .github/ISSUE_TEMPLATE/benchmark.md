---
name: Benchmark report
about: Share real-world cost / quality numbers from your Yukti usage. These are the highest-value contribution to the project.
title: "[benchmark] <task type>: <one-line summary>"
labels: benchmark
assignees: ''
---

> Yukti's claim is **~50–60% cost reduction with quality on par for routine work**. We need real-world numbers to validate that. If your numbers contradict the claim — that's the most valuable thing you can report. We will not delete unflattering data.

## Setup

- **Yukti version**: <!-- e.g. v0.1.0 — check `/plugin list` or git tag -->
- **Install method**: <!-- marketplace / curl fallback / --plugin-dir -->
- **Project type**: <!-- e.g. TypeScript Next.js app, Rust CLI, Python ML pipeline -->
- **Approx project size**: <!-- e.g. ~50 source files, ~8000 LOC -->

## The task

<!-- One paragraph describing what you asked Yukti to do. Be specific. -->

## Numbers

|  | Always-Opus baseline | Yukti `/yukti:smart` | Delta |
|---|---|---|---|
| Total cost (USD) |  |  |  |
| Total tokens |  |  |  |
| Wall-clock time |  |  |  |
| Result quality (subjective 1–5) |  |  |  |

> If you only have one of (cost / tokens), that's still useful. Report what you have.

## What surprised you (good or bad)

<!--
Examples worth writing:
- "The planner missed file X that was obvious to me."
- "Reviewer caught a P0 I would've shipped."
- "Implementer rewrote a file I asked it to edit." (this is a bug — we want it)
- "Stop-hook verification was slow / loud / quiet."
-->

## Anything else?

<!-- Anonymized snippets, links to relevant code, etc. -->
