const std = @import("std");
const treesitter = @import("treesitter");

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    std.debug.print("Generating 25,000 token test document in memory...\n", .{});
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(gpa);

    try buf.appendSlice(gpa, "1");
    for (0..25000) |_| {
        try buf.appendSlice(gpa, " + 2");
    }

    std.debug.print("Document size: {d} bytes\n", .{buf.items.len});

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(treesitter.expressionLanguage);

    var tree = try parser.parseString(buf.items);
    defer tree.deinit();

    std.debug.print("Parsed large file: nodes={d}, error={}\n", .{
        tree.pool.nodes.items.len,
        tree.hasError(),
    });

    std.debug.print("Large file parsing demonstration completed successfully!\n", .{});
}
