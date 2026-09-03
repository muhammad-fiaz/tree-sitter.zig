---
description: Debugging examples — error inspection, logging, and tracing.
---

# Debugging

## What you'll learn

- Turning broken parses into actionable diagnostics.

## Complete example

`examples/error_recovery.zig`:

```zig
for ([_][]const u8{ "1 + * 2", "(1 + 2", "1 @ 2" }) |source| {
    var tree = try parser.parseString(source);
    defer tree.deinit();
    std.debug.print("{s} => has_error={} nodes={d}\n", .{ source, tree.hasError(), tree.nodeCount() });
}
```

## Expected output

```text
1 + * 2 => has_error=true nodes=11
(1 + 2 => has_error=true nodes=15
1 @ 2 => has_error=true nodes=6
```

## How it works

Each input exercises a different recovery path: a skipped operator becomes an `ERROR` leaf, the unclosed paren gains a zero-width `MISSING` `)`, and the illegal `@` byte is skipped. Pair this with `parser.setLogger(.{ .level = .debug })` to watch shifts, reductions, and recovery events while diagnosing grammar-table gaps.

## API used

- [Tree](/api/tree), [Node](/api/node), [Errors](/api/errors), [Logging](/api/logging).

## Related guides

- [Error Recovery](/guide/error-recovery), [Logging](/guide/logging), [Troubleshooting](/guide/troubleshooting)
