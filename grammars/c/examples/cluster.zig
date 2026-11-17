const std = @import("std");
const treesitter = @import("treesitter");
const grammar = @import("tree_sitter_c");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(grammar.language);

    const source = "struct Cluster { int id; double weight; };";
    var tree = try parser.parseString(source);
    defer tree.deinit();

    std.debug.print("Successfully parsed C cluster example: root={s} error={}\n", .{
        tree.rootNode().nodeType(),
        tree.hasError(),
    });
}
