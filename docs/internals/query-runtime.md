---
description: Query runtime internals — S-expression parsing, matching, and predicates.
---

# Query Runtime

`src/query/` stages: `parser.zig` turns S-expressions into flat `PatternNode`s (groups, fields, captures, quantifiers, anchors) plus interned captures and predicates; `matcher.zig` runs backtracking descent with per-alternative scratch save/restore; `predicate.zig` filters matches with equality, substring, and a small built-in regex subset; `cursor.zig` owns collected matches. Root patterns are tried at every tree node (iterative stack walk); nested patterns require direct children; quantifier repetition is greedy. Invalid query text fails at compile time with positional error kinds — never silently.

## Related pages

[Queries](/concepts/queries), [Query Predicates](/guide/query-predicates)
