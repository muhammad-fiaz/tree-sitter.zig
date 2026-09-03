---
description: External scanner concepts — context-sensitive tokens without C.
---

# External Scanners

## Simple explanation

Most tokens are recognizable in isolation, but some (indentation, heredocs) depend on context. External scanners handle those with custom Zig code the lexer consults when ordinary matchers decline.

## Technical explanation

The `Language.external_scanner` slot carries a payload plus `scan`/`reset` function pointers. `scan` receives the source, start offset, and a `valid_symbols` bitmap describing which external tokens the parser can currently accept, returning a symbol plus length or `null`. The tokenizer runs the scanner first at every lex point; per-offset result caching keeps stateful decisions (indent stacks) consistent across the skip/lex double consultation. The bundled outline grammar demonstrates the full loop: newline/indent/dedent/blank tokens from Zig code, with caller-owned payload state reset at every parse start. Upstream additionally snapshots scanner state (serialize/deserialize) at reuse points; this runtime resets per parse and relies on monotonic offsets instead — a documented simplification, not a gap in token coverage.

## Related pages

- [External Scanners guide](/guide/external-scanners), [Lexer](/concepts/lexer)
- [Language API](/api/language)
