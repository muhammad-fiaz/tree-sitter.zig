# tree-sitter-json

Pure native Zig grammar and parsing package for JSON.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const json = @import("tree_sitter_json");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(json.language);
    var tree = try parser.parseString("{\"name\": \"tree-sitter\", \"version\": 1}");
    defer tree.deinit();

    std.debug.print("Parsed JSON tree: has_error={}\n", .{tree.hasError()});
}
```
