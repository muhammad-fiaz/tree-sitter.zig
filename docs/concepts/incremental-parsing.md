---
description: Incremental parsing concepts — why reuse is sound and how it flows.
---

# Incremental Parsing

## Simple explanation

When source changes slightly, most of the old syntax tree is still right. Incremental parsing finds the still-right pieces and only re-parses the neighborhood of the edit.

## Technical explanation

Soundness rests on LR determinism: the same parser state plus the same upcoming bytes always produces the same subtree. The parser therefore records every node's start state (`reuse_state`), translates old positions through the `InputEdit`, and collects candidates fully outside the edited span. During parsing, a candidate whose translated start, symbol, and start state match the live state is cloned into the new pool and skipped — whole subtrees at a time, preferring the largest span. `reused_node_count` reports the take-up. Old trees are never mutated; reuse copies.

## Related pages

- [Incremental Parsing guide](/guide/incremental-parsing), [Changed Ranges](/concepts/changed-ranges)
- [Incremental Runtime](/internals/incremental-runtime)
