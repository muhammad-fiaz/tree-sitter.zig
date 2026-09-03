const std = @import("std");
const core = @import("../core/core.zig");
const language_mod = @import("../language/language.zig");
const parser_mod = @import("../parser/parser.zig");
const tree_mod = @import("../tree/tree.zig");
const sexp_mod = @import("../tree/sexp.zig");

/// Differential conformance harness: corpus-driven behavioral comparison.
///
/// Each case in `corpus/*.txt` (next to this file) declares a grammar, an
/// input source, and the expected S-expression (see `tree/sexp.zig` for
/// the format). `runCase` parses the source and compares against the
/// reference output; `incremental` cases additionally reparse an edited
/// source through the incremental path and require byte-identical trees
/// to a fresh parse. The same cases run inside `zig build test` (see
/// the corpus test at the bottom of `parser/parser.zig`) and as a
/// human-readable report via `zig build conformance`.
pub const CaseKind = enum {
    parse,
    incremental,
};

/// Every corpus case, embedded once here. Both `zig build conformance`
/// and the `zig build test` corpus test iterate this list, so reference
/// outputs cannot drift between runners.
pub const corpus_files: []const []const u8 = &.{
    @embedFile("corpus/expr_precedence.txt"),
    @embedFile("corpus/expr_parens.txt"),
    @embedFile("corpus/expr_error.txt"),
    @embedFile("corpus/expr_missing.txt"),
    @embedFile("corpus/expr_empty.txt"),
    @embedFile("corpus/sexp_nested.txt"),
    @embedFile("corpus/sexp_empty.txt"),
    @embedFile("corpus/sexp_atoms.txt"),
    @embedFile("corpus/incr_growth.txt"),
    @embedFile("corpus/incr_replace.txt"),
    @embedFile("corpus/json_basic.txt"),
    @embedFile("corpus/json_nested.txt"),
    @embedFile("corpus/json_empty.txt"),
    @embedFile("corpus/json_error.txt"),
    @embedFile("corpus/json_incr.txt"),
    @embedFile("corpus/outline_basic.txt"),
    @embedFile("corpus/outline_nested.txt"),
    @embedFile("corpus/outline_error.txt"),
    @embedFile("corpus/outline_incr.txt"),
};

pub const Case = struct {
    arena: std.heap.ArenaAllocator,
    grammar: []const u8,
    name: []const u8,
    kind: CaseKind,
    source: []const u8,
    expected: []const u8,
    edit: core.InputEdit,
    new_source: []const u8,

    pub fn deinit(self: *Case) void {
        self.arena.deinit();
    }
};

