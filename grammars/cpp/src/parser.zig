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
pub const sym_namespace: u16 = 1;
pub const sym_class: u16 = 2;
pub const sym_public: u16 = 3;
pub const sym_private: u16 = 4;
pub const sym_protected: u16 = 5;
pub const sym_int: u16 = 6;
pub const sym_void: u16 = 7;
pub const sym_bool: u16 = 8;
pub const sym_double: u16 = 9;
pub const sym_auto: u16 = 10;
pub const sym_return: u16 = 11;
pub const sym_this: u16 = 12;
pub const sym_coloncolon: u16 = 13;
pub const sym_semi: u16 = 14;
pub const sym_colon: u16 = 15;
pub const sym_comma: u16 = 16;
pub const sym_lparen: u16 = 17;
pub const sym_rparen: u16 = 18;
pub const sym_lbrace: u16 = 19;
pub const sym_rbrace: u16 = 20;
pub const sym_plus: u16 = 21;
pub const sym_minus: u16 = 22;
pub const sym_star: u16 = 23;
pub const sym_eq: u16 = 24;
pub const sym_shl: u16 = 25;
pub const sym_identifier: u16 = 26;
pub const sym_number_literal: u16 = 27;
pub const sym_string_literal: u16 = 28;
pub const sym_whitespace: u16 = 29;
pub const sym_comment: u16 = 30;
pub const sym_translation_unit: u16 = 31;
pub const sym_declarations: u16 = 32;
pub const sym_declaration: u16 = 33;
pub const sym_namespace_definition: u16 = 34;
pub const sym_class_specifier: u16 = 35;
pub const sym_member_list: u16 = 36;
pub const sym_member_item: u16 = 37;
pub const sym_access_specifier: u16 = 38;
pub const sym_function_definition: u16 = 39;
pub const sym_declarator: u16 = 40;
pub const sym_qualified_identifier: u16 = 41;
pub const sym_parameter_list: u16 = 42;
pub const sym_parameter_declaration: u16 = 43;
pub const sym_type_specifier: u16 = 44;
pub const sym_compound_statement: u16 = 45;
pub const sym_statements: u16 = 46;
pub const sym_statement: u16 = 47;
pub const sym_return_statement: u16 = 48;
pub const sym_expression_statement: u16 = 49;
pub const sym_variable_declaration: u16 = 50;
pub const sym_expression: u16 = 51;
pub const sym_binary_expression: u16 = 52;
pub const sym_call_expression: u16 = 53;
pub const sym_argument_list: u16 = 54;
pub const sym_primary_expression: u16 = 55;
pub const sym_ERROR: u16 = 56;

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
    .{ .id = sym_namespace, .name = "namespace", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_class, .name = "class", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_public, .name = "public", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_private, .name = "private", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_protected, .name = "protected", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_int, .name = "int", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_void, .name = "void", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_bool, .name = "bool", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_double, .name = "double", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_auto, .name = "auto", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_return, .name = "return", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_this, .name = "this", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_coloncolon, .name = "::", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_semi, .name = ";", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_colon, .name = ":", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_comma, .name = ",", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lparen, .name = "(", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rparen, .name = ")", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lbrace, .name = "{", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rbrace, .name = "}", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_plus, .name = "+", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_minus, .name = "-", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_star, .name = "*", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_eq, .name = "=", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_shl, .name = "<<", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_number_literal, .name = "number_literal", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_string_literal, .name = "string_literal", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = true, .named = false, .extra = true } },
    .{ .id = sym_comment, .name = "comment", .kind = .terminal, .metadata = .{ .visible = true, .named = true, .extra = true } },
    .{ .id = sym_translation_unit, .name = "translation_unit", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declarations, .name = "declarations", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declaration, .name = "declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_namespace_definition, .name = "namespace_definition", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_class_specifier, .name = "class_specifier", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_member_list, .name = "member_list", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_member_item, .name = "member_item", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_access_specifier, .name = "access_specifier", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_function_definition, .name = "function_definition", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_declarator, .name = "declarator", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_qualified_identifier, .name = "qualified_identifier", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
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
    .{ .symbol = sym_namespace, .match = matchKeyword("namespace") },
    .{ .symbol = sym_class, .match = matchKeyword("class") },
    .{ .symbol = sym_public, .match = matchKeyword("public") },
    .{ .symbol = sym_private, .match = matchKeyword("private") },
    .{ .symbol = sym_protected, .match = matchKeyword("protected") },
    .{ .symbol = sym_int, .match = matchKeyword("int") },
    .{ .symbol = sym_void, .match = matchKeyword("void") },
    .{ .symbol = sym_bool, .match = matchKeyword("bool") },
    .{ .symbol = sym_double, .match = matchKeyword("double") },
    .{ .symbol = sym_auto, .match = matchKeyword("auto") },
    .{ .symbol = sym_return, .match = matchKeyword("return") },
    .{ .symbol = sym_this, .match = matchKeyword("this") },
    .{ .symbol = sym_coloncolon, .match = matchLiteral("::") },
    .{ .symbol = sym_semi, .match = language_mod.matchChar(';') },
    .{ .symbol = sym_colon, .match = language_mod.matchChar(':') },
    .{ .symbol = sym_comma, .match = language_mod.matchChar(',') },
    .{ .symbol = sym_lparen, .match = language_mod.matchChar('(') },
    .{ .symbol = sym_rparen, .match = language_mod.matchChar(')') },
    .{ .symbol = sym_lbrace, .match = language_mod.matchChar('{') },
    .{ .symbol = sym_rbrace, .match = language_mod.matchChar('}') },
    .{ .symbol = sym_plus, .match = language_mod.matchChar('+') },
    .{ .symbol = sym_minus, .match = language_mod.matchChar('-') },
    .{ .symbol = sym_star, .match = language_mod.matchChar('*') },
    .{ .symbol = sym_eq, .match = language_mod.matchChar('=') },
    .{ .symbol = sym_shl, .match = matchLiteral("<<") },
    .{ .symbol = sym_identifier, .match = matchIdentifier },
    .{ .symbol = sym_number_literal, .match = matchNumber },
    .{ .symbol = sym_string_literal, .match = matchString },
    .{ .symbol = sym_whitespace, .match = language_mod.matchWhitespace },
    .{ .symbol = sym_comment, .match = matchComment },
};

