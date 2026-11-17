const std = @import("std");
const treesitter = @import("treesitter");

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    std.debug.print("Simulating real-time code editor buffer editing session...\n", .{});

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(treesitter.expressionLanguage);

    // Initial buffer state
    const doc_v1 = "var_a = 10 + 20";
    std.debug.print("1. Initial document state:\n   '{s}'\n", .{doc_v1});
    var tree = try parser.parseString(doc_v1);
    defer tree.deinit();
    std.debug.print("   Initial tree: has_error={}, nodes={d}\n", .{ tree.hasError(), tree.pool.nodes.items.len });

    // User types: replaces "20" with "200 * factor"
    const doc_v2 = "var_a = 10 + 200 * factor";
    std.debug.print("2. User edit: expanded term at offset 13:\n   '{s}'\n", .{doc_v2});

    const edit = treesitter.InputEdit{
        .start_byte = 13,
        .old_end_byte = 15,
        .new_end_byte = 25,
        .start_point = .{ .row = 0, .column = 13 },
        .old_end_point = .{ .row = 0, .column = 15 },
        .new_end_point = .{ .row = 0, .column = 25 },
    };

    tree.edit(edit);

    var tree_v2 = try parser.parse(&tree, edit, doc_v2);
    defer tree_v2.deinit();

    std.debug.print("3. Reparsed with incremental tree reuse:\n", .{});
    std.debug.print("   Reparsed tree: has_error={}, nodes={d}\n", .{ tree_v2.hasError(), tree_v2.pool.nodes.items.len });

    const changed_ranges = try treesitter.getChangedRanges(gpa, &tree, &tree_v2);
    defer treesitter.freeChangedRanges(gpa, changed_ranges);

    std.debug.print("   Detected {d} changed syntax ranges:\n", .{changed_ranges.len});
    for (changed_ranges) |cr| {
        std.debug.print("     Changed range: bytes [{d}..{d}]\n", .{ cr.start_byte, cr.end_byte });
    }

    std.debug.print("Editor incremental parsing session completed successfully!\n", .{});
}
