const std = @import("std");

pub const core = @import("core/core.zig");
pub const memory = @import("memory/memory.zig");
pub const parser_mod = @import("parser/parser.zig");
pub const lexer_mod = @import("lexer/lexer.zig");
pub const tree_mod = @import("tree/tree.zig");
pub const language_mod = @import("language/language.zig");
pub const query_mod = @import("query/query.zig");
pub const input_mod = @import("input/input.zig");
pub const unicode_mod = @import("unicode/unicode.zig");
pub const debug_mod = @import("debug/debug.zig");
pub const utils = @import("utils/utils.zig");

pub const Point = core.Point;
pub const Range = core.Range;
pub const InputEdit = core.InputEdit;
pub const Symbol = core.Symbol;
pub const SymbolId = core.SymbolId;
pub const Length = core.Length;

pub const Parser = parser_mod.Parser;
pub const ParserError = parser_mod.ParserError;

pub const Tree = tree_mod.Tree;
pub const Node = tree_mod.Node;
pub const Subtree = tree_mod.Subtree;
pub const TreeCursor = tree_mod.TreeCursor;
pub const sexp_mod = tree_mod.sexp_mod;

pub const Language = language_mod.Language;
pub const ExternalScanner = language_mod.ExternalScanner;
pub const TokenMatcher = language_mod.TokenMatcher;

pub const Query = query_mod.Query;
pub const QueryError = query_mod.QueryError;
pub const QueryCursor = query_mod.QueryCursor;
pub const Match = query_mod.Match;
pub const Capture = query_mod.Capture;

pub const Input = input_mod.Input;
pub const InputEncoding = input_mod.InputEncoding;
pub const MemorySource = input_mod.MemorySource;
pub const ReaderSource = input_mod.ReaderSource;
pub const Source = input_mod.Source;
pub const StreamBuffer = input_mod.StreamBuffer;

pub const Logger = debug_mod.Logger;
pub const LogLevel = debug_mod.Level;
pub const Tracer = debug_mod.Tracer;
pub const TraceEvent = debug_mod.TraceEvent;
pub const TraceEntry = debug_mod.TraceEntry;
pub const conformance = @import("debug/conformance.zig");

/// Transcode UTF-16 input to owned UTF-8 (`little_endian` selects LE).
/// Used internally for UTF-16 `Input`s; also handy for hosts.
pub const transcodeUtf16ToUtf8 = unicode_mod.transcodeUtf16ToUtf8;
pub const Utf16Error = unicode_mod.Utf16Error;

pub const version = "0.0.1";
pub const package_name = "treesitter";

/// Bundled arithmetic expression language (identifiers, numbers,
/// `+ - * /`, parens). Shared by tests, examples, and benchmarks.
pub const expression_language = language_mod.expression_language;
/// Bundled s-expression language (nested parenthesized lists).
pub const sexp_language = language_mod.sexp_language;
/// Bundled JSON language (objects, arrays, strings, numbers, literals).
pub const json_language = language_mod.json_language;
/// Bundled outline language (indentation-sensitive demo using an
/// external scanner).
pub const outline_language = language_mod.outline_language;
/// Per-parser state for the outline external scanner. Copy
/// `outline_language`, point its scanner payload here, and pass the
/// copy to `setLanguage`.
pub const OutlineScanState = language_mod.outline_scanner.ScanState;
/// Compatibility shim: `test_grammar.test_language` is now
/// `expression_language`. Prefer the canonical name in new code.
pub const test_grammar = struct {
    pub const test_language = language_mod.expression_language;
};
pub const parser_stack = @import("parser/stack.zig");
pub const lexer_types = @import("lexer/lexer.zig");
pub const unicode_types = @import("unicode/unicode.zig");
pub const memory_types = @import("memory/memory.zig");
pub const repository = "muhammad-fiaz/tree-sitter.zig";
pub const license = "MIT";
pub const copyright = "Copyright (c) 2026 Muhammad Fiaz";
pub const abi_version = language_mod.metadata.current_abi_version;

