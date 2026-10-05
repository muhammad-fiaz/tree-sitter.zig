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
pub const SymbolType = language_mod.SymbolType;
pub const LookaheadIterator = language_mod.LookaheadIterator;

pub const ParserState = parser_mod.ParseState;
pub const ParseState = parser_mod.ParseState;
pub const ParseOptions = parser_mod.ParseOptions;

pub const Query = query_mod.Query;
pub const QueryError = query_mod.QueryError;
pub const QueryCursor = query_mod.QueryCursor;
pub const QueryCursorOptions = query_mod.query_cursor.QueryCursorOptions;
pub const Match = query_mod.Match;
pub const Capture = query_mod.Capture;

pub const Input = input_mod.Input;
pub const InputEncoding = input_mod.InputEncoding;
pub const Encoding = input_mod.Encoding;
pub const MemorySource = input_mod.MemorySource;
pub const ReaderSource = input_mod.ReaderSource;
pub const Source = input_mod.Source;
pub const StreamBuffer = input_mod.StreamBuffer;
pub const Io = std.Io;
pub const File = std.Io.File;
pub const Reader = std.Io.Reader;
pub const Writer = std.Io.Writer;

pub const Logger = debug_mod.Logger;
pub const LogLevel = debug_mod.Level;
/// Null logger: silently discards all log events.
/// Ownership: stateless — no allocation, no lifetime constraint.
pub const nullLogger = debug_mod.nullLogger;
pub const Tracer = debug_mod.Tracer;
pub const TraceEvent = debug_mod.TraceEvent;
pub const TraceEntry = debug_mod.TraceEntry;
pub const conformance = @import("debug/conformance.zig");

/// Transcode UTF-16 input to owned UTF-8 (`little_endian` selects LE).
/// Used internally for UTF-16 `Input`s; also handy for hosts.
pub const transcodeUtf16ToUtf8 = unicode_mod.transcodeUtf16ToUtf8;
pub const Utf16Error = unicode_mod.Utf16Error;

pub const version = "0.0.2";
pub const package_name = "treesitter";

/// Bundled arithmetic expression language (identifiers, numbers,
/// `+ - * /`, parens). Shared by tests, examples, and benchmarks.
/// Ownership: static, immutable — safe to share across threads.
pub const expressionLanguage = language_mod.expression_language;
/// Bundled s-expression language (nested parenthesized lists).
/// Ownership: static, immutable — safe to share across threads.
pub const sexpLanguage = language_mod.sexp_language;
/// Bundled JSON language (objects, arrays, strings, numbers, literals).
/// Ownership: static, immutable — safe to share across threads.
pub const jsonLanguage = language_mod.json_language;
/// Bundled outline language (indentation-sensitive demo using an
/// external scanner). The external scanner payload field must be
/// pointed at a caller-owned `OutlineScanState` before parsing.
/// Ownership: copy the `Language` value; point its scanner payload at
/// a caller-owned `OutlineScanState`; caller owns the state.
pub const outlineLanguage = language_mod.outline_language;
/// Per-parser state for the outline external scanner. Copy
/// `outlineLanguage`, point its scanner payload here, and pass the
/// copy to `setLanguage`.
/// Ownership: exclusively owned by the caller; not shared between parsers.
pub const OutlineScanState = language_mod.outline_scanner.ScanState;
pub const parserStack = @import("parser/stack.zig");
pub const lexerTypes = @import("lexer/lexer.zig");
pub const unicodeTypes = @import("unicode/unicode.zig");
pub const memoryTypes = @import("memory/memory.zig");
pub const repository = "muhammad-fiaz/tree-sitter.zig";
pub const license = "MIT";
pub const copyright = "Copyright (c) 2026 Muhammad Fiaz";
pub const abiVersion = language_mod.metadata.currentAbiVersion;
pub const currentAbiVersion = language_mod.metadata.currentAbiVersion;
pub const abiVersionMin = language_mod.metadata.abiVersionMin;
pub const abiVersionMax = language_mod.metadata.abiVersionMax;

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
    const tg = expressionLanguage;
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
    const tg = expressionLanguage;
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
    const tg = expressionLanguage;
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
    const tg = expressionLanguage;
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
    try std.testing.expectEqualStrings("0.0.2", version);
    try std.testing.expectEqualStrings("treesitter", package_name);
    try std.testing.expectEqualStrings("muhammad-fiaz/tree-sitter.zig", repository);
    try std.testing.expectEqualStrings("MIT", license);
    try std.testing.expectEqualStrings("Copyright (c) 2026 Muhammad Fiaz", copyright);
}

