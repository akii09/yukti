# CLAUDE.md — web/

Working instructions for anyone (AI or human) editing the Yukti landing page in this directory. Read this **and the root [`CLAUDE.md`](../CLAUDE.md)** before changing any file in `web/`.

The root CLAUDE.md's rules apply here too: **no state-changing git commands**, **manual verification before commit**, **suggest commits in chat for the user to run**.

---

## What this directory is

The Yukti landing page. An Astro 5 static site, deployed to Cloudflare Pages (or any static host). It is **independent of the plugin runtime** — editing files here cannot break the plugin behavior.

But the site **describes** the plugin, so its content must stay in sync with the plugin source. See "Alignment with the plugin" below and the cross-cutting checklist in the root [`CLAUDE.md`](../CLAUDE.md#cross-cutting-alignment--keeping-plugin-and-web-in-sync).

---

## Stack (locked unless explicitly approved)

- **Astro 5** — static-first, ships zero JS by default
- **Motion** (`motion.dev`) — declared for any future micro-animations. Current build uses CSS + a tiny IntersectionObserver instead.
- **Rough.js** — declared for future hand-drawn shapes. Current build uses pre-baked SVG paths.
- **Google Fonts**: Caveat (display), Inter (body), JetBrains Mono (code), with `display=swap`
- **No frontend framework runtimes.** Astro components only — no React, Vue, Svelte hydrations unless explicitly approved.

---

## What's locked (don't change without discussion)

- **Color tokens** in `src/styles/global.css` `:root` — `--ink`, `--paper`, `--accent`, `--accent-soft`, `--accent-ink`, the grey scale. These are brand. Changing them requires explicit approval.
- **Logo** in `src/components/Logo.astro` — hand-drawn `Y` with 3-branch descender. Branches represent the model split (Haiku/Sonnet/Opus). The `viewBox`, stroke widths, and bezier paths are tuned; do not refactor without discussion. The `favicon.svg` in `public/` mirrors the static logo and must stay byte-equivalent.
- **Section order** on the landing page (`src/pages/index.astro`)
- **Performance budget** (see below)
- **SEO surface** in `BaseLayout.astro`: `title`, `description`, `canonical`, all OpenGraph tags, the JSON-LD `SoftwareApplication` block. Don't remove or rename these.
- **Site URL** in `astro.config.mjs` — change only when changing the actual production URL.

## What's safe to change

- Section copy (claims, benchmark rows, story milestones, install commands, usage examples)
- Add new sections by adding a component in `src/components/` + including it in `src/pages/index.astro`
- Animation timing and easing
- Adding scoped Motion One imports for new interactive bits (already in deps)
- Adding optional Rough.js shapes if needed (already in deps)

---

## Astro scoping gotcha (learned the hard way in v0.2.0)

When writing scoped `<style>` rules with `:checked ~ ...` selectors (CSS-only tabs via radio inputs, accordion patterns, etc.), **do NOT comma-group multiple `:checked` selectors into one ruleset.** Astro's CSS scoper has a bug where the leading `#id:checked ~` prefix gets dropped from the FIRST selector in the comma group, leaving an unconditional rule like `.tab-labels label[for=foo] { ... }` that always matches.

Wrong (Astro mangles the first selector — one tab always appears active):
```css
#tab-a:checked ~ .panels .panel-a,
#tab-b:checked ~ .panels .panel-b { display: block; }
```

Right (split into separate rulesets, repeat the body — verbose but correct):
```css
#tab-a:checked ~ .panels .panel-a { display: block; }
#tab-b:checked ~ .panels .panel-b { display: block; }
```

See `src/components/GetStarted.astro` for the canonical workaround in this codebase. If you ever add another set of CSS-only tabs / accordions / radio-driven UI, follow the split-rule pattern.

Also: CSS-only tabs require the radio inputs to be **direct siblings** of the elements they control via `~`. Don't wrap radios in a `<fieldset>` or any container — the general-sibling combinator can't cross those boundaries. For accessibility, put `role="region"` + `aria-label` on the outer wrapper instead.

## Performance budget

This is a one-page marketing site. The bar is **Lighthouse 100 across all four categories** on a clean Cloudflare Pages deploy.

Current production bundle (gzipped):
- HTML: ~8 KB
- CSS: ~5 KB
- JS: 0 (inlined IntersectionObserver, no separate bundle)
- **Total: ~13 KB** (excluding fonts that browsers cache)

Hard limits:
- HTML: <30 KB gzipped
- CSS: <15 KB gzipped
- JS: <10 KB gzipped (across all bundles)
- **Total page weight (excl. fonts): <50 KB gzipped**

Any change that drops a Lighthouse category below 95 must be named explicitly to the user with the regression source. Any change that exceeds the bundle limits must be justified.

If you add JS, prefer in this order:
1. Inline `<script>` blocks inside `index.astro` or component files (Astro inlines them; no extra request)
2. Motion One for animations (already in deps, ~3.8 KB)
3. Native browser APIs (IntersectionObserver, `navigator.clipboard`, `scrollIntoView`)

Avoid: full frameworks, jQuery, large utility libs, anything that requires a `<script type="module" src="...">` external bundle.

---

## Component layout

```
src/
├── layouts/
│   └── BaseLayout.astro       SEO, fonts, JSON-LD, body wrapper
├── pages/
│   └── index.astro            Composes sections; scroll-reveal + smooth-scroll JS lives here
├── components/
│   ├── Logo.astro             Hand-drawn Y wordmark; entrance animation
│   ├── Nav.astro              Sticky nav with blur backdrop
│   ├── Hero.astro             Title, claim, click-to-copy install command
│   ├── Pipeline.astro         5-stage SVG diagram (data in `steps` array)
│   ├── WhyUse.astro           6 claim cards (data in `claims` array)
│   ├── GetStarted.astro       3 install paths + 4 usage examples (data in `installs` and `examples`)
│   ├── Benchmarks.astro       Table + 3 disclaimers (data in `rows`)
│   ├── Story.astro            Architecture timeline (data in `milestones`)
│   ├── Contribute.astro       Want / don't-want columns (data in `want`, `dontWant`)
│   └── Footer.astro           Brand + nav + signature
└── styles/
    └── global.css             Tokens, typography, base layout, reveal utility
```

Each section component has its content in a small frontmatter array — that's where most edits happen.

---

## Alignment with the plugin

This site **trails** the plugin source. Common drift sources and where to update:

| If you change in the plugin… | Update in `web/` |
|---|---|
| A subagent's `model` (`agents/<name>.md`) | `Pipeline.astro` `steps` array — `model:` field |
| A skill's invocation pattern (`skills/*/SKILL.md`) | `GetStarted.astro` `examples` array; `Hero.astro` install command if `/yukti:smart` is renamed |
| Install instructions in root `README.md` | `Hero.astro` install command; `GetStarted.astro` `installs` array |
| Repo URL or marketplace ID | `Hero.astro`, `GetStarted.astro`, `Contribute.astro`, `Footer.astro` link `href`s |
| Benchmark numbers in `README.md` | `Benchmarks.astro` `rows` array — keep numbers identical to README |
| New tagged release / architecture iteration | `Story.astro` `milestones` array — **append** an entry, don't replace existing ones (the timeline is part of the brand story) |
| Contribution rules in root `CLAUDE.md` or `CONTRIBUTING.md` | `Contribute.astro` `want` / `dontWant` arrays |
| Color/font tokens in brand | `src/styles/global.css` — but discuss with user first |
| New skill in plugin (`/yukti:status`, etc.) | `GetStarted.astro` examples (if user-visible); README skill table is the canonical list — web mirrors it |
| New hook event registered (`SessionStart`, `UserPromptSubmit`, etc.) | Mention in `WhyUse.astro` if user-visible; skip web update for purely-internal hooks |
| Project-level state file added (e.g. `.claude/.yukti-state.json`) | No web change needed — site doesn't surface runtime state |

When making a plugin change, **proactively check** which of the above need to follow, and surface drift to the user with the specific file:line references. Never silently update the web copy from a plugin change without flagging it first — the user may want to bundle web changes into a different commit.

The full alignment audit script is in the root [`CLAUDE.md`](../CLAUDE.md#cross-cutting-alignment--keeping-plugin-and-web-in-sync). Run it after any behavior-affecting change.

---

## Develop / build / verify

```bash
cd web

# install once
npm install

# develop
npm run dev               # http://localhost:4321

# production build (run before suggesting commits that touch this folder)
npm run build

# preview the built output
npm run preview

# bundle-size check (gzipped)
for f in dist/index.html dist/_astro/*.css dist/_astro/*.js; do
  printf "  %-60s " "$f"
  gzip -c "$f" 2>/dev/null | wc -c | awk '{printf "%6.1f KB gz\n", $1/1024}'
done
```

Astro's build catches most issues — frontmatter typos, broken imports, missing components. **Always run `npm run build` before suggesting a commit**; if it fails, the change isn't ready.

---

## SEO requirements (must hold for every change)

- `<title>` set per page via `BaseLayout` `title` prop (under 60 chars)
- `<meta name="description">` 140–160 chars, includes "Claude Code" and "Yukti"
- `<link rel="canonical">` matching `og:url`
- Full OpenGraph + Twitter card tags
- JSON-LD `SoftwareApplication` block (in `BaseLayout`)
- Semantic HTML: one `<h1>` per page, header/main/footer/section landmarks, `aria-label` on nav and major regions
- Skip-link for keyboard users
- All decorative SVGs marked `aria-hidden="true"`
- All meaningful SVGs have `role="img"` + `aria-label`
- `prefers-reduced-motion` respected for every animation

If a change risks any of these, name it explicitly to the user.

---

## Deploy

Cloudflare Pages auto-deploys on push to `main` once the project is configured (Root: `web`, Build: `npm run build`, Output: `dist`). After the first deploy:

1. Note the actual deploy URL (e.g. `yukti.pages.dev`)
2. Update `astro.config.mjs` `site` field to match
3. Commit + push (canonical/og/sitemap URLs will update on next deploy)

---

## When suggesting changes (recap of root CLAUDE.md)

- Make file changes locally; run `npm run build` to verify
- Do NOT run `git commit`, `git push`, `git tag`, or any state-changing git command
- Surface a suggested single-line commit message in chat for the user to run
- If the change touches `web/` AND the plugin, suggest separate commits unless the alignment is genuinely a single logical change
