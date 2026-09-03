const std = @import("std");
const pattern_mod = @import("pattern.zig");
const capture_mod = @import("capture.zig");
const predicate_mod = @import("predicate.zig");

/// Application-level directive helpers, mirroring how upstream's
/// tags/highlight crates consume `#select-adjacent!` and `#strip!`.
///
/// Upstream architecture note: directives are parsed and exposed by the
/// query engine but *applied* by higher-level code. This module is that
/// layer for tree-sitter.zig: `selectAdjacent` filters captures the way
/// the tags crate filters doc nodes, and `stripText` applies
/// regex-replace-all the way doc strings are cleaned.
/// Keep captures per `select-adjacent!` semantics: all captures are
/// kept except those named by `target`, which survive only when they
/// form a line-contiguous run directly above the anchor node.
///
/// Concretely (mirroring `tags.rs`): let `anchor` be the last capture
/// named `anchor_name`. Walk the `target`-named captures backward from
/// the anchor, keeping nodes whose `end_row + 1 >= current start_row`
/// and stepping the start row upward. A gap (blank line) stops the run.
/// With no anchor capture, everything is kept.
pub fn selectAdjacent(
    gpa: std.mem.Allocator,
    captures: []const capture_mod.Capture,
    target_name: u32,
    anchor_name: u32,
) std.mem.Allocator.Error![]capture_mod.Capture {
    var anchor_node: ?@import("../tree/node.zig").Node = null;
    for (captures) |c| {
        if (c.name_index == anchor_name) anchor_node = c.node;
    }
    var out = std.ArrayList(capture_mod.Capture).empty;
    errdefer out.deinit(gpa);
    const anchor = anchor_node orelse {
        try out.appendSlice(gpa, captures);
        return out.toOwnedSlice(gpa);
    };
    // Collect target indices in order.
    var targets = std.ArrayList(usize).empty;
    defer targets.deinit(gpa);
    for (captures, 0..) |c, i| {
        if (c.name_index == target_name) try targets.append(gpa, i);
    }
    var keep_from = targets.items.len;
    var start_row = anchor.startPoint().row;
    while (keep_from > 0) {
        const node = captures[targets.items[keep_from - 1]].node;
        if (node.endPoint().row + 1 >= start_row) {
            keep_from -= 1;
            start_row = node.startPoint().row;
        } else {
            break;
        }
    }
    for (captures, 0..) |c, i| {
        if (c.name_index != target_name) {
            try out.append(gpa, c);
            continue;
        }
        var kept = false;
        for (targets.items[keep_from..]) |ti| {
            if (ti == i) {
                kept = true;
                break;
            }
        }
        if (kept) try out.append(gpa, c);
    }
    return out.toOwnedSlice(gpa);
}

/// Remove every non-overlapping match of the built-in regex subset
/// from `text` (upstream `strip!` semantics: `replace_all` with `""`).
/// Empty matches advance one byte so stripping always terminates.
pub fn stripText(gpa: std.mem.Allocator, text: []const u8, pattern: []const u8) std.mem.Allocator.Error![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(gpa);
    var i: usize = 0;
    while (i < text.len) {
        const span = predicate_mod.findSpan(pattern, text, i) orelse {
            try out.appendSlice(gpa, text[i..]);
            break;
        };
        try out.appendSlice(gpa, text[i..span[0]]);
        if (span[1] <= span[0]) {
            try out.append(gpa, text[i]);
            i += 1;
        } else {
            i = span[1];
        }
    }
    return out.toOwnedSlice(gpa);
}

const tree_mod = @import("../tree/tree.zig");
const subtree_mod = @import("../tree/subtree.zig");
const language_mod = @import("../language/language.zig");

