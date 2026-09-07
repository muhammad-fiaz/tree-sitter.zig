<div align="center">
<img src="docs/public/logo.png" alt="tree-sitter.zig logo" width="300" />

# tree-sitter.zig

<a href="https://muhammad-fiaz.github.io/tree-sitter.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.16.0-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/tree-sitter.zig"><img src="https://img.shields.io/github/stars/muhammad-fiaz/tree-sitter.zig" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/tree-sitter.zig/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/tree-sitter.zig" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/tree-sitter.zig/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/tree-sitter.zig" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/tree-sitter.zig"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/tree-sitter.zig" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/tree-sitter.zig"><img src="https://img.shields.io/github/license/muhammad-fiaz/tree-sitter.zig" alt="License"></a>
<a href="https://github.com/muhammad-fiaz/tree-sitter.zig/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/tree-sitter.zig/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/tree-sitter.zig/actions/workflows/release.yml"><img src="https://github.com/muhammad-fiaz/tree-sitter.zig/actions/workflows/release.yml/badge.svg" alt="Release"></a>
<a href="https://github.com/muhammad-fiaz/tree-sitter.zig/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/tree-sitter.zig?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-💖-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://hits.sh/muhammad-fiaz/tree-sitter.zig/"><img src="https://hits.sh/muhammad-fiaz/tree-sitter.zig.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>A fast, native Tree-sitter runtime built in Zig.</em></p>

<b><a href="https://muhammad-fiaz.github.io/tree-sitter.zig/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/tree-sitter.zig/api/">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/tree-sitter.zig/guide/getting-started">Quick Start</a> |
<a href="CONTRIBUTING.md">Contributing</a></b>

</div>

**tree-sitter.zig** is a production-grade, native Zig implementation of the Tree-sitter runtime — a clean, modular, allocator-explicit parsing toolkit for editors, analyzers, and language tooling.

> [!NOTE]
> This is an independent Zig implementation of the Tree-sitter runtime concepts and algorithms. It is not the official Tree-sitter project, and it does not link, wrap, or depend on the upstream C runtime. The upstream implementation was studied as an algorithm and behavior reference during development; no upstream code ships with or is required by this package.

**⭐️ If you love `tree-sitter.zig`, make sure to give it a star! ⭐️**

---

<details>
<summary><strong>Table of Contents</strong> (click to expand)</summary>

