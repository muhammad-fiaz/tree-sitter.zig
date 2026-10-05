---
description: Debugging examples — error inspection, logging, and tracing.
---

# Debugging & Error Recovery

## What you'll learn

- Inspecting malformed inputs and error recovery behavior.
- Distinguishing between valid trees, trees with syntax errors, and missing nodes.
- Enabling parser logs and tracing for diagnostic output.

## Example 1: Syntax Error Recovery

This program demonstrates Tree-sitter's resilient error recovery across various malformed inputs (invalid operators, unclosed delimiters, and unrecognized characters), verifying that the parser always returns a usable AST with `tree.hasError() == true`:

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

    for ([_][]const u8{ "1 + * 2", "(1 + 2", "1 @ 2" }) |source| {
        var tree = try parser.parseString(source);
        defer tree.deinit();
        std.debug.print("{s} => has_error={} nodes={d}\n", .{ source, tree.hasError(), tree.nodeCount() });
    }
}
```

### Running Example 1

```bash
zig build run-error_recovery
```

### Expected output

```text
1 + * 2 => has_error=true nodes=11
(1 + 2 => has_error=true nodes=15
1 @ 2 => has_error=true nodes=6
```

---

## Example 2: Lifecycle Tracing & Events

This example attaches a `Tracer` to record shifts, reductions, tokens, and accept lifecycle events directly into memory for test assertions and debugging without writing unrequested output to standard error:

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

    // Attach Tracer to record parse lifecycle events in memory
    var tracer = treesitter.Tracer.init(gpa, .{ .level = .off });
    defer tracer.deinit();
    parser.setTracer(&tracer);

    var tree = try parser.parseString("total + 42");
    defer tree.deinit();

    std.debug.print("Parsed tree has_error={} nodes={d}\n", .{ tree.hasError(), tree.nodeCount() });
    std.debug.print("Tracer recorded {d} lifecycle events:\n", .{tracer.count()});
    for (tracer.entries.items) |entry| {
        std.debug.print("  event: {s} offset={d} sym={d} state={d}\n", .{
            @tagName(entry.event),
            entry.byte_offset,
            entry.symbol,
            entry.state,
        });
    }
}
```

### Running Example 2

```bash
zig build run-logging
```

### Expected output

```text
Parsed tree has_error=false nodes=10
Tracer recorded 16 lifecycle events:
  event: parse_begin offset=0 sym=0 state=0
  event: lex_token offset=0 sym=1 state=0
  event: shift offset=0 sym=1 state=6
  event: reduce offset=0 sym=13 state=4
  event: reduce offset=0 sym=12 state=3
  event: reduce offset=0 sym=11 state=2
  event: lex_token offset=6 sym=3 state=2
  event: shift offset=6 sym=3 state=8
  event: lex_token offset=8 sym=2 state=8
  event: shift offset=8 sym=2 state=5
  event: reduce offset=8 sym=13 state=4
  event: reduce offset=8 sym=12 state=13
  event: reduce offset=0 sym=11 state=2
  event: reduce offset=0 sym=10 state=1
  event: accept offset=10 sym=0 state=1
  event: parse_end offset=10 sym=10 state=1
```

## How it works

1. `1 + * 2` contains adjacent binary operators; the parser recovers by creating an `ERROR` node for the unexpected `*` and completing the expression with `2`.
2. `(1 + 2` is missing a closing parenthesis; Tree-sitter recovers by inserting a zero-width `MISSING` `)` node at EOF so that the syntax tree remains well-formed.
3. `1 @ 2` has an unrecognized character `@`; the lexer skips the invalid byte and parsing resumes at the next valid token.
4. `Tracer` records every shift, reduction, lex token, and accept event into an in-memory buffer without printing unrequested output to standard error, making it suitable for diagnostic inspections and test assertions.

## API used

- [Parser](/api/parser) — `Parser.init`, `Parser.setLanguage`, `Parser.parseString`, `Parser.setTracer`, `Parser.setLogger`
- [Tree](/api/tree) — `Tree.hasError`, `Tree.nodeCount`
- [Node](/api/node) — `Node.isError`, `Node.isMissing`
- [Tracer](/api/logging) — `Tracer.init`, `Tracer.count`, `Tracer.entries`

## Related guides

- [Error Recovery Guide](/guide/error-recovery)
- [Logging & Tracing](/guide/logging)
- [Troubleshooting](/guide/troubleshooting)
