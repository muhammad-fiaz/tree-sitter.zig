---
description: Subtrees — the pooled node records that make trees cheap and shareable.
---

# Subtrees

## Simple explanation

Instead of allocating each syntax node separately, the runtime stores all nodes of a tree in one flat pool. Sharing and copying whole regions then means copying plain records, not chasing pointers.

## Technical explanation

`tree/subtree.zig` defines `Subtree`: symbol, production id, byte/point spans, child slice location (`children_start` + `child_count`), parent index, named/descendant counts, flags (named, visible, extra, missing, error), and `reuse_state` (the LR state at the node's start). `SubtreePool` owns the two backing arrays. Children are `u32` indices into the same pool, so cloning a region is a memcpy-style walk that rewrites parent links — the mechanism behind incremental reuse.

## Related pages

- [Tree Structure](/concepts/tree-structure), [Nodes](/concepts/nodes)
- [Subtree Runtime](/internals/subtree-runtime), [Incremental Runtime](/internals/incremental-runtime)
