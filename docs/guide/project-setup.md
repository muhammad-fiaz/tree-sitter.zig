---
description: Set up a Zig 0.16.0 project that depends on tree-sitter.zig.
---

# Project Setup

## What you'll learn

- The minimal `build.zig` / `build.zig.zon` wiring for a consumer project.
- Which Zig version gate to enforce.

## Complete example

`build.zig.zon`:

```zig
.{
    .name = .my_app,
    .version = "0.0.0",
    .fingerprint = 0x1234567890abcdef,
    .minimum_zig_version = "0.16.0",
    .dependencies = .{
        .treesitter = .{
            .url = "https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.1.tar.gz",
            .hash = "...",
        },
    },
    .paths = .{ "build.zig", "build.zig.zon", "src" },
}
```

`build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const treesitter = b.dependency("treesitter", .{ .target = target, .optimize = optimize });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("treesitter", treesitter.module("treesitter"));
    const exe = b.addExecutable(.{ .name = "my_app", .root_module = exe_mod });
    b.installArtifact(exe);
}
```

`src/main.zig`:

```zig
const treesitter = @import("treesitter");

pub fn main() !void {
    _ = treesitter.version;
}
```

## How it works

The package exposes a single module named `treesitter` whose root is `src/treesitter.zig`. Consumers always import exactly that name, so swapping between fetched, vendored, and source checkouts never changes application code.

## Related guides

- [Installation](/guide/installation)
- [Your First Parser](/guide/first-parser)
