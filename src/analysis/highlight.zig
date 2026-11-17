const std = @import("std");
const treesitter = @import("../treesitter.zig");
const Query = treesitter.Query;
const QueryCursor = treesitter.QueryCursor;
const Tree = treesitter.Tree;
const Node = treesitter.Node;

pub const HighlightEvent = union(enum) {
    source: []const u8,
    highlight_start: usize,
    highlight_end,
};

pub const HighlightSpan = struct {
    start_byte: u32,
    end_byte: u32,
    highlight_id: usize,
    capture_name: []const u8,
};

pub const Highlighter = struct {
    allocator: std.mem.Allocator,
    query: Query,
    capture_names: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator, query_source: []const u8, language: treesitter.Language) !Highlighter {
        const q = try Query.compile(allocator, language, query_source);
        var names = std.ArrayList([]const u8).empty;
        errdefer names.deinit(allocator);

        for (q.captureNames()) |name| {
            try names.append(allocator, try allocator.dupe(u8, name));
        }

        return .{
            .allocator = allocator,
            .query = q,
            .capture_names = names,
        };
    }

    pub fn deinit(self: *Highlighter) void {
        const gpa = self.allocator;
        self.query.deinit();
        for (self.capture_names.items) |n| gpa.free(n);
        self.capture_names.deinit(gpa);
    }

    pub fn highlight(self: *Highlighter, tree: *const Tree, source: []const u8) ![]HighlightSpan {
        _ = source;
        const gpa = self.allocator;
        var cursor = QueryCursor.init(gpa);
        defer cursor.deinit();

        var spans = std.ArrayList(HighlightSpan).empty;
        errdefer spans.deinit(gpa);

        try cursor.execute(self.query.language, self.query.patterns(), self.query.nodes(), self.query.captureNames(), tree);
        while (cursor.nextMatch()) |m| {
            for (m.captures) |c| {
                const node = c.node;
                const name = self.query.captureName(c.name_index) orelse "unknown";
                try spans.append(gpa, .{
                    .start_byte = node.startByte(),
                    .end_byte = node.endByte(),
                    .highlight_id = c.name_index,
                    .capture_name = name,
                });
            }
        }

        // Sort spans by start_byte, then end_byte descending
        std.mem.sort(HighlightSpan, spans.items, {}, struct {
            fn lessThan(_: void, a: HighlightSpan, b: HighlightSpan) bool {
                if (a.start_byte != b.start_byte) return a.start_byte < b.start_byte;
                return a.end_byte > b.end_byte;
            }
        }.lessThan);

        _ = source;
        return try spans.toOwnedSlice(gpa);
    }

    pub fn renderAnsi(self: *Highlighter, spans: []const HighlightSpan, source: []const u8, writer: anytype) !void {
        _ = self;
        var offset: usize = 0;
        for (spans) |span| {
            if (span.start_byte > offset and offset < source.len) {
                try writer.writeAll(source[offset..span.start_byte]);
            }
            if (span.start_byte >= offset and span.end_byte <= source.len) {
                const color_code = colorForCapture(span.capture_name);
                try writer.print("\x1b[{s}m{s}\x1b[0m", .{ color_code, source[span.start_byte..span.end_byte] });
                offset = span.end_byte;
            }
        }
        if (offset < source.len) {
            try writer.writeAll(source[offset..]);
        }
    }

    fn colorForCapture(name: []const u8) []const u8 {
        if (std.mem.startsWith(u8, name, "keyword")) return "35"; // Magenta
        if (std.mem.startsWith(u8, name, "string")) return "32"; // Green
        if (std.mem.startsWith(u8, name, "number") or std.mem.startsWith(u8, name, "constant")) return "33"; // Yellow
        if (std.mem.startsWith(u8, name, "function")) return "34"; // Blue
        if (std.mem.startsWith(u8, name, "type")) return "36"; // Cyan
        if (std.mem.startsWith(u8, name, "comment")) return "90"; // Bright Black (Gray)
        if (std.mem.startsWith(u8, name, "operator")) return "37"; // White
        return "39"; // Default
    }
};

test "highlight: highlight json source" {
    const json_lang = treesitter.jsonLanguage;
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(json_lang);

    const source = "{\"name\": \"ada\", \"active\": true}";
    var tree = try parser.parseString(source);
    defer tree.deinit();

    const query_src =
        \\(pair key: (string) @property.key)
        \\(pair value: (string) @string)
        \\(number) @number
        \\(true) @constant.builtin
        \\(false) @constant.builtin
    ;

    var highlighter = try Highlighter.init(std.testing.allocator, query_src, json_lang);
    defer highlighter.deinit();

    const spans = try highlighter.highlight(&tree, source);
    defer std.testing.allocator.free(spans);

    try std.testing.expect(spans.len >= 2);
}
