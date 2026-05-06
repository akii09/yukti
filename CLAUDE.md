# CLAUDE.md

Project-level guide for Claude Code (or any AI assistant) and human contributors working in the **Yukti** repo. Read this before making changes.

---

## What Yukti is

A lightweight Claude Code plugin that splits a coding task across specialist subagents, each running on the cheapest model that can do its step well. The bet: routing buys ~50–60% cost reduction vs always-Opus, with quality on par for routine work.

- **Repo**: https://github.com/akii09/yukti
- **License**: MIT
- **Owner**: Akash Ree (`akii09` on GitHub)
- **Status**: pre-v0.1.0; see [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) (local-only, gitignored) for current phase.

---

## Strategy

### The pipeline
```
User: /yukti:smart <task>
  → explorer  (Haiku) — find files
  → planner   (Opus)  — phased plan
  → USER CONFIRMS PLAN ◀── hard gate, cannot skip
  → implementer (Sonnet) per phase — edit → verify → report
  → reviewer  (Opus)  — P0/P1/P2/P3 issues + verdict
```

### Why each choice was made
- **Haiku for explorer**: grep + glob doesn't need reasoning. Cheap and fast wins.
- **Opus for planner**: long-horizon multi-file reasoning is where Opus genuinely pulls ahead. Bad plans cost more downstream than the planner itself.
- **Sonnet for implementer**: near-Opus on focused, single-phase tasks at ~5× cheaper. The trick is keeping the focus tight (see "Edit, don't rewrite" below).
- **Opus for reviewer**: catches what Sonnet misses on the final diff. The asymmetric value: a missed P0 in review can cost more than the entire review run.
- **Opus for orchestrator with restricted tools**: the orchestrator only has `Agent`, `Read`, `Bash` — it physically *cannot* implement. It can only delegate. This is harness-enforced, not prompted.

### What Yukti deliberately does *not* do
These were considered and rejected; do not re-introduce without explicit discussion:
- **`UserPromptSubmit` auto-routing**: heuristic, silent misroutes degrade quality invisibly. Users type `/yukti:smart` instead.
- **Hard `Stop`-hook gates**: block semantics aren't fully documented (no confirmed loop-back, no max-block count). The Stop hook is advisory only; verification is inside the implementer.
- **MCP search server**: real win on exploration-heavy sessions, but substantial engineering and a runtime dependency. Deferred.

If a feature's reliability depends on undocumented Claude Code internals, **it does not ship in v1**.

---

## Working agreements (for AI assistants)

These are non-negotiable when an AI is making changes in this repo.

1. **Do not `git push`.** Ever, automatically. Make commits if approved, then stop and let the user push. The only exception is when the user explicitly approves a push in their *current* reply.
2. **Risk-averse posture.** When you have a choice between a clever-but-risky approach and a boring-but-reliable one, pick the boring one and surface the tradeoff. This is the user's "dream project" being taken open-source — over-engineering and undocumented-behavior bets are off the table.
3. **Plan-driven work.** Non-trivial changes go through [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md): goal → tasks → exit criteria → **verification steps the user can run**. Update the plan when reality changes.
4. **Verify before claiming done.** If the plan has verification commands, run them. If a verification surfaces a defect, fix it and re-run, don't paper over it.
5. **One commit per logical change.** Don't batch unrelated edits.
6. **Honest scope and honest claims.** Don't over-promise in code, comments, README, or docs. The README's "honest benchmarks" voice is the project's voice.

---

## Code-quality and consistency rules

### Naming convention (locked)
- **Lowercase `yukti`** for technical identifiers: command names (`/yukti:smart`), file paths (`yukti-config.json`), plugin name (`plugin.json` → `"name": "yukti"`), repo URLs (`github.com/akii09/yukti`), mktemp prefixes (`yukti-verify.XXXXXX`), marketplace install IDs (`yukti@akii09-yukti`).
- **Capitalized `Yukti`** for brand and display contexts: README h1, agent description fields, orchestrator system-prompt opening (`You are the Yukti orchestrator`), user-facing log lines and `systemMessage` strings.
- Never use the legacy name `optim-claude` / `optim-config` anywhere except historical notes in `docs/`.
- The user's GitHub handle is `akii09`. Never `akashree` — that was an earlier placeholder and has been swept from the repo.

