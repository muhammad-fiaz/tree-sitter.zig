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

    for ([_][]const u8{ "1 + * 2", "(1 + 2", "1 @ 2" }) |source| {
        var tree = try parser.parseString(source);
        defer tree.deinit();
        std.debug.print("{s} => has_error={} nodes={d}\n", .{ source, tree.hasError(), tree.nodeCount() });
    }
}
