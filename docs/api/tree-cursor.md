---
description: TreeCursor API — traversal, depth, fields, and snapshots.
---

# Tree Cursor

<VersionBadge />

## Overview

Stateful depth-first traversal with an internal `(parent, child position)` stack. Source: `src/tree/cursor.zig`.

## Lifecycle

```zig
var cursor = tree.cursor(); // inherits the tree allocator
defer cursor.deinit();
// standalone form: TreeCursor.init(gpa, node)
```

## Methods

```zig
pub fn reset(self: *TreeCursor, node: Node) void
pub fn currentNode(self: *const TreeCursor) Node
pub fn depth(self: *const TreeCursor) u32
pub fn currentFieldName(self: *const TreeCursor) ?[]const u8
pub fn currentFieldId(self: *const TreeCursor) ?u16
pub fn gotoFirstChild(self: *TreeCursor) bool
pub fn gotoLastChild(self: *TreeCursor) bool
pub fn gotoParent(self: *TreeCursor) bool
pub fn gotoNextSibling(self: *TreeCursor) bool
pub fn gotoPreviousSibling(self: *TreeCursor) bool
pub fn gotoDescendant(self: *TreeCursor, goal_byte_offset: u32) void
pub fn copy(self: *const TreeCursor) Allocator.Error!TreeCursor
```

`goto*` returns `false` when the move is impossible. `currentFieldName` is `null` at the start node. `copy` duplicates the path stack with the cursor's allocator.

## Ownership

Owns the path stack only; borrows the tree.

## Performance

Ordinary movement never allocates; the stack grows only on first descent past its capacity.

## Related APIs

[Tree](/api/tree), [Node](/api/node)
