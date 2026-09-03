---
description: Documentation generation from syntax trees.
---

# Documentation Generation

## Problem

API docs need signatures, not prose guesses — parameter lists, return positions, nesting.

## Why tree-sitter.zig helps

Queries extract declarations structurally; ranges map them back to source for linked output.

## API

`Query` captures for declaration shapes; `Node.text` and `range` for rendering. `#set!` settings travel on patterns (`query.propertySettings`), while `#select-adjacent!` / `#strip!` apply through `query.directives.selectAdjacent` / `stripText` — the native equivalent of the tags-crate doc pipeline (see `examples/query_directives.zig`).

## Architecture

```text
Parse → query declarations → render signatures → link to ranges
```

## Next steps

- [Source Indexing](/use-cases/source-indexing), [Queries](/guide/queries)
