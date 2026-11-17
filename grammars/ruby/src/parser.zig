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
pub const sym_def: u16 = 1;
pub const sym_class: u16 = 2;
pub const sym_return: u16 = 3;
pub const sym_nil: u16 = 4;
pub const sym_true: u16 = 5;
pub const sym_false: u16 = 6;
pub const sym_kw_end: u16 = 7;
pub const sym_comma: u16 = 8;
pub const sym_lparen: u16 = 9;
pub const sym_rparen: u16 = 10;
pub const sym_eq: u16 = 11;
pub const sym_plus: u16 = 12;
pub const sym_minus: u16 = 13;
pub const sym_identifier: u16 = 14;
pub const sym_integer: u16 = 15;
pub const sym_string: u16 = 16;
pub const sym_whitespace: u16 = 17;
pub const sym_comment: u16 = 18;
pub const sym_program: u16 = 19;
pub const sym_statements: u16 = 20;
pub const sym_statement: u16 = 21;
pub const sym_method_definition: u16 = 22;
pub const sym_parameters: u16 = 23;
pub const sym_class_definition: u16 = 24;
pub const sym_return_statement: u16 = 25;
pub const sym_expression_statement: u16 = 26;
pub const sym_expression: u16 = 27;
pub const sym_binary_op: u16 = 28;
pub const sym_primary: u16 = 29;
pub const sym_ERROR: u16 = 30;

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

    if (start < source.len and source[start] == '#') {
        var i = start + 1;
        while (i < source.len and source[i] != '\n') : (i += 1) {}
        return i - start;
    }
    return null;
}

const symbol_table: []const symbols_mod.SymbolInfo = &.{
    .{ .id = sym_end, .name = "end", .kind = .end, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_def, .name = "def", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_class, .name = "class", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_return, .name = "return", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_nil, .name = "nil", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_true, .name = "true", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_false, .name = "false", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_kw_end, .name = "end", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_comma, .name = ",", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lparen, .name = "(", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rparen, .name = ")", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_eq, .name = "=", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_plus, .name = "+", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_minus, .name = "-", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_integer, .name = "integer", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_string, .name = "string", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = true, .named = false, .extra = true } },
    .{ .id = sym_comment, .name = "comment", .kind = .terminal, .metadata = .{ .visible = true, .named = true, .extra = true } },
    .{ .id = sym_program, .name = "program", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statements, .name = "statements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statement, .name = "statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_method_definition, .name = "method_definition", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_parameters, .name = "parameters", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_class_definition, .name = "class_definition", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_return_statement, .name = "return_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression_statement, .name = "expression_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression, .name = "expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_binary_op, .name = "binary_op", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_primary, .name = "primary", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_ERROR, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_def, .match = matchKeyword("def") },
    .{ .symbol = sym_class, .match = matchKeyword("class") },
    .{ .symbol = sym_return, .match = matchKeyword("return") },
    .{ .symbol = sym_nil, .match = matchKeyword("nil") },
    .{ .symbol = sym_true, .match = matchKeyword("true") },
    .{ .symbol = sym_false, .match = matchKeyword("false") },
    .{ .symbol = sym_kw_end, .match = matchKeyword("end") },
    .{ .symbol = sym_comma, .match = language_mod.matchChar(',') },
    .{ .symbol = sym_lparen, .match = language_mod.matchChar('(') },
    .{ .symbol = sym_rparen, .match = language_mod.matchChar(')') },
    .{ .symbol = sym_eq, .match = language_mod.matchChar('=') },
    .{ .symbol = sym_plus, .match = language_mod.matchChar('+') },
    .{ .symbol = sym_minus, .match = language_mod.matchChar('-') },
    .{ .symbol = sym_identifier, .match = matchIdentifier },
    .{ .symbol = sym_integer, .match = matchNumber },
    .{ .symbol = sym_string, .match = matchString },
    .{ .symbol = sym_whitespace, .match = language_mod.matchWhitespace },
    .{ .symbol = sym_comment, .match = matchComment },
};

