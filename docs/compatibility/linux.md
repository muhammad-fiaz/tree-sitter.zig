---
description: Linux compatibility — validated targets and notes.
---

# Linux

Validated via `zig build-lib --target <t> -fno-emit-bin`:

- `x86-linux` — compiles clean.
- `x86_64-linux` — compiles clean; all examples additionally compile for this target.
- `aarch64-linux` — compiles clean.

Related: [Feature Matrix](/compatibility/feature-matrix).
