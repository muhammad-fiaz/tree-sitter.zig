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
pub const sym_function: u16 = 1;
pub const sym_const: u16 = 2;
pub const sym_let: u16 = 3;
pub const sym_var: u16 = 4;
pub const sym_return: u16 = 5;
pub const sym_true: u16 = 6;
pub const sym_false: u16 = 7;
pub const sym_null: u16 = 8;
pub const sym_arrow: u16 = 9;
pub const sym_eqeqeq: u16 = 10;
pub const sym_semi: u16 = 11;
pub const sym_comma: u16 = 12;
pub const sym_colon: u16 = 13;
pub const sym_lparen: u16 = 14;
pub const sym_rparen: u16 = 15;
pub const sym_lbrace: u16 = 16;
pub const sym_rbrace: u16 = 17;
pub const sym_lbracket: u16 = 18;
pub const sym_rbracket: u16 = 19;
pub const sym_plus: u16 = 20;
pub const sym_minus: u16 = 21;
pub const sym_eq: u16 = 22;
pub const sym_identifier: u16 = 23;
pub const sym_number: u16 = 24;
pub const sym_string: u16 = 25;
pub const sym_whitespace: u16 = 26;
pub const sym_comment: u16 = 27;
pub const sym_program: u16 = 28;
pub const sym_statements: u16 = 29;
pub const sym_statement: u16 = 30;
pub const sym_function_declaration: u16 = 31;
pub const sym_parameter_list: u16 = 32;
pub const sym_statement_block: u16 = 33;
pub const sym_variable_declaration: u16 = 34;
pub const sym_return_statement: u16 = 35;
pub const sym_expression_statement: u16 = 36;
pub const sym_expression: u16 = 37;
pub const sym_arrow_function: u16 = 38;
pub const sym_assignment_expression: u16 = 39;
pub const sym_binary_expression: u16 = 40;
pub const sym_call_expression: u16 = 41;
pub const sym_argument_list: u16 = 42;
pub const sym_primary_expression: u16 = 43;
pub const sym_object: u16 = 44;
pub const sym_object_properties: u16 = 45;
pub const sym_pair: u16 = 46;
pub const sym_array: u16 = 47;
pub const sym_array_elements: u16 = 48;
pub const sym_ERROR: u16 = 49;

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
    .{ .id = sym_function, .name = "function", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_const, .name = "const", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_let, .name = "let", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_var, .name = "var", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_return, .name = "return", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_true, .name = "true", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_false, .name = "false", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_null, .name = "null", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_arrow, .name = "=>", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_eqeqeq, .name = "===", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_semi, .name = ";", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_comma, .name = ",", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_colon, .name = ":", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lparen, .name = "(", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rparen, .name = ")", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lbrace, .name = "{", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rbrace, .name = "}", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lbracket, .name = "[", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rbracket, .name = "]", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_plus, .name = "+", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_minus, .name = "-", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_eq, .name = "=", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_number, .name = "number", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_string, .name = "string", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = true, .named = false, .extra = true } },
    .{ .id = sym_comment, .name = "comment", .kind = .terminal, .metadata = .{ .visible = true, .named = true, .extra = true } },
    .{ .id = sym_program, .name = "program", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statements, .name = "statements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statement, .name = "statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_function_declaration, .name = "function_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_parameter_list, .name = "parameter_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statement_block, .name = "statement_block", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_variable_declaration, .name = "variable_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_return_statement, .name = "return_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression_statement, .name = "expression_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression, .name = "expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_arrow_function, .name = "arrow_function", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_assignment_expression, .name = "assignment_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_binary_expression, .name = "binary_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_call_expression, .name = "call_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_argument_list, .name = "argument_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_primary_expression, .name = "primary_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_object, .name = "object", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_object_properties, .name = "object_properties", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_pair, .name = "pair", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_array, .name = "array", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_array_elements, .name = "array_elements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_ERROR, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_function, .match = matchKeyword("function") },
    .{ .symbol = sym_const, .match = matchKeyword("const") },
    .{ .symbol = sym_let, .match = matchKeyword("let") },
    .{ .symbol = sym_var, .match = matchKeyword("var") },
    .{ .symbol = sym_return, .match = matchKeyword("return") },
    .{ .symbol = sym_true, .match = matchKeyword("true") },
    .{ .symbol = sym_false, .match = matchKeyword("false") },
    .{ .symbol = sym_null, .match = matchKeyword("null") },
    .{ .symbol = sym_arrow, .match = matchLiteral("=>") },
    .{ .symbol = sym_eqeqeq, .match = matchLiteral("===") },
    .{ .symbol = sym_semi, .match = language_mod.matchChar(';') },
    .{ .symbol = sym_comma, .match = language_mod.matchChar(',') },
    .{ .symbol = sym_colon, .match = language_mod.matchChar(':') },
    .{ .symbol = sym_lparen, .match = language_mod.matchChar('(') },
    .{ .symbol = sym_rparen, .match = language_mod.matchChar(')') },
    .{ .symbol = sym_lbrace, .match = language_mod.matchChar('{') },
    .{ .symbol = sym_rbrace, .match = language_mod.matchChar('}') },
    .{ .symbol = sym_lbracket, .match = language_mod.matchChar('[') },
    .{ .symbol = sym_rbracket, .match = language_mod.matchChar(']') },
    .{ .symbol = sym_plus, .match = language_mod.matchChar('+') },
    .{ .symbol = sym_minus, .match = language_mod.matchChar('-') },
    .{ .symbol = sym_eq, .match = language_mod.matchChar('=') },
    .{ .symbol = sym_identifier, .match = matchIdentifier },
    .{ .symbol = sym_number, .match = matchNumber },
    .{ .symbol = sym_string, .match = matchString },
    .{ .symbol = sym_whitespace, .match = language_mod.matchWhitespace },
    .{ .symbol = sym_comment, .match = matchComment },
};

