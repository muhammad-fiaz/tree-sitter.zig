const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expression_language;

fn printNode(node: treesitter.Node, depth: usize) void {
    for (0..depth) |_| std.debug.print("  ", .{});
    std.debug.print("{s} [{d}, {d}] named={}\n", .{ node.nodeType(), node.startByte(), node.endByte(), node.isNamed() });
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        printNode(node.child(i).?, depth + 1);
    }
}

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseString("a * (b + 2)");
    defer tree.deinit();
    printNode(tree.rootNode(), 0);
}
