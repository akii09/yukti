# Yukti — landing page

Marketing/landing page for the [Yukti](https://github.com/akii09/yukti) plugin. Built with [Astro](https://astro.build/) for best-in-class SEO and zero default JS.

## Stack

- **Astro 5** — static-first, ships near-zero JS by default
- **Motion** (`motion.dev`) — available for any future micro-animations (current build uses native CSS + a tiny IntersectionObserver for scroll reveal — no Motion One runtime needed yet)
- **Rough.js** — declared for future hand-drawn shapes (current build uses pre-baked SVG paths instead, keeping JS bundle minimal)
- **Caveat + Inter + JetBrains Mono** — Google Fonts, weight-scoped, `display=swap`

## Develop

```bash
cd web
npm install
npm run dev          # http://localhost:4321
```

## Build

```bash
npm run build
npm run preview
```

The static output lands in `web/dist/` ready to deploy.

## Deploy

### Cloudflare Pages (recommended)

1. Cloudflare Pages → Create project → Connect to your GitHub `akii09/yukti` repo
2. Build settings:
   - **Framework preset**: Astro
   - **Build command**: `npm run build`
   - **Build output directory**: `dist`
   - **Root directory (advanced)**: `web`
3. Deploy. Default URL `yukti.pages.dev` (or similar). Custom domain optional.

### Vercel

1. Vercel → Import → pick `akii09/yukti`
2. Set **Root directory** to `web`
3. Vercel auto-detects Astro. Deploy.

### GitHub Pages

If you prefer GitHub Pages, set `astro.config.mjs` `site` to your final URL and add a workflow that builds `web/` and pushes `web/dist` to a `gh-pages` branch. Cloudflare/Vercel are simpler.

## Customizing

- **Color tokens**: `src/styles/global.css` — change `--accent`, `--ink`, etc. in `:root`.
- **Sections**: `src/components/*.astro` — each section is a self-contained component.
- **SEO**: `src/layouts/BaseLayout.astro` — title, description, OpenGraph, JSON-LD.
- **Site URL**: `astro.config.mjs` `site` field — set to your production URL so canonical/sitemap/og URLs are correct.

## Performance budget

The page is intentionally minimal. Current targets:

- HTML: <30 KB gzipped
- CSS: <15 KB gzipped (component-scoped, deduplicated by Astro)
- JS: <5 KB gzipped (just the IntersectionObserver + smooth-scroll script)
- Lighthouse: 100 / 100 / 100 / 100 expected on a clean deploy

If you add animations or interactive components, prefer **Motion One** (already in deps) or scoped CSS animations over large libraries.
