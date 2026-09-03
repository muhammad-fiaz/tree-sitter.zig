---
description: Allocator patterns for tree-sitter.zig — pass once, inherit everywhere.
---

# Allocators

## What you'll learn

- Why only `Parser.init` takes an allocator and how every other object inherits it.

## The one-allocator rule

```zig
var parser = treesitter.Parser.init(allocator); // ← the single handoff
defer parser.deinit();

var tree = try parser.parseString(src); // inherits parser allocator
var cursor = tree.cursor(); // inherits tree allocator
var query = try parser.compileQuery("(identifier) @id"); // inherits parser allocator
var qcursor = parser.queryCursor(); // inherits parser allocator
```

Standalone constructors (`TreeCursor.init(gpa, node)`, `Query.compile(gpa, lang, src)`, `QueryCursor.init(gpa)`, `getChangedRanges(gpa, a, b)`) still exist for code that builds those objects without a parser or tree. Prefer the inheriting forms in application code.

## Choosing an allocator

| Allocator | Use for |
|-----------|---------|
| `std.heap.DebugAllocator` | Development, tests, leak detection (what the test suite uses) |
| `std.heap.ArenaAllocator` | Batch jobs: parse thousands of files, then free once |
| `std.heap.FixedBufferAllocator` | Embedded budgets and allocation-failure testing |
| `std.heap.SmpAllocator` / page allocator | Long-lived editor-grade processes |

The test suite exercises `std.testing.failing_allocator` to prove `OutOfMemory` propagates without leaks or corruption.

## API used

- [Allocator](/api/allocator), [Parser](/api/parser).

## Related guides

- [Memory Management](/guide/memory-management), [Testing](/guide/testing)
