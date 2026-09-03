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

    var old_tree = try parser.parseString("1 + 2");
    defer old_tree.deinit();
    std.debug.print("before: {s}\n", .{old_tree.rootNode().text()});

    const edit = treesitter.InputEdit{
        .start_byte = 4,
        .old_end_byte = 5,
        .new_end_byte = 6,
        .start_point = .{ .row = 0, .column = 4 },
        .old_end_point = .{ .row = 0, .column = 5 },
        .new_end_point = .{ .row = 0, .column = 6 },
    };
    var new_tree = try parser.parse(&old_tree, edit, "1 + 22");
    defer new_tree.deinit();
    std.debug.print("after:  {s}\n", .{new_tree.rootNode().text()});

    const ranges = try old_tree.getChangedRanges(&new_tree);
    defer old_tree.freeChangedRanges(ranges);
    for (ranges) |r| {
        std.debug.print("changed: bytes [{d}, {d}]\n", .{ r.start_byte, r.end_byte });
    }
}
