---
description: Fuzzing tree-sitter.zig — the shipped fuzz target.
---

# Fuzzing

`zig build fuzz` runs a seeded PRNG fuzzer over the parser and the query compiler (plus matcher execution on success paths). Any panic, out-of-bounds access, or leak (the `DebugAllocator` checks on exit) fails the run; ordinary `OutOfMemory` and query-compile rejections are tolerated and counted.

```sh
zig build fuzz
zig build fuzz -- --iterations=20000 --seed=42
```

## What it covers

- Random sources from an expression alphabet plus hostile bytes (`@#$.\"':;!?`, tabs, newlines) through `Parser.parseString`.
- Pure-noise queries (rejection paths) alternating with fragment-assembled queries (`(identifier) @x`, predicates, quantifiers) that frequently compile — those also execute against the fuzzed tree, covering the matcher, predicates, and cursor iteration.

Typical output:

```text
fuzz: 2000 iterations (seed 12648430): parses ok=2000 err=0, queries ok=228 rejected=1772 matches=1987
```

Good follow-ups when extending it: truncated/mutated corpus seeds, `endByte ≤ len` assertions, changed-range stability, and incremental-vs-fresh equality on mutated pairs.

Related: [Testing](/development/testing), [Conformance](/development/conformance), [Error Recovery](/concepts/error-recovery).
