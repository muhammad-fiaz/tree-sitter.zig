---
description: Dependency analysis — imports and references from syntax structure.
---

# Dependency Analysis

## Problem

Build tools and reviewers need the real dependency graph, not grep approximations.

## Why tree-sitter.zig helps

Import statements are structural nodes; queries extract exactly their operands.

## API

`Query` captures over import-like productions; `Node.text` for operands.

## Architecture

```text
Parse → query imports → resolve operands → graph edges
```

## Next steps

- [Source Indexing](/use-cases/source-indexing), [Documentation Generation](/use-cases/documentation-generation)
