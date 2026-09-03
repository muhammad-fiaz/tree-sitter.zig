const std = @import("std");
const core = @import("../core/core.zig");
const tree_mod = @import("tree.zig");

pub fn applyEdit(tree: *tree_mod.Tree, edit: core.InputEdit) void {
    for (tree.pool.nodes.items) |*node| {
        node.start_byte = edit.translateByte(node.start_byte);
        node.end_byte = edit.translateByte(node.end_byte);
        node.start_point = edit.translatePoint(node.start_point);
        node.end_point = edit.translatePoint(node.end_point);
    }
}

pub fn editPoint(point: core.Point, edit: core.InputEdit) core.Point {
    return edit.translatePoint(point);
}

pub fn editByte(byte: u32, edit: core.InputEdit) u32 {
    return edit.translateByte(byte);
}
