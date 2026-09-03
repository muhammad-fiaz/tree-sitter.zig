const std = @import("std");

pub const Symbol = enum(u16) {
    end = 0,
    end_of_non_terminal_extra = 1,
    _,
};

pub const SymbolId = u16;

pub const no_symbol: SymbolId = std.math.maxInt(SymbolId);

pub fn symbolFromId(id: SymbolId) Symbol {
    return @enumFromInt(id);
}

pub fn symbolToId(sym: Symbol) SymbolId {
    return @intFromEnum(sym);
}

pub fn isTerminalId(symbol_count: u16, id: SymbolId) bool {
    return id < symbol_count;
}
