---
description: Logging API — levels, Logger, and parse tracing.
---

# Logging

## Overview

Level-gated diagnostics plus structured parse-event tracing. Sources: `src/debug/logger.zig`, `src/debug/trace.zig`.

## Logger

```zig
pub const Level = enum(u8) { off = 0, err = 1, warn = 2, info = 3, debug = 4, trace = 5 };
pub const Logger = struct {
    level: Level = .off,
    prefix: []const u8 = "treesitter",
    pub fn enabled(self: Logger, level: Level) bool
    pub fn log / err / warn / info / debug / trace(self: Logger, comptime fmt: []const u8, args: anytype) void
    pub fn writeToIo(self: Logger, writer: *std.Io.Writer, level: Level, comptime fmt: []const u8, args: anytype) void
};
pub const null_logger: Logger  // .off
```

Default `.off` costs one integer comparison per site. The parser logs lifecycle (`info`: parse start/end with sizes and reuse counts), reuse/error spans (`debug`), recovery skips (`trace`), and every shift/reduce (`trace`) — all client-controlled via `Parser.setLogger`. Levels can be flipped mid-session; `.off` silences everything.

## Tracer

```zig
pub const TraceEvent = enum { parse_begin, parse_end, shift, reduce, accept, recover, lex_token, reuse_node };
pub const Tracer = struct {
    pub fn init(gpa: Allocator, logger: Logger) Tracer
    pub fn deinit(self: *Tracer) void
    pub fn record(self: *Tracer, event: TraceEvent, byte_offset: u32, symbol: u16, state: u16) void
    pub fn count(self: *const Tracer) usize
};
```

Attach with `Parser.setTracer(&tracer)` (borrowed: the caller owns it and keeps it alive across parses). The parser records begin/end, shift/reduce/accept, recovery, and reuse events; the tracer's own logger gates the text side independently. Pass `null` to detach.

## Related pages

[Logging](/guide/logging), [Parser](/api/parser) — `setLogger`
