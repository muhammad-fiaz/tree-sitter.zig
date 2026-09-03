---
description: Input API — Input callbacks, MemorySource, ReaderSource, StreamBuffer, and Source.
---

# Input

<VersionBadge />

## Overview

Four ways to feed bytes, from simplest to most general. Source: `src/input/`.

## Types

```zig
pub const ReadFn = *const fn (payload: ?*anyopaque, byte_index: u32, position: Point, bytes_read: *u32) ?[*]const u8;
pub const Input = struct { payload: ?*anyopaque = null, read: ReadFn, encoding: InputEncoding = .utf8 };
pub fn chunk(self: Input, byte_index: u32, position: Point) ?struct { ptr: [*]const u8, len: u32 }
```

`MemorySource { bytes }` adapts a slice (`source.input()`); `ReaderSource { reader: *Io.Reader, buffer }` adapts a `std.Io.Reader` with a caller buffer. `StreamBuffer` is the incremental pull buffer behind `Parser.parseStream`: `require(end)` pulls chunks until `[0, end)` is buffered or the callback reports EOF, `truncate(len)` drops unread read-ahead, and `takeOwned()` transfers the cache (becoming `Tree.source` with no extra copy). `Source` is a `union { bytes, input }` with `byteLen`, `byteAt`, `slice`, and `pointAt` helpers plus `sourceFromBytes` / `sourceFromInput` constructors.

Return `null` or length 0 from `read` at end of input. Offsets are pulled monotonically. Inputs are limited to 4 GiB (`u32` offsets throughout the runtime).

## Encodings

`Input.encoding` selects `.utf8` (default), `.utf16_le`, `.utf16_be`, or `.custom` (raw bytes, treated as UTF-8). UTF-16 inputs are transcoded via `unicode.utf16.transcodeToUtf8` (also exposed as `treesitter.transcodeUtf16ToUtf8`): matching BOMs are stripped, conflicting BOMs (`UnexpectedBOM`), lone surrogates (`LoneSurrogate`), and truncation (`Truncated`) are errors — never silent replacement. Tree offsets always refer to the UTF-8 form.

## Ownership

Payloads and buffers stay caller-owned and must live through the parse call. Trees copy what they need.

## Related pages

[Parsing Source](/guide/parsing-source), [Custom Input](/guide/custom-input), [Input & I/O](/reference/input-io)
