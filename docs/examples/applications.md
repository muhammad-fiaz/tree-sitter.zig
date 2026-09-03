---
description: Application patterns — highlighting, navigation, analysis, and editor integration with tree-sitter.zig.
---

# Applications

## What you'll learn

- How the primitives compose into syntax highlighting, navigation, indexing, and editor updates.

## Syntax highlighting

Walk with a cursor, classify named nodes by type, and emit spans:

```zig
var cursor = tree.cursor();
defer cursor.deinit();
// gotoFirstChild / gotoNextSibling over the tree;
// switch on node.nodeType(): "identifier" → variable color,
// "number" → constant color, operators → punctuation color.
```

Changed ranges limit repainting to dirty spans after each keystroke.

## Code navigation

`gotoDescendant(offset)` jumps to the node under a click; `parent()` climbs to the enclosing construct; `childByFieldName("left")` pulls out operands. Queries like `(identifier) @id` build document-symbol lists in one pass.

## Source indexing and structural search

Compile project-wide queries once (`(identifier) @name`), execute per file with a reused `QueryCursor`, and record `(file, node.range(), text)` triples. Because matching is structural, renames and reformatting do not break the index the way regex would.

## Editor integration

The incremental loop from [Incremental](/examples/incremental) is the whole protocol: keystroke → `InputEdit` → `parse(old, edit, text)` → `getChangedRanges` → repaint/retokenize only those spans. Parser and cursor reuse keep per-keystroke work proportional to the edit, not the file.

## Related guides

- [Use Cases](/use-cases/) for full problem → architecture → example walkthroughs.
- [Performance](/guide/performance) for budgets.
