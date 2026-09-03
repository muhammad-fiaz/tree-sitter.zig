---
description: Structural search — find code by shape across files.
---

# Structural Search

## Problem

Text search cannot express "an addition inside a multiplication" or "all calls with three arguments".

## Why tree-sitter.zig helps

Patterns describe nesting directly: `(term (_) @a "*" @op (_) @b)` finds multiplications regardless of formatting.

## API

`Query` with nested patterns, fields, and quantifiers; `QueryCursor` with match limits.

## Architecture

```text
Pattern → compile once → execute per file → ranked matches
```

## Next steps

- [Queries](/guide/queries), [Source Indexing](/use-cases/source-indexing)
