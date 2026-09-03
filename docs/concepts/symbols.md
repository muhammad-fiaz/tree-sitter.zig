---
description: Symbols — terminals, non-terminals, visibility, named status, and extras.
---

# Symbols

## Simple explanation

Every distinct thing in a grammar — a keyword, an identifier, an expression — gets a numeric id called a *symbol*. Symbols say whether a node is named (structural) or anonymous (punctuation), visible, or an extra like whitespace.

## Technical explanation

`language/symbols.zig` defines `SymbolInfo { id, name, kind, metadata }` with kinds `terminal`, `non_terminal`, `external`, and `end`. Metadata flags: `visible` (appears in trees), `named` (structural vs punctuation), `supertype` (abstract grouping symbol), `extra` (skipped/attached outside the grammar proper). `core/symbol.zig` provides the shared `Symbol` / `SymbolId` vocabulary (`0` = end). The `Language` helpers (`symbolName`, `symbolIsNamed`, `symbolForName`, …) are what nodes and queries use to resolve ids to names.

## Related pages

- [Nodes](/concepts/nodes), [Fields](/concepts/fields), [Aliases](/concepts/aliases)
- [Symbols API](/api/symbols)
