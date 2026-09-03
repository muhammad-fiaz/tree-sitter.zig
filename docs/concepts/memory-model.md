---
description: Memory model — allocator handoff, ownership, and lifetimes.
---

# Memory Model

<MemoryModel />

## The handoff rule

The client allocator enters the library at exactly one place — `Parser.init` — and is then inherited: trees inherit the parser's allocator, cursors inherit their tree's or parser's, queries inherit the parser's via the convenience constructors. Standalone constructors take an explicit allocator for code that has no parent object to inherit from.

## Ownership summary

| Object | Owns | Borrows |
|--------|------|---------|
| Parser | stacks, scratch, candidates, ranges | the allocator itself, the `Language` tables |
| Tree | source copy, node pool, child indices | the allocator, the `Language` |
| Node | nothing | its tree |
| TreeCursor | path stack | its tree |
| Query | patterns, captures, predicate args | the allocator, the `Language` |
| QueryCursor | match lists | the allocator |
| Range slice | nothing (caller-owned) | — |

`Language` table data is always borrowed — grammars are typically comptime-known statics, and the runtime never frees them.

## Related pages

- [Memory Management](/guide/memory-management), [Allocators](/guide/allocators)
- [Ownership](/reference/ownership), [Allocator Model](/reference/allocator-model), [Memory Runtime](/internals/memory-runtime)
