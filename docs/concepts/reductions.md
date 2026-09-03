---
description: Reductions — how popped stack values become interior syntax nodes.
---

# Reductions

## Simple explanation

A reduction takes several finished pieces (for example `expression`, `+`, `term`) and glues them into one new node (`expression`), computing its span from the first and last child.

## Technical explanation

`parser/reduce.zig` builds interior nodes: symbol and production id come from the `ReduceRule`; byte/point spans come from the outer children; `named_child_count` and `descendant_count` aggregate over children; `has_error` propagates from any tainted child. Pending `ERROR` leaves whose spans fall inside the new node are spliced into the child list in positional order, which is how skipped text lands inside the smallest enclosing construct. The new node's `reuse_state` is inherited from its first child — the LR state active where the node starts — enabling later incremental reuse.

## Related pages

- [Parse Actions](/concepts/parse-actions), [Subtrees](/concepts/subtrees), [Incremental Parsing](/concepts/incremental-parsing)
