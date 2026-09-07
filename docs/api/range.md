---
description: Range API — byte and point spans with containment helpers.
---

# Range

## Overview

`Range { start_byte, end_byte, start_point, end_point }` spans source text in both coordinate systems. Source: `src/core/range.zig`.

## Methods

```zig
pub fn isEmpty(self: Range) bool
pub fn containsByte(self: Range, byte: u32) bool
pub fn containsRange(self: Range, other: Range) bool
pub fn overlaps(self: Range, other: Range) bool
pub fn rangeContainsPoint(range: Range, point: Point) bool
```

## Related APIs

[Point](/api/point), [Node](/api/node) — `range()`, [Changed Ranges](/api/changed-ranges)
