---
description: Benchmarks — running parse_bench and interpreting results.
---

# Benchmarks

```sh
zig build bench
zig build bench -Doptimize=ReleaseFast
```

`benchmarks/parse_bench.zig` generates a 20,000-operand expression corpus (~80KB, 100,000 nodes) and prints: source bytes, initial parse, repeated parse, worst-case leading-edge incremental parse with `reused_nodes`, traversal visits, and query matches — timed on the `std.Io` monotonic clock. Reference numbers live in [Performance](/guide/performance). When optimizing, profile the ReleaseFast numbers, change one thing, and keep the Debug suite green; per-node allocation or per-token allocation regressions show up immediately in the incremental line.

Related: [Performance](/guide/performance), [Incremental Runtime](/internals/incremental-runtime).
