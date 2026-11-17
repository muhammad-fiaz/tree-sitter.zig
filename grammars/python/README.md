# tree-sitter-python

Pure native Zig grammar and parsing package for Python.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const python = @import("tree_sitter_python");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(python.language);
    var tree = try parser.parseString("def greet(name):\\n    return name\\n");
    defer tree.deinit();

    std.debug.print("Parsed Python tree: has_error={}\n", .{tree.hasError()});
}
```
