---
description: Get started with tree-sitter.zig — install the package, parse your first source, and inspect the tree.
---

# Getting Started

## What you'll learn

- How to add `tree-sitter.zig` to a Zig 0.16.0 project.
- How to create a parser, parse source, and read the resulting tree.
- Where to go next for editing, queries, and embedding.

## When to use this

You are new to the library and want the shortest path to a working parse.

## Prerequisites

- Zig **0.16.0 exactly** (`zig version` must print `0.16.0`).
- A `Language` value describing the grammar to parse. The package ships a bundled expression grammar used by the examples and tests; real integrations plug in their own generated table data (see [Language Definition](/guide/language-definition)).

## Complete example

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expression_language;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const allocator = gpa_state.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseString("1 + 2 * 3");
    defer tree.deinit();

    const root = tree.rootNode();
    std.debug.print("root: {s} [{d}, {d}]\n", .{ root.nodeType(), root.startByte(), root.endByte() });
    std.debug.print("has error: {}\n", .{tree.hasError()});
}
```

## Running the example

```sh
zig build run-basic_parse
```

## Expected output

```text
root: program [0, 9]
has error: false
text: 1 + 2 * 3
```

## How it works

1. `Parser.init(allocator)` — the **only** place you hand over an allocator. Everything created from this parser inherits it.
2. `setLanguage(...)` — loads generic grammar tables and validates the ABI version.
3. `parseString(...)` — runs the LR engine and returns an owning `Tree`. The source is copied into the tree, so the tree outlives your input slice.
4. `rootNode()` — returns a lightweight `Node` handle. Reading its type, bytes, and points allocates nothing.
5. Each `defer ...deinit()` releases exactly what its object owns.

## API used

- [Parser](/api/parser) — `init`, `setLanguage`, `parseString`.
- [Tree](/api/tree) — `rootNode`, `hasError`.
- [Node](/api/node) — `nodeType`, `startByte`, `endByte`, `text`.

## Memory ownership

<MemoryModel />

## Performance considerations

`parseString` performs one source copy plus pooled tree construction. Reuse the same `Parser` for every parse to reuse its internal scratch buffers (see [Parser Reuse](/guide/parser-reuse)).

## Related guides

- [Installation](/guide/installation) for all setup methods.
- [Your First Parser](/guide/first-parser) for the line-by-line version.
- [Understanding Trees](/guide/understanding-trees) for what the result means.
