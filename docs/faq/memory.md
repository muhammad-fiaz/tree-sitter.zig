---
description: Memory FAQ — allocators, ownership, deinit, and allocation failures.
---

# Memory FAQ

## How do I provide an allocator?

Once: `Parser.init(allocator)`. Everything else inherits it. See [Allocators](/guide/allocators).

## What must I deinit?

Parsers, trees, cursors, queries, query cursors, and changed-range slices. Nodes never.

## What happens on allocation failure?

`OutOfMemory` propagates with partial state cleaned up — covered by failing-allocator tests.

## Can objects outlive the allocator?

No. The allocator must outlive everything created from it.
