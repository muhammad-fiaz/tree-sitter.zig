---
description: Subtree runtime internals — pool layout, indices, and cloning.
---

# Subtree Runtime

`src/tree/subtree.zig`: `Subtree` is a 48-byte-ish plain record; `SubtreePool` owns `nodes` and `child_indices` arrays. Children are `(start, count)` windows of `u32` indices — never pointers — so pools relocate freely and clones rewrite only integers. `pushNode`/`pushChildren` are thin `ArrayList` appends; `cloneSubtree` (in the parser) pushes the parent record first, then appends children directly into `child_indices` with backpatched `(start, count)`, avoiding any temporary allocation on the hot path.

## Related pages

[Subtrees](/concepts/subtrees), [Incremental Runtime](/internals/incremental-runtime), [Memory Runtime](/internals/memory-runtime)
