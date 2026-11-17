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
pub const sym_int: u16 = 1;
pub const sym_char: u16 = 2;
pub const sym_void: u16 = 3;
pub const sym_float: u16 = 4;
pub const sym_double: u16 = 5;
pub const sym_struct: u16 = 6;
pub const sym_return: u16 = 7;
pub const sym_semi: u16 = 8;
pub const sym_comma: u16 = 9;
pub const sym_lparen: u16 = 10;
pub const sym_rparen: u16 = 11;
pub const sym_lbrace: u16 = 12;
pub const sym_rbrace: u16 = 13;
pub const sym_plus: u16 = 14;
pub const sym_minus: u16 = 15;
pub const sym_star: u16 = 16;
pub const sym_slash: u16 = 17;
pub const sym_eq: u16 = 18;
pub const sym_identifier: u16 = 19;
pub const sym_number_literal: u16 = 20;
pub const sym_string_literal: u16 = 21;
pub const sym_whitespace: u16 = 22;
pub const sym_comment: u16 = 23;
pub const sym_translation_unit: u16 = 24;
pub const sym_declarations: u16 = 25;
pub const sym_declaration: u16 = 26;
pub const sym_struct_specifier: u16 = 27;
pub const sym_struct_fields: u16 = 28;
pub const sym_struct_field: u16 = 29;
pub const sym_function_definition: u16 = 30;
pub const sym_declarator: u16 = 31;
pub const sym_parameter_list: u16 = 32;
pub const sym_parameter_declaration: u16 = 33;
pub const sym_type_specifier: u16 = 34;
pub const sym_compound_statement: u16 = 35;
pub const sym_statements: u16 = 36;
pub const sym_statement: u16 = 37;
pub const sym_return_statement: u16 = 38;
pub const sym_expression_statement: u16 = 39;
pub const sym_variable_declaration: u16 = 40;
pub const sym_expression: u16 = 41;
pub const sym_binary_expression: u16 = 42;
pub const sym_call_expression: u16 = 43;
pub const sym_argument_list: u16 = 44;
pub const sym_primary_expression: u16 = 45;
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
    .{ .id = sym_int, .name = "int", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_char, .name = "char", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_void, .name = "void", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_float, .name = "float", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_double, .name = "double", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_struct, .name = "struct", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_return, .name = "return", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_semi, .name = ";", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_comma, .name = ",", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lparen, .name = "(", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rparen, .name = ")", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lbrace, .name = "{", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rbrace, .name = "}", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_plus, .name = "+", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_minus, .name = "-", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_star, .name = "*", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_slash, .name = "/", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_eq, .name = "=", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_number_literal, .name = "number_literal", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_string_literal, .name = "string_literal", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = true, .named = false, .extra = true } },
    .{ .id = sym_comment, .name = "comment", .kind = .terminal, .metadata = .{ .visible = true, .named = true, .extra = true } },
    .{ .id = sym_translation_unit, .name = "translation_unit", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declarations, .name = "declarations", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declaration, .name = "declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_struct_specifier, .name = "struct_specifier", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_struct_fields, .name = "struct_fields", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_struct_field, .name = "struct_field", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_function_definition, .name = "function_definition", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declarator, .name = "declarator", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_parameter_list, .name = "parameter_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_parameter_declaration, .name = "parameter_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_type_specifier, .name = "type_specifier", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_compound_statement, .name = "compound_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statements, .name = "statements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statement, .name = "statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_return_statement, .name = "return_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression_statement, .name = "expression_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_variable_declaration, .name = "variable_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression, .name = "expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_binary_expression, .name = "binary_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_call_expression, .name = "call_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_argument_list, .name = "argument_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_primary_expression, .name = "primary_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_ERROR, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_int, .match = matchKeyword("int") },
    .{ .symbol = sym_char, .match = matchKeyword("char") },
    .{ .symbol = sym_void, .match = matchKeyword("void") },
    .{ .symbol = sym_float, .match = matchKeyword("float") },
    .{ .symbol = sym_double, .match = matchKeyword("double") },
    .{ .symbol = sym_struct, .match = matchKeyword("struct") },
    .{ .symbol = sym_return, .match = matchKeyword("return") },
    .{ .symbol = sym_semi, .match = language_mod.matchChar(';') },
    .{ .symbol = sym_comma, .match = language_mod.matchChar(',') },
    .{ .symbol = sym_lparen, .match = language_mod.matchChar('(') },
    .{ .symbol = sym_rparen, .match = language_mod.matchChar(')') },
    .{ .symbol = sym_lbrace, .match = language_mod.matchChar('{') },
    .{ .symbol = sym_rbrace, .match = language_mod.matchChar('}') },
    .{ .symbol = sym_plus, .match = language_mod.matchChar('+') },
    .{ .symbol = sym_minus, .match = language_mod.matchChar('-') },
    .{ .symbol = sym_star, .match = language_mod.matchChar('*') },
    .{ .symbol = sym_slash, .match = language_mod.matchChar('/') },
    .{ .symbol = sym_eq, .match = language_mod.matchChar('=') },
    .{ .symbol = sym_identifier, .match = matchIdentifier },
    .{ .symbol = sym_number_literal, .match = matchNumber },
    .{ .symbol = sym_string_literal, .match = matchString },
    .{ .symbol = sym_whitespace, .match = language_mod.matchWhitespace },
    .{ .symbol = sym_comment, .match = matchComment },
};

