---
description: Reuse trees — copying, old-tree validity, and subtree splicing.
---

# Tree Reuse

## What you'll learn

- How old trees stay valid during incremental parsing and how to duplicate a tree.

## Complete example

```zig
var old_tree = try parser.parseString("alpha + beta");
defer old_tree.deinit();

var dup = try old_tree.copy();
defer dup.deinit();

// old_tree is untouched by incremental parsing and still fully usable.
var new_tree = try parser.parse(&old_tree, edit, "alpha + gamma");
defer new_tree.deinit();
```

## How it works

- Old trees are **immutable** from the parser's perspective: reuse clones subtrees (translating positions through the edit) into the new pool. The old pool is only ever read.
- `copy()` duplicates source bytes, nodes, and child indices with the tree's own allocator — a snapshot you can edit or compare later.
- Reused subtrees keep their recorded LR start states, which is what makes splicing sound: identical state plus identical bytes implies an identical subtree.

## API used

- [Tree](/api/tree) — `copy`, `getChangedRanges`; [Parser](/api/parser) — `parse`, `reused_node_count`.

## Related guides

- [Incremental Parsing](/guide/incremental-parsing), [Changed Ranges](/guide/changed-ranges)
