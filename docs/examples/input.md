---
description: Input examples — chunked callbacks and std.Io.Reader sources.
---

# Input

## What you'll learn

- Serving source from chunk callbacks and from `std.Io.Reader`.

## Complete example

`examples/custom_input.zig` serves `12 + 34` as two chunks (`"12 + "`, `"34"`) through an `Input.read` callback, then parses with `parseWithInput`.

## Running the example

```sh
zig build run-custom_input
```

## Expected output

```text
parsed from chunks: 12 + 34 error=false
```

`examples/utf16_parse.zig` feeds UTF-16LE bytes (with BOM) through an `Input` with `.encoding = .utf16_le` — try `zig build run-utf16_parse`:

```text
parsed utf16: 1 + 2 error=false
```

## How it works

The callback maps a byte index to the containing chunk and returns its remainder; `null` signals end of input. `ReaderSource` adapts the same shape over any `std.Io.Reader` with a caller buffer. `parseWithInput` buffers pulled chunks and runs the standard parse, so results equal `parseString` on the concatenated bytes. `parseStream` skips the pre-buffering and lexes incrementally instead — same result, streaming memory profile.

## API used

- [Input](/api/input), [Parser](/api/parser) — `parseWithInput`, `parseStream`.

## Related guides

- [Parsing Source](/guide/parsing-source), [Custom Input](/guide/custom-input)
