---
description: Install tree-sitter.zig 0.0.2 — Zig fetch (stable), manual configuration, source builds, and vendoring.
---

# Installation

## What you'll learn

- The four ways to add `tree-sitter.zig` **0.0.2** (current stable) to your project.
- How to install the latest development snapshot.
- How to wire the module into your `build.zig`.

## Method 1: Zig Fetch (Recommended)

Latest Stable Release (v0.0.2)

```sh
zig fetch --save https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.2.tar.gz
```

> [!NOTE]
> `tree-sitter.zig` targets **Zig 0.17.0+** (v0.0.2).
>
> For projects using **Zig 0.16.0**, use release **0.0.1**:
>
> ```bash
> zig fetch --save https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.1.tar.gz
> ```
>
> See [Zig 0.16 Support](/development/zig-0.16) for details.

## Method 2: Zig Fetch (Latest / in development)

Use this for the latest in-development version from the `main` branch:

```sh
zig fetch --save git+https://github.com/muhammad-fiaz/tree-sitter.zig.git
```

## Method 3: Manual build.zig.zon Configuration

```zig
.dependencies = .{
    .treesitter = .{
        .url = "https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.2.tar.gz",
        .hash = "...", // Run `zig fetch --save <url>` to generate the hash.
    },
},
```

## Method 4: Local Source Checkout

```sh
git clone https://github.com/muhammad-fiaz/tree-sitter.zig.git
cd tree-sitter.zig
zig build
zig build test
```

To use a local checkout from another project:

```zig
.dependencies = .{
    .treesitter = .{
        .path = "../tree-sitter.zig",
    },
},
```

## Wire into build.zig

```zig
const treesitter_dep = b.dependency("treesitter", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("treesitter", treesitter_dep.module("treesitter"));
```

Useful commands:

```sh
zig build test       # full test suite
zig build examples   # all runnable examples
zig build bench      # benchmark (add -Doptimize=ReleaseFast)
zig build docs       # native Zig autodoc into zig-out/docs
```

## Prebuilt Library

Release archives (`.tar.gz` source snapshots such as `0.0.2.tar.gz`) are published on the [Releases page](https://github.com/muhammad-fiaz/tree-sitter.zig/releases). To vendor manually, extract the archive and expose its `src/treesitter.zig` as a module:

```zig
const treesitter_mod = b.createModule(.{
    .root_source_file = b.path("vendor/tree-sitter.zig-0.0.2/src/treesitter.zig"),
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("treesitter", treesitter_mod);
```

## Verifying the installation

```zig
const treesitter = @import("treesitter");
comptime {
    if (!std.mem.eql(u8, treesitter.version, "0.0.2")) @compileError("unexpected treesitter version");
}
```

Continue with [Project Setup](/guide/project-setup) or jump to [Your First Parser](/guide/first-parser).

## Related API

- [Allocator](/api/allocator) — what the dependency needs from your program (one allocator, once).
