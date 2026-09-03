---
description: Grammars and languages — how grammar data drives the generic runtime.
---

# Grammar & Language

## Simple explanation

A *grammar* describes a language's structure (what an expression looks like); a *language* is that description packaged as data the parser can run. tree-sitter.zig never hard-codes any programming language — the same engine parses whatever tables you load.

## Technical explanation

`language/language.zig` is the runtime-facing `Language` struct: metadata, symbol table, token matchers, extras, LR tables, fields, aliases, supertypes, and an optional external scanner. Grammar authors (or generators targeting this runtime) produce those tables; the parser only calls `actionFor` / `gotoState` and the matchers. Four table sets ship with the library: the 18-state expression grammar (`expression_language`, formerly also reachable as `test_grammar.test_language`), a 12-state s-expression grammar (`sexp_language`) demonstrating aliases, a 27-state JSON grammar (`json_language`) with key/value fields, and a 21-state indentation-sensitive outline grammar (`outline_language`) demonstrating external scanners. All are used by tests, examples, benchmarks, and the conformance corpus.

## Related pages

- [Language Definition](/guide/language-definition), [Language Tables](/concepts/language-tables), [Symbols](/concepts/symbols)
- [Language API](/api/language)
