---
description: Tree structure — pools, roots, source copies, and tree-level operations.
---

# Tree Structure

## Simple explanation

A `Tree` is the parsed result you keep: it owns its text and all its nodes, tells you its root, whether anything is broken, and can diff itself against another tree.

## Technical explanation

`tree/tree.zig` owns `source` (a copy of the parsed bytes), the `SubtreePool`, and `root_index`. Operations: `rootNode()` (handle, no allocation), `hasError()` (reads the root flag), `copy()` (deep duplicate with the tree's allocator), `includedRange()`, `languageOf()`, `sourceText()`, plus the allocator-inheriting `cursor()`, `getChangedRanges()`, and `freeChangedRanges()`. Trees are immutable after parsing except for `applyEdit`, which shifts stored positions through an edit's translation.

## Related pages

- [Understanding Trees](/guide/understanding-trees), [Subtrees](/concepts/subtrees)
- [Tree Runtime](/internals/tree-runtime), [Tree API](/api/tree)
