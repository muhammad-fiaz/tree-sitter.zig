---
description: System architecture of tree-sitter.zig — subsystem map and dependency direction.
---

# Architecture

```text
                    tree-sitter.zig
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
      Parser             Tree              Query
        │                  │                  │
   ┌────┼────┐       ┌─────┼─────┐       ┌────┼────┐
   │    │    │       │     │     │       │    │    │
 Lexer Stack Actions Node Cursor Edit  Pattern Capture Matcher
   │
 Input
   │
 Unicode
   │
 Language
```

## In plain language

Source text flows downward: input bytes are tokenized by the lexer, assembled into a tree by the parser using language tables, and then read through nodes, cursors, or queries. Edits flow back up: an edit plus an old tree reuses subtrees to build a new tree cheaply.

## Dependency direction

Low-level code never imports high-level code:

```text
utils → core → memory → input/unicode → language → tree → lexer → parser → query
```

`core` (points, ranges, edits, symbols) knows nothing about parsing; `utils` is pure helpers over the standard library. Each subsystem exposes a facade (`parser/parser.zig`, `tree/tree.zig`, …) re-exported by `src/treesitter.zig`.

## Related pages

- [Development: Architecture](/development/architecture), [Development: Source Layout](/development/source-layout)
- [Parser](/concepts/parser), [Memory Model](/concepts/memory-model)
