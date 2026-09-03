---
description: Structural queries in tree-sitter.zig — patterns, named and anonymous nodes, wildcards, and fields.
---

# Queries

## What you'll learn

- The supported query syntax and how matching works.

## Query syntax at a glance

```scheme
(identifier) @id            ; named node with a capture
"+" @plus                   ; anonymous token
(_) @any                    ; wildcard: any named node
(expression left: (_) @l)   ; field-constrained child
(term)?                     ; ? * + quantifiers on any node
((identifier) @x (#eq? @x "foo")) ; grouped pattern with predicate
```

Top-level patterns match at any depth; nested patterns require a **direct** parent-child relationship. Sibling patterns match in order (gaps allowed unless `.` anchors are used).

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

## Expected output

```text
@var: total [0, 5]
@var: price [8, 13]
@var: count [16, 21]
```

## How it works

```text
Source → Parser → Tree → Query → QueryCursor → Matches → Captures → Application
```

1. `compileQuery` parses the S-expression source once into flat pattern nodes, capture names, predicates, `#set!` settings, and general directives. Compile errors (`UnexpectedToken`, `InvalidPredicate`, `InvalidCapture` for undeclared predicate captures) are reported with no partial state.
2. `execute` walks the tree depth-first, tries every root pattern at every node, and records captures into reusable scratch space. Pattern symbol names resolve to ids once per execution, so hot matching compares integers.
3. Predicates filter matches after structural matching (`eq`/`match` default to all-captured-nodes; `any-` variants need one).

## Memory ownership

Queries own their compiled representation; cursors own their match lists. Both inherit the parser's allocator via the convenience constructors and are reusable across trees.

## API used

- [Query](/api/query), [Query Cursor](/api/query-cursor).

## Related guides

- [Query Captures](/guide/query-captures), [Query Predicates](/guide/query-predicates), [Query Quantifiers](/guide/query-quantifiers), [Query Cursors](/guide/query-cursors)
