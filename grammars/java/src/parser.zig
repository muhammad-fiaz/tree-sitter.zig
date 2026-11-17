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
pub const sym_public: u16 = 3;
pub const sym_private: u16 = 4;
pub const sym_protected: u16 = 5;
pub const sym_static: u16 = 6;
pub const sym_final: u16 = 7;
pub const sym_class: u16 = 8;
pub const sym_int: u16 = 9;
pub const sym_void: u16 = 10;
pub const sym_boolean: u16 = 11;
pub const sym_return: u16 = 12;
pub const sym_semi: u16 = 13;
pub const sym_dot: u16 = 14;
pub const sym_comma: u16 = 15;
pub const sym_lparen: u16 = 16;
pub const sym_rparen: u16 = 17;
pub const sym_lbrace: u16 = 18;
pub const sym_rbrace: u16 = 19;
pub const sym_eq: u16 = 20;
pub const sym_plus: u16 = 21;
pub const sym_identifier: u16 = 22;
pub const sym_integer_literal: u16 = 23;
pub const sym_string_literal: u16 = 24;
pub const sym_whitespace: u16 = 25;
pub const sym_comment: u16 = 26;
pub const sym_program: u16 = 27;
pub const sym_package_declaration: u16 = 28;
pub const sym_qualified_name: u16 = 29;
pub const sym_class_declarations: u16 = 30;
pub const sym_class_declaration: u16 = 31;
pub const sym_modifiers: u16 = 32;
pub const sym_modifier: u16 = 33;
pub const sym_class_body: u16 = 34;
pub const sym_member_declarations: u16 = 35;
pub const sym_member_declaration: u16 = 36;
pub const sym_method_declaration: u16 = 37;
pub const sym_formal_parameters: u16 = 38;
pub const sym_formal_parameter: u16 = 39;
pub const sym_field_declaration: u16 = 40;
pub const sym_type_type: u16 = 41;
pub const sym_block: u16 = 42;
pub const sym_statements: u16 = 43;
pub const sym_statement: u16 = 44;
pub const sym_return_statement: u16 = 45;
pub const sym_expression_statement: u16 = 46;
pub const sym_expression: u16 = 47;
pub const sym_binary_expression: u16 = 48;
pub const sym_primary: u16 = 49;
pub const sym_ERROR: u16 = 50;

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
    .{ .id = sym_public, .name = "public", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_private, .name = "private", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_protected, .name = "protected", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_static, .name = "static", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_final, .name = "final", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_class, .name = "class", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_int, .name = "int", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_void, .name = "void", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_boolean, .name = "boolean", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_return, .name = "return", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_semi, .name = ";", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_dot, .name = ".", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_comma, .name = ",", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lparen, .name = "(", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rparen, .name = ")", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_lbrace, .name = "{", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_rbrace, .name = "}", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_eq, .name = "=", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_plus, .name = "+", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_identifier, .name = "identifier", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_integer_literal, .name = "integer_literal", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_string_literal, .name = "string_literal", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = true, .named = false, .extra = true } },
    .{ .id = sym_comment, .name = "comment", .kind = .terminal, .metadata = .{ .visible = true, .named = true, .extra = true } },
    .{ .id = sym_program, .name = "program", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_package_declaration, .name = "package_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_qualified_name, .name = "qualified_name", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_class_declarations, .name = "class_declarations", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_class_declaration, .name = "class_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_modifiers, .name = "modifiers", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_modifier, .name = "modifier", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_class_body, .name = "class_body", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_member_declarations, .name = "member_declarations", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_member_declaration, .name = "member_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_method_declaration, .name = "method_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_formal_parameters, .name = "formal_parameters", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_formal_parameter, .name = "formal_parameter", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_field_declaration, .name = "field_declaration", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_type_type, .name = "type_type", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_block, .name = "block", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statements, .name = "statements", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_statement, .name = "statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_return_statement, .name = "return_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression_statement, .name = "expression_statement", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_expression, .name = "expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_binary_expression, .name = "binary_expression", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_primary, .name = "primary", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_ERROR, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_package, .match = matchKeyword("package") },
    .{ .symbol = sym_import, .match = matchKeyword("import") },
    .{ .symbol = sym_public, .match = matchKeyword("public") },
    .{ .symbol = sym_private, .match = matchKeyword("private") },
    .{ .symbol = sym_protected, .match = matchKeyword("protected") },
    .{ .symbol = sym_static, .match = matchKeyword("static") },
    .{ .symbol = sym_final, .match = matchKeyword("final") },
    .{ .symbol = sym_class, .match = matchKeyword("class") },
    .{ .symbol = sym_int, .match = matchKeyword("int") },
    .{ .symbol = sym_void, .match = matchKeyword("void") },
    .{ .symbol = sym_boolean, .match = matchKeyword("boolean") },
    .{ .symbol = sym_return, .match = matchKeyword("return") },
    .{ .symbol = sym_semi, .match = language_mod.matchChar(';') },
    .{ .symbol = sym_dot, .match = language_mod.matchChar('.') },
    .{ .symbol = sym_comma, .match = language_mod.matchChar(',') },
    .{ .symbol = sym_lparen, .match = language_mod.matchChar('(') },
    .{ .symbol = sym_rparen, .match = language_mod.matchChar(')') },
    .{ .symbol = sym_lbrace, .match = language_mod.matchChar('{') },
    .{ .symbol = sym_rbrace, .match = language_mod.matchChar('}') },
    .{ .symbol = sym_eq, .match = language_mod.matchChar('=') },
    .{ .symbol = sym_plus, .match = language_mod.matchChar('+') },
    .{ .symbol = sym_identifier, .match = matchIdentifier },
    .{ .symbol = sym_integer_literal, .match = matchNumber },
    .{ .symbol = sym_string_literal, .match = matchString },
    .{ .symbol = sym_whitespace, .match = language_mod.matchWhitespace },
    .{ .symbol = sym_comment, .match = matchComment },
};

