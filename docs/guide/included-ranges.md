---
description: Included ranges in tree-sitter.zig — enforced lexer semantics.
---

# Included Ranges

`Parser.setIncludedRanges` restricts lexing to byte/point ranges (editor visible regions, injections) while nodes keep their original document coordinates.

```zig
try parser.setIncludedRanges(&.{.{
    .start_byte = 120,
    .end_byte = 340,
    .start_point = .{ .row = 8, .column = 0 },
    .end_point = .{ .row = 20, .column = 5 },
}});
```

## Semantics

- Ranges must be sorted by `start_byte` and non-overlapping, otherwise `error.InvalidRange`. An empty slice clears the restriction.
- The tokenizer skips excluded gaps silently: gaps never produce tokens and never produce errors.
- A token must lie within a single range; tokens cannot span gaps.
- Positions stay exact (points advance through skipped bytes), including in streaming mode.
- Incremental reuse and queries operate on the ranged tree normally.

## Complete example

```zig
try parser.setIncludedRanges(&.{.{
    .start_byte = 0,
    .end_byte = 5,
    .start_point = .{},
    .end_point = .{ .row = 0, .column = 5 },
}});
var tree = try parser.parseString("1 + 2 + 3");
defer tree.deinit();
// root covers only the included prefix:
// root.text() == "1 + 2", endByte() == 5, hasError() == false
```

## API used

- [Parser](/api/parser) — `setIncludedRanges`, `includedRanges`; [Range](/api/range).

## Related guides

- [Parsing Source](/guide/parsing-source), [Custom Input](/guide/custom-input)
