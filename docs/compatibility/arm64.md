---
description: ARM64 notes — no architecture-specific behavior in the runtime.
---

# ARM64

`aarch64-windows`, `aarch64-linux`, and `aarch64-macos` all compile clean. The runtime uses no intrinsics, no endianness assumptions, and no pointer-width tricks — atomics go through `std.atomic` with explicit orderings, so ARM's memory model is respected by construction.

Related: [x86-64](/compatibility/x86-64), [Feature Matrix](/compatibility/feature-matrix).
