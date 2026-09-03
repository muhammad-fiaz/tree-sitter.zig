---
description: Building a code editor backend on tree-sitter.zig — the incremental loop.
---

# Code Editor

## Problem

Every keystroke must update highlighting, folding, and diagnostics in milliseconds on large files.

## Why tree-sitter.zig helps

One long-lived `Parser` plus per-keystroke `InputEdit`s keeps reparse work proportional to the edit. Reuse counters (`reused_node_count`) let you verify the budget in production.

## API

`Parser` (reused), `InputEdit`, `Tree`, `getChangedRanges`, `TreeCursor`.

## Architecture

```text
Buffer → keystroke → InputEdit → parse(old, edit, text)
  → changed ranges → update faces/folds/diagnostics
```

## Example

See [Incremental](/examples/incremental): `1 + 2` → `1 + 22` reparses with a one-span diff.

## Output

```text
changed: bytes [4, 6]
```

## Next steps

- [Incremental Parsing](/guide/incremental-parsing), [Performance](/guide/performance)
- [IDE Language Tools](/use-cases/ide-language-tools)