const extra_symbols: []const u16 = &.{ sym_whitespace, sym_comment };

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_op, .state = 18 },
    .{ .symbol = sym_class_definition, .state = 14 },
    .{ .symbol = sym_expression, .state = 17 },
    .{ .symbol = sym_expression_statement, .state = 16 },
    .{ .symbol = sym_method_definition, .state = 13 },
    .{ .symbol = sym_primary, .state = 19 },
    .{ .symbol = sym_program, .state = 10 },
    .{ .symbol = sym_return_statement, .state = 15 },
    .{ .symbol = sym_statement, .state = 12 },
    .{ .symbol = sym_statements, .state = 11 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 20 } },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 21 } },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s3_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_op, .state = 18 },
    .{ .symbol = sym_expression, .state = 22 },
    .{ .symbol = sym_primary, .state = 19 },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 24 } } },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 25 } } },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 26 } } },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 21 } } },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 22 } } },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 23 } } },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_program, .child_count = 1, .production_id = 1 } } },
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s11_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_op, .state = 18 },
    .{ .symbol = sym_class_definition, .state = 14 },
    .{ .symbol = sym_expression, .state = 17 },
    .{ .symbol = sym_expression_statement, .state = 16 },
    .{ .symbol = sym_method_definition, .state = 13 },
    .{ .symbol = sym_primary, .state = 19 },
    .{ .symbol = sym_return_statement, .state = 15 },
    .{ .symbol = sym_statement, .state = 23 },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 5 } } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 6 } } },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 7 } } },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 25 } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_plus, .action = .{ .shift = 24 } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 16 } } },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 17 } } },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 18 } } },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 26 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s20_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_op, .state = 18 },
    .{ .symbol = sym_class_definition, .state = 14 },
    .{ .symbol = sym_expression, .state = 17 },
    .{ .symbol = sym_expression_statement, .state = 16 },
    .{ .symbol = sym_method_definition, .state = 13 },
    .{ .symbol = sym_primary, .state = 19 },
    .{ .symbol = sym_return_statement, .state = 15 },
    .{ .symbol = sym_statement, .state = 12 },
    .{ .symbol = sym_statements, .state = 27 },
};
const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s21_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_op, .state = 18 },
    .{ .symbol = sym_class_definition, .state = 14 },
    .{ .symbol = sym_expression, .state = 17 },
    .{ .symbol = sym_expression_statement, .state = 16 },
    .{ .symbol = sym_method_definition, .state = 13 },
    .{ .symbol = sym_primary, .state = 19 },
    .{ .symbol = sym_return_statement, .state = 15 },
    .{ .symbol = sym_statement, .state = 12 },
    .{ .symbol = sym_statements, .state = 28 },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 25 } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_plus, .action = .{ .shift = 24 } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 14 } } },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s24_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary, .state = 29 },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s25_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary, .state = 30 },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 32 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 31 } },
};
const s26_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_parameters, .state = 33 },
};
const s27_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_kw_end, .action = .{ .shift = 34 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s27_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_op, .state = 18 },
    .{ .symbol = sym_class_definition, .state = 14 },
    .{ .symbol = sym_expression, .state = 17 },
    .{ .symbol = sym_expression_statement, .state = 16 },
    .{ .symbol = sym_method_definition, .state = 13 },
    .{ .symbol = sym_primary, .state = 19 },
    .{ .symbol = sym_return_statement, .state = 15 },
    .{ .symbol = sym_statement, .state = 23 },
};
const s28_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_kw_end, .action = .{ .shift = 35 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s28_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_op, .state = 18 },
    .{ .symbol = sym_class_definition, .state = 14 },
    .{ .symbol = sym_expression, .state = 17 },
    .{ .symbol = sym_expression_statement, .state = 16 },
    .{ .symbol = sym_method_definition, .state = 13 },
    .{ .symbol = sym_primary, .state = 19 },
    .{ .symbol = sym_return_statement, .state = 15 },
    .{ .symbol = sym_statement, .state = 23 },
};
const s29_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 19 } } },
};
const s30_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_binary_op, .child_count = 3, .production_id = 20 } } },
};
const s31_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s31_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_op, .state = 18 },
    .{ .symbol = sym_class_definition, .state = 14 },
    .{ .symbol = sym_expression, .state = 17 },
    .{ .symbol = sym_expression_statement, .state = 16 },
    .{ .symbol = sym_method_definition, .state = 13 },
    .{ .symbol = sym_primary, .state = 19 },
    .{ .symbol = sym_return_statement, .state = 15 },
    .{ .symbol = sym_statement, .state = 12 },
    .{ .symbol = sym_statements, .state = 36 },
};
const s32_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameters, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameters, .child_count = 1, .production_id = 11 } } },
};
const s33_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 37 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 38 } },
};
const s34_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 4, .production_id = 10 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 4, .production_id = 10 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 4, .production_id = 10 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 4, .production_id = 10 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 4, .production_id = 10 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 4, .production_id = 10 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 4, .production_id = 10 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 4, .production_id = 10 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 4, .production_id = 10 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 4, .production_id = 10 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 4, .production_id = 10 } } },
};
const s35_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_class_definition, .child_count = 4, .production_id = 13 } } },
};
const s36_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_kw_end, .action = .{ .shift = 39 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s36_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_op, .state = 18 },
    .{ .symbol = sym_class_definition, .state = 14 },
    .{ .symbol = sym_expression, .state = 17 },
    .{ .symbol = sym_expression_statement, .state = 16 },
    .{ .symbol = sym_method_definition, .state = 13 },
    .{ .symbol = sym_primary, .state = 19 },
    .{ .symbol = sym_return_statement, .state = 15 },
    .{ .symbol = sym_statement, .state = 23 },
};
const s37_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 40 } },
};
const s38_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s38_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_op, .state = 18 },
    .{ .symbol = sym_class_definition, .state = 14 },
    .{ .symbol = sym_expression, .state = 17 },
    .{ .symbol = sym_expression_statement, .state = 16 },
    .{ .symbol = sym_method_definition, .state = 13 },
    .{ .symbol = sym_primary, .state = 19 },
    .{ .symbol = sym_return_statement, .state = 15 },
    .{ .symbol = sym_statement, .state = 12 },
    .{ .symbol = sym_statements, .state = 41 },
};
const s39_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 6, .production_id = 9 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 6, .production_id = 9 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 6, .production_id = 9 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 6, .production_id = 9 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 6, .production_id = 9 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 6, .production_id = 9 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 6, .production_id = 9 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 6, .production_id = 9 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 6, .production_id = 9 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 6, .production_id = 9 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 6, .production_id = 9 } } },
};
const s40_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameters, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameters, .child_count = 3, .production_id = 12 } } },
};
const s41_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_def, .action = .{ .shift = 1 } },
    .{ .symbol = sym_false, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_integer, .action = .{ .shift = 8 } },
    .{ .symbol = sym_kw_end, .action = .{ .shift = 42 } },
    .{ .symbol = sym_nil, .action = .{ .shift = 4 } },
    .{ .symbol = sym_return, .action = .{ .shift = 3 } },
    .{ .symbol = sym_string, .action = .{ .shift = 9 } },
    .{ .symbol = sym_true, .action = .{ .shift = 5 } },
};
const s41_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_op, .state = 18 },
    .{ .symbol = sym_class_definition, .state = 14 },
    .{ .symbol = sym_expression, .state = 17 },
    .{ .symbol = sym_expression_statement, .state = 16 },
    .{ .symbol = sym_method_definition, .state = 13 },
    .{ .symbol = sym_primary, .state = 19 },
    .{ .symbol = sym_return_statement, .state = 15 },
    .{ .symbol = sym_statement, .state = 23 },
};
const s42_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 7, .production_id = 8 } } },
    .{ .symbol = sym_def, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 7, .production_id = 8 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 7, .production_id = 8 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 7, .production_id = 8 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 7, .production_id = 8 } } },
    .{ .symbol = sym_integer, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 7, .production_id = 8 } } },
    .{ .symbol = sym_kw_end, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 7, .production_id = 8 } } },
    .{ .symbol = sym_nil, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 7, .production_id = 8 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 7, .production_id = 8 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 7, .production_id = 8 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_method_definition, .child_count = 7, .production_id = 8 } } },
};

const parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = s0_actions, .gotos = s0_gotos }, // 0
    .{ .actions = s1_actions }, // 1
    .{ .actions = s2_actions }, // 2
    .{ .actions = s3_actions, .gotos = s3_gotos }, // 3
    .{ .actions = s4_actions }, // 4
    .{ .actions = s5_actions }, // 5
    .{ .actions = s6_actions }, // 6
    .{ .actions = s7_actions }, // 7
    .{ .actions = s8_actions }, // 8
    .{ .actions = s9_actions }, // 9
    .{ .actions = s10_actions }, // 10
    .{ .actions = s11_actions, .gotos = s11_gotos }, // 11
    .{ .actions = s12_actions }, // 12
    .{ .actions = s13_actions }, // 13
    .{ .actions = s14_actions }, // 14
    .{ .actions = s15_actions }, // 15
    .{ .actions = s16_actions }, // 16
    .{ .actions = s17_actions }, // 17
    .{ .actions = s18_actions }, // 18
    .{ .actions = s19_actions }, // 19
    .{ .actions = s20_actions, .gotos = s20_gotos }, // 20
    .{ .actions = s21_actions, .gotos = s21_gotos }, // 21
    .{ .actions = s22_actions }, // 22
    .{ .actions = s23_actions }, // 23
    .{ .actions = s24_actions, .gotos = s24_gotos }, // 24
    .{ .actions = s25_actions, .gotos = s25_gotos }, // 25
    .{ .actions = s26_actions, .gotos = s26_gotos }, // 26
    .{ .actions = s27_actions, .gotos = s27_gotos }, // 27
    .{ .actions = s28_actions, .gotos = s28_gotos }, // 28
    .{ .actions = s29_actions }, // 29
    .{ .actions = s30_actions }, // 30
    .{ .actions = s31_actions, .gotos = s31_gotos }, // 31
    .{ .actions = s32_actions }, // 32
    .{ .actions = s33_actions }, // 33
    .{ .actions = s34_actions }, // 34
    .{ .actions = s35_actions }, // 35
    .{ .actions = s36_actions, .gotos = s36_gotos }, // 36
    .{ .actions = s37_actions }, // 37
    .{ .actions = s38_actions, .gotos = s38_gotos }, // 38
    .{ .actions = s39_actions }, // 39
    .{ .actions = s40_actions }, // 40
    .{ .actions = s41_actions, .gotos = s41_gotos }, // 41
    .{ .actions = s42_actions }, // 42
};

