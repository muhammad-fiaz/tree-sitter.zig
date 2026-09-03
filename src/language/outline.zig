const std = @import("std");
const language_mod = @import("language.zig");
const symbols_mod = @import("symbols.zig");
const tables_mod = @import("tables.zig");
const fields_mod = @import("fields.zig");
const metadata_mod = @import("metadata.zig");
const outline_scanner = @import("outline_scanner.zig");

/// Bundled outline grammar tables (see `outline_language` below).
///
/// A small indentation-sensitive language that demonstrates external
/// scanners end to end:
///
/// ```text
/// # Title
/// - item one
/// - item two
///   # Nested
///   - deep item
/// - item three
/// ```
///
/// ```text
/// program  := blocks
/// blocks   := block | blocks block
/// block    := HEADER NEWLINE | HEADER NEWLINE body | HEADER NEWLINE items
///            | HEADER NEWLINE body items
/// body     := INDENT items DEDENT
/// items    := item | items item | items block | block
/// item     := ITEM NEWLINE
/// ```
///
/// `HEADER` (`#...`) and `ITEM` (`-...`) lines lex internally;
/// `NEWLINE`, `INDENT`, `DEDENT`, and `BLANK` come from the external
/// scanner (`outline_scanner.zig`), which owns all
/// whitespace-sensitive decisions. Nesting happens through `#`
/// sub-headers; bare continuation lines and deeper bare bullets are
/// parse errors by design.
pub const sym_end: u16 = 0;
pub const sym_header: u16 = 1;
pub const sym_item_tok: u16 = 2;
pub const sym_newline: u16 = 3;
pub const sym_indent: u16 = 4;
pub const sym_dedent: u16 = 5;
pub const sym_whitespace: u16 = 6;
pub const sym_blank: u16 = 7;
pub const sym_program: u16 = 8;
pub const sym_blocks: u16 = 9;
pub const sym_block: u16 = 10;
pub const sym_body: u16 = 11;
pub const sym_items: u16 = 12;
pub const sym_item: u16 = 13;
pub const sym_error: u16 = 14;

fn matchLine(comptime marker: u8) language_mod.TokenMatchFn {
    return struct {
        fn match(source: []const u8, start: usize) ?usize {
            if (start >= source.len or source[start] != marker) return null;
            var i = start + 1;
            while (i < source.len and source[i] != '\n') : (i += 1) {}
            return i - start;
        }
    }.match;
}

/// Horizontal whitespace only: newlines are significant (they feed the
/// external scanner), so the shared whitespace matcher — which covers
/// `\n` — must not be listed as an extra here.
fn matchSpaces(source: []const u8, start: usize) ?usize {
    if (start >= source.len) return null;
    if (source[start] != ' ' and source[start] != '\t') return null;
    var i = start + 1;
    while (i < source.len and (source[i] == ' ' or source[i] == '\t')) : (i += 1) {}
    return i - start;
}

