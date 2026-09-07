---
description: Tree API — ownership, roots, copies, cursors, and diffs.
---

# Tree

## Overview

`Tree` owns a parse result: the source copy, the node pool, and the child-index buffer. Source: `src/tree/tree.zig`.

## Lifecycle

```zig
var tree = try parser.parseString("1 + 2");
defer tree.deinit();
```

## Methods

### deinit

```zig
pub fn deinit(self: *Tree) void
```

Frees source, pool, and indices. Nodes and cursors borrowed from the tree must not outlive it.

### rootNode

```zig
pub fn rootNode(self: *const Tree) Node
```

Handle to the start-symbol node. Never allocates.

### cursor

```zig
pub fn cursor(self: *const Tree) TreeCursor
```

Traversal cursor inheriting the tree's allocator. Prefer over `TreeCursor.init(gpa, node)`.

### languageOf / sourceText / nodeCount / hasError

```zig
pub fn languageOf(self: *const Tree) Language
pub fn sourceText(self: *const Tree) []const u8
pub fn nodeCount(self: *const Tree) usize
pub fn hasError(self: *const Tree) bool
```

### getNode

```zig
pub fn getNode(self: *const Tree, index: u32) *const Subtree
```

Pool access for advanced tooling.

### copy

```zig
pub fn copy(self: *const Tree) Allocator.Error!Tree
```

Deep duplicate (source, nodes, indices) with the tree's allocator.

### includedRange

```zig
pub fn includedRange(self: *const Tree) Range
```

Span of the root node (empty range for an empty tree).

### getChangedRanges / freeChangedRanges

```zig
pub fn getChangedRanges(self: *const Tree, other: *const Tree) Allocator.Error![]Range
pub fn freeChangedRanges(self: *const Tree, ranges: []Range) void
```

Diff against another tree using the caller's allocator; free with either tree sharing it.

## Ownership

Owns source + pools; borrows allocator and language tables. Streaming parses (`parseStream`) transfer the pull buffer as the source with no extra copy.

## S-expressions

`treesitter.sexp_mod.toSexp(gpa, node)` renders a canonical single-line S-expression (`(type child ...)`, `(type "text")` leaves, `"text"` anonymous tokens, `(MISSING type)`) for debugging and for the [conformance corpus](/development/conformance).

## Example

- [Understanding Trees](/guide/understanding-trees), [Tree Reuse](/guide/tree-reuse)

## Related APIs

[Node](/api/node), [Tree Cursor](/api/tree-cursor), [Changed Ranges](/api/changed-ranges)
