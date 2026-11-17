# tree-sitter-c

Pure native Zig grammar and parsing package for C.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const c = @import("tree_sitter_c");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(c.language);
    var tree = try parser.parseString("int add(int a, int b) { return a + b; }");
    defer tree.deinit();

    std.debug.print("Parsed C tree: has_error={}\n", .{tree.hasError()});
}
```
