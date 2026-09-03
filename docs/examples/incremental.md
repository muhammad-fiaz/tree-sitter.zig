---
description: Incremental examples — edits, subtree reuse, and changed ranges with real output.
---

# Incremental

## What you'll learn

- Editor-style update: describe an edit, reparse, and diff the trees.

## Complete example

`examples/incremental_parse.zig`:

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

const ranges = try old_tree.getChangedRanges(&new_tree);
defer old_tree.freeChangedRanges(ranges);
for (ranges) |r| {
    std.debug.print("changed: bytes [{d}, {d}]\n", .{ r.start_byte, r.end_byte });
}
```

## Running the example

```sh
zig build run-incremental_parse
```

## Expected output

```text
before: 1 + 2
after:  1 + 22
changed: bytes [4, 6]
```

## Input

Original source `1 + 2`.

## Edit

Insert one byte at offset 4 (`2` → `22`): start 4, old end 5, new end 6, same row, columns adjusted.

## Result

New tree for `1 + 22` with only bytes `[4, 6]` reported changed. The untouched `1 +` prefix reuses old subtrees (`parser.reused_node_count > 0`).

## API used

- [Parser](/api/parser), [InputEdit](/api/input-edit), [Changed Ranges](/api/changed-ranges)

## Memory ownership

Both trees coexist; the old tree is only read during reuse. Each `deinit` frees its own pool.

## Performance considerations

Trailing edits reuse large subtrees in single clones; leading-edge edits re-examine more. See [Performance](/guide/performance).

## Related guides

- [Incremental Parsing](/guide/incremental-parsing), [Editing Trees](/guide/editing-trees)
