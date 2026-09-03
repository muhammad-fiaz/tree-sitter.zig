---
description: Testing tree-sitter.zig — suite layout, allocation-failure tests, and writing your own tests.
---

# Testing

## What you'll learn

- How the test suite is organized and how to test your own grammars and integrations.

## Layout

Tests live inline at the bottom of the source file that implements the functionality — there is no separate `tests/` tree:

```text
src/parser/parser.zig    parser, recovery, edits, changed ranges, integration, ranges, streaming, sexp, json, outline, predicates, corpus
src/parser/stack.zig     stack
src/tree/tree.zig        tree properties, copies, ownership
src/tree/node.zig        navigation, fields, ranges
src/tree/cursor.zig      traversal, siblings, reset, copy
src/query/query.zig      queries, matcher semantics, anchors, directives, strictness
src/query/predicate.zig  predicate evaluation (eq/match/contains/any-of/is)
src/query/matcher.zig    subtype expansion, id resolution
src/query/directives.zig select-adjacent, strip
src/language/language.zig metadata, symbols, fields, aliases
src/language/json.zig    string/number matchers
src/language/outline_scanner.zig newline/indent/dedent/blank scanning
src/input/*              chunked, reader, streaming, and UTF-16 sources
src/unicode/utf16.zig    BOM, surrogates, transcoding
src/debug/conformance.zig corpus-format parsing
...plus pure unit tests for core types, costs, logging, codecs, and arenas
```

Plus smoke tests at the bottom of `src/treesitter.zig`. Run everything with:

```sh
zig build test
```

## Allocation-failure testing

The suite uses `std.testing.failing_allocator` to prove `OutOfMemory` propagates cleanly, and `std.testing.allocator` everywhere else so any leak fails the run:

```zig
var parser = treesitter.Parser.init(std.testing.failing_allocator);
defer parser.deinit();
try parser.setLanguage(treesitter.expression_language);
try std.testing.expectError(error.OutOfMemory, parser.parseString("1 + 2"));
```

## Testing your integration

- Parse representative valid sources and assert `!tree.hasError()` plus key node types and ranges.
- Parse broken sources and assert `hasError()` with `isError()` / `isMissing()` where you surface diagnostics.
- Round-trip incremental edits and assert the result equals a fresh parse.
- Compile queries once in setup; assert `matchCount()` and capture texts.

## Related pages

- [Development: Testing](/development/testing), [Troubleshooting](/guide/troubleshooting)
