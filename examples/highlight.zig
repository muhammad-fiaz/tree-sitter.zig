const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expressionLanguage;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    const source = "price * (count + 1)";
    var tree = try parser.parseString(source);
    defer tree.deinit();

    var cursor = tree.cursor();
    defer cursor.deinit();

    std.debug.print("Highlighting tokens for: {s}\n", .{source});
    outer: while (true) {
        const node = cursor.currentNode();
        // Classify leaf tokens (nodes without children)
        if (node.childCount() == 0) {
            const kind = if (std.mem.eql(u8, node.nodeType(), "identifier"))
                "variable"
            else if (std.mem.eql(u8, node.nodeType(), "number"))
                "constant"
            else
                "operator";
            std.debug.print("span [{d: >2}..{d: >2}]: {s: <10} => {s}\n", .{
                node.startByte(),
                node.endByte(),
                node.text(),
                kind,
            });
        }
        if (cursor.gotoFirstChild()) continue;
        while (true) {
            if (cursor.gotoNextSibling()) break;
            if (!cursor.gotoParent()) break :outer;
        }
    }
}
