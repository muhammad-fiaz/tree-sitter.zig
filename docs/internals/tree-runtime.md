---
description: Tree runtime internals — roots, error aggregation, edits, and diffs.
---

# Tree Runtime

`src/tree/` composes the pool (`subtree.zig`), handles (`node.zig`), traversal (`cursor.zig`), position shifting (`edit.zig`), and diffing (`changed_ranges.zig`) behind the owning `Tree` facade. Error aggregation is bottom-up at construction time (`has_error` set from children), so `tree.hasError()` is O(1). `applyEdit` maps every stored position through the edit translation; `changedRanges` re-derives minimal diffs structurally without needing the original edit.

## Related pages

[Tree Structure](/concepts/tree-structure), [Nodes](/concepts/nodes), [Cursors](/concepts/cursors)
