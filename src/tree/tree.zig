const std = @import("std");
const core = @import("../core/core.zig");
const language_mod = @import("../language/language.zig");
const subtree_mod = @import("subtree.zig");
const node_mod = @import("node.zig");

pub const Subtree = subtree_mod.Subtree;
pub const SubtreePool = subtree_mod.SubtreePool;
pub const Node = node_mod.Node;
pub const cursor_mod = @import("cursor.zig");
pub const edit_mod = @import("edit.zig");
pub const changed_ranges_mod = @import("changed_ranges.zig");
pub const sexp_mod = @import("sexp.zig");
pub const TreeCursor = cursor_mod.TreeCursor;

pub const Tree = struct {
    gpa: std.mem.Allocator,
    language: language_mod.Language,
    source: []u8,
    pool: SubtreePool = .{},
    root_index: u32 = 0,

    pub fn deinit(self: *Tree) void {
        self.pool.deinit(self.gpa);
        self.gpa.free(self.source);
        self.* = undefined;
    }

    pub fn rootNode(self: *const Tree) Node {
        return Node{ .tree = self, .index = self.root_index };
    }

    pub fn cursor(self: *const Tree) TreeCursor {
        return TreeCursor.init(self.gpa, self.rootNode());
    }

    pub fn getChangedRanges(self: *const Tree, other: *const Tree) std.mem.Allocator.Error![]core.Range {
        return changed_ranges_mod.changedRanges(self.gpa, self, other);
    }

    pub fn freeChangedRanges(self: *const Tree, ranges: []core.Range) void {
        changed_ranges_mod.freeRanges(self.gpa, ranges);
    }

    pub fn languageOf(self: *const Tree) language_mod.Language {
        return self.language;
    }

    pub fn sourceText(self: *const Tree) []const u8 {
        return self.source;
    }

    pub fn getNode(self: *const Tree, index: u32) *const Subtree {
        std.debug.assert(index < self.pool.nodes.items.len);
        return &self.pool.nodes.items[index];
    }

    pub fn nodeCount(self: *const Tree) usize {
        return self.pool.nodes.items.len;
    }

    pub fn hasError(self: *const Tree) bool {
        if (self.pool.nodes.items.len == 0) return false;
        return self.getNode(self.root_index).has_error;
    }

    pub fn copy(self: *const Tree) std.mem.Allocator.Error!Tree {
        const new_source = try self.gpa.dupe(u8, self.source);
        errdefer self.gpa.free(new_source);
        var new_pool = SubtreePool{};
        errdefer new_pool.deinit(self.gpa);
        try new_pool.nodes.appendSlice(self.gpa, self.pool.nodes.items);
        errdefer {}
        try new_pool.child_indices.appendSlice(self.gpa, self.pool.child_indices.items);
        return .{
            .gpa = self.gpa,
            .language = self.language,
            .source = new_source,
            .pool = new_pool,
            .root_index = self.root_index,
        };
    }

    pub fn includedRange(self: *const Tree) core.Range {
        if (self.pool.nodes.items.len == 0) return .{};
        const root = self.getNode(self.root_index);
        return .{
            .start_byte = root.start_byte,
            .end_byte = root.end_byte,
            .start_point = root.start_point,
            .end_point = root.end_point,
        };
    }
};

const parser_mod = @import("../parser/parser.zig");

test "tree: root properties" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 + 2");
    defer tree.deinit();
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
    try std.testing.expect(root.isNamed());
    try std.testing.expect(!root.isMissing());
    try std.testing.expect(!root.isExtra());
    try std.testing.expect(!root.isError());
    try std.testing.expect(!root.hasError());
    try std.testing.expectEqual(@as(u32, 0), root.startByte());
    try std.testing.expectEqual(@as(u32, 5), root.endByte());
}

test "tree: copy is independent" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 + 2");
    defer tree.deinit();
    var dup = try tree.copy();
    defer dup.deinit();
    try std.testing.expectEqualStrings("program", dup.rootNode().nodeType());
    try std.testing.expectEqual(tree.rootNode().endByte(), dup.rootNode().endByte());
}

test "tree: source text owned by tree" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("xyz");
    defer tree.deinit();
    try std.testing.expectEqualStrings("xyz", tree.sourceText());
}

test "tree: multiline points" {
    var parser = parser_mod.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 +\n  2");
    defer tree.deinit();
    const root = tree.rootNode();
    try std.testing.expectEqual(@as(u32, 1), root.endPoint().row);
    try std.testing.expectEqual(@as(u32, 3), root.endPoint().column);
}
