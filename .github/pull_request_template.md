## Description

<!-- What does this PR change and why? Link related issues: Fixes #..., Relates to #... -->

## Type of change

- [ ] Bug fix
- [ ] New feature (runtime, query, language, input)
- [ ] Performance improvement
- [ ] Documentation only
- [ ] Tooling (build, CI, docs site, fuzz, bench, conformance)
- [ ] Refactor (no behavior change)

## Testing

<!-- Check everything you ran locally (Zig 0.16.0 exactly). -->

- [ ] `zig build test` (129+ inline tests)
- [ ] `zig build conformance`
- [ ] `zig build run-all-examples`
- [ ] `zig build bench` (for performance-related changes, paste before/after numbers)
- [ ] `zig build fuzz -- --iterations=N --seed=N` (for parser/query changes)
- [ ] Docs build (`bun run docs:build` in `docs/`) for documentation changes

## Checklist

- [ ] `zig fmt` is clean (`zig fmt --check src/ benchmarks/ conformance/ fuzz/ examples/ build.zig build.zig.zon`)
- [ ] New behavior has inline tests at the bottom of the implementing source file (no separate `tests/` files)
- [ ] Examples under `examples/` are not reused as tests
- [ ] Allocator rules respected: no hidden globals, ownership documented, `deinit` provided
- [ ] Public API changes are reflected in `README.md` and the VitePress docs with real signatures and output
- [ ] No invented APIs, outputs, or benchmark numbers — everything matches the implementation
