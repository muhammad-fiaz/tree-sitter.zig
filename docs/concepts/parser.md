---
description: How the tree-sitter.zig parser works — LR engine, lookahead, and tree construction.
---

# Parser

## Simple explanation

The parser reads the source left to right and progressively builds a structured tree. At each step it asks one question: given everything parsed so far (summarized as a *state*) and the next token (*lookahead*), should it *shift* the token onto its stack, *reduce* the stack top into a syntax node, *accept* the finished tree, or *recover* from an error?

## Technical explanation

`parser/parser.zig` implements a table-driven LR loop over `language/tables.zig` data:

1. **Lookahead** (`parser/lookahead.zig`): longest-match tokenization with extras skipped, one token of lookahead held in `ParseState`.
2. **Shift**: create a token subtree, push `(target_state, node)`.
3. **Reduce**: pop N values, drain any pending error nodes inside the span, build the interior node, push the goto target.
4. **Accept**: the end token in an accept state finishes the parse; leftover error nodes attach to the root positionally.
5. **Recovery** (`parser/recover.zig`): skip bad input into `ERROR` spans, insert `MISSING` tokens at end of input, or unwind to a final error-marked root — always terminating via bounded budgets.

Reductions record each node's LR start state (`reuse_state`), which is what later makes [incremental reuse](/concepts/incremental-parsing) sound.

## Related pages

- [Lexer](/concepts/lexer), [Parser Stack](/concepts/parser-stack), [Parse Actions](/concepts/parse-actions), [Reductions](/concepts/reductions)
- [Parser Runtime](/internals/parser-runtime), [Parser API](/api/parser)
