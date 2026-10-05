const std = @import("std");
const node_mod = @import("node.zig");
const core = @import("../core/core.zig");

const Entry = struct {
    index: u32,
    child_pos: u32,
    descendant_index: u32 = 0,
};

/// Stateful depth-first cursor over an immutable `Tree`.
///
/// **Ownership**: `TreeCursor` owns its internal navigation stack via `gpa`.
/// Call `deinit` to free it.  The cursor borrows `*const Tree` through the
/// root `Node`; the `Tree` must outlive the cursor.
///
/// **Concurrency**: a `TreeCursor` MUST NOT be accessed concurrently from
/// multiple threads.  For parallel traversals, create one independent
/// `TreeCursor` per thread over the same shared immutable `Tree`.
pub const TreeCursor = struct {
    gpa: std.mem.Allocator,
    node: node_mod.Node,
    stack: std.ArrayList(Entry) = .empty,
    current_descendant_index: u32 = 0,

    pub fn init(gpa: std.mem.Allocator, node: node_mod.Node) TreeCursor {
        return .{ .gpa = gpa, .node = node };
    }

    pub fn deinit(self: *TreeCursor) void {
        self.stack.deinit(self.gpa);
        self.* = undefined;
    }

    pub fn reset(self: *TreeCursor, node: node_mod.Node) void {
        self.stack.clearRetainingCapacity();
        self.node = node;
        self.current_descendant_index = 0;
    }

    pub fn resetTo(self: *TreeCursor, src: *const TreeCursor) std.mem.Allocator.Error!void {
        self.stack.clearRetainingCapacity();
        try self.stack.appendSlice(self.gpa, src.stack.items);
        self.node = src.node;
        self.current_descendant_index = src.current_descendant_index;
    }

    pub fn currentNode(self: *const TreeCursor) node_mod.Node {
        return self.node;
    }

    pub fn depth(self: *const TreeCursor) u32 {
        return @as(u32, @intCast(self.stack.items.len));
    }

    pub fn currentDepth(self: *const TreeCursor) u32 {
        return self.depth();
    }

    pub fn currentDescendantIndex(self: *const TreeCursor) u32 {
        return self.current_descendant_index;
    }

    pub fn currentFieldName(self: *const TreeCursor) ?[]const u8 {
        if (self.stack.items.len == 0) return null;
        const parent_entry = if (self.stack.items.len >= 2)
            self.stack.items[self.stack.items.len - 2]
        else
            return null;
        const parent = node_mod.Node{ .tree = self.node.tree, .index = parent_entry.index };
        const pos = self.stack.items[self.stack.items.len - 1].child_pos;
        return parent.fieldNameForChild(pos);
    }

    pub fn currentFieldId(self: *const TreeCursor) ?u16 {
        const name = self.currentFieldName() orelse return null;
        return self.node.tree.language.fieldIdForName(name);
    }

    pub fn gotoFirstChild(self: *TreeCursor) bool {
        const first = self.node.child(0) orelse return false;
        self.stack.append(self.gpa, .{
            .index = self.node.index,
            .child_pos = 0,
            .descendant_index = self.current_descendant_index,
        }) catch return false;
        self.node = first;
        self.current_descendant_index += 1;
        return true;
    }

    pub fn gotoLastChild(self: *TreeCursor) bool {
        const count = self.node.childCount();
        if (count == 0) return false;
        const last_pos = count - 1;
        const last = self.node.child(last_pos) orelse return false;
        var desc_idx = self.current_descendant_index + 1;
        var i: u32 = 0;
        while (i < last_pos) : (i += 1) {
            if (self.node.child(i)) |c| desc_idx += c.descendantCount();
        }
        self.stack.append(self.gpa, .{
            .index = self.node.index,
            .child_pos = last_pos,
            .descendant_index = self.current_descendant_index,
        }) catch return false;
        self.node = last;
        self.current_descendant_index = desc_idx;
        return true;
    }

    pub fn gotoFirstChildForByte(self: *TreeCursor, goal_byte: u32) ?u32 {
        const count = self.node.childCount();
        if (count == 0) return null;
        var i: u32 = 0;
        var desc_idx = self.current_descendant_index + 1;
        while (i < count) : (i += 1) {
            const c = self.node.child(i) orelse break;
            if (c.endByte() > goal_byte or c.startByte() >= goal_byte) {
                self.stack.append(self.gpa, .{
                    .index = self.node.index,
                    .child_pos = i,
                    .descendant_index = self.current_descendant_index,
                }) catch return null;
                self.node = c;
                self.current_descendant_index = desc_idx;
                return i;
            }
            desc_idx += c.descendantCount();
        }
        return null;
    }

    pub fn gotoFirstChildForPoint(self: *TreeCursor, goal_point: core.Point) ?u32 {
        const count = self.node.childCount();
        if (count == 0) return null;
        var i: u32 = 0;
        var desc_idx = self.current_descendant_index + 1;
        while (i < count) : (i += 1) {
            const c = self.node.child(i) orelse break;
            if (c.endPoint().order(goal_point) == .gt or goal_point.lessOrEql(c.startPoint())) {
                self.stack.append(self.gpa, .{
                    .index = self.node.index,
                    .child_pos = i,
                    .descendant_index = self.current_descendant_index,
                }) catch return null;
                self.node = c;
                self.current_descendant_index = desc_idx;
                return i;
            }
            desc_idx += c.descendantCount();
        }
        return null;
    }

    pub fn gotoParent(self: *TreeCursor) bool {
        const entry = self.stack.pop() orelse return false;
        self.node = node_mod.Node{ .tree = self.node.tree, .index = entry.index };
        self.current_descendant_index = entry.descendant_index;
        return true;
    }

    pub fn gotoNextSibling(self: *TreeCursor) bool {
        if (self.stack.items.len == 0) return false;
        const top = &self.stack.items[self.stack.items.len - 1];
        const parent = node_mod.Node{ .tree = self.node.tree, .index = top.index };
        const next_pos = top.child_pos + 1;
        const next = parent.child(next_pos) orelse return false;
        top.child_pos = next_pos;
        self.current_descendant_index += self.node.descendantCount();
        self.node = next;
        return true;
    }

    pub fn gotoPreviousSibling(self: *TreeCursor) bool {
        if (self.stack.items.len == 0) return false;
        const top = &self.stack.items[self.stack.items.len - 1];
        if (top.child_pos == 0) return false;
        const parent = node_mod.Node{ .tree = self.node.tree, .index = top.index };
        const prev_pos = top.child_pos - 1;
        const prev = parent.child(prev_pos) orelse return false;
        top.child_pos = prev_pos;
        self.current_descendant_index -= prev.descendantCount();
        self.node = prev;
        return true;
    }

    pub fn gotoDescendant(self: *TreeCursor, goal_byte_offset: u32) void {
        while (true) {
            const count = self.node.childCount();
            var descended = false;
            var i: u32 = 0;
            var desc_idx = self.current_descendant_index + 1;
            while (i < count) : (i += 1) {
                const c = self.node.child(i) orelse break;
                if (c.startByte() <= goal_byte_offset and goal_byte_offset < c.endByte()) {
                    self.stack.append(self.gpa, .{
                        .index = self.node.index,
                        .child_pos = i,
                        .descendant_index = self.current_descendant_index,
                    }) catch return;
                    self.node = c;
                    self.current_descendant_index = desc_idx;
                    descended = true;
                    break;
                }
                desc_idx += c.descendantCount();
            }
            if (!descended) return;
        }
    }

    pub fn copy(self: *const TreeCursor) std.mem.Allocator.Error!TreeCursor {
        var new_stack = std.ArrayList(Entry).empty;
        try new_stack.appendSlice(self.gpa, self.stack.items);
        return .{
            .gpa = self.gpa,
            .node = self.node,
            .stack = new_stack,
            .current_descendant_index = self.current_descendant_index,
        };
    }
};

