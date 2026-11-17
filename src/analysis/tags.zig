const std = @import("std");
const treesitter = @import("../treesitter.zig");
const Query = treesitter.Query;
const QueryCursor = treesitter.QueryCursor;
const Tree = treesitter.Tree;
const Range = treesitter.Range;
const Point = treesitter.Point;

pub const TagKind = enum {
    function,
    method,
    class,
    module,
    interface,
    type,
    variable,
    constant,
    field,
    call,
    other,

    pub fn fromCaptureName(name: []const u8) TagKind {
        if (std.mem.indexOf(u8, name, "function") != null) return .function;
        if (std.mem.indexOf(u8, name, "method") != null) return .method;
        if (std.mem.indexOf(u8, name, "class") != null) return .class;
        if (std.mem.indexOf(u8, name, "module") != null) return .module;
        if (std.mem.indexOf(u8, name, "interface") != null) return .interface;
        if (std.mem.indexOf(u8, name, "type") != null) return .type;
        if (std.mem.indexOf(u8, name, "variable") != null) return .variable;
        if (std.mem.indexOf(u8, name, "constant") != null) return .constant;
        if (std.mem.indexOf(u8, name, "field") != null) return .field;
        if (std.mem.indexOf(u8, name, "call") != null) return .call;
        return .other;
    }
};

pub const Tag = struct {
    name: []const u8,
    kind: TagKind,
    range: Range,
    is_definition: bool = true,
    doc: ?[]const u8 = null,
};

pub const TagsEngine = struct {
    allocator: std.mem.Allocator,
    query: Query,

    pub fn init(allocator: std.mem.Allocator, language: treesitter.Language, tags_query_source: []const u8) !TagsEngine {
        const q = try Query.compile(allocator, language, tags_query_source);
        return .{
            .allocator = allocator,
            .query = q,
        };
    }

    pub fn deinit(self: *TagsEngine) void {
        self.query.deinit();
    }

    pub fn generateTags(self: *TagsEngine, tree: *const Tree, source: []const u8) ![]Tag {
        const gpa = self.allocator;
        var cursor = QueryCursor.init(gpa);
        defer cursor.deinit();

        var tags = std.ArrayList(Tag).empty;
        errdefer {
            for (tags.items) |t| {
                gpa.free(t.name);
                if (t.doc) |d| gpa.free(d);
            }
            tags.deinit(gpa);
        }

        try cursor.execute(self.query.language, self.query.patterns(), self.query.nodes(), self.query.captureNames(), tree);
        while (cursor.nextMatch()) |m| {
            var tag_name: ?[]const u8 = null;
            var tag_range: ?Range = null;
            var tag_kind: TagKind = .other;
            var is_def = true;
            var doc_text: ?[]const u8 = null;

            for (m.captures) |c| {
                const cname = self.query.captureName(c.name_index) orelse "";
                const node_text = if (c.node.endByte() <= source.len) source[c.node.startByte()..c.node.endByte()] else "";
                if (std.mem.eql(u8, cname, "name")) {
                    tag_name = node_text;
                    tag_range = .{
                        .start_byte = c.node.startByte(),
                        .end_byte = c.node.endByte(),
                        .start_point = c.node.startPoint(),
                        .end_point = c.node.endPoint(),
                    };
                } else if (std.mem.startsWith(u8, cname, "definition.")) {
                    tag_kind = TagKind.fromCaptureName(cname);
                    is_def = true;
                    if (tag_range == null) {
                        tag_range = .{
                            .start_byte = c.node.startByte(),
                            .end_byte = c.node.endByte(),
                            .start_point = c.node.startPoint(),
                            .end_point = c.node.endPoint(),
                        };
                    }
                } else if (std.mem.startsWith(u8, cname, "reference.")) {
                    tag_kind = TagKind.fromCaptureName(cname);
                    is_def = false;
                } else if (std.mem.eql(u8, cname, "doc")) {
                    doc_text = node_text;
                }
            }

            if (tag_name) |tname| {
                const trange: Range = tag_range orelse Range{};
                try tags.append(gpa, .{
                    .name = try gpa.dupe(u8, tname),
                    .kind = tag_kind,
                    .range = trange,
                    .is_definition = is_def,
                    .doc = if (doc_text) |dt| try gpa.dupe(u8, dt) else null,
                });
            }
        }

        return try tags.toOwnedSlice(gpa);
    }
};

test "tags: extract symbol tags" {
    const expr_lang = treesitter.expressionLanguage;
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(expr_lang);

    const source = "total * count";
    var tree = try parser.parseString(source);
    defer tree.deinit();

    const query_src =
        \\(factor (identifier) @name) @definition.variable
    ;

    var engine = try TagsEngine.init(std.testing.allocator, expr_lang, query_src);
    defer engine.deinit();

    const tags = try engine.generateTags(&tree, source);
    defer {
        for (tags) |t| {
            std.testing.allocator.free(t.name);
            if (t.doc) |d| std.testing.allocator.free(d);
        }
        std.testing.allocator.free(tags);
    }

    try std.testing.expectEqual(@as(usize, 2), tags.len);
    try std.testing.expectEqualStrings("total", tags[0].name);
    try std.testing.expectEqual(TagKind.variable, tags[0].kind);
}
