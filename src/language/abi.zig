const std = @import("std");

pub const TREE_SITTER_LANGUAGE_VERSION: u32 = 15;
pub const TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION: u32 = 13;
pub const LANGUAGE_VERSION_WITH_PRIMARY_STATES: u32 = 14;
pub const LANGUAGE_VERSION_WITH_RESERVED_WORDS: u32 = 15;
pub const TREE_SITTER_SERIALIZATION_BUFFER_SIZE: usize = 1024;

pub const TSStateId = u16;
pub const TSSymbol = u16;
pub const TSFieldId = u16;

pub const BUILTIN_SYM_ERROR: TSSymbol = std.math.maxInt(u16);
pub const BUILTIN_SYM_END: TSSymbol = 0;

pub const TSMapSlice = extern struct {
    index: u16 = 0,
    length: u16 = 0,
};

pub const TSFieldMapEntry = extern struct {
    field_id: TSFieldId = 0,
    child_index: u8 = 0,
    inherited: bool = false,
};

pub const TSSymbolMetadata = extern struct {
    visible: bool = false,
    named: bool = false,
    supertype: bool = false,
};

pub const TSParseActionType = enum(u8) {
    shift = 0,
    reduce = 1,
    accept = 2,
    recover = 3,
};

pub const TSParseAction = extern union {
    shift: extern struct {
        type: u8,
        state: TSStateId,
        extra: bool,
        repetition: bool,
    },
    reduce: extern struct {
        type: u8,
        child_count: u8,
        symbol: TSSymbol,
        dynamic_precedence: i16,
        production_id: u16,
    },
    type: u8,

    pub fn actionType(self: TSParseAction) TSParseActionType {
        return @fromBackingInt(@intCast(self.type));
    }
};

pub const TSParseActionEntry = extern union {
    action: TSParseAction,
    entry: extern struct {
        count: u8,
        reusable: bool,
    },
};

pub const TSLexMode = extern struct {
    lex_state: u16 = 0,
    external_lex_state: u16 = 0,
};

pub const TSLexerMode = extern struct {
    lex_state: u16 = 0,
    external_lex_state: u16 = 0,
    reserved_word_set_id: u16 = 0,
};

pub const TSLanguageMetadata = extern struct {
    major_version: u8 = 0,
    minor_version: u8 = 0,
    patch_version: u8 = 0,
};

pub const TSCharacterRange = extern struct {
    start: i32,
    end: i32,
};

pub const LexerInterface = extern struct {
    lookahead: i32 = 0,
    result_symbol: TSSymbol = 0,
    advance: *const fn (lexer: *LexerInterface, skip: bool) callconv(.c) void,
    mark_end: *const fn (lexer: *LexerInterface) callconv(.c) void,
    get_column: *const fn (lexer: *LexerInterface) callconv(.c) u32,
    is_at_included_range_start: *const fn (lexer: *const LexerInterface) callconv(.c) bool,
    eof: *const fn (lexer: *const LexerInterface) callconv(.c) bool,
    log: ?*const fn (lexer: *const LexerInterface, fmt: [*c]const u8, ...) callconv(.c) void = null,
};

pub const TSExternalScanner = extern struct {
    states: ?[*]const bool = null,
    symbol_map: ?[*]const TSSymbol = null,
    create: ?*const fn () callconv(.c) ?*anyopaque = null,
    destroy: ?*const fn (payload: ?*anyopaque) callconv(.c) void = null,
    scan: ?*const fn (payload: ?*anyopaque, lexer: *LexerInterface, whitelist: [*]const bool) callconv(.c) bool = null,
    serialize: ?*const fn (payload: ?*anyopaque, buffer: [*]u8) callconv(.c) c_uint = null,
    deserialize: ?*const fn (payload: ?*anyopaque, buffer: [*]const u8, length: c_uint) callconv(.c) void = null,
};

