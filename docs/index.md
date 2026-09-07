---
layout: home
title: tree-sitter.zig
description: A native Zig implementation of the Tree-sitter parsing runtime with incremental parsing, structural queries, and error recovery.
head:
  - - meta
    - property: og:title
      content: tree-sitter.zig
---

# tree-sitter.zig

A native Zig implementation of the Tree-sitter parsing runtime.

Fast, incremental, dependency-free parsing for Zig 0.16.0 — no C code, no Rust, no `@cImport`. Just Zig and its standard library.

<VersionBadge />

<div class="vp-doc" style="display:flex;gap:0.6rem;flex-wrap:wrap;margin:1.4rem 0">
  <a class="vp-button medium brand" href="/tree-sitter.zig/guide/getting-started.html">Get Started</a>
  <a class="vp-button medium alt" href="/tree-sitter.zig/examples/">Examples</a>
  <a class="vp-button medium alt" href="/tree-sitter.zig/api/">API Reference</a>
  <a class="vp-button medium alt" href="https://github.com/muhammad-fiaz/tree-sitter.zig">GitHub</a>
</div>

## What is tree-sitter.zig?

Tree-sitter is a parsing strategy built for developer tools: instead of parsing a file once and throwing the result away, it keeps a **concrete syntax tree** alive, updates it cheaply on every keystroke, and lets tools ask structural questions about code.

`tree-sitter.zig` implements that runtime natively in Zig:

```zig
const treesitter = @import("treesitter");

var parser = treesitter.Parser.init(allocator);
defer parser.deinit();
try parser.setLanguage(my_language);

var tree = try parser.parseString("1 + 2 * 3");
defer tree.deinit();

const root = tree.rootNode(); // lightweight handle, no allocation
```

## Features

<FeatureGrid :features="[
  { title: 'LR parsing engine', description: 'Table-driven shift / reduce / accept with lookahead, implemented from scratch in Zig.', link: '/concepts/parser' },
  { title: 'Incremental parsing', description: 'Pass an old tree plus an edit; unaffected subtrees are reused, not re-parsed.', link: '/guide/incremental-parsing' },
  { title: 'Structural queries', description: 'S-expression patterns with captures, fields, quantifiers, and predicates.', link: '/guide/queries' },
  { title: 'Error recovery', description: 'Malformed input yields ERROR and MISSING nodes instead of failures.', link: '/guide/error-recovery' },
  { title: 'Explicit allocators', description: 'Pass an allocator once to Parser.init; everything else inherits it.', link: '/guide/allocators' },
  { title: 'Dependency-free', description: 'Zig 0.16.0 standard library only. No C runtime, no Rust.', link: '/compatibility/zig' },
]" />

## Quick Start

```zig
var parser = treesitter.Parser.init(allocator);
defer parser.deinit();
try parser.setLanguage(my_language);

var tree = try parser.parseString("a + b");
defer tree.deinit();

var query = try parser.compileQuery("(identifier) @id");
defer query.deinit();

var qcursor = parser.queryCursor();
defer qcursor.deinit();
try qcursor.execute(my_language, query.patterns(), query.nodes(), query.captureNames(), &tree);
while (qcursor.nextMatch()) |m| {
    for (m.captures) |cap| std.debug.print("@{s}: {s}\n", .{ cap.name, cap.node.text() });
}
```

Read the [Getting Started](/guide/getting-started) guide, browse [runnable examples](/examples/), or jump to the [API reference](/api/).

## Architecture

```text
                    tree-sitter.zig
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
      Parser             Tree              Query
        │                  │                  │
   ┌────┼────┐       ┌─────┼─────┐       ┌────┼────┐
   │    │    │       │     │     │       │    │    │
 Lexer Stack Actions Node Cursor Edit  Pattern Capture Matcher
   │
 Input
   │
 Unicode
   │
 Language
```

See [Architecture](/concepts/architecture) for the full picture.

## Core Concepts

- [Parser](/concepts/parser) — turns source text into a syntax tree.
- [Nodes](/concepts/nodes) — lightweight handles into the tree.
- [Cursors](/concepts/cursors) — allocation-free tree traversal.
- [Incremental parsing](/concepts/incremental-parsing) — reparse only what changed.
- [Queries](/concepts/queries) — structural search with captures.

## Use Cases

From [syntax highlighting](/use-cases/syntax-highlighting) to [editor integration](/use-cases/code-editor) and [static analysis](/use-cases/static-analysis) — if your tool reads code structurally, start with the [use cases](/use-cases/).

## Performance

On an ~80KB expression corpus (100,000 nodes, ReleaseFast): initial parse ~10 ms, worst-case incremental edit ~4–16 ms with ~40,000 reused subtrees, traversal ~1 ms, 20,000 query matches in ~4 ms. Details and reproduction steps: [Performance](/guide/performance).

## Compatibility

Windows, Linux, and macOS across x86, x86_64, and ARM64 — validated with Zig 0.16.0. See the [compatibility matrix](/compatibility/feature-matrix).

## GitHub & Community

- Repository: [muhammad-fiaz/tree-sitter.zig](https://github.com/muhammad-fiaz/tree-sitter.zig)
- Issues and feature requests welcome.
- If this project helps you, please star it.
