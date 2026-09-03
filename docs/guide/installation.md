---
description: Install tree-sitter.zig 0.0.1 — Zig fetch (stable), manual configuration, source builds, and vendoring.
---

# Installation

<VersionBadge />

## What you'll learn

- The four ways to add `tree-sitter.zig` **0.0.1** (current stable) to your project.
- How to install the latest development snapshot.

## Method 1: Zig Fetch (Recommended Stable)

```sh
zig fetch --save https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.1.tar.gz
```

This records the dependency and its hash in your `build.zig.zon`, then import it in `build.zig`:

```zig
const treesitter = b.dependency("treesitter", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("treesitter", treesitter.module("treesitter"));
```

## Method 2: Manual Configuration

Add this to your `build.zig.zon` (replace `...` with the real hash — run `zig build` once and copy it from the error message):

```zig
.dependencies = .{
    .treesitter = .{
        .url = "https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.1.tar.gz",
        .hash = "...",
    },
},
```

Then wire the module exactly as in Method 1.

## Development builds

For the latest `main` snapshot instead of stable:

```sh
zig fetch --save git+https://github.com/muhammad-fiaz/tree-sitter.zig.git
```

## Method 3: Building from Source

```sh
git clone https://github.com/muhammad-fiaz/tree-sitter.zig.git
cd tree-sitter.zig
zig build
zig build test
```

Useful commands:

```sh
zig build test       # full test suite
zig build examples   # all eight runnable examples
zig build bench      # benchmark (add -Doptimize=ReleaseFast)
zig build docs       # native Zig autodoc into zig-out/docs
```

## Prebuilt Library

Release archives (`.tar.gz` source snapshots such as `0.0.1.tar.gz`) are published on the [Releases page](https://github.com/muhammad-fiaz/tree-sitter.zig/releases). To vendor manually, extract the archive and expose its `src/treesitter.zig` as a module:

```zig
const treesitter_mod = b.addModule("treesitter", .{
    .root_source_file = b.path("vendor/tree-sitter.zig-0.0.1/src/treesitter.zig"),
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("treesitter", treesitter_mod);
```

## Verifying the installation

```zig
const treesitter = @import("treesitter");
comptime {
    if (!std.mem.eql(u8, treesitter.version, "0.0.1")) @compileError("unexpected treesitter version");
}
```

Continue with [Project Setup](/guide/project-setup) or jump to [Your First Parser](/guide/first-parser).

## Related API

- [Allocator](/api/allocator) — what the dependency needs from your program (one allocator, once).
