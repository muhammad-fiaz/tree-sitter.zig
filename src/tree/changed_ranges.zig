const std = @import("std");
const core = @import("../core/core.zig");
const tree_mod = @import("tree.zig");
const node_mod = @import("node.zig");

pub fn changedRanges(
    gpa: std.mem.Allocator,
    old_tree: *const tree_mod.Tree,
    new_tree: *const tree_mod.Tree,
) std.mem.Allocator.Error![]core.Range {
    var out = std.ArrayList(core.Range).empty;
    errdefer out.deinit(gpa);
    if (old_tree.pool.nodes.items.len == 0 or new_tree.pool.nodes.items.len == 0) {
        try out.append(gpa, new_tree.includedRange());
        return try out.toOwnedSlice(gpa);
    }
    collectChanged(
        old_tree,
        old_tree.rootNode(),
        new_tree,
        new_tree.rootNode(),
        &out,
        gpa,
    ) catch {};
    if (out.items.len == 0) {
        const o = old_tree.includedRange();
        const n = new_tree.includedRange();
        if (o.start_byte != n.start_byte or o.end_byte != n.end_byte) {
            try out.append(gpa, n);
        }
    }
    return try out.toOwnedSlice(gpa);
}

fn nodesEqual(a: node_mod.Node, b: node_mod.Node) bool {
    if (a.symbol() != b.symbol()) return false;
    if (a.childCount() != b.childCount()) return false;
    if (!a.startPoint().eql(b.startPoint())) return false;
    if (!a.endPoint().eql(b.endPoint())) return false;
    if (a.isMissing() != b.isMissing()) return false;
    return true;
}

fn collectChanged(
    old_tree: *const tree_mod.Tree,
    old_node: node_mod.Node,
    new_tree: *const tree_mod.Tree,
    new_node: node_mod.Node,
    out: *std.ArrayList(core.Range),
    gpa: std.mem.Allocator,
) std.mem.Allocator.Error!void {
    if (nodesEqual(old_node, new_node)) {
        if (old_node.childCount() == 0) return;
        var i: u32 = 0;
        while (i < old_node.childCount()) : (i += 1) {
            const oc = old_node.child(i) orelse break;
            const nc = new_node.child(i) orelse break;
            try collectChanged(old_tree, oc, new_tree, nc, out, gpa);
        }
        return;
    }
    if (old_node.childCount() > 0 and new_node.childCount() > 0 and
        old_node.symbol() == new_node.symbol())
    {
        var i: u32 = 0;
        const common = @min(old_node.childCount(), new_node.childCount());
        while (i < common) : (i += 1) {
            const oc = old_node.child(i) orelse break;
            const nc = new_node.child(i) orelse break;
            try collectChanged(old_tree, oc, new_tree, nc, out, gpa);
        }
        var j: u32 = common;
        while (j < @max(old_node.childCount(), new_node.childCount())) : (j += 1) {
            if (new_node.child(j)) |nc| {
                try out.append(gpa, nc.range());
            } else if (old_node.child(j)) |oc| {
                try out.append(gpa, oc.range());
            }
        }
        return;
    }
    try out.append(gpa, new_node.range());
}

pub fn freeRanges(gpa: std.mem.Allocator, ranges: []core.Range) void {
    gpa.free(ranges);
}
