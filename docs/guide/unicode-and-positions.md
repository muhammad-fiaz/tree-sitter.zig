---
description: Unicode in tree-sitter.zig — byte offsets vs code points, UTF-8 decoding, rows and columns.
---

# Unicode & Positions

## What you'll learn

- Why byte offsets are the source of truth and how points relate to them.

## Byte offset, code point, row, column

These are four different things:

| Concept | Meaning | Example in `"aé中b"` |
|---------|---------|----------------------|
| Byte offset | Index into the UTF-8 bytes | `é` starts at 1, `中` at 3, `b` at 6 |
| Code point | One Unicode scalar value | 4 code points, 7 bytes |
| Row | Zero-based line number | Newlines increment it |
| Column | Byte offset within the line | Counts bytes, not characters |

The parser tracks bytes exactly and advances points per byte (`\n` starts a new row). It never decodes the whole source up front; UTF-8 is decoded only where character semantics are needed.

## Complete example

```zig
const unicode = treesitter.unicode_types;
const r = try unicode.decodeOne("é"); // code_point 0xE9, len 2
var buf: [4]u8 = undefined;
const enc = unicode.encodeOne(0x20AC, &buf); // "€", 3 bytes
```

Invalid sequences (`Truncated`, `InvalidStart`, `InvalidContinuation`, `Overlong`, `Surrogate`, `TooLarge`) are reported as errors; the lexer substitutes the replacement character and continues.

## UTF-16 input

`Input` values may carry `.utf16_le` / `.utf16_be` encodings. UTF-16 is transcoded to UTF-8 up front (matching BOM stripped, conflicting BOM rejected as `UnexpectedBOM`, lone surrogates and truncation rejected) — tree offsets then refer to the UTF-8 form. `.custom` is treated as raw UTF-8 bytes. Run `zig build run-utf16_parse`:

```text
parsed utf16: 1 + 2 error=false
```

See `treesitter.transcodeUtf16ToUtf8` and [Input](/api/input).

## API used

- [Point](/api/point), [Range](/api/range); `unicode.utf8` and `unicode.tables` via `treesitter.unicode_types`.

## Related guides

- [Unicode example](/examples/unicode), [Unicode](/concepts/unicode), [Positions](/reference/positions)