const parser_mod = @import("../parser/parser.zig");
const language_mod = @import("../language/language.zig");

test "cursor: full traversal visits every node" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 + 2 * 3");
    defer tree.deinit();
    var cursor = TreeCursor.init(std.testing.allocator, tree.rootNode());
    defer cursor.deinit();
    var visited: usize = 1;
    var depth_max: u32 = 0;
    outer: while (true) {
        if (cursor.gotoFirstChild()) {
            visited += 1;
            depth_max = @max(depth_max, cursor.depth());
            continue;
        }
        while (true) {
            if (cursor.gotoNextSibling()) {
                visited += 1;
                depth_max = @max(depth_max, cursor.depth());
                break;
            }
            if (!cursor.gotoParent()) break :outer;
        }
    }
    try std.testing.expect(visited >= tree.nodeCount());
    try std.testing.expect(depth_max > 2);
}

test "cursor: sibling navigation" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("a + b");
    defer tree.deinit();
    var cursor = TreeCursor.init(std.testing.allocator, tree.rootNode());
    defer cursor.deinit();
    try std.testing.expect(cursor.gotoFirstChild());
    try std.testing.expect(cursor.gotoFirstChild());
    try std.testing.expectEqualStrings("a", cursor.currentNode().text());
    try std.testing.expect(cursor.gotoNextSibling());
    try std.testing.expectEqualStrings("+", cursor.currentNode().nodeType());
    try std.testing.expect(cursor.gotoNextSibling());
    try std.testing.expectEqualStrings("b", cursor.currentNode().text());
    try std.testing.expect(!cursor.gotoNextSibling());
    try std.testing.expect(cursor.gotoPreviousSibling());
    try std.testing.expectEqualStrings("+", cursor.currentNode().nodeType());
}

