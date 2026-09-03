const std = @import("std");
const language_mod = @import("../language/language.zig");

pub const ExternalToken = language_mod.ExternalScanner.ExternalToken;

pub const ExternalState = struct {
    active: bool = false,

    pub fn reset(self: *ExternalState) void {
        self.active = false;
    }

    pub fn scan(
        self: *ExternalState,
        language: language_mod.Language,
        source: []const u8,
        start: usize,
        valid_symbols: []const bool,
    ) ?ExternalToken {
        _ = self;
        const scanner = language.external_scanner orelse return null;
        return scanner.scan(scanner.payload, source, start, valid_symbols);
    }

    pub fn notifyReset(self: *ExternalState, language: language_mod.Language) void {
        _ = self;
        if (language.external_scanner) |scanner| {
            if (scanner.reset) |resetFn| resetFn(scanner.payload);
        }
    }
};
