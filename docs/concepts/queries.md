---
description: Query concepts — structural patterns over syntax trees.
---

# Queries

## Simple explanation

Queries find code by *shape* instead of text: "all identifiers inside binary expressions" rather than "the letters f-o-o". Patterns describe node types, parent-child nesting, and captured names; the engine returns every match with its captures.

## Technical explanation

`query/` compiles S-expression sources into flat pattern nodes (named / anonymous / wildcard kinds, field constraints, captures, quantifiers, anchors) plus predicates. Matching is a backtracking descent: roots match at any depth, children must be direct descendants in order, captures record into scratch space, and predicates filter afterwards. `QueryCursor` owns the collected matches. The matcher is generic over the same `Language` tables as the parser, so node-type checks respect named/anonymous distinctions.

## Related pages

- [Queries guide](/guide/queries), [Query Captures](/guide/query-captures), [Query Predicates](/guide/query-predicates)
- [Query Runtime](/internals/query-runtime), [Query API](/api/query)
