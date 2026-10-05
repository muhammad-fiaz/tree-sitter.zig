const std = @import("std");
const core = @import("../core/core.zig");
const language_mod = @import("../language/language.zig");
const pattern_mod = @import("pattern.zig");
const parser_mod = @import("parser.zig");
const capture_mod = @import("capture.zig");
const predicate_mod = @import("predicate.zig");
const cursor_mod = @import("cursor.zig");
const matcher_mod = @import("matcher.zig");

pub const pattern = @import("pattern.zig");
pub const query_parser = @import("parser.zig");
pub const capture = @import("capture.zig");
pub const predicate = @import("predicate.zig");
pub const query_cursor = @import("cursor.zig");
pub const matcher = @import("matcher.zig");
pub const directives = @import("directives.zig");
pub const selectAdjacent = directives.selectAdjacent;
pub const stripText = directives.stripText;

comptime {
    _ = directives;
}

pub const QueryCursor = query_cursor.QueryCursor;
pub const Match = capture.Match;
pub const Capture = capture.Capture;

pub const QueryError = std.mem.Allocator.Error || parser_mod.QueryParseError || error{
    InvalidLanguage,
};

/// Compiled S-expression query pattern.
///
/// **Ownership**: `Query` owns compiled pattern bytecode and capture-name
/// strings allocated with `gpa`.  Call `deinit` to free them.
///
/// **Concurrency**: a compiled `Query` is effectively immutable after
/// construction (pattern bytecode and capture names do not change).
/// Multiple threads MAY read the same `Query` concurrently — pass it to
/// independent `QueryCursor` instances without synchronisation.
///
/// **Exception**: `disableCapture` / `disablePattern` mutate internal
/// disabled-flag slices.  Do NOT call these concurrently with reading
/// or with other mutations.  Apply all mutations before sharing the
/// `Query` with other threads.
pub const Query = struct {
    gpa: std.mem.Allocator,
    language: language_mod.Language,
    parsed: parser_mod.ParsedQuery,
    disabled_captures: std.ArrayList(bool) = .empty,
    disabled_patterns: std.ArrayList(bool) = .empty,

    pub fn compile(gpa: std.mem.Allocator, language: language_mod.Language, source: []const u8) QueryError!Query {
        const parsed = try parser_mod.parse(gpa, source);
        var self = Query{
            .gpa = gpa,
            .language = language,
            .parsed = parsed,
        };
        try self.disabled_captures.appendNTimes(gpa, false, parsed.captures.items.len);
        try self.disabled_patterns.appendNTimes(gpa, false, parsed.patterns.items.len);
        return self;
    }

    pub fn deinit(self: *Query) void {
        self.disabled_captures.deinit(self.gpa);
        self.disabled_patterns.deinit(self.gpa);
        self.parsed.deinit();
        self.* = undefined;
    }

    pub fn disableCapture(self: *Query, capture_id: u32) void {
        if (capture_id < self.disabled_captures.items.len) {
            self.disabled_captures.items[capture_id] = true;
        }
    }

    pub fn disablePattern(self: *Query, pattern_id: u32) void {
        if (pattern_id < self.disabled_patterns.items.len) {
            self.disabled_patterns.items[pattern_id] = true;
        }
    }

    pub fn isCaptureDisabled(self: Query, capture_id: u32) bool {
        if (capture_id < self.disabled_captures.items.len) {
            return self.disabled_captures.items[capture_id];
        }
        return false;
    }

    pub fn isPatternDisabled(self: Query, pattern_id: u32) bool {
        if (pattern_id < self.disabled_patterns.items.len) {
            return self.disabled_patterns.items[pattern_id];
        }
        return false;
    }

    pub fn isPatternRooted(self: Query, pattern_id: u32) bool {
        if (pattern_id < self.parsed.patterns.items.len) {
            return self.parsed.patterns.items[pattern_id].is_rooted;
        }
        return false;
    }

    pub fn isPatternNonLocal(self: Query, pattern_id: u32) bool {
        _ = self;
        _ = pattern_id;
        return false;
    }

    pub fn isPatternGuaranteedAtStep(self: Query, byte_offset: u32) bool {
        _ = self;
        _ = byte_offset;
        return false;
    }

    pub fn startByteForPattern(self: Query, pattern_id: u32) u32 {
        _ = self;
        _ = pattern_id;
        return 0;
    }

    pub fn endByteForPattern(self: Query, pattern_id: u32) u32 {
        if (pattern_id < self.parsed.patterns.items.len) {
            return @as(u32, @intCast(self.parsed.source.len));
        }
        return 0;
    }

    pub fn predicatesForPattern(self: Query, pattern_id: u32) []const pattern_mod.Predicate {
        if (pattern_id < self.parsed.patterns.items.len) {
            return self.parsed.patterns.items[pattern_id].predicates;
        }
        return &.{};
    }

    pub fn stringCount(self: Query) usize {
        return self.parsed.captures.items.len;
    }

    pub fn stringValueForId(self: Query, id: u32) ?[]const u8 {
        return self.captureName(id);
    }

    pub fn patternCount(self: *const Query) usize {
        return self.parsed.patterns.items.len;
    }

    pub fn captureCount(self: *const Query) usize {
        return self.parsed.captures.items.len;
    }

    pub fn captureName(self: *const Query, index: u32) ?[]const u8 {
        if (index >= self.parsed.captures.items.len) return null;
        return self.parsed.captures.items[index];
    }

    pub fn captureIndexForName(self: *const Query, name: []const u8) ?u32 {
        for (self.parsed.captures.items, 0..) |n, i| {
            if (std.mem.eql(u8, n, name)) return @as(u32, @intCast(i));
        }
        return null;
    }

    pub fn nodes(self: *const Query) []const pattern_mod.PatternNode {
        return self.parsed.nodes.items;
    }

    pub fn patterns(self: *const Query) []const pattern_mod.Pattern {
        return self.parsed.patterns.items;
    }

    pub fn captureNames(self: *const Query) []const []const u8 {
        return self.parsed.captures.items;
    }

    /// `#set!` property settings for a pattern (upstream
    /// `property_settings`).
    pub fn propertySettings(self: *const Query, pattern_index: usize) []const pattern_mod.Setting {
        if (pattern_index >= self.parsed.patterns.items.len) return &.{};
        return self.parsed.patterns.items[pattern_index].settings;
    }

    /// General `#name!` directives for a pattern (upstream
    /// `general_predicates`): `select-adjacent!`, `strip!`, and anything
    /// unknown, exposed structurally for higher-level code.
    pub fn generalPredicates(self: *const Query, pattern_index: usize) []const pattern_mod.Directive {
        if (pattern_index >= self.parsed.patterns.items.len) return &.{};
        return self.parsed.patterns.items[pattern_index].directives;
    }

    /// Quantifier of the node carrying `capture_index` in the given
    /// pattern, or null when the pattern never captures it (upstream
    /// `capture_quantifier` introspection).
    pub fn captureQuantifier(self: *const Query, pattern_index: usize, capture_index: u32) ?pattern_mod.Quantifier {
        if (pattern_index >= self.parsed.patterns.items.len) return null;
        const all_nodes = self.parsed.nodes.items;
        const root = self.parsed.patterns.items[pattern_index].root;
        return findCaptureQuantifier(all_nodes, root, capture_index);
    }
};

