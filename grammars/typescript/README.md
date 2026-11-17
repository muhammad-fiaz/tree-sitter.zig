# tree-sitter-typescript

Pure native Zig grammar and parsing package for TypeScript.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const typescript = @import("tree_sitter_typescript");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(typescript.language);
    var tree = try parser.parseString("function calculate(x: number): number { return x * 2; }");
    defer tree.deinit();

    std.debug.print("Parsed TypeScript tree: has_error={}\n", .{tree.hasError()});
}
```
