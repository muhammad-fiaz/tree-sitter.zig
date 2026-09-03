---
description: Basic examples — parse source, inspect the root, and handle malformed input.
---

# Basics

## What you'll learn

- Parsing a string, reading the root node, and detecting errors.

## When to use this

First contact with the library, smoke tests, and language experiments.

## Complete example

`examples/basic_parse.zig`:

```zig
var parser = treesitter.Parser.init(gpa);
defer parser.deinit();
try parser.setLanguage(treesitter.expression_language);

var tree = try parser.parseString("1 + 2 * 3");
defer tree.deinit();

const root = tree.rootNode();
std.debug.print("root: {s} [{d}, {d}]\n", .{ root.nodeType(), root.startByte(), root.endByte() });
std.debug.print("has error: {}\n", .{tree.hasError()});
std.debug.print("text: {s}\n", .{root.text()});
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

`parseString` lexes and reduces `1 + 2 * 3` into a `program` node spanning the whole input. `hasError()` reads the root's aggregated flag — false here because every token had a valid table action. `text()` slices the tree's owned source copy.

## API used

- [Parser](/api/parser), [Tree](/api/tree), [Node](/api/node)

## Memory ownership

Parser owns scratch; tree owns pool and source; handles borrow. Three `deinit` calls release everything.

## Related guides

- [Your First Parser](/guide/first-parser), [Error Recovery](/guide/error-recovery) for the `has_error=true` side.