fn findCaptureQuantifier(
    nodes: []const pattern_mod.PatternNode,
    idx: u32,
    capture_index: u32,
) ?pattern_mod.Quantifier {
    if (idx >= nodes.len) return null;
    const node = nodes[idx];
    if (node.capture) |cap| {
        if (cap == capture_index) return node.quantifier;
    }
    for (node.children) |child| {
        if (findCaptureQuantifier(nodes, child, capture_index)) |q| return q;
    }
    return null;
}

const runtime_parser = @import("../parser/parser.zig");

test "query: named node with capture" {
    var parser = runtime_parser.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("foo + 42");
    defer tree.deinit();
    var query = try Query.compile(std.testing.allocator, language_mod.expression_language, "(identifier) @id");
    defer query.deinit();
    var cursor = QueryCursor.init(std.testing.allocator);
    defer cursor.deinit();
    try cursor.execute(language_mod.expression_language, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 1), cursor.matchCount());
    const m = cursor.nextMatch().?;
    try std.testing.expectEqualStrings("id", m.captures[0].name);
    try std.testing.expectEqualStrings("foo", m.captures[0].node.text());
}

test "query: anonymous token" {
    var parser = runtime_parser.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 + 2 - 3");
    defer tree.deinit();
    var query = try Query.compile(std.testing.allocator, language_mod.expression_language, "(expression \"+\" @plus)");
    defer query.deinit();
    var cursor = QueryCursor.init(std.testing.allocator);
    defer cursor.deinit();
    try cursor.execute(language_mod.expression_language, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 1), cursor.matchCount());
}

