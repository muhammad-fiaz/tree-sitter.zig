---
description: Zig version compatibility — tree-sitter.zig targets Zig 0.16.0 exactly.
---

# Zig

tree-sitter.zig targets **exactly Zig 0.16.0** (`minimum_zig_version = "0.16.0"`, verified against the installed SDK source — not older-version idioms). Older (`std.io` streams, managed `ArrayList`) and newer APIs are not assumed. If a future release retargets, the version badge, `build.zig.zon`, README, and this page move together.

Related: [Zig 0.16 Notes](/development/zig-0.16), [Feature Matrix](/compatibility/feature-matrix).
