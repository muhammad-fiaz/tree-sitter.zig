---
description: Concurrency, ownership, and thread-safety guarantees for every public type in tree-sitter.zig.
---

# Concurrency & Ownership

This page documents the exact ownership, lifetime, and thread-safety guarantees for every public type in **tree-sitter.zig**.  Read this before writing multi-threaded code that uses the library.

> [!IMPORTANT]
> Three separate concepts must never be confused:
>
> | Concept | Description |
> |---|---|
> | **I/O execution model** | Which `std.Io` context is used for timeouts and DOT graphs |
> | **Parser concurrency model** | Whether one `Parser` may be used from multiple threads |
> | **Allocator concurrency model** | Whether the backing allocator is thread-safe |
>
> Configuring a multi-threaded `std.Io` context does **not** make the parser safe for concurrent mutation.

---

## Type Concurrency Matrix

| Type | Mutable | Shareable across threads | Concurrent reads | Concurrent mutation | Synchronisation required |
|---|---|---|---|---|---|
| `Parser` | Yes | No | No | No | Caller |
| `Language` (no payload) | No | Yes | Yes | N/A | None |
| `Language` (with payload) | Yes (payload) | No | No | No | Caller |
| `Tree` | After applyEdit | Yes (immutable) | Yes | No (exclusive) | Caller for mutation |
| `Node` | No | Yes (immutable) | Yes | N/A | None |
| `TreeCursor` | Yes | No | No | No | Caller |
| `Query` (read-only) | No | Yes | Yes | N/A | None |
| `Query` (after disableCapture) | Yes | No | No | No | Caller |
| `QueryCursor` | Yes | No | No | No | Caller |
| `OutlineScanState` | Yes | No | No | No | Caller |

---

## Parser

A `Parser` instance must be used from **one thread at a time**.

**Correct — independent parsers per thread:**

`zig
var parserA = treesitter.Parser.init(allocatorA);
defer parserA.deinit();
`

**Ownership**: borrows `gpa`; allocator must outlive the parser.
**I/O context**: `setIo` controls timeout/DOT context only — not thread safety.

---

## Language

All built-in languages are static and immutable. They may be shared across threads without synchronisation.

**Exception**: a `Language` copy with `external_scanner.?.payload` set is mutable and must be single-threaded.

---

## Tree

After construction, a `Tree` is immutable and may be read concurrently from multiple threads. Mutation (`applyEdit`) requires exclusive access.

`Node` and `TreeCursor` borrow `*const Tree` and must not outlive it.

---

## TreeCursor / QueryCursor

These are stateful and exclusively owned. Create one per thread for parallel workloads.

---

## Verified Concurrency Scenarios

| Scenario | Status |
|---|---|
| Multiple parsers on multiple OS threads | Verified |
| Shared immutable Tree with independent cursors | Verified |
| Shared Query with independent QueryCursors | Verified |
| parseReader — reader borrowed, not retained | Verified |
| writeDotGraph — writer borrowed, not retained | Verified |

---

## Global Mutable State Audit

tree-sitter.zig contains **no hidden global mutable state**. All parse tables are compile-time constants. No hidden mutexes or lazy-init caches.

## Summary

> [!NOTE]
> Prefer independent instances over shared mutable state. The library is designed for explicit ownership.

| Responsibility | Owner |
|---|---|
| Parser used from one thread at a time | **Caller** |
| TreeCursor / QueryCursor single-threaded | **Caller** |
| Tree mutation is exclusive | **Caller** |
| Sharing Language (no payload) | **Safe** |
| Sharing immutable Tree for reads | **Safe** |
| Sharing read-only Query | **Safe** |
| Allocator thread-safety for concurrent parsers | **Caller** |
