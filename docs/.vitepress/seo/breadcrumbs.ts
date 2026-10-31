// BreadcrumbList JSON-LD for search engines.
//
// Breadcrumbs are emitted as structured data only (no visible UI). The list
// is intentionally kept to Home + the current page so every `item` URL is a
// real canonical page and search crawlers never see synthetic section URLs.

import { canonicalUrlFor } from "./urls";

export interface Crumb {
  name: string;
  url: string;
}

function titleCase(part: string): string {
  return part
    .split("-")
    .map((s) => (s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s))
    .join(" ");
}

function lastSegment(relativePath: string): string {
  const parts = relativePath
    .replace(/\.md$/, "")
    .split("/")
    .filter((part) => part.length > 0 && part !== "index");
  return parts.length > 0 ? parts[parts.length - 1] : "";
}

export function breadcrumbsForPath(siteUrl: string, relativePath: string): Crumb[] {
  const crumbs: Crumb[] = [{ name: "Home", url: `${siteUrl}/` }];
  if (relativePath === "index.md") return crumbs;

  const segment = lastSegment(relativePath);
  crumbs.push({
    name: segment.length > 0 ? titleCase(segment) : "Documentation",
    url: canonicalUrlFor(relativePath),
  });
  return crumbs;
}

export function breadcrumbJsonLd(siteUrl: string, relativePath: string): Record<string, unknown> {
  return {
    "@type": "BreadcrumbList",
    itemListElement: breadcrumbsForPath(siteUrl, relativePath).map((crumb, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: crumb.name,
      item: crumb.url,
    })),
  };
}