const extra_symbols: []const u16 = &.{ sym_whitespace, sym_comment };

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 5 } },
    .{ .symbol = sym_float, .action = .{ .shift = 4 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_int, .action = .{ .shift = 1 } },
    .{ .symbol = sym_struct, .action = .{ .shift = 6 } },
    .{ .symbol = sym_void, .action = .{ .shift = 3 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_declaration, .state = 10 },
    .{ .symbol = sym_declarations, .state = 9 },
    .{ .symbol = sym_function_definition, .state = 12 },
    .{ .symbol = sym_struct_specifier, .state = 11 },
    .{ .symbol = sym_translation_unit, .state = 8 },
    .{ .symbol = sym_type_specifier, .state = 13 },
    .{ .symbol = sym_variable_declaration, .state = 14 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 19 } } },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 20 } } },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 21 } } },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 22 } } },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 23 } } },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 15 } },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 25 } } },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 5 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_translation_unit, .child_count = 1, .production_id = 1 } } },
    .{ .symbol = sym_float, .action = .{ .shift = 4 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_int, .action = .{ .shift = 1 } },
    .{ .symbol = sym_struct, .action = .{ .shift = 6 } },
    .{ .symbol = sym_void, .action = .{ .shift = 3 } },
};
const s9_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_declaration, .state = 16 },
    .{ .symbol = sym_function_definition, .state = 12 },
    .{ .symbol = sym_struct_specifier, .state = 11 },
    .{ .symbol = sym_type_specifier, .state = 13 },
    .{ .symbol = sym_variable_declaration, .state = 14 },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_semi, .action = .{ .shift = 17 } },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 18 } },
};
const s13_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_declarator, .state = 19 },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 20 } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_struct_specifier, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 21 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_struct_specifier, .child_count = 2, .production_id = 8 } } },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eq, .action = .{ .shift = 23 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 22 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_variable_declaration, .child_count = 2, .production_id = 38 } } },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 24 } },
};
const s19_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_compound_statement, .state = 25 },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 6 } } },
};
const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 5 } },
    .{ .symbol = sym_float, .action = .{ .shift = 4 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_int, .action = .{ .shift = 1 } },
    .{ .symbol = sym_struct, .action = .{ .shift = 6 } },
    .{ .symbol = sym_void, .action = .{ .shift = 3 } },
};
const s21_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_struct_field, .state = 28 },
    .{ .symbol = sym_struct_fields, .state = 27 },
    .{ .symbol = sym_struct_specifier, .state = 26 },
    .{ .symbol = sym_type_specifier, .state = 29 },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 5 } },
    .{ .symbol = sym_float, .action = .{ .shift = 4 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_int, .action = .{ .shift = 1 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 31 } },
    .{ .symbol = sym_struct, .action = .{ .shift = 6 } },
    .{ .symbol = sym_void, .action = .{ .shift = 30 } },
};
const s22_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_parameter_declaration, .state = 33 },
    .{ .symbol = sym_parameter_list, .state = 32 },
    .{ .symbol = sym_struct_specifier, .state = 26 },
    .{ .symbol = sym_type_specifier, .state = 34 },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 36 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 35 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 37 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 38 } },
};
const s23_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 40 },
    .{ .symbol = sym_call_expression, .state = 41 },
    .{ .symbol = sym_expression, .state = 39 },
    .{ .symbol = sym_primary_expression, .state = 42 },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 5 } },
    .{ .symbol = sym_float, .action = .{ .shift = 4 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 45 } },
    .{ .symbol = sym_int, .action = .{ .shift = 1 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 24 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 35 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 37 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 44 } },
    .{ .symbol = sym_return, .action = .{ .shift = 43 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 38 } },
    .{ .symbol = sym_struct, .action = .{ .shift = 6 } },
    .{ .symbol = sym_void, .action = .{ .shift = 3 } },
};
const s24_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 40 },
    .{ .symbol = sym_call_expression, .state = 41 },
    .{ .symbol = sym_compound_statement, .state = 47 },
    .{ .symbol = sym_expression, .state = 53 },
    .{ .symbol = sym_expression_statement, .state = 51 },
    .{ .symbol = sym_primary_expression, .state = 42 },
    .{ .symbol = sym_return_statement, .state = 50 },
    .{ .symbol = sym_statement, .state = 49 },
    .{ .symbol = sym_statements, .state = 48 },
    .{ .symbol = sym_struct_specifier, .state = 26 },
    .{ .symbol = sym_type_specifier, .state = 46 },
    .{ .symbol = sym_variable_declaration, .state = 52 },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 12 } } },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 24 } } },
};
const s27_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 5 } },
    .{ .symbol = sym_float, .action = .{ .shift = 4 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_int, .action = .{ .shift = 1 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 54 } },
    .{ .symbol = sym_struct, .action = .{ .shift = 6 } },
    .{ .symbol = sym_void, .action = .{ .shift = 3 } },
};
const s27_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_struct_field, .state = 55 },
    .{ .symbol = sym_struct_specifier, .state = 26 },
    .{ .symbol = sym_type_specifier, .state = 29 },
};
const s28_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 1, .production_id = 9 } } },
};
const s29_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 56 } },
};
const s30_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 57 } },
};
const s31_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_declarator, .child_count = 3, .production_id = 14 } } },
};
const s32_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 58 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 59 } },
};
const s33_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 16 } } },
};
const s34_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 60 } },
};
const s35_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 36 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 35 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 37 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 38 } },
};
const s35_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 40 },
    .{ .symbol = sym_call_expression, .state = 41 },
    .{ .symbol = sym_expression, .state = 61 },
    .{ .symbol = sym_primary_expression, .state = 42 },
};
const s36_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 62 } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
};
const s37_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 51 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 51 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 51 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 51 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 51 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 51 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 51 } } },
};
const s38_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 52 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 52 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 52 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 52 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 52 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 52 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 52 } } },
};
const s39_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 63 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_variable_declaration, .child_count = 4, .production_id = 37 } } },
    .{ .symbol = sym_slash, .action = .{ .shift = 66 } },
    .{ .symbol = sym_star, .action = .{ .shift = 65 } },
};
const s40_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 39 } } },
};
const s41_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 40 } } },
};
const s42_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 41 } } },
};
const s43_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 36 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 35 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 37 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 67 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 38 } },
};
const s43_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 40 },
    .{ .symbol = sym_call_expression, .state = 41 },
    .{ .symbol = sym_expression, .state = 68 },
    .{ .symbol = sym_primary_expression, .state = 42 },
};
const s44_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 26 } } },
};
const s45_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 62 } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
};
const s46_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 69 } },
};
const s47_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 33 } } },
};
const s48_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 5 } },
    .{ .symbol = sym_float, .action = .{ .shift = 4 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 45 } },
    .{ .symbol = sym_int, .action = .{ .shift = 1 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 24 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 35 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 37 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 70 } },
    .{ .symbol = sym_return, .action = .{ .shift = 43 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 38 } },
    .{ .symbol = sym_struct, .action = .{ .shift = 6 } },
    .{ .symbol = sym_void, .action = .{ .shift = 3 } },
};
const s48_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 40 },
    .{ .symbol = sym_call_expression, .state = 41 },
    .{ .symbol = sym_compound_statement, .state = 47 },
    .{ .symbol = sym_expression, .state = 53 },
    .{ .symbol = sym_expression_statement, .state = 51 },
    .{ .symbol = sym_primary_expression, .state = 42 },
    .{ .symbol = sym_return_statement, .state = 50 },
    .{ .symbol = sym_statement, .state = 71 },
    .{ .symbol = sym_struct_specifier, .state = 26 },
    .{ .symbol = sym_type_specifier, .state = 46 },
    .{ .symbol = sym_variable_declaration, .state = 52 },
};
const s49_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 28 } } },
};
const s50_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 30 } } },
};
const s51_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 32 } } },
};
const s52_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 72 } },
};
const s53_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 63 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 73 } },
    .{ .symbol = sym_slash, .action = .{ .shift = 66 } },
    .{ .symbol = sym_star, .action = .{ .shift = 65 } },
};
const s54_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_struct_specifier, .child_count = 5, .production_id = 7 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_struct_specifier, .child_count = 5, .production_id = 7 } } },
};
const s55_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 2, .production_id = 10 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 2, .production_id = 10 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 2, .production_id = 10 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 2, .production_id = 10 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 2, .production_id = 10 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 2, .production_id = 10 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 2, .production_id = 10 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 2, .production_id = 10 } } },
};
const s56_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 74 } },
};
const s57_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_declarator, .child_count = 4, .production_id = 15 } } },
};
const s58_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 5 } },
    .{ .symbol = sym_float, .action = .{ .shift = 4 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 7 } },
    .{ .symbol = sym_int, .action = .{ .shift = 1 } },
    .{ .symbol = sym_struct, .action = .{ .shift = 6 } },
    .{ .symbol = sym_void, .action = .{ .shift = 3 } },
};
const s58_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_parameter_declaration, .state = 75 },
    .{ .symbol = sym_struct_specifier, .state = 26 },
    .{ .symbol = sym_type_specifier, .state = 34 },
};
const s59_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_declarator, .child_count = 4, .production_id = 13 } } },
};
const s60_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_declaration, .child_count = 2, .production_id = 18 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_declaration, .child_count = 2, .production_id = 18 } } },
};
const s61_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 63 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 76 } },
    .{ .symbol = sym_slash, .action = .{ .shift = 66 } },
    .{ .symbol = sym_star, .action = .{ .shift = 65 } },
};
const s62_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 36 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 35 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 37 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 77 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 38 } },
};
const s62_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_argument_list, .state = 79 },
    .{ .symbol = sym_binary_expression, .state = 40 },
    .{ .symbol = sym_call_expression, .state = 41 },
    .{ .symbol = sym_expression, .state = 78 },
    .{ .symbol = sym_primary_expression, .state = 42 },
};
const s63_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 80 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 35 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 37 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 38 } },
};
const s63_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary_expression, .state = 81 },
};
const s64_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 80 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 35 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 37 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 38 } },
};
const s64_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary_expression, .state = 82 },
};
const s65_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 80 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 35 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 37 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 38 } },
};
const s65_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary_expression, .state = 83 },
};
const s66_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 80 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 35 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 37 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 38 } },
};
const s66_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary_expression, .state = 84 },
};
const s67_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 35 } } },
};
const s68_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 63 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 85 } },
    .{ .symbol = sym_slash, .action = .{ .shift = 66 } },
    .{ .symbol = sym_star, .action = .{ .shift = 65 } },
};
const s69_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eq, .action = .{ .shift = 23 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_variable_declaration, .child_count = 2, .production_id = 38 } } },
};
const s70_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 27 } } },
};
const s71_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 29 } } },
};
const s72_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 31 } } },
};
const s73_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 36 } } },
};
const s74_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_struct_field, .child_count = 3, .production_id = 11 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_struct_field, .child_count = 3, .production_id = 11 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_struct_field, .child_count = 3, .production_id = 11 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_struct_field, .child_count = 3, .production_id = 11 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_struct_field, .child_count = 3, .production_id = 11 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_struct_field, .child_count = 3, .production_id = 11 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_struct_field, .child_count = 3, .production_id = 11 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_struct_field, .child_count = 3, .production_id = 11 } } },
};
const s75_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 3, .production_id = 17 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 3, .production_id = 17 } } },
};
const s76_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 53 } } },
};
const s77_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 47 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 47 } } },
};
const s78_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 1, .production_id = 48 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 63 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 1, .production_id = 48 } } },
    .{ .symbol = sym_slash, .action = .{ .shift = 66 } },
    .{ .symbol = sym_star, .action = .{ .shift = 65 } },
};
const s79_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 86 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 87 } },
};
const s80_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 50 } } },
};
const s81_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 42 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 42 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 42 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 42 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 42 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 42 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 42 } } },
};
const s82_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 43 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 43 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 43 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 43 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 43 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 43 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 43 } } },
};
const s83_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 44 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 44 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 44 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 44 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 44 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 44 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 44 } } },
};
const s84_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 45 } } },
};
const s85_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_char, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_float, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_struct, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 34 } } },
};
const s86_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 36 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 35 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 37 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 38 } },
};
const s86_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 40 },
    .{ .symbol = sym_call_expression, .state = 41 },
    .{ .symbol = sym_expression, .state = 88 },
    .{ .symbol = sym_primary_expression, .state = 42 },
};
const s87_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 46 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 46 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 46 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 46 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 46 } } },
    .{ .symbol = sym_slash, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 46 } } },
    .{ .symbol = sym_star, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 46 } } },
};
const s88_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 3, .production_id = 49 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 63 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 3, .production_id = 49 } } },
    .{ .symbol = sym_slash, .action = .{ .shift = 66 } },
    .{ .symbol = sym_star, .action = .{ .shift = 65 } },
};

const parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = s0_actions, .gotos = s0_gotos }, // 0
    .{ .actions = s1_actions }, // 1
    .{ .actions = s2_actions }, // 2
    .{ .actions = s3_actions }, // 3
    .{ .actions = s4_actions }, // 4
    .{ .actions = s5_actions }, // 5
    .{ .actions = s6_actions }, // 6
    .{ .actions = s7_actions }, // 7
    .{ .actions = s8_actions }, // 8
    .{ .actions = s9_actions, .gotos = s9_gotos }, // 9
    .{ .actions = s10_actions }, // 10
    .{ .actions = s11_actions }, // 11
    .{ .actions = s12_actions }, // 12
    .{ .actions = s13_actions, .gotos = s13_gotos }, // 13
    .{ .actions = s14_actions }, // 14
    .{ .actions = s15_actions }, // 15
    .{ .actions = s16_actions }, // 16
    .{ .actions = s17_actions }, // 17
    .{ .actions = s18_actions }, // 18
    .{ .actions = s19_actions, .gotos = s19_gotos }, // 19
    .{ .actions = s20_actions }, // 20
    .{ .actions = s21_actions, .gotos = s21_gotos }, // 21
    .{ .actions = s22_actions, .gotos = s22_gotos }, // 22
    .{ .actions = s23_actions, .gotos = s23_gotos }, // 23
    .{ .actions = s24_actions, .gotos = s24_gotos }, // 24
    .{ .actions = s25_actions }, // 25
    .{ .actions = s26_actions }, // 26
    .{ .actions = s27_actions, .gotos = s27_gotos }, // 27
    .{ .actions = s28_actions }, // 28
    .{ .actions = s29_actions }, // 29
    .{ .actions = s30_actions }, // 30
    .{ .actions = s31_actions }, // 31
    .{ .actions = s32_actions }, // 32
    .{ .actions = s33_actions }, // 33
    .{ .actions = s34_actions }, // 34
    .{ .actions = s35_actions, .gotos = s35_gotos }, // 35
    .{ .actions = s36_actions }, // 36
    .{ .actions = s37_actions }, // 37
    .{ .actions = s38_actions }, // 38
    .{ .actions = s39_actions }, // 39
    .{ .actions = s40_actions }, // 40
    .{ .actions = s41_actions }, // 41
    .{ .actions = s42_actions }, // 42
    .{ .actions = s43_actions, .gotos = s43_gotos }, // 43
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
    .{ .actions = s54_actions }, // 54
    .{ .actions = s55_actions }, // 55
    .{ .actions = s56_actions }, // 56
    .{ .actions = s57_actions }, // 57
    .{ .actions = s58_actions, .gotos = s58_gotos }, // 58
    .{ .actions = s59_actions }, // 59
    .{ .actions = s60_actions }, // 60
    .{ .actions = s61_actions }, // 61
    .{ .actions = s62_actions, .gotos = s62_gotos }, // 62
    .{ .actions = s63_actions, .gotos = s63_gotos }, // 63
    .{ .actions = s64_actions, .gotos = s64_gotos }, // 64
    .{ .actions = s65_actions, .gotos = s65_gotos }, // 65
    .{ .actions = s66_actions, .gotos = s66_gotos }, // 66
    .{ .actions = s67_actions }, // 67
    .{ .actions = s68_actions }, // 68
    .{ .actions = s69_actions }, // 69
    .{ .actions = s70_actions }, // 70
    .{ .actions = s71_actions }, // 71
    .{ .actions = s72_actions }, // 72
    .{ .actions = s73_actions }, // 73
    .{ .actions = s74_actions }, // 74
    .{ .actions = s75_actions }, // 75
    .{ .actions = s76_actions }, // 76
    .{ .actions = s77_actions }, // 77
    .{ .actions = s78_actions }, // 78
    .{ .actions = s79_actions }, // 79
    .{ .actions = s80_actions }, // 80
    .{ .actions = s81_actions }, // 81
    .{ .actions = s82_actions }, // 82
    .{ .actions = s83_actions }, // 83
    .{ .actions = s84_actions }, // 84
    .{ .actions = s85_actions }, // 85
    .{ .actions = s86_actions, .gotos = s86_gotos }, // 86
    .{ .actions = s87_actions }, // 87
    .{ .actions = s88_actions }, // 88
};