const extra_symbols: []const u16 = &.{ sym_whitespace, sym_comment };

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 7 } },
    .{ .symbol = sym_final, .action = .{ .shift = 6 } },
    .{ .symbol = sym_package, .action = .{ .shift = 1 } },
    .{ .symbol = sym_private, .action = .{ .shift = 3 } },
    .{ .symbol = sym_protected, .action = .{ .shift = 4 } },
    .{ .symbol = sym_public, .action = .{ .shift = 2 } },
    .{ .symbol = sym_static, .action = .{ .shift = 5 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_declaration, .state = 11 },
    .{ .symbol = sym_class_declarations, .state = 10 },
    .{ .symbol = sym_modifier, .state = 13 },
    .{ .symbol = sym_modifiers, .state = 12 },
    .{ .symbol = sym_package_declaration, .state = 9 },
    .{ .symbol = sym_program, .state = 8 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 14 } },
};
const s1_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_qualified_name, .state = 15 },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 12 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 12 } } },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 13 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 13 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 13 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 13 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 13 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 13 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 13 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 13 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 13 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 13 } } },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 14 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 14 } } },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 15 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 15 } } },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 16 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_modifier, .child_count = 1, .production_id = 16 } } },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 16 } },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 7 } },
    .{ .symbol = sym_final, .action = .{ .shift = 6 } },
    .{ .symbol = sym_private, .action = .{ .shift = 3 } },
    .{ .symbol = sym_protected, .action = .{ .shift = 4 } },
    .{ .symbol = sym_public, .action = .{ .shift = 2 } },
    .{ .symbol = sym_static, .action = .{ .shift = 5 } },
};
const s9_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_declaration, .state = 11 },
    .{ .symbol = sym_class_declarations, .state = 17 },
    .{ .symbol = sym_modifier, .state = 13 },
    .{ .symbol = sym_modifiers, .state = 12 },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 7 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_program, .child_count = 1, .production_id = 1 } } },
    .{ .symbol = sym_final, .action = .{ .shift = 6 } },
    .{ .symbol = sym_private, .action = .{ .shift = 3 } },
    .{ .symbol = sym_protected, .action = .{ .shift = 4 } },
    .{ .symbol = sym_public, .action = .{ .shift = 2 } },
    .{ .symbol = sym_static, .action = .{ .shift = 5 } },
};
const s10_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_declaration, .state = 18 },
    .{ .symbol = sym_modifier, .state = 13 },
    .{ .symbol = sym_modifiers, .state = 12 },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 1, .production_id = 6 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 1, .production_id = 6 } } },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 19 } },
    .{ .symbol = sym_final, .action = .{ .shift = 6 } },
    .{ .symbol = sym_private, .action = .{ .shift = 3 } },
    .{ .symbol = sym_protected, .action = .{ .shift = 4 } },
    .{ .symbol = sym_public, .action = .{ .shift = 2 } },
    .{ .symbol = sym_static, .action = .{ .shift = 5 } },
};
const s12_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_modifier, .state = 20 },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 1, .production_id = 10 } } },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_qualified_name, .child_count = 1, .production_id = 4 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_qualified_name, .child_count = 1, .production_id = 4 } } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .shift = 22 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 21 } },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 23 } },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .shift = 7 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_program, .child_count = 2, .production_id = 2 } } },
    .{ .symbol = sym_final, .action = .{ .shift = 6 } },
    .{ .symbol = sym_private, .action = .{ .shift = 3 } },
    .{ .symbol = sym_protected, .action = .{ .shift = 4 } },
    .{ .symbol = sym_public, .action = .{ .shift = 2 } },
    .{ .symbol = sym_static, .action = .{ .shift = 5 } },
};
const s17_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_declaration, .state = 18 },
    .{ .symbol = sym_modifier, .state = 13 },
    .{ .symbol = sym_modifiers, .state = 12 },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 2, .production_id = 7 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_class_declarations, .child_count = 2, .production_id = 7 } } },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 24 } },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_modifiers, .child_count = 2, .production_id = 11 } } },
};
const s21_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_package_declaration, .child_count = 3, .production_id = 3 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_package_declaration, .child_count = 3, .production_id = 3 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_package_declaration, .child_count = 3, .production_id = 3 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_package_declaration, .child_count = 3, .production_id = 3 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_package_declaration, .child_count = 3, .production_id = 3 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_package_declaration, .child_count = 3, .production_id = 3 } } },
};
const s22_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 25 } },
};
const s23_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .shift = 28 } },
    .{ .symbol = sym_final, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 29 } },
    .{ .symbol = sym_int, .action = .{ .shift = 26 } },
    .{ .symbol = sym_private, .action = .{ .shift = 3 } },
    .{ .symbol = sym_protected, .action = .{ .shift = 4 } },
    .{ .symbol = sym_public, .action = .{ .shift = 2 } },
    .{ .symbol = sym_static, .action = .{ .shift = 5 } },
    .{ .symbol = sym_void, .action = .{ .shift = 27 } },
};
const s23_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_body, .state = 31 },
    .{ .symbol = sym_field_declaration, .state = 35 },
    .{ .symbol = sym_member_declaration, .state = 33 },
    .{ .symbol = sym_member_declarations, .state = 32 },
    .{ .symbol = sym_method_declaration, .state = 34 },
    .{ .symbol = sym_modifier, .state = 13 },
    .{ .symbol = sym_modifiers, .state = 30 },
    .{ .symbol = sym_type_type, .state = 36 },
};
const s24_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 37 } },
};
const s25_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_dot, .action = .{ .reduce = .{ .symbol = sym_qualified_name, .child_count = 3, .production_id = 5 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_qualified_name, .child_count = 3, .production_id = 5 } } },
};
const s26_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_type, .child_count = 1, .production_id = 30 } } },
};
const s27_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_type, .child_count = 1, .production_id = 31 } } },
};
const s28_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_type, .child_count = 1, .production_id = 32 } } },
};
const s29_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_type_type, .child_count = 1, .production_id = 33 } } },
};
const s30_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .shift = 28 } },
    .{ .symbol = sym_final, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 29 } },
    .{ .symbol = sym_int, .action = .{ .shift = 26 } },
    .{ .symbol = sym_private, .action = .{ .shift = 3 } },
    .{ .symbol = sym_protected, .action = .{ .shift = 4 } },
    .{ .symbol = sym_public, .action = .{ .shift = 2 } },
    .{ .symbol = sym_static, .action = .{ .shift = 5 } },
    .{ .symbol = sym_void, .action = .{ .shift = 27 } },
};
const s30_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_modifier, .state = 20 },
    .{ .symbol = sym_type_type, .state = 38 },
};
const s31_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_rbrace, .action = .{ .shift = 39 } },
};
const s32_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .shift = 28 } },
    .{ .symbol = sym_final, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 29 } },
    .{ .symbol = sym_int, .action = .{ .shift = 26 } },
    .{ .symbol = sym_private, .action = .{ .shift = 3 } },
    .{ .symbol = sym_protected, .action = .{ .shift = 4 } },
    .{ .symbol = sym_public, .action = .{ .shift = 2 } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_class_body, .child_count = 1, .production_id = 17 } } },
    .{ .symbol = sym_static, .action = .{ .shift = 5 } },
    .{ .symbol = sym_void, .action = .{ .shift = 27 } },
};
const s32_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_field_declaration, .state = 35 },
    .{ .symbol = sym_member_declaration, .state = 40 },
    .{ .symbol = sym_method_declaration, .state = 34 },
    .{ .symbol = sym_modifier, .state = 13 },
    .{ .symbol = sym_modifiers, .state = 30 },
    .{ .symbol = sym_type_type, .state = 36 },
};
const s33_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_class_body, .child_count = 1, .production_id = 18 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 1, .production_id = 19 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 1, .production_id = 19 } } },
};
const s34_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 21 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 21 } } },
};
const s35_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 22 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_member_declaration, .child_count = 1, .production_id = 22 } } },
};
const s36_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 41 } },
};
const s37_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .shift = 28 } },
    .{ .symbol = sym_final, .action = .{ .shift = 6 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 29 } },
    .{ .symbol = sym_int, .action = .{ .shift = 26 } },
    .{ .symbol = sym_private, .action = .{ .shift = 3 } },
    .{ .symbol = sym_protected, .action = .{ .shift = 4 } },
    .{ .symbol = sym_public, .action = .{ .shift = 2 } },
    .{ .symbol = sym_static, .action = .{ .shift = 5 } },
    .{ .symbol = sym_void, .action = .{ .shift = 27 } },
};
const s37_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_class_body, .state = 42 },
    .{ .symbol = sym_field_declaration, .state = 35 },
    .{ .symbol = sym_member_declaration, .state = 33 },
    .{ .symbol = sym_member_declarations, .state = 32 },
    .{ .symbol = sym_method_declaration, .state = 34 },
    .{ .symbol = sym_modifier, .state = 13 },
    .{ .symbol = sym_modifiers, .state = 30 },
    .{ .symbol = sym_type_type, .state = 36 },
};
const s38_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 43 } },
};
const s39_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 5, .production_id = 9 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 5, .production_id = 9 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 5, .production_id = 9 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 5, .production_id = 9 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 5, .production_id = 9 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 5, .production_id = 9 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 5, .production_id = 9 } } },
};
const s40_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 2, .production_id = 20 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_member_declarations, .child_count = 2, .production_id = 20 } } },
};
const s41_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_semi, .action = .{ .shift = 44 } },
};
const s42_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_rbrace, .action = .{ .shift = 45 } },
};
const s43_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_eq, .action = .{ .shift = 47 } },
    .{ .symbol = sym_lparen, .action = .{ .shift = 46 } },
};
const s44_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 3, .production_id = 29 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 3, .production_id = 29 } } },
};
const s45_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_class, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 6, .production_id = 8 } } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 6, .production_id = 8 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 6, .production_id = 8 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 6, .production_id = 8 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 6, .production_id = 8 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 6, .production_id = 8 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_class_declaration, .child_count = 6, .production_id = 8 } } },
};
const s46_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 29 } },
    .{ .symbol = sym_int, .action = .{ .shift = 26 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 48 } },
    .{ .symbol = sym_void, .action = .{ .shift = 27 } },
};
const s46_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_formal_parameter, .state = 50 },
    .{ .symbol = sym_formal_parameters, .state = 49 },
    .{ .symbol = sym_type_type, .state = 51 },
};
const s47_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 52 } },
    .{ .symbol = sym_integer_literal, .action = .{ .shift = 53 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 54 } },
};
const s47_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 56 },
    .{ .symbol = sym_expression, .state = 55 },
    .{ .symbol = sym_primary, .state = 57 },
};
const s48_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 58 } },
};
const s48_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_block, .state = 59 },
};
const s49_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .shift = 60 } },
    .{ .symbol = sym_rparen, .action = .{ .shift = 61 } },
};
const s50_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_formal_parameters, .child_count = 1, .production_id = 25 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_formal_parameters, .child_count = 1, .production_id = 25 } } },
};
const s51_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 62 } },
};
const s52_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 46 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 46 } } },
};
const s53_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 47 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 47 } } },
};
const s54_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 48 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_primary, .child_count = 1, .production_id = 48 } } },
};
const s55_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_plus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 63 } },
};
const s56_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 43 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 43 } } },
};
const s57_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 44 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_expression, .child_count = 1, .production_id = 44 } } },
};
const s58_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 52 } },
    .{ .symbol = sym_integer_literal, .action = .{ .shift = 53 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 66 } },
    .{ .symbol = sym_return, .action = .{ .shift = 65 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 54 } },
};
const s58_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 56 },
    .{ .symbol = sym_expression, .state = 71 },
    .{ .symbol = sym_expression_statement, .state = 70 },
    .{ .symbol = sym_primary, .state = 57 },
    .{ .symbol = sym_return_statement, .state = 69 },
    .{ .symbol = sym_statement, .state = 68 },
    .{ .symbol = sym_statements, .state = 67 },
};
const s59_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 6, .production_id = 24 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 6, .production_id = 24 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 6, .production_id = 24 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 6, .production_id = 24 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 6, .production_id = 24 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 6, .production_id = 24 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 6, .production_id = 24 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 6, .production_id = 24 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 6, .production_id = 24 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 6, .production_id = 24 } } },
};
const s60_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .shift = 28 } },
    .{ .symbol = sym_identifier, .action = .{ .shift = 29 } },
    .{ .symbol = sym_int, .action = .{ .shift = 26 } },
    .{ .symbol = sym_void, .action = .{ .shift = 27 } },
};
const s60_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_formal_parameter, .state = 72 },
    .{ .symbol = sym_type_type, .state = 51 },
};
const s61_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_lbrace, .action = .{ .shift = 58 } },
};
const s61_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_block, .state = 73 },
};
const s62_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_formal_parameter, .child_count = 2, .production_id = 27 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_formal_parameter, .child_count = 2, .production_id = 27 } } },
};
const s63_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 6, .production_id = 28 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 6, .production_id = 28 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 6, .production_id = 28 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 6, .production_id = 28 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 6, .production_id = 28 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 6, .production_id = 28 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 6, .production_id = 28 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 6, .production_id = 28 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 6, .production_id = 28 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_field_declaration, .child_count = 6, .production_id = 28 } } },
};
const s64_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 52 } },
    .{ .symbol = sym_integer_literal, .action = .{ .shift = 53 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 54 } },
};
const s64_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_primary, .state = 74 },
};
const s65_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 52 } },
    .{ .symbol = sym_integer_literal, .action = .{ .shift = 53 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 75 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 54 } },
};
const s65_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 56 },
    .{ .symbol = sym_expression, .state = 76 },
    .{ .symbol = sym_primary, .state = 57 },
};
const s66_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 34 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 34 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 34 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 34 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 34 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 34 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 34 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 34 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 34 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 34 } } },
};
const s67_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .shift = 52 } },
    .{ .symbol = sym_integer_literal, .action = .{ .shift = 53 } },
    .{ .symbol = sym_rbrace, .action = .{ .shift = 77 } },
    .{ .symbol = sym_return, .action = .{ .shift = 65 } },
    .{ .symbol = sym_string_literal, .action = .{ .shift = 54 } },
};
const s67_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_binary_expression, .state = 56 },
    .{ .symbol = sym_expression, .state = 71 },
    .{ .symbol = sym_expression_statement, .state = 70 },
    .{ .symbol = sym_primary, .state = 57 },
    .{ .symbol = sym_return_statement, .state = 69 },
    .{ .symbol = sym_statement, .state = 78 },
};
const s68_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_integer_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 36 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 1, .production_id = 36 } } },
};
const s69_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_integer_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 38 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 38 } } },
};
const s70_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_integer_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statement, .child_count = 1, .production_id = 39 } } },
};
const s71_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_plus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 79 } },
};
const s72_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_comma, .action = .{ .reduce = .{ .symbol = sym_formal_parameters, .child_count = 3, .production_id = 26 } } },
    .{ .symbol = sym_rparen, .action = .{ .reduce = .{ .symbol = sym_formal_parameters, .child_count = 3, .production_id = 26 } } },
};
const s73_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 7, .production_id = 23 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 7, .production_id = 23 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 7, .production_id = 23 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 7, .production_id = 23 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 7, .production_id = 23 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 7, .production_id = 23 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 7, .production_id = 23 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 7, .production_id = 23 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 7, .production_id = 23 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_method_declaration, .child_count = 7, .production_id = 23 } } },
};
const s74_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_plus, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 45 } } },
    .{ .symbol = sym_semi, .action = .{ .reduce = .{ .symbol = sym_binary_expression, .child_count = 3, .production_id = 45 } } },
};
const s75_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 41 } } },
    .{ .symbol = sym_integer_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 41 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 41 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 41 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 2, .production_id = 41 } } },
};
const s76_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_plus, .action = .{ .shift = 64 } },
    .{ .symbol = sym_semi, .action = .{ .shift = 80 } },
};
const s77_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_boolean, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_final, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_int, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_private, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_protected, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_public, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_static, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 35 } } },
    .{ .symbol = sym_void, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 35 } } },
};
const s78_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 37 } } },
    .{ .symbol = sym_integer_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 37 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 37 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 37 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_statements, .child_count = 2, .production_id = 37 } } },
};
const s79_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_integer_literal, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 42 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_expression_statement, .child_count = 2, .production_id = 42 } } },
};
const s80_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_identifier, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_integer_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_rbrace, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_return, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 40 } } },
    .{ .symbol = sym_string_literal, .action = .{ .reduce = .{ .symbol = sym_return_statement, .child_count = 3, .production_id = 40 } } },
};

const parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = s0_actions, .gotos = s0_gotos }, // 0
    .{ .actions = s1_actions, .gotos = s1_gotos }, // 1
    .{ .actions = s2_actions }, // 2
    .{ .actions = s3_actions }, // 3
    .{ .actions = s4_actions }, // 4
    .{ .actions = s5_actions }, // 5
    .{ .actions = s6_actions }, // 6
    .{ .actions = s7_actions }, // 7
    .{ .actions = s8_actions }, // 8
    .{ .actions = s9_actions, .gotos = s9_gotos }, // 9
    .{ .actions = s10_actions, .gotos = s10_gotos }, // 10
    .{ .actions = s11_actions }, // 11
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
    .{ .actions = s23_actions, .gotos = s23_gotos }, // 23
    .{ .actions = s24_actions }, // 24
    .{ .actions = s25_actions }, // 25
    .{ .actions = s26_actions }, // 26
    .{ .actions = s27_actions }, // 27
    .{ .actions = s28_actions }, // 28
    .{ .actions = s29_actions }, // 29
    .{ .actions = s30_actions, .gotos = s30_gotos }, // 30
    .{ .actions = s31_actions }, // 31
    .{ .actions = s32_actions, .gotos = s32_gotos }, // 32
    .{ .actions = s33_actions }, // 33
    .{ .actions = s34_actions }, // 34
    .{ .actions = s35_actions }, // 35
    .{ .actions = s36_actions }, // 36
    .{ .actions = s37_actions, .gotos = s37_gotos }, // 37
    .{ .actions = s38_actions }, // 38
    .{ .actions = s39_actions }, // 39
    .{ .actions = s40_actions }, // 40
    .{ .actions = s41_actions }, // 41
    .{ .actions = s42_actions }, // 42
    .{ .actions = s43_actions }, // 43
    .{ .actions = s44_actions }, // 44
    .{ .actions = s45_actions }, // 45
    .{ .actions = s46_actions, .gotos = s46_gotos }, // 46
    .{ .actions = s47_actions, .gotos = s47_gotos }, // 47
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
    .{ .actions = s60_actions, .gotos = s60_gotos }, // 60
    .{ .actions = s61_actions, .gotos = s61_gotos }, // 61
    .{ .actions = s62_actions }, // 62
    .{ .actions = s63_actions }, // 63
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
    .{ .actions = s78_actions }, // 78
    .{ .actions = s79_actions }, // 79
    .{ .actions = s80_actions }, // 80
};

