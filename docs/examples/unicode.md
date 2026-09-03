---
description: Unicode examples — UTF-8 decoding, byte-exact offsets, and position tracking.
---

# Unicode

## What you'll learn

- Decoding multibyte sequences and keeping byte offsets exact.

## Complete example

```zig
const unicode = treesitter.unicode_types;

// 2-byte sequence: code point U+00E9, length 2.
const e_acute = try unicode.decodeOne("é");
// 3-byte sequence: U+20AC, length 3.
const euro = try unicode.decodeOne("€");

// Round-trip any scalar value.
var buf: [4]u8 = undefined;
const enc = unicode.encodeOne(0x1F600, &buf);
const back = try unicode.decodeOne(enc); // U+1F600
```

Invalid inputs (`""`, `"\xFF"`, truncated `"\xC3"`, overlong `"\xC0\xAF"`, surrogates) return descriptive errors instead of panicking.

## How it works

`decodeOne` reads the lead byte to find the length, validates continuations, and rejects overlong forms, surrogates, and values above U+10FFFF. The parser uses the same decoder for single-character lookahead and falls back to the replacement character on corrupt bytes so parsing continues.

## API used

- [Point](/api/point); `unicode.utf8` / `unicode.tables` via `treesitter.unicode_types`.

## Related guides

- [Unicode & Positions](/guide/unicode-and-positions), [Positions](/reference/positions)
