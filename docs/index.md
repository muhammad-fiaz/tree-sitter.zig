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

Fast, incremental, dependency-free parsing for Zig 0.17.0 - no C code, no Rust, no `@cImport`. Just Zig and its standard library.

<div class="vp-doc" style="display:flex;gap:0.6rem;flex-wrap:wrap;margin:1.4rem 0">
  <a class="vp-button medium brand" href="/tree-sitter.zig/guide/getting-started.html">Get Started</a>
  <a class="vp-button medium alt" href="/tree-sitter.zig/examples/">Examples</a>
  <a class="vp-button medium alt" href="/tree-sitter.zig/api/">API Reference</a>
  <a class="vp-button medium alt" href="https://github.com/muhammad-fiaz/tree-sitter.zig">GitHub</a>
</div>

## What is tree-sitter.zig?

Tree-sitter is a parsing strategy built for developer tools: instead of parsing a file once and throwing the result away, it keeps a **concrete syntax tree** alive, updates it cheaply on every keystroke, and lets tools ask structural questions about code.

`tree-sitter.zig` implements that runtime natively in Zig:

> [!IMPORTANT]
> **No C Compatibility Notice**:
> This project does **NOT** maintain backward compatibility with the original C version of Tree-sitter. It is an independent, 100% native Zig implementation that uses its own Zig-based configurations, native parse tables (`parser.zig`), native external scanners (`scanner.zig`), and grammar metadata (`grammar.json`, `node-types.json`) for all supported grammars.

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
  { title: 'Dependency-free', description: 'Zig 0.17.0 standard library only. No C runtime, no Rust.', link: '/compatibility/zig' },
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

- [Parser](/concepts/parser) - turns source text into a syntax tree.
- [Nodes](/concepts/nodes) - lightweight handles into the tree.
- [Cursors](/concepts/cursors) - allocation-free tree traversal.
- [Incremental parsing](/concepts/incremental-parsing) - reparse only what changed.
- [Queries](/concepts/queries) - structural search with captures.

## Use Cases

From [syntax highlighting](/use-cases/syntax-highlighting) to [editor integration](/use-cases/code-editor) and [static analysis](/use-cases/static-analysis) - if your tool reads code structurally, start with the [use cases](/use-cases/).

## Performance

On an ~80KB expression corpus (100,000 nodes, ReleaseFast): initial parse ~10 ms, worst-case incremental edit ~4-16 ms with ~40,000 reused subtrees, traversal ~1 ms, 20,000 query matches in ~4 ms. Details and reproduction steps: [Performance](/guide/performance).

## Compatibility

Windows, Linux, and macOS across x86, x86_64, and ARM64 - validated with Zig 0.17.0. See the [compatibility matrix](/compatibility/feature-matrix).

## Related Zig projects

- For env.zig (.env parsing), check out [env.zig](https://github.com/muhammad-fiaz/env.zig).
- For TUI support, check out [tui.zig](https://github.com/muhammad-fiaz/tui.zig).
- For ZON file format support, check out [zon.zig](https://github.com/muhammad-fiaz/zon.zig).
- For spinners/loading/progress bar support, check out [loaders.zig](https://github.com/muhammad-fiaz/loaders.zig).
- For MCP support, check out [mcp.zig](https://github.com/muhammad-fiaz/mcp.zig).
- For args parsing support, check out [args.zig](https://github.com/muhammad-fiaz/args.zig).
- For HTTP client/server support, check out [httpx.zig](https://github.com/muhammad-fiaz/httpx.zig).
- For API framework support, check out [api.zig](https://github.com/muhammad-fiaz/api.zig).
- For web framework support, check out [zix](https://github.com/muhammad-fiaz/zix).
- For archive/compression support, check out [archive.zig](https://github.com/muhammad-fiaz/archive.zig).
- For compression file format support, check out [zigx](https://github.com/muhammad-fiaz/zigx).
- For file downloading support, check out [downloader.zig](https://github.com/muhammad-fiaz/downloader.zig).
- For update checker/auto-updater support, check out [updater.zig](https://github.com/muhammad-fiaz/updater.zig).
- For numerical computing support, check out [num.zig](https://github.com/muhammad-fiaz/num.zig).
- For logging support, check out [logly.zig](https://github.com/muhammad-fiaz/logly.zig).
- For data validation and serialization support, check out [zigantic](https://github.com/muhammad-fiaz/zigantic).
- For build tooling support, check out [buildx.zig](https://github.com/muhammad-fiaz/buildx.zig).
- For CUDA/GPU computing support, check out [cuda.zig](https://github.com/muhammad-fiaz/cuda.zig).
- For Sqlite support, check out [sqlite.zig](https://github.com/muhammad-fiaz/sqlite.zig).
- For Simplified Build.zig support, check out [build.zig](https://github.com/muhammad-fiaz/buildx.zig).

## GitHub & Community

- Repository: [muhammad-fiaz/tree-sitter.zig](https://github.com/muhammad-fiaz/tree-sitter.zig)
- Issues and feature requests welcome.
- If this project helps you, please star it.

## Acknowledgement

> [!NOTE]
> This project is an independent implementation developed from scratch and written natively in pure Zig. The original Tree-sitter project was used as the reference for algorithms, behavior, architecture, and feature compatibility.
>
> Reference: https://github.com/tree-sitter/tree-sitter

