const std = @import("std");
const treesitter = @import("treesitter");
const language_mod = treesitter.language_mod;
const symbols_mod = language_mod.symbols;
const tables_mod = language_mod.tables;
const fields_mod = language_mod.fields;
const metadata_mod = language_mod.metadata;
const Language = treesitter.Language;
const TokenMatcher = treesitter.TokenMatcher;

pub const sym_end: u16 = 0;
pub const sym_lbrace: u16 = 1;
pub const sym_rbrace: u16 = 2;
pub const sym_colon: u16 = 3;
pub const sym_semi: u16 = 4;
pub const sym_comma: u16 = 5;
pub const sym_dot: u16 = 6;
pub const sym_hash: u16 = 7;
pub const sym_identifier: u16 = 8;
pub const sym_number: u16 = 9;
pub const sym_whitespace: u16 = 10;
pub const sym_comment: u16 = 11;
pub const sym_stylesheet: u16 = 12;
pub const sym_rulesets: u16 = 13;
pub const sym_ruleset: u16 = 14;
pub const sym_selectors: u16 = 15;
pub const sym_selector: u16 = 16;
pub const sym_tag_selector: u16 = 17;
pub const sym_class_selector: u16 = 18;
pub const sym_id_selector: u16 = 19;
pub const sym_declaration_list: u16 = 20;
pub const sym_declaration: u16 = 21;
pub const sym_property_value: u16 = 22;
pub const sym_ERROR: u16 = 23;

fn matchKeyword(comptime word: []const u8) language_mod.TokenMatchFn {
    return struct {
        fn match(source: []const u8, start: usize) ?usize {
            if (start + word.len > source.len) return null;
            if (!std.mem.eql(u8, source[start .. start + word.len], word)) return null;
            if (start + word.len < source.len) {
                const next_c = source[start + word.len];
                if (std.ascii.isAlphanumeric(next_c) or next_c == '_') return null;
            }
            return word.len;
        }
    }.match;
}

fn matchLiteral(comptime lit: []const u8) language_mod.TokenMatchFn {
    return struct {
        fn match(source: []const u8, start: usize) ?usize {
            if (start + lit.len > source.len) return null;
            if (!std.mem.eql(u8, source[start .. start + lit.len], lit)) return null;
            return lit.len;
        }
    }.match;
}

fn matchIdentifier(source: []const u8, start: usize) ?usize {
    if (start >= source.len) return null;
    const first = source[start];
    if (!std.ascii.isAlphabetic(first) and first != '_') return null;
    var i = start + 1;
    while (i < source.len and (std.ascii.isAlphanumeric(source[i]) or source[i] == '_')) : (i += 1) {}
    return i - start;
}

fn matchNumber(source: []const u8, start: usize) ?usize {
    if (start >= source.len or !std.ascii.isDigit(source[start])) return null;
    var i = start + 1;
    while (i < source.len and (std.ascii.isDigit(source[i]) or source[i] == '.')) : (i += 1) {}
    return i - start;
}

fn matchString(source: []const u8, start: usize) ?usize {
    if (start >= source.len) return null;
    const quote = source[start];
    if (quote != '"' and quote != '\'') return null;
    var i = start + 1;
    while (i < source.len) {
        if (source[i] == '\\') {
            i += 2;
        } else if (source[i] == quote) {
            return i + 1 - start;
        } else {
            i += 1;
        }
    }
    return null;
}

fn matchComment(source: []const u8, start: usize) ?usize {
    if (start + 1 < source.len and source[start] == '/' and source[start + 1] == '/') {
        var i = start + 2;
        while (i < source.len and source[i] != '\n') : (i += 1) {}
        return i - start;
    }
    if (start + 1 < source.len and source[start] == '/' and source[start + 1] == '*') {
        var i = start + 2;
        while (i + 1 < source.len) : (i += 1) {
            if (source[i] == '*' and source[i + 1] == '/') return i + 2 - start;
        }
        return source.len - start;
    }
    return null;
}

