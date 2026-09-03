---
description: Memory management in tree-sitter.zig — owners, borrowers, lifetimes, and deinit rules.
---

# Memory Management

## What you'll learn

- Exactly who owns every allocation and when to call `deinit`.

## The rules

<MemoryModel />

1. **Parser** owns its stacks, scratch buffers, candidate lists, and range list. `deinit` frees them all.
2. **Tree** owns its source copy, node pool, and child-index buffer. Nodes and cursors borrow the tree — never use them after `tree.deinit()`.
3. **Node** owns nothing. It is two words (tree pointer + index).
4. **TreeCursor** owns its path stack only.
5. **Query** owns compiled patterns, captures, and predicate args. **QueryCursor** owns its match lists.
6. **Changed-range slices** are owned by the caller and freed with `freeChangedRanges` (or `tree.freeChangedRanges`).

## No leaks, no hidden state

There are no global allocators, no global parsers, and no hidden I/O. Two parsers in different threads never share memory (parsers are not internally synchronized — use one parser per thread; see [FAQ](/faq/memory)).

## API used

- [Allocator](/api/allocator); [Ownership](/reference/ownership), [Allocator Model](/reference/allocator-model).

## Related guides

- [Allocators](/guide/allocators), [Parser Reuse](/guide/parser-reuse), [Tree Reuse](/guide/tree-reuse)