test "public api: sexp serializer" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(expressionLanguage);
    var tree = try parser.parseString("1 + 2");
    defer tree.deinit();
    const text = try sexp_mod.toSexp(std.testing.allocator, tree.rootNode());
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings(
        "(program (expression (expression (term (factor (number \"1\")))) \"+\" (term (factor (number \"2\")))))",
        text,
    );
}

test "public api: lookahead iterator" {
    var it = LookaheadIterator.init(expressionLanguage, 0).?;
    var found_tokens: usize = 0;
    while (it.next()) {
        const sym = it.currentSymbol();
        const name = it.currentSymbolName();
        if (sym > 0 and name.len > 0) {
            found_tokens += 1;
        }
    }
    try std.testing.expect(found_tokens > 0);
}

test "public api: node fields, siblings and descendants" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(jsonLanguage);
    var tree = try parser.parseString("{\"key\": 42}");
    defer tree.deinit();

    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
    try std.testing.expectEqual(@as(u32, 1), root.namedChildCount());

    const top_val = root.namedChild(0).?;
    try std.testing.expectEqualStrings("value", top_val.nodeType());

    const obj = top_val.namedChild(0).?;
    try std.testing.expectEqualStrings("object", obj.nodeType());

    const desc_pair = obj.descendantForByteRange(1, 10).?;
    try std.testing.expect(desc_pair.startByte() >= 1);

    var query = try parser.compileQuery("(pair) @p");
    defer query.deinit();
    var qcursor = parser.queryCursor();
    defer qcursor.deinit();
    try qcursor.execute(jsonLanguage, query.patterns(), query.nodes(), query.captureNames(), &tree);
    const m = qcursor.nextMatch().?;
    const pair = m.captures[0].node;
    try std.testing.expectEqualStrings("pair", pair.nodeType());

    const key_node = pair.childByFieldName("key").?;
    try std.testing.expectEqualStrings("string", key_node.nodeType());
    try std.testing.expectEqualStrings("\"key\"", key_node.text());

    const val_node = pair.childByFieldName("value").?;
    try std.testing.expectEqualStrings("value", val_node.nodeType());
    try std.testing.expectEqualStrings("42", val_node.text());

    try std.testing.expect(key_node.nextNamedSibling() != null);
    try std.testing.expectEqualStrings("value", key_node.nextNamedSibling().?.nodeType());
    try std.testing.expect(val_node.prevNamedSibling() != null);
    try std.testing.expectEqualStrings("string", val_node.prevNamedSibling().?.nodeType());

    const desc = obj.descendantForByteRange(key_node.startByte(), key_node.endByte()).?;
    try std.testing.expectEqualStrings("string", desc.nodeType());
}

test "public api: query capture streaming and disabling" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(jsonLanguage);
    var tree = try parser.parseString("{\"first\": 1, \"second\": 2}");
    defer tree.deinit();

    var query = try Query.compile(std.testing.allocator, jsonLanguage, "(pair (string) @key (value) @val)");
    defer query.deinit();

    var cursor = QueryCursor.init(std.testing.allocator);
    defer cursor.deinit();
    try cursor.execute(jsonLanguage, query.patterns(), query.nodes(), query.captureNames(), &tree);

    var count: usize = 0;
    var out_m: Match = undefined;
    var cap_idx: u32 = 0;
    while (cursor.nextCapture(&out_m, &cap_idx)) {
        count += 1;
        try std.testing.expect(cap_idx < out_m.captures.len);
    }
    try std.testing.expectEqual(@as(usize, 4), count); // 2 pairs * 2 captures (@key, @val)

    // Test disabling capture
    query.disableCapture(0);
    try std.testing.expect(query.isCaptureDisabled(0));
}

test "public api: external scanner with outline language" {
    var scanner_state = OutlineScanState.init(std.testing.allocator);
    defer scanner_state.deinit();

    var lang = outlineLanguage;
    lang.external_scanner.?.payload = @ptrCast(&scanner_state);

    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(lang);

    const source =
        \\# Section
        \\  - item 1
        \\  - item 2
    ;
    var tree = try parser.parseString(source);
    defer tree.deinit();

    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
}

test "public api: timeout and cancellation flag" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(expressionLanguage);

    var cancel: usize = 1;
    parser.setCancellationFlag(&cancel);
    try std.testing.expect(parser.cancellationFlag() != null);

    const result = parser.parseString("1 + 2 + 3 + 4 + 5");
    try std.testing.expectError(error.Aborted, result);

    parser.setCancellationFlag(null);
    var ok_tree = try parser.parseString("1 + 2");
    defer ok_tree.deinit();
    try std.testing.expect(!ok_tree.hasError());
}
