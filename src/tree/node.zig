const std = @import("std");
const core = @import("../core/core.zig");
const subtree_mod = @import("subtree.zig");
const tree_mod = @import("tree.zig");

pub const Node = struct {
    tree: *const tree_mod.Tree,
    index: u32,

    pub fn isNull(self: Node) bool {
        return self.index == subtree_mod.no_index;
    }

    pub fn raw(self: Node) *const subtree_mod.Subtree {
        return self.tree.getNode(self.index);
    }

    pub fn symbol(self: Node) u16 {
        return self.raw().symbol;
    }

    pub fn nodeType(self: Node) []const u8 {
        return self.tree.language.symbolName(self.symbol());
    }

    pub fn isNamed(self: Node) bool {
        return self.raw().named;
    }

    pub fn isMissing(self: Node) bool {
        return self.raw().missing;
    }

    pub fn isExtra(self: Node) bool {
        return self.raw().extra;
    }

    pub fn isError(self: Node) bool {
        return self.raw().is_error;
    }

    pub fn hasError(self: Node) bool {
        return self.raw().has_error;
    }

    pub fn startByte(self: Node) u32 {
        return self.raw().start_byte;
    }

    pub fn endByte(self: Node) u32 {
        return self.raw().end_byte;
    }

    pub fn startPoint(self: Node) core.Point {
        return self.raw().start_point;
    }

    pub fn endPoint(self: Node) core.Point {
        return self.raw().end_point;
    }

    pub fn byteRange(self: Node) struct { start: u32, end: u32 } {
        return .{ .start = self.startByte(), .end = self.endByte() };
    }

    pub fn range(self: Node) core.Range {
        return .{
            .start_byte = self.startByte(),
            .end_byte = self.endByte(),
            .start_point = self.startPoint(),
            .end_point = self.endPoint(),
        };
    }

    pub fn childCount(self: Node) u32 {
        return self.raw().child_count;
    }

    pub fn namedChildCount(self: Node) u32 {
        return self.raw().named_child_count;
    }

    pub fn descendantCount(self: Node) u32 {
        return self.raw().descendant_count;
    }

    pub fn children(self: Node) []const u32 {
        return self.tree.pool.childrenOf(self.raw().*);
    }

    pub fn child(self: Node, i: u32) ?Node {
        const list = self.children();
        if (i >= list.len) return null;
        return Node{ .tree = self.tree, .index = list[i] };
    }

    pub fn namedChild(self: Node, i: u32) ?Node {
        var seen: u32 = 0;
        for (self.children()) |idx| {
            const n = Node{ .tree = self.tree, .index = idx };
            if (n.isNamed()) {
                if (seen == i) return n;
                seen += 1;
            }
        }
        return null;
    }

    pub fn parent(self: Node) ?Node {
        const p = self.raw().parent;
        if (p == subtree_mod.no_parent) return null;
        return Node{ .tree = self.tree, .index = p };
    }

    fn siblingOffset(self: Node) ?usize {
        const p = self.parent() orelse return null;
        for (p.children(), 0..) |idx, i| {
            if (idx == self.index) return i;
        }
        return null;
    }

    pub fn nextSibling(self: Node) ?Node {
        const p = self.parent() orelse return null;
        const off = self.siblingOffset() orelse return null;
        const list = p.children();
        if (off + 1 >= list.len) return null;
        return Node{ .tree = self.tree, .index = list[off + 1] };
    }

    pub fn prevSibling(self: Node) ?Node {
        const p = self.parent() orelse return null;
        const off = self.siblingOffset() orelse return null;
        if (off == 0) return null;
        const list = p.children();
        return Node{ .tree = self.tree, .index = list[off - 1] };
    }

    pub fn nextNamedSibling(self: Node) ?Node {
        var sib = self.nextSibling();
        while (sib) |s| {
            if (s.isNamed()) return s;
            sib = s.nextSibling();
        }
        return null;
    }

    pub fn prevNamedSibling(self: Node) ?Node {
        var sib = self.prevSibling();
        while (sib) |s| {
            if (s.isNamed()) return s;
            sib = s.prevSibling();
        }
        return null;
    }

    pub fn childByFieldName(self: Node, name: []const u8) ?Node {
        const bindings = self.tree.language.fields.bindingsForProduction(self.raw().production_id);
        for (bindings) |b| {
            if (std.mem.eql(u8, b.name, name)) {
                return self.child(@as(u32, @intCast(b.child_index)));
            }
        }
        return null;
    }

    pub fn fieldNameForChild(self: Node, child_index: u32) ?[]const u8 {
        const bindings = self.tree.language.fields.bindingsForProduction(self.raw().production_id);
        for (bindings) |b| {
            if (b.child_index == child_index) return b.name;
        }
        return null;
    }

    pub fn text(self: Node) []const u8 {
        const src = self.tree.sourceText();
        const s: usize = @as(usize, @intCast(self.startByte()));
        const e: usize = @as(usize, @intCast(self.endByte()));
        if (s > src.len or e > src.len or s > e) return "";
        return src[s..e];
    }

    pub fn descendantForByteRange(self: Node, start: u32, end: u32) ?Node {
        if (self.endByte() < start or self.startByte() > end) return null;
        if (self.startByte() >= start and self.endByte() <= end) {
            var best: Node = self;
            var current: ?Node = self;
            while (current) |c| {
                var descended = false;
                for (c.children()) |idx| {
                    const n = Node{ .tree = self.tree, .index = idx };
                    if (n.startByte() >= start and n.endByte() <= end) {
                        best = n;
                        current = n;
                        descended = true;
                        break;
                    }
                }
                if (!descended) break;
            }
            return best;
        }
        for (self.children()) |idx| {
            const n = Node{ .tree = self.tree, .index = idx };
            if (n.endByte() >= start and n.startByte() <= end) {
                if (n.descendantForByteRange(start, end)) |found| return found;
            }
        }
        return null;
    }

    pub fn namedDescendantForByteRange(self: Node, start: u32, end: u32) ?Node {
        const found = self.descendantForByteRange(start, end) orelse return null;
        if (found.isNamed()) return found;
        var cursor: ?Node = found;
        while (cursor) |c| {
            if (c.isNamed()) return c;
            cursor = c.parent();
        }
        return null;
    }

    pub fn eql(a: Node, b: Node) bool {
        return a.tree == b.tree and a.index == b.index;
    }
};

