---
description: Performance FAQ — budgets, reuse verification, and measurement.
---

# Performance FAQ

## Is it fast enough for keystroke parsing?

On the 80KB benchmark corpus (ReleaseFast): ~10 ms full parse, ~4–16 ms incremental, ~1 ms traversal. Measure your grammar with `zig build bench -Doptimize=ReleaseFast`.

## How do I verify reuse is working?

Read `parser.reused_node_count` after incremental parses — sustained zero on small edits means your edits or states are defeating reuse; check the edit spans.

## Does it allocate per node?

No. Nodes live in pools; handles are two words. Cursor moves and metadata reads allocate nothing.

## Where do I report bottlenecks?

Profile first ([Benchmarks](/development/benchmarks)), then open an issue with the corpus shape and numbers.