const symbol_table: []const symbols_mod.SymbolInfo = &.{
    .{ .id = sym_end, .name = "end", .kind = .end, .metadata = .{ .visible = false, .named = false } },
    .{ .id = sym_header, .name = "header", .kind = .terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_item_tok, .name = "item_token", .kind = .terminal, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_newline, .name = "newline", .kind = .external, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_indent, .name = "indent", .kind = .external, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_dedent, .name = "dedent", .kind = .external, .metadata = .{ .visible = true, .named = false } },
    .{ .id = sym_whitespace, .name = "whitespace", .kind = .terminal, .metadata = .{ .visible = false, .named = false, .extra = true } },
    .{ .id = sym_blank, .name = "blank", .kind = .external, .metadata = .{ .visible = false, .named = false, .extra = true } },
    .{ .id = sym_program, .name = "program", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_blocks, .name = "blocks", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_block, .name = "block", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_body, .name = "body", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_items, .name = "items", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_item, .name = "item", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
    .{ .id = sym_error, .name = "ERROR", .kind = .non_terminal, .metadata = .{ .visible = true, .named = true } },
};

const token_matchers: []const language_mod.TokenMatcher = &.{
    .{ .symbol = sym_header, .match = matchLine('#') },
    .{ .symbol = sym_item_tok, .match = matchLine('-') },
    .{ .symbol = sym_whitespace, .match = matchSpaces },
};

const extra_symbols: []const u16 = &.{ sym_whitespace, sym_blank };

const s0_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_header, .action = .{ .shift = 11 } },
};
const s0_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_program, .state = 1 },
    .{ .symbol = sym_blocks, .state = 2 },
    .{ .symbol = sym_block, .state = 3 },
};
const s1_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .accept },
};
const s2_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_header, .action = .{ .shift = 11 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_program, .child_count = 1, .production_id = 1 } } },
};
const s2_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_block, .state = 4 },
};
const s3_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_blocks, .child_count = 1, .production_id = 2 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_blocks, .child_count = 1, .production_id = 2 } } },
};
const s4_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_blocks, .child_count = 2, .production_id = 3 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_blocks, .child_count = 2, .production_id = 3 } } },
};
const s5_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 5 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 5 } } },
    .{ .symbol = sym_item_tok, .action = .{ .shift = 14 } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 5 } } },
};
const s5_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_item, .state = 19 },
    .{ .symbol = sym_items, .state = 20 },
};
const s6_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_item_tok, .action = .{ .shift = 14 } },
    .{ .symbol = sym_header, .action = .{ .shift = 11 } },
    .{ .symbol = sym_dedent, .action = .{ .shift = 16 } },
};
const s6_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_item, .state = 8 },
    .{ .symbol = sym_block, .state = 9 },
};
const s7_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_item_tok, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
};
const s8_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_item_tok, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 2, .production_id = 8 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 2, .production_id = 8 } } },
};
const s9_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 2, .production_id = 9 } } },
    .{ .symbol = sym_item_tok, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 2, .production_id = 9 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 2, .production_id = 9 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 2, .production_id = 9 } } },
};
const s10_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_item_tok, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 10 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 10 } } },
};
const s11_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_newline, .action = .{ .shift = 12 } },
};
const s12_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_indent, .action = .{ .shift = 13 } },
    .{ .symbol = sym_item_tok, .action = .{ .shift = 14 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 4 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 4 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 2, .production_id = 4 } } },
};
const s12_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_body, .state = 5 },
    .{ .symbol = sym_items, .state = 17 },
    .{ .symbol = sym_item, .state = 18 },
};
const s13_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_item_tok, .action = .{ .shift = 14 } },
    .{ .symbol = sym_header, .action = .{ .shift = 11 } },
};
const s13_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_items, .state = 6 },
    .{ .symbol = sym_item, .state = 7 },
    .{ .symbol = sym_block, .state = 10 },
};
const s14_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_newline, .action = .{ .shift = 15 } },
};
const s15_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_item, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_item_tok, .action = .{ .reduce = .{ .symbol = sym_item, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_item, .child_count = 2, .production_id = 11 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_item, .child_count = 2, .production_id = 11 } } },
};
const s16_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_body, .child_count = 3, .production_id = 6 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_body, .child_count = 3, .production_id = 6 } } },
    .{ .symbol = sym_item_tok, .action = .{ .reduce = .{ .symbol = sym_body, .child_count = 3, .production_id = 6 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_body, .child_count = 3, .production_id = 6 } } },
};
const s17_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_item_tok, .action = .{ .shift = 14 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 12 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 3, .production_id = 12 } } },
};
const s17_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_item, .state = 8 },
};
const s18_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_item_tok, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
};
const s19_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_item_tok, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_items, .child_count = 1, .production_id = 7 } } },
};
const s20_actions: []const tables_mod.ActionEntry = &.{
    .{ .symbol = sym_item_tok, .action = .{ .shift = 14 } },
    .{ .symbol = sym_end, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_header, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 4, .production_id = 13 } } },
    .{ .symbol = sym_dedent, .action = .{ .reduce = .{ .symbol = sym_block, .child_count = 4, .production_id = 13 } } },
};
const s20_gotos: []const tables_mod.GotoEntry = &.{
    .{ .symbol = sym_item, .state = 8 },
};

const parse_states: []const tables_mod.ParseState = &.{
    .{ .actions = s0_actions, .gotos = s0_gotos }, // 0
    .{ .actions = s1_actions }, // 1
    .{ .actions = s2_actions, .gotos = s2_gotos }, // 2
    .{ .actions = s3_actions }, // 3
    .{ .actions = s4_actions }, // 4
    .{ .actions = s5_actions, .gotos = s5_gotos }, // 5
    .{ .actions = s6_actions, .gotos = s6_gotos }, // 6
    .{ .actions = s7_actions }, // 7 item single
    .{ .actions = s8_actions }, // 8 item extend
    .{ .actions = s9_actions }, // 9 block in items
    .{ .actions = s10_actions }, // 10 block single
    .{ .actions = s11_actions }, // 11 after header
    .{ .actions = s12_actions, .gotos = s12_gotos }, // 12 after header newline
    .{ .actions = s13_actions, .gotos = s13_gotos }, // 13 after indent
    .{ .actions = s14_actions }, // 14 after item token
    .{ .actions = s15_actions }, // 15 item done
    .{ .actions = s16_actions }, // 16 after dedent
    .{ .actions = s17_actions, .gotos = s17_gotos }, // 17 header-level items
    .{ .actions = s18_actions }, // 18 header-level first item
    .{ .actions = s19_actions }, // 19 trailing first item
    .{ .actions = s20_actions, .gotos = s20_gotos }, // 20 trailing items
};

/// Bundled outline grammar: an indentation-sensitive demo language
/// whose `newline`, `indent`, `dedent`, and `blank` tokens come from
/// the external scanner in `outline_scanner.zig`.
pub const outline_language: language_mod.Language = .{
    .metadata = .{
        .name = "outline",
        .abi_version = metadata_mod.current_abi_version,
        .version = "0.0.1",
        .symbol_count = 15,
        .state_count = 21,
        .field_count = 0,
    },
    .symbols = symbol_table,
    .token_matchers = token_matchers,
    .extra_symbols = extra_symbols,
    .table = .{
        .states = parse_states,
        .start_state = 0,
        .end_symbol = sym_end,
        .error_symbol = sym_error,
    },
    .external_scanner = .{
        .payload = null,
        .scan = outline_scanner.scan,
        .reset = outline_scanner.resetPayload,
    },
};
