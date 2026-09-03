---
description: Code formatters on tree-sitter.zig — layout from structure.
---

# Formatter

## Problem

Formatters must reproduce code with canonical spacing without changing meaning.

## Why tree-sitter.zig helps

The tree gives exact spans for every construct; named/anonymous distinctions tell layout rules where whitespace is significant.

## API

`TreeCursor` walk emitting `node.text()` plus layout rules per type.

## Architecture

```text
Parse → walk → emit with spacing rules → verify by reparse
```

## Next steps

- [Code Transformation](/use-cases/code-transformation), [Tree Cursors](/guide/tree-cursors)
