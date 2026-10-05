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

/// Immutable syntax tree produced by a `Parser`.
///
/// **Ownership**: the `Tree` is exclusively owned by the caller after it is
/// returned from `Parser.parseString`, `Parser.parse`, etc.  Call
/// `Tree.deinit` to free all memory.  The tree owns its source copy and
/// node pool; `Node` and `TreeCursor` values borrow from the tree and
/// MUST NOT outlive it.
///
/// **Concurrency**: after construction a `Tree` is immutable.  Multiple
/// threads MAY read the same `Tree` concurrently (e.g. traverse with
/// independent `TreeCursor` instances) without synchronisation.
/// A `Tree` MUST NOT be mutated (e.g. `applyEdit`) while another thread
/// is reading it.  Mutation and reading are mutually exclusive.
///
/// **Lifetime rules**:
///   - `Node` values borrow `*const Tree`; they are valid only as long as
///     the tree is alive and unmutated.
///   - `TreeCursor` borrows `*const Tree`; same constraint.
///   - `getChangedRanges` compares two trees but does not retain either.
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

    pub fn rootNodeWithOffset(self: *const Tree, offset_bytes: u32, offset_point: core.Point) Node {
        _ = offset_bytes;
        _ = offset_point;
        return self.rootNode();
    }

    pub fn edit(self: *Tree, input_edit: core.InputEdit) void {
        edit_mod.applyEdit(self, input_edit);
    }

    pub fn getLanguage(self: *const Tree) language_mod.Language {
        return self.language;
    }

    pub fn includedRanges(self: *const Tree, gpa: std.mem.Allocator) std.mem.Allocator.Error![]core.Range {
        const slice = try gpa.alloc(core.Range, 1);
        slice[0] = self.includedRange();
        return slice;
    }

    pub fn printDotGraph(self: *const Tree, writer: *std.Io.Writer) anyerror!void {
        try writer.writeAll("digraph tree {\n");
        var i: u32 = 0;
        while (i < self.pool.nodes.items.len) : (i += 1) {
            const node = self.getNode(i);
            const type_name = self.language.symbolName(node.symbol);
            try writer.print("  node_{d} [label=\"{s}\"];\n", .{ i, type_name });
            for (self.pool.childrenOf(node.*)) |child_idx| {
                try writer.print("  node_{d} -> node_{d};\n", .{ i, child_idx });
            }
        }
        try writer.writeAll("}\n");
    }

    pub fn writeDotGraph(self: *const Tree, writer: *std.Io.Writer) anyerror!void {
        return self.printDotGraph(writer);
    }

    pub fn printDotGraphToFile(self: *const Tree, io: std.Io, file: std.Io.File) anyerror!void {
        var w = file.writer(io, &.{});
        defer w.flush() catch {};
        return self.printDotGraph(&w.interface);
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
