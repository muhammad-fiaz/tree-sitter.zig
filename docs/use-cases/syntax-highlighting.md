---
description: Syntax highlighting with tree-sitter.zig — token classification and incremental repaint.
---

# Syntax Highlighting

## Problem

Highlighters must classify every token correctly even while the user is mid-keystroke and the code does not parse cleanly.

## Why tree-sitter.zig helps

Error recovery keeps a full tree available at all times, and changed ranges say exactly which spans need repainting.

## API

`Parser.parse` → `Tree` → `TreeCursor` walk → `getChangedRanges` per edit.

## Architecture

```text
Keystroke → InputEdit → incremental parse → changed ranges
   → re-walk dirty spans → classify by nodeType → repaint
```

## Example

Walk dirty nodes with `tree.cursor()`; map `identifier` → variable face, `number` → constant face, anonymous operators → punctuation face, `ERROR` nodes → error face.

## Output

Only the edited expression re-tokenizes; the rest of the buffer keeps its faces.

## Next steps

- [Tree Cursors](/guide/tree-cursors), [Changed Ranges](/guide/changed-ranges)
- [Code Editor](/use-cases/code-editor)