const extra_symbols: []const u16 = &.{ sym_whitespace, sym_comment };

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .shift = 7 } },
    .{ .symbol = sym_bool, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_int, .action = .{ .shift = 3 } },
    .{ .symbol = sym_namespace, .action = .{ .shift = 1 } },
    .{ .symbol = sym_void, .action = .{ .shift = 4 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_specifier, .state = 13 },
    .{ .symbol = sym_declaration, .state = 11 },
    .{ .symbol = sym_declarations, .state = 10 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_namespace_definition, .state = 12 },
    .{ .symbol = sym_qualified_identifier, .state = 15 },
    .{ .symbol = sym_translation_unit, .state = 9 },
    .{ .symbol = sym_type_specifier, .state = 16 },
    .{ .symbol = sym_variable_declaration, .state = 17 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 18 } },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 19 } },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 27 } } },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 28 } } },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 29 } } },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 30 } } },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 31 } } },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_coloncolon, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 1, .production_id = 22 } } },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .shift = 7 } },
    .{ .symbol = sym_bool, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 6 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_translation_unit, .child_count = 1, .production_id = 1 } } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_int, .action = .{ .shift = 3 } },
    .{ .symbol = sym_namespace, .action = .{ .shift = 1 } },
    .{ .symbol = sym_void, .action = .{ .shift = 4 } },
};
const s10_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_specifier, .state = 13 },
    .{ .symbol = sym_declaration, .state = 20 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_namespace_definition, .state = 12 },
    .{ .symbol = sym_qualified_identifier, .state = 15 },
    .{ .symbol = sym_type_specifier, .state = 16 },
    .{ .symbol = sym_variable_declaration, .state = 17 },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 1, .production_id = 2 } } },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 4 } } },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 21 } },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 1, .production_id = 6 } } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_coloncolon, .action = .{ .shift = 22 } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 32 } } },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 23 } },
};
const s16_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_declarator, .state = 24 },
    .{ .symbol = sym_qualified_identifier, .state = 25 },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 26 } },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 27 } },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 28 } },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_declarations, .child_count = 2, .production_id = 3 } } },
};
const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 5 } } },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 29 } },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_coloncolon, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_eq, .action = .{ .shift = 30 } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_variable_declaration, .child_count = 2, .production_id = 45 } } },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 31 } },
};
const s24_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_compound_statement, .state = 32 },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_coloncolon, .action = .{ .shift = 22 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 33 } },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_declaration, .child_count = 2, .production_id = 7 } } },
};
const s27_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .shift = 7 } },
    .{ .symbol = sym_bool, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_int, .action = .{ .shift = 3 } },
    .{ .symbol = sym_namespace, .action = .{ .shift = 1 } },
    .{ .symbol = sym_void, .action = .{ .shift = 4 } },
};
const s27_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_specifier, .state = 13 },
    .{ .symbol = sym_declaration, .state = 11 },
    .{ .symbol = sym_declarations, .state = 34 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_namespace_definition, .state = 12 },
    .{ .symbol = sym_qualified_identifier, .state = 15 },
    .{ .symbol = sym_type_specifier, .state = 16 },
    .{ .symbol = sym_variable_declaration, .state = 17 },
};
const s28_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .shift = 7 } },
    .{ .symbol = sym_bool, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_int, .action = .{ .shift = 3 } },
    .{ .symbol = sym_namespace, .action = .{ .shift = 1 } },
    .{ .symbol = sym_private, .action = .{ .shift = 36 } },
    .{ .symbol = sym_protected, .action = .{ .shift = 37 } },
    .{ .symbol = sym_public, .action = .{ .shift = 35 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 38 } },
    .{ .symbol = sym_void, .action = .{ .shift = 4 } },
};
const s28_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_access_specifier, .state = 42 },
    .{ .symbol = sym_class_specifier, .state = 13 },
    .{ .symbol = sym_declaration, .state = 39 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_member_item, .state = 41 },
    .{ .symbol = sym_member_list, .state = 40 },
    .{ .symbol = sym_namespace_definition, .state = 12 },
    .{ .symbol = sym_qualified_identifier, .state = 15 },
    .{ .symbol = sym_type_specifier, .state = 16 },
    .{ .symbol = sym_variable_declaration, .state = 17 },
};
const s29_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_coloncolon, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 3, .production_id = 23 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 3, .production_id = 23 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 3, .production_id = 23 } } },
};
const s30_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 45 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 44 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 46 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 47 } },
    .{ .symbol = sym_this, .action = .{ .shift = 43 } },
};
const s30_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 50 },
    .{ .symbol = sym_call_expression, .state = 51 },
    .{ .symbol = sym_expression, .state = 49 },
    .{ .symbol = sym_primary_expression, .state = 52 },
    .{ .symbol = sym_qualified_identifier, .state = 48 },
};
const s31_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .shift = 7 } },
    .{ .symbol = sym_bool, .action = .{ .shift = 5 } },
    .{ .symbol = sym_double, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 45 } },
    .{ .symbol = sym_int, .action = .{ .shift = 3 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 31 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 44 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 46 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 54 } },
    .{ .symbol = sym_return, .action = .{ .shift = 53 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 47 } },
    .{ .symbol = sym_this, .action = .{ .shift = 43 } },
    .{ .symbol = sym_void, .action = .{ .shift = 4 } },
};
const s31_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 50 },
    .{ .symbol = sym_call_expression, .state = 51 },
    .{ .symbol = sym_compound_statement, .state = 57 },
    .{ .symbol = sym_expression, .state = 63 },
    .{ .symbol = sym_expression_statement, .state = 61 },
    .{ .symbol = sym_primary_expression, .state = 52 },
    .{ .symbol = sym_qualified_identifier, .state = 55 },
    .{ .symbol = sym_return_statement, .state = 60 },
    .{ .symbol = sym_statement, .state = 59 },
    .{ .symbol = sym_statements, .state = 58 },
    .{ .symbol = sym_type_specifier, .state = 56 },
    .{ .symbol = sym_variable_declaration, .state = 62 },
};
const s32_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_function_definition, .child_count = 3, .production_id = 18 } } },
};
const s33_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .shift = 7 } },
    .{ .symbol = sym_bool, .action = .{ .shift = 5 } },
    .{ .symbol = sym_double, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_int, .action = .{ .shift = 3 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 65 } },
    .{ .symbol = sym_void, .action = .{ .shift = 64 } },
};
const s33_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_parameter_declaration, .state = 67 },
    .{ .symbol = sym_parameter_list, .state = 66 },
    .{ .symbol = sym_qualified_identifier, .state = 15 },
    .{ .symbol = sym_type_specifier, .state = 68 },
};
const s34_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .shift = 7 } },
    .{ .symbol = sym_bool, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_int, .action = .{ .shift = 3 } },
    .{ .symbol = sym_namespace, .action = .{ .shift = 1 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 69 } },
    .{ .symbol = sym_void, .action = .{ .shift = 4 } },
};
const s34_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_specifier, .state = 13 },
    .{ .symbol = sym_declaration, .state = 20 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_namespace_definition, .state = 12 },
    .{ .symbol = sym_qualified_identifier, .state = 15 },
    .{ .symbol = sym_type_specifier, .state = 16 },
    .{ .symbol = sym_variable_declaration, .state = 17 },
};
const s35_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .reduce = .{ .symbol = sym_access_specifier, .child_count = 1, .production_id = 15 } } },
};
const s36_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .reduce = .{ .symbol = sym_access_specifier, .child_count = 1, .production_id = 16 } } },
};
const s37_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .reduce = .{ .symbol = sym_access_specifier, .child_count = 1, .production_id = 17 } } },
};
const s38_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_class_specifier, .child_count = 4, .production_id = 10 } } },
};
const s39_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 1, .production_id = 14 } } },
};
const s40_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .shift = 7 } },
    .{ .symbol = sym_bool, .action = .{ .shift = 5 } },
    .{ .symbol = sym_class, .action = .{ .shift = 2 } },
    .{ .symbol = sym_double, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_int, .action = .{ .shift = 3 } },
    .{ .symbol = sym_namespace, .action = .{ .shift = 1 } },
    .{ .symbol = sym_private, .action = .{ .shift = 36 } },
    .{ .symbol = sym_protected, .action = .{ .shift = 37 } },
    .{ .symbol = sym_public, .action = .{ .shift = 35 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 70 } },
    .{ .symbol = sym_void, .action = .{ .shift = 4 } },
};
const s40_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_access_specifier, .state = 42 },
    .{ .symbol = sym_class_specifier, .state = 13 },
    .{ .symbol = sym_declaration, .state = 39 },
    .{ .symbol = sym_function_definition, .state = 14 },
    .{ .symbol = sym_member_item, .state = 71 },
    .{ .symbol = sym_namespace_definition, .state = 12 },
    .{ .symbol = sym_qualified_identifier, .state = 15 },
    .{ .symbol = sym_type_specifier, .state = 16 },
    .{ .symbol = sym_variable_declaration, .state = 17 },
};
const s41_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 1, .production_id = 11 } } },
};
const s42_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_colon, .action = .{ .shift = 72 } },
};
const s43_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 59 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 59 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 59 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 59 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 59 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 59 } } },
};
const s44_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 45 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 44 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 46 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 47 } },
    .{ .symbol = sym_this, .action = .{ .shift = 43 } },
};
const s44_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 50 },
    .{ .symbol = sym_call_expression, .state = 51 },
    .{ .symbol = sym_expression, .state = 73 },
    .{ .symbol = sym_primary_expression, .state = 52 },
    .{ .symbol = sym_qualified_identifier, .state = 48 },
};
const s45_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_coloncolon, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_qualified_identifier, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
};
const s46_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 57 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 57 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 57 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 57 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 57 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 57 } } },
};
const s47_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 58 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 58 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 58 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 58 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 58 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 58 } } },
};
const s48_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_coloncolon, .action = .{ .shift = 22 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 74 } },
};
const s49_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 76 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 75 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_variable_declaration, .child_count = 4, .production_id = 44 } } },
    .{ .symbol = sym_shl, .action = .{ .shift = 77 } },
};
const s50_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 46 } } },
};
const s51_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 47 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 47 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 47 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 47 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 47 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 47 } } },
};
const s52_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 48 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 48 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 48 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 48 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 48 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 48 } } },
};
const s53_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 45 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 44 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 46 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 78 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 47 } },
    .{ .symbol = sym_this, .action = .{ .shift = 43 } },
};
const s53_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 50 },
    .{ .symbol = sym_call_expression, .state = 51 },
    .{ .symbol = sym_expression, .state = 79 },
    .{ .symbol = sym_primary_expression, .state = 52 },
    .{ .symbol = sym_qualified_identifier, .state = 48 },
};
const s54_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_this, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 2, .production_id = 33 } } },
};
const s55_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_coloncolon, .action = .{ .shift = 22 } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 32 } } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 74 } },
};
const s56_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 80 } },
};
const s57_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_this, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 40 } } },
};
const s58_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .shift = 7 } },
    .{ .symbol = sym_bool, .action = .{ .shift = 5 } },
    .{ .symbol = sym_double, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 45 } },
    .{ .symbol = sym_int, .action = .{ .shift = 3 } },
    .{ .symbol = sym_lbrace, .action = .{ .shift = 31 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 44 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 46 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 81 } },
    .{ .symbol = sym_return, .action = .{ .shift = 53 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 47 } },
    .{ .symbol = sym_this, .action = .{ .shift = 43 } },
    .{ .symbol = sym_void, .action = .{ .shift = 4 } },
};
const s58_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 50 },
    .{ .symbol = sym_call_expression, .state = 51 },
    .{ .symbol = sym_compound_statement, .state = 57 },
    .{ .symbol = sym_expression, .state = 63 },
    .{ .symbol = sym_expression_statement, .state = 61 },
    .{ .symbol = sym_primary_expression, .state = 52 },
    .{ .symbol = sym_qualified_identifier, .state = 55 },
    .{ .symbol = sym_return_statement, .state = 60 },
    .{ .symbol = sym_statement, .state = 82 },
    .{ .symbol = sym_type_specifier, .state = 56 },
    .{ .symbol = sym_variable_declaration, .state = 62 },
};
const s59_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_this, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 35 } } },
};
const s60_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_this, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 37 } } },
};
const s61_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_this, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
};
const s62_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 83 } },
};
const s63_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 76 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 75 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 84 } },
    .{ .symbol = sym_shl, .action = .{ .shift = 77 } },
};
const s64_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_specifier, .child_count = 1, .production_id = 28 } } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 85 } },
};
const s65_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_declarator, .child_count = 3, .production_id = 20 } } },
};
const s66_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 86 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 87 } },
};
const s67_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 24 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 1, .production_id = 24 } } },
};
const s68_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 88 } },
};
const s69_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_namespace_definition, .child_count = 5, .production_id = 8 } } },
};
const s70_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_class_specifier, .child_count = 5, .production_id = 9 } } },
};
const s71_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_member_list, .child_count = 2, .production_id = 12 } } },
};
const s72_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_member_item, .child_count = 2, .production_id = 13 } } },
};
const s73_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 76 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 75 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 89 } },
    .{ .symbol = sym_shl, .action = .{ .shift = 77 } },
};
const s74_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 45 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 44 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 46 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 90 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 47 } },
    .{ .symbol = sym_this, .action = .{ .shift = 43 } },
};
const s74_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_argument_list, .state = 92 },
    .{ .symbol = sym_binary_expression, .state = 50 },
    .{ .symbol = sym_call_expression, .state = 51 },
    .{ .symbol = sym_expression, .state = 91 },
    .{ .symbol = sym_primary_expression, .state = 52 },
    .{ .symbol = sym_qualified_identifier, .state = 48 },
};
const s75_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 93 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 44 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 46 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 47 } },
    .{ .symbol = sym_this, .action = .{ .shift = 43 } },
};
const s75_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary_expression, .state = 94 },
};
const s76_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 93 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 44 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 46 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 47 } },
    .{ .symbol = sym_this, .action = .{ .shift = 43 } },
};
const s76_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary_expression, .state = 95 },
};
const s77_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 93 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 44 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 46 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 47 } },
    .{ .symbol = sym_this, .action = .{ .shift = 43 } },
};
const s77_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary_expression, .state = 96 },
};
const s78_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_this, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 42 } } },
};
const s79_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_minus, .action = .{ .shift = 76 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 75 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 97 } },
    .{ .symbol = sym_shl, .action = .{ .shift = 77 } },
};
const s80_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eq, .action = .{ .shift = 30 } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_variable_declaration, .child_count = 2, .production_id = 45 } } },
};
const s81_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_namespace, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_this, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_compound_statement, .child_count = 3, .production_id = 34 } } },
};
const s82_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_this, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 36 } } },
};
const s83_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_this, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 2, .production_id = 38 } } },
};
const s84_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_this, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 43 } } },
};
const s85_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_declarator, .child_count = 4, .production_id = 21 } } },
};
const s86_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .shift = 7 } },
    .{ .symbol = sym_bool, .action = .{ .shift = 5 } },
    .{ .symbol = sym_double, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 8 } },
    .{ .symbol = sym_int, .action = .{ .shift = 3 } },
    .{ .symbol = sym_void, .action = .{ .shift = 4 } },
};
const s86_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_parameter_declaration, .state = 98 },
    .{ .symbol = sym_qualified_identifier, .state = 15 },
    .{ .symbol = sym_type_specifier, .state = 68 },
};
const s87_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_declarator, .child_count = 4, .production_id = 19 } } },
};
const s88_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_declaration, .child_count = 2, .production_id = 26 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_declaration, .child_count = 2, .production_id = 26 } } },
};
const s89_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 60 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 60 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 60 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 60 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 60 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 3, .production_id = 60 } } },
};
const s90_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 53 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 3, .production_id = 53 } } },
};
const s91_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 1, .production_id = 54 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 76 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 75 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 1, .production_id = 54 } } },
    .{ .symbol = sym_shl, .action = .{ .shift = 77 } },
};
const s92_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 99 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 100 } },
};
const s93_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_primary_expression, .child_count = 1, .production_id = 56 } } },
};
const s94_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 49 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 49 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 49 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 49 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 49 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 49 } } },
};
const s95_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 50 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 50 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 50 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 50 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 50 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 50 } } },
};
const s96_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 51 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 51 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 51 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 51 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 51 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 51 } } },
};
const s97_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_auto, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_bool, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_double, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_lbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_lparen, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_number_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_this, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 41 } } },
};
const s98_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 3, .production_id = 25 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_parameter_list, .child_count = 3, .production_id = 25 } } },
};
const s99_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 45 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 44 } },
    .{ .symbol = sym_number_literal, .action = .{ .shift = 46 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 47 } },
    .{ .symbol = sym_this, .action = .{ .shift = 43 } },
};
const s99_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 50 },
    .{ .symbol = sym_call_expression, .state = 51 },
    .{ .symbol = sym_expression, .state = 101 },
    .{ .symbol = sym_primary_expression, .state = 52 },
    .{ .symbol = sym_qualified_identifier, .state = 48 },
};
const s100_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 52 } } },
    .{ .symbol = sym_minus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 52 } } },
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 52 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 52 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 52 } } },
    .{ .symbol = sym_shl, .action = .{ .reduce = .{ .symbol = sym_call_expression, .child_count = 4, .production_id = 52 } } },
};
const s101_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 3, .production_id = 55 } } },
    .{ .symbol = sym_minus, .action = .{ .shift = 76 } },
    .{ .symbol = sym_plus, .action = .{ .shift = 75 } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_argument_list, .child_count = 3, .production_id = 55 } } },
    .{ .symbol = sym_shl, .action = .{ .shift = 77 } },
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
    .{ .actions = s9_actions }, // 9
    .{ .actions = s10_actions, .gotos = s10_gotos }, // 10
    .{ .actions = s11_actions }, // 11
    .{ .actions = s12_actions }, // 12
    .{ .actions = s13_actions }, // 13
    .{ .actions = s14_actions }, // 14
    .{ .actions = s15_actions }, // 15
    .{ .actions = s16_actions, .gotos = s16_gotos }, // 16
    .{ .actions = s17_actions }, // 17
    .{ .actions = s18_actions }, // 18
    .{ .actions = s19_actions }, // 19
    .{ .actions = s20_actions }, // 20
    .{ .actions = s21_actions }, // 21
    .{ .actions = s22_actions }, // 22
    .{ .actions = s23_actions }, // 23
    .{ .actions = s24_actions, .gotos = s24_gotos }, // 24
    .{ .actions = s25_actions }, // 25
    .{ .actions = s26_actions }, // 26
    .{ .actions = s27_actions, .gotos = s27_gotos }, // 27
    .{ .actions = s28_actions, .gotos = s28_gotos }, // 28
    .{ .actions = s29_actions }, // 29
    .{ .actions = s30_actions, .gotos = s30_gotos }, // 30
    .{ .actions = s31_actions, .gotos = s31_gotos }, // 31
    .{ .actions = s32_actions }, // 32
    .{ .actions = s33_actions, .gotos = s33_gotos }, // 33
    .{ .actions = s34_actions, .gotos = s34_gotos }, // 34
    .{ .actions = s35_actions }, // 35
    .{ .actions = s36_actions }, // 36
    .{ .actions = s37_actions }, // 37
    .{ .actions = s38_actions }, // 38
    .{ .actions = s39_actions }, // 39
    .{ .actions = s40_actions, .gotos = s40_gotos }, // 40
    .{ .actions = s41_actions }, // 41
    .{ .actions = s42_actions }, // 42
    .{ .actions = s43_actions }, // 43
    .{ .actions = s44_actions, .gotos = s44_gotos }, // 44
    .{ .actions = s45_actions }, // 45
    .{ .actions = s46_actions }, // 46
    .{ .actions = s47_actions }, // 47
    .{ .actions = s48_actions }, // 48
    .{ .actions = s49_actions }, // 49
    .{ .actions = s50_actions }, // 50
    .{ .actions = s51_actions }, // 51
    .{ .actions = s52_actions }, // 52
    .{ .actions = s53_actions, .gotos = s53_gotos }, // 53
    .{ .actions = s54_actions }, // 54
    .{ .actions = s55_actions }, // 55
    .{ .actions = s56_actions }, // 56
    .{ .actions = s57_actions }, // 57
    .{ .actions = s58_actions, .gotos = s58_gotos }, // 58
    .{ .actions = s59_actions }, // 59
    .{ .actions = s60_actions }, // 60
    .{ .actions = s61_actions }, // 61
    .{ .actions = s62_actions }, // 62
    .{ .actions = s63_actions }, // 63
    .{ .actions = s64_actions }, // 64
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
    .{ .actions = s75_actions, .gotos = s75_gotos }, // 75
    .{ .actions = s76_actions, .gotos = s76_gotos }, // 76
    .{ .actions = s77_actions, .gotos = s77_gotos }, // 77
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
    .{ .actions = s89_actions }, // 89
    .{ .actions = s90_actions }, // 90
    .{ .actions = s91_actions }, // 91
    .{ .actions = s92_actions }, // 92
    .{ .actions = s93_actions }, // 93
    .{ .actions = s94_actions }, // 94
    .{ .actions = s95_actions }, // 95
    .{ .actions = s96_actions }, // 96
    .{ .actions = s97_actions }, // 97
    .{ .actions = s98_actions }, // 98
    .{ .actions = s99_actions, .gotos = s99_gotos }, // 99
    .{ .actions = s100_actions }, // 100
    .{ .actions = s101_actions }, // 101
};

