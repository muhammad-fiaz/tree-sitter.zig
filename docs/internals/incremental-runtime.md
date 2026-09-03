---
description: Incremental runtime internals — candidate collection, matching, and cloning.
---

# Incremental Runtime

`Parser.parse(old, edit, source)` runs three phases:

1. **Collect** (`collectReusable`): one pre-order walk of the old pool, translating positions through the edit. Nodes intersecting the edited span, exceeding the new length, or carrying errors are skipped (descending into their children); everything else becomes a `Candidate { old_index, translated span/points, symbol, reuse_state }`. Candidates are then sorted into an interval index (start offset ascending, longest span first).
2. **Match** (`tryReuse`): binary search finds candidates starting at the lookahead token; ties are scanned for matching start state with a valid shift/goto target, preferring the largest span. Zero-width candidates are skipped to guarantee progress.
3. **Clone** (`cloneSubtree`): the chosen region is copied with translated positions and fixed parent links. Direct-child indices are collected in the parser scratch buffer (mark/restore discipline, no per-node allocation) and appended contiguously — recording positions around recursion is incorrect because descendants interleave with direct children in the index list. (An earlier implementation got this wrong and corrupted bushy reuses; the conformance corpus now pins structural equality.)

Determinism makes this sound: identical LR start state plus identical upcoming bytes always yields an identical subtree, so splicing equals re-parsing. Recovery backstops any mismatch.

## Related pages

[Incremental Parsing](/concepts/incremental-parsing), [Parser Runtime](/internals/parser-runtime), [Subtree Runtime](/internals/subtree-runtime)
