---
description: Refactoring tools — find, verify, and rewrite code structurally.
---

# Refactoring Tools

## Problem

Renames and structural edits must touch every real occurrence and nothing else — comments and strings that merely mention a name must be left alone.

## Why tree-sitter.zig helps

Queries return only structural matches (identifiers in code positions, never inside unrelated tokens), each with an exact byte range to rewrite.

## API

`Query` with predicates (`#eq?` on the old name), `Node.range`, incremental reparse to verify.

## Architecture

```text
Query old name → ranges → apply text edits → reparse → no stale matches
```

## Next steps

- [Structural Search](/use-cases/structural-search), [Code Transformation](/use-cases/code-transformation)
