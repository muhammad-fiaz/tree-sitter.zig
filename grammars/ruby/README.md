# tree-sitter-ruby

Pure native Zig grammar and parsing package for Ruby.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const ruby = @import("tree_sitter_ruby");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(ruby.language);
    var tree = try parser.parseString("def calculate(value)\\n  return value\\nend\\n");
    defer tree.deinit();

    std.debug.print("Parsed Ruby tree: has_error={}\n", .{tree.hasError()});
}
```
