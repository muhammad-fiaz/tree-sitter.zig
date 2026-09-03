---
description: Compute minimal changed ranges between two syntax trees.
---

# Changed Ranges

## What you'll learn

- How to diff two trees into minimal `Range` values for repainting or re-analysis.

## Complete example

```zig
const ranges = try old_tree.getChangedRanges(&new_tree);
defer old_tree.freeChangedRanges(ranges);
for (ranges) |r| {
    std.debug.print("changed: bytes [{d}, {d}] rows {d}..{d}\n", .{
        r.start_byte, r.end_byte, r.start_point.row, r.end_point.row,
    });
}
```

## How it works

The comparison walks both trees in lockstep. Nodes with equal symbols, child counts, and start/end points are descended into; the first node that differs on either side contributes its range, and equal leaves contribute nothing. Identical trees therefore report zero ranges, while an insertion reports only the narrow span around the new text (e.g. `bytes [4, 6]` for `1 + 2` → `1 + 22`).

## Memory ownership

`getChangedRanges` allocates the result slice with the old tree's allocator; `freeChangedRanges` on either tree releases it (both normally share your single allocator).

## API used

- [Changed Ranges](/api/changed-ranges), [Range](/api/range), [Tree](/api/tree).

## Related guides

- [Incremental Parsing](/guide/incremental-parsing), [Editing Trees](/guide/editing-trees)
