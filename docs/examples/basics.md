---
description: Basic examples — parse source, inspect the root, and handle malformed input.
---

# Basics

## What you'll learn

- Parsing a string with `Parser.parseString`.
- Inspecting the root node type, byte range, and source text.
- Checking for syntax errors with `Tree.hasError`.

## Complete example

This self-contained program initializes a Tree-sitter parser with an explicit allocator, loads the arithmetic expression grammar, parses an input string into an immutable syntax tree, and inspects root node metadata:

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expressionLanguage;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseString("1 + 2 * 3");
    defer tree.deinit();

    const root = tree.rootNode();
    std.debug.print("root: {s} [{d}, {d}]\n", .{ root.nodeType(), root.startByte(), root.endByte() });
    std.debug.print("has error: {}\n", .{tree.hasError()});
    std.debug.print("text: {s}\n", .{root.text()});
}
```

## Running the example

Run the example using the build system:

```bash
zig build run-basic_parse
```

## Expected output

```text
root: program [0, 9]
has error: false
text: 1 + 2 * 3
```

## How it works

1. `Parser.init(gpa)` initializes the parser with an explicit allocator.
2. `parser.setLanguage(grammar)` loads the language tables and validates ABI compatibility.
3. `parser.parseString("1 + 2 * 3")` parses the string into an owned `Tree`.
4. `tree.rootNode()` returns a lightweight `Node` handle that borrows directly from the tree's node pool.
5. `root.nodeType()` returns `"program"`, and `root.text()` slices the tree's owned copy of the source string.
6. `tree.hasError()` checks if any syntax error nodes were produced during parsing.

## API used

- [Parser](/api/parser) — `Parser.init`, `Parser.setLanguage`, `Parser.parseString`
- [Tree](/api/tree) — `Tree.rootNode`, `Tree.hasError`, `Tree.deinit`
- [Node](/api/node) — `Node.nodeType`, `Node.startByte`, `Node.endByte`, `Node.text`

## Related guides

- [Your First Parser](/guide/first-parser)
- [Parsing Source](/guide/parsing-source)
- [Error Recovery](/guide/error-recovery)