/// Parse one corpus file. Format:
///
/// ```text
/// # grammar: expression
/// # name: precedence
/// ---source---
/// 1 + 2 * 3
/// ---sexp---
/// (program ...)
/// ```
///
/// Incremental cases replace `---sexp---` with an edit triple
/// (`start_byte old_end_byte new_end_byte`, single-line sources only)
/// followed by a second `---source---` section.
pub fn parseCase(gpa: std.mem.Allocator, text: []const u8) !Case {
    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit();
    const aa = arena.allocator();
    var grammar: []const u8 = "";
    var name: []const u8 = "";
    var kind: CaseKind = .parse;
    var source: []const u8 = "";
    var expected: []const u8 = "";
    var new_source: []const u8 = "";
    var edit: core.InputEdit = .{};
    var section: enum { none, source, sexp, edit } = .none;
    var source_count: u8 = 0;
    var src_buf = std.ArrayList(u8).empty;
    var exp_buf = std.ArrayList(u8).empty;
    var new_buf = std.ArrayList(u8).empty;
    var edit_vals: [3]u32 = .{ 0, 0, 0 };
    var edit_seen = false;

    // Strip the file-final newline so the last section does not gain a
    // phantom empty line. (Corpus sources must not end in a blank line;
    // interior blank lines are preserved.)
    var lines = std.mem.splitScalar(u8, std.mem.trimEnd(u8, text, "\r\n"), '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (std.mem.startsWith(u8, line, "# grammar:")) {
            grammar = try aa.dupe(u8, std.mem.trim(u8, line["# grammar:".len..], " "));
        } else if (std.mem.startsWith(u8, line, "# name:")) {
            name = try aa.dupe(u8, std.mem.trim(u8, line["# name:".len..], " "));
        } else if (std.mem.eql(u8, line, "---source---")) {
            source_count += 1;
            if (source_count == 2) kind = .incremental;
            section = .source;
        } else if (std.mem.eql(u8, line, "---sexp---")) {
            section = .sexp;
        } else if (std.mem.eql(u8, line, "---edit---")) {
            section = .edit;
        } else if (section == .edit) {
            const t = std.mem.trim(u8, line, " ");
            if (t.len == 0) continue;
            var it = std.mem.splitScalar(u8, t, ' ');
            var i: usize = 0;
            while (it.next()) |tok| {
                if (tok.len == 0) continue;
                if (i < 3) edit_vals[i] = try std.fmt.parseInt(u32, tok, 10);
                i += 1;
            }
            if (i != 3) return error.InvalidCorpus;
            edit_seen = true;
        } else if (section == .source) {
            const buf = if (source_count == 1) &src_buf else &new_buf;
            if (buf.items.len > 0) try buf.append(aa, '\n');
            try buf.appendSlice(aa, line);
        } else if (section == .sexp) {
            const t = std.mem.trim(u8, line, " ");
            if (t.len == 0) continue;
            if (exp_buf.items.len > 0) try exp_buf.append(aa, ' ');
            try exp_buf.appendSlice(aa, t);
        }
    }
    source = try src_buf.toOwnedSlice(aa);
    expected = try exp_buf.toOwnedSlice(aa);
    new_source = try new_buf.toOwnedSlice(aa);
    if (grammar.len == 0 or name.len == 0 or source_count == 0) return error.InvalidCorpus;
    if (kind == .incremental) {
        if (!edit_seen) return error.InvalidCorpus;
        edit = .{
            .start_byte = edit_vals[0],
            .old_end_byte = edit_vals[1],
            .new_end_byte = edit_vals[2],
            .start_point = .{ .row = 0, .column = edit_vals[0] },
            .old_end_point = .{ .row = 0, .column = edit_vals[1] },
            .new_end_point = .{ .row = 0, .column = edit_vals[2] },
        };
    } else if (expected.len == 0) {
        return error.InvalidCorpus;
    }
    return .{
        .arena = arena,
        .grammar = grammar,
        .name = name,
        .kind = kind,
        .source = source,
        .expected = expected,
        .edit = edit,
        .new_source = new_source,
    };
}

/// Resolve a corpus grammar name to bundled table data.
pub fn languageForName(name: []const u8) ?language_mod.Language {
    if (std.mem.eql(u8, name, "expression")) return language_mod.expression_language;
    if (std.mem.eql(u8, name, "sexp")) return language_mod.sexp_language;
    if (std.mem.eql(u8, name, "json")) return language_mod.json_language;
    if (std.mem.eql(u8, name, "outline")) return language_mod.outline_language;
    return null;
}

pub const CaseFailure = error{
    OutOfMemory,
    GrammarMismatch,
    SexpMismatch,
    IncrementalMismatch,
} || parser_mod.ParserError || language_mod.Language.Error;

const outline_scanner = @import("../language/outline_scanner.zig");

const Prepared = struct {
    parser: parser_mod.Parser,
    gpa: std.mem.Allocator,
    scan_holder: ?*outline_scanner.ScanState,

    fn deinit(self: *Prepared) void {
        self.parser.deinit();
        if (self.scan_holder) |holder| {
            holder.deinit();
            self.gpa.destroy(holder);
        }
    }
};