test "cursor: last child and reset" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("a + b");
    defer tree.deinit();
    var cursor = TreeCursor.init(std.testing.allocator, tree.rootNode());
    defer cursor.deinit();
    try std.testing.expect(cursor.gotoFirstChild());
    try std.testing.expect(cursor.gotoLastChild());
    try std.testing.expectEqualStrings("b", cursor.currentNode().text());
    cursor.reset(tree.rootNode());
    try std.testing.expectEqual(@as(u32, 0), cursor.depth());
    try std.testing.expect(cursor.currentNode().eql(tree.rootNode()));
}

test "cursor: goto descendant" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("a + b");
    defer tree.deinit();
    var cursor = TreeCursor.init(std.testing.allocator, tree.rootNode());
    defer cursor.deinit();
    cursor.gotoDescendant(4);
    try std.testing.expectEqualStrings("b", cursor.currentNode().text());
}

test "cursor: copy is independent" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("a + b");
    defer tree.deinit();
    var cursor = TreeCursor.init(std.testing.allocator, tree.rootNode());
    defer cursor.deinit();
    try std.testing.expect(cursor.gotoFirstChild());
    var dup = try cursor.copy();
    defer dup.deinit();
    try std.testing.expect(dup.currentNode().eql(cursor.currentNode()));
    try std.testing.expect(cursor.gotoFirstChild());
    try std.testing.expect(!dup.currentNode().eql(cursor.currentNode()));
}

test "cursor: resetTo, descendant indexing, and byte/point child search" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("a + b");
    defer tree.deinit();

    var cursor = TreeCursor.init(std.testing.allocator, tree.rootNode());
    defer cursor.deinit();

    try std.testing.expectEqual(@as(u32, 0), cursor.currentDepth());
    try std.testing.expectEqual(@as(u32, 0), cursor.currentDescendantIndex());

    try std.testing.expect(cursor.gotoFirstChild());
    try std.testing.expectEqual(@as(u32, 1), cursor.currentDepth());
    try std.testing.expectEqual(@as(u32, 1), cursor.currentDescendantIndex());

    const c_idx = cursor.gotoFirstChildForByte(4);
    try std.testing.expect(c_idx != null);
    try std.testing.expectEqualStrings("b", cursor.currentNode().text());

    var other = TreeCursor.init(std.testing.allocator, tree.rootNode());
    defer other.deinit();
    try other.resetTo(&cursor);
    try std.testing.expect(other.currentNode().eql(cursor.currentNode()));
    try std.testing.expectEqual(cursor.currentDepth(), other.currentDepth());
    try std.testing.expectEqual(cursor.currentDescendantIndex(), other.currentDescendantIndex());

    other.reset(tree.rootNode());
    const pt_idx = other.gotoFirstChildForPoint(.{ .row = 0, .column = 0 });
    try std.testing.expect(pt_idx != null);
}
