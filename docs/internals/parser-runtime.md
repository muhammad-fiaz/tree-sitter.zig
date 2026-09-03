---
description: Parser runtime internals — the LR loop, lookahead installation, and termination guards.
---

# Parser Runtime

`src/parser/` implements the loop in `parseLoop` (`parser.zig`):

1. **Reuse probe** (`tryReuse`): if no lookahead is held, lex one token and install it (advancing the tokenizer — the single-lexing invariant). Scan the monotonic candidate cursor for the largest span starting at the token with a matching start state and a valid shift/goto target; clone it, push, jump. Successful probes `continue`.
2. **Action dispatch** on `(state, lookahead)`: accept (attach leftovers, return root), shift (token node + push), reduce (pop N, drain in-span errors, build node, goto, push), or recover.
3. **Termination**: every iteration consumes input, shrinks the stack, or pushes new state; recovery budgets bound the rest; a step guard (`8n + 1024`) backstops pathological grammars into `finalize`, which always returns a (possibly error-marked) root.

`ParseState` (`state.zig`) carries the tokenizer, stack, installed lookahead, error span, pending error nodes, and the detected start symbol (the non-terminal whose goto reaches the accept state).

## Related pages

[Parser](/concepts/parser), [Incremental Runtime](/internals/incremental-runtime), [Stack Runtime](/internals/stack-runtime)
