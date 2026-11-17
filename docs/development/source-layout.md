---
description: Source layout - the repository map for contributors.
---

# Source Layout

```text
build.zig / build.zig.zon   Zig 0.17.0 build, module "treesitter" v0.0.3
src/treesitter.zig          public facade + smoke tests
src/core/                   Point, Range, InputEdit, symbols, positions (+ unit tests)
src/memory/                 allocator model, ownership, refcount, arena (+ tests)
src/parser/                 LR engine, stack, actions, reduce, recovery (+ tests)
src/lexer/                  lexer, modes, chunk input, UTF-8, external (+ tests)
src/tree/                   pool, nodes, cursor, edits, changed ranges, sexp (+ tests)
src/language/               Language model + bundled expression/s-expression/JSON/outline grammars, registry, package (+ tests)
src/grammar/                Grammar AST, DSL, and grammar compiler (+ tests)
src/generator/              Native Zig parser generator emitting self-contained parsers (+ tests)
src/highlight/              Syntax highlighting engine with capture resolution (+ tests)
src/injection/              Multi-language syntax injection engine (+ tests)
src/locals/                 Lexical scope and local variable analysis (+ tests)
src/tags/                   Code tags and symbol extraction engine (+ tests)
src/query/                  query parser, matcher, predicates, directives, cursor (+ tests)
src/input/                  memory / callback / std.Io.Reader / streaming sources (+ tests)
src/unicode/                UTF-8 and UTF-16 codecs and tables (+ tests)
src/debug/                  logger, tracer, conformance harness + corpus/ (+ tests)
src/utils/                  std-backed helpers (array, bitset, math, ascii)
grammars/                   14 modular native Zig grammar packages (C, C++, Python, JS, TS, Rust, Go, HTML, CSS, JSON, Java, Ruby, PHP, Zig)
conformance/main.zig        corpus report runner (zig build conformance)
fuzz/fuzz.zig               parser/query fuzzer (zig build fuzz)
examples/                   25 runnable standalone programs in examples/*.zig
benchmarks/parse_bench.zig  corpus benchmark (zig build bench)
docs/                       VitePress documentation website
```

Tests live inline in `src/` - see [Testing](/development/testing). Examples consume only the public API and bundled grammars.

Related: [Testing](/development/testing), [Contributing](/development/contributing).
