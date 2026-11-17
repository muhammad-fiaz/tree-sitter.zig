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
pub const sym_pub: u16 = 1;
pub const sym_fn: u16 = 2;
pub const sym_const: u16 = 3;
pub const sym_var: u16 = 4;
pub const sym_return: u16 = 5;
pub const sym_i32: u16 = 6;
pub const sym_u32: u16 = 7;
pub const sym_void: u16 = 8;
pub const sym_bool: u16 = 9;
pub const sym_builtin_identifier: u16 = 10;
pub const sym_semi: u16 = 11;
pub const sym_colon: u16 = 12;
pub const sym_comma: u16 = 13;
pub const sym_lparen: u16 = 14;
pub const sym_rparen: u16 = 15;
pub const sym_lbrace: u16 = 16;
pub const sym_rbrace: u16 = 17;
pub const sym_eq: u16 = 18;
pub const sym_plus: u16 = 19;
pub const sym_minus: u16 = 20;
pub const sym_identifier: u16 = 21;
pub const sym_number: u16 = 22;
pub const sym_string: u16 = 23;
pub const sym_true: u16 = 24;
pub const sym_false: u16 = 25;
pub const sym_whitespace: u16 = 26;
pub const sym_comment: u16 = 27;
pub const sym_source_file: u16 = 28;
pub const sym_declarations: u16 = 29;
pub const sym_declaration: u16 = 30;
pub const sym_fn_proto: u16 = 31;
pub const sym_param_list: u16 = 32;
pub const sym_param_decl: u16 = 33;
pub const sym_const_declaration: u16 = 34;
pub const sym_type_expr: u16 = 35;
pub const sym_block: u16 = 36;
pub const sym_statements: u16 = 37;
pub const sym_statement: u16 = 38;
pub const sym_return_statement: u16 = 39;
pub const sym_expr_statement: u16 = 40;
pub const sym_expr: u16 = 41;
pub const sym_binary_expr: u16 = 42;
pub const sym_call_expr: u16 = 43;
pub const sym_arg_list: u16 = 44;
pub const sym_primary_expr: u16 = 45;
pub const sym_ERROR: u16 = 46;

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
    .{ .id = sym_pub, .name = "pub", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_fn, .name = "fn", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_const, .name = "const", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_var, .name = "var", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_return, .name = "return", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_i32, .name = "i32", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_u32, .name = "u32", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_void, .name = "void", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_bool, .name = "bool", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_builtin_identifier, .name = "@import", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_semi, .name = ";", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_colon, .name = ":", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_comma, .name = ",", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lparen, .name = "(", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rparen, .name = ")", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lbrace, .name = "{", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rbrace, .name = "}", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_eq, .name = "=", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_plus, .name = "+", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_minus, .name = "-", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_number, .name = "number", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_string, .name = "string", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_true, .name = "true", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_false, .name = "false", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = true, .named = false, .extra = true } },
    .{ .id = sym_comment, .name = "comment", .kind = .terminal, .metadata = .{ .visible = true, .named = true, .extra = true } },
    .{ .id = sym_source_file, .name = "source_file", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declarations, .name = "declarations", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declaration, .name = "declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_fn_proto, .name = "fn_proto", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_param_list, .name = "param_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_param_decl, .name = "param_decl", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_const_declaration, .name = "const_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_type_expr, .name = "type_expr", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_block, .name = "block", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statements, .name = "statements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statement, .name = "statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_return_statement, .name = "return_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expr_statement, .name = "expr_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expr, .name = "expr", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_binary_expr, .name = "binary_expr", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_call_expr, .name = "call_expr", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_arg_list, .name = "arg_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_primary_expr, .name = "primary_expr", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_ERROR, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_pub, .match = matchKeyword("pub") },
    .{ .symbol = sym_fn, .match = matchKeyword("fn") },
    .{ .symbol = sym_const, .match = matchKeyword("const") },
    .{ .symbol = sym_var, .match = matchKeyword("var") },
    .{ .symbol = sym_return, .match = matchKeyword("return") },
    .{ .symbol = sym_i32, .match = matchKeyword("i32") },
    .{ .symbol = sym_u32, .match = matchKeyword("u32") },
    .{ .symbol = sym_void, .match = matchKeyword("void") },
    .{ .symbol = sym_bool, .match = matchKeyword("bool") },
    .{ .symbol = sym_builtin_identifier, .match = matchKeyword("@import") },
    .{ .symbol = sym_semi, .match = language_mod.matchChar(';') },
    .{ .symbol = sym_colon, .match = language_mod.matchChar(':') },
    .{ .symbol = sym_comma, .match = language_mod.matchChar(',') },
    .{ .symbol = sym_lparen, .match = language_mod.matchChar('(') },
    .{ .symbol = sym_rparen, .match = language_mod.matchChar(')') },
    .{ .symbol = sym_lbrace, .match = language_mod.matchChar('{') },
    .{ .symbol = sym_rbrace, .match = language_mod.matchChar('}') },
    .{ .symbol = sym_eq, .match = language_mod.matchChar('=') },
    .{ .symbol = sym_plus, .match = language_mod.matchChar('+') },
    .{ .symbol = sym_minus, .match = language_mod.matchChar('-') },
    .{ .symbol = sym_identifier, .match = matchIdentifier },
    .{ .symbol = sym_number, .match = matchNumber },
    .{ .symbol = sym_string, .match = matchString },
    .{ .symbol = sym_true, .match = matchKeyword("true") },
    .{ .symbol = sym_false, .match = matchKeyword("false") },
    .{ .symbol = sym_whitespace, .match = language_mod.matchWhitespace },
    .{ .symbol = sym_comment, .match = matchComment },
};

