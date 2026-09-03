---
description: Read concrete syntax trees — root nodes, named vs anonymous nodes, ranges, and tree structure.
---

# Understanding Trees

## What you'll learn

- What a concrete syntax tree contains and how to read one.
- Named vs anonymous nodes, byte ranges, and points.

## The tree for `a * (b + 2)`

Parsing with the bundled expression grammar (`examples/tree_walk.zig`) prints:

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

## How it works

- The **root** is always the grammar's start symbol (`program` here). `tree.rootNode()` returns it.
- **Named nodes** (`identifier`, `expression`) carry the language's structure. **Anonymous nodes** (`+`, `(`, `)`) are punctuation tokens — visible in the tree but `isNamed()` is false.
- Every node records an exact **byte range** plus **row/column points**. Bytes are the source of truth; columns count bytes per line in the same way the reference runtime does.
- Nodes are pooled inside the `Tree`: a `Node` is just a `(tree, index)` handle, so reading metadata never allocates.

## What you receive

```text
Source
  ↓
Parser
  ↓
Tree (owns pool + source copy)
  ↓
Root Node (handle)
  ↓
Child Nodes (handles)
  ↓
Application
```

## API used

- [Tree](/api/tree) — `rootNode`, `hasError`, `nodeCount`, `sourceText`.
- [Node](/api/node) — `nodeType`, `isNamed`, `startByte`, `endByte`, `text`.

## Related guides

- [Navigating Nodes](/guide/navigating-nodes), [Tree Cursors](/guide/tree-cursors)
- [Nodes](/concepts/nodes), [Tree Structure](/concepts/tree-structure)