const field_names: []const []const u8 = &.{ "name", "body", "type", "declarator", "argument", "value", "left", "right", "function", "arguments" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 7, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 3 } } },
    .{ .production_id = 8, .bindings = &.{.{ .name = "name", .child_index = 1 }} },
    .{ .production_id = 11, .bindings = &.{ .{ .name = "type", .child_index = 0 }, .{ .name = "declarator", .child_index = 1 } } },
    .{ .production_id = 12, .bindings = &.{ .{ .name = "type", .child_index = 0 }, .{ .name = "declarator", .child_index = 1 }, .{ .name = "body", .child_index = 2 } } },
    .{ .production_id = 18, .bindings = &.{ .{ .name = "type", .child_index = 0 }, .{ .name = "declarator", .child_index = 1 } } },
    .{ .production_id = 34, .bindings = &.{.{ .name = "argument", .child_index = 1 }} },
    .{ .production_id = 37, .bindings = &.{ .{ .name = "type", .child_index = 0 }, .{ .name = "declarator", .child_index = 1 }, .{ .name = "value", .child_index = 3 } } },
    .{ .production_id = 38, .bindings = &.{ .{ .name = "type", .child_index = 0 }, .{ .name = "declarator", .child_index = 1 } } },
    .{ .production_id = 42, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 43, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 44, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 45, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 46, .bindings = &.{ .{ .name = "function", .child_index = 0 }, .{ .name = "arguments", .child_index = 2 } } },
    .{ .production_id = 47, .bindings = &.{.{ .name = "function", .child_index = 0 }} },
};

pub const language: Language = .{
    .metadata = .{
        .name = "c",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.3",
        .symbol_count = 47,
        .state_count = 89,
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

test "parser: c table verification" {
    try std.testing.expectEqualStrings("c", language.metadata.name);
    try std.testing.expect(language.metadata.symbol_count > 0);
    try std.testing.expect(language.table.stateCount() > 0);
}

test "parser: c node types verification" {
    var nt = try treesitter.NodeTypes.parseJSON(std.testing.allocator, node_types_json);
    defer nt.deinit();
    try std.testing.expect(nt.findType("translation_unit") != null);
}

test "parser: c grammar json verification" {
    var dsl = treesitter.DSLParser.init(std.testing.allocator);
    var g = try dsl.parseJSON(grammar_json);
    defer g.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("c", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}

test "parser: c genuine program parsing 1" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("int main(void) { return 0; }");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("translation_unit", root.nodeType());
}

test "parser: c genuine program parsing 2" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("int add(int a, int b) { return a + b; }");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("translation_unit", root.nodeType());
}

test "parser: c genuine program parsing 3" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("struct Cluster { int id; double weight; };");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("translation_unit", root.nodeType());
}
