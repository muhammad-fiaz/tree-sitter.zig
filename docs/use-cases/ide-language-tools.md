---
description: IDE language tools — hover, go-to-definition, and document symbols via queries.
---

# IDE Language Tools

## Problem

Hover, go-to-definition, and symbol lists need precise, fast answers about the code under the cursor.

## Why tree-sitter.zig helps

`gotoDescendant(offset)` answers "what is under the cursor" in one dive; compiled queries answer "every X in this file" in one walk.

## API

`TreeCursor.gotoDescendant`, `Node.parent`, `Query` + `QueryCursor`.

## Architecture

```text
Cursor event → gotoDescendant → parent chain → definition lookup
File open → execute (identifier) @id → document symbols
```

## Example

```zig
var cursor = tree.cursor();
defer cursor.deinit();
cursor.gotoDescendant(click_byte);
const def_node = cursor.currentNode().parent();
```

## Next steps

- [Code Navigation](/use-cases/code-navigation), [Queries](/guide/queries)
