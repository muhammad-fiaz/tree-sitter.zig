const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expression_language;

/// Query directives demo: `#set!` metadata, general directives, and the
/// application-level `select-adjacent` / `strip` helpers.
pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseString("foo + bar");
    defer tree.deinit();

    var query = try parser.compileQuery("((identifier) @x (#set! kind \"variable\") (#select-adjacent! @x @x))");
    defer query.deinit();

    for (query.propertySettings(0)) |setting| {
        std.debug.print("setting: {s} = {s}\n", .{ setting.key, setting.value orelse "(none)" });
    }
    for (query.generalPredicates(0)) |directive| {
        std.debug.print("directive: {s} args={d}\n", .{ directive.operator, directive.args.len });
    }

    var cursor = parser.queryCursor();
    defer cursor.deinit();
    try cursor.execute(grammar, query.patterns(), query.nodes(), query.captureNames(), &tree);
    while (cursor.nextMatch()) |m| {
        const kept = try treesitter.query_mod.directives.selectAdjacent(gpa, m.captures, 0, 0);
        defer gpa.free(kept);
        for (kept) |cap| std.debug.print("@{s}: {s}\n", .{ cap.name, cap.node.text() });
    }

    const stripped = try treesitter.query_mod.directives.stripText(gpa, "## shopping", "^#+");
    defer gpa.free(stripped);
    std.debug.print("stripped: '{s}'\n", .{stripped});
}
