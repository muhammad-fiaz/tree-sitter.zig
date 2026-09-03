---
description: Allocator API — the one-handoff rule and lifetime requirements.
---

# Allocator

<VersionBadge />

## Overview

The library takes `std.mem.Allocator` — the standard Zig 0.16.0 interface — in exactly one typical place. Sources: `src/memory/`, `std.mem.Allocator`.

## The rule

```zig
var parser = treesitter.Parser.init(allocator); // the handoff
```

Everything else inherits: `Tree` stores it, `tree.cursor()` / `parser.queryCursor()` / `parser.compileQuery()` / `getChangedRanges` reuse it. Standalone constructors accept an explicit allocator for parentless use.

## Requirements

- The allocator must outlive every object created from it.
- Any `std.mem.Allocator` works: `DebugAllocator`, `ArenaAllocator`, `FixedBufferAllocator`, `SmpAllocator`, page allocator, testing allocators.
- No hidden global or fallback allocators exist anywhere in the runtime.

## Helpers

`memory/allocator.zig` (`allocMany`, `dupeSlice`, `freeSlice`), `memory/arena.zig` (`Arena` wrapper with `reset`/`queryCapacity`), `memory/refcount.zig` (atomic `RefCount`), `memory/ownership.zig` (`OwnerToken`, `Ownership`).

## Related pages

[Allocators](/guide/allocators), [Memory Management](/guide/memory-management), [Allocator Model](/reference/allocator-model)
