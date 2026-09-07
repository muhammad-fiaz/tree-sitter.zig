import { withBase } from "vitepress";

// Resolve a component link for hosting under the site base with clean
// URLs disabled: external, hash, and mailto links pass through untouched,
// directory links and paths with a file extension keep their shape, and
// bare page paths gain `.html` so they resolve on static hosting.
export function resolveSiteLink(link: string): string {
  if (/^(https?:)?\/\//.test(link) || link.startsWith("#") || link.startsWith("mailto:")) return link;
  if (link.endsWith("/") || /\.[A-Za-z0-9]+$/.test(link)) return withBase(link);
  return withBase(`${link}.html`);
}
