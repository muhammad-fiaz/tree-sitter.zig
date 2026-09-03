---
description: Query predicates — #eq?, #match?, #contains?, #any-of?, #is? and their negations.
---

# Query Predicates

## What you'll learn

- Which predicates are supported and exactly how each one evaluates.

## Supported predicates

| Predicate | Meaning |
|-----------|---------|
| `(#eq? @a @b)` / `(#eq? @a "lit")` | All `@a` texts byte-equal the other side |
| `(#not-eq? ...)` | Negation |
| `(#any-eq? ...)` / `(#any-not-eq? ...)` | Any `@a` text (in)equality |
| `(#match? @a "regex")` | All `@a` texts match (subset: `.`, `*`, `+`, `?`, `^`, `$`, `[...]` classes, `\` escapes) |
| `(#not-match? ...)` / `(#any-match? ...)` / `(#any-not-match? ...)` | Negation / any-variants |
| `(#contains? @a @b)` / `(#contains? @a "lit")` | Every `@a` text contains the substring (evaluated extension) |
| `(#not-contains? ...)` | Negation |
| `(#any-of? @a "lit" ...)` | Capture text equals one of the literals (rest must be literals) |
| `(#not-any-of? ...)` | Negation |
| `(#is? @a prop)` / `(#is-not? @a prop)` | Node property check: `named`, `anonymous`, `missing`, `error` (is or contains an error), `extra`, `visible` |

Argument shapes are validated at compile time (comparison first arguments must be captures, `match?` takes a literal pattern), and every predicate capture must be declared by a node pattern — typos fail with `InvalidCapture` instead of silently matching nothing.

Predicates attach to a pattern either after it — `(identifier) @x (#eq? @x "foo")` — or inside a group: `((identifier) @x (#match? @x "^a"))`.

## Directives

`#set!` and every other `#name!` form are parsed but not evaluated by the engine — mirroring upstream, which exposes them structurally for higher-level code:

```scheme
((identifier) @x (#set! kind "variable") (#select-adjacent! @x @x))
```

- `query.propertySettings(i)` returns the `#set!` entries (`key`, optional `value`, optional `capture`).
- `query.generalPredicates(i)` returns the rest (`select-adjacent!`, `strip!`, unknown) with operator and raw args.
- `query.directives.selectAdjacent(gpa, captures, target, anchor)` keeps the line-contiguous run above the anchor (tags-crate semantics).
- `query.directives.stripText(gpa, text, pattern)` deletes every regex match (replace-all with `""`).

Unknown *properties* to `#is?` are reserved for host-defined extensions and never filter a match; unknown `?` predicate *names* are a compile error (`InvalidPredicate`), so typos fail fast instead of silently passing.

## Complete example

```zig
var query = try parser.compileQuery("((identifier) @x (#match? @x \"^a\"))");
```

Over `abc + 1` this yields one match; over `zzz + 1` it yields none. Membership and property filters compose the same way:

```zig
"((identifier) @x (#any-of? @x \"foo\" \"bar\"))" // text is foo or bar
"((identifier) @x (#is? @x named))"               // node is named
```

## How it works

Predicates evaluate after structural matching, against the captures of that match. See `checkProperty` in [Query](/api/query) for the exact property table.

## API used

- [Query](/api/query); predicates live in `query/predicate.zig`.

## Related guides

- [Queries](/guide/queries), [Query Quantifiers](/guide/query-quantifiers)
