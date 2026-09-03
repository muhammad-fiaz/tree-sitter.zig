---
description: Debug logging and parse tracing in tree-sitter.zig.
---

# Logging

## What you'll learn

- How to enable level-gated logging and record parse events.

## Complete example

```zig
parser.setLogger(.{ .level = .debug, .prefix = "my-parser" });
// ... parse ...
parser.setLogger(.{}); // back to silent (.off is the default)
```

Levels, in increasing verbosity: `.off`, `.err`, `.warn`, `.info`, `.debug`, `.trace`. Disabled levels compile to a cheap integer comparison — no formatting work happens when logging is off.

For programmatic tracing, attach a `Tracer` (caller-owned) alongside the logger — the parser records structured `TraceEvent`s (`parse_begin`, `shift`, `reduce`, `accept`, `recover`, `lex_token`, `reuse_node`) into it:

```zig
var tracer = treesitter.Tracer.init(gpa, .{ .level = .off });
defer tracer.deinit();
parser.setTracer(&tracer);
// ... parse ...
std.debug.print("events: {d}\n", .{tracer.count()});
parser.setTracer(null); // detach
```

## API used

- [Logging](/api/logging); `debug/logger.zig` and `debug/trace.zig` via `treesitter.debug_mod`.

## Related guides

- [Debugging example](/examples/debugging), [Troubleshooting](/guide/troubleshooting)
