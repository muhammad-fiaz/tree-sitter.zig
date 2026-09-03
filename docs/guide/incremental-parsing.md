---
description: Incremental parsing in tree-sitter.zig — edits, subtree reuse, and editor-style updates.
---

# Incremental Parsing

## What you'll learn

- How an `InputEdit` plus an old tree produces a new tree with reuse.
- How to read `reused_node_count`.

## When to use this

Any program that re-parses after small source changes — editors, language servers, watchers.

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
```

## Expected output

```text
before: 1 + 2
after:  1 + 22
changed: bytes [4, 6]
```

## How it works

```text
Original source → initial parse → Tree
      ↓
Source edit (bytes + points, old and new ends)
      ↓
InputEdit → Parser.parse(old, edit, new_source)
      ↓
Reuse compatible subtrees (same state, same bytes)
      ↓
New Tree → Changed ranges
```

1. Describe the edit once: where it starts, where the old text ended, where the new text ends — in both bytes and points.
2. `parse` collects reusable old subtrees: nodes fully outside the edited span, without errors, whose recorded LR state matches the current parse state at their (translated) start offset.
3. Matching subtrees are cloned into the new pool and the parser jumps over them — no re-lexing, no re-reducing.
4. `parser.reused_node_count` reports how many old subtrees were spliced in (about 40,000 on the 80KB benchmark corpus for a leading-edge edit).

## Performance considerations

- Reuse is opportunistic and always correct: identical LR state plus identical bytes implies an identical subtree, and error recovery backstops any mismatch.
- Leading-edge edits (byte 0) are the worst case; trailing edits reuse large subtrees in single clones.
- Old trees stay valid and immutable — reuse copies, never moves.

## API used

- [Parser](/api/parser) — `parse`, `reused_node_count`.
- [InputEdit](/api/input-edit), [Changed Ranges](/api/changed-ranges).

## Related guides

- [Editing Trees](/guide/editing-trees), [Changed Ranges](/guide/changed-ranges), [Tree Reuse](/guide/tree-reuse)
- [Incremental Runtime](/internals/incremental-runtime)
