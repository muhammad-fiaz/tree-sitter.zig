const std = @import("std");

pub const SymbolType = enum {
    terminal,
    non_terminal,
    external,
    end,
};

pub const SymbolMetadata = struct {
    visible: bool = true,
    named: bool = true,
    supertype: bool = false,
    extra: bool = false,
};

pub const SymbolInfo = struct {
    id: u16,
    name: []const u8,
    kind: SymbolType = .terminal,
    metadata: SymbolMetadata = .{},
};

pub fn isNamed(info: SymbolInfo) bool {
    return info.metadata.named;
}

pub fn isVisible(info: SymbolInfo) bool {
    return info.metadata.visible;
}

pub fn isExtra(info: SymbolInfo) bool {
    return info.metadata.extra;
}
