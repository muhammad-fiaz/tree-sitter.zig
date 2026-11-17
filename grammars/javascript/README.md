# tree-sitter-javascript

Pure native Zig grammar and parsing package for JavaScript.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const javascript = @import("tree_sitter_javascript");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(javascript.language);
    var tree = try parser.parseString("function multiply(a, b) { return a * b; }");
    defer tree.deinit();

    std.debug.print("Parsed JavaScript tree: has_error={}\n", .{tree.hasError()});
}
```
