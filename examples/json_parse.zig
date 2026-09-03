const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.json_language;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseString("{\"name\": \"ada\", \"scores\": [10, 20.5, -3e-2], \"admin\": true}");
    defer tree.deinit();

    const root = tree.rootNode();
    std.debug.print("root: {s} has_error={}\n", .{ root.nodeType(), tree.hasError() });

    var pair_query = try parser.compileQuery("(pair) @p");
    defer pair_query.deinit();
    var pair_cursor = parser.queryCursor();
    defer pair_cursor.deinit();
    try pair_cursor.execute(grammar, pair_query.patterns(), pair_query.nodes(), pair_query.captureNames(), &tree);
    const first = pair_cursor.nextMatch().?.captures[0].node;
    std.debug.print("first pair: key={s} value={s}\n", .{
        first.childByFieldName("key").?.text(),
        first.childByFieldName("value").?.text(),
    });

    var query = try parser.compileQuery("(string) @s");
    defer query.deinit();
    var cursor = parser.queryCursor();
    defer cursor.deinit();
    try cursor.execute(grammar, query.patterns(), query.nodes(), query.captureNames(), &tree);
    std.debug.print("strings: {d}\n", .{cursor.matchCount()});
    while (cursor.nextMatch()) |m| {
        std.debug.print("  {s}\n", .{m.captures[0].node.text()});
    }
}
