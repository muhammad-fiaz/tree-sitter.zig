import { defineConfig } from "vitepress";
import llmstxt from "vitepress-plugin-llms";
import {
  SITE_URL,
  SITE_NAME,
  SITE_DESCRIPTION,
  SITE_VERSION,
  KEYWORDS,
  AUTHOR_NAME,
  GA_ID,
  GTM_ID,
  ADSENSE_CLIENT_ID,
  REPO_URL,
} from "./seo/metadata";
import { schemaForPage } from "./seo/schema";
import { gtmSnippet, gtmNoscript } from "./analytics/google-tag-manager";
import { ADSENSE_SRC } from "./analytics/adsense";

export { SITE_URL, SITE_NAME, SITE_DESCRIPTION, GA_ID, GTM_ID, ADSENSE_CLIENT_ID };

export default defineConfig({
  lang: "en-US",
  title: SITE_NAME,
  description: SITE_DESCRIPTION,
  base: "/tree-sitter.zig/",
  lastUpdated: true,
  cleanUrls: false,

  sitemap: {
    hostname: new URL(SITE_URL).origin,
    transformItems: (items) => {
      const base = new URL(SITE_URL).pathname.replace(/\/$/, "");
      return items
        .filter((item) => item.url.endsWith("/") || item.url.endsWith(".html"))
        .map((item) => {
          const path = item.url === "/" ? "" : item.url.startsWith("/") ? item.url : `/${item.url}`;
          return { ...item, url: `${base}${path}` };
        });
    },
  },

  vite: {
    plugins: [llmstxt()],
  },

  head: [
    ["meta", { name: "title", content: SITE_NAME }],
    ["meta", { name: "description", content: SITE_DESCRIPTION }],
    ["meta", { name: "keywords", content: KEYWORDS }],
    ["meta", { name: "author", content: AUTHOR_NAME }],
    ["meta", { name: "robots", content: "index, follow" }],
    ["meta", { name: "language", content: "English" }],
    ["meta", { name: "revisit-after", content: "7 days" }],
    ["meta", { name: "generator", content: "VitePress" }],

    ["meta", { property: "og:type", content: "website" }],
    ["meta", { property: "og:url", content: SITE_URL }],
    ["meta", { property: "og:title", content: SITE_NAME }],
    ["meta", { property: "og:description", content: SITE_DESCRIPTION }],
    ["meta", { property: "og:image", content: `${SITE_URL}/logo.png` }],
    ["meta", { property: "og:image:alt", content: "tree-sitter.zig - Native Zig Tree-sitter Runtime" }],
    ["meta", { property: "og:site_name", content: SITE_NAME }],
    ["meta", { property: "og:locale", content: "en_US" }],

    ["meta", { name: "twitter:card", content: "summary" }],
    ["meta", { name: "twitter:url", content: SITE_URL }],
    ["meta", { name: "twitter:title", content: SITE_NAME }],
    ["meta", { name: "twitter:description", content: SITE_DESCRIPTION }],
    ["meta", { name: "twitter:image", content: `${SITE_URL}/logo.png` }],
    ["meta", { name: "twitter:image:alt", content: "tree-sitter.zig - Native Zig Tree-sitter Runtime" }],
    ["meta", { name: "twitter:site", content: "@muhammadfiaz_" }],
    ["meta", { name: "twitter:creator", content: "@muhammadfiaz_" }],

    ["link", { rel: "canonical", href: SITE_URL }],
    ["link", { rel: "icon", type: "image/svg+xml", href: "/tree-sitter.zig/favicon.svg" }],
    ["link", { rel: "apple-touch-icon", href: "/tree-sitter.zig/logo.png" }],
    ["link", { rel: "manifest", href: "/tree-sitter.zig/manifest.webmanifest" }],

    ["meta", { name: "theme-color", content: "#2f7d4f" }],
    ["meta", { name: "msapplication-TileColor", content: "#2f7d4f" }],

    ["script", { async: "", src: `https://www.googletagmanager.com/gtag/js?id=${GA_ID}` }],
    [
      "script",
      {},
      `window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('js', new Date());
gtag('config', '${GA_ID}');`,
    ],

    ...(GTM_ID
      ? ([
          ["script", {}, gtmSnippet(GTM_ID)],
          ["noscript", {}, gtmNoscript(GTM_ID)],
        ] as [string, Record<string, string>, string][])
      : []),

    ["script", { async: "", src: ADSENSE_SRC, crossorigin: "anonymous" }],
  ],

  ignoreDeadLinks: [/.*\.zig$/],

  transformPageData(pageData: any) {
    const pageTitle: string = pageData.title || SITE_NAME;
    const pageDescription: string = pageData.frontmatter.description || SITE_DESCRIPTION;
    const isIndexPage = /(^|\/)index\.md$/.test(pageData.relativePath);
    const normalizedPath: string = pageData.relativePath
      .replace(/\.md$/, "")
      .replace(/(^|\/)index$/, "$1")
      .replace(/\/$/, "");
    const canonicalUrl =
      normalizedPath.length > 0
        ? isIndexPage
          ? `${SITE_URL}/${normalizedPath}/`
          : `${SITE_URL}/${normalizedPath}.html`
        : SITE_URL;

    pageData.frontmatter.head ??= [];
    pageData.frontmatter.head.push(
      ["link", { rel: "canonical", href: canonicalUrl }],
      ["meta", { property: "og:title", content: `${pageTitle} | ${SITE_NAME}` }],
      ["meta", { property: "og:url", content: canonicalUrl }],
    );

    if (pageData.frontmatter.description) {
      pageData.frontmatter.head.push(
        ["meta", { property: "og:description", content: pageData.frontmatter.description }],
        ["meta", { name: "description", content: pageData.frontmatter.description }],
      );
    }

    const isFaq = pageData.relativePath.startsWith("faq/");
    pageData.frontmatter.head.push([
      "script",
      { type: "application/ld+json" },
      JSON.stringify(
        schemaForPage({
          title: pageTitle,
          description: pageDescription,
          relativePath: pageData.relativePath,
          lastUpdated: pageData.lastUpdated,
          isFaq,
        }),
      ),
    ]);
  },

  themeConfig: {
    logo: "/logo.png",
    siteTitle: SITE_NAME,

    nav: [
      { text: "Home", link: "/" },
      { text: "Guide", link: "/guide/getting-started" },
      { text: "Concepts", link: "/concepts/" },
      { text: "Examples", link: "/examples/" },
      { text: "API", link: "/api/" },
      { text: "FAQ", link: "/faq/" },
      {
        text: "Support",
        items: [
          { text: "💖 Sponsor", link: "https://github.com/sponsors/muhammad-fiaz" },
          { text: "📦 Releases", link: `${REPO_URL}/releases` },
        ],
      },
      { text: "GitHub", link: REPO_URL },
    ],

    sidebar: [
      {
        text: "Guide",
        items: [
          { text: "Overview", link: "/guide/" },
          { text: "Getting Started", link: "/guide/getting-started" },
          { text: "Installation", link: "/guide/installation" },
          { text: "Project Setup", link: "/guide/project-setup" },
          { text: "Your First Parser", link: "/guide/first-parser" },
          { text: "Parsing Source", link: "/guide/parsing-source" },
          { text: "Understanding Trees", link: "/guide/understanding-trees" },
          { text: "Navigating Nodes", link: "/guide/navigating-nodes" },
          { text: "Tree Cursors", link: "/guide/tree-cursors" },
          { text: "Incremental Parsing", link: "/guide/incremental-parsing" },
          { text: "Editing Trees", link: "/guide/editing-trees" },
          { text: "Changed Ranges", link: "/guide/changed-ranges" },
          { text: "Error Recovery", link: "/guide/error-recovery" },
          { text: "Custom Input", link: "/guide/custom-input" },
          { text: "Included Ranges", link: "/guide/included-ranges" },
          { text: "Unicode & Positions", link: "/guide/unicode-and-positions" },
          { text: "Language Definition", link: "/guide/language-definition" },
          { text: "External Scanners", link: "/guide/external-scanners" },
          { text: "Queries", link: "/guide/queries" },
          { text: "Query Captures", link: "/guide/query-captures" },
          { text: "Query Predicates", link: "/guide/query-predicates" },
          { text: "Query Quantifiers", link: "/guide/query-quantifiers" },
          { text: "Query Cursors", link: "/guide/query-cursors" },
          { text: "Logging", link: "/guide/logging" },
          { text: "Memory Management", link: "/guide/memory-management" },
          { text: "Allocators", link: "/guide/allocators" },
          { text: "Parser Reuse", link: "/guide/parser-reuse" },
          { text: "Tree Reuse", link: "/guide/tree-reuse" },
          { text: "Performance", link: "/guide/performance" },
          { text: "Testing", link: "/guide/testing" },
          { text: "Troubleshooting", link: "/guide/troubleshooting" },
        ],
      },
      {
        text: "Concepts",
        items: [
          { text: "Overview", link: "/concepts/" },
          { text: "Architecture", link: "/concepts/architecture" },
          { text: "Parser", link: "/concepts/parser" },
          { text: "Lexer", link: "/concepts/lexer" },
          { text: "Parser Stack", link: "/concepts/parser-stack" },
          { text: "Parse Actions", link: "/concepts/parse-actions" },
          { text: "Reductions", link: "/concepts/reductions" },
          { text: "Error Recovery", link: "/concepts/error-recovery" },
          { text: "Grammar & Language", link: "/concepts/grammar-language" },
          { text: "Language Tables", link: "/concepts/language-tables" },
          { text: "Symbols", link: "/concepts/symbols" },
          { text: "Fields", link: "/concepts/fields" },
          { text: "Aliases", link: "/concepts/aliases" },
          { text: "Subtrees", link: "/concepts/subtrees" },
          { text: "Tree Structure", link: "/concepts/tree-structure" },
          { text: "Nodes", link: "/concepts/nodes" },
          { text: "Cursors", link: "/concepts/cursors" },
          { text: "Incremental Parsing", link: "/concepts/incremental-parsing" },
          { text: "Changed Ranges", link: "/concepts/changed-ranges" },
          { text: "Queries", link: "/concepts/queries" },
          { text: "Unicode", link: "/concepts/unicode" },
          { text: "External Scanners", link: "/concepts/external-scanners" },
          { text: "Memory Model", link: "/concepts/memory-model" },
        ],
      },
      {
        text: "Examples",
        items: [
          { text: "Overview", link: "/examples/" },
          { text: "Basics", link: "/examples/basics" },
          { text: "Trees", link: "/examples/trees" },
          { text: "Incremental", link: "/examples/incremental" },
          { text: "Input", link: "/examples/input" },
          { text: "Languages", link: "/examples/languages" },
          { text: "Queries", link: "/examples/queries" },
          { text: "Unicode", link: "/examples/unicode" },
          { text: "Debugging", link: "/examples/debugging" },
          { text: "Applications", link: "/examples/applications" },
        ],
      },
      {
        text: "Use Cases",
        items: [
          { text: "Overview", link: "/use-cases/" },
          { text: "Syntax Highlighting", link: "/use-cases/syntax-highlighting" },
          { text: "Code Editor", link: "/use-cases/code-editor" },
          { text: "IDE Language Tools", link: "/use-cases/ide-language-tools" },
          { text: "Source Code Analysis", link: "/use-cases/source-code-analysis" },
          { text: "Code Navigation", link: "/use-cases/code-navigation" },
          { text: "Refactoring Tools", link: "/use-cases/refactoring-tools" },
          { text: "Static Analysis", link: "/use-cases/static-analysis" },
          { text: "Source Indexing", link: "/use-cases/source-indexing" },
          { text: "Dependency Analysis", link: "/use-cases/dependency-analysis" },
          { text: "Structural Search", link: "/use-cases/structural-search" },
          { text: "Formatter", link: "/use-cases/formatter" },
          { text: "Linter", link: "/use-cases/linter" },
          { text: "Code Transformation", link: "/use-cases/code-transformation" },
          { text: "Documentation Generation", link: "/use-cases/documentation-generation" },
          { text: "Configuration Parser", link: "/use-cases/configuration-parser" },
        ],
      },
      {
        text: "API Reference",
        items: [
          { text: "Overview", link: "/api/" },
          { text: "Parser", link: "/api/parser" },
          { text: "Tree", link: "/api/tree" },
          { text: "Node", link: "/api/node" },
          { text: "Tree Cursor", link: "/api/tree-cursor" },
          { text: "Language", link: "/api/language" },
          { text: "Query", link: "/api/query" },
          { text: "Query Cursor", link: "/api/query-cursor" },
          { text: "Input", link: "/api/input" },
          { text: "InputEdit", link: "/api/input-edit" },
          { text: "Point", link: "/api/point" },
          { text: "Range", link: "/api/range" },
          { text: "Changed Ranges", link: "/api/changed-ranges" },
          { text: "Symbols", link: "/api/symbols" },
          { text: "Fields", link: "/api/fields" },
          { text: "Errors", link: "/api/errors" },
          { text: "Logging", link: "/api/logging" },
          { text: "Allocator", link: "/api/allocator" },
        ],
      },
      {
        text: "Reference",
        items: [
          { text: "Overview", link: "/reference/" },
          { text: "Ownership", link: "/reference/ownership" },
          { text: "Allocator Model", link: "/reference/allocator-model" },
          { text: "Input & I/O", link: "/reference/input-io" },
          { text: "Positions", link: "/reference/positions" },
        ],
      },
      {
        text: "Internals",
        items: [
          { text: "Overview", link: "/internals/" },
          { text: "Parser Runtime", link: "/internals/parser-runtime" },
          { text: "Lexer Runtime", link: "/internals/lexer-runtime" },
          { text: "Stack Runtime", link: "/internals/stack-runtime" },
          { text: "Subtree Runtime", link: "/internals/subtree-runtime" },
          { text: "Tree Runtime", link: "/internals/tree-runtime" },
          { text: "Query Runtime", link: "/internals/query-runtime" },
          { text: "Incremental Runtime", link: "/internals/incremental-runtime" },
          { text: "Memory Runtime", link: "/internals/memory-runtime" },
          { text: "Upstream Conformance", link: "/internals/upstream-conformance" },
        ],
      },
      {
        text: "Development",
        items: [
          { text: "Overview", link: "/development/" },
          { text: "Architecture", link: "/development/architecture" },
          { text: "Source Layout", link: "/development/source-layout" },
          { text: "Zig 0.16 Notes", link: "/development/zig-0.16" },
          { text: "Testing", link: "/development/testing" },
          { text: "Fuzzing", link: "/development/fuzzing" },
          { text: "Benchmarks", link: "/development/benchmarks" },
          { text: "Conformance", link: "/development/conformance" },
          { text: "Debugging", link: "/development/debugging" },
          { text: "Contributing", link: "/development/contributing" },
        ],
      },
      {
        text: "Compatibility",
        items: [
          { text: "Overview", link: "/compatibility/" },
          { text: "Zig", link: "/compatibility/zig" },
          { text: "Windows", link: "/compatibility/windows" },
          { text: "Linux", link: "/compatibility/linux" },
          { text: "macOS", link: "/compatibility/macos" },
          { text: "x86-64", link: "/compatibility/x86-64" },
          { text: "ARM64", link: "/compatibility/arm64" },
          { text: "WebAssembly", link: "/compatibility/wasm" },
          { text: "Feature Matrix", link: "/compatibility/feature-matrix" },
        ],
      },
      {
        text: "FAQ",
        items: [
          { text: "Overview", link: "/faq/" },
          { text: "General", link: "/faq/general" },
          { text: "Parsing", link: "/faq/parsing" },
          { text: "Incremental", link: "/faq/incremental" },
          { text: "Queries", link: "/faq/queries" },
          { text: "Languages", link: "/faq/languages" },
          { text: "Memory", link: "/faq/memory" },
          { text: "Performance", link: "/faq/performance" },
        ],
      },
      {
        text: "Project",
        items: [
          { text: "License", link: `${REPO_URL}/blob/main/LICENSE` },
        ],
      },
    ],

    socialLinks: [{ icon: "github", link: REPO_URL }],

    footer: {
      message: "Released under the MIT License.",
      copyright: `Copyright © 2026 Muhammad Fiaz · v${SITE_VERSION}`,
    },

    search: { provider: "local" },

    editLink: {
      pattern: `${REPO_URL}/edit/main/docs/:path`,
      text: "Edit this page on GitHub",
    },

    lastUpdated: {
      text: "Last updated",
      formatOptions: { dateStyle: "medium", timeStyle: "short" },
    },
  },
});
