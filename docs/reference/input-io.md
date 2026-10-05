---
description: Input and I/O reference — sources, lifetimes, buffering, std.Io polymorphic contexts, and multi-threading.
---

# Input & I/O

## Sources & Lifetimes

| Source | Lifetime | Buffering & Copying |
|--------|----------|---------------------|
| `parseString([]const u8)` | Caller slice needed only during the call | One copy into tree-managed storage |
| `parseReader(*std.Io.Reader, []u8)` | Reader and buffer live during the call | Chunks buffered into tree-managed storage |
| `Input` callback | Payload live during the call | Buffered once by `parseWithInput` |
| `ReaderSource` (`std.Io.Reader`) | Reader + buffer live during the call | Buffered once (`parseWithInput`) or incremental (`parseStream`) |
| `parseStream` | Payload live during the call | Incremental on-demand pull; pull buffer transferred to tree with zero extra copy |
| UTF-16 `Input` (`.utf16_le` / `.utf16_be`) | Payload live during the call | Transcoded to UTF-8 up front; tree offsets refer to UTF-8 |

---

## Polymorphic `std.Io` Contexts

The runtime integrates natively with Zig 0.17.0's polymorphic `std.Io` system:

- **Configurable Context**: Every `Parser` can receive an explicit `std.Io` via `parser.setIo(io_ctx)`.
- **Default Fallback**: If unset, `parser.getIo()` gracefully falls back to `std.Io.Threaded.global_single_threaded.io()`.
- **Custom & Multi-threaded I/O**: Callers can supply multi-threaded threaded contexts (`std.Io.Threaded.init`), async event loops, or custom mock interfaces.
- **Timeouts & Clocks**: Clock lookups (`std.Io.Timestamp.now(parser.getIo(), .awake)`) execute against the configured I/O interface.
- **Graphviz DOT Output**: `tree.writeDotGraph(writer)` writes directly to any `*std.Io.Writer`, and `tree.printDotGraphToFile(io, file)` writes to a `std.Io.File` with explicit I/O handle management.

---

## Multi-Threading & Concurrency Model

`tree-sitter.zig` is designed for high-concurrency production workloads:

1. **Parser Thread Isolation**:
   - Each `Parser` instance maintains internal scratch stacks, pools, and reuse tables.
   - Multiple `Parser` instances can run concurrently across OS threads without shared mutable state or global locks.

2. **Immutable Trees**:
   - Once returned by `parseString`, `parseReader`, or `parseStream`, a `Tree` is completely immutable.
   - Multiple worker threads can read the same `Tree`, traverse it with independent `TreeCursor` instances, and execute queries with independent `QueryCursor` instances concurrently without synchronization overhead.

3. **Immutable Queries**:
   - Compiled `Query` objects are read-only patterns.
   - A single `Query` can be shared across arbitrary threads simultaneously while each thread executes it with its own `QueryCursor`.

4. **Caller-Controlled Ownership**:
   - Memory is strictly allocated via the caller-supplied `std.mem.Allocator`.
   - I/O streams (`std.Io.Reader`, `std.Io.Writer`, `std.Io.File`) remain owned by the caller.

---

## What the library does not do

- No unrequested filesystem or network access.
- No hidden background threads or unbounded worker pools.
- No global locks or thread-unsafe global state.
- No legacy `std.io` APIs (`std.Io` only).

## Related pages

[Parsing Source](/guide/parsing-source), [Custom Input](/guide/custom-input), [Input API](/api/input), [Parser API](/api/parser)
