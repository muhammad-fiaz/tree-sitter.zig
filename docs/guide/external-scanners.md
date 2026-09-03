---
description: External scanners in tree-sitter.zig — the Zig-native interface for context-sensitive tokens.
---

# External Scanners

## What you'll learn

- When a grammar needs an external scanner and how to plug one in without C.

## When to use this

Some tokens cannot be described by longest-match rules: significant indentation, heredocs, or tokens valid only in certain parser states. Those belong in an external scanner.

## The interface

```zig
pub const ExternalScanner = struct {
    payload: ?*anyopaque = null,
    scan: *const fn (
        payload: ?*anyopaque,
        source: []const u8,
        start: usize,
        valid_symbols: []const bool,
    ) ?ExternalToken,
    reset: ?*const fn (payload: ?*anyopaque) void = null,
};
```

Attach it to your language:

```zig
var lang = my_base_language;
lang.external_scanner = .{ .payload = &my_state, .scan = myScan, .reset = myReset };
try parser.setLanguage(lang);
```

`valid_symbols` tells the scanner which external tokens the parser can currently accept; return the symbol plus its byte length, or `null` to decline.

## Dispatch rules

The tokenizer consults the scanner **first** at every lex point (before built-in matchers), with the current state's valid set (action symbols plus extras, recomputed per parser step):

- A non-extra token wins immediately — even zero-width (indent/dedent).
- An extra token must consume input (`length > 0`); zero-width extras are ignored so skipping always progresses.
- Results are cached per offset: the scanner runs at most once per offset per parser step, because scanning may mutate payload state (indent stacks).
- Included ranges still apply; streaming (`parseStream`) buffers first when a scanner is present, since stateful scanners observe whole lines.
- Every parse starts with the scanner `reset` hook (fresh source, fresh state). Offsets within a parse are monotonic, so payload caches stay valid across incremental reuse jumps.

Payloads are caller-owned, which keeps parsers independent (no globals, thread-safe by construction):

```zig
var lang = treesitter.outline_language;
var state = treesitter.OutlineScanState.init(gpa);
defer state.deinit();
lang.external_scanner.?.payload = &state;
try parser.setLanguage(lang);
```

## Bundled demo: the outline language

`treesitter.outline_language` parses indentation-sensitive outlines (`#` headers, `-` items, nested `#` sub-headers) with `newline`, `indent`, `dedent`, and `blank` tokens from `src/language/outline_scanner.zig`. The scanner keeps a per-line indent cache plus an indent stack, emits one dedent per call (zero-width re-entry needs no queue), virtualizes a missing trailing newline at EOF, and unwinds open levels there. Run it with `zig build run-external_scanner`. Nesting rules: sub-headers attach directly under a header line or inside a body; bare continuation lines and deeper bare bullets are parse errors by design.

Upstream differences, documented honestly: upstream scanners support create/destroy plus serialize/deserialize so the parser can snapshot state at reuse points; here the parser resets per parse and relies on monotonic offsets plus the payload cache instead. Scanner authors should keep `scan` allocation-free on the hot path (the outline cache amortizes its line scan) and treat `source` as borrowed.

## Status

Implemented end to end: interface, per-state dispatch, result caching, the outline demo with corpus cases (`outline_*`), inline scanner unit tests, and the runnable example.

## API used

- [Language](/api/language) — `ExternalScanner`, `outline_language`, `OutlineScanState`.

## Related guides

- [Language Definition](/guide/language-definition), [External Scanners](/concepts/external-scanners)
