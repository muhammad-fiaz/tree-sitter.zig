const std = @import("std");
const treesitter = @import("../treesitter.zig");
const Query = treesitter.Query;
const QueryCursor = treesitter.QueryCursor;
const Tree = treesitter.Tree;
const Range = treesitter.Range;

pub const InjectionRegion = struct {
    language_name: []const u8,
    ranges: []Range,
    combined: bool = false,
};

pub const InjectionEngine = struct {
    allocator: std.mem.Allocator,
    query: Query,

    pub fn init(allocator: std.mem.Allocator, language: treesitter.Language, injection_query_source: []const u8) !InjectionEngine {
        const q = try Query.compile(allocator, language, injection_query_source);
        return .{
            .allocator = allocator,
            .query = q,
        };
    }

    pub fn deinit(self: *InjectionEngine) void {
        self.query.deinit();
    }

    pub fn collectInjections(self: *InjectionEngine, tree: *const Tree, source: []const u8) ![]InjectionRegion {
        const gpa = self.allocator;
        var cursor = QueryCursor.init(gpa);
        defer cursor.deinit();

        var list = std.ArrayList(InjectionRegion).empty;
        errdefer {
            for (list.items) |r| {
                gpa.free(r.language_name);
                gpa.free(r.ranges);
            }
            list.deinit(gpa);
        }

        try cursor.execute(self.query.language, self.query.patterns(), self.query.nodes(), self.query.captureNames(), tree);
        while (cursor.nextMatch()) |m| {
            var lang_name: ?[]const u8 = null;
            var content_start: ?u32 = null;
            var content_end: ?u32 = null;
            var start_point = treesitter.Point{};
            var end_point = treesitter.Point{};
            var combined = false;

            // Check pattern settings for injection.language
            const pat_idx = m.pattern_index;
            for (self.query.propertySettings(pat_idx)) |s| {
                if (std.mem.eql(u8, s.key, "injection.language") or std.mem.eql(u8, s.key, "language")) {
                    lang_name = s.value;
                }
                if (std.mem.eql(u8, s.key, "injection.combined")) {
                    combined = true;
                }
            }

            for (m.captures) |c| {
                const cname = self.query.captureName(c.name_index) orelse "";
                if (std.mem.eql(u8, cname, "injection.language") or std.mem.eql(u8, cname, "language")) {
                    const sb = c.node.startByte();
                    const eb = c.node.endByte();
                    if (eb <= source.len and sb <= eb) {
                        lang_name = source[sb..eb];
                    }
                } else if (std.mem.eql(u8, cname, "injection.content") or std.mem.eql(u8, cname, "content")) {
                    content_start = c.node.startByte();
                    content_end = c.node.endByte();
                    start_point = c.node.startPoint();
                    end_point = c.node.endPoint();
                }
            }

            if (lang_name) |lname| {
                if (content_start) |cs| {
                    const ce = content_end orelse cs;
                    var ranges = try gpa.alloc(Range, 1);
                    ranges[0] = .{
                        .start_byte = cs,
                        .end_byte = ce,
                        .start_point = start_point,
                        .end_point = end_point,
                    };
                    try list.append(gpa, .{
                        .language_name = try gpa.dupe(u8, lname),
                        .ranges = ranges,
                        .combined = combined,
                    });
                }
            }
        }

        return try list.toOwnedSlice(gpa);
    }
};

test "injection: find embedded language regions" {
    const json_lang = treesitter.jsonLanguage;
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(json_lang);

    const source = "{\"script\": \"console.log(1);\"}";
    var tree = try parser.parseString(source);
    defer tree.deinit();

    const query_src =
        \\((pair (string) @key (value) @injection.content)
        \\ (#set! injection.language "javascript"))
    ;

    var engine = try InjectionEngine.init(std.testing.allocator, json_lang, query_src);
    defer engine.deinit();

    const regions = try engine.collectInjections(&tree, source);
    defer {
        for (regions) |r| {
            std.testing.allocator.free(r.language_name);
            std.testing.allocator.free(r.ranges);
        }
        std.testing.allocator.free(regions);
    }

    try std.testing.expectEqual(@as(usize, 1), regions.len);
    try std.testing.expectEqualStrings("javascript", regions[0].language_name);
}