const extra_symbols: []const u16 = &.{ sym_whitespace, sym_comment };

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .shift = 3 } },
    .{ .symbol = sym_fn, .action = .{ .shift = 2 } },
    .{ .symbol = sym_pub, .action = .{ .shift = 1 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_const_declaration, .state = 8 },
    .{ .symbol = sym_declaration, .state = 6 },
    .{ .symbol = sym_declarations, .state = 5 },
    .{ .symbol = sym_fn_proto, .state = 7 },
    .{ .symbol = sym_source_file, .state = 4 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .shift = 10 } },
    .{ .symbol = sym_fn, .action = .{ .shift = 9 } },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 11 } },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 12 } },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .shift = 3 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_source_file, .child_count = 1, .production_id = 1 } } },
    .{ .symbol = sym_fn, .action = .{ .shift = 2 } },
    .{ .symbol = sym_pub, .action = .{ .shift = 1 } },
};
const s5_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_const_declaration, .state = 8 },
    .{ .symbol = sym_declaration, .state = 13 },
    .{ .symbol = sym_fn_proto, .state = 7 },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_fn, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_pub, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 14 } },
};
const s7_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_block, .state = 15 },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 16 } },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 17 } },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 18 } },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lparen, .action = .{ .shift = 19 } },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eq, .action = .{ .shift = 20 } },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_fn, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_pub, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .shift = 22 } },
    .{ .symbol = sym_false, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 24 } },
    .{ .symbol = sym_number, .action = .{ .shift = 25 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 23 } },
    .{ .symbol = sym_return, .action = .{ .shift = 21 } },
    .{ .symbol = sym_string, .action = .{ .shift = 26 } },
    .{ .symbol = sym_true, .action = .{ .shift = 27 } },
};
const s14_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expr, .state = 34 },
    .{ .symbol = sym_call_expr, .state = 35 },
    .{ .symbol = sym_expr, .state = 33 },
    .{ .symbol = sym_expr_statement, .state = 32 },
    .{ .symbol = sym_primary_expr, .state = 36 },
    .{ .symbol = sym_return_statement, .state = 31 },
    .{ .symbol = sym_statement, .state = 30 },
    .{ .symbol = sym_statements, .state = 29 },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 4 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 4 } } },
    .{ .symbol = sym_fn, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 4 } } },
    .{ .symbol = sym_pub, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 4 } } },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_fn, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_pub, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lparen, .action = .{ .shift = 37 } },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eq, .action = .{ .shift = 38 } },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 40 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 39 } },
};
const s19_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_param_decl, .state = 42 },
    .{ .symbol = sym_param_list, .state = 41 },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .shift = 22 } },
    .{ .symbol = sym_false, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 24 } },
    .{ .symbol = sym_number, .action = .{ .shift = 25 } },
    .{ .symbol = sym_string, .action = .{ .shift = 26 } },
    .{ .symbol = sym_true, .action = .{ .shift = 27 } },
};
const s20_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expr, .state = 34 },
    .{ .symbol = sym_call_expr, .state = 35 },
    .{ .symbol = sym_expr, .state = 43 },
    .{ .symbol = sym_primary_expr, .state = 36 },
};
const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .shift = 22 } },
    .{ .symbol = sym_false, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 24 } },
    .{ .symbol = sym_number, .action = .{ .shift = 25 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 44 } },
    .{ .symbol = sym_string, .action = .{ .shift = 26 } },
    .{ .symbol = sym_true, .action = .{ .shift = 27 } },
};
const s21_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expr, .state = 34 },
    .{ .symbol = sym_call_expr, .state = 35 },
    .{ .symbol = sym_expr, .state = 45 },
    .{ .symbol = sym_primary_expr, .state = 36 },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lparen, .action = .{ .shift = 46 } },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_fn, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_pub, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 20 } } },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 47 } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 39 } } },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 40 } } },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 41 } } },
};
const s27_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 42 } } },
};
const s28_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 43 } } },
};
const s29_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .shift = 22 } },
    .{ .symbol = sym_false, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 24 } },
    .{ .symbol = sym_number, .action = .{ .shift = 25 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 48 } },
    .{ .symbol = sym_return, .action = .{ .shift = 21 } },
    .{ .symbol = sym_string, .action = .{ .shift = 26 } },
    .{ .symbol = sym_true, .action = .{ .shift = 27 } },
};
const s29_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expr, .state = 34 },
    .{ .symbol = sym_call_expr, .state = 35 },
    .{ .symbol = sym_expr, .state = 33 },
    .{ .symbol = sym_expr_statement, .state = 32 },
    .{ .symbol = sym_primary_expr, .state = 36 },
    .{ .symbol = sym_return_statement, .state = 31 },
    .{ .symbol = sym_statement, .state = 49 },
};
const s30_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 22 } } },
};
const s31_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 24 } } },
};
const s32_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 25 } } },
};
const s33_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 52 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 51 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 50 } },
};
const s34_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 29 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 29 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 29 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 29 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 29 } } },
};
const s35_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 30 } } },
};
const s36_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 31 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 31 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 31 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 31 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expr, .child_count = 1, .production_id = 31 } } },
};
const s37_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 40 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 53 } },
};
const s37_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_param_decl, .state = 42 },
    .{ .symbol = sym_param_list, .state = 54 },
};
const s38_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .shift = 22 } },
    .{ .symbol = sym_false, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 24 } },
    .{ .symbol = sym_number, .action = .{ .shift = 25 } },
    .{ .symbol = sym_string, .action = .{ .shift = 26 } },
    .{ .symbol = sym_true, .action = .{ .shift = 27 } },
};
const s38_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expr, .state = 34 },
    .{ .symbol = sym_call_expr, .state = 35 },
    .{ .symbol = sym_expr, .state = 55 },
    .{ .symbol = sym_primary_expr, .state = 36 },
};
const s39_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_bool, .action = .{ .shift = 59 } },
    .{ .symbol = sym_i32, .action = .{ .shift = 56 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 60 } },
    .{ .symbol = sym_u32, .action = .{ .shift = 57 } },
    .{ .symbol = sym_void, .action = .{ .shift = 58 } },
};
const s39_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_type_expr, .state = 61 },
};
const s40_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .shift = 62 } },
};
const s41_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 63 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 64 } },
};
const s42_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_param_list, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_param_list, .child_count = 1, .production_id = 10 } } },
};
const s43_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 52 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 51 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_const_declaration, .child_count = 4, .production_id = 14 } } },
};
const s44_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 27 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 27 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 27 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 27 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 27 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 27 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 27 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 27 } } },
};
const s45_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 52 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 51 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 65 } },
};
const s46_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .shift = 22 } },
    .{ .symbol = sym_false, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 24 } },
    .{ .symbol = sym_number, .action = .{ .shift = 25 } },
    .{ .symbol = sym_string, .action = .{ .shift = 26 } },
    .{ .symbol = sym_true, .action = .{ .shift = 27 } },
};
const s46_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_arg_list, .state = 67 },
    .{ .symbol = sym_binary_expr, .state = 34 },
    .{ .symbol = sym_call_expr, .state = 35 },
    .{ .symbol = sym_expr, .state = 66 },
    .{ .symbol = sym_primary_expr, .state = 36 },
};
const s47_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .shift = 22 } },
    .{ .symbol = sym_false, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 24 } },
    .{ .symbol = sym_number, .action = .{ .shift = 25 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 68 } },
    .{ .symbol = sym_string, .action = .{ .shift = 26 } },
    .{ .symbol = sym_true, .action = .{ .shift = 27 } },
};
const s47_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_arg_list, .state = 69 },
    .{ .symbol = sym_binary_expr, .state = 34 },
    .{ .symbol = sym_call_expr, .state = 35 },
    .{ .symbol = sym_expr, .state = 66 },
    .{ .symbol = sym_primary_expr, .state = 36 },
};
const s48_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 21 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 21 } } },
    .{ .symbol = sym_fn, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 21 } } },
    .{ .symbol = sym_pub, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 21 } } },
};
const s49_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 23 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 23 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 23 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 23 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 23 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 23 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 23 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 23 } } },
};
const s50_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .reduce = .{ .symbol = sym_expr_statement, .child_count = 2, .production_id = 28 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_expr_statement, .child_count = 2, .production_id = 28 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expr_statement, .child_count = 2, .production_id = 28 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_expr_statement, .child_count = 2, .production_id = 28 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expr_statement, .child_count = 2, .production_id = 28 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expr_statement, .child_count = 2, .production_id = 28 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_expr_statement, .child_count = 2, .production_id = 28 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_expr_statement, .child_count = 2, .production_id = 28 } } },
};
const s51_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 70 } },
    .{ .symbol = sym_number, .action = .{ .shift = 25 } },
    .{ .symbol = sym_string, .action = .{ .shift = 26 } },
    .{ .symbol = sym_true, .action = .{ .shift = 27 } },
};
const s51_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary_expr, .state = 71 },
};
const s52_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 70 } },
    .{ .symbol = sym_number, .action = .{ .shift = 25 } },
    .{ .symbol = sym_string, .action = .{ .shift = 26 } },
    .{ .symbol = sym_true, .action = .{ .shift = 27 } },
};
const s52_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary_expr, .state = 72 },
};
const s53_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_bool, .action = .{ .shift = 59 } },
    .{ .symbol = sym_i32, .action = .{ .shift = 56 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 60 } },
    .{ .symbol = sym_u32, .action = .{ .shift = 57 } },
    .{ .symbol = sym_void, .action = .{ .shift = 58 } },
};
const s53_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_type_expr, .state = 73 },
};
const s54_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 63 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 74 } },
};
const s55_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 52 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 51 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_const_declaration, .child_count = 5, .production_id = 13 } } },
};
const s56_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 15 } } },
};
const s57_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 16 } } },
};
const s58_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 17 } } },
};
const s59_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 18 } } },
};
const s60_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_type_expr, .child_count = 1, .production_id = 19 } } },
};
const s61_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_fn_proto, .child_count = 5, .production_id = 9 } } },
};
const s62_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_bool, .action = .{ .shift = 59 } },
    .{ .symbol = sym_i32, .action = .{ .shift = 56 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 60 } },
    .{ .symbol = sym_u32, .action = .{ .shift = 57 } },
    .{ .symbol = sym_void, .action = .{ .shift = 58 } },
};
const s62_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_type_expr, .state = 75 },
};
const s63_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 40 } },
};
const s63_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_param_decl, .state = 76 },
};
const s64_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_bool, .action = .{ .shift = 59 } },
    .{ .symbol = sym_i32, .action = .{ .shift = 56 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 60 } },
    .{ .symbol = sym_u32, .action = .{ .shift = 57 } },
    .{ .symbol = sym_void, .action = .{ .shift = 58 } },
};
const s64_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_type_expr, .state = 77 },
};
const s65_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 26 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 26 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 26 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 26 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 26 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 26 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 26 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 26 } } },
};
const s66_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_arg_list, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 52 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 51 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_arg_list, .child_count = 1, .production_id = 37 } } },
};
const s67_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 78 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 79 } },
};
const s68_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 3, .production_id = 35 } } },
};
const s69_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 78 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 80 } },
};
const s70_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expr, .child_count = 1, .production_id = 39 } } },
};
const s71_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expr, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expr, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expr, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expr, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expr, .child_count = 3, .production_id = 32 } } },
};
const s72_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expr, .child_count = 3, .production_id = 33 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expr, .child_count = 3, .production_id = 33 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expr, .child_count = 3, .production_id = 33 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expr, .child_count = 3, .production_id = 33 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expr, .child_count = 3, .production_id = 33 } } },
};
const s73_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_fn_proto, .child_count = 6, .production_id = 8 } } },
};
const s74_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_bool, .action = .{ .shift = 59 } },
    .{ .symbol = sym_i32, .action = .{ .shift = 56 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 60 } },
    .{ .symbol = sym_u32, .action = .{ .shift = 57 } },
    .{ .symbol = sym_void, .action = .{ .shift = 58 } },
};
const s74_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_type_expr, .state = 81 },
};
const s75_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_param_decl, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_param_decl, .child_count = 3, .production_id = 12 } } },
};
const s76_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_param_list, .child_count = 3, .production_id = 11 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_param_list, .child_count = 3, .production_id = 11 } } },
};
const s77_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_fn_proto, .child_count = 6, .production_id = 7 } } },
};
const s78_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_builtin_identifier, .action = .{ .shift = 22 } },
    .{ .symbol = sym_false, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 24 } },
    .{ .symbol = sym_number, .action = .{ .shift = 25 } },
    .{ .symbol = sym_string, .action = .{ .shift = 26 } },
    .{ .symbol = sym_true, .action = .{ .shift = 27 } },
};
const s78_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expr, .state = 34 },
    .{ .symbol = sym_call_expr, .state = 35 },
    .{ .symbol = sym_expr, .state = 82 },
    .{ .symbol = sym_primary_expr, .state = 36 },
};
const s79_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 4, .production_id = 36 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 4, .production_id = 36 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 4, .production_id = 36 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 4, .production_id = 36 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 4, .production_id = 36 } } },
};
const s80_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 4, .production_id = 34 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 4, .production_id = 34 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 4, .production_id = 34 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 4, .production_id = 34 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_call_expr, .child_count = 4, .production_id = 34 } } },
};
const s81_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_fn_proto, .child_count = 7, .production_id = 6 } } },
};
const s82_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_arg_list, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 52 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 51 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_arg_list, .child_count = 3, .production_id = 38 } } },
};

const parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = s0_actions, .gotos = s0_gotos }, // 0
    .{ .actions = s1_actions }, // 1
    .{ .actions = s2_actions }, // 2
    .{ .actions = s3_actions }, // 3
    .{ .actions = s4_actions }, // 4
    .{ .actions = s5_actions, .gotos = s5_gotos }, // 5
    .{ .actions = s6_actions }, // 6
    .{ .actions = s7_actions, .gotos = s7_gotos }, // 7
    .{ .actions = s8_actions }, // 8
    .{ .actions = s9_actions }, // 9
    .{ .actions = s10_actions }, // 10
    .{ .actions = s11_actions }, // 11
    .{ .actions = s12_actions }, // 12
    .{ .actions = s13_actions }, // 13
    .{ .actions = s14_actions, .gotos = s14_gotos }, // 14
    .{ .actions = s15_actions }, // 15
    .{ .actions = s16_actions }, // 16
    .{ .actions = s17_actions }, // 17
    .{ .actions = s18_actions }, // 18
    .{ .actions = s19_actions, .gotos = s19_gotos }, // 19
    .{ .actions = s20_actions, .gotos = s20_gotos }, // 20
    .{ .actions = s21_actions, .gotos = s21_gotos }, // 21
    .{ .actions = s22_actions }, // 22
    .{ .actions = s23_actions }, // 23
    .{ .actions = s24_actions }, // 24
    .{ .actions = s25_actions }, // 25
    .{ .actions = s26_actions }, // 26
    .{ .actions = s27_actions }, // 27
    .{ .actions = s28_actions }, // 28
    .{ .actions = s29_actions, .gotos = s29_gotos }, // 29
    .{ .actions = s30_actions }, // 30
    .{ .actions = s31_actions }, // 31
    .{ .actions = s32_actions }, // 32
    .{ .actions = s33_actions }, // 33
    .{ .actions = s34_actions }, // 34
    .{ .actions = s35_actions }, // 35
    .{ .actions = s36_actions }, // 36
    .{ .actions = s37_actions, .gotos = s37_gotos }, // 37
    .{ .actions = s38_actions, .gotos = s38_gotos }, // 38
    .{ .actions = s39_actions, .gotos = s39_gotos }, // 39
    .{ .actions = s40_actions }, // 40
    .{ .actions = s41_actions }, // 41
    .{ .actions = s42_actions }, // 42
    .{ .actions = s43_actions }, // 43
    .{ .actions = s44_actions }, // 44
    .{ .actions = s45_actions }, // 45
    .{ .actions = s46_actions, .gotos = s46_gotos }, // 46
    .{ .actions = s47_actions, .gotos = s47_gotos }, // 47
    .{ .actions = s48_actions }, // 48
    .{ .actions = s49_actions }, // 49
    .{ .actions = s50_actions }, // 50
    .{ .actions = s51_actions, .gotos = s51_gotos }, // 51
    .{ .actions = s52_actions, .gotos = s52_gotos }, // 52
    .{ .actions = s53_actions, .gotos = s53_gotos }, // 53
    .{ .actions = s54_actions }, // 54
    .{ .actions = s55_actions }, // 55
    .{ .actions = s56_actions }, // 56
    .{ .actions = s57_actions }, // 57
    .{ .actions = s58_actions }, // 58
    .{ .actions = s59_actions }, // 59
    .{ .actions = s60_actions }, // 60
    .{ .actions = s61_actions }, // 61
    .{ .actions = s62_actions, .gotos = s62_gotos }, // 62
    .{ .actions = s63_actions, .gotos = s63_gotos }, // 63
    .{ .actions = s64_actions, .gotos = s64_gotos }, // 64
    .{ .actions = s65_actions }, // 65
    .{ .actions = s66_actions }, // 66
    .{ .actions = s67_actions }, // 67
    .{ .actions = s68_actions }, // 68
    .{ .actions = s69_actions }, // 69
    .{ .actions = s70_actions }, // 70
    .{ .actions = s71_actions }, // 71
    .{ .actions = s72_actions }, // 72
    .{ .actions = s73_actions }, // 73
    .{ .actions = s74_actions, .gotos = s74_gotos }, // 74
    .{ .actions = s75_actions }, // 75
    .{ .actions = s76_actions }, // 76
    .{ .actions = s77_actions }, // 77
    .{ .actions = s78_actions, .gotos = s78_gotos }, // 78
    .{ .actions = s79_actions }, // 79
    .{ .actions = s80_actions }, // 80
    .{ .actions = s81_actions }, // 81
    .{ .actions = s82_actions }, // 82
};

