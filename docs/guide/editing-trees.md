---
description: Apply InputEdit metadata to trees — byte/point translation semantics.
---

# Editing Trees

## What you'll learn

- The six fields of `InputEdit` and what each one means.
- How `applyEdit` shifts stored positions.

## The six fields

| Field | Meaning |
|-------|---------|
| `start_byte` | Where the change begins (old and new text agree before this) |
| `old_end_byte` | Where the replaced old text ended |
| `new_end_byte` | Where the replacement new text ends |
| `start_point` | Row/column of `start_byte` |
| `old_end_point` | Row/column of `old_end_byte` in the old text |
| `new_end_point` | Row/column of `new_end_byte` in the new text |

For a pure insertion, `start_byte == old_end_byte`. For a pure deletion, `start_byte == new_end_byte`.

## Complete example

```zig
treesitter.applyEdit(&tree, .{
    .start_byte = 0,
    .old_end_byte = 0,
    .new_end_byte = 4,
    .start_point = .{},
    .old_end_point = .{},
    .new_end_point = .{ .row = 0, .column = 4 },
});
// tree.rootNode().startByte() == 4, endByte() == 9
```

## How it works

`applyEdit` rewrites every stored node position through the edit:

- Bytes before `start_byte` are untouched.
- Bytes at or after `old_end_byte` shift by `new − old` length delta.
- Bytes inside the edited span clamp to the new span.
- Points translate with the same rules, row-aware: positions before the start point keep their row, positions after the old end shift rows, and columns on the edited rows rebase onto the new end column.

## When to use this

Call `applyEdit` when you keep a tree around while its source changes and want its positions to stay meaningful — for example, to map cursor positions before reparsing. `Parser.parse` does its own translation internally, so the edit-and-reparse flow does not require a prior `applyEdit`.

## API used

- [InputEdit](/api/input-edit), [Tree](/api/tree) — `applyEdit` helper, [Point](/api/point).

## Related guides

- [Incremental Parsing](/guide/incremental-parsing), [Changed Ranges](/guide/changed-ranges)
