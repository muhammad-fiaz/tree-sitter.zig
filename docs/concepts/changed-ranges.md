---
description: Changed ranges — minimal diffs between two syntax trees.
---

# Changed Ranges

## Simple explanation

After re-parsing, tools need to know *what visually or semantically changed* — which lines to repaint, which symbols to re-analyze. Changed ranges answer that as a short list of byte/point spans.

## Technical explanation

`tree/changed_ranges.zig` walks old and new trees in lockstep. Structurally equal nodes (same symbol, child count, and points) are descended into; the first divergence on either side emits the new node's range. Equal leaves emit nothing, so identical trees diff to an empty list and insertions diff to a narrow span. A known consequence: same-span text substitutions (e.g. `2` → `3`) change no positions or structure and therefore report no ranges — see [Troubleshooting](/guide/troubleshooting).

## Related pages

- [Changed Ranges guide](/guide/changed-ranges), [Incremental Parsing](/concepts/incremental-parsing)
- [Changed Ranges API](/api/changed-ranges)
