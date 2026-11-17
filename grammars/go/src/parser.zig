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
pub const sym_package: u16 = 1;
pub const sym_import: u16 = 2;
pub const sym_func: u16 = 3;
pub const sym_type: u16 = 4;
pub const sym_struct: u16 = 5;
pub const sym_var: u16 = 6;
pub const sym_return: u16 = 7;
pub const sym_colon_eq: u16 = 8;
pub const sym_semi: u16 = 9;
pub const sym_comma: u16 = 10;
pub const sym_lparen: u16 = 11;
pub const sym_rparen: u16 = 12;
pub const sym_lbrace: u16 = 13;
pub const sym_rbrace: u16 = 14;
pub const sym_eq: u16 = 15;
pub const sym_plus: u16 = 16;
pub const sym_minus: u16 = 17;
pub const sym_identifier: u16 = 18;
pub const sym_int_literal: u16 = 19;
pub const sym_string_literal: u16 = 20;
pub const sym_whitespace: u16 = 21;
pub const sym_comment: u16 = 22;
pub const sym_source_file: u16 = 23;
pub const sym_package_clause: u16 = 24;
pub const sym_import_declaration: u16 = 25;
pub const sym_declarations: u16 = 26;
pub const sym_declaration: u16 = 27;
pub const sym_function_declaration: u16 = 28;
pub const sym_parameter_list: u16 = 29;
pub const sym_parameter_declaration: u16 = 30;
pub const sym_type_declaration: u16 = 31;
pub const sym_struct_fields: u16 = 32;
pub const sym_struct_field: u16 = 33;
pub const sym_var_declaration: u16 = 34;
pub const sym_block: u16 = 35;
pub const sym_statements: u16 = 36;
pub const sym_statement: u16 = 37;
pub const sym_short_var_declaration: u16 = 38;
pub const sym_return_statement: u16 = 39;
pub const sym_expression_statement: u16 = 40;
pub const sym_expression: u16 = 41;
pub const sym_binary_expression: u16 = 42;
pub const sym_call_expression: u16 = 43;
pub const sym_argument_list: u16 = 44;
pub const sym_primary_expression: u16 = 45;
pub const sym_type_identifier: u16 = 46;
pub const sym_ERROR: u16 = 47;

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
    .{ .id = sym_package, .name = "package", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_import, .name = "import", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_func, .name = "func", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_type, .name = "type", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_struct, .name = "struct", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_var, .name = "var", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_return, .name = "return", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_colon_eq, .name = ":=", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_semi, .name = ";", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_comma, .name = ",", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lparen, .name = "(", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rparen, .name = ")", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lbrace, .name = "{", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rbrace, .name = "}", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_eq, .name = "=", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_plus, .name = "+", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_minus, .name = "-", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_int_literal, .name = "int_literal", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_string_literal, .name = "string_literal", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = true, .named = false, .extra = true } },
    .{ .id = sym_comment, .name = "comment", .kind = .terminal, .metadata = .{ .visible = true, .named = true, .extra = true } },
    .{ .id = sym_source_file, .name = "source_file", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_package_clause, .name = "package_clause", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_import_declaration, .name = "import_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declarations, .name = "declarations", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declaration, .name = "declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_function_declaration, .name = "function_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_parameter_list, .name = "parameter_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_parameter_declaration, .name = "parameter_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_type_declaration, .name = "type_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_struct_fields, .name = "struct_fields", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_struct_field, .name = "struct_field", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_var_declaration, .name = "var_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_block, .name = "block", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statements, .name = "statements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statement, .name = "statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_short_var_declaration, .name = "short_var_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_return_statement, .name = "return_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression_statement, .name = "expression_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression, .name = "expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_binary_expression, .name = "binary_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_call_expression, .name = "call_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_argument_list, .name = "argument_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_primary_expression, .name = "primary_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_type_identifier, .name = "type_identifier", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_ERROR, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_package, .match = matchKeyword("package") },
    .{ .symbol = sym_import, .match = matchKeyword("import") },
    .{ .symbol = sym_func, .match = matchKeyword("func") },
    .{ .symbol = sym_type, .match = matchKeyword("type") },
    .{ .symbol = sym_struct, .match = matchKeyword("struct") },
    .{ .symbol = sym_var, .match = matchKeyword("var") },
    .{ .symbol = sym_return, .match = matchKeyword("return") },
    .{ .symbol = sym_colon_eq, .match = matchLiteral(":=") },
    .{ .symbol = sym_semi, .match = language_mod.matchChar(';') },
    .{ .symbol = sym_comma, .match = language_mod.matchChar(',') },
    .{ .symbol = sym_lparen, .match = language_mod.matchChar('(') },
    .{ .symbol = sym_rparen, .match = language_mod.matchChar(')') },
    .{ .symbol = sym_lbrace, .match = language_mod.matchChar('{') },
    .{ .symbol = sym_rbrace, .match = language_mod.matchChar('}') },
    .{ .symbol = sym_eq, .match = language_mod.matchChar('=') },
    .{ .symbol = sym_plus, .match = language_mod.matchChar('+') },
    .{ .symbol = sym_minus, .match = language_mod.matchChar('-') },
    .{ .symbol = sym_identifier, .match = matchIdentifier },
    .{ .symbol = sym_int_literal, .match = matchNumber },
    .{ .symbol = sym_string_literal, .match = matchString },
    .{ .symbol = sym_whitespace, .match = language_mod.matchWhitespace },
    .{ .symbol = sym_comment, .match = matchComment },
};

