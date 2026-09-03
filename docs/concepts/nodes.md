---
description: Nodes — lightweight handles into the syntax tree.
---

# Nodes

## Simple explanation

A node is how your program touches the tree: a tiny handle identifying one syntax element, with methods to read its type, span, children, and text. Handles are cheap to copy and never allocate.

## Technical explanation

`tree/node.zig` defines `Node { tree: *const Tree, index: u32 }`. Every method resolves through the tree's pool: metadata reads are O(1); child/sibling walks are O(degree); `descendantForByteRange` dives to the smallest covering node. `text()` slices the tree's owned source. Equality is pointer-plus-index comparison. Because nodes borrow the tree, using one after `tree.deinit()` is use-after-free — the ownership rules in [Memory Model](/concepts/memory-model) exist to prevent exactly that.

## Related pages

- [Navigating Nodes](/guide/navigating-nodes), [Cursors](/concepts/cursors)
- [Node API](/api/node)