const field_names: []const []const u8 = &.{ "name", "parameters", "body", "argument", "left", "right" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 8, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "parameters", .child_index = 3 }, .{ .name = "body", .child_index = 5 } } },
    .{ .production_id = 9, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 4 } } },
    .{ .production_id = 10, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 2 } } },
    .{ .production_id = 13, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 2 } } },
    .{ .production_id = 14, .bindings = &.{.{ .name = "argument", .child_index = 1 }} },
    .{ .production_id = 19, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 20, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
};

pub const language: Language = .{
    .metadata = .{
        .name = "ruby",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.3",
        .symbol_count = 31,
        .state_count = 43,
        .field_count = 6,
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

test "parser: ruby table verification" {
    try std.testing.expectEqualStrings("ruby", language.metadata.name);
    try std.testing.expect(language.metadata.symbol_count > 0);
    try std.testing.expect(language.table.stateCount() > 0);
}

test "parser: ruby node types verification" {
    var nt = try treesitter.NodeTypes.parseJSON(std.testing.allocator, node_types_json);
    defer nt.deinit();
    try std.testing.expect(nt.findType("program") != null);
}

test "parser: ruby grammar json verification" {
    var dsl = treesitter.DSLParser.init(std.testing.allocator);
    var g = try dsl.parseJSON(grammar_json);
    defer g.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("ruby", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}

test "parser: ruby genuine program parsing 1" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("def add(a, b) return a + b end");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
}

test "parser: ruby genuine program parsing 2" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("class Person def greet() return 1 end end");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
}
