---
description: Parse actions — shift, reduce, accept, and recovery in tree-sitter.zig.
---

# Parse Actions

## Simple explanation

Language tables tell the parser what to do for every combination of "current state" and "next token". There are only four moves: shift it, reduce the stack into a node, accept the finished tree, or recover.

## Technical explanation

`language/tables.zig` defines `Action = union { none, shift: u16, reduce: ReduceRule, accept, recover }`, stored per state as sorted `ActionEntry` lists plus `GotoEntry` lists for non-terminals. `table.actionFor(state, symbol)` and `table.gotoState(state, symbol)` are the only queries the engine makes, so any grammar that can be expressed as LR tables — regardless of source language — parses with the same loop. `parser/actions.zig` provides the small predicates (`isShift`, `shiftState`, `reduceRule`, …) the engine uses to dispatch.

## Related pages

- [Parser](/concepts/parser), [Reductions](/concepts/reductions), [Language Tables](/concepts/language-tables)
