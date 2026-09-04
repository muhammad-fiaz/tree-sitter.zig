---
description: Source layout — the repository map for contributors.
---

# Source Layout

```text
build.zig / build.zig.zon   Zig 0.16.0 build, module "treesitter" v0.0.1
src/treesitter.zig          public facade + smoke tests
src/core/                   Point, Range, InputEdit, symbols, positions (+ unit tests)
src/memory/                 allocator model, ownership, refcount, arena (+ tests)
src/parser/                 LR engine, stack, actions, reduce, recovery (+ tests)
src/lexer/                  lexer, modes, chunk input, UTF-8, external (+ tests)
src/tree/                   pool, nodes, cursor, edits, changed ranges, sexp (+ tests)
src/language/               Language model + bundled expression/s-expression/JSON/outline grammars (+ tests)
src/query/                  query parser, matcher, predicates, cursor (+ tests)
src/input/                  memory / callback / std.Io.Reader / streaming sources (+ tests)
src/unicode/                UTF-8 codec and tables (+ tests)
src/debug/                  logger, tracer, conformance harness + corpus/ (+ tests)
src/utils/                  std-backed helpers (array, bitset, math, ascii)
conformance/main.zig        corpus report runner (zig build conformance)
fuzz/fuzz.zig               parser/query fuzzer (zig build fuzz)
examples/                   thirteen runnable programs (no test reuse)
benchmarks/parse_bench.zig  corpus benchmark (zig build bench)
docs/                       this website
```

Tests live inline in `src/` — see [Testing](/development/testing). Examples consume only the public API and bundled grammars.

Related: [Testing](/development/testing), [Contributing](/development/contributing).
