---
description: Point API — rows, columns, comparison, and arithmetic.
---

# Point

<VersionBadge />

## Overview

`Point { row: u32, column: u32 }` — zero-based line and byte-column. Source: `src/core/point.zig`.

## Methods

```zig
pub fn eql(a: Point, b: Point) bool
pub fn order(a: Point, b: Point) std.math.Order
pub fn lessThan(a: Point, b: Point) bool
pub fn lessOrEql(a: Point, b: Point) bool
pub fn add(a: Point, b: Point) Point
pub fn sub(a: Point, b: Point) Point   // asserts b <= a
pub fn advancePoint(point: Point, byte: u8) Point   // '\n' → next row
pub fn pointForBytes(source: []const u8, byte_offset: usize) Point
```

Columns count bytes, not code points — see [Unicode](/concepts/unicode).

## Related APIs

[Range](/api/range), [InputEdit](/api/input-edit), [Positions](/reference/positions)
