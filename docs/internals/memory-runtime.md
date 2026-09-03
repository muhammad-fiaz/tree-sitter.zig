---
description: Memory runtime internals — pools, arenas, refcounts, and allocator plumbing.
---

# Memory Runtime

`src/memory/` stays thin by design: `allocator.zig` re-exports the `std.mem.Allocator` interface with small helpers; `arena.zig` wraps `std.heap.ArenaAllocator` (`init`/`deinit`/`allocator`/`reset`/`queryCapacity`); `refcount.zig` is an atomic `RefCount` for future shared structures; `ownership.zig` documents the borrow/own vocabulary (`OwnerToken`). The deliberate non-goal is a custom allocator framework — the standard facilities plus pooled tree storage already give the hot paths zero per-node allocation.

## Related pages

[Memory Model](/concepts/memory-model), [Allocator Model](/reference/allocator-model)
