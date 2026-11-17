# tree-sitter-html

Pure native Zig grammar and parsing package for HTML.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const html = @import("tree_sitter_html");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(html.language);
    var tree = try parser.parseString("<div class=\"container\"><span>Hello</span></div>");
    defer tree.deinit();

    std.debug.print("Parsed HTML tree: has_error={}\n", .{tree.hasError()});
}
```
