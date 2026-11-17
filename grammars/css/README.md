# tree-sitter-css

Pure native Zig grammar and parsing package for CSS.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const css = @import("tree_sitter_css");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(css.language);
    var tree = try parser.parseString(".header { color: red; font-size: 16px; }");
    defer tree.deinit();

    std.debug.print("Parsed CSS tree: has_error={}\n", .{tree.hasError()});
}
```
