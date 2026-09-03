// Breadcrumb helpers shared by the theme layout and JSON-LD generation.

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

function pageUrl(siteUrl: string, clean: string, isIndex: boolean): string {
  if (clean.length === 0) return siteUrl;
  return isIndex ? `${siteUrl}/${clean}/` : `${siteUrl}/${clean}.html`;
}

export function breadcrumbsForPath(siteUrl: string, relativePath: string): Crumb[] {
  const crumbs: Crumb[] = [{ name: "Home", url: siteUrl }];
  const isIndex = /(^|\/)index\.md$/.test(relativePath);
  const clean = relativePath.replace(/\.md$/, "").replace(/(^|\/)index$/, "$1").replace(/\/$/, "");
  if (clean.length === 0) return crumbs;
  const parts = clean.split("/");
  parts.forEach((part, index) => {
    const isLast = index === parts.length - 1;
    const url = isLast
      ? pageUrl(siteUrl, clean, isIndex)
      : `${siteUrl}/${parts.slice(0, index + 1).join("/")}/`;
    crumbs.push({ name: titleCase(part), url });
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
