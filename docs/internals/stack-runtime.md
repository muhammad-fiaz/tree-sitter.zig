---
description: Stack runtime internals — parallel arrays, lockstep invariants, and retained capacity.
---

# Stack Runtime

`src/parser/stack.zig` keeps `states` and `values` as parallel unmanaged `ArrayList`s. `push` appends to both; `pop` removes from both (restoring the state on value-stack underflow, which cannot happen when callers respect the depth checks); `popMany(n)` asserts `n < depth` so the bottom state always survives for recovery anchoring. `clearRetainingCapacity` between parses is what makes parser reuse allocation-free in steady state.

## Related pages

[Parser Stack](/concepts/parser-stack), [Parser Runtime](/internals/parser-runtime)
