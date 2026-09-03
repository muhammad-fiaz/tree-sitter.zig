---
description: Write the smallest complete tree-sitter.zig program and understand every line.
---

# Your First Parser

## What you'll learn

- The five calls every program makes: init, setLanguage, parse, inspect, deinit.

## Complete example

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expression_language;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();

    var parser = treesitter.Parser.init(gpa_state.allocator());
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

This is `examples/basic_parse.zig` from the repository.

## Expected output

```text
root: program [0, 9]
has error: false
text: 1 + 2 * 3
```

## How it works

1. **Allocator once.** `Parser.init` is the only call that takes an allocator. The parser stores it and every derived object reuses it.
2. **Language.** `setLanguage` validates the grammar's ABI version and loads its tables. Without it, `parseString` returns `error.NoLanguage`.
3. **Parse.** `parseString` runs the lexer plus the LR engine and returns an owning `Tree`.
4. **Inspect.** `rootNode()` gives a `Node` — a small handle (tree pointer + index), not an allocation.
5. **Cleanup.** Each `deinit` frees exactly what its object owns: parser scratch, tree pool and source copy.

## API used

- [Parser](/api/parser), [Tree](/api/tree), [Node](/api/node)

## Related guides

- [Parsing Source](/guide/parsing-source) for non-string inputs.
- [Understanding Trees](/guide/understanding-trees) for reading the result.
