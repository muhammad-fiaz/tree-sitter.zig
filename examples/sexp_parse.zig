const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.sexp_language;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseString("(add 1 (mul 2 3))");
    defer tree.deinit();

    const root = tree.rootNode();
    std.debug.print("root: {s} [{d}, {d}]\n", .{ root.nodeType(), root.startByte(), root.endByte() });
    const seq = root.child(0).?.child(0).?.child(1).?;
    std.debug.print("grouped list aliased to: {s} text='{s}'\n", .{ seq.nodeType(), seq.text() });

    var query = try parser.compileQuery("(sequence) @list");
    defer query.deinit();
    var cursor = parser.queryCursor();
    defer cursor.deinit();
    try cursor.execute(grammar, query.patterns(), query.nodes(), query.captureNames(), &tree);
    std.debug.print("sequence matches: {d}\n", .{cursor.matchCount()});
}
