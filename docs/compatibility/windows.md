---
description: Windows compatibility — validated targets and notes.
---

# Windows

Validated via `zig build-lib --target <t> -fno-emit-bin` plus the native test suite on `x86_64-windows`:

- `x86-windows` — compiles clean.
- `x86_64-windows` — compiles clean; full `zig build test` green.
- `aarch64-windows` — compiles clean.

No `usize`-to-`u64` assumptions, no POSIX-only calls on any path. Examples run as `.exe` via `zig build run-<name>`.

Related: [Feature Matrix](/compatibility/feature-matrix).
