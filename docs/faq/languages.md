---
description: Language FAQ — grammars, tables, scanners, and ABI versions.
---

# Languages FAQ

## How do languages plug in?

As `Language` table data: symbols, matchers, LR tables, fields, metadata. See [Language Definition](/guide/language-definition).

## Is the runtime tied to one language?

No — the engine only calls table lookups and matchers. Four bundled grammars exist for tests and examples: the expression grammar (`expression_language`), an s-expression grammar (`sexp_language`) demonstrating aliases, a JSON grammar (`json_language`), and an indentation-sensitive outline grammar (`outline_language`) demonstrating external scanners.

## What are external scanners for?

Context-sensitive tokens (indentation, heredocs) via Zig callbacks. See [External Scanners](/guide/external-scanners).

## What ABI versions are accepted?

13–15; anything else is `IncompatibleAbiVersion` at `setLanguage` time.
