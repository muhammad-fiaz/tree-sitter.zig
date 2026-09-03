---
description: Source indexing — project-wide symbol indexes from queries.
---

# Source Indexing

## Problem

Cross-file search needs an index of where every symbol is defined and used.

## Why tree-sitter.zig helps

One compiled query executed per file with a reused cursor produces `(file, range, name)` triples cheaply.

## API

`parser.compileQuery` once; `parser.queryCursor()` reused; `setByteRange` for sharding.

## Architecture

```text
File list → parse each → execute shared query → index triples
```

## Next steps

- [Structural Search](/use-cases/structural-search), [Queries](/guide/queries)
