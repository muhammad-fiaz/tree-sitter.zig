---
description: Parse in-memory source, callback input, and std.Io.Reader streams with tree-sitter.zig.
---

# Parsing Source

## What you'll learn

- The three input paths: `parseString`, `parseWithInput` with callbacks, and `ReaderSource`.
- What the parser copies and what it borrows.

## When to use this

Choose the input style that matches where your bytes live.

## Complete example

```zig
// 1. Simplest: an in-memory slice. The tree copies it.
var tree = try parser.parseString("12 + 34");
defer tree.deinit();

// 2. Callback input: bytes are pulled in chunks by byte offset.
var tree2 = try parser.parseWithInput(null, null, my_input);
defer tree2.deinit();

// 3. Anything behind a std.Io.Reader (files, sockets).
var reader: std.Io.Reader = ...;
var backing: [4096]u8 = undefined;
var source = treesitter.ReaderSource.init(&reader, &backing);
var tree3 = try parser.parseWithInput(null, null, source.input());
defer tree3.deinit();
```

The chunked-callback variant is `examples/custom_input.zig`:

```zig
const Chunked = struct {
    chunks: []const []const u8,
    fn read(payload: ?*anyopaque, byte_index: u32, position: treesitter.Point, bytes_read: *u32) ?[*]const u8 {
        _ = position;
        const self: *@This() = @ptrCast(@alignCast(payload.?));
        var offset: usize = 0;
        for (self.chunks) |chunk| {
            if (@as(usize, @intCast(byte_index)) < offset + chunk.len) {
                const inner = @as(usize, @intCast(byte_index)) - offset;
                bytes_read.* = @as(u32, @intCast(chunk.len - inner));
                return chunk.ptr + inner;
            }
            offset += chunk.len;
        }
        bytes_read.* = 0;
        return null;
    }
};
```

## Expected output

```text
parsed from chunks: 12 + 34 error=false
```

## How it works

- `parseString` is the zero-friction path: no filesystem access, one source copy owned by the tree.
- `Input.read` is a plain function pointer receiving the payload, byte index, and position, returning a pointer plus length. Return `null` (or length 0) for end of input.
- `ReaderSource` adapts a `std.Io.Reader` to that callback shape with a caller-provided buffer.
- `parseWithInput` buffers pulled chunks and then runs the standard parse, so callback input behaves identically to memory input. `parseStream` skips the pre-buffering and lexes incrementally instead (see [Custom Input](/guide/custom-input)).

## Memory ownership

Trees always own their source copy. Callback payloads and reader buffers stay caller-owned and only need to live for the duration of the `parseWithInput` call.

## API used

- [Parser](/api/parser) — `parseString`, `parseWithInput`.
- [Input](/api/input) — `Input`, `MemorySource`, `ReaderSource`, `Source`.

## Related guides

- [Custom Input](/guide/custom-input), [Included Ranges](/guide/included-ranges)
- [Input & I/O](/reference/input-io)
