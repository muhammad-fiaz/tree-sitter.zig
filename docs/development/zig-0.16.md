---
description: Zig 0.16 compatibility — using tree-sitter.zig version 0.0.1 on Zig 0.16.0.
---

# Zig 0.16 Support

> [!NOTE]
> `tree-sitter.zig` version **0.0.2+** targets **Zig 0.17.0+**.
>
> If your project is using **Zig 0.16.0**, use `tree-sitter.zig` version **0.0.1**.

## Installing Version 0.0.1 for Zig 0.16.0

To add the Zig 0.16.0-compatible release to your project:

### Using `zig fetch`

```sh
zig fetch --save https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.1.tar.gz
```

### Manual `build.zig.zon`

Add the dependency to your `build.zig.zon`:

```zig
.dependencies = .{
    .treesitter = .{
        .url = "https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.1.tar.gz",
    },
},
```

> [!IMPORTANT]
> Version `0.0.1` is maintained for projects targeting Zig 0.16.0. For modern projects on Zig 0.17.0+, use `0.0.2` or later as documented in [Installation](/guide/installation) and [Zig 0.17 Notes](/development/zig-0.17).
