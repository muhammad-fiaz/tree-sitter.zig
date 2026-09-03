---
description: Source code analysis — metrics and structure extraction from syntax trees.
---

# Source Code Analysis

## Problem

Counting constructs, measuring nesting, and extracting structure from text with regex breaks on nesting and comments.

## Why tree-sitter.zig helps

The tree already encodes nesting; a cursor walk with depth tracking yields exact metrics.

## API

`TreeCursor` (`depth`, `nodeType`), `Node.descendantCount`.

## Architecture

```text
Parse → cursor walk → classify by type → aggregate metrics
```

## Example

Count binary operations and max nesting depth in one pass over `a + b * (c - d)`.

## Next steps

- [Static Analysis](/use-cases/static-analysis), [Tree Cursors](/guide/tree-cursors)
