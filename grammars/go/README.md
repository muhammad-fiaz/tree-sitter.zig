# tree-sitter-go

Pure native Zig grammar and parsing package for Go.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const go = @import("tree_sitter_go");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(go.language);
    var tree = try parser.parseString("package main\\n\\nfunc main() {\\n    return\\n}\\n");
    defer tree.deinit();

    std.debug.print("Parsed Go tree: has_error={}\n", .{tree.hasError()});
}
```
