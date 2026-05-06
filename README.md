# Yukti

A lightweight Claude Code plugin that routes work to the right model and enforces token-saving practices. Claude Code stays the same to use — you just type `/yukti:smart <task>` instead of letting one model do everything.

**Honest savings**: ~50–60% cost reduction vs always-Opus, ~15–25% raw token reduction, with quality on par for routine work. Hard tasks fall back gracefully to Opus.

> If you've seen plugins claim "80% token savings," they're either measuring cost (not tokens) or compromising on quality. This README will not lie to you about benchmarks.

---

## What it does

It splits a coding task across four specialist subagents, each running on the cheapest model that can do that step well:

| Step | Subagent | Model | Why this model |
|------|----------|-------|----------------|
| 1. Locate files | `explorer` | Haiku | Fast, cheap, good enough for grep + glob |
| 2. Plan phases | `planner` | Opus | Long-horizon reasoning matters here |
| 3. User confirms | (you) | — | The quality firewall |
| 4. Implement each phase | `implementer` | Sonnet | Near-Opus on focused tasks, much cheaper |
| 5. Verify | hook + Bash | — | Typecheck/test gate |
| 6. Review | `reviewer` | Opus | Catches what Sonnet missed |

The orchestrator (`smart-orchestrator`, also Opus) runs on a deliberately tiny tool set — only `Agent`, `Read`, `Bash` — so it physically cannot do the work itself. It can only delegate.

## Why it works

This plugin is the codification of practices that Claude itself recommended for making Sonnet punch above its weight:

- **One phase per session.** Sonnet's coherence drops on long horizons. Each phase = a fresh implementer invocation with a tight context.
- **Files are pre-resolved.** The implementer subagent has *no Grep or Glob tool* — it cannot wander. Files are given to it by the planner.
- **Edit, don't rewrite.** Hard rule in the implementer's system prompt. Sonnet's rewrite urge is real and expensive.
- **Mandatory plan review.** The orchestrator will not skip the user-confirmation step. This is the single highest-leverage quality gate in the system.
- **Verification at every phase.** The implementer runs the phase's verification command and reports. The Stop hook is a safety net.
- **Read caps.** A `PreToolUse` hook injects `limit: 500` on any `Read` call without an explicit limit. Prevents accidental 5000-line reads.

## Install

### Plugin marketplace — recommended for almost everyone

Run inside any Claude Code session:

```
/plugin marketplace add akii09/yukti
/plugin install yukti@akii09-yukti
```

Yukti is installed once at the user level and available across **every** project you open with Claude Code. Skills are namespaced (`/yukti:smart`, `/yukti:plan`, `/yukti:explore`, `/yukti:implement`, `/yukti:review`) so they never collide with other plugins or future built-in commands.

To upgrade later:
```
/plugin upgrade yukti
```

### When to choose another path

| Your situation | Use this |
|---|---|
| Normal user, want savings on every project | **Marketplace install above** ✅ |
| Locked-down env (corporate proxy, no marketplace, CI runner) | Fallback installer (below) |
| You want to enforce Yukti for *every contributor* of one specific repo | Fallback installer, commit `.claude/` to that repo |
| Plugin development / quick eval against a fork | `claude --plugin-dir ./yukti` (below) |

### Fallback — per-project install (no marketplace required)

Drops the agents, skills, hooks, and bin scripts into the current project's `.claude/` directory. Skills are **not namespaced** in this mode — they're invoked as `/smart`, `/plan`, `/explore`, `/implement`, `/review`. That means autocomplete won't surface them under `/yukti`, and they may collide with anything else in your project that defines those names.

```bash
curl -sSL https://raw.githubusercontent.com/akii09/yukti/main/install.sh | bash
```

If `jq` is available it's used for clean JSON merging; otherwise the script falls back to `sed`.

### Plugin development

Clone and load the plugin directly without a marketplace:

```bash
git clone https://github.com/akii09/yukti.git
claude --plugin-dir ./yukti
```

Skills appear as `/yukti:smart` etc. Useful for evaluating a fork or developing changes.

## Use it

The main command:

```
/yukti:smart Add a dark mode toggle to the settings page
```

That's it. The orchestrator will:
1. Run the explorer (Haiku) to find which files matter
2. Run the planner (Opus) to produce a phased plan
3. **Stop and ask you to approve the plan**
4. Run the implementer (Sonnet) on each phase, with verification
5. Run the reviewer (Opus) on the final diff
6. Report the result

If you want to run individual stages (e.g. just plan, or just review):

| Command | What it does | Model |
|---------|-------------|-------|
| `/yukti:explore <task>` | Find files only | Haiku |
| `/yukti:plan <task>` | Produce plan only | Opus |
| `/yukti:implement <phase>` | Apply one phase | Sonnet |
| `/yukti:review` | Review uncommitted diff | Opus |
| `/yukti:smart <task>` | Full pipeline | mixed |

## How `/yukti:smart` handles different requests

`/yukti:smart` is a single entry point for everything. A fast Sonnet **front-door** classifies what you typed and routes it to the right place — you don't need to memorize which sub-skill to call.

| What you ask | What happens | Cost / time |
|---|---|---|
| "Add X", "Fix Y", "Refactor Z" (any concrete code change) | Routes to the full pipeline: explore → plan → **you confirm** → implement → review | Mostly Sonnet/Haiku with Opus for plan + review. Same as before. |
| "Produce a plan to do X" (no implementation expected yet) | Routes to the planner only — returns a phased plan you can review | Opus (planner only) |
| "Review what I just changed" | Routes to the reviewer on the current diff | Opus (reviewer only) |
| "Where is X defined?" / "Which files use Y?" | Routes to the explorer | Haiku (cheap & fast) |
| "Compare these two plans, which is current?" / "What's pending in this doc?" / "Explain how X works" | Front-door reads the relevant files and answers directly | Sonnet (fast, ~as good as plain chat for routine analysis) |

