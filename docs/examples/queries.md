---
description: Query examples — captures over real source with real output.
---

# Queries

## What you'll learn

- Compiling a query once and iterating captures.

## Complete example

`examples/query.zig` over `total + price * count`:

```zig
var query = try parser.compileQuery("(identifier) @var");
defer query.deinit();

var cursor = parser.queryCursor();
defer cursor.deinit();
try cursor.execute(treesitter.expression_language, query.patterns(), query.nodes(), query.captureNames(), &tree);
while (cursor.nextMatch()) |m| {
    for (m.captures) |cap| {
        std.debug.print("@{s}: {s} [{d}, {d}]\n", .{ cap.name, cap.node.text(), cap.node.startByte(), cap.node.endByte() });
    }
}
```

## Running the example

```sh
zig build run-query
```

## Expected output

```text
@var: total [0, 5]
@var: price [8, 13]
@var: count [16, 21]
```

## How it works

The `(identifier)` pattern matches every named `identifier` node at any depth; each match carries one `@var` capture pointing at the node. Numbers and operators never match because the pattern names a specific named type.

## Directives example

`examples/query_directives.zig` shows `#set!` metadata, general directives, and the application helpers:

```sh
zig build run-query_directives
```

```text
setting: kind = variable
directive: select-adjacent! args=2
@x: foo
@x: bar
stripped: ' shopping'
```

## API used

- [Query](/api/query), [Query Cursor](/api/query-cursor).

## Related guides

- [Queries](/guide/queries), [Query Captures](/guide/query-captures), [Query Predicates](/guide/query-predicates)
