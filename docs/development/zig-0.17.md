---
description: Zig 0.17 notes — standard-library facilities and installation for tree-sitter.zig 0.0.2.
---

# Zig 0.17 Notes

`tree-sitter.zig` targets **Zig 0.17.0+** starting with release **0.0.2**.

## Installation for Zig 0.17.0+

### Method 1: Zig Fetch (Stable v0.0.2)

```sh
zig fetch --save https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.2.tar.gz
```

### Method 2: `build.zig.zon` Dependency

Add `tree-sitter.zig` to your `build.zig.zon`:

```zig
.dependencies = .{
    .treesitter = .{
        .url = "https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.2.tar.gz",
    },
},
```

### Adding to `build.zig`

Attach the module to your executable or library:

```zig
const treesitter_dep = b.dependency("treesitter", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("treesitter", treesitter_dep.module("treesitter"));
```

---

## Zig 0.17 Standard Library Facilities

The runtime is pure Zig with zero external dependencies, building directly on the local Zig 0.17.0 standard library (`lib/std/std.zig`):

- **Allocators**: `std.mem.Allocator` interface (`alloc`, `resize`, `remap`, `free`, `dupe`, `create`, `destroy`).
- **Containers**: Unmanaged `std.ArrayList(T)` (`.empty`, passing allocator explicitly: `append(gpa, x)`, `deinit(gpa)`).
- **Maps**: Managed `StringHashMap` / `AutoHashMap` (`.init(gpa)` / `.deinit()`).
- **I/O & Files**: Modern `std.Io` namespace (`std.Io.File`, `std.Io.Dir`, `std.Io.Reader`, `std.Io.Writer`).
- **Time & Clock**: Monotonic clock via `std.Io.Timestamp.now(io, .awake)` with `std.Io.Threaded.global_single_threaded.io()`. Sleeping via `std.Io.sleep(io, duration, .awake)`.
- **Text & Unicode**: `std.unicode` decoders and encoders, `std.ascii` predicates, context comparators with `std.mem.sort`, and bitsets with `std.StaticBitSet` / `DynamicBitSetUnmanaged`.
- **Testing**: `std.testing.allocator`, `failing_allocator`, leak detection, and failure-injection tests.
- **Build System**: `b.addModule`, `createModule`, `addTest`, `addExecutable`, `addPassthruArgs`, `getEmittedDocs`.

Related: [Installation Guide](/guide/installation), [Compatibility: Zig](/compatibility/zig), [Zig 0.16 Support](/development/zig-0.16).
