---
description: Changed-ranges API — diffing two trees into minimal spans.
---

# Changed Ranges

<VersionBadge />

## Overview

Tree-to-tree diffing for repaints and re-analysis. Source: `src/tree/changed_ranges.zig`.

## Functions and methods

```zig
pub fn changedRanges(gpa: Allocator, old_tree: *const Tree, new_tree: *const Tree) Allocator.Error![]Range
pub fn freeRanges(gpa: Allocator, ranges: []Range) void
// allocator-inheriting forms on Tree:
pub fn getChangedRanges(self: *const Tree, other: *const Tree) Allocator.Error![]Range
pub fn freeChangedRanges(self: *const Tree, ranges: []Range) void
```

Identical trees yield an empty slice. The caller owns the result.

## Related pages

[Changed Ranges guide](/guide/changed-ranges), [Tree](/api/tree), [Range](/api/range)
