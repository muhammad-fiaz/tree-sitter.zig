---
description: Zig 0.16.0 notes — the exact standard-library APIs tree-sitter.zig builds on.
---

# Zig 0.16 Notes

This project targets **exactly Zig 0.16.0**; the SDK source is the authority, not memory of older versions.

- **Allocators**: `std.mem.Allocator` interface from `lib/std/mem/Allocator.zig`; `DebugAllocator`, `ArenaAllocator`, `FixedBufferAllocator`, `SmpAllocator` from `std.heap`.
- **Lists**: unmanaged `std.ArrayList(T)` — `.empty`, methods taking `gpa` explicitly (`append(gpa, x)`, `deinit(gpa)`).
- **Maps**: managed `StringHashMap` / `AutoHashMap` (`.init(gpa)` / `.deinit()`).
- **I/O**: new `std.Io` (`Io.Reader.readSliceShort`, `Io.Timestamp`, `Io.Writer.print`); debug output via `std.debug.print`. No legacy `std.io` usage.
- **Text**: `std.ascii` predicates, `std.mem.sort` with context comparators, `std.StaticBitSet` / `DynamicBitSetUnmanaged`.
- **Testing**: `std.testing.allocator`, `failing_allocator`, `checkAllAllocationFailures`-style failure injection.
- **Build**: `b.addModule` / `createModule` / `addTest` / `addExecutable` with `root_module`, `addRunArtifact`, `getEmittedDocs`, `addInstallDirectory`.
- **Time**: monotonic clock via `std.Io.Timestamp.now(io, .awake)` — `std.time` no longer hosts wall-clock helpers.

When in doubt, read `C:\tools\zig-x86_64-windows-0.16.0\lib\std\` before assuming an API exists.

Related: [Compatibility: Zig](/compatibility/zig).
