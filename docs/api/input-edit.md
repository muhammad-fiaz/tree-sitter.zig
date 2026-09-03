---
description: InputEdit API — describing source changes in bytes and points.
---

# InputEdit

<VersionBadge />

## Overview

`InputEdit` describes one contiguous source change so trees can be updated and reparsed. Source: `src/core/edit.zig`.

## Struct

```zig
pub const InputEdit = struct {
    start_byte: u32 = 0,
    old_end_byte: u32 = 0,
    new_end_byte: u32 = 0,
    start_point: Point = .{},
    old_end_point: Point = .{},
    new_end_point: Point = .{},
};
```

## Methods

```zig
pub fn isInsertion(self: InputEdit) bool   // old_end == start
pub fn isDeletion(self: InputEdit) bool    // new_end == start
pub fn oldLength(self: InputEdit) u32
pub fn newLength(self: InputEdit) u32
pub fn editedByteCount(self: InputEdit) i64
pub fn translateByte(self: InputEdit, byte: u32) u32
pub fn translatePoint(self: InputEdit, point: Point) Point
```

Translation rules: positions before the start are untouched; positions at/after the old end shift by the length delta; positions inside clamp into the new span (points row-aware).

## Related APIs

[Tree](/api/tree) (`applyEdit` helper), [Point](/api/point), [Range](/api/range); [Editing Trees](/guide/editing-trees)
