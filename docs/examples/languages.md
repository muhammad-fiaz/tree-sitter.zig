---
description: Language examples — inspecting symbols, tables, fields, and parsing bundled grammars.
---

# Languages

## What you'll learn

- Introspecting grammar metadata (ABI version, symbol counts, state counts).
- Enumerating symbols and inspecting their named/visible properties.
- Resolving symbol IDs and field IDs by name.
- Parsing S-Expressions with aliased node substitutions.
- Parsing JSON data structures with field child navigation.
- Implementing indentation-sensitive parsing using stateful external scanners.

---

## Example 1: Language Introspection

This example introspects static grammar tables, querying ABI versioning, counting symbols and parse states, and resolving tokens and field IDs by name:

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expressionLanguage;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    _ = gpa_state.allocator();

    const lang = grammar;
    std.debug.print("language: {s} abi={d} symbols={d} states={d}\n", .{
        lang.metadata.name,
        lang.metadata.abiVersion(),
        lang.symbolCount(),
        lang.table.stateCount(),
    });
    for (lang.symbols) |sym| {
        std.debug.print("  #{d} {s} named={} visible={}\n", .{ sym.id, sym.name, sym.metadata.named, sym.metadata.visible });
    }
    const plus = lang.symbolForName("+", false).?;
    std.debug.print("symbol for \"+\": {d}\n", .{plus});
    const left = lang.fieldIdForName("left").?;
    std.debug.print("field id for \"left\": {d} ({s})\n", .{ left, lang.fieldNameForId(left).? });
}
```

### Running Example 1

```bash
zig build run-language
```

### Expected output

```text
language: expression abi=15 symbols=15 states=18
  #0 end named=false visible=false
  #1 identifier named=true visible=true
  #2 number named=true visible=true
  #3 + named=false visible=true
  #4 - named=false visible=true
  #5 * named=false visible=true
  #6 / named=false visible=true
  #7 ( named=false visible=true
  #8 ) named=false visible=true
  #9 whitespace named=false visible=false
  #10 program named=true visible=true
  #11 expression named=true visible=true
  #12 term named=true visible=true
  #13 factor named=true visible=true
  #14 ERROR named=true visible=true
symbol for "+": 3
field id for "left": 1 (left)
```

---

## Example 2: S-Expressions with Dynamic Aliasing

This program parses nested S-Expressions and demonstrates dynamic node aliasing, where concrete syntax groups are assigned semantic symbol names (`sequence`) for pattern matching:

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.sexp_language;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseString("(add 1 (mul 2 3))");
    defer tree.deinit();

    const root = tree.rootNode();
    std.debug.print("root: {s} [{d}, {d}]\n", .{ root.nodeType(), root.startByte(), root.endByte() });
    const seq = root.child(0).?.child(0).?.child(1).?;
    std.debug.print("grouped list aliased to: {s} text='{s}'\n", .{ seq.nodeType(), seq.text() });

    var query = try parser.compileQuery("(sequence) @list");
    defer query.deinit();
    var cursor = parser.queryCursor();
    defer cursor.deinit();
    try cursor.execute(grammar, query.patterns(), query.nodes(), query.captureNames(), &tree);
    std.debug.print("sequence matches: {d}\n", .{cursor.matchCount()});
}
```

### Running Example 2

```bash
zig build run-sexp_parse
```

### Expected output

```text
root: program [0, 17]
grouped list aliased to: sequence text='add 1 (mul 2 3)'
sequence matches: 2
```

---

## Example 3: JSON Parsing & Field Child Queries