const parser_mod = @import("../parser/parser.zig");
const language_mod = @import("../language/language.zig");

test "node: children and named children" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 + x");
    defer tree.deinit();
    const expr = tree.rootNode().child(0).?;
    try std.testing.expectEqual(@as(u32, 3), expr.childCount());
    try std.testing.expectEqual(@as(u32, 2), expr.namedChildCount());
    const left = expr.namedChild(0).?;
    try std.testing.expectEqualStrings("1", left.text());
    const right = expr.namedChild(1).?;
    try std.testing.expectEqualStrings("x", right.text());
    const op = expr.child(1).?;
    try std.testing.expect(!op.isNamed());
    try std.testing.expectEqualStrings("+", op.nodeType());
}

test "node: parent and siblings" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 + x");
    defer tree.deinit();
    const expr = tree.rootNode().child(0).?;
    const left = expr.child(0).?;
    try std.testing.expect(left.parent().?.eql(expr));
    try std.testing.expect(left.nextSibling().?.eql(expr.child(1).?));
    try std.testing.expect(expr.child(2).?.prevSibling().?.eql(expr.child(1).?));
    try std.testing.expect(left.nextNamedSibling().?.eql(expr.child(2).?));
    try std.testing.expect(tree.rootNode().parent() == null);
}

test "node: field lookup" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("a - b");
    defer tree.deinit();
    const expr = tree.rootNode().child(0).?;
    const left = expr.childByFieldName("left").?;
    try std.testing.expectEqualStrings("a", left.text());
    const right = expr.childByFieldName("right").?;
    try std.testing.expectEqualStrings("b", right.text());
    try std.testing.expect(expr.childByFieldName("nope") == null);
}

test "node: descendant for byte range" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 + 22");
    defer tree.deinit();
    const found = tree.rootNode().descendantForByteRange(4, 6).?;
    try std.testing.expectEqualStrings("22", found.text());
    const named = tree.rootNode().namedDescendantForByteRange(4, 6).?;
    try std.testing.expect(named.isNamed());
}

test "node: equality" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("7");
    defer tree.deinit();
    const root = tree.rootNode();
    try std.testing.expect(root.eql(root));
    try std.testing.expect(!root.eql(root.child(0).?));
}