const extra_symbols: []const u16 = &.{ sym_whitespace, sym_comment };

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_package, .action = .{ .shift = 1 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_package_clause, .state = 3 },
    .{ .symbol = sym_source_file, .state = 2 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 4 } },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_func, .action = .{ .shift = 6 } },
    .{ .symbol = sym_import, .action = .{ .shift = 5 } },
    .{ .symbol = sym_type, .action = .{ .shift = 7 } },
    .{ .symbol = sym_var, .action = .{ .shift = 8 } },
};
const s3_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_declaration, .state = 11 },
    .{ .symbol = sym_declarations, .state = 10 },
    .{ .symbol = sym_function_declaration, .state = 12 },
    .{ .symbol = sym_import_declaration, .state = 9 },
    .{ .symbol = sym_type_declaration, .state = 13 },
    .{ .symbol = sym_var_declaration, .state = 14 },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_package_clause, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_import, .action = .{ .reduce = .{ .symbol = sym_package_clause, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_package_clause, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_package_clause, .child_count = 2, .production_id = 3 } } },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_string_literal, .action = .{ .shift = 15 } },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 16 } },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 17 } },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 18 } },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_func, .action = .{ .shift = 6 } },
    .{ .symbol = sym_type, .action = .{ .shift = 7 } },
    .{ .symbol = sym_var, .action = .{ .shift = 8 } },
};
const s9_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_declaration, .state = 11 },
    .{ .symbol = sym_declarations, .state = 19 },
    .{ .symbol = sym_function_declaration, .state = 12 },
    .{ .symbol = sym_type_declaration, .state = 13 },
    .{ .symbol = sym_var_declaration, .state = 14 },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_source_file, .child_count = 2, .production_id = 1 } } },
    .{ .symbol = sym_func, .action = .{ .shift = 6 } },
    .{ .symbol = sym_type, .action = .{ .shift = 7 } },
    .{ .symbol = sym_var, .action = .{ .shift = 8 } },
};
const s10_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_declaration, .state = 20 },
    .{ .symbol = sym_function_declaration, .state = 12 },
    .{ .symbol = sym_type_declaration, .state = 13 },
    .{ .symbol = sym_var_declaration, .state = 14 },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 5 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 5 } } },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 7 } } },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 8 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 8 } } },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 9 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 9 } } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_import_declaration, .child_count = 2, .production_id = 4 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_import_declaration, .child_count = 2, .production_id = 4 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_import_declaration, .child_count = 2, .production_id = 4 } } },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lparen, .action = .{ .shift = 21 } },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_struct, .action = .{ .shift = 22 } },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 23 } },
};
const s18_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_type_identifier, .state = 24 },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_source_file, .child_count = 3, .production_id = 2 } } },
    .{ .symbol = sym_func, .action = .{ .shift = 6 } },
    .{ .symbol = sym_type, .action = .{ .shift = 7 } },
    .{ .symbol = sym_var, .action = .{ .shift = 8 } },
};
const s19_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_declaration, .state = 20 },
    .{ .symbol = sym_function_declaration, .state = 12 },
    .{ .symbol = sym_type_declaration, .state = 13 },
    .{ .symbol = sym_var_declaration, .state = 14 },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 6 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 6 } } },
};
const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 26 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 25 } },
};
const s21_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_parameter_declaration, .state = 28 },
    .{ .symbol = sym_parameter_list, .state = 27 },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 29 } },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_type_identifier, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_type_identifier, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_eq, .action = .{ .reduce = .{ .symbol = sym_type_identifier, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_type_identifier, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_identifier, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_type_identifier, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_type_identifier, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_type_identifier, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_type_identifier, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_type_identifier, .child_count = 1, .production_id = 46 } } },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_var_declaration, .child_count = 3, .production_id = 22 } } },
    .{ .symbol = sym_eq, .action = .{ .shift = 30 } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_var_declaration, .child_count = 3, .production_id = 22 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_var_declaration, .child_count = 3, .production_id = 22 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_var_declaration, .child_count = 3, .production_id = 22 } } },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 23 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 31 } },
};
const s25_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_block, .state = 32 },
    .{ .symbol = sym_type_identifier, .state = 33 },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 23 } },
};
const s26_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_type_identifier, .state = 34 },
};
const s27_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 35 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 36 } },
};
const s28_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 13 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 13 } } },
};
const s29_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 38 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 37 } },
};
const s29_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_struct_field, .state = 40 },
    .{ .symbol = sym_struct_fields, .state = 39 },
};
const s30_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 41 } },
    .{ .symbol = sym_int_literal, .action = .{ .shift = 42 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 43 } },
};
const s30_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 45 },
    .{ .symbol = sym_call_expression, .state = 46 },
    .{ .symbol = sym_expression, .state = 44 },
    .{ .symbol = sym_primary_expression, .state = 47 },
};
const s31_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 50 } },
    .{ .symbol = sym_int_literal, .action = .{ .shift = 42 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 49 } },
    .{ .symbol = sym_return, .action = .{ .shift = 48 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 43 } },
};
const s31_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 45 },
    .{ .symbol = sym_call_expression, .state = 46 },
    .{ .symbol = sym_expression, .state = 56 },
    .{ .symbol = sym_expression_statement, .state = 55 },
    .{ .symbol = sym_primary_expression, .state = 47 },
    .{ .symbol = sym_return_statement, .state = 54 },
    .{ .symbol = sym_short_var_declaration, .state = 53 },
    .{ .symbol = sym_statement, .state = 52 },
    .{ .symbol = sym_statements, .state = 51 },
};
const s32_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 12 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 12 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 12 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 5, .production_id = 12 } } },
};
const s33_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 31 } },
};
const s33_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_block, .state = 57 },
};
const s34_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_declaration, .child_count = 2, .production_id = 15 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_declaration, .child_count = 2, .production_id = 15 } } },
};
const s35_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 26 } },
};
const s35_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_parameter_declaration, .state = 58 },
};
const s36_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 23 } },
};
const s36_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_type_identifier, .state = 59 },
};
const s37_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_type_declaration, .child_count = 5, .production_id = 17 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_type_declaration, .child_count = 5, .production_id = 17 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_type_declaration, .child_count = 5, .production_id = 17 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_type_declaration, .child_count = 5, .production_id = 17 } } },
};
const s38_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 23 } },
};
const s38_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_type_identifier, .state = 60 },
};
const s39_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 38 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 61 } },
};
const s39_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_struct_field, .state = 62 },
};
const s40_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 1, .production_id = 18 } } },
};
const s41_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 63 } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
};
const s42_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 44 } } },
};
const s43_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 45 } } },
};
const s44_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_var_declaration, .child_count = 5, .production_id = 21 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_var_declaration, .child_count = 5, .production_id = 21 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 65 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_var_declaration, .child_count = 5, .production_id = 21 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_var_declaration, .child_count = 5, .production_id = 21 } } },
};
const s45_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 34 } } },
};
const s46_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 35 } } },
};
const s47_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 36 } } },
};
const s48_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 41 } },
    .{ .symbol = sym_int_literal, .action = .{ .shift = 42 } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 43 } },
};
const s48_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 45 },
    .{ .symbol = sym_call_expression, .state = 46 },
    .{ .symbol = sym_expression, .state = 66 },
    .{ .symbol = sym_primary_expression, .state = 47 },
};
const s49_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 23 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 23 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 23 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 23 } } },
};
const s50_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon_eq, .action = .{ .shift = 67 } },
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 63 } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
};
const s51_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 50 } },
    .{ .symbol = sym_int_literal, .action = .{ .shift = 42 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 68 } },
    .{ .symbol = sym_return, .action = .{ .shift = 48 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 43 } },
};
const s51_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 45 },
    .{ .symbol = sym_call_expression, .state = 46 },
    .{ .symbol = sym_expression, .state = 56 },
    .{ .symbol = sym_expression_statement, .state = 55 },
    .{ .symbol = sym_primary_expression, .state = 47 },
    .{ .symbol = sym_return_statement, .state = 54 },
    .{ .symbol = sym_short_var_declaration, .state = 53 },
    .{ .symbol = sym_statement, .state = 69 },
};
const s52_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 25 } } },
};
const s53_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 27 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 27 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 27 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 27 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 27 } } },
};
const s54_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 28 } } },
};
const s55_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 29 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 29 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 29 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 29 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 29 } } },
};
const s56_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 65 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 33 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 1, .production_id = 33 } } },
};
const s57_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 11 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 11 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 11 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 6, .production_id = 11 } } },
};
const s58_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 3, .production_id = 14 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 3, .production_id = 14 } } },
};
const s59_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 31 } },
};
const s59_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_block, .state = 70 },
};
const s60_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_struct_field, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_struct_field, .child_count = 2, .production_id = 20 } } },
};
const s61_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_type_declaration, .child_count = 6, .production_id = 16 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_type_declaration, .child_count = 6, .production_id = 16 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_type_declaration, .child_count = 6, .production_id = 16 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_type_declaration, .child_count = 6, .production_id = 16 } } },
};
const s62_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 2, .production_id = 19 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_struct_fields, .child_count = 2, .production_id = 19 } } },
};
const s63_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 41 } },
    .{ .symbol = sym_int_literal, .action = .{ .shift = 42 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 71 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 43 } },
};
const s63_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_argument_list, .state = 73 },
    .{ .symbol = sym_binary_expression, .state = 45 },
    .{ .symbol = sym_call_expression, .state = 46 },
    .{ .symbol = sym_expression, .state = 72 },
    .{ .symbol = sym_primary_expression, .state = 47 },
};
const s64_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 74 } },
    .{ .symbol = sym_int_literal, .action = .{ .shift = 42 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 43 } },
};
const s64_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary_expression, .state = 75 },
};
const s65_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 74 } },
    .{ .symbol = sym_int_literal, .action = .{ .shift = 42 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 43 } },
};
const s65_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary_expression, .state = 76 },
};
const s66_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 65 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 31 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 31 } } },
};
const s67_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 41 } },
    .{ .symbol = sym_int_literal, .action = .{ .shift = 42 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 43 } },
};
const s67_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 45 },
    .{ .symbol = sym_call_expression, .state = 46 },
    .{ .symbol = sym_expression, .state = 77 },
    .{ .symbol = sym_primary_expression, .state = 47 },
};
const s68_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 24 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 24 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 24 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 24 } } },
};
const s69_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 26 } } },
};
const s70_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 7, .production_id = 10 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 7, .production_id = 10 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 7, .production_id = 10 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_function_declaration, .child_count = 7, .production_id = 10 } } },
};
const s71_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 40 } } },
};
const s72_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 1, .production_id = 41 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 65 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 1, .production_id = 41 } } },
};
const s73_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 78 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 79 } },
};
const s74_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 43 } } },
};
const s75_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 37 } } },
};
const s76_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 38 } } },
};
const s77_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_short_var_declaration, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_short_var_declaration, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 65 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_short_var_declaration, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_short_var_declaration, .child_count = 3, .production_id = 30 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_short_var_declaration, .child_count = 3, .production_id = 30 } } },
};
const s78_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 41 } },
    .{ .symbol = sym_int_literal, .action = .{ .shift = 42 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 43 } },
};
const s78_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 45 },
    .{ .symbol = sym_call_expression, .state = 46 },
    .{ .symbol = sym_expression, .state = 80 },
    .{ .symbol = sym_primary_expression, .state = 47 },
};
const s79_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_func, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_int_literal, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_type, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
    .{ .symbol = sym_var, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 39 } } },
};
const s80_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 3, .production_id = 42 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 65 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 3, .production_id = 42 } } },
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
    .{ .actions = s9_actions, .gotos = s9_gotos }, // 9
    .{ .actions = s10_actions, .gotos = s10_gotos }, // 10
    .{ .actions = s11_actions }, // 11
    .{ .actions = s12_actions }, // 12
    .{ .actions = s13_actions }, // 13
    .{ .actions = s14_actions }, // 14
    .{ .actions = s15_actions }, // 15
    .{ .actions = s16_actions }, // 16
    .{ .actions = s17_actions }, // 17
    .{ .actions = s18_actions, .gotos = s18_gotos }, // 18
    .{ .actions = s19_actions, .gotos = s19_gotos }, // 19
    .{ .actions = s20_actions }, // 20
    .{ .actions = s21_actions, .gotos = s21_gotos }, // 21
    .{ .actions = s22_actions }, // 22
    .{ .actions = s23_actions }, // 23
    .{ .actions = s24_actions }, // 24
    .{ .actions = s25_actions, .gotos = s25_gotos }, // 25
    .{ .actions = s26_actions, .gotos = s26_gotos }, // 26
    .{ .actions = s27_actions }, // 27
    .{ .actions = s28_actions }, // 28
    .{ .actions = s29_actions, .gotos = s29_gotos }, // 29
    .{ .actions = s30_actions, .gotos = s30_gotos }, // 30
    .{ .actions = s31_actions, .gotos = s31_gotos }, // 31
    .{ .actions = s32_actions }, // 32
    .{ .actions = s33_actions, .gotos = s33_gotos }, // 33
    .{ .actions = s34_actions }, // 34
    .{ .actions = s35_actions, .gotos = s35_gotos }, // 35
    .{ .actions = s36_actions, .gotos = s36_gotos }, // 36
    .{ .actions = s37_actions }, // 37
    .{ .actions = s38_actions, .gotos = s38_gotos }, // 38
    .{ .actions = s39_actions, .gotos = s39_gotos }, // 39
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
    .{ .actions = s51_actions, .gotos = s51_gotos }, // 51
    .{ .actions = s52_actions }, // 52
    .{ .actions = s53_actions }, // 53
    .{ .actions = s54_actions }, // 54
    .{ .actions = s55_actions }, // 55
    .{ .actions = s56_actions }, // 56
    .{ .actions = s57_actions }, // 57
    .{ .actions = s58_actions }, // 58
    .{ .actions = s59_actions, .gotos = s59_gotos }, // 59
    .{ .actions = s60_actions }, // 60
    .{ .actions = s61_actions }, // 61
    .{ .actions = s62_actions }, // 62
    .{ .actions = s63_actions, .gotos = s63_gotos }, // 63
    .{ .actions = s64_actions, .gotos = s64_gotos }, // 64
    .{ .actions = s65_actions, .gotos = s65_gotos }, // 65
    .{ .actions = s66_actions }, // 66
    .{ .actions = s67_actions, .gotos = s67_gotos }, // 67
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
    .{ .actions = s78_actions, .gotos = s78_gotos }, // 78
    .{ .actions = s79_actions }, // 79
    .{ .actions = s80_actions }, // 80
};

