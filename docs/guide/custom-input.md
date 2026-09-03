---
description: Feed the parser from callbacks, readers, and true streaming input.
---

# Custom Input

## What you'll learn

- How to implement the `Input.read` callback for chunked or generated source.
- When to buffer (`parseWithInput`) versus stream (`parseStream`).

## Complete example

See [Parsing Source](/guide/parsing-source) for the full `Chunked` implementation and [examples/custom_input.zig](https://github.com/muhammad-fiaz/tree-sitter.zig/blob/main/examples/custom_input.zig). Run it with:

```sh
zig build run-custom_input
```

## Expected output

```text
parsed from chunks: 12 + 34 error=false
```

## How it works

The callback receives an opaque payload, a byte index, and the position at that index, and returns a pointer plus the available length. The parser pulls monotonically increasing offsets, so ring buffers, paged storage, and generated streams all fit naturally. Return `null` or length `0` at end of input.

## Buffering versus streaming

- `parseWithInput(old, edit, input)` buffers the whole input first, then parses. Use it when you also pass an old tree: subtree reuse needs the complete new text.
- `parseStream(null, null, input)` pulls bytes on demand as the lexer advances — no pre-buffering — and the tree takes ownership of exactly the consumed prefix. Ideal for files, sockets, and decompressors behind `std.Io.Reader`. With an old tree it falls back to buffering so reuse still applies.

```zig
var tree = try parser.parseStream(null, null, source.input());
defer tree.deinit();
```

Inputs are UTF-8; offsets are `u32` (4 GiB limit, shared by the whole runtime).

## API used

- [Input](/api/input), [Parser](/api/parser) — `parseWithInput`, `parseStream`, `StreamBuffer`.

## Related guides

- [Reader Input](/guide/parsing-source), [Input & I/O](/reference/input-io)
