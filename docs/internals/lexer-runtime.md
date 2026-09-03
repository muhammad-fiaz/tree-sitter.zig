---
description: Lexer runtime internals — tokenizer, chunk reading, and external dispatch.
---

# Lexer Runtime

`src/lexer/` splits responsibilities: `lexer.zig` tracks absolute offset plus point with independent token-end marking; `lookahead.zig` (`Tokenizer`) implements skip-extras then longest-match with an invalid-token marker for unmatched bytes; `input.zig` (`ChunkReader`) serves bytes from slices directly or pulls callback chunks with a one-chunk cache; `unicode.zig` decodes single characters; `state.zig` models lex modes; `external.zig` delegates to the language's Zig scanner when present.

Key invariant: token end (`markEnd`) is independent of the lookahead position, so matchers can overshoot while the emitted token stays exact.

## Related pages

[Lexer](/concepts/lexer), [Parser Runtime](/internals/parser-runtime)
