const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expression_language;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseString("1 + 2 * 3");
    defer tree.deinit();

    const root = tree.rootNode();
    std.debug.print("root: {s} [{d}, {d}]\n", .{ root.nodeType(), root.startByte(), root.endByte() });
    std.debug.print("has error: {}\n", .{tree.hasError()});
    std.debug.print("text: {s}\n", .{root.text()});
}
