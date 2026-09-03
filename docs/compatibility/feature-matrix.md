---
description: Feature matrix — implemented, partial, and planned areas.
---

# Feature Matrix

<VersionBadge />

| Area | Status | Notes |
|------|--------|-------|
| LR parsing (shift/reduce/accept) | Implemented | Table-driven, generic over languages |
| Lexer, extras, EOF | Implemented | Longest match, allocation-free lookahead |
| Error recovery (`ERROR`/`MISSING`) | Implemented | Bounded budgets, error costs |
| Incremental parsing + reuse | Implemented | Sorted interval index, structural equality verified |
| Changed ranges | Implemented | Minimal structural diffs |
| Tree / Node / Cursor | Implemented | Allocation-free reads and moves |
| Queries, captures, quantifiers | Implemented | Greedy repetition, anchors |
| Predicates `#eq?`/`#match?`/`#contains?` (+negations) | Implemented | Small built-in regex subset, all/any semantics |
| Predicates `#any-of?`/`#not-any-of?`/`#is?`/`#is-not?` | Implemented | Membership + node-property checks |
| Predicates `any-eq?`/`any-match?` (+negations) | Implemented | Any-node variants, validated shapes |
| Directives `#set!`/`select-adjacent!`/`strip!` | Implemented | Parsed + exposed; native apply helpers |
| Negated fields `!field`, audited anchors | Implemented | First/last named, named-adjacency |
| Groups `((...) (#...))` | Implemented | Single pattern + predicates |
| External scanners | Implemented | Per-state dispatch, caching, outline demo |
| Aliases | Implemented | Substitution on reduce; demoed by s-expression grammar |
| Supertypes | Implemented | Subtype expansion in query matching |
| Included ranges | Implemented | Validated; lexer-enforced |
| Callback input + streaming | Implemented | `parseWithInput` buffers; `parseStream` lexes incrementally |
| UTF-16 input | Implemented | LE/BE transcode, BOM + surrogate errors |
| Bundled grammars | Implemented | Expression + s-expression + JSON + outline |
| Conformance corpus | Implemented | `zig build conformance`, embedded in tests |
| Fuzz target | Implemented | `zig build fuzz` over parser + queries |
| 32/64-bit + ARM64 + WASM | Implemented | 8 OS targets compile; wasm32-wasi validated |

Statuses use exactly these words: **Implemented**, **Partial**, **Experimental**, **Not implemented**. Deliberate differences from upstream are documented in [Upstream Conformance](/internals/upstream-conformance).
