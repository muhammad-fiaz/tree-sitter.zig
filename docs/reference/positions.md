---
description: Positions reference — byte offsets, points, ranges, and edit translation math.
---

# Positions

## Coordinates

- **Byte offset** (`u32`): index into UTF-8 source. The only coordinate everything else derives from. 32-bit by design (see [x86-64](/compatibility/x86-64)).
- **Point** (`row: u32`, `column: u32`): zero-based line plus byte-column. Columns count bytes, so wide characters occupy multiple columns — identical to the reference runtime's convention.
- **Range**: both systems together, with containment/overlap helpers.

## Translation through edits

`translateByte`: before-start untouched; at/after old-end shifted by the length delta; inside clamped into the new span. `translatePoint`: rows before the start untouched; rows after the old end shifted; edited rows rebase columns onto the new end. Zero-width nodes at an insertion point stay at the point; content at the point shifts right.

## Related pages

[Unicode & Positions](/guide/unicode-and-positions), [Editing Trees](/guide/editing-trees), [Point](/api/point), [Range](/api/range)