const extra_symbols: []const u16 = &.{ sym_whitespace, sym_comment };

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .shift = 2 } },
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_function, .action = .{ .shift = 1 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_let, .action = .{ .shift = 3 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_return, .action = .{ .shift = 5 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 9 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
    .{ .symbol = sym_var, .action = .{ .shift = 4 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 23 },
    .{ .symbol = sym_expression_statement, .state = 22 },
    .{ .symbol = sym_function_declaration, .state = 19 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
    .{ .symbol = sym_program, .state = 16 },
    .{ .symbol = sym_return_statement, .state = 21 },
    .{ .symbol = sym_statement, .state = 18 },
    .{ .symbol = sym_statements, .state = 17 },
    .{ .symbol = sym_variable_declaration, .state = 20 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 31 } },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 32 } },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 33 } },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 34 } },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 1, .production_id = 20 } } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s5_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 35 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 40 } } },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 41 } } },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 42 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 42 } } },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 9 } } },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 37 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 36 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s10_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 39 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_parameter_list, .state = 38 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 41 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 40 } },
    .{ .symbol = sym_string, .action = .{ .shift = 42 } },
};
const s11_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_object_properties, .state = 43 },
    .{ .symbol = sym_pair, .state = 44 },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_rbracket, .action = .{ .shift = 45 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s12_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_array_elements, .state = 47 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 46 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_eq, .action = .{ .shift = 48 } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 38 } } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 39 } } },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .shift = 2 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_program, .child_count = 1, .production_id = 1 } } },
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_function, .action = .{ .shift = 1 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_let, .action = .{ .shift = 3 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_return, .action = .{ .shift = 5 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 9 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
    .{ .symbol = sym_var, .action = .{ .shift = 4 } },
};
const s17_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 23 },
    .{ .symbol = sym_expression_statement, .state = 22 },
    .{ .symbol = sym_function_declaration, .state = 19 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
    .{ .symbol = sym_return_statement, .state = 21 },
    .{ .symbol = sym_statement, .state = 49 },
    .{ .symbol = sym_variable_declaration, .state = 20 },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 2 } } },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_semi, .action = .{ .shift = 50 } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 4 } } },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 51 } },
};
const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 52 } },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 53 } },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 21 } } },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 25 } } },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 22 } } },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 23 } } },
};
const s27_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 24 } } },
};
const s28_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 26 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 26 } } },
};
const s29_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
};
const s30_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
};
const s31_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lparen, .action = .{ .shift = 58 } },
};
const s32_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eq, .action = .{ .shift = 59 } },
};
const s33_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eq, .action = .{ .shift = 60 } },
};
const s34_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eq, .action = .{ .shift = 61 } },
};
const s35_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 19 } } },
};
const s36_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_arrow, .action = .{ .shift = 62 } },
};
const s37_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_eq, .action = .{ .shift = 48 } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
};
const s38_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 63 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 64 } },
};
const s39_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 65 } },
};
const s40_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 46 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 46 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 46 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 46 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 46 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 46 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 46 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 46 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 2, .production_id = 46 } } },
};
const s41_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .shift = 66 } },
};
const s42_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .shift = 67 } },
};
const s43_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 68 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 69 } },
};
const s44_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_object_properties, .child_count = 1, .production_id = 48 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_object_properties, .child_count = 1, .production_id = 48 } } },
};
const s45_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 52 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 52 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 52 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 52 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 52 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 52 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 52 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 52 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 2, .production_id = 52 } } },
};
const s46_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_array_elements, .child_count = 1, .production_id = 54 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_array_elements, .child_count = 1, .production_id = 54 } } },
};
const s47_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 70 } },
    .{ .symbol = sym_rbracket, .action = .{ .shift = 71 } },
};
const s48_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s48_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 72 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s49_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 3 } } },
};
const s50_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 5 } } },
};
const s51_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 6 } } },
};
const s52_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 7 } } },
};
const s53_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 8 } } },
};
const s54_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 74 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 73 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s54_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 75 },
};
const s55_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 76 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s55_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_argument_list, .state = 78 },
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 77 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s56_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 74 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 73 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s56_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 79 },
};
const s57_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 74 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 73 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s57_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 80 },
};
const s58_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 82 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 81 } },
};
const s58_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_parameter_list, .state = 83 },
};
const s59_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s59_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 84 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s60_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s60_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 85 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s61_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s61_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 86 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s62_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 87 } },
};
const s62_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_statement_block, .state = 88 },
};
const s63_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 89 } },
};
const s64_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_arrow, .action = .{ .shift = 90 } },
};
const s65_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 45 } } },
};
const s66_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s66_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 91 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s67_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s67_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 92 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s68_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 41 } },
    .{ .symbol = sym_string, .action = .{ .shift = 42 } },
};
const s68_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_pair, .state = 93 },
};
const s69_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_object, .child_count = 3, .production_id = 47 } } },
};
const s70_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s70_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 94 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s71_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_array, .child_count = 3, .production_id = 53 } } },
};
const s72_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_assignment_expression, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_assignment_expression, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_assignment_expression, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_assignment_expression, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_assignment_expression, .child_count = 3, .production_id = 29 } } },
};
const s73_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s73_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 39 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s74_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 37 } } },
};
const s75_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 32 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 32 } } },
};
const s76_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 34 } } },
};
const s77_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 1, .production_id = 35 } } },
};
const s78_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 95 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 96 } },
};
const s79_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 30 } } },
};
const s80_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 31 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 31 } } },
};
const s81_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 87 } },
};
const s81_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_statement_block, .state = 97 },
};
const s82_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 12 } } },
};
const s83_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 63 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 98 } },
};
const s84_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_variable_declaration, .child_count = 4, .production_id = 16 } } },
};
const s85_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_variable_declaration, .child_count = 4, .production_id = 17 } } },
};
const s86_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_variable_declaration, .child_count = 4, .production_id = 18 } } },
};
const s87_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .shift = 2 } },
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_function, .action = .{ .shift = 1 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_let, .action = .{ .shift = 3 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 99 } },
    .{ .symbol = sym_return, .action = .{ .shift = 5 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 9 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
    .{ .symbol = sym_var, .action = .{ .shift = 4 } },
};
const s87_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 23 },
    .{ .symbol = sym_expression_statement, .state = 22 },
    .{ .symbol = sym_function_declaration, .state = 19 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
    .{ .symbol = sym_return_statement, .state = 21 },
    .{ .symbol = sym_statement, .state = 18 },
    .{ .symbol = sym_statements, .state = 100 },
    .{ .symbol = sym_variable_declaration, .state = 20 },
};
const s88_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 4, .production_id = 28 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 4, .production_id = 28 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 4, .production_id = 28 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 4, .production_id = 28 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 4, .production_id = 28 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 4, .production_id = 28 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 4, .production_id = 28 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 4, .production_id = 28 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 4, .production_id = 28 } } },
};
const s89_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 3, .production_id = 13 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 3, .production_id = 13 } } },
};
const s90_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 87 } },
};
const s90_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_statement_block, .state = 101 },
};
const s91_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_pair, .child_count = 3, .production_id = 50 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_pair, .child_count = 3, .production_id = 50 } } },
};
const s92_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_pair, .child_count = 3, .production_id = 51 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_pair, .child_count = 3, .production_id = 51 } } },
};
const s93_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_object_properties, .child_count = 3, .production_id = 49 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_object_properties, .child_count = 3, .production_id = 49 } } },
};
const s94_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_array_elements, .child_count = 3, .production_id = 55 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_array_elements, .child_count = 3, .production_id = 55 } } },
};
const s95_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
};
const s95_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 102 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
};
const s96_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 33 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 33 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 33 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 33 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 33 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 33 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 33 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 33 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 33 } } },
};
const s97_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 11 } } },
};
const s98_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 87 } },
};
const s98_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_statement_block, .state = 103 },
};
const s99_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 2, .production_id = 14 } } },
};
const s100_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .shift = 2 } },
    .{ .symbol = sym_false, .action = .{ .shift = 7 } },
    .{ .symbol = sym_function, .action = .{ .shift = 1 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 13 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 11 } },
    .{ .symbol = sym_lbracket, .action = .{ .shift = 12 } },
    .{ .symbol = sym_let, .action = .{ .shift = 3 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 10 } },
    .{ .symbol = sym_null, .action = .{ .shift = 8 } },
    .{ .symbol = sym_number, .action = .{ .shift = 14 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 104 } },
    .{ .symbol = sym_return, .action = .{ .shift = 5 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 9 } },
    .{ .symbol = sym_string, .action = .{ .shift = 15 } },
    .{ .symbol = sym_true, .action = .{ .shift = 6 } },
    .{ .symbol = sym_var, .action = .{ .shift = 4 } },
};
const s100_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_array, .state = 30 },
    .{ .symbol = sym_arrow_function, .state = 24 },
    .{ .symbol = sym_assignment_expression, .state = 25 },
    .{ .symbol = sym_binary_expression, .state = 26 },
    .{ .symbol = sym_call_expression, .state = 27 },
    .{ .symbol = sym_expression, .state = 23 },
    .{ .symbol = sym_expression_statement, .state = 22 },
    .{ .symbol = sym_function_declaration, .state = 19 },
    .{ .symbol = sym_object, .state = 29 },
    .{ .symbol = sym_primary_expression, .state = 28 },
    .{ .symbol = sym_return_statement, .state = 21 },
    .{ .symbol = sym_statement, .state = 49 },
    .{ .symbol = sym_variable_declaration, .state = 20 },
};
const s101_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 5, .production_id = 27 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 5, .production_id = 27 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 5, .production_id = 27 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 5, .production_id = 27 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 5, .production_id = 27 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 5, .production_id = 27 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 5, .production_id = 27 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 5, .production_id = 27 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_arrow_function, .child_count = 5, .production_id = 27 } } },
};
const s102_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 3, .production_id = 36 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .shift = 54 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 55 } },
    .{ .symbol = sym_minus, .action = .{ .shift = 57 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 56 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 3, .production_id = 36 } } },
};
const s103_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 10 } } },
};
const s104_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_const, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_eqeqeq, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_false, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_function, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_lbracket, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_let, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_null, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_number, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_rbracket, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_string, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_true, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_statement_block, .child_count = 3, .production_id = 15 } } },
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
    .{ .actions = s10_actions, .gotos = s10_gotos }, // 10
    .{ .actions = s11_actions, .gotos = s11_gotos }, // 11
    .{ .actions = s12_actions, .gotos = s12_gotos }, // 12
    .{ .actions = s13_actions }, // 13
    .{ .actions = s14_actions }, // 14
    .{ .actions = s15_actions }, // 15
    .{ .actions = s16_actions }, // 16
    .{ .actions = s17_actions, .gotos = s17_gotos }, // 17
    .{ .actions = s18_actions }, // 18
    .{ .actions = s19_actions }, // 19
    .{ .actions = s20_actions }, // 20
    .{ .actions = s21_actions }, // 21
    .{ .actions = s22_actions }, // 22
    .{ .actions = s23_actions }, // 23
    .{ .actions = s24_actions }, // 24
    .{ .actions = s25_actions }, // 25
    .{ .actions = s26_actions }, // 26
    .{ .actions = s27_actions }, // 27
    .{ .actions = s28_actions }, // 28
    .{ .actions = s29_actions }, // 29
    .{ .actions = s30_actions }, // 30
    .{ .actions = s31_actions }, // 31
    .{ .actions = s32_actions }, // 32
    .{ .actions = s33_actions }, // 33
    .{ .actions = s34_actions }, // 34
    .{ .actions = s35_actions }, // 35
    .{ .actions = s36_actions }, // 36
    .{ .actions = s37_actions }, // 37
    .{ .actions = s38_actions }, // 38
    .{ .actions = s39_actions }, // 39
    .{ .actions = s40_actions }, // 40
    .{ .actions = s41_actions }, // 41
    .{ .actions = s42_actions }, // 42
    .{ .actions = s43_actions }, // 43
    .{ .actions = s44_actions }, // 44
    .{ .actions = s45_actions }, // 45
    .{ .actions = s46_actions }, // 46
    .{ .actions = s47_actions }, // 47
    .{ .actions = s48_actions, .gotos = s48_gotos }, // 48
    .{ .actions = s49_actions }, // 49
    .{ .actions = s50_actions }, // 50
    .{ .actions = s51_actions }, // 51
    .{ .actions = s52_actions }, // 52
    .{ .actions = s53_actions }, // 53
    .{ .actions = s54_actions, .gotos = s54_gotos }, // 54
    .{ .actions = s55_actions, .gotos = s55_gotos }, // 55
    .{ .actions = s56_actions, .gotos = s56_gotos }, // 56
    .{ .actions = s57_actions, .gotos = s57_gotos }, // 57
    .{ .actions = s58_actions, .gotos = s58_gotos }, // 58
    .{ .actions = s59_actions, .gotos = s59_gotos }, // 59
    .{ .actions = s60_actions, .gotos = s60_gotos }, // 60
    .{ .actions = s61_actions, .gotos = s61_gotos }, // 61
    .{ .actions = s62_actions, .gotos = s62_gotos }, // 62
    .{ .actions = s63_actions }, // 63
    .{ .actions = s64_actions }, // 64
    .{ .actions = s65_actions }, // 65
    .{ .actions = s66_actions, .gotos = s66_gotos }, // 66
    .{ .actions = s67_actions, .gotos = s67_gotos }, // 67
    .{ .actions = s68_actions, .gotos = s68_gotos }, // 68
    .{ .actions = s69_actions }, // 69
    .{ .actions = s70_actions, .gotos = s70_gotos }, // 70
    .{ .actions = s71_actions }, // 71
    .{ .actions = s72_actions }, // 72
    .{ .actions = s73_actions, .gotos = s73_gotos }, // 73
    .{ .actions = s74_actions }, // 74
    .{ .actions = s75_actions }, // 75
    .{ .actions = s76_actions }, // 76
    .{ .actions = s77_actions }, // 77
    .{ .actions = s78_actions }, // 78
    .{ .actions = s79_actions }, // 79
    .{ .actions = s80_actions }, // 80
    .{ .actions = s81_actions, .gotos = s81_gotos }, // 81
    .{ .actions = s82_actions }, // 82
    .{ .actions = s83_actions }, // 83
    .{ .actions = s84_actions }, // 84
    .{ .actions = s85_actions }, // 85
    .{ .actions = s86_actions }, // 86
    .{ .actions = s87_actions, .gotos = s87_gotos }, // 87
    .{ .actions = s88_actions }, // 88
    .{ .actions = s89_actions }, // 89
    .{ .actions = s90_actions, .gotos = s90_gotos }, // 90
    .{ .actions = s91_actions }, // 91
    .{ .actions = s92_actions }, // 92
    .{ .actions = s93_actions }, // 93
    .{ .actions = s94_actions }, // 94
    .{ .actions = s95_actions, .gotos = s95_gotos }, // 95
    .{ .actions = s96_actions }, // 96
    .{ .actions = s97_actions }, // 97
    .{ .actions = s98_actions, .gotos = s98_gotos }, // 98
    .{ .actions = s99_actions }, // 99
    .{ .actions = s100_actions, .gotos = s100_gotos }, // 100
    .{ .actions = s101_actions }, // 101
    .{ .actions = s102_actions }, // 102
    .{ .actions = s103_actions }, // 103
    .{ .actions = s104_actions }, // 104
};