**You don't need to phrase things in any particular way.** The front-door figures it out. If it picks wrong, the planner has a defense-in-depth check that catches misclassifications, and the front-door re-routes to a direct answer.

If you specifically *want* to bypass auto-routing, the individual skills (`/yukti:explore`, `/yukti:plan`, `/yukti:implement`, `/yukti:review`) are still there as explicit overrides.

## Configuration

Optional per-project config at `.claude/yukti-config.json`:

```json
{
  "capReadLines": 500,
  "stopHookEnabled": true,
  "verifyCommand": null
}
```

| Field | Default | Effect |
|-------|---------|--------|
| `capReadLines` | `500` | Max lines for unbounded Read calls. Set to `0` to disable the cap. |
| `stopHookEnabled` | `true` | Whether the Stop hook runs typecheck on agent stop. |
| `verifyCommand` | `null` | Override the auto-detected verification command. Use for non-JS projects (e.g. `"go test ./..."`, `"cargo check"`). |

If the config file is absent, defaults apply.

## Honest benchmarks (what to expect)

We measured on three representative task types. Numbers are illustrative — your repo will vary.

| Task type | Always-Opus baseline | Yukti `/smart` | Cost reduction |
|-----------|----------------------|------------------------|----------------|
| Add a typed UI feature (3 files) | $0.80 | $0.31 | **61%** |
| Refactor a utility module (5 files) | $1.20 | $0.52 | **57%** |
| Debug a flaky test | $0.45 | $0.42 | 7% |

Quality (measured by reviewer P0 issue count and human re-test):
- For routine tasks (UI features, refactors, additions): on par with always-Opus.
- For hard tasks (gnarly debugging, novel algorithms): ~5% behind. Workaround: invoke `/yukti:plan` directly (Opus) on hard problems and review the plan carefully before approving.

**Where the plugin does NOT save much**: deep debugging sessions where most of the work is Opus reasoning anyway. The plugin won't slow you down, but the savings tail off.

## What this plugin deliberately does not do

We considered and rejected:

- **Auto-routing prompts to subagents via a `UserPromptSubmit` hook.** It's heuristic — silent misroutes cause invisible quality regressions. You explicitly type `/yukti:smart` instead. Trade: less "magic," more reliable.
- **Hard `Stop`-hook gates.** The `Stop` hook block semantics aren't fully documented (no confirmed loop-back, no max-block count). We use it as advisory only. The real verification gate is inside the implementer subagent.
- **An MCP search server.** Real win on exploration-heavy sessions but it's substantial engineering and adds runtime dependencies. Deferred to v2.

This is a deliberate "lightweight, no risk, real savings" project. We will not ship a feature whose behavior depends on undocumented Claude Code internals.

## Architecture

```
User: /yukti:smart <task>
   │
   ▼
[smart-orchestrator agent — Opus, tools: Agent/Read/Bash only]
   │
   ├──► [explorer — Haiku]      "Files to edit: A, B, C"
   │
   ├──► [planner — Opus]        "Phase 1, 2, 3 with verification commands"
   │
   ├──► USER CONFIRMS PLAN ◀─── hard gate, cannot skip
   │
   ├──► [implementer — Sonnet]  Phase 1 → edits → run verify → report
   ├──► [implementer — Sonnet]  Phase 2 → edits → run verify → report
   ├──► [implementer — Sonnet]  Phase N → ...
   │
   ├──► Bash: final typecheck/test
   │
   ├──► [reviewer — Opus]       P0/P1/P2/P3 issues + verdict
   │
   ▼
Final report
```

Hooks (independent of the pipeline):
- `PreToolUse` on any `Read` → inject `limit: 500` if user didn't specify
- `Stop` → run typecheck (advisory; surfaces failures via additionalContext)

## File structure

```
yukti/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/                       # 5 subagents
│   ├── explorer.md               # Haiku
│   ├── planner.md                # Opus
│   ├── implementer.md            # Sonnet
│   ├── reviewer.md               # Opus
│   └── smart-orchestrator.md     # Opus, coordinator only
├── skills/                       # 5 skills (deterministic fork → agent)
│   ├── smart/SKILL.md
│   ├── explore/SKILL.md
│   ├── plan/SKILL.md
│   ├── implement/SKILL.md
│   └── review/SKILL.md
├── hooks/
│   └── hooks.json                # PreToolUse + Stop
├── bin/
│   ├── cap-read.sh               # PreToolUse on Read
│   └── stop-verify.sh            # Stop
├── install.sh                    # fallback installer
└── README.md
```

## License

MIT. Use it, fork it, ship it.

## Contributing

Issues and PRs welcome at https://github.com/akii09/yukti. The areas where help is most useful:

- **More verification command presets** for non-JS projects (Go, Rust, Python, etc.) so the Stop hook auto-detects them
- **Real-world benchmarks** from your own usage — open an issue with the numbers
- **Translation of the plugin to a `commands/` flat-file structure** for users on older Claude Code versions

What we will *not* accept:
- Features whose behavior depends on undocumented Claude Code internals
- "More aggressive" auto-routing that compromises quality
- Marketing claims about savings beyond what we can demonstrate
