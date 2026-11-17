# tree-sitter-php

Pure native Zig grammar and parsing package for PHP.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const php = @import("tree_sitter_php");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(php.language);
    var tree = try parser.parseString("function test() { return 42; }");
    defer tree.deinit();

    std.debug.print("Parsed PHP tree: has_error={}\n", .{tree.hasError()});
}
```
