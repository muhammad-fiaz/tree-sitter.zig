---
description: Troubleshoot common tree-sitter.zig problems — setup, parsing, queries, and memory.
---

# Troubleshooting

## `error.NoLanguage` from parse

Call `setLanguage` first. It also validates the ABI — `IncompatibleAbiVersion` means the tables target an ABI outside 13–15.

## Tree has errors on input I expected to parse

- Print the tree (`examples/tree_walk.zig` pattern) and look for `ERROR` / `MISSING` nodes.
- Check token coverage: characters no matcher accepts become skipped error bytes.
- Check table coverage: the grammar tables must define an action for every reachable `(state, token)` pair.

## Query compiles but matches nothing

- Top-level patterns match anywhere, but nested patterns need **direct** children — `(program (number))` fails when a `number` is nested deeper.
- Anonymous tokens match only non-named nodes; `(+)` never matches an `identifier`.
- Field names must come from the language's field map for that production.

## Query compile errors

- `UnexpectedToken` usually means unbalanced parentheses or a stray `!` assertion.
- `InvalidPredicate` means the `#name?` is unknown — see the [supported list](/guide/query-predicates).
- An empty query source is `UnexpectedEof`, not an empty query.

## Changed ranges are empty after an edit

Same-span text substitutions (e.g. `2` → `3`) change no positions or structure, so there is structurally nothing to report. Insertions, deletions, and span changes report normally.

## Leaks reported by the testing allocator

Every owning object needs `deinit`: parser, trees, cursors, queries, query cursors, and changed-range slices. Nodes never need cleanup.

## Still stuck?

- Enable `parser.setLogger(.{ .level = .debug })` and re-run.
- Open an issue at the [repository](https://github.com/muhammad-fiaz/tree-sitter.zig/issues) with the source, the grammar tables version, and the tree dump.