const field_names: []const []const u8 = &.{ "name", "parameters", "body", "value", "argument", "left", "right", "function", "arguments", "key" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 10, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "parameters", .child_index = 3 }, .{ .name = "body", .child_index = 5 } } },
    .{ .production_id = 11, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 4 } } },
    .{ .production_id = 16, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "value", .child_index = 3 } } },
    .{ .production_id = 17, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "value", .child_index = 3 } } },
    .{ .production_id = 18, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "value", .child_index = 3 } } },
    .{ .production_id = 19, .bindings = &.{.{ .name = "argument", .child_index = 1 }} },
    .{ .production_id = 27, .bindings = &.{ .{ .name = "parameters", .child_index = 1 }, .{ .name = "body", .child_index = 4 } } },
    .{ .production_id = 28, .bindings = &.{.{ .name = "body", .child_index = 3 }} },
    .{ .production_id = 29, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 30, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 31, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 32, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 33, .bindings = &.{ .{ .name = "function", .child_index = 0 }, .{ .name = "arguments", .child_index = 2 } } },
    .{ .production_id = 34, .bindings = &.{.{ .name = "function", .child_index = 0 }} },
    .{ .production_id = 50, .bindings = &.{ .{ .name = "key", .child_index = 0 }, .{ .name = "value", .child_index = 2 } } },
    .{ .production_id = 51, .bindings = &.{ .{ .name = "key", .child_index = 0 }, .{ .name = "value", .child_index = 2 } } },
};

pub const language: Language = .{
    .metadata = .{
        .name = "javascript",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.3",
        .symbol_count = 50,
        .state_count = 105,
        .field_count = 10,
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

test "parser: javascript table verification" {
    try std.testing.expectEqualStrings("javascript", language.metadata.name);
    try std.testing.expect(language.metadata.symbol_count > 0);
    try std.testing.expect(language.table.stateCount() > 0);
}

test "parser: javascript node types verification" {
    var nt = try treesitter.NodeTypes.parseJSON(std.testing.allocator, node_types_json);
    defer nt.deinit();
    try std.testing.expect(nt.findType("program") != null);
}

test "parser: javascript grammar json verification" {
    var dsl = treesitter.DSLParser.init(std.testing.allocator);
    var g = try dsl.parseJSON(grammar_json);
    defer g.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("javascript", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}

test "parser: javascript genuine program parsing 1" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("function add(a, b) { return a + b; }");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
}

test "parser: javascript genuine program parsing 2" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("const obj = { x: 1, y: 2 };");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
}
