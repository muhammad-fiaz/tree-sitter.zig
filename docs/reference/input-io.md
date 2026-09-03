---
description: Input and I/O reference — sources, lifetimes, buffering, and std.Io.
---

# Input & I/O

## Sources

| Source | Lifetime | Copying |
|--------|----------|---------|
| `parseString([]const u8)` | Caller slice needed only during the call | One copy into the tree |
| `Input` callback | Payload live during the call | Buffered once by `parseWithInput` |
| `ReaderSource` (`std.Io.Reader`) | Reader + buffer live during the call | Buffered once (`parseWithInput`) or incremental (`parseStream`) |
| `parseStream` | Payload live during the call | No pre-buffering; pull buffer becomes the tree source |
| UTF-16 `Input` (`.utf16_le` / `.utf16_be`) | Payload live during the call | Transcoded to UTF-8 up front; tree offsets refer to the UTF-8 form |

## `std.Io` relationship

The core memory path performs no I/O at all. `ReaderSource` consumes the Zig 0.16.0 `std.Io.Reader` interface (`readSliceShort` and friends, verified against `lib/std/Io/Reader.zig`); the benchmark clock uses `std.Io.Timestamp` on the monotonic clock; debug logging goes through `std.debug.print` (which itself rides the 0.16 `Io` plumbing). No legacy `std.io` APIs are used anywhere.

## What the library does not do

- No filesystem access on any parse path.
- No hidden buffering beyond the documented single copy/buffer.
- No decoding beyond UTF-8 and UTF-16 (`InputEncoding.custom` is raw bytes; tree offsets always refer to UTF-8).

## Related pages

[Parsing Source](/guide/parsing-source), [Custom Input](/guide/custom-input), [Input API](/api/input)
