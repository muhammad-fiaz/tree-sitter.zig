// JSON-LD structured-data builders.
import { SITE_URL, SITE_NAME, SITE_DESCRIPTION, SITE_VERSION, AUTHOR_NAME, AUTHOR_URL, REPO_URL } from "./metadata";
import { breadcrumbJsonLd } from "./breadcrumbs";

interface PageInfo {
  title: string;
  description: string;
  relativePath: string;
  lastUpdated?: number;
  isFaq?: boolean;
}

function authorSchema(): Record<string, unknown> {
  return {
    "@type": "Person",
    name: AUTHOR_NAME,
    url: AUTHOR_URL,
    sameAs: ["https://github.com/muhammad-fiaz", "https://www.linkedin.com/in/muhammad-fiaz-", "https://x.com/muhammadfiaz_"],
  };
}

function publisherSchema(): Record<string, unknown> {
  return {
    "@type": "Organization",
    name: SITE_NAME,
    url: SITE_URL,
    logo: { "@type": "ImageObject", url: `${SITE_URL}/logo.png` },
  };
}

export function schemaForPage(page: PageInfo): Record<string, unknown> {
  const normalized = page.relativePath.replace(/\.md$/, "").replace(/(^|\/)index$/, "$1").replace(/\/$/, "");
  const canonical = normalized.length > 0 ? `${SITE_URL}/${normalized}` : SITE_URL;
  const isHome = page.relativePath === "index.md";
  const lastUpdated = page.lastUpdated ? new Date(page.lastUpdated).toISOString() : new Date().toISOString();
  const graph: unknown[] = [];

  if (isHome) {
    graph.push({
      "@type": "WebSite",
      name: SITE_NAME,
      url: SITE_URL,
      description: SITE_DESCRIPTION,
      author: { "@type": "Person", name: AUTHOR_NAME, url: AUTHOR_URL },
    });
  }

  const primary: Record<string, unknown> = {
    "@type": page.isFaq ? "FAQPage" : isHome ? "SoftwareApplication" : "TechArticle",
    name: isHome ? SITE_NAME : page.title,
    description: page.description,
    url: canonical,
    image: `${SITE_URL}/logo.png`,
    author: authorSchema(),
    publisher: publisherSchema(),
  };

  if (isHome) {
    Object.assign(primary, {
      applicationCategory: "DeveloperApplication",
      operatingSystem: "Cross-platform",
      programmingLanguage: "Zig",
      offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
      downloadUrl: REPO_URL,
      softwareVersion: SITE_VERSION,
      license: "https://opensource.org/licenses/MIT",
    });
  } else if (!page.isFaq) {
    const section = page.relativePath.includes("/")
      ? page.relativePath.split("/")[0].charAt(0).toUpperCase() + page.relativePath.split("/")[0].slice(1)
      : "Documentation";
    Object.assign(primary, {
      headline: page.title,
      articleSection: section,
      mainEntityOfPage: { "@type": "WebPage", "@id": canonical },
      datePublished: "2026-09-07T00:00:00Z",
      dateModified: lastUpdated,
    });
  }

  graph.push(primary);
  graph.push(breadcrumbJsonLd(SITE_URL, page.relativePath));
  return { "@context": "https://schema.org", "@graph": graph };
}