test "query: wildcard and fields" {
    var parser = runtime_parser.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("a * b");
    defer tree.deinit();
    var query = try Query.compile(
        std.testing.allocator,
        language_mod.expression_language,
        "(term left: (_) @l right: (_) @r)",
    );
    defer query.deinit();
    var cursor = QueryCursor.init(std.testing.allocator);
    defer cursor.deinit();
    try cursor.execute(language_mod.expression_language, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 1), cursor.matchCount());
    const m = cursor.nextMatch().?;
    try std.testing.expectEqual(@as(usize, 2), m.captures.len);
}

test "query: eq predicate filters" {
    var parser = runtime_parser.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("foo + foo");
    defer tree.deinit();
    var query = try Query.compile(
        std.testing.allocator,
        language_mod.expression_language,
        "((identifier) @a (#eq? @a \"foo\"))",
    );
    defer query.deinit();
    var cursor = QueryCursor.init(std.testing.allocator);
    defer cursor.deinit();
    try cursor.execute(language_mod.expression_language, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 2), cursor.matchCount());
}

test "query: invalid syntax errors" {
    const r = Query.compile(std.testing.allocator, language_mod.expression_language, "((unclosed");
    if (r) |q| {
        var query = q;
        query.deinit();
        try std.testing.expect(false);
    } else |_| {}
}

test "query: multiple patterns" {
    var parser = runtime_parser.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("a + 1");
    defer tree.deinit();
    var query = try Query.compile(
        std.testing.allocator,
        language_mod.expression_language,
        "(identifier) @id (number) @num",
    );
    defer query.deinit();
    try std.testing.expectEqual(@as(usize, 2), query.patternCount());
    var cursor = QueryCursor.init(std.testing.allocator);
    defer cursor.deinit();
    try cursor.execute(language_mod.expression_language, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 2), cursor.matchCount());
}

fn countMatches(source: []const u8, pattern_text: []const u8) !usize {
    var parser = runtime_parser.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString(source);
    defer tree.deinit();
    var query = try Query.compile(std.testing.allocator, language_mod.expression_language, pattern_text);
    defer query.deinit();
    var cursor = QueryCursor.init(std.testing.allocator);
    defer cursor.deinit();
    try cursor.execute(language_mod.expression_language, query.patterns(), query.nodes(), query.captureNames(), &tree);
    return cursor.matchCount();
}

test "matcher: nested pattern requires direct child" {
    try std.testing.expectEqual(@as(usize, 1), try countMatches("1 + 2", "(program (expression))"));
    try std.testing.expectEqual(@as(usize, 0), try countMatches("1 + 2", "(program (number))"));
}

test "matcher: match predicate on text" {
    try std.testing.expectEqual(
        @as(usize, 1),
        try countMatches("abc + 1", "((identifier) @x (#match? @x \"^a\"))"),
    );
    try std.testing.expectEqual(
        @as(usize, 0),
        try countMatches("abc + 1", "((identifier) @x (#match? @x \"^z\"))"),
    );
}

test "matcher: byte range limits results" {
    var parser = runtime_parser.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("a + b");
    defer tree.deinit();
    var query = try Query.compile(std.testing.allocator, language_mod.expression_language, "(identifier) @id");
    defer query.deinit();
    var cursor = QueryCursor.init(std.testing.allocator);
    defer cursor.deinit();
    cursor.setByteRange(4, 5);
    try cursor.execute(language_mod.expression_language, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 1), cursor.matchCount());
}

test "matcher: quantifiers" {
    try std.testing.expectEqual(@as(usize, 2), try countMatches("a + b + c", "(expression (_) @x \"+\" @p (_) @y)"));
    try std.testing.expectEqual(@as(usize, 1), try countMatches("a", "(program (expression (term (factor (number)?))))"));
}

test "predicates: any-eq distinguishes all from any" {
    // One match with two @x captures ("a" and "b"): ALL fails, ANY passes.
    try std.testing.expectEqual(@as(usize, 0), try countMatches("a + b", "((expression (_) @x \"+\" (_) @x) (#eq? @x \"a\"))"));
    try std.testing.expectEqual(@as(usize, 1), try countMatches("a + b", "((expression (_) @x \"+\" (_) @x) (#any-eq? @x \"a\"))"));
    try std.testing.expectEqual(@as(usize, 1), try countMatches("a + b", "((expression (_) @x \"+\" (_) @x) (#any-not-eq? @x \"a\"))"));
    try std.testing.expectEqual(@as(usize, 0), try countMatches("a + a", "((expression (_) @x \"+\" (_) @x) (#any-not-eq? @x \"a\"))"));
}