pub fn applyEdit(tree: *Tree, edit: InputEdit) void {
    tree_mod.edit_mod.applyEdit(tree, edit);
}

pub fn getChangedRanges(gpa: std.mem.Allocator, old_tree: *const Tree, new_tree: *const Tree) ![]Range {
    return tree_mod.changed_ranges_mod.changedRanges(gpa, old_tree, new_tree);
}

pub fn freeChangedRanges(gpa: std.mem.Allocator, ranges: []Range) void {
    tree_mod.changed_ranges_mod.freeRanges(gpa, ranges);
}

test "public api: parse simple expression" {
    const tg = expression_language;
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(tg);
    var tree = try parser.parseString("1 + 2");
    defer tree.deinit();
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
    try std.testing.expect(!tree.hasError());
    try std.testing.expectEqual(@as(u32, 0), root.startByte());
    try std.testing.expectEqual(@as(u32, 5), root.endByte());
}

test "public api: nodes and cursor" {
    const tg = expression_language;
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(tg);
    var tree = try parser.parseString("a * (b + 3)");
    defer tree.deinit();
    const root = tree.rootNode();
    try std.testing.expect(root.isNamed());
    try std.testing.expectEqual(@as(u32, 1), root.childCount());
    var cursor = TreeCursor.init(std.testing.allocator, root);
    defer cursor.deinit();
    try std.testing.expect(cursor.gotoFirstChild());
    try std.testing.expectEqualStrings("expression", cursor.currentNode().nodeType());
    try std.testing.expectEqual(@as(u32, 1), cursor.depth());
    try std.testing.expect(cursor.gotoParent());
    try std.testing.expectEqual(@as(u32, 0), cursor.depth());
}

test "public api: queries" {
    const tg = expression_language;
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(tg);
    var tree = try parser.parseString("1 + abc");
    defer tree.deinit();
    var query = try Query.compile(std.testing.allocator, tg, "(identifier) @id");
    defer query.deinit();
    try std.testing.expectEqual(@as(usize, 1), query.patternCount());
    var qcursor = QueryCursor.init(std.testing.allocator);
    defer qcursor.deinit();
    try qcursor.execute(tg, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 1), qcursor.matchCount());
    const m = qcursor.nextMatch().?;
    try std.testing.expectEqual(@as(usize, 1), m.captures.len);
    try std.testing.expectEqualStrings("abc", m.captures[0].node.text());
}

test "public api: incremental edit and changed ranges" {
    const tg = expression_language;
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(tg);
    var old_tree = try parser.parseString("1 + 2");
    defer old_tree.deinit();
    const edit = InputEdit{
        .start_byte = 5,
        .old_end_byte = 5,
        .new_end_byte = 6,
        .start_point = .{ .row = 0, .column = 5 },
        .old_end_point = .{ .row = 0, .column = 5 },
        .new_end_point = .{ .row = 0, .column = 6 },
    };
    var new_tree = try parser.parse(&old_tree, edit, "1 + 22");
    defer new_tree.deinit();
    try std.testing.expect(!new_tree.hasError());
    const ranges = try getChangedRanges(std.testing.allocator, &old_tree, &new_tree);
    defer freeChangedRanges(std.testing.allocator, ranges);
    try std.testing.expect(ranges.len > 0);
}

test "public api: metadata" {
    try std.testing.expectEqualStrings("0.0.1", version);
    try std.testing.expectEqualStrings("treesitter", package_name);
    try std.testing.expectEqualStrings("muhammad-fiaz/tree-sitter.zig", repository);
    try std.testing.expectEqualStrings("MIT", license);
    try std.testing.expectEqualStrings("Copyright (c) 2026 Muhammad Fiaz", copyright);
}

test "public api: sexp serializer" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(expression_language);
    var tree = try parser.parseString("1 + 2");
    defer tree.deinit();
    const text = try sexp_mod.toSexp(std.testing.allocator, tree.rootNode());
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings(
        "(program (expression (expression (term (factor (number \"1\")))) \"+\" (term (factor (number \"2\")))))",
        text,
    );
}
