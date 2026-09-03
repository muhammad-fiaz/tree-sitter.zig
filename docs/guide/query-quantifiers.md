---
description: Query quantifiers — ?, *, and + on pattern nodes.
---

# Query Quantifiers

## What you'll learn

- How `?`, `*`, and `+` modify child matching.

## Complete example

```scheme
(expression (_) @x "+" @p (_) @y)   ; exactly two operands around one plus
(factor (number)?)                   ; a factor with an optional number child
```

## How it works

- `?` — the child may appear once at the current position or be absent.
- `*` — zero or more consecutive matching children (greedy).
- `+` — one or more consecutive matching children (greedy).
- Plain children match as an ordered subsequence: later pattern children may skip unmatched tree children, so `(a b)` finds `b` after `a` even with nodes in between.
- `.` anchors constrain the edges, ignoring anonymous nodes: a leading `.` pins the first child to the first *named* child, `.` between children requires named-adjacency, and a trailing `.` requires the last match to be the last *named* child. A `.` at group end is vacuous.
- `!field` asserts the node lacks a field: `(pair !key)` never matches a pair that binds `key`.

Repetition matching is greedy without full backtracking across the rest of the sequence; ambiguous patterns resolve to the longest greedy run. This covers the practical cases (optional nodes, repeated arguments) while keeping matching linear.

## API used

- [Query](/api/query)

## Related guides

- [Queries](/guide/queries), [Query Predicates](/guide/query-predicates)
