# tree-sitter-java

Pure native Zig grammar and parsing package for Java.

## Features

- 100% native Zig implementation.
- Compatible with tree-sitter.zig parsing engine.
- Syntax highlighting queries (`queries/highlights.scm`).
- Code symbol tag queries (`queries/tags.scm`).

## Usage

```zig
const std = @import("std");
const treesitter = @import("treesitter");
const java = @import("tree_sitter_java");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(java.language);
    var tree = try parser.parseString("public class App { public static void main() { return; } }");
    defer tree.deinit();

    std.debug.print("Parsed Java tree: has_error={}\n", .{tree.hasError()});
}
```