test "predicates: any-match" {
    try std.testing.expectEqual(@as(usize, 1), try countMatches("abc + zzz", "((expression (_) @x \"+\" (_) @x) (#any-match? @x \"^a\"))"));
    try std.testing.expectEqual(@as(usize, 0), try countMatches("abc + zzz", "((expression (_) @x \"+\" (_) @x) (#match? @x \"^a\"))"));
}

test "predicates: argument shapes are validated" {
    const lang = language_mod.expression_language;
    // First arg must be a capture.
    try std.testing.expectError(error.InvalidPredicate, Query.compile(std.testing.allocator, lang, "((identifier) @x (#eq? \"a\" \"b\"))"));
    // match? takes a literal pattern.
    try std.testing.expectError(error.InvalidPredicate, Query.compile(std.testing.allocator, lang, "(number) @y ((identifier) @x (#match? @x @y))"));
    // any-of? takes literals only.
    try std.testing.expectError(error.InvalidPredicate, Query.compile(std.testing.allocator, lang, "(number) @y ((identifier) @x (#any-of? @x @y))"));
    // Undeclared captures are compile errors (typo protection).
    try std.testing.expectError(error.InvalidCapture, Query.compile(std.testing.allocator, lang, "((identifier) @x (#eq? @typo \"a\"))"));
    try std.testing.expectError(error.InvalidCapture, Query.compile(std.testing.allocator, lang, "((identifier) @x (#select-adjacent! @x @nope))"));
}

test "anchors: leading, between, and trailing" {
    // Leading: first named child of each term (both terms match once).
    try std.testing.expectEqual(@as(usize, 2), try countMatches("a * b", "(term . (_) @a)"));
    try std.testing.expectEqual(@as(usize, 2), try countMatches("a * b", "(term (_) @a)"));
    // Leading skips anonymous nodes: the expression sits behind "(".
    try std.testing.expectEqual(@as(usize, 1), try countMatches("(1 + 2)", "(factor . (expression) @e)"));
    // Leading anonymous children match the exact first child.
    try std.testing.expectEqual(@as(usize, 1), try countMatches("(1 + 2)", "(factor . \"(\" @p)"));
    // Between: named-adjacent despite the anonymous operator.
    try std.testing.expectEqual(@as(usize, 1), try countMatches("a * b", "(term (_) @a . (_) @b)"));
    // Trailing: last named child of each term.
    try std.testing.expectEqual(@as(usize, 2), try countMatches("a * b", "(term (_) @a .)"));
    // Group trailing dot is vacuous.
    try std.testing.expectEqual(@as(usize, 1), try countMatches("a + 1", "((identifier) @x .)"));
}

test "fields: negated assertions" {
    const jlang = language_mod.json_language;
    var jparser = runtime_parser.Parser.init(std.testing.allocator);
    defer jparser.deinit();
    try jparser.setLanguage(jlang);
    var jtree = try jparser.parseString("{\"a\": 1}");
    defer jtree.deinit();
    var jq = try Query.compile(std.testing.allocator, jlang, "(pair !key) @p");
    defer jq.deinit();
    var jqc = QueryCursor.init(std.testing.allocator);
    defer jqc.deinit();
    try jqc.execute(jlang, jq.patterns(), jq.nodes(), jq.captureNames(), &jtree);
    // Every pair binds key: no match.
    try std.testing.expectEqual(@as(usize, 0), jqc.matchCount());
    var jq2 = try Query.compile(std.testing.allocator, jlang, "(pair !middle) @p");
    defer jq2.deinit();
    var jqc2 = QueryCursor.init(std.testing.allocator);
    defer jqc2.deinit();
    try jqc2.execute(jlang, jq2.patterns(), jq2.nodes(), jq2.captureNames(), &jtree);
    try std.testing.expectEqual(@as(usize, 1), jqc2.matchCount());
}

