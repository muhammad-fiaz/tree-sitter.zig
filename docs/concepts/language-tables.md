---
description: LR parse tables — states, actions, gotos, and reduce rules.
---

# Language Tables

## Simple explanation

Parse tables pre-answer every "what now?" decision so parsing is fast: for each grammar state and next token, the table says shift, reduce, or accept.

## Technical explanation

`language/tables.zig` holds `ParseTable { states, start_state, end_symbol, error_symbol }`. Each `ParseState` carries `actions` (terminal → `Action`) and `gotos` (non-terminal → state). A `ReduceRule` names the parent symbol, child count, production id (for fields/aliases), and dynamic precedence. The bundled grammar's tables are a hand-verified SLR(1) construction for the expression grammar — states 0–17 covering programs, expressions, terms, factors, and parenthesization.

## Related pages

- [Parse Actions](/concepts/parse-actions), [Grammar & Language](/concepts/grammar-language)
- [Language API](/api/language)
