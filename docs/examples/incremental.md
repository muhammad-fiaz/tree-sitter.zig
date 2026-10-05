---
description: Incremental examples — edits, subtree reuse, and changed ranges with real output.
---

# Incremental Parsing

## What you'll learn

- Performing incremental re-parsing using an existing syntax tree and an `InputEdit`.
- Computing changed ranges between an old tree and a new tree with `getChangedRanges`.
- Reusing unchanged subtrees across keystroke edits.

## Complete example

This program demonstrates how editors perform incremental re-parsing: applying an `InputEdit` to shift coordinates in an existing tree, parsing updated text while reusing unaffected subtrees, and querying the exact `changedRanges` between trees:

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

    var old_tree = try parser.parseString("1 + 2");
    defer old_tree.deinit();
    std.debug.print("before: {s}\n", .{old_tree.rootNode().text()});

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
    std.debug.print("after:  {s}\n", .{new_tree.rootNode().text()});

    const ranges = try old_tree.getChangedRanges(&new_tree);
    defer old_tree.freeChangedRanges(ranges);
    for (ranges) |r| {
        std.debug.print("changed: bytes [{d}, {d}]\n", .{ r.start_byte, r.end_byte });
    }
}
```

## Running the example

```bash
zig build run-incremental_parse
```

## Expected output

```text
before: 1 + 2
after:  1 + 22
changed: bytes [4, 6]
```

## How it works

1. `old_tree` is constructed from `"1 + 2"`.
2. An `InputEdit` is created describing the change: replacing `"2"` (offset 4 to 5) with `"22"` (offset 4 to 6).
3. `parser.parse(&old_tree, edit, "1 + 22")` reuses unaffected nodes (such as the number `"1"` and operator `"+"`) from `old_tree`, only creating new nodes for the edited token and its ancestors.
4. `old_tree.getChangedRanges(&new_tree)` diffs the two trees to find exact byte and point intervals that were affected, printing `[4, 6]`.

## API used

- [Parser](/api/parser) — `Parser.parse`
- [Input Edit](/api/input-edit) — `InputEdit`
- [Changed Ranges](/api/changed-ranges) — `Tree.getChangedRanges`, `Tree.freeChangedRanges`

## Related guides

- [Incremental Parsing](/guide/incremental-parsing)
- [Editing Trees](/guide/editing-trees)
- [Changed Ranges](/guide/changed-ranges)
