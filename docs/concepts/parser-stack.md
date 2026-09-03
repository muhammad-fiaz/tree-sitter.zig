---
description: The parser stack — parallel state and value stacks in tree-sitter.zig.
---

# Parser Stack

## Simple explanation

While parsing, the engine keeps a stack of "where am I in the grammar" states alongside the half-built tree pieces. Reductions pop finished pieces off and push back a single combined node.

## Technical explanation

`parser/stack.zig` holds two parallel `ArrayList`s — `states: []u16` and `values: []u32` (subtree indices) — kept in lockstep by `push`/`pop`/`popMany`. The stack starts with the grammar's start state; a shift pushes one entry and a reduce of N children pops N entries before pushing the goto target. Both lists live on the `Parser` and are cleared (capacity retained) between parses, which is why parser reuse is cheap.

## Related pages

- [Parser](/concepts/parser), [Parse Actions](/concepts/parse-actions), [Stack Runtime](/internals/stack-runtime)
