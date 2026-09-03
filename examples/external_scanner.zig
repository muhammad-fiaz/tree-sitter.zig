const std = @import("std");
const treesitter = @import("treesitter");

/// External scanner demo: the outline language lexes `newline`,
/// `indent`, `dedent`, and `blank` tokens through a stateful Zig
/// scanner. Scanner state is caller-owned: copy the language, point it
/// at a live state value, and parse with the copy.
pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();

    var lang = treesitter.outline_language;
    var scan_state = treesitter.OutlineScanState.init(gpa);
    defer scan_state.deinit();
    lang.external_scanner.?.payload = &scan_state;
    try parser.setLanguage(lang);

    var tree = try parser.parseString("# Shopping\n  # Fruit\n  - pears\n- bread\n");
    defer tree.deinit();

    const root = tree.rootNode();
    std.debug.print("root: {s} has_error={}\n", .{ root.nodeType(), tree.hasError() });

    var query = try parser.compileQuery("(header) @h");
    defer query.deinit();
    var cursor = parser.queryCursor();
    defer cursor.deinit();
    try cursor.execute(lang, query.patterns(), query.nodes(), query.captureNames(), &tree);
    while (cursor.nextMatch()) |m| {
        std.debug.print("header: {s}\n", .{m.captures[0].node.text()});
    }
}
