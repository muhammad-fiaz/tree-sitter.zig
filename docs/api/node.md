---
description: Node API — every method on the lightweight syntax-tree handle.
---

# Node

<VersionBadge />

## Overview

`Node { tree: *const Tree, index: u32 }` — two words, zero ownership. Every method below is allocation-free. Source: `src/tree/node.zig`.

## Identity and type

```zig
pub fn symbol(self: Node) u16
pub fn nodeType(self: Node) []const u8
pub fn eql(a: Node, b: Node) bool
pub fn isNull(self: Node) bool
```

## Flags

```zig
pub fn isNamed(self: Node) bool
pub fn isMissing(self: Node) bool
pub fn isExtra(self: Node) bool
pub fn isError(self: Node) bool
pub fn hasError(self: Node) bool
```

## Spans

```zig
pub fn startByte(self: Node) u32
pub fn endByte(self: Node) u32
pub fn startPoint(self: Node) Point
pub fn endPoint(self: Node) Point
pub fn byteRange(self: Node) struct { start: u32, end: u32 }
pub fn range(self: Node) Range
pub fn text(self: Node) []const u8
```

`text()` slices the tree's owned source; out-of-range spans safely yield `""`.

## Children

```zig
pub fn childCount(self: Node) u32
pub fn namedChildCount(self: Node) u32
pub fn descendantCount(self: Node) u32
pub fn children(self: Node) []const u32
pub fn child(self: Node, i: u32) ?Node
pub fn namedChild(self: Node, i: u32) ?Node
```

## Family navigation

```zig
pub fn parent(self: Node) ?Node
pub fn nextSibling(self: Node) ?Node
pub fn prevSibling(self: Node) ?Node
pub fn nextNamedSibling(self: Node) ?Node
pub fn prevNamedSibling(self: Node) ?Node
```

`parent()` is `null` at the root.

## Fields

```zig
pub fn childByFieldName(self: Node, name: []const u8) ?Node
pub fn fieldNameForChild(self: Node, child_index: u32) ?[]const u8
```

## Range lookup

```zig
pub fn descendantForByteRange(self: Node, start: u32, end: u32) ?Node
pub fn namedDescendantForByteRange(self: Node, start: u32, end: u32) ?Node
```

## Ownership

Borrows the tree. No `deinit`.

## Related APIs

[Tree](/api/tree), [Tree Cursor](/api/tree-cursor), [Point](/api/point), [Range](/api/range)