const field_names: []const []const u8 = &.{ "name", "parameters", "return_type", "type", "value", "left", "right", "function", "arguments" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 6, .bindings = &.{ .{ .name = "name", .child_index = 2 }, .{ .name = "parameters", .child_index = 4 }, .{ .name = "return_type", .child_index = 6 } } },
    .{ .production_id = 7, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "parameters", .child_index = 3 }, .{ .name = "return_type", .child_index = 5 } } },
    .{ .production_id = 8, .bindings = &.{ .{ .name = "name", .child_index = 2 }, .{ .name = "return_type", .child_index = 5 } } },
    .{ .production_id = 9, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "return_type", .child_index = 4 } } },
    .{ .production_id = 12, .bindings = &.{ .{ .name = "name", .child_index = 0 }, .{ .name = "type", .child_index = 2 } } },
    .{ .production_id = 13, .bindings = &.{ .{ .name = "name", .child_index = 2 }, .{ .name = "value", .child_index = 4 } } },
    .{ .production_id = 14, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "value", .child_index = 3 } } },
    .{ .production_id = 26, .bindings = &.{.{ .name = "value", .child_index = 1 }} },
    .{ .production_id = 32, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 33, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 34, .bindings = &.{ .{ .name = "function", .child_index = 0 }, .{ .name = "arguments", .child_index = 2 } } },
    .{ .production_id = 35, .bindings = &.{.{ .name = "function", .child_index = 0 }} },
    .{ .production_id = 36, .bindings = &.{ .{ .name = "function", .child_index = 0 }, .{ .name = "arguments", .child_index = 2 } } },
};

pub const language: Language = .{
    .metadata = .{
        .name = "zig",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.3",
        .symbol_count = 47,
        .state_count = 83,
        .field_count = 9,
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

test "parser: zig table verification" {
    try std.testing.expectEqualStrings("zig", language.metadata.name);
    try std.testing.expect(language.metadata.symbol_count > 0);
    try std.testing.expect(language.table.stateCount() > 0);
}

test "parser: zig node types verification" {
    var nt = try treesitter.NodeTypes.parseJSON(std.testing.allocator, node_types_json);
    defer nt.deinit();
    try std.testing.expect(nt.findType("source_file") != null);
}

test "parser: zig grammar json verification" {
    var dsl = treesitter.DSLParser.init(std.testing.allocator);
    var g = try dsl.parseJSON(grammar_json);
    defer g.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("zig", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}

test "parser: zig genuine program parsing 1" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("pub fn add(a: i32, b: i32) i32 { return a + b; }");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("source_file", root.nodeType());
}

test "parser: zig genuine program parsing 2" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("pub const MAX = 100;");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("source_file", root.nodeType());
}
