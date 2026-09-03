---
description: Performance characteristics and measured benchmarks for tree-sitter.zig 0.0.1.
---

# Performance

## What you'll learn

- Where time goes in each operation and how to reproduce the numbers.

## Measured results

~80KB expression corpus, 100,000 nodes, 20,000 query matches (Windows x86_64):

| Benchmark | Debug | ReleaseFast |
|-----------|-------|-------------|
| Initial parse | ~87 ms | ~10 ms |
| Repeated parse | ~86 ms | ~10 ms |
| Small-edit incremental (≈40k reused) | ~94 ms | ~4–16 ms |
| Tree traversal (100k nodes) | ~9 ms | ~1 ms |
| Query execution (20k matches) | ~95 ms | ~4 ms |

## Reproduce them

```sh
zig build bench
zig build bench -Doptimize=ReleaseFast
```

The benchmark (`benchmarks/parse_bench.zig`) prints each measurement plus `reused_nodes`. Timing uses the Zig 0.16.0 `std.Io` monotonic clock.

## Design notes

- **No per-node allocation.** Nodes live in two pools (node structs + child indices); a `Node` is a handle.
- **No per-token allocation.** The tokenizer writes into parser-owned scratch.
- **No repeated source copies.** One copy per tree; callback input is buffered once (`parseStream` transfers its pull buffer with no extra copy).
- **Indexed reuse search.** Candidates are sorted into an interval index (start offset, longest span first) with binary-search lookup; cloning borrows the parser scratch buffer instead of allocating per node.
- **Clone, don't re-lex.** Reused subtrees are copied into the new pool with translated positions.

## API used

- [Parser](/api/parser) — `reused_node_count`; benchmark source in the repo.

## Related guides

- [Incremental Parsing](/guide/incremental-parsing), [Parser Reuse](/guide/parser-reuse), [Memory Management](/guide/memory-management)
