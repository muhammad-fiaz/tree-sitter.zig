# tree-sitter-rust

Pure native Zig grammar and parsing package for Rust.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const rust = @import("tree_sitter_rust");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(rust.language);
    var tree = try parser.parseString("pub fn compute(val: i32) -> i32 { val * 4 }");
    defer tree.deinit();

    std.debug.print("Parsed Rust tree: has_error={}\n", .{tree.hasError()});
}
```