const symbol_table: []const symbols_mod.SymbolInfo = &.{
    .{ .id = sym_end, .name = "end", .kind = .end, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lbrace, .name = "{", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rbrace, .name = "}", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_colon, .name = ":", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_semi, .name = ";", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_comma, .name = ",", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_dot, .name = ".", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_hash, .name = "#", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_number, .name = "number", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = true, .named = false, .extra = true } },
    .{ .id = sym_comment, .name = "comment", .kind = .terminal, .metadata = .{ .visible = true, .named = true, .extra = true } },
    .{ .id = sym_stylesheet, .name = "stylesheet", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_rulesets, .name = "rulesets", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_ruleset, .name = "ruleset", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_selectors, .name = "selectors", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_selector, .name = "selector", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_tag_selector, .name = "tag_selector", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_class_selector, .name = "class_selector", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_id_selector, .name = "id_selector", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declaration_list, .name = "declaration_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declaration, .name = "declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_property_value, .name = "property_value", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_ERROR, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_lbrace, .match = language_mod.matchChar('{') },
    .{ .symbol = sym_rbrace, .match = language_mod.matchChar('}') },
    .{ .symbol = sym_colon, .match = language_mod.matchChar(':') },
    .{ .symbol = sym_semi, .match = language_mod.matchChar(';') },
    .{ .symbol = sym_comma, .match = language_mod.matchChar(',') },
    .{ .symbol = sym_dot, .match = language_mod.matchChar('.') },
    .{ .symbol = sym_hash, .match = language_mod.matchChar('#') },
    .{ .symbol = sym_identifier, .match = matchIdentifier },
    .{ .symbol = sym_number, .match = matchNumber },
    .{ .symbol = sym_whitespace, .match = language_mod.matchWhitespace },
    .{ .symbol = sym_comment, .match = matchComment },
};

const extra_symbols: []const u16 = &.{ sym_whitespace, sym_comment };

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .shift = 1 } },
    .{ .symbol = sym_hash, .action = .{ .shift = 2 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 3 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_selector, .state = 10 },
    .{ .symbol = sym_id_selector, .state = 11 },
    .{ .symbol = sym_ruleset, .state = 6 },
    .{ .symbol = sym_rulesets, .state = 5 },
    .{ .symbol = sym_selector, .state = 8 },
    .{ .symbol = sym_selectors, .state = 7 },
    .{ .symbol = sym_stylesheet, .state = 4 },
    .{ .symbol = sym_tag_selector, .state = 9 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 12 } },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_tag_selector, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_tag_selector, .child_count = 1, .production_id = 11 } } },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .shift = 1 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_stylesheet, .child_count = 1, .production_id = 1 } } },
    .{ .symbol = sym_hash, .action = .{ .shift = 2 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 3 } },
};
const s5_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_selector, .state = 10 },
    .{ .symbol = sym_id_selector, .state = 11 },
    .{ .symbol = sym_ruleset, .state = 14 },
    .{ .symbol = sym_selector, .state = 8 },
    .{ .symbol = sym_selectors, .state = 7 },
    .{ .symbol = sym_tag_selector, .state = 9 },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_rulesets, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_rulesets, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_hash, .action = .{ .reduce = .{ .symbol = sym_rulesets, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_rulesets, .child_count = 1, .production_id = 2 } } },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 16 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 15 } },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_selectors, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_selectors, .child_count = 1, .production_id = 6 } } },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_selector, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_selector, .child_count = 1, .production_id = 8 } } },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_selector, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_selector, .child_count = 1, .production_id = 9 } } },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_selector, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_selector, .child_count = 1, .production_id = 10 } } },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_class_selector, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_class_selector, .child_count = 2, .production_id = 12 } } },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_id_selector, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_id_selector, .child_count = 2, .production_id = 13 } } },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_rulesets, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_rulesets, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_hash, .action = .{ .reduce = .{ .symbol = sym_rulesets, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_rulesets, .child_count = 2, .production_id = 3 } } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 18 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 17 } },
};
const s15_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_declaration, .state = 20 },
    .{ .symbol = sym_declaration_list, .state = 19 },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .shift = 1 } },
    .{ .symbol = sym_hash, .action = .{ .shift = 2 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 3 } },
};
const s16_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_selector, .state = 10 },
    .{ .symbol = sym_id_selector, .state = 11 },
    .{ .symbol = sym_selector, .state = 21 },
    .{ .symbol = sym_tag_selector, .state = 9 },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_ruleset, .child_count = 3, .production_id = 5 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_ruleset, .child_count = 3, .production_id = 5 } } },
    .{ .symbol = sym_hash, .action = .{ .reduce = .{ .symbol = sym_ruleset, .child_count = 3, .production_id = 5 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_ruleset, .child_count = 3, .production_id = 5 } } },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .shift = 22 } },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 18 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 23 } },
};
const s19_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_declaration, .state = 24 },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declaration_list, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_declaration_list, .child_count = 1, .production_id = 14 } } },
};
const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_selectors, .child_count = 3, .production_id = 7 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_selectors, .child_count = 3, .production_id = 7 } } },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 25 } },
    .{ .symbol = sym_number, .action = .{ .shift = 26 } },
};
const s22_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_property_value, .state = 27 },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_ruleset, .child_count = 4, .production_id = 4 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_ruleset, .child_count = 4, .production_id = 4 } } },
    .{ .symbol = sym_hash, .action = .{ .reduce = .{ .symbol = sym_ruleset, .child_count = 4, .production_id = 4 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_ruleset, .child_count = 4, .production_id = 4 } } },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declaration_list, .child_count = 2, .production_id = 15 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_declaration_list, .child_count = 2, .production_id = 15 } } },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_property_value, .child_count = 1, .production_id = 17 } } },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_property_value, .child_count = 1, .production_id = 18 } } },
};
const s27_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 28 } },
};
const s28_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 4, .production_id = 16 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 4, .production_id = 16 } } },
};

const parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = s0_actions, .gotos = s0_gotos }, // 0
    .{ .actions = s1_actions }, // 1
    .{ .actions = s2_actions }, // 2
    .{ .actions = s3_actions }, // 3
    .{ .actions = s4_actions }, // 4
    .{ .actions = s5_actions, .gotos = s5_gotos }, // 5
    .{ .actions = s6_actions }, // 6
    .{ .actions = s7_actions }, // 7
    .{ .actions = s8_actions }, // 8
    .{ .actions = s9_actions }, // 9
    .{ .actions = s10_actions }, // 10
    .{ .actions = s11_actions }, // 11
    .{ .actions = s12_actions }, // 12
    .{ .actions = s13_actions }, // 13
    .{ .actions = s14_actions }, // 14
    .{ .actions = s15_actions, .gotos = s15_gotos }, // 15
    .{ .actions = s16_actions, .gotos = s16_gotos }, // 16
    .{ .actions = s17_actions }, // 17
    .{ .actions = s18_actions }, // 18
    .{ .actions = s19_actions, .gotos = s19_gotos }, // 19
    .{ .actions = s20_actions }, // 20
    .{ .actions = s21_actions }, // 21
    .{ .actions = s22_actions, .gotos = s22_gotos }, // 22
    .{ .actions = s23_actions }, // 23
    .{ .actions = s24_actions }, // 24
    .{ .actions = s25_actions }, // 25
    .{ .actions = s26_actions }, // 26
    .{ .actions = s27_actions }, // 27
    .{ .actions = s28_actions }, // 28
};

const field_names: []const []const u8 = &.{ "name", "value" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 16, .bindings = &.{ .{ .name = "name", .child_index = 0 }, .{ .name = "value", .child_index = 2 } } },
};

pub const language: Language = .{
    .metadata = .{
        .name = "css",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.3",
        .symbol_count = 24,
        .state_count = 29,
        .field_count = 2,
    },
    .symbols = symbol_table,
    .token_matchers = token_matchers,
    .extra_symbols = extra_symbols,
    .table = .{
        .states = parse_states,
        .start_state = 0,
        .end_symbol = sym_end,
        .error_symbol = sym_ERROR,
    },
    .fields = .{
        .names = field_names,
        .productions = field_productions,
    },
    .external_scanner = null,
};

pub fn getLanguage() Language {
    return language;
}

pub const scanner = @import("scanner.zig");
pub const grammar_json = @embedFile("grammar.json");
pub const node_types_json = @embedFile("node-types.json");

test "parser: css table verification" {
    try std.testing.expectEqualStrings("css", language.metadata.name);
    try std.testing.expect(language.metadata.symbol_count > 0);
    try std.testing.expect(language.table.stateCount() > 0);
}

test "parser: css node types verification" {
    var nt = try treesitter.NodeTypes.parseJSON(std.testing.allocator, node_types_json);
    defer nt.deinit();
    try std.testing.expect(nt.findType("stylesheet") != null);
}

test "parser: css grammar json verification" {
    var dsl = treesitter.DSLParser.init(std.testing.allocator);
    var g = try dsl.parseJSON(grammar_json);
    defer g.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("css", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}

test "parser: css genuine program parsing 1" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("body { color: red; margin: 0; }");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("stylesheet", root.nodeType());
}

test "parser: css genuine program parsing 2" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("#header, .nav { display: block; }");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("stylesheet", root.nodeType());
}
