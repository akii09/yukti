# CLAUDE.md

Project-level guide for Claude Code (or any AI assistant) and human contributors working in the **Yukti** repo. Read this before making changes.

---

## What Yukti is

A lightweight Claude Code plugin that splits a coding task across specialist subagents, each running on the cheapest model that can do its step well. The bet: routing buys ~50–60% cost reduction vs always-Opus, with quality on par for routine work.

- **Repo**: https://github.com/akii09/yukti
- **License**: MIT
- **Owner**: [`akii09`](https://github.com/akii09) on GitHub
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

1. **Do not run any state-changing git or `gh` command.** This is the strictest rule.
   - **Forbidden**: `git commit`, `git push`, `git tag`, `git add`, `git rm`, `git mv`, `git rebase`, `git merge`, `git cherry-pick`, `git revert`, `git reset`, `git checkout` (to switch branches or restore files), `git stash`, `gh release create`, `gh pr create`, `gh pr merge`, `gh issue close`, etc.
   - **Allowed (read-only)**: `git status`, `git log`, `git diff`, `git show`, `git branch --list`, `git tag --list`, `git remote -v`, `git ls-files`, `git rev-parse`, `git config --get`, `gh pr view`, `gh issue view`, `gh release view`.
   - When you would normally run a state-changing command, instead output the exact command for the user to run, with a suggested commit message inline. The user runs every git operation manually.
   - **Manual verification is required before every commit.** After making changes, stop. The user verifies and decides what to stage, what message to use, and when to commit/push/tag.
   - Prior approval does **not** generalize. Each git boundary needs explicit user action — no inferring "they said yes once, they'd say yes again."
2. **Risk-averse posture.** When you have a choice between a clever-but-risky approach and a boring-but-reliable one, pick the boring one and surface the tradeoff. This is the user's "dream project" being taken open-source — over-engineering and undocumented-behavior bets are off the table.
3. **Plan-driven work.** Non-trivial changes go through [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md): goal → tasks → exit criteria → **verification steps the user can run**. Update the plan when reality changes.
4. **Verify before reporting done.** If the plan has verification commands, run them yourself (read-only operations only). If a verification surfaces a defect, fix the file and re-run, don't paper over it. Surfacing a real defect during verification is a *good* outcome, not a setback.
5. **One commit per logical change** — when *suggesting* commits to the user. Don't bundle unrelated edits into a single suggested commit.
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

## Cross-cutting alignment — keeping plugin and web in sync

The repo has multiple surfaces that describe Yukti's behavior, install path, models, and brand. They must stay aligned. The plugin source files in `agents/`, `skills/`, `hooks/`, and `bin/` are the **source of truth**; everything else trails them.

| Surface | What lives there | Role |
|---|---|---|
| `agents/*.md` | Subagent definitions — model, tools, prompts | ✅ source of truth |
| `skills/*/SKILL.md` | Skill frontmatter, fork target, allowed-tools | ✅ source of truth |
| `hooks/hooks.json` + `bin/*.sh` | Hook behavior, config keys | ✅ source of truth |
| `.claude-plugin/plugin.json` + `marketplace.json` | Marketplace metadata | trails source |
| `install.sh` | Fallback installer, config file paths | trails source |
| `README.md` | User-facing docs — install, use, benchmarks, behavior | trails source |
| `CLAUDE.md` (this file) | AI working rules + project conventions | trails source |
| `CONTRIBUTING.md` | Contributor expectations | trails source |
| `web/` | Landing page — install commands, pipeline diagram, story timeline, benchmarks, contribution copy | trails source |

### When a behavior-affecting change lands, run the alignment audit

After modifying any of these (or before suggesting a commit that touches them):
- A subagent's `model` or `tools` in `agents/<name>.md`
- A skill's frontmatter (especially `agent:`, `context:`, `allowed-tools:`)
- A hook's behavior in `bin/*.sh`
- A config key in `yukti-config.example.json`
- A version release / new architecture iteration
- The README's install commands or skill-name table
- The contribution accept/reject lists

…run this audit and **flag anything that drifted to the user**. Do NOT silently update — surface drift with file paths and the specific lines that need attention. Let the user decide what to align.

```bash
# Yukti alignment audit — run from repo root
echo "=== 1. Subagent models (agents/) ==="
grep -E "^model:" agents/*.md

echo ""
echo "=== 2. Models referenced in web/ pipeline diagram (must match above) ==="
grep -nE "model: '(Haiku|Sonnet|Opus|human)'" web/src/components/Pipeline.astro 2>/dev/null

echo ""
echo "=== 3. Skill names + fork targets (skills/) ==="
for f in skills/*/SKILL.md; do
  printf "  %-30s " "$f"
  grep -hE "^(name|agent|context|allowed-tools):" "$f" | tr '\n' ' '
  echo
done

echo ""
echo "=== 4. Skill invocations in web/ usage examples (must reference real skills) ==="
grep -hoE "/yukti:[a-z-]+|/(smart|explore|plan|implement|review)\b" web/src/components/*.astro 2>/dev/null | sort -u

echo ""
echo "=== 5. Install commands across README, install.sh, web/ (must match exactly) ==="
echo "-- README.md:"
grep -nE "marketplace add|@akii09-yukti|raw\.githubusercontent\.com.*install\.sh" README.md
echo "-- install.sh REPO_GIT/REPO_RAW:"
grep -nE "REPO_(GIT|RAW)=" install.sh
echo "-- web/ install commands:"
grep -nE "marketplace add|@akii09-yukti|raw\.githubusercontent\.com.*install\.sh" web/src/components/Hero.astro web/src/components/GetStarted.astro 2>/dev/null

echo ""
echo "=== 6. Benchmark numbers (web/ table must match README's) ==="
grep -nE "[0-9]+%" README.md web/src/components/Benchmarks.astro 2>/dev/null | grep -E "cost|reduction|baseline|delta|−"

echo ""
echo "=== 7. Story timeline versions (web/) ==="
grep -nE "v0\.[0-9]+\.[0-9]+" web/src/components/Story.astro 2>/dev/null

echo ""
echo "=== 8. Contribution copy alignment (CLAUDE.md, CONTRIBUTING.md, web/Contribute) ==="
echo "-- CLAUDE.md 'We accept' items:"
sed -n '/^We accept:/,/^We do not accept:/p' CLAUDE.md | grep -E "^- "
echo "-- web/Contribute 'want' array:"
grep -A 6 "^const want = " web/src/components/Contribute.astro 2>/dev/null | grep "  '"
```

**Drift you should catch most often:**

| If you change… | Likely needs an update in |
|---|---|
| A subagent's `model` (`agents/*.md` frontmatter) | `web/src/components/Pipeline.astro` `steps` array |
| A skill name or `agent:` target | `web/src/components/GetStarted.astro` examples; `Hero.astro` if it's `/yukti:smart`; `README.md` skill table |
| Install commands (README) | `web/src/components/Hero.astro` install button; `web/src/components/GetStarted.astro` install cards; `install.sh` REPO_GIT URL |
| Benchmark numbers in README | `web/src/components/Benchmarks.astro` rows + disclaimers |
| New architecture iteration / new tagged release | `web/src/components/Story.astro` milestones array — **add a new entry, don't replace existing ones** |
| Contribution rules in this CLAUDE.md or in CONTRIBUTING.md | `web/src/components/Contribute.astro` `want` / `dontWant` arrays |
| Model labels (`Haiku`/`Sonnet`/`Opus`) | `web/src/components/Pipeline.astro`; pipeline ASCII art in `README.md`; agent description fields |
| Hook events registered (`hooks/hooks.json`) | `install.sh` post-install summary; `README.md` "Configuration"; `web/src/components/GetStarted.astro` if hooks are user-visible |
| New skill added in `skills/` | `README.md` skill table; `install.sh` post-install summary skill list |
| New config key in `yukti-config.example.json` | `README.md` "Configuration" table; `install.sh`'s default-config heredoc; relevant hook/skill scripts that read it |
| `bin/session-brief.sh` output format / state file schema | `skills/status/SKILL.md` (must produce equivalent output); `agents/smart-orchestrator.md` (writes the same schema) |

### Yukti-specific runtime state files (project-level)

The plugin writes these at runtime in the user's project — they are NOT source-of-truth, they're scratch state that the user gitignores:

| File | Written by | Read by | Purpose |
|---|---|---|---|
| `.claude/yukti-config.json` | user / `install.sh` (defaults) | hooks, scripts, agents | per-project config (capReadLines, briefEnabled, verifyCommand, telemetry, routingHints, …) |
| `.claude/.yukti-state.json` | `smart-orchestrator` between pipeline steps | `bin/session-brief.sh`, `skills/status/SKILL.md` | in-flight task state (lastTask, currentPhase, lastUpdated) |
| `.claude/.yukti-telemetry-scratch.jsonl` | `smart-orchestrator` (one line per pipeline stage) | `bin/yukti-telemetry-record.sh` (consumes + deletes at end of pipeline) | per-task scratch — only `{stage, model, size_bucket}`, no source content |
| `~/.claude/yukti-telemetry.jsonl` | `bin/yukti-telemetry-record.sh` (when telemetry: local) | `bin/yukti-savings-summary.sh`, `/yukti:status` | local-only opt-in usage log; per-task cost + baseline + savings |

### Privacy invariants for telemetry (must hold across every change)

When changing anything in the telemetry path (`bin/yukti-telemetry-record.sh`, `bin/yukti-savings-summary.sh`, the orchestrator's scratch-write instructions, or the subagent metrics directives), these must remain true:

1. **The scratch file contains ONLY** `{stage, model, size_bucket}` — never source content, file lists, diffs, prompts, or responses.
2. **Task descriptions are truncated to 80 chars** before they reach the log.
3. **The recorder enforces a privacy gate** that refuses to write any line matching common source-code patterns (`function`, `class`, `import`, `const`, `let`, `var`, `def`).
4. **Telemetry default is `"off"`** — opt-in only.
5. **Logs are local-only** — `~/.claude/yukti-telemetry.jsonl` is never uploaded by Yukti. (If a future feature wants to *opt-in* share, it must be a separate `share` mode behind explicit user action.)
6. **Disable is one config-flag flip away** — `"telemetry": "off"` immediately stops new writes; deleting the log file is one `rm` away.

### Privacy invariants for routing hints (must hold across every change)

When changing `bin/yukti-route-hint.sh` or its config field:

1. **The hook reads the prompt but writes nothing about it anywhere.** No logs, no scratch files. The only effect is the `additionalContext` emitted that turn — which goes back to the main agent, not to disk.
2. **Default mode is `"off"`** — no advisory ever, no behavior change.
3. **Classifier is conservative**: imperative verbs at the start, length filter, question-mark filter, skip if user already invoked `/yukti:*` or `/smart`. False negatives are fine; false positives cost trust.
4. **`"auto"` mode is honestly labeled as best-effort.** Claude Code hooks cannot directly invoke an agent. The hint is a strong suggestion to the main agent — never a guaranteed route. Documentation must say so.
5. **Coexists with other plugins' UserPromptSubmit hooks** without ordering dependency (per Claude Code docs: "all matching hooks run in parallel").

When changing the schema or output format of any of these, update both writers AND readers in the same logical change.

For the web's own working rules (stack, what's locked, what's editable, performance budget, deploy), see [`web/CLAUDE.md`](web/CLAUDE.md).

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
