---
description: Upstream conformance — how tree-sitter.zig relates to the reference implementation.
---

# Upstream Conformance

## Relationship

```text
Upstream Tree-sitter (C)
        ↓ studied as a behavioral and algorithmic reference
        ↓ (no code vendored, no symbols linked, no headers imported)
tree-sitter.zig (native Zig)
```

Concepts carried over: table-driven LR parsing with shift/reduce/accept, error-cost recovery with `ERROR`/`MISSING` nodes, reusable-subtree incremental parsing, changed ranges, byte-plus-point coordinates, and structural S-expression queries with captures and predicates.

## What conformance means here

- **Differential corpus** (`src/debug/corpus/`, `zig build conformance`): reference S-expressions for all bundled grammars plus incremental-vs-fresh equality checks. Embedded once and also executed by `zig build test`, so the report and the suite cannot drift.
- **Behavioral tests** assert tree shapes, node properties, ranges, recovery outcomes, reuse counts, and query matches against hand-verified expectations.
- **Deliberate differences** from upstream C: the query engine covers the documented predicate/quantifier/directive subset (no WASM store needed — see below), error costs use a smaller equivalent scale, and scanner snapshots use reset-plus-monotonic-offsets instead of serialize/deserialize. Each is marked in the [Feature Matrix](/compatibility/feature-matrix).

## C library coverage (`tree-sitter/lib/src`)

Every upstream runtime file was studied as a behavioral reference and has a native counterpart below; nothing was wrapped, linked, or vendored (the reference clone has since been removed from this repository):

| Upstream file(s) | Native counterpart | Notes |
|---|---|---|
| `alloc.c/h` | `src/memory/` (allocator, arena, ownership, refcount) | Explicit allocators, no globals |
| `array.h` | `src/utils/array.zig` (+ std `ArrayList`) | |
| `atomic.h` | `std.atomic` via `memory/refcount.zig` | |
| `error_costs.h` | `src/parser/recover.zig` | Equivalent relative costs, smaller scale (1/skip, 2/missing + op budgets) |
| `get_changed_ranges.c/h` | `src/tree/changed_ranges.zig` | Structural minimal diffs |
| `host.h`, `portable/endian.h` | Zig `builtin` + explicit LE/BE in `unicode/utf16.zig` | No platform branches in user code |
| `language.c/h` | `src/language/` (model, symbols, tables, fields, aliases, metadata) | Plus 4 bundled table sets |
| `length.h` | `src/core/position.zig` (`Length`) | |
| `lexer.c/h` | `src/lexer/` + `src/parser/lookahead.zig` | External-first dispatch, per-offset scan cache |
| `lib.c` | `src/treesitter.zig` facade | |
| `node.c` | `src/tree/node.zig` | Handle-based, allocation-free reads |
| `parser.c/h` | `src/parser/` (engine, stack, actions, reduce, recovery, state) | Reuse via sorted interval index |
| `point.c/h` | `src/core/point.zig` | |
| `query.c` | `src/query/` (compiler, matcher, predicates, directives, cursors) | NFA-alternative backtracking matcher, same anchor/predicate semantics |
| `reduce_action.h` | `src/parser/actions.zig`, `reduce.zig` | Alias substitution applied here |
| `reusable_node.h` | `Parser.candidates` + `cloneSubtree` | Contiguous child cloning, scratch discipline |
| `stack.c/h` | `src/parser/stack.zig` | |
| `subtree.c/h` | `src/tree/subtree.zig` | Pooled nodes + child indices |
| `tree.c/h` | `src/tree/tree.zig` (+ `edit.zig`, `sexp.zig`) | Ownership-explicit trees |
| `tree_cursor.c/h` | `src/tree/cursor.zig` | Field tracking included |
| `ts_assert.h` | `src/utils/assertions.zig` | |
| `unicode/*` (ICU tables, utf8/utf16 headers) | `src/unicode/` (tables, utf8, utf16) | Strict decoding; UTF-16 transcode |
| `wasm_store.c/h`, `wasm-stdlib/*` | Intentionally absent | Grammars are native Zig data and scanners are Zig code, so no WASM loader or C shims are needed — including on `wasm32-wasi` itself |

## Related pages

[Development: Conformance](/development/conformance), [Error Recovery](/concepts/error-recovery)
