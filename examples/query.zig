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

    var tree = try parser.parseString("total + price * count");
    defer tree.deinit();

    var query = try parser.compileQuery("(identifier) @var");
    defer query.deinit();

    var cursor = parser.queryCursor();
    defer cursor.deinit();
    try cursor.execute(grammar, query.patterns(), query.nodes(), query.captureNames(), &tree);

    while (cursor.nextMatch()) |m| {
        for (m.captures) |cap| {
            std.debug.print("@{s}: {s} [{d}, {d}]\n", .{ cap.name, cap.node.text(), cap.node.startByte(), cap.node.endByte() });
        }
    }
}
