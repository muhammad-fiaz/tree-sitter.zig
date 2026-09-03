---
description: Error recovery concepts — ERROR nodes, MISSING nodes, costs, and budgets.
---

# Error Recovery

## Simple explanation

Real-world code is often broken — half-typed, mid-edit, or mid-paste. Instead of failing, the parser marks the broken parts (`ERROR` for skipped text, `MISSING` for absent tokens) and keeps building a useful tree around them.

## Technical explanation

`parser/recover.zig` defines the budgets (`max_recovery_ops`, `max_missing_inserts`) and costs (per skipped byte, per insertion). The engine, on a missing table action:

1. At end of input, inserts a `MISSING` token — preferring a symbol whose shift target itself handles end-of-input (this closes open parens correctly) — and continues.
2. Otherwise skips the offending token or byte into an open error span, which closes into an `ERROR` leaf attached to the next enclosing reduction or, at worst, the root.
3. Gives up gracefully into an error-marked root wrapping all fragments when budgets exhaust.

Because recovery only ever *adds* information (error flags, extra children), valid regions of broken files still produce exactly the nodes a fresh parse of the fixed file would.

## Related pages

- [Error Recovery guide](/guide/error-recovery), [Errors API](/api/errors)
- [Upstream Conformance](/internals/upstream-conformance)