### File / directory conventions
The plugin layout is documented in [README.md](README.md#file-structure) and is locked. New files belong in:
- `agents/` — subagent markdown files (frontmatter: `name`, `description`, `model`, `tools`)
- `skills/<name>/SKILL.md` — every skill must use `context: fork` + `agent: <name>` (the deterministic delegation mechanism)
- `hooks/hooks.json` — hook event registrations only
- `bin/` — executable shell scripts (chmod +x, `#!/usr/bin/env bash`, `set -euo pipefail`)
- `.claude-plugin/` — manifest and marketplace JSON only; nothing else
- `docs/` — local working docs (gitignored, not pushed)

### JSON / shell / markdown standards
- All JSON must pass `jq empty <file>`.
- All shell scripts must pass `bash -n <file>`. Use `set -euo pipefail` at the top.
- Hook scripts must read input from stdin and emit valid hook output JSON; smoke-test before committing.
- Markdown: use GitHub-flavored markdown. Tables for comparison data. Code fences with language tag.
- No emojis in code or docs unless the user explicitly requests them. The README's tone is plain, factual, and honest.

### Comments and dead code
- Default to **no comments**. The codebase is small; well-named identifiers carry the weight.
- A comment is justified only when the *why* is non-obvious — a hidden constraint, a workaround for a specific Claude Code quirk, or behavior that would surprise a future reader. Reference the doc URL when it's a behavior pinned to docs.
- Don't leave `// removed X` placeholders, half-implemented branches, or speculative TODOs in committed code. Open an issue or update the plan instead.

### Hook scripts in particular
- `cap-read.sh` and `stop-verify.sh` must be **idempotent and silent on the happy path** (no output when there's nothing to inject or warn about).
- Read the project config from `${CLAUDE_PROJECT_DIR}/.claude/yukti-config.json` if present, falling back to documented defaults.
- Failures must not block the user's work; they emit `additionalContext` for advisory surfacing.

### Subagent prompts
- The implementer's prompt forbids Grep/Glob — files come from the planner. Don't relax this; it's the lever that keeps Sonnet focused.
- The orchestrator's tool list is restricted to `Agent`, `Read`, `Bash`. Don't add `Edit` or `Write` "for convenience"; the restriction is the design.

### Verification (every change touches it)
For any non-trivial change, the workflow is:
1. State the goal and exit criteria.
2. Write or update the verification commands in `docs/IMPLEMENTATION_PLAN.md`.
3. Make the change.
4. Run the verification commands; fix defects until green.
5. Commit. (Stop. Do not push.)

---

## Open-source contribution rules

We accept:
- Verification command presets for non-JS projects (Go, Rust, Python) in `bin/stop-verify.sh`.
- Real-world benchmark data — open an issue with the numbers and the task type.
- Bug fixes with a reproducer and a verification step.

We do not accept:
- Features whose behavior depends on undocumented Claude Code internals.
- "More aggressive" auto-routing that compromises quality.
- Marketing claims about cost or token savings beyond what we can demonstrate.
- Major scope expansions without prior discussion in an issue.

PRs should:
- Reference an issue or a phase in `docs/IMPLEMENTATION_PLAN.md`.
- Include verification steps a reviewer can run.
- Update the README only if user-visible behavior changes.

---

## Quick reference

- **What's in v0.1.0**: see "Phase 1" in [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md).
- **How to run the plugin locally**: `claude --plugin-dir ./` from the repo root.
- **Smoke-test the hooks**: see Phase 1 verification block in the plan.
- **Don't push for the user.** Always.