test "directives: set and general forms" {
    const lang = language_mod.expression_language;
    var q = try Query.compile(std.testing.allocator, lang, "((identifier) @x (#set! lang \"expr\") (#set! flag))");
    defer q.deinit();
    const settings = q.propertySettings(0);
    try std.testing.expectEqual(@as(usize, 2), settings.len);
    try std.testing.expectEqualStrings("lang", settings[0].key);
    try std.testing.expectEqualStrings("expr", settings[0].value.?);
    try std.testing.expectEqualStrings("flag", settings[1].key);
    try std.testing.expect(settings[1].value == null);

    var q2 = try Query.compile(
        std.testing.allocator,
        lang,
        "((identifier) @x (#select-adjacent! @x @x) (#strip! @x \"^a\") (#frobnicate! @x \"z\"))",
    );
    defer q2.deinit();
    const generals = q2.generalPredicates(0);
    try std.testing.expectEqual(@as(usize, 3), generals.len);
    try std.testing.expectEqualStrings("select-adjacent!", generals[0].operator);
    try std.testing.expectEqualStrings("strip!", generals[1].operator);
    try std.testing.expectEqualStrings("frobnicate!", generals[2].operator);
    try std.testing.expect(q2.propertySettings(0).len == 0);
    try std.testing.expect(q2.propertySettings(9).len == 0);
}

test "query: capture quantifier introspection" {
    const lang = language_mod.expression_language;
    var q = try Query.compile(std.testing.allocator, lang, "((identifier)+ @id)");
    defer q.deinit();
    try std.testing.expectEqual(pattern_mod.Quantifier.one_or_more, q.captureQuantifier(0, 0).?);
    var q2 = try Query.compile(std.testing.allocator, lang, "(identifier) @id");
    defer q2.deinit();
    try std.testing.expectEqual(pattern_mod.Quantifier.one, q2.captureQuantifier(0, 0).?);
    try std.testing.expect(q2.captureQuantifier(0, 7) == null);
    try std.testing.expect(q2.captureQuantifier(7, 0) == null);
}

test "query: disabling and metadata introspection" {
    const lang = language_mod.expression_language;
    var q = try Query.compile(std.testing.allocator, lang, "(identifier) @id (number) @num");
    defer q.deinit();

    try std.testing.expectEqual(@as(usize, 2), q.stringCount());
    try std.testing.expectEqualStrings("id", q.stringValueForId(0).?);
    try std.testing.expectEqualStrings("num", q.stringValueForId(1).?);
    try std.testing.expect(q.stringValueForId(99) == null);

    try std.testing.expect(!q.isCaptureDisabled(0));
    q.disableCapture(0);
    try std.testing.expect(q.isCaptureDisabled(0));

    try std.testing.expect(!q.isPatternDisabled(0));
    q.disablePattern(0);
    try std.testing.expect(q.isPatternDisabled(0));

    try std.testing.expect(!q.isPatternRooted(0));
    try std.testing.expect(!q.isPatternNonLocal(0));
    try std.testing.expectEqual(@as(u32, 0), q.startByteForPattern(0));
    try std.testing.expect(q.endByteForPattern(0) > 0);
    try std.testing.expectEqual(@as(usize, 0), q.predicatesForPattern(0).len);
}

test "query cursor: nextCapture, removeMatch, matchLimit, and containing ranges" {
    const lang = language_mod.expression_language;
    var parser = runtime_parser.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(lang);

    var tree = try parser.parseString("foo + bar * 42");
    defer tree.deinit();

    var query = try Query.compile(std.testing.allocator, lang, "(identifier) @id");
    defer query.deinit();

    var cursor = QueryCursor.init(std.testing.allocator);
    defer cursor.deinit();

    try cursor.execute(lang, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 2), cursor.matchCount());

    // Test nextCapture
    var match: capture_mod.Match = undefined;
    var cap_idx: u32 = 0;
    var cap_count: usize = 0;
    while (cursor.nextCapture(&match, &cap_idx)) {
        cap_count += 1;
        try std.testing.expect(cap_idx == 0);
    }
    try std.testing.expectEqual(@as(usize, 2), cap_count);

    // Test removeMatch
    cursor.removeMatch(0);
    try std.testing.expectEqual(@as(usize, 1), cursor.matchCount());

    // Test matchLimit
    cursor.setMatchLimit(1);
    try std.testing.expectEqual(@as(?u32, 1), cursor.matchLimit());
    try cursor.execute(lang, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expect(cursor.didExceedMatchLimit());
    try std.testing.expectEqual(@as(usize, 1), cursor.matchCount());

    // Test containing byte range
    cursor.resetAll();
    cursor.setContainingByteRange(0, 3); // only "foo"
    try cursor.execute(lang, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 1), cursor.matchCount());

    // Test max start depth
    cursor.resetAll();
    cursor.setMaxStartDepth(0); // root only (program) -> no identifier at depth 0
    try cursor.execute(lang, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 0), cursor.matchCount());
}
