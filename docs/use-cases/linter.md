---
description: Linters on tree-sitter.zig — rules as queries, violations as matches.
---

# Linter

## Problem

Style and correctness rules must run fast on every save with precise locations.

## Why tree-sitter.zig helps

Rules compile once to queries; incremental parsing plus byte-range scoping keeps per-save work tiny.

## API

`Query`, `QueryCursor.setByteRange` (limit to changed ranges), `Node.range`.

## Architecture

```text
Save → incremental parse → changed ranges → run rules on dirty spans → diagnostics
```

## Next steps

- [Static Analysis](/use-cases/static-analysis), [Changed Ranges](/guide/changed-ranges)
