---
description: Query examples — captures and directives over real source with real output.
---

# Queries

## What you'll learn

- Compiling S-expression patterns with captures (`@name`).
- Executing queries over trees using `QueryCursor`.
- Inspecting pattern metadata and directives (`#set!`, `#select-adjacent!`, `#strip-text!`).

## Example 1: Basic Captures

This program demonstrates S-expression pattern compilation and execution with `QueryCursor`, capturing all `(identifier)` nodes as `@var` and iterating over matches:

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

    var tree = try parser.parseString("total + price * count");
    defer tree.deinit();

    var query = try parser.compileQuery("(identifier) @var");
    defer query.deinit();

    var cursor = parser.queryCursor();
    defer cursor.deinit();
    try cursor.execute(grammar, query.patterns(), query.nodes(), query.captureNames(), &tree);

    while (cursor.nextMatch()) |m| {
        for (m.captures) |cap| {
            std.debug.print("@{s}: {s} [{d}, {d}]\n", .{ cap.name, cap.node.text(), cap.node.startByte(), cap.node.endByte() });
        }
    }
}
```

### Running Example 1

```bash
zig build run-query
```

### Expected output

```text
@var: total [0, 5]
@var: price [8, 13]
@var: count [16, 21]
```

---

## Example 2: Query Directives and Metadata

Tree-sitter queries support directives such as `#set!` for passing metadata to tooling, alongside custom filter predicates like `#select-adjacent!` and `#strip-text!`:

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

    var tree = try parser.parseString("foo + bar");
    defer tree.deinit();

    var query = try parser.compileQuery("((identifier) @x (#set! kind \"variable\") (#select-adjacent! @x @x))");
    defer query.deinit();

    for (query.propertySettings(0)) |setting| {
        std.debug.print("setting: {s} = {s}\n", .{ setting.key, setting.value orelse "(none)" });
    }
    for (query.generalPredicates(0)) |directive| {
        std.debug.print("directive: {s} args={d}\n", .{ directive.operator, directive.args.len });
    }

    var cursor = parser.queryCursor();
    defer cursor.deinit();
    try cursor.execute(grammar, query.patterns(), query.nodes(), query.captureNames(), &tree);
    while (cursor.nextMatch()) |m| {
        const kept = try treesitter.query_mod.directives.selectAdjacent(gpa, m.captures, 0, 0);
        defer gpa.free(kept);
        for (kept) |cap| std.debug.print("@{s}: {s}\n", .{ cap.name, cap.node.text() });
    }

    const stripped = try treesitter.query_mod.directives.stripText(gpa, "## shopping", "^#+");
    defer gpa.free(stripped);
    std.debug.print("stripped: '{s}'\n", .{stripped});
}
```

### Running Example 2

```bash
zig build run-query_directives
```

### Expected output

```text
setting: kind = variable
directive: select-adjacent! args=2
@x: foo
@x: bar
stripped: ' shopping'
```

## How it works

1. `parser.compileQuery` parses the S-expression query pattern, extracts captures, and verifies that the symbols belong to the active language.
2. `cursor.execute(...)` sets the query parameters and prepares the matcher.
3. `cursor.nextMatch()` yields each successful match with all associated captured nodes.
4. `#set!` assigns key-value properties to the pattern, which can be retrieved through `query.propertySettings(pattern_index)`.

## API used

- [Query](/api/query) — `Query.compile`, `Query.patterns`, `Query.captureNames`, `Query.propertySettings`, `Query.generalPredicates`
- [Query Cursor](/api/query-cursor) — `QueryCursor.init`, `QueryCursor.execute`, `QueryCursor.nextMatch`, `QueryCursor.nextCapture`

## Related guides

- [Queries Guide](/guide/queries)
- [Query Captures](/guide/query-captures)
- [Query Predicates](/guide/query-predicates)