This example parses JSON objects, arrays, and literals, utilizing field ID queries to navigate key-value pairs and extracting string literals:

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.json_language;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseString("{\"name\": \"ada\", \"scores\": [10, 20.5, -3e-2], \"admin\": true}");
    defer tree.deinit();

    const root = tree.rootNode();
    std.debug.print("root: {s} has_error={}\n", .{ root.nodeType(), tree.hasError() });

    var pair_query = try parser.compileQuery("(pair) @p");
    defer pair_query.deinit();
    var pair_cursor = parser.queryCursor();
    defer pair_cursor.deinit();
    try pair_cursor.execute(grammar, pair_query.patterns(), pair_query.nodes(), pair_query.captureNames(), &tree);
    const first = pair_cursor.nextMatch().?.captures[0].node;
    std.debug.print("first pair: key={s} value={s}\n", .{
        first.childByFieldName("key").?.text(),
        first.childByFieldName("value").?.text(),
    });

    var query = try parser.compileQuery("(string) @s");
    defer query.deinit();
    var cursor = parser.queryCursor();
    defer cursor.deinit();
    try cursor.execute(grammar, query.patterns(), query.nodes(), query.captureNames(), &tree);
    std.debug.print("strings: {d}\n", .{cursor.matchCount()});
    while (cursor.nextMatch()) |m| {
        std.debug.print("  {s}\n", .{m.captures[0].node.text()});
    }
}
```

### Running Example 3

```bash
zig build run-json_parse
```

### Expected output

```text
root: program has_error=false
first pair: key="name" value="ada"
strings: 4
  "name"
  "ada"
  "scores"
  "admin"
```

---

## Example 4: Outline Parser with External Scanner

This program configures an indentation-sensitive outline language where block structure is tracked across newlines and indent/dedent levels by an external scanner:

```zig
const std = @import("std");
const treesitter = @import("treesitter");

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();

    var lang = treesitter.outline_language;
    var scan_state = treesitter.OutlineScanState.init(gpa);
    defer scan_state.deinit();
    lang.external_scanner.?.payload = &scan_state;
    try parser.setLanguage(lang);

    var tree = try parser.parseString("# Shopping\n  # Fruit\n  - pears\n- bread\n");
    defer tree.deinit();

    const root = tree.rootNode();
    std.debug.print("root: {s} has_error={}\n", .{ root.nodeType(), tree.hasError() });

    var query = try parser.compileQuery("(header) @h");
    defer query.deinit();
    var cursor = parser.queryCursor();
    defer cursor.deinit();
    try cursor.execute(lang, query.patterns(), query.nodes(), query.captureNames(), &tree);
    while (cursor.nextMatch()) |m| {
        std.debug.print("header: {s}\n", .{m.captures[0].node.text()});
    }
}
```

### Running Example 4

```bash
zig build run-external_scanner
```

### Expected output

```text
root: program has_error=false
header: # Shopping
header: # Fruit
```

---

## How it works

1. `Language` is a static, read-only structure holding the parse tables, lexer tables, symbol metadata, and field maps.
2. `lang.symbolCount()` returns the total number of terminals, non-terminals, and auxiliary symbols.
3. `lang.symbolForName("+", false)` resolves the symbol ID for anonymous tokens.
4. `lang.fieldIdForName("left")` maps human-readable field names used in queries and node access to numeric IDs for $O(1)$ lookups.
5. In S-Expressions, aliasing allows concrete syntax groups to be mapped dynamically to queryable symbol names (`sequence`).
6. In JSON, field IDs enable extracting child nodes by semantic role (`key`, `value`).
7. In Outline, stateful indentation (`indent`, `dedent`, `newline`, `blank`) is produced by caller-configured external scanner instances.

## API used

- [Language](/api/language) — `Language.symbolCount`, `Language.symbolForName`, `Language.fieldIdForName`, `Language.fieldNameForId`
- [Symbols](/api/symbols) — `Symbol`
- [Fields](/api/fields) — `FieldId`
- [External Scanners](/concepts/external-scanners) — `ExternalScanner`, `OutlineScanState`

## Related guides

- [Language Definition](/guide/language-definition)
- [Grammar & Language](/concepts/grammar-language)
- [Language Tables](/concepts/language-tables)
- [External Scanners](/guide/external-scanners)
