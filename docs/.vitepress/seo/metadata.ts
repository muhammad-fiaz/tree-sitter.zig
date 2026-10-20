// Central site metadata for tree-sitter.zig documentation.
// Single source of truth imported by config.ts, theme, and SEO helpers.

export const SITE_URL = "https://muhammad-fiaz.github.io/tree-sitter.zig";

// Deployment base path. The site is served from a GitHub Pages project
// subpath, so the base mirrors the path component of SITE_URL. VitePress
// prefixes every internal link and asset with it.
export const SITE_BASE = `${new URL(SITE_URL).pathname.replace(/\/+$/, "")}/`;

// Base URL used as the sitemap hostname. It must include the deployment
// subpath and end in a slash, otherwise VitePress resolves page URLs
// against the domain root and drops the subpath.
export const SITE_HOSTNAME = new URL(SITE_BASE, SITE_URL).href;

export const SITE_NAME = "tree-sitter.zig";
export const SITE_DESCRIPTION =
  "A native Zig implementation of the Tree-sitter parsing runtime with incremental parsing, structural queries, error recovery, and explicit allocator control.";
export const SITE_VERSION = "0.0.2";
export const ZIG_VERSION = "0.17.0";
export const AUTHOR_NAME = "Muhammad Fiaz";
export const AUTHOR_URL = "https://github.com/muhammad-fiaz";
export const REPO_URL = "https://github.com/muhammad-fiaz/tree-sitter.zig";
export const UPSTREAM_URL = "https://github.com/tree-sitter/tree-sitter";

// Google Analytics and Google Tag Manager IDs (single configuration location).
export const GA_ID = "G-6BVYCRK57P";
export const GTM_ID = "GTM-P4M9T8ZR";

// Google AdSense publisher/client ID (single configuration location).
export const ADSENSE_CLIENT_ID = "ca-pub-2040560600290490";

// SEO keywords.
export const KEYWORDS =
  "zig, tree-sitter, parsing, parser, incremental parsing, syntax tree, concrete syntax tree, queries, query predicates, directives, error recovery, lexer, external scanners, json grammar, utf-16, webassembly, wasm, allocator, zig library, code analysis, editor tooling";
