# Contributing to Yukti

Thanks for considering a contribution. This file is short on purpose — most rules live in [CLAUDE.md](CLAUDE.md), which is the single source of truth for *how this codebase works*. Read that first.

## What we want most

In rough priority order:

1. **Real-world benchmark data.** The README claims ~50–60% cost reduction. We need data that confirms or contradicts it. If your numbers are bad, **submit them anyway** — that is the highest-value contribution to the project right now. Open a [Benchmark report](.github/ISSUE_TEMPLATE/benchmark.md) issue.
2. **Bug reports with a reproducer.** Use the [Bug report](.github/ISSUE_TEMPLATE/bug_report.md) template. Include the exact command and full output.
3. **Verification-command presets** for non-JS/Go/Rust/Python projects in [`bin/stop-verify.sh`](bin/stop-verify.sh) (e.g. Elixir `mix compile --warnings-as-errors`, Java `./gradlew compileJava`).
4. **Documentation fixes** — typos, broken links, install steps that don't work for your environment.

## What we will not accept

- Features whose behavior depends on **undocumented Claude Code internals**. We're explicit about this in `CLAUDE.md` — auto-routing via `UserPromptSubmit`, hard `Stop`-hook gates, and similar speculative bets are off the table.
- "More aggressive" auto-routing that compromises quality.
- Marketing claims about cost or token savings beyond what we can demonstrate.
- Major scope expansions without prior discussion in an issue.
- PRs without a verification step a reviewer can run.

## Submitting a PR

1. **Open an issue first** for anything beyond a small fix, so we can align on scope.
2. **Branch from `main`.**
3. **Keep the change focused.** One logical change per PR. Don't bundle unrelated edits.
4. **Run the relevant verifications** before opening the PR:
   - JSON valid: `for f in $(find . -name "*.json" -not -path "./.git/*"); do jq empty "$f"; done`
   - Shell syntax: `for f in bin/*.sh install.sh; do bash -n "$f"; done`
   - If you touched `cap-read.sh` or `stop-verify.sh`, smoke-test with a synthetic input (see existing examples in those scripts).
   - If you touched `install.sh`, run it against a temp dir: `bash install.sh /tmp/test-install` and inspect the result.
5. **Describe what changed and why** in the PR body. Link the issue. List the verification commands you ran.

## Naming conventions (locked)

- **Lowercase `yukti`** for technical identifiers: command names (`/yukti:smart`), file paths, plugin name, repo URLs.
- **Capitalized `Yukti`** for brand and display contexts: README h1, agent descriptions, user-facing messages.

## Code style

- Default to **no comments**. The codebase is small and self-documenting. A comment is justified only when the *why* is non-obvious — a hidden constraint, a workaround for a specific Claude Code quirk, or behavior that would surprise a future reader.
- Shell scripts: use `#!/usr/bin/env bash` and `set -euo pipefail`. Be silent on the happy path.
- Markdown: use GitHub-flavored markdown. Tables for comparison data. No emojis unless the project's tone calls for them (it generally doesn't).

## Code of conduct

Be civil. Disagreement on technical choices is welcome; personal attacks are not. Maintainer reserves the right to lock or close issues that don't meet that bar.

## License

By contributing you agree your contribution is licensed under the project's [MIT License](LICENSE).