fn docTree() !tree_mod.Tree {
    var pool = subtree_mod.SubtreePool{};
    errdefer pool.deinit(std.testing.allocator);
    // root program [0,26); doc1 row 0; doc2 row 4; anchor row 5.
    const d1 = try pool.pushNode(std.testing.allocator, .{
        .symbol = 1,
        .start_byte = 0,
        .end_byte = 5,
        .start_point = .{},
        .end_point = .{ .row = 0, .column = 5 },
        .named = true,
        .visible = true,
    });
    const d2 = try pool.pushNode(std.testing.allocator, .{
        .symbol = 1,
        .start_byte = 10,
        .end_byte = 15,
        .start_point = .{ .row = 4, .column = 0 },
        .end_point = .{ .row = 4, .column = 5 },
        .named = true,
        .visible = true,
    });
    const anchor = try pool.pushNode(std.testing.allocator, .{
        .symbol = 2,
        .start_byte = 20,
        .end_byte = 25,
        .start_point = .{ .row = 5, .column = 0 },
        .end_point = .{ .row = 5, .column = 5 },
        .named = true,
        .visible = true,
    });
    const root = try pool.pushNode(std.testing.allocator, .{
        .symbol = 10,
        .start_byte = 0,
        .end_byte = 26,
        .start_point = .{},
        .end_point = .{ .row = 5, .column = 6 },
        .named = true,
        .visible = true,
        .named_child_count = 3,
        .descendant_count = 3,
    });
    pool.nodes.items[root].children_start = 0;
    pool.nodes.items[root].child_count = 3;
    try pool.child_indices.appendSlice(std.testing.allocator, &.{ d1, d2, anchor });
    pool.nodes.items[d1].parent = root;
    pool.nodes.items[d2].parent = root;
    pool.nodes.items[anchor].parent = root;
    const source = try std.testing.allocator.dupe(u8, "doc1......doc2......anchor.");
    return .{
        .gpa = std.testing.allocator,
        .language = language_mod.expression_language,
        .source = source,
        .pool = pool,
        .root_index = root,
    };
}

test "directives: selectAdjacent keeps the contiguous run" {
    var tree = try docTree();
    defer tree.deinit();
    const root = tree.rootNode();
    const caps = [_]capture_mod.Capture{
        .{ .name = "doc", .name_index = 0, .node = root.child(0).? },
        .{ .name = "doc", .name_index = 0, .node = root.child(1).? },
        .{ .name = "name", .name_index = 1, .node = root.child(2).? },
    };
    // doc2 (row 4) is contiguous with the anchor (row 5); doc1 is not.
    const kept = try selectAdjacent(std.testing.allocator, &caps, 0, 1);
    defer std.testing.allocator.free(kept);
    try std.testing.expectEqual(@as(usize, 2), kept.len);
    try std.testing.expectEqualStrings("doc", kept[0].name);
    try std.testing.expectEqual(@as(u32, 10), kept[0].node.startByte());
    try std.testing.expectEqualStrings("name", kept[1].name);
}

test "directives: selectAdjacent without anchor keeps all" {
    var tree = try docTree();
    defer tree.deinit();
    const root = tree.rootNode();
    const caps = [_]capture_mod.Capture{
        .{ .name = "doc", .name_index = 0, .node = root.child(0).? },
    };
    const kept = try selectAdjacent(std.testing.allocator, &caps, 0, 7);
    defer std.testing.allocator.free(kept);
    try std.testing.expectEqual(@as(usize, 1), kept.len);
}

test "directives: stripText removes matches" {
    const a = try stripText(std.testing.allocator, "a1b22c", "[0-9]+");
    defer std.testing.allocator.free(a);
    try std.testing.expectEqualStrings("abc", a);
    const b = try stripText(std.testing.allocator, "## hi", "^#+");
    defer std.testing.allocator.free(b);
    try std.testing.expectEqualStrings(" hi", b);
    const c = try stripText(std.testing.allocator, "a [b] c", "\\[.*\\]");
    defer std.testing.allocator.free(c);
    try std.testing.expectEqualStrings("a  c", c);
    // Empty matches never loop and never delete.
    const d = try stripText(std.testing.allocator, "ab", "x*");
    defer std.testing.allocator.free(d);
    try std.testing.expectEqualStrings("ab", d);
}
