---
description: Unicode concepts — bytes, code points, rows, and columns.
---

# Unicode

## Simple explanation

Source files are bytes; humans think in characters and lines. The runtime keeps byte offsets exact (everything indexes bytes) while tracking row/column points and decoding UTF-8 only where character meaning matters.

## Technical explanation

`unicode/utf8.zig` implements strict decoding (rejecting truncated, overlong, surrogate, and out-of-range sequences) plus encoding, code-point counting, and continuation-byte helpers. `unicode/tables.zig` classifies whitespace/letter/digit/word code points beyond ASCII. Points advance per byte with `\n` starting a new row, matching reference-runtime column semantics. The lexer substitutes the replacement character on invalid bytes and continues rather than failing the parse.

## Related pages

- [Unicode & Positions guide](/guide/unicode-and-positions), [Positions](/reference/positions)
