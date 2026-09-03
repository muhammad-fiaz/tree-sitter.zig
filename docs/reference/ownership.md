---
description: Ownership reference — exact owners for parsers, trees, nodes, cursors, and queries.
---

# Ownership

## Parser

Owns: state/value stacks, token scratch, reuse-candidate list, included-range list. Borrows: allocator, `Language` tables. `deinit` frees the owned lists.

## Tree

Owns: source byte copy, `SubtreePool` (nodes + child indices). Borrows: allocator, `Language`. `copy()` duplicates all owned storage with the tree's allocator. `applyEdit` mutates positions in place — no ownership change.

## Node

Owns nothing. Two words. Invalid after its tree's `deinit` (use-after-free if misused — the test suite guards the boundary with explicit lifetimes, never with runtime checks, for speed).

## TreeCursor

Owns: path stack. Borrows: tree. `copy()` duplicates the stack.

## Query / QueryCursor

`Query` owns: node list, child/field lists, pattern list, capture names, predicate arg slices. `QueryCursor` owns: match list plus one owned capture slice per match. Both borrow the allocator (and the language, for matching).

## Changed ranges

`getChangedRanges` returns a caller-owned slice; `freeChangedRanges` releases it. Either tree sharing the allocator may free it.

## Related pages

[Memory Model](/concepts/memory-model), [Allocator Model](/reference/allocator-model), [Memory Management](/guide/memory-management)
