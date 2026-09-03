---
description: Debugging the runtime — loggers, tracers, and tree dumps.
---

# Debugging

1. **Tree dumps**: walk with `tree.cursor()` printing `nodeType` + spans (the `tree_walk` example pattern) — most "wrong tree" reports become obvious here.
2. **Loggers**: `parser.setLogger(.{ .level = .debug })` streams shifts, reductions, recovery, and reuse decisions; `.trace` adds lexer events.
3. **Tracers**: `Tracer` records structured events for programmatic inspection and replay.
4. **Bisection**: shrink the source to the smallest failing span, then check token coverage (unmatched bytes) and table coverage (missing actions) at that state.

Related: [Logging](/guide/logging), [Troubleshooting](/guide/troubleshooting), [Debugging examples](/examples/debugging).
