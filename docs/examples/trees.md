---
description: Tree examples — recursive walks and cursor traversal with real output.
---

# Trees

## What you'll learn

- Traversing syntax trees recursively using `Node` child indices.
- Efficiently navigating trees without extra allocation using `TreeCursor`.
- Walking down to children, across to siblings, and back to parents.

## Example 1: Recursive Tree Walk

This approach uses `Node.childCount()` and `Node.child(i)` to recursively walk and print the full syntax tree structure down to arbitrary depths:

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expressionLanguage;

fn printNode(node: treesitter.Node, depth: usize) void {
    for (0..depth) |_| std.debug.print("  ", .{});
    std.debug.print("{s} [{d}, {d}] named={}\n", .{ node.nodeType(), node.startByte(), node.endByte(), node.isNamed() });
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        printNode(node.child(i).?, depth + 1);
    }
}

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseString("a * (b + 2)");
    defer tree.deinit();
    printNode(tree.rootNode(), 0);
}
```

### Running Example 1

```bash
zig build run-tree_walk
```

### Expected output

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
          expression [5, 6] named=true
            term [5, 6] named=true
              factor [5, 6] named=true
                identifier [5, 6] named=true
          + [7, 8] named=false
          term [9, 10] named=true
            factor [9, 10] named=true
              number [9, 10] named=true
        ) [10, 11] named=false
```

---

## Example 2: Iterative Traversal with TreeCursor

`TreeCursor` provides stateful, non-recursive navigation with `gotoFirstChild()`, `gotoNextSibling()`, and `gotoParent()`, keeping traversal memory $O(\text{depth})$ without allocating recursion frames:

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expressionLanguage;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseString("a + b * c");
    defer tree.deinit();

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
}
```

### Running Example 2

```bash
zig build run-tree_cursor
```

### Expected output

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

1. **Recursive Walk**: Traverses the node tree by recursively asking each `Node` for its `child(i)`. Simple and readable, ideal for printing and inspection.
2. **Cursor Traversal**: `tree.cursor()` tracks the current position along an internal node stack, allowing depth-first traversal in constant space without recursion.
3. Precedence in the grammar determines grouping: `b * c` is grouped under `term`, while `a + (term)` forms the enclosing `expression`.

## API used

- [Node](/api/node) — `Node.childCount`, `Node.child`, `Node.nodeType`, `Node.startByte`, `Node.endByte`, `Node.isNamed`
- [Tree](/api/tree) — `Tree.rootNode`, `Tree.cursor`
- [Tree Cursor](/api/tree-cursor) — `TreeCursor.currentNode`, `TreeCursor.depth`, `TreeCursor.gotoFirstChild`, `TreeCursor.gotoNextSibling`, `TreeCursor.gotoParent`

## Related guides

- [Understanding Trees](/guide/understanding-trees)
- [Navigating Nodes](/guide/navigating-nodes)
- [Tree Cursors](/guide/tree-cursors)