const field_names: []const []const u8 = &.{ "name", "body", "type", "declarator", "argument", "value", "left", "right", "function", "arguments" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 8, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 3 } } },
    .{ .production_id = 9, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 3 } } },
    .{ .production_id = 10, .bindings = &.{.{ .name = "name", .child_index = 1 }} },
    .{ .production_id = 18, .bindings = &.{ .{ .name = "type", .child_index = 0 }, .{ .name = "declarator", .child_index = 1 }, .{ .name = "body", .child_index = 2 } } },
    .{ .production_id = 26, .bindings = &.{ .{ .name = "type", .child_index = 0 }, .{ .name = "declarator", .child_index = 1 } } },
    .{ .production_id = 41, .bindings = &.{.{ .name = "argument", .child_index = 1 }} },
    .{ .production_id = 44, .bindings = &.{ .{ .name = "type", .child_index = 0 }, .{ .name = "declarator", .child_index = 1 }, .{ .name = "value", .child_index = 3 } } },
    .{ .production_id = 45, .bindings = &.{ .{ .name = "type", .child_index = 0 }, .{ .name = "declarator", .child_index = 1 } } },
    .{ .production_id = 49, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 50, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 51, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
    .{ .production_id = 52, .bindings = &.{ .{ .name = "function", .child_index = 0 }, .{ .name = "arguments", .child_index = 2 } } },
    .{ .production_id = 53, .bindings = &.{.{ .name = "function", .child_index = 0 }} },
};

pub const language: Language = .{
    .metadata = .{
        .name = "cpp",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.3",
        .symbol_count = 57,
        .state_count = 102,
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

test "parser: cpp table verification" {
    try std.testing.expectEqualStrings("cpp", language.metadata.name);
    try std.testing.expect(language.metadata.symbol_count > 0);
    try std.testing.expect(language.table.stateCount() > 0);
}

test "parser: cpp node types verification" {
    var nt = try treesitter.NodeTypes.parseJSON(std.testing.allocator, node_types_json);
    defer nt.deinit();
    try std.testing.expect(nt.findType("translation_unit") != null);
}

test "parser: cpp grammar json verification" {
    var dsl = treesitter.DSLParser.init(std.testing.allocator);
    var g = try dsl.parseJSON(grammar_json);
    defer g.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("cpp", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}

test "parser: cpp genuine program parsing 1" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("namespace math { class Calculator { public: int compute(int x) { return x + 1; } }; }");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("translation_unit", root.nodeType());
}
