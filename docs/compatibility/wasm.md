---
description: WebAssembly support — the runtime compiles to wasm32-wasi out of the box.
---

# WebAssembly

`zig build -Dtarget=wasm32-wasi` compiles the library, every example, and every tool clean — the runtime is portable Zig standard library only (verified against Zig 0.16.0's `std` per `std.zig`): `std.mem` allocators, `std.atomic` ordering, `std.Io` clocks/readers, and `std.process` argument handling all lower to WASI. The static library also compiles for `wasm32-freestanding` (hosted syscalls like process args aside).

Two upstream pieces deliberately have no counterpart here:

- **`wasm_store.c`** (loads compiled grammar blobs at runtime): unnecessary — grammars are native Zig table data linked into the binary, on every target including WASM itself.
- **`wasm-stdlib/*`** (C shims for scanners running inside WASM): unnecessary — external scanners are Zig functions with caller-owned payloads.

Validate locally:

```sh
zig build -Dtarget=wasm32-wasi        # library + tools compile
zig build -Dtarget=wasm32-wasi test   # test artifacts compile (host executes)
```

Related: [Feature Matrix](/compatibility/feature-matrix), [Zig](/compatibility/zig).