- [Prerequisites](#prerequisites)
- [Supported Platforms](#supported-platforms)
- [Installation](#installation)
  - [Method 1: Zig Fetch (Recommended)](#method-1-zig-fetch-recommended)
  - [Method 2: Zig Fetch (Latest / in development)](#method-2-zig-fetch-latest--in-development)
  - [Method 3: Manual build.zig.zon Configuration](#method-3-manual-buildzigzon-configuration)
  - [Method 4: Local Source Checkout](#method-4-local-source-checkout)
  - [Wire into build.zig](#wire-into-buildzig)
  - [Prebuilt Library](#prebuilt-library)
- [Quick Start](#quick-start)
- [Allocator Usage](#allocator-usage)
- [Usage Examples](#usage-examples)
  - [Basic Parsing](#basic-parsing)
  - [Incremental Parsing](#incremental-parsing)
  - [Changed Ranges](#changed-ranges)
  - [Tree Walking](#tree-walking)
  - [Tree Cursor](#tree-cursor)
  - [Queries](#queries)
  - [Predicates](#predicates)
  - [Custom Input](#custom-input)
  - [Reader Input](#reader-input)
  - [Streaming Input](#streaming-input)
  - [Error Recovery](#error-recovery)
  - [Language Metadata](#language-metadata)
  - [Debug Logging](#debug-logging)
- [Configuration](#configuration)
  - [Parser Configuration](#parser-configuration)
- [Node API](#node-api)
- [Cursor API](#cursor-api)
- [Query API](#query-api)
- [Performance \& Benchmarks](#performance--benchmarks)
  - [Benchmark Results](#benchmark-results)
  - [Summary](#summary)
  - [Reproducing the Benchmark Results](#reproducing-the-benchmark-results)
    - [Performance Notes](#performance-notes)
- [Building](#building)
- [Documentation](#documentation)
  - [Online Documentation](#online-documentation)
  - [Generating Local Documentation](#generating-local-documentation)
- [Contributing](#contributing)
- [License](#license)
- [Links](#links)

</details>

----

<details>
<summary><strong>Features of tree-sitter.zig</strong> (click to expand)</summary>

| Feature | Description | Documentation |
|---------|-------------|---------------|
| **Native Zig Runtime** | No C code, no `@cImport`, no Rust — Zig standard library only | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/getting-started) |
| **LR Parsing Engine** | Table-driven shift / reduce / accept with lookahead | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/parsing-source) |
| **Incremental Parsing** | Subtree reuse across edits with reuse counters | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/incremental-parsing) |
| **Changed Ranges** | Minimal byte/point ranges between two trees | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/changed-ranges) |
| **Error Recovery** | `ERROR` and `MISSING` nodes with error-cost recovery | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/error-recovery) |
| **Generic Languages** | Symbols, parse tables, fields, aliases, metadata | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/language-definition) |
| **Bundled Grammars** | Expression, s-expression (aliases), JSON (fields), outline (external scanner) | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/language-definition) |
| **External Scanners** | Zig-native scanner interface with per-state dispatch, no C callbacks | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/external-scanners) |
| **Structural Queries** | Named/anonymous/wildcard patterns, fields, captures | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/queries) |
| **Quantifiers** | `?`, `*`, `+` on pattern nodes | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/query-quantifiers) |
| **Predicates** | `#eq?`, `#match?`, `#contains?`, `#any-of?`, `#is?`, `any-` variants and negations | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/query-predicates) |
| **Directives** | `#set!` settings plus structural `#select-adjacent!`/`#strip!` exposure with apply helpers | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/queries) |
| **Included Ranges** | Lexer-enforced `setIncludedRanges` with validation | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/included-ranges) |
| **Aliases & Supertypes** | Alias substitution on reduce, subtype expansion in queries | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/language-definition) |
| **Tree Cursor** | Allocation-free traversal with field tracking | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/tree-cursors) |
| **UTF-8 Support** | Exact byte offsets with code-point-aware positions | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/unicode-and-positions) |
| **UTF-16 Input** | LE/BE transcode with BOM and surrogate errors | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/unicode-and-positions) |
| **WASM Targets** | `wasm32-wasi` validated; native data needs no WASM loader | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/compatibility/wasm) |
| **Custom Input** | Memory slices, callbacks, `std.Io.Reader` sources, true streaming via `parseStream` | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/custom-input) |
| **Explicit Allocators** | Client-provided allocator, no hidden globals | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/allocators) |
| **Debug Tracing** | Level-gated logging and parse-event tracing | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/guide/logging) |
| **Cross-Platform** | Windows, Linux, macOS on x86, x86_64, and ARM64 | [Docs](https://muhammad-fiaz.github.io/tree-sitter.zig/compatibility/) |

</details>

----

<details>
<summary><strong>Prerequisites & Supported Platforms</strong> (click to expand)</summary>

<br>

## Prerequisites

Before installing tree-sitter.zig, ensure you have the following:

| Requirement | Version | Notes |
|-------------|---------|-------|
| **Zig** | 0.16.0 exactly | Download from [ziglang.org](https://ziglang.org/download/) |
| **Operating System** | Windows 10+, Linux, macOS | Cross-platform support |
| **Terminal** | Any modern terminal | For example output |

> Verify your Zig installation by running `zig version` in your terminal. It must print `0.16.0`.
> - For Zig 0.16.0, use tree-sitter.zig version 0.0.1 (current stable)
> - See Zig releases and downloads at [ziglang.org](https://ziglang.org/)

---

## Supported Platforms

tree-sitter.zig supports a wide range of platforms and architectures:

| Platform | Architectures | Status |
|----------|---------------|--------|
| **Windows** | x86, x86_64, ARM64 | Full support |
| **Linux** | x86, x86_64, ARM64 | Full support |
| **macOS** | x86_64, ARM64 (Apple Silicon) | Full support |

The implementation makes no pointer-width, endianness, or architecture-specific assumptions.

</details>

---

## Installation

### Method 1: Zig Fetch (Recommended)

Latest Stable Release (v0.0.1)

```bash
zig fetch --save https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.1.tar.gz
```

> [!WARNING]
> tree-sitter.zig requires Zig 0.16.0 exactly. New projects should use Zig 0.16.0 with tree-sitter.zig v0.0.1.

### Method 2: Zig Fetch (Latest / in development)

Use this for the latest in-development version from the `main` branch:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/tree-sitter.zig.git
```

### Method 3: Manual build.zig.zon Configuration

```zig
.dependencies = .{
    .treesitter = .{
        .url = "https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.1.tar.gz",
        .hash = "...", // Run `zig fetch --save <url>` to generate the hash.
    },
},
```

### Method 4: Local Source Checkout

```bash
git clone https://github.com/muhammad-fiaz/tree-sitter.zig.git
cd tree-sitter.zig
zig build
```

To use a local checkout from another project:

```zig
.dependencies = .{
    .treesitter = .{
        .path = "../tree-sitter.zig",
    },
},
```

### Wire into build.zig

```zig
const treesitter_dep = b.dependency("treesitter", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("treesitter", treesitter_dep.module("treesitter"));
```

> [!NOTE]
> Zig 0.16 keeps `root_module` on the compile step. You only need it to attach the `treesitter` module when using the package manager.

### Prebuilt Library

> [!NOTE]
> The recommended integration is the Zig Package Manager (Methods 1 and 2). Release archives (`.tar.gz` source snapshots such as `0.0.1.tar.gz`) for every stable version are published on the [Releases](https://github.com/muhammad-fiaz/tree-sitter.zig/releases) page. These can be useful for integration with other build systems or for vendoring.

To vendor manually, download the `0.0.1` archive, extract it, and add its `src/treesitter.zig` as a module in your `build.zig`:

```zig
const treesitter_mod = b.createModule(.{
    .root_source_file = b.path("vendor/tree-sitter.zig-0.0.1/src/treesitter.zig"),
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("treesitter", treesitter_mod);
```

## Quick Start

```zig
const std = @import("std");
const treesitter = @import("treesitter");

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const allocator = gpa_state.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(my_language);

    var tree = try parser.parseString("1 + 2 * 3");
    defer tree.deinit();

    const root = tree.rootNode();
    std.debug.print("root: {s} [{d}, {d}]\n", .{ root.nodeType(), root.startByte(), root.endByte() });
}
```

> [!NOTE]
> `Parser.parseString` copies the source into the tree, so the returned tree owns its text and stays valid after the caller's slice goes away. Trees, parser scratch memory, and query state are all released by their respective `deinit` calls.

## Allocator Usage

tree-sitter.zig works with any `std.mem.Allocator` implementation. You pass your allocator **once** to `Parser.init` — every object derived from the parser or its trees transparently reuses it. There are no hidden global allocators, and ordinary operations never ask for an allocator again:

```zig
var gpa_state = std.heap.DebugAllocator(.{}).init;
defer _ = gpa_state.deinit();

var parser = treesitter.Parser.init(gpa_state.allocator());
defer parser.deinit();

var tree = try parser.parseString("1 + 2");
defer tree.deinit();

var cursor = tree.cursor(); // allocator inherited from the tree
defer cursor.deinit();

var query = try parser.compileQuery("(identifier) @id"); // allocator inherited from the parser
defer query.deinit();

var qcursor = parser.queryCursor(); // allocator inherited from the parser
defer qcursor.deinit();
```

The recommended default in applications is `std.heap.DebugAllocator`. For batch workloads, callers can wrap their allocator with a `std.heap.ArenaAllocator` and pass it to `Parser.init`. The parser retains the allocator and reuses its internal capacity across parses; call `parser.reset()` to drop retained scratch memory. The allocator must outlive every object created from it.

## Usage Examples

### Basic Parsing

```zig
try parser.setLanguage(my_language);
var tree = try parser.parseString("a * (b + 2)");
defer tree.deinit();
const root = tree.rootNode();
// root.nodeType() == "program", root.text() == "a * (b + 2)"
```

### Incremental Parsing

```zig
var old_tree = try parser.parseString("1 + 2");
defer old_tree.deinit();

const edit = treesitter.InputEdit{
    .start_byte = 4,
    .old_end_byte = 5,
    .new_end_byte = 6,
    .start_point = .{ .row = 0, .column = 4 },
    .old_end_point = .{ .row = 0, .column = 5 },
    .new_end_point = .{ .row = 0, .column = 6 },
};
var new_tree = try parser.parse(&old_tree, edit, "1 + 22");
defer new_tree.deinit();
// parser.reused_node_count reports how many old subtrees were spliced in.
```

### Changed Ranges

```zig
const ranges = try old_tree.getChangedRanges(&new_tree);
defer old_tree.freeChangedRanges(ranges);
for (ranges) |r| {
    std.debug.print("changed bytes [{d}, {d}]\n", .{ r.start_byte, r.end_byte });
}
```

You can also shift an existing tree's positions in place before reparsing elsewhere:

```zig
treesitter.applyEdit(&tree, edit);
```

### Tree Walking

```zig
fn printNode(node: treesitter.Node, depth: usize) void {
    for (0..depth) |_| std.debug.print("  ", .{});
    std.debug.print("{s} [{d}, {d}]\n", .{ node.nodeType(), node.startByte(), node.endByte() });
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) printNode(node.child(i).?, depth + 1);
}
```

### Tree Cursor

```zig
var cursor = tree.cursor();
defer cursor.deinit();
if (cursor.gotoFirstChild()) {
    // cursor.currentNode(), cursor.depth(), cursor.currentFieldName()
}
_ = cursor.gotoNextSibling();
_ = cursor.gotoParent();
cursor.gotoDescendant(byte_offset);
```

### Queries

```zig
var query = try parser.compileQuery("(identifier) @var");
defer query.deinit();

var cursor = parser.queryCursor();
defer cursor.deinit();
try cursor.execute(lang, query.patterns(), query.nodes(), query.captureNames(), &tree);
while (cursor.nextMatch()) |m| {
    for (m.captures) |cap| std.debug.print("@{s}: {s}\n", .{ cap.name, cap.node.text() });
}
```

### Predicates

```zig
// Only identifiers whose text is exactly "foo".
"((identifier) @x (#eq? @x \"foo\"))"
// Identifiers starting with "a", via the built-in pattern matcher.
"((identifier) @x (#match? @x \"^a\"))"
// Identifiers containing "err".
"((identifier) @x (#contains? @x \"err\"))"
// Identifiers equal to "foo" or "bar".
"((identifier) @x (#any-of? @x \"foo\" \"bar\"))"
// Only named nodes (also supports anonymous, missing, error, extra, visible).
"((identifier) @x (#is? @x named))"
// Any-node variants: one of several captures may satisfy.
"((expression (_) @x \"+\" (_) @x) (#any-eq? @x \"a\"))"
// Negations (#not-eq?, #not-match?, #not-contains?, #not-any-of?, #is-not?) are supported too.
// Directives attach metadata instead of filtering:
"((identifier) @x (#set! kind \"variable\") (#select-adjacent! @x @x))"
```

### Custom Input

```zig
const State = struct {
    bytes: []const u8,
    fn read(payload: ?*anyopaque, byte_index: u32, position: treesitter.Point, bytes_read: *u32) ?[*]const u8 {
        _ = position;
        const self: *@This() = @ptrCast(@alignCast(payload.?));
        const i: usize = @as(usize, @intCast(byte_index));
        if (i >= self.bytes.len) {
            bytes_read.* = 0;
            return null;
        }
        bytes_read.* = @as(u32, @intCast(self.bytes.len - i));
        return self.bytes.ptr + i;
    }
};
var state = State{ .bytes = "7 * 8" };
const input = treesitter.Input{ .payload = &state, .read = State.read };
var tree = try parser.parseWithInput(null, null, input);
defer tree.deinit();
```

### Reader Input

Anything behind a `std.Io.Reader` (files, sockets, decompressors) can feed the parser through `treesitter.ReaderSource`:

```zig
var reader: std.Io.Reader = ...;
var backing: [4096]u8 = undefined;
var source = treesitter.ReaderSource.init(&reader, &backing);
var tree = try parser.parseWithInput(null, null, source.input());
defer tree.deinit();
```

### Streaming Input

`parseStream` goes further: bytes are pulled from the callback on demand as the lexer advances, without pre-buffering the whole text, and the tree takes ownership of exactly the consumed prefix:

```zig
var tree = try parser.parseStream(null, null, source.input());
defer tree.deinit();
// With a previous tree, the input is buffered once so subtree reuse applies:
var updated = try parser.parseStream(&tree, edit, source.input());
defer updated.deinit();
```

### Error Recovery

Malformed input still produces a tree. Skipped text becomes `ERROR` nodes and absent-but-expected tokens become zero-width `MISSING` nodes:

```zig
var tree = try parser.parseString("1 + * 2");
defer tree.deinit();
// tree.hasError() == true; walk children to find node.isError() / node.isMissing().
```

### Language Metadata

```zig
const lang = my_language;
std.debug.print("{s} abi={d} symbols={d}\n", .{
    lang.metadata.name, lang.metadata.abi_version, lang.symbolCount(),
});
const plus = lang.symbolForName("+", false).?;
const left = lang.fieldIdForName("left").?;
```

### Debug Logging

```zig
var parser = treesitter.Parser.init(allocator);
defer parser.deinit();
parser.setLogger(.{ .level = .debug, .prefix = "my-parser" });
```

Set `.level = .off` (the default) to silence all logging with minimal overhead.

## Configuration

### Parser Configuration

```zig
// Language (required before parsing; validates the ABI version).
try parser.setLanguage(my_language);

// Restrict parsing to byte/point ranges (editor visible regions, injections).
// Ranges must be sorted and non-overlapping; excluded gaps never produce tokens.
try parser.setIncludedRanges(&.{.{ .start_byte = 0, .end_byte = 1024 }});

// Level-gated diagnostics (.off, .err, .warn, .info, .debug, .trace).
parser.setLogger(.{ .level = .info });

// Drop retained scratch capacity between unrelated workloads.
parser.reset();

// Observability: subtrees reused by the last incremental parse.
const reused = parser.reused_node_count;
```

## Node API

| Method | Description |
|--------|-------------|
| `nodeType()` | Symbol name (`"expression"`, `"+"`, `"ERROR"`) |
| `symbol()` | Numeric symbol id |
| `isNamed()` / `isMissing()` / `isExtra()` / `isError()` | Node flags |
| `hasError()` | Subtree contains an error or missing node |
| `startByte()` / `endByte()` | Byte offsets (exact, UTF-8 safe) |
| `startPoint()` / `endPoint()` | Row/column positions |
| `range()` | Combined `Range` value |
| `childCount()` / `namedChildCount()` / `descendantCount()` | Counts, no allocation |
| `child(i)` / `namedChild(i)` | Indexed access, no allocation |
| `parent()` / `nextSibling()` / `prevSibling()` | Navigation, no allocation |
| `nextNamedSibling()` / `prevNamedSibling()` | Named-only navigation |
| `childByFieldName(name)` / `fieldNameForChild(i)` | Field access |
| `text()` | Source slice, no allocation |
| `descendantForByteRange(s, e)` | Smallest node in a range |
| `eql(other)` | Handle equality |

## Cursor API

| Method | Description |
|--------|-------------|
| `currentNode()` | Node under the cursor |
| `depth()` | Depth below the start node |
| `currentFieldName()` / `currentFieldId()` | Field of the current child |
| `gotoFirstChild()` / `gotoLastChild()` | Descend, no allocation |
| `gotoParent()` | Ascend, no allocation |
| `gotoNextSibling()` / `gotoPreviousSibling()` | Move sideways, no allocation |
| `gotoDescendant(byte)` | Deepest node containing a byte |
| `reset(node)` / `copy()` | Reuse and snapshot cursors |

## Query API

| Item | Description |
|------|-------------|
| `parser.compileQuery(src)` | Compile once, execute repeatedly (inherits parser allocator) |
| `Query.compile(gpa, lang, src)` | Standalone compile with an explicit allocator |
| `query.patternCount()` / `query.captureCount()` | Introspection |
| `query.captureName(i)` / `query.captureIndexForName(n)` | Capture lookup |
| `QueryCursor.execute(...)` | Collect matches for a tree |
| `cursor.nextMatch()` / `cursor.matchCount()` | Iterate results |
| `cursor.setByteRange(s, e)` / `setPointRange()` | Restrict matching |
| `cursor.setMatchLimit(n)` | Cap result count |
| `cursor.reset()` / `resetAll()` | Reuse the cursor |

## Performance & Benchmarks

tree-sitter.zig is designed for every-keystroke parsing: pooled tree storage, reusable parser scratch memory, O(n) candidate collection for incremental reuse, and allocation-free node/cursor access. Below are benchmark results from running `zig build bench` on an ~80KB expression corpus (20,000 operands, 100,000 tree nodes).

### Benchmark Results

<details>
<summary><strong>ReleaseFast (Windows x86_64)</strong></summary>

| Benchmark | Time (lower is better) | Notes |
|-----------|------------------------|-------|
| Initial parse | ~10 ms | 100,000 nodes from scratch |
| Repeated parse | ~10 ms | Reused parser, fresh tree |
| Small-edit incremental | ~4–16 ms | Leading-edge edit, ~40,000 subtrees reused |
| Tree traversal | ~1–2 ms | 100,000 nodes visited |
| Query execution | ~4–5 ms | 20,000 `(identifier)` matches |

</details>

<details>
<summary><strong>Debug (Windows x86_64)</strong></summary>

| Benchmark | Time (lower is better) | Notes |
|-----------|------------------------|-------|
| Initial parse | ~87 ms | 100,000 nodes from scratch |
| Repeated parse | ~86 ms | Reused parser, fresh tree |
| Small-edit incremental | ~94 ms | Leading-edge edit, ~40,000 subtrees reused |
| Tree traversal | ~9 ms | 100,000 nodes visited |
| Query execution | ~95 ms | 20,000 `(identifier)` matches |

</details>

### Summary

| Metric | Value |
|--------|-------|
| **Corpus** | ~80KB source, 20,000 operands, 100,000 nodes, 20,000 query matches |
| **ReleaseFast parse throughput** | ~8 MB/s |
| **Incremental reuse (leading-edge edit)** | ~40,000 subtrees spliced without re-lexing |
| **Traversal** | ~1 ms per 100,000 nodes (ReleaseFast) |

> [!NOTE]
> Benchmark results may vary based on operating system, environment, Zig version, hardware specifications, and software configurations.

### Reproducing the Benchmark Results

To reproduce the benchmark table above locally, run the benchmark executable included with the repository. The benchmark implementation is at [benchmarks/parse_bench.zig](benchmarks/parse_bench.zig) and is licensed under the repository's `LICENSE` (MIT) in the project root.

Run the benchmark with the following command (Windows and POSIX both supported):

```bash
# Build and run the benchmark (Debug by default)
zig build bench

# ReleaseFast numbers (recommended for comparison):
zig build bench -Doptimize=ReleaseFast
```

> [!NOTE]
> The benchmark measures initial parse, repeated parse, a worst-case leading-edge incremental edit (with the `reused_node_count` printed), full tree traversal, and query execution over a generated 20,000-operand expression corpus. Timing uses the Zig 0.16.0 `std.Io` monotonic clock, so no external dependencies are needed.
> Results will vary by OS, Zig version, hardware, and environment.
> For each latest release, benchmark numbers can be found on each [releases page](https://github.com/muhammad-fiaz/tree-sitter.zig/releases).

#### Performance Notes

> [!NOTE]
> - **Reuse counters** - After `parser.parse(&old_tree, edit, src)`, `parser.reused_node_count` tells how many old subtrees were spliced in.
> - **Leading-edge edits** shift every byte offset and are the worst case for reuse; trailing edits reuse large subtrees in single clones.
> - **DebugAllocator overhead** - Benchmarks and tests use `std.heap.DebugAllocator`, which adds per-allocation bookkeeping. Production embeds should measure with their own allocator.
> - **Zero-copy core** - Parsing a `[]const u8` never touches the filesystem; callback and `std.Io.Reader` inputs only copy when buffering chunks.
> - All benchmarks use the bundled expression grammar; per-language tables change absolute numbers but not the architecture.

## Building

```bash
# Run the full test suite (all tests live inline in src/, plus the conformance corpus)
zig build test

# Differential conformance report (parse/shape/incremental corpus in src/debug/corpus)
zig build conformance

# Fuzz the parser and query compiler (options: --iterations=N --seed=N after --)
zig build fuzz

# Build all examples
zig build examples

# Run an example
./zig-out/bin/basic_parse       # POSIX
.\zig-out\bin\basic_parse.exe # Windows PowerShell

# Run the benchmark (add -Doptimize=ReleaseFast for fast numbers)
zig build bench
```

Individual examples:

```bash
zig build examples
./zig-out/bin/basic_parse
./zig-out/bin/incremental_parse
./zig-out/bin/tree_walk
./zig-out/bin/tree_cursor
./zig-out/bin/query
./zig-out/bin/custom_input
./zig-out/bin/error_recovery
./zig-out/bin/language
```

## Documentation

### Online Documentation
Full documentation is available at: https://muhammad-fiaz.github.io/tree-sitter.zig

### Generating Local Documentation
The public API entry point is `src/treesitter.zig` — start there and follow the subsystem facades (`core`, `memory`, `parser`, `lexer`, `tree`, `language`, `query`, `input`, `unicode`, `debug`, `utils`). Each subsystem directory documents its ownership and lifetime rules in its facade module.

To generate `zig docs` HTML locally:

```bash
zig build docs
```

This will generate HTML documentation in the `zig-out/docs/` directory. Open `zig-out/docs/index.html` in your browser to view the documentation.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- **Documentation**: https://muhammad-fiaz.github.io/tree-sitter.zig
- **Repository**: https://github.com/muhammad-fiaz/tree-sitter.zig
- **Issues**: https://github.com/muhammad-fiaz/tree-sitter.zig/issues
- **Upstream Tree-sitter**: https://github.com/tree-sitter/tree-sitter (algorithm and behavior reference only)
