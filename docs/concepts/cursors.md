---
description: Cursors — stateful, allocation-free tree traversal.
---

# Cursors

## Simple explanation

A cursor is a finger you move through the tree: down to the first or last child, sideways to siblings, up to the parent. Unlike recursive walks, it uses constant extra memory and can pause, snapshot, and resume.

## Technical explanation

`tree/cursor.zig` keeps the current node plus a stack of `(parent index, child position)` entries. Moves rewrite stack entries in place, so ordinary traversal never allocates (the stack only grows on first descent into unusual depth). The cursor also tracks field context (`currentFieldName`/`currentFieldId`) and supports `gotoDescendant` dives, `reset` reuse, and `copy` snapshots. Cursor movement never mutates the tree.

## Related pages

- [Tree Cursors](/guide/tree-cursors), [Nodes](/concepts/nodes)
- [Tree Cursor API](/api/tree-cursor)
