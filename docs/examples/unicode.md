---
description: Unicode examples — UTF-8 decoding, byte-exact offsets, and position tracking.
---

# Unicode

## What you'll learn

- Decoding multibyte UTF-8 sequences and retrieving code points and byte lengths.
- Encoding Unicode scalar values to UTF-8 buffers.
- Ensuring byte offsets and positions remain exact across multibyte characters.

## Complete example

This program demonstrates UTF-8 scalar decoding and encoding across 1-byte, 2-byte, 3-byte, and 4-byte sequences, ensuring exact code point extraction and buffer round-trips:

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const unicode = treesitter.unicode_types;

pub fn main() !void {
    // 1-byte ASCII sequence: 'A' (U+0041)
    const ascii = try unicode.decodeOne("A");
    std.debug.print("ASCII: U+{X:0>4} (len {d})\n", .{ ascii.code_point, ascii.len });

    // 2-byte sequence: 'é' (U+00E9)
    const e_acute = try unicode.decodeOne("é");
    std.debug.print("é:     U+{X:0>4} (len {d})\n", .{ e_acute.code_point, e_acute.len });

    // 3-byte sequence: '€' (U+20AC)
    const euro = try unicode.decodeOne("€");
    std.debug.print("€:     U+{X:0>4} (len {d})\n", .{ euro.code_point, euro.len });

    // 4-byte sequence: '😀' (U+1F600)
    const emoji = try unicode.decodeOne("😀");
    std.debug.print("😀:    U+{X:0>4} (len {d})\n", .{ emoji.code_point, emoji.len });

    // Round-trip encoding
    var buf: [4]u8 = undefined;
    const encoded = unicode.encodeOne(0x1F600, &buf);
    const decoded = try unicode.decodeOne(encoded);
    std.debug.print("round-trip: U+{X:0>4} matches={}\n", .{ decoded.code_point, decoded.code_point == 0x1F600 });
}
```

## Running the example

```bash
zig build run-unicode
```

## Expected output

```text
ASCII: U+0041 (len 1)
é:     U+00E9 (len 2)
€:     U+20AC (len 3)
😀:    U+1F600 (len 4)
round-trip: U+1F600 matches=true
```

## How it works

1. `unicode.decodeOne(bytes)` examines the initial byte to determine sequence length (1 to 4 bytes).
2. Continuation bytes (`0x80..0xBF`) are validated, and overlong encodings, UTF-16 surrogates (`0xD800..0xDFFF`), and values beyond `0x10FFFF` are rejected with descriptive error types (`error.Overlong`, `error.Surrogate`, `error.TooLarge`).
3. `unicode.encodeOne(code_point, buffer)` encodes scalar values into UTF-8 slices.
4. Tree-sitter's lexer tracks positions (`row`, `column`, `byte_offset`) using this decoder to guarantee that column counts reflect logical character advances while byte offsets reflect exact storage sizes.

## API used

- [Point](/api/point) — `Point`
- [Unicode & Positions](/guide/unicode-and-positions) — `unicode_types.decodeOne`, `unicode_types.encodeOne`

## Related guides

- [Unicode & Positions Guide](/guide/unicode-and-positions)
- [Positions Reference](/reference/positions)
