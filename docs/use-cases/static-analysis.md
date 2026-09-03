---
description: Static analysis — rule checking over syntax trees.
---

# Static Analysis

## Problem

Lint rules ("no empty blocks", "no magic numbers") need reliable patterns over code shape.

## Why tree-sitter.zig helps

Each rule is a query; violations are matches with exact ranges for diagnostics.

## API

`Query` / `QueryCursor` with `setByteRange` scoping per file region.

## Architecture

```text
Rules as queries → execute per file → matches become diagnostics
```

## Example

`(number) @magic` finds every numeric literal; predicates narrow to suspicious values.

## Next steps

- [Linter](/use-cases/linter), [Query Predicates](/guide/query-predicates)
