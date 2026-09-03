---
description: macOS compatibility — validated targets and notes.
---

# macOS

Validated via `zig build-lib --target <t> -fno-emit-bin`:

- `x86_64-macos` — compiles clean.
- `aarch64-macos` (Apple Silicon) — compiles clean.

The `std.Io` clock backend used by benchmarks resolves per-OS (monotonic/uptime sources); parsing itself makes no OS calls.

Related: [Feature Matrix](/compatibility/feature-matrix).
