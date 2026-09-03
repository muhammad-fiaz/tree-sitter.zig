---
description: Tree examples — recursive walks and cursor traversal with real output.
---

# Trees

## What you'll learn

- Recursive tree printing and iterative cursor traversal.

## Complete example

`examples/tree_walk.zig` (recursive, over `a * (b + 2)`):

```zig
fn printNode(node: treesitter.Node, depth: usize) void {
    for (0..depth) |_| std.debug.print("  ", .{});
    std.debug.print("{s} [{d}, {d}] named={}\n", .{ node.nodeType(), node.startByte(), node.endByte(), node.isNamed() });
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) printNode(node.child(i).?, depth + 1);
}
```

`examples/tree_cursor.zig` (iterative, over `a + b * c`) drives `gotoFirstChild` / `gotoNextSibling` / `gotoParent` with `tree.cursor()`.

## Running the examples

```sh
zig build run-tree_walk
zig build run-tree_cursor
```

## Expected output

`tree_walk` (abridged):

```text
program [0, 11] named=true
  expression [0, 11] named=true
    term [0, 11] named=true
      term [0, 1] named=true
        factor [0, 1] named=true
          identifier [0, 1] named=true
      * [2, 3] named=false
      factor [4, 11] named=true
        ( [4, 5] named=false
        expression [5, 10] named=true
        ...
        ) [10, 11] named=false
```

`tree_cursor`:

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

Both traversals visit the same nodes: recursion is simplest for printing, while the cursor version runs in constant extra memory and can pause or snapshot with `copy()`. Notice how precedence shapes the tree — `b * c` groups under one `term`, and the parenthesized `(b + 2)` nests a full `expression` inside a `factor`.

## API used

- [Node](/api/node), [Tree Cursor](/api/tree-cursor), [Tree](/api/tree)

## Related guides

- [Understanding Trees](/guide/understanding-trees), [Tree Cursors](/guide/tree-cursors)