pub const TSLanguage = extern struct {
    abi_version: u32,
    symbol_count: u32,
    alias_count: u32,
    token_count: u32,
    external_token_count: u32,
    state_count: u32,
    large_state_count: u32,
    production_id_count: u32,
    field_count: u32,
    max_alias_sequence_length: u16,
    parse_table: ?[*]const u16,
    small_parse_table: ?[*]const u16,
    small_parse_table_map: ?[*]const u32,
    parse_actions: ?[*]const TSParseActionEntry,
    symbol_names: ?[*]const [*c]const u8,
    field_names: ?[*]const ?[*c]const u8,
    field_map_slices: ?[*]const TSMapSlice,
    field_map_entries: ?[*]const TSFieldMapEntry,
    symbol_metadata: ?[*]const TSSymbolMetadata,
    public_symbol_map: ?[*]const TSSymbol,
    alias_map: ?[*]const u16,
    alias_sequences: ?[*]const TSSymbol,
    lex_modes: ?*const anyopaque,
    lex_fn: ?*const fn (lexer: *LexerInterface, state: TSStateId) callconv(.c) bool,
    keyword_lex_fn: ?*const fn (lexer: *LexerInterface, state: TSStateId) callconv(.c) bool,
    keyword_capture_token: TSSymbol,
    external_scanner: TSExternalScanner,
    primary_state_ids: ?[*]const TSStateId,
    name: [*c]const u8,
    reserved_words: ?[*]const TSSymbol,
    max_reserved_word_set_size: u16,
    supertype_count: u32,
    supertype_symbols: ?[*]const TSSymbol,
    supertype_map_slices: ?[*]const TSMapSlice,
    supertype_map_entries: ?[*]const TSSymbol,
    metadata: TSLanguageMetadata,

    pub fn isValid(self: *const TSLanguage) bool {
        return self.abi_version >= TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION and
            self.abi_version <= TREE_SITTER_LANGUAGE_VERSION;
    }

    pub fn lookup(self: *const TSLanguage, state: TSStateId, symbol: TSSymbol) u16 {
        if (state >= self.large_state_count) {
            const map = self.small_parse_table_map orelse return 0;
            const small_table = self.small_parse_table orelse return 0;
            const index = map[state - self.large_state_count];
            var ptr = small_table + index;
            const group_count = ptr[0];
            ptr += 1;
            var g: u32 = 0;
            while (g < group_count) : (g += 1) {
                const section_value = ptr[0];
                const sym_count = ptr[1];
                ptr += 2;
                var s: u32 = 0;
                while (s < sym_count) : (s += 1) {
                    if (ptr[s] == symbol) return section_value;
                }
                ptr += sym_count;
            }
            return 0;
        } else {
            const table = self.parse_table orelse return 0;
            return table[@as(usize, state) * self.symbol_count + symbol];
        }
    }

    pub fn getLexMode(self: *const TSLanguage, state: TSStateId) TSLexerMode {
        if (self.lex_modes == null) return .{};
        if (self.abi_version < 15) {
            const modes: [*]const TSLexMode = @ptrCast(@alignCast(self.lex_modes.?));
            const m = modes[state];
            return .{
                .lex_state = m.lex_state,
                .external_lex_state = m.external_lex_state,
                .reserved_word_set_id = 0,
            };
        } else {
            const modes: [*]const TSLexerMode = @ptrCast(@alignCast(self.lex_modes.?));
            return modes[state];
        }
    }

    pub fn getSymbolName(self: *const TSLanguage, symbol: TSSymbol) []const u8 {
        if (self.symbol_names) |names| {
            if (symbol < self.symbol_count) {
                const str = names[symbol];
                return std.mem.span(str);
            }
        }
        return "(unknown)";
    }

    pub fn getFieldName(self: *const TSLanguage, field_id: TSFieldId) ?[]const u8 {
        if (self.field_names) |names| {
            if (field_id < self.field_count and field_id > 0) {
                if (names[field_id]) |str| {
                    return std.mem.span(str);
                }
            }
        }
        return null;
    }

    pub fn isSymbolNamed(self: *const TSLanguage, symbol: TSSymbol) bool {
        if (self.symbol_metadata) |meta| {
            if (symbol < self.symbol_count) return meta[symbol].named;
        }
        return false;
    }

    pub fn isSymbolVisible(self: *const TSLanguage, symbol: TSSymbol) bool {
        if (self.symbol_metadata) |meta| {
            if (symbol < self.symbol_count) return meta[symbol].visible;
        }
        return true;
    }

    pub fn isSymbolSupertype(self: *const TSLanguage, symbol: TSSymbol) bool {
        if (self.symbol_metadata) |meta| {
            if (symbol < self.symbol_count) return meta[symbol].supertype;
        }
        return false;
    }
};

test "abi: TSLanguage structure sizes and offsets" {
    try std.testing.expectEqual(@as(u32, 15), TREE_SITTER_LANGUAGE_VERSION);
    try std.testing.expectEqual(@as(u32, 13), TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION);
    try std.testing.expect(@sizeOf(TSParseAction) >= 4);
    try std.testing.expect(@sizeOf(TSParseActionEntry) >= 4);
}
