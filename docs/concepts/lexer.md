---
description: How the tree-sitter.zig lexer works — position tracking, longest match, extras, and EOF.
---

# Lexer

## Simple explanation

The lexer turns raw bytes into labeled tokens (`identifier`, `number`, `+`, …) while tracking exactly where each token sits — byte offsets plus row/column points.

## Technical explanation

- `lexer/lexer.zig` is a position-tracking cursor over the source: `advance()` moves one byte and updates the point; `markEnd()` freezes the token end independently of lookahead.
- Tokenization tries every non-extra `TokenMatcher` at each offset and takes the **longest match**; extra symbols (whitespace) are skipped in a loop first.
- End of input surfaces as the grammar's `end` token; bytes no matcher accepts surface as an invalid marker that error recovery skips one byte at a time.
- `lexer/input.zig` (`ChunkReader`) abstracts slice vs callback sources; `lexer/unicode.zig` decodes the current character without decoding the whole file; `lexer/external.zig` dispatches to a Zig external scanner when the language provides one.

The lexer never allocates for ordinary lookahead.

## Related pages

- [Parser](/concepts/parser), [Unicode](/concepts/unicode), [External Scanners](/concepts/external-scanners)
- [Lexer Runtime](/internals/lexer-runtime)
