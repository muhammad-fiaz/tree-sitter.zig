---
description: Allocator model reference — Zig 0.16.0 facilities and their exact use.
---

# Allocator Model

## Interface

Everything is expressed through `std.mem.Allocator` (verified against `lib/std/mem/Allocator.zig` in the 0.16.0 SDK): `alloc` / `resize` / `remap` / `free` plus the convenience wrappers (`alloc`, `dupe`, `alignedAlloc`, `free`).

## Containers

- Unmanaged `std.ArrayList(T)` (`.empty`, methods taking `gpa`) backs every growable buffer: stacks, pools, scratch, matches.
- Managed `std.StringHashMap` / `AutoHashMap` are available for maps; the hot paths avoid hashing entirely.
- `std.heap.ArenaAllocator` wraps batch workloads; the library's `memory.Arena` adds `reset`/`queryCapacity` conveniences.

## Rules enforced by tests

- One handoff (`Parser.init`); inheritance everywhere else.
- No `std.heap.page_allocator` fallback, no global singleton, no per-operation allocator parameters on the hot path.
- `OutOfMemory` propagates with partial state cleaned up (failing-allocator tests).
- `std.testing.allocator` across the suite means any leak fails CI.

## Related pages

[Allocators](/guide/allocators), [Ownership](/reference/ownership), [Allocator API](/api/allocator)