const field_names: []const []const u8 = &.{ "package", "name", "parameters", "result", "body", "type", "value", "left", "right", "argument", "function", "arguments" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 3, .bindings = &.{.{ .name = "package", .child_index = 1 }} },
    .{ .production_id = 10, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "parameters", .child_index = 3 }, .{ .name = "result", .child_index = 5 }, .{ .name = "body", .child_index = 6 } } },
    .{ .production_id = 11, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "result", .child_index = 4 }, .{ .name = "body", .child_index = 5 } } },
    .{ .production_id = 12, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 4 } } },
    .{ .production_id = 15, .bindings = &.{ .{ .name = "name", .child_index = 0 }, .{ .name = "type", .child_index = 1 } } },
    .{ .production_id = 16, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 4 } } },
    .{ .production_id = 17, .bindings = &.{.{ .name = "name", .child_index = 1 }} },
    .{ .production_id = 20, .bindings = &.{ .{ .name = "name", .child_index = 0 }, .{ .name = "type", .child_index = 1 } } },
    .{ .production_id = 21, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "type", .child_index = 2 }, .{ .name = "value", .child_index = 4 } } },
    .{ .production_id = 22, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "type", .child_index = 2 } } },
    .{ .production_id = 30, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 31, .bindings = &.{.{ .name = "argument", .child_index = 1 }} },
    .{ .production_id = 37, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 38, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 39, .bindings = &.{ .{ .name = "function", .child_index = 0 }, .{ .name = "arguments", .child_index = 2 } } },
    .{ .production_id = 40, .bindings = &.{.{ .name = "function", .child_index = 0 }} },
};

pub const language: Language = .{
    .metadata = .{
        .name = "go",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.3",
        .symbol_count = 48,
        .state_count = 81,
        .field_count = 12,
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

test "parser: go table verification" {
    try std.testing.expectEqualStrings("go", language.metadata.name);
    try std.testing.expect(language.metadata.symbol_count > 0);
    try std.testing.expect(language.table.stateCount() > 0);
}

test "parser: go node types verification" {
    var nt = try treesitter.NodeTypes.parseJSON(std.testing.allocator, node_types_json);
    defer nt.deinit();
    try std.testing.expect(nt.findType("source_file") != null);
}

test "parser: go grammar json verification" {
    var dsl = treesitter.DSLParser.init(std.testing.allocator);
    var g = try dsl.parseJSON(grammar_json);
    defer g.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("go", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}

test "parser: go genuine program parsing 1" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("package main\nfunc add(a int, b int) int { return a + b }\n");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("source_file", root.nodeType());
}

test "parser: go genuine program parsing 2" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("package main\nimport \"fmt\"\ntype Point struct { x int }\n");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("source_file", root.nodeType());
}
