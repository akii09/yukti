---
name: Bug report
about: Something Yukti did that it shouldn't, or something that broke
title: "[bug] <one-line summary>"
labels: bug
assignees: ''
---

## What happened

<!-- One or two sentences. What did you expect, what did you see. -->

## Reproducer

<!--
Minimal steps a stranger could follow to see the same thing. Include:
- The exact command you ran (e.g. `/yukti:smart Add a dark mode toggle`)
- Any project-specific context that matters
- The full output, or the relevant slice (use a code fence or `details`)
-->

```
<paste output here>
```

## Environment

- **Yukti version**: <!-- e.g. v0.1.0 -->
- **Install method**: <!-- marketplace / curl fallback / --plugin-dir -->
- **Claude Code version**: <!-- output of `claude --version` -->
- **OS**: <!-- macOS 14.x / Ubuntu 22.04 / etc. -->
- **Project language(s)**: <!-- TypeScript / Go / Rust / Python / mixed -->

## Hook behavior (if relevant)

- [ ] `cap-read.sh` fired when not expected, or didn't fire when it should have
- [ ] `stop-verify.sh` ran the wrong command, or its advisory message looked wrong
- [ ] Not hook-related

## Anything you tried to work around it

<!-- Useful for prioritization. -->
