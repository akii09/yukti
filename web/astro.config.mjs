import { defineConfig } from 'astro/config';

// https://astro.build/config
//
// IMPORTANT: edit `site` to your production URL before deploying so
// canonical/og/sitemap URLs are correct.
//   - Cloudflare Pages / Vercel root domain  → just the host, e.g. https://yukti.dev
//   - GitHub Pages project page              → host + base, plus add `base: '/yukti'`
export default defineConfig({
  site: 'https://yukti.pages.dev',
  build: {
    inlineStylesheets: 'auto',
  },
  compressHTML: true,
});
