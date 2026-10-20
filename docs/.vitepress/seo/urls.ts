// Canonical public URL resolution shared by the head tags, the JSON-LD
// structured data, the breadcrumbs, and the sitemap.
//
// The site is served from a GitHub Pages project subpath, so every public
// URL is prefixed with the deployment base. The shapes below mirror the
// URLs VitePress itself emits for the sitemap: section indexes end in "/",
// regular pages end in ".html" (clean URLs are disabled), and the site root
// is the base with a trailing slash.

import { SITE_URL } from "./metadata";

/**
 * Canonical absolute URL for a source page, given its path relative to the
 * docs root (e.g. "index.md", "api/index.md", "guide/getting-started.md").
 */
export function canonicalUrlFor(relativePath: string): string {
  const isIndex = /(^|\/)index\.md$/.test(relativePath);
  const clean = relativePath
    .replace(/\.md$/, "")
    .replace(/(^|\/)index$/, "$1")
    .replace(/\/$/, "");
  if (clean.length === 0) return `${SITE_URL}/`;
  return isIndex ? `${SITE_URL}/${clean}/` : `${SITE_URL}/${clean}.html`;
}
