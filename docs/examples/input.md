---
description: Input examples — chunked callbacks and UTF-16 stream sources.
---

# Input Sources

## What you'll learn

- Serving source from chunked memory through an `Input.read` callback.
- Handling UTF-16 encoded input streams with automatic UTF-8 transcoding.
- Streaming input directly from a standard library `std.Io.Reader` interface.
- Using `parseWithInput` and `parseReader` for custom I/O sources.

## Example 1: Chunked Input Callback

When source code is stored across disjoint memory buffers or piece trees, an `Input.read` callback provides chunks on demand without consolidating them into a single contiguous slice beforehand:

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expressionLanguage;

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

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var feed = Chunked{ .chunks = &.{ "12 + ", "34" } };
    const input = treesitter.Input{ .payload = &feed, .read = Chunked.read };
    var tree = try parser.parseWithInput(null, null, input);
    defer tree.deinit();
    std.debug.print("parsed from chunks: {s} error={}\n", .{ tree.rootNode().text(), tree.hasError() });
}
```

### Running Example 1

```bash
zig build run-custom_input
```

### Expected output

```text
parsed from chunks: 12 + 34 error=false
```

---

## Example 2: UTF-16 Encoded Input

Tree-sitter supports UTF-16 LE and BE encoded input streams with automatic on-the-fly transcoding into tree-managed UTF-8, ensuring node byte offsets and positions remain canonical:

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expressionLanguage;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    const utf16 = [_]u8{ 0xFF, 0xFE, '1', 0, ' ', 0, '+', 0, ' ', 0, '2', 0 };
    const State = struct {
        bytes: []const u8,
        fn read(payload: ?*anyopaque, byte_index: u32, position: treesitter.Point, bytes_read: *u32) ?[*]const u8 {
            _ = position;
            const self: *@This() = @ptrCast(@alignCast(payload.?));
            const i: usize = @as(usize, @intCast(byte_index));
            if (i >= self.bytes.len) {
                bytes_read.* = 0;
                return null;
            }
            bytes_read.* = @as(u32, @intCast(self.bytes.len - i));
            return self.bytes.ptr + i;
        }
    };
    var state = State{ .bytes = &utf16 };

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseWithInput(null, null, .{
        .payload = &state,
        .read = State.read,
        .encoding = .utf16_le,
    });
    defer tree.deinit();
    std.debug.print("parsed utf16: {s} error={}\n", .{ tree.rootNode().text(), tree.hasError() });
}
```

### Running Example 2

```bash
zig build run-utf16_parse
```

### Expected output

```text
parsed utf16: 1 + 2 error=false
```

---

## Example 3: Streaming from `std.Io.Reader`

For streaming from files, network sockets, or in-memory fixed buffers without buffering the whole file first, `Parser.parseReader` pulls bytes incrementally through any `*std.Io.Reader` into a caller-supplied buffer:

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expressionLanguage;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    // Fixed or file-backed reader stream
    const source = "base_price * (1 + tax_rate)";
    var reader = std.Io.Reader.fixed(source);
    var chunk_buf: [16]u8 = undefined;

    var tree = try parser.parseReader(&reader, &chunk_buf);
    defer tree.deinit();

    std.debug.print("parsed from reader: {s} error={}\n", .{
        tree.rootNode().text(),
        tree.hasError(),
    });
}
```

### Running Example 3

```bash
zig build run-custom_io
```

### Expected output

```text
parsed from reader: base_price * (1 + tax_rate) error=false
```

## How it works

1. `Input` specifies a `payload`, a `read` callback, and an optional `encoding` (defaulting to `.utf8`).
2. When the lexer requests more source data, `read(payload, byte_index, position, bytes_read)` is invoked.
3. For UTF-16, the stream is automatically transcoded to UTF-8 into tree-managed memory; all subsequent node byte offsets and positions refer to the canonical UTF-8 representation.
4. `Parser.parseReader` adapts any standard library `std.Io.Reader` into a chunked `ReaderSource`, reading only when more tokens are needed and storing canonical UTF-8 in tree-managed memory.

## API used

- [Input](/api/input) — `Input`, `InputEncoding`
- [Parser](/api/parser) — `Parser.parseWithInput`, `Parser.parseStream`, `Parser.parseReader`
- [Input & I/O Reference](/reference/input-io) — `ReaderSource`, `std.Io.Reader`

## Related guides

- [Parsing Source](/guide/parsing-source)
- [Custom Input](/guide/custom-input)
- [Concurrency & I/O](/examples/concurrency)
- [Unicode & Positions](/guide/unicode-and-positions)