/// Build a parser for a corpus grammar. Bundled scanner languages ship
/// a null payload, so the harness provisions heap-owned caller state
/// (the same pattern tests and examples use) and wires it in.
fn prepare(gpa: std.mem.Allocator, grammar: []const u8) !Prepared {
    var language = languageForName(grammar) orelse return error.GrammarMismatch;
    var holder: ?*outline_scanner.ScanState = null;
    errdefer if (holder) |h| {
        h.deinit();
        gpa.destroy(h);
    };
    if (language.external_scanner) |*scanner| {
        if (scanner.payload == null) {
            holder = try gpa.create(outline_scanner.ScanState);
            holder.?.* = outline_scanner.ScanState.init(gpa);
            scanner.payload = holder.?;
        }
    }
    var parser = parser_mod.Parser.init(gpa);
    errdefer parser.deinit();
    try parser.setLanguage(language);
    return .{ .parser = parser, .gpa = gpa, .scan_holder = holder };
}

/// Run one case. On mismatch returns `SexpMismatch` /
/// `IncrementalMismatch`; callers print `actual` via `renderActual`.
pub fn runCase(gpa: std.mem.Allocator, case: *const Case) CaseFailure!void {
    var prep = try prepare(gpa, case.grammar);
    defer prep.deinit();
    var parser = &prep.parser;
    if (case.kind == .parse) {
        var tree = try parser.parseString(case.source);
        defer tree.deinit();
        const actual = try sexp_mod.toSexp(gpa, tree.rootNode());
        defer gpa.free(actual);
        if (!std.mem.eql(u8, actual, case.expected)) return error.SexpMismatch;
        return;
    }
    var old_tree = try parser.parseString(case.source);
    defer old_tree.deinit();
    var inc = try parser.parse(&old_tree, case.edit, case.new_source);
    defer inc.deinit();
    var fresh = try parser.parseString(case.new_source);
    defer fresh.deinit();
    const a = try sexp_mod.toSexp(gpa, inc.rootNode());
    defer gpa.free(a);
    const b = try sexp_mod.toSexp(gpa, fresh.rootNode());
    defer gpa.free(b);
    if (!std.mem.eql(u8, a, b)) return error.IncrementalMismatch;
}

/// Render the actual S-expression of a case for failure reports.
pub fn renderActual(gpa: std.mem.Allocator, case: *const Case) ![]u8 {
    var prep = try prepare(gpa, case.grammar);
    defer prep.deinit();
    var parser = &prep.parser;
    if (case.kind == .parse) {
        var tree = try parser.parseString(case.source);
        defer tree.deinit();
        return sexp_mod.toSexp(gpa, tree.rootNode());
    }
    var old_tree = try parser.parseString(case.source);
    defer old_tree.deinit();
    var inc = try parser.parse(&old_tree, case.edit, case.new_source);
    defer inc.deinit();
    return sexp_mod.toSexp(gpa, inc.rootNode());
}

test "conformance: corpus format parses" {
    const text =
        "# grammar: expression\n" ++
        "# name: demo\n" ++
        "---source---\n" ++
        "1 + 2\n" ++
        "---sexp---\n" ++
        "(program (expression))\n";
    var case = try parseCase(std.testing.allocator, text);
    defer case.deinit();
    try std.testing.expectEqualStrings("expression", case.grammar);
    try std.testing.expectEqualStrings("demo", case.name);
    try std.testing.expectEqual(CaseKind.parse, case.kind);
    try std.testing.expectEqualStrings("1 + 2", case.source);

    const incr_text =
        "# grammar: expression\n" ++
        "# name: growth\n" ++
        "---source---\n" ++
        "1 + 2\n" ++
        "---edit---\n" ++
        "5 5 6\n" ++
        "---source---\n" ++
        "1 + 22\n";
    var icase = try parseCase(std.testing.allocator, incr_text);
    defer icase.deinit();
    try std.testing.expectEqual(CaseKind.incremental, icase.kind);
    try std.testing.expectEqual(@as(u32, 5), icase.edit.start_byte);
    try std.testing.expectEqual(@as(u32, 6), icase.edit.new_end_byte);
    try std.testing.expectEqualStrings("1 + 22", icase.new_source);

    try std.testing.expect(languageForName("expression") != null);
    try std.testing.expect(languageForName("sexp") != null);
    try std.testing.expect(languageForName("nope") == null);
}
