---
description: Query FAQ — syntax, captures, predicates, and matching semantics.
---

# Queries FAQ

## What query syntax is supported?

Named `(identifier)`, anonymous `"+"`, wildcard `(_)`, fields `left: (...)`, captures `@name`, quantifiers `?`/`*`/`+`, `.` anchors, groups `((...) (#pred? ...))`, and `#eq?`/`#match?`/`#contains?`/`#any-of?`/`#is?` predicates with negations.

## How do captures work?

Each `@name` records the matched node into the match; read them via `match.captures`. See [Query Captures](/guide/query-captures).

## Why does my nested pattern not match?

Nesting means *direct* child. Use shallower patterns or wildcards for deeper matches.

## How do I limit results?

`setByteRange`, `setPointRange`, and `setMatchLimit` before `execute`.

## Do supertype patterns match subtypes?

Yes — a pattern naming a supertype matches the supertype itself plus every subtype in the language's `supertype_map`. Aliased nodes match under their alias name. See [Aliases](/concepts/aliases).

## What are directives for?

`#set!` attaches metadata you read via `query.propertySettings(i)`; every other `#name!` form (`select-adjacent!`, `strip!`, custom) is exposed via `query.generalPredicates(i)` for your own code to apply, with `selectAdjacent` / `stripText` helpers provided. See [Query Predicates](/guide/query-predicates).
