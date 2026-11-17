# tree-sitter-zig

Pure native Zig grammar and parsing package for Zig.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const zig = @import("tree_sitter_zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(zig.language);
    var tree = try parser.parseString("pub fn square(x: i32) i32 { return x * x; }");
    defer tree.deinit();

    std.debug.print("Parsed Zig tree: has_error={}\n", .{tree.hasError()});
}
```
