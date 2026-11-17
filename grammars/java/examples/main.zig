const std = @import("std");
const treesitter = @import("treesitter");
const grammar = @import("tree_sitter_java");

pub fn main() !void {
    std.debug.print("Native Zig grammar for java:\n", .{});
    std.debug.print("  Name: {s}\n", .{grammar.language.metadata.name});
    std.debug.print("  Symbols: {d}\n", .{grammar.language.metadata.symbol_count});
    std.debug.print("  States: {d}\n", .{grammar.language.metadata.state_count});

    const allocator = std.heap.page_allocator;
    var parser = treesitter.Parser.init(allocator);
    defer parser.deinit();

    const lang = grammar.language;
    try parser.setLanguage(lang);

    const source = "public class Main { public static int add(int a, int b) { return a + b; } }";
    var tree = try parser.parseString(source);
    defer tree.deinit();

    std.debug.print("  Parsed: root={s} error={}\n", .{
        tree.rootNode().nodeType(),
        tree.hasError(),
    });
}
