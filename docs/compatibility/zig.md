---
description: Zig version compatibility — tree-sitter.zig targets Zig 0.17.0+.
---

# Zig
 
`tree-sitter.zig` version **0.0.2** targets **Zig 0.17.0+** (`minimum_zig_version = "0.17.0"`, verified against the local SDK standard library). All APIs build directly on the Zig 0.17.0 standard library (`std.Io`, explicit allocators, monotonic clocks).
 
> [!NOTE]
> For projects using **Zig 0.16.0**, use release **0.0.1**:
>
> ```bash
> zig fetch --save https://github.com/muhammad-fiaz/tree-sitter.zig/archive/refs/tags/0.0.1.tar.gz
> ```
>
> See [Zig 0.16 Support](/development/zig-0.16) for details.
 
Related: [Zig 0.17 Notes](/development/zig-0.17), [Zig 0.16 Support](/development/zig-0.16), [Feature Matrix](/compatibility/feature-matrix).
