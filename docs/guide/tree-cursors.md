---
description: Traverse syntax trees with TreeCursor — allocation-free movement, depth, and field tracking.
---

# Tree Cursors

## What you'll learn

- Depth-first traversal with a reusable cursor.
- Depth and current-field introspection.

## When to use this

Walk whole subtrees (highlighting, analysis) without allocating per node.

## Complete example

`examples/tree_cursor.zig` over `a + b * c`:

```zig
var cursor = tree.cursor();
defer cursor.deinit();

outer: while (true) {
    const node = cursor.currentNode();
    std.debug.print("depth={d} {s} [{d}, {d}]\n", .{ cursor.depth(), node.nodeType(), node.startByte(), node.endByte() });
    if (cursor.gotoFirstChild()) continue;
    while (true) {
        if (cursor.gotoNextSibling()) break;
        if (!cursor.gotoParent()) break :outer;
    }
}
```

## Expected output

```text
depth=0 program [0, 9]
depth=1 expression [0, 9]
depth=2 expression [0, 1]
depth=3 term [0, 1]
depth=4 factor [0, 1]
depth=5 identifier [0, 1]
depth=2 + [2, 3]
depth=2 term [4, 9]
depth=3 term [4, 5]
depth=4 factor [4, 5]
depth=5 identifier [4, 5]
depth=3 * [6, 7]
depth=3 factor [8, 9]
depth=4 identifier [8, 9]
```

## How it works

- The cursor keeps a small stack of `(node, child position)` entries. Movement rewrites the top entry — ordinary movement never touches the allocator.
- `depth()` reports how far below the start node you are; `currentFieldName()` reports the field binding (e.g. `"left"`) of the current child, if any.
- `gotoDescendant(byte)` dives to the deepest node containing a byte offset — ideal for hover and click handling.
- `reset(node)` reuses the cursor for another walk; `copy()` snapshots it.

## Memory ownership

`tree.cursor()` inherits the tree's allocator. `cursor.deinit()` releases the cursor's own stack; the tree is untouched.

## API used

- [Tree Cursor](/api/tree-cursor), [Tree](/api/tree) — `cursor()`.

## Related guides

- [Tree walking example](/examples/trees), [Cursors](/concepts/cursors)
