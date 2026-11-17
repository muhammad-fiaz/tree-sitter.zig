const std = @import("std");
const treesitter = @import("../treesitter.zig");
const Query = treesitter.Query;
const QueryCursor = treesitter.QueryCursor;
const Tree = treesitter.Tree;
const Node = treesitter.Node;

pub const Definition = struct {
    name: []const u8,
    node: Node,
    scope_id: usize,
};

pub const Reference = struct {
    name: []const u8,
    node: Node,
    definition_index: ?usize = null,
};

pub const Scope = struct {
    id: usize,
    parent_id: ?usize = null,
    node: Node,
    definitions: std.ArrayList(Definition),

    pub fn init(allocator: std.mem.Allocator, id: usize, parent_id: ?usize, node: Node) Scope {
        _ = allocator;
        return .{
            .id = id,
            .parent_id = parent_id,
            .node = node,
            .definitions = std.ArrayList(Definition).empty,
        };
    }

    pub fn deinit(self: *Scope, allocator: std.mem.Allocator) void {
        self.definitions.deinit(allocator);
    }
};

pub const ScopeTable = struct {
    allocator: std.mem.Allocator,
    scopes: std.ArrayList(Scope),
    references: std.ArrayList(Reference),

    pub fn init(allocator: std.mem.Allocator) ScopeTable {
        return .{
            .allocator = allocator,
            .scopes = std.ArrayList(Scope).empty,
            .references = std.ArrayList(Reference).empty,
        };
    }

    pub fn deinit(self: *ScopeTable) void {
        const gpa = self.allocator;
        for (self.scopes.items) |*s| s.deinit(gpa);
        self.scopes.deinit(gpa);
        self.references.deinit(gpa);
    }

    pub fn findDefinition(self: *const ScopeTable, scope_id: usize, name: []const u8) ?Definition {
        var cur: ?usize = scope_id;
        while (cur) |sid| {
            if (sid >= self.scopes.items.len) break;
            const scope = self.scopes.items[sid];
            for (scope.definitions.items) |d| {
                if (std.mem.eql(u8, d.name, name)) return d;
            }
            cur = scope.parent_id;
        }
        return null;
    }
};

pub const LocalsEngine = struct {
    allocator: std.mem.Allocator,
    query: Query,

    pub fn init(allocator: std.mem.Allocator, language: treesitter.Language, locals_query_source: []const u8) !LocalsEngine {
        const q = try Query.compile(allocator, language, locals_query_source);
        return .{
            .allocator = allocator,
            .query = q,
        };
    }

    pub fn deinit(self: *LocalsEngine) void {
        self.query.deinit();
    }

    pub fn analyze(self: *LocalsEngine, tree: *const Tree, source: []const u8) !ScopeTable {
        const gpa = self.allocator;
        var table = ScopeTable.init(gpa);
        errdefer table.deinit();

        // Create root scope
        const root_scope = Scope.init(gpa, 0, null, tree.rootNode());
        try table.scopes.append(gpa, root_scope);

        var cursor = QueryCursor.init(gpa);
        defer cursor.deinit();

        try cursor.execute(self.query.language, self.query.patterns(), self.query.nodes(), self.query.captureNames(), tree);
        while (cursor.nextMatch()) |m| {
            for (m.captures) |c| {
                const name = self.query.captureName(c.name_index) orelse "";
                if (std.mem.startsWith(u8, name, "local.scope")) {
                    const sid = table.scopes.items.len;
                    // Find parent scope by checking node containment
                    var parent_sid: usize = 0;
                    for (table.scopes.items, 0..) |s, i| {
                        if (c.node.startByte() >= s.node.startByte() and c.node.endByte() <= s.node.endByte()) {
                            parent_sid = i;
                        }
                    }
                    try table.scopes.append(gpa, Scope.init(gpa, sid, parent_sid, c.node));
                } else if (std.mem.startsWith(u8, name, "local.definition")) {
                    const node = c.node;
                    // Determine which scope this definition belongs to
                    var target_sid: usize = 0;
                    for (table.scopes.items, 0..) |s, i| {
                        if (node.startByte() >= s.node.startByte() and node.endByte() <= s.node.endByte()) {
                            target_sid = i;
                        }
                    }
                    const text_slice = if (node.endByte() <= source.len) source[node.startByte()..node.endByte()] else "";
                    try table.scopes.items[target_sid].definitions.append(gpa, .{
                        .name = text_slice,
                        .node = node,
                        .scope_id = target_sid,
                    });
                } else if (std.mem.startsWith(u8, name, "local.reference")) {
                    const node = c.node;
                    const text_slice = if (node.endByte() <= source.len) source[node.startByte()..node.endByte()] else "";
                    try table.references.append(gpa, .{
                        .name = text_slice,
                        .node = node,
                    });
                }
            }
        }

        // Resolve references
        for (table.references.items) |*ref| {
            var ref_scope: usize = 0;
            for (table.scopes.items, 0..) |s, i| {
                if (ref.node.startByte() >= s.node.startByte() and ref.node.endByte() <= s.node.endByte()) {
                    ref_scope = i;
                }
            }
            if (table.findDefinition(ref_scope, ref.name)) |def| {
                _ = def;
                ref.definition_index = 0;
            }
        }

        return table;
    }
};

test "locals: analyze scope and definitions" {
    const expr_lang = treesitter.expressionLanguage;
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(expr_lang);

    const source = "x + y * x";
    var tree = try parser.parseString(source);
    defer tree.deinit();

    const query_src =
        \\(program) @local.scope
        \\(identifier) @local.definition
    ;

    var engine = try LocalsEngine.init(std.testing.allocator, expr_lang, query_src);
    defer engine.deinit();

    var table = try engine.analyze(&tree, source);
    defer table.deinit();

    try std.testing.expect(table.scopes.items.len >= 1);
    var def_count: usize = 0;
    for (table.scopes.items) |s| def_count += s.definitions.items.len;
    try std.testing.expect(def_count >= 1);
}
