---
description: Code navigation — definitions, references, and enclosing scopes.
---

# Code Navigation

## Problem

Jumping between a use and its definition requires understanding scope structure, not text.

## Why tree-sitter.zig helps

Parent chains give you enclosing scopes; queries collect candidate definitions; byte ranges give you jump targets.

## API

`Node.parent`, `descendantForByteRange`, `Query` captures.

## Architecture

```text
Symbol at offset → namedDescendantForByteRange → parent scopes
  → query definitions in scope → jump to range
```

## Next steps

- [IDE Language Tools](/use-cases/ide-language-tools), [Navigating Nodes](/guide/navigating-nodes)
