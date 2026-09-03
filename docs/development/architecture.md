---
description: Contributor architecture — facades, dependency direction, and subsystem contracts.
---

# Architecture

Each subsystem directory owns a facade re-exported by `src/treesitter.zig`: `core/core.zig`, `memory/memory.zig`, `parser/parser.zig`, `lexer/lexer.zig`, `tree/tree.zig`, `language/language.zig`, `query/query.zig`, `input/input.zig`, `unicode/unicode.zig`, `debug/debug.zig`, `utils/utils.zig`. Internal files are imported relatively; the dependency direction `utils → core → memory → input/unicode → language → tree → lexer → parser → query` is load-bearing — `core` must never import `parser` or `query`. The one deliberate exception is the `tree ↔ node` handle/pool split, which Zig's lazy file evaluation tolerates. Keep new code inside the subsystem that owns its data.

## Related pages

[Architecture](/concepts/architecture), [Source Layout](/development/source-layout)
