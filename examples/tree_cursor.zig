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

    var tree = try parser.parseString("a + b * c");
    defer tree.deinit();

    var cursor = tree.cursor();
    defer cursor.deinit();

    outer: while (true) {
        const node = cursor.currentNode();
        std.debug.print("depth={d} {s} [{d}, {d}]\n", .{ cursor.depth(), node.nodeType(), node.startByte(), node.endByte() });
        if (cursor.gotoFirstChild()) continue;
        while (true) {
            if (cursor.gotoNextSibling()) break;
            if (!cursor.gotoParent()) break :outer;
        }
    }
}
