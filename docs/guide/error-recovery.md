---
description: Error recovery in tree-sitter.zig — ERROR nodes, MISSING nodes, and inspecting broken syntax.
---

# Error Recovery

## What you'll learn

- What the parser produces for malformed source and how to inspect it.

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

- **Unexpected tokens** are skipped and the skipped span becomes an `ERROR` leaf (named, `isError()`, `hasError()` set). Skipping accrues an error cost per byte, bounded by a maximum recovery budget.
- **Unexpected end of input** inserts a zero-width `MISSING` token for the expected symbol (e.g. the missing `)` in `(1 + 2`) and continues parsing, so unclosed constructs still produce structured trees.
- **Unrecoverable states** fall back to wrapping all fragments in a root node marked `hasError()`, so a tree is always returned — parsing never fails just because the source is broken.
- `tree.hasError()` / `node.hasError()` flag tainted subtrees; walk children for `isError()` / `isMissing()` to pinpoint problems for diagnostics.

## API used

- [Tree](/api/tree) — `hasError`; [Node](/api/node) — `isError`, `isMissing`, `hasError`; [Errors](/api/errors).

## Related guides

- [Testing](/guide/testing) for asserting recovery behavior, [Troubleshooting](/guide/troubleshooting).
- [Error Recovery](/concepts/error-recovery), [Upstream Conformance](/internals/upstream-conformance).
