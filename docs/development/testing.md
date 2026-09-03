---
description: Testing reference — inline tests, corpus, fuzz, and quality gates.
---

# Testing

All tests live inline at the bottom of the source file that implements the functionality — there is no separate `tests/` tree, and examples never double as tests. `zig build test` compiles `src/treesitter.zig` as a test root, which pulls in every inline suite: parser, recovery, stack, tree, node, cursor, edits, changed ranges, queries, matcher, predicates, directives, anchors, negated fields, lexer, unicode (UTF-8 + UTF-16), allocators, ownership, input/streaming/reader, languages (expression, sexp, JSON, outline, scanner), sexp serializer, conformance corpus, public API, plus pure unit tests for core types (points, ranges, edits), the cost model, logging, and the corpus-format parser.

Conventions: `std.testing.allocator` everywhere (leaks fail the run), `failing_allocator` for `OutOfMemory` propagation, structural assertions (S-expression equality for incremental-vs-fresh, spans, counts) over weak proxies, and incremental tests that assert reuse counts plus structural equality with fresh parses.

Beyond unit tests:

- `zig build conformance` — differential corpus (`src/debug/corpus/`): reference S-expressions plus incremental-vs-fresh checks.
- `zig build fuzz` — seeded parser/query fuzzer (`--iterations=N --seed=N`).
- `zig build bench` — parse/traversal/query benchmark over a generated corpus.
- Cross-target compilation is validated across the 8 supported targets.

Related: [Testing guide](/guide/testing), [Benchmarks](/development/benchmarks), [Conformance](/development/conformance), [Fuzzing](/development/fuzzing).
