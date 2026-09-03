---
description: Incremental FAQ — edits, reuse, and changed ranges.
---

# Incremental FAQ

## How does incremental parsing work?

Describe the change as an `InputEdit`, pass the old tree with the new source to `Parser.parse`, and unaffected subtrees are spliced in without re-lexing. See [Incremental Parsing](/guide/incremental-parsing).

## How do I reuse a tree?

Keep the old tree alive and hand it to `parse` — it is only read, never mutated. `copy()` snapshots it.

## Is the tree reusable?

Yes: old trees feed incremental parses, and `copy()` duplicates them. New trees are independent values.

## How do I run a query (on a new tree)?

Queries are independent of parsing — `execute` against any tree. Reuse compiled queries and cursors across trees.

## Why are my changed ranges empty?

Same-span substitutions change no positions or structure. Insertions and deletions report normally. See [Troubleshooting](/guide/troubleshooting).

## Are included ranges enforced?

Yes: `setIncludedRanges` validates (sorted, non-overlapping) and the lexer skips excluded gaps while keeping document coordinates. See [Included Ranges](/guide/included-ranges).
