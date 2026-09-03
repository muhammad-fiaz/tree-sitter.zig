---
description: Contributing guide — workflow, conventions, and quality gates.
---

# Contributing

## Workflow

1. Fork and clone, then verify the baseline:
   ```sh
   zig build test
   zig build conformance
   ```
2. Keep changes focused: one feature or fix per pull request.
3. Follow the codebase conventions:
   - Tests live **inline** at the bottom of the source file that implements the functionality — never in a separate `tests/` tree.
   - Examples in `examples/` consume only the public API (`@import("treesitter")`) and the bundled grammars; they must all run via `zig build run-all-examples`.
   - No hidden allocators: take `std.mem.Allocator` explicitly, document ownership on every public type.
   - No C, no Rust, no vendored code: upstream Tree-sitter is a behavioral reference only.
4. Prove behavior changes with the harnesses:
   - New grammar behavior → add `src/debug/corpus/*.txt` cases and list them in `conformance.corpus_files`.
   - New query syntax → inline tests in `src/query/` plus corpus or example coverage where it parses real source.
   - Fuzz-sensitive areas → extend `fuzz/fuzz.zig` fragments.
5. Update every affected surface together: source, inline tests, examples, `README.md`, and the matching pages under `docs/` (guides, concepts, API reference, compatibility matrix, FAQ).
6. Run the full verification before opening the PR:
   ```sh
   zig build test-all     # tests + benchmark + all examples
   zig build conformance  # differential corpus (19 cases)
   zig build fuzz         # seeded parser/query fuzzer
   ```
   From `docs/`: `npm run docs:build` must complete with no warnings.

## Docs conventions

- Every page starts with `description` frontmatter (one accurate sentence).
- Document only implemented behavior; mark partial areas honestly.
- Register new pages in `docs/.vitepress/config.ts` (sidebar) or the build still passes but readers can't find them.
- Never leave dead internal links: removing a page means updating its sidebar entry and every link to it.
- Code samples must be real: copy runnable snippets from `examples/` or verified test output, never invented output.

## Adding a bundled grammar

1. Add `src/language/<name>.zig` with symbol table, matchers, LR tables, and metadata (plus an external scanner module if tokens need context).
2. Re-export from `src/language/language.zig` and `src/treesitter.zig`.
3. Add `src/debug/corpus/<name>_*.txt` cases (valid, nested, empty, error, incremental) and register them in `corpus_files`.
4. Add an `examples/<name>_parse.zig` program and list it in `build.zig`.
5. Document it in `docs/guide/language-definition.md`, `docs/examples/languages.md`, `docs/api/language.md`, and the compatibility matrix.

The canonical contributor file also lives at the repository root: [CONTRIBUTING.md](https://github.com/muhammad-fiaz/tree-sitter.zig/blob/main/CONTRIBUTING.md). The full test/benchmark/fuzz reference is [Testing](/development/testing).

## License

Contributions land under the repository's MIT license.