const field_names: []const []const u8 = &.{ "name", "body", "parameters", "type", "argument", "left", "right" };
const field_productions: []const fields_mod.FieldProduction = &.{
    .{ .production_id = 8, .bindings = &.{ .{ .name = "name", .child_index = 2 }, .{ .name = "body", .child_index = 4 } } },
    .{ .production_id = 9, .bindings = &.{ .{ .name = "name", .child_index = 1 }, .{ .name = "body", .child_index = 3 } } },
    .{ .production_id = 23, .bindings = &.{ .{ .name = "name", .child_index = 2 }, .{ .name = "parameters", .child_index = 4 }, .{ .name = "body", .child_index = 6 } } },
    .{ .production_id = 24, .bindings = &.{ .{ .name = "name", .child_index = 2 }, .{ .name = "body", .child_index = 5 } } },
    .{ .production_id = 27, .bindings = &.{ .{ .name = "type", .child_index = 0 }, .{ .name = "name", .child_index = 1 } } },
    .{ .production_id = 40, .bindings = &.{.{ .name = "argument", .child_index = 1 }} },
    .{ .production_id = 45, .bindings = &.{ .{ .name = "left", .child_index = 0 }, .{ .name = "right", .child_index = 2 } } },
};

pub const language: Language = .{
    .metadata = .{
        .name = "java",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.3",
        .symbol_count = 51,
        .state_count = 81,
        .field_count = 7,
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

test "parser: java table verification" {
    try std.testing.expectEqualStrings("java", language.metadata.name);
    try std.testing.expect(language.metadata.symbol_count > 0);
    try std.testing.expect(language.table.stateCount() > 0);
}

test "parser: java node types verification" {
    var nt = try treesitter.NodeTypes.parseJSON(std.testing.allocator, node_types_json);
    defer nt.deinit();
    try std.testing.expect(nt.findType("program") != null);
}

test "parser: java grammar json verification" {
    var dsl = treesitter.DSLParser.init(std.testing.allocator);
    var g = try dsl.parseJSON(grammar_json);
    defer g.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("java", g.name);
    try std.testing.expect(g.rules.items.len > 0);
}

test "parser: java genuine program parsing 1" {
    var parser = treesitter.Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language);
    var tree = try parser.parseString("public class Main { public static int add(int a, int b) { return a + b; } }");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
}
