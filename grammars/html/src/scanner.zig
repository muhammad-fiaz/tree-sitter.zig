const std = @import("std");
const treesitter = @import("treesitter");
const language_mod = treesitter.language_mod;
const html_parser = @import("parser.zig");

pub const ScanState = struct {
    gpa: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator) ScanState {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *ScanState) void {
        _ = self;
    }

    pub fn resetState(self: *ScanState) void {
        _ = self;
    }
};

fn validAt(valid: []const bool, symbol: u16) bool {
    if (symbol >= valid.len) return false;
    return valid[symbol];
}

pub fn scan(
    payload: ?*anyopaque,
    source: []const u8,
    start: usize,
    valid_symbols: []const bool,
) ?language_mod.ExternalScanner.ExternalToken {
    _ = payload;
    const TEXT = html_parser.sym_text;
    if (validAt(valid_symbols, TEXT)) {
        if (start >= source.len or source[start] == '<') return null;
        var i = start;
        while (i < source.len and source[i] != '<') : (i += 1) {}
        if (i > start) return .{ .symbol = TEXT, .length = i - start };
    }
    return null;
}

pub fn resetPayload(payload: ?*anyopaque) void {
    _ = payload;
}

pub fn serializePayload(payload: ?*anyopaque, buffer: []u8) usize {
    _ = payload;
    _ = buffer;
    return 0;
}

pub fn deserializePayload(payload: ?*anyopaque, buffer: []const u8) void {
    _ = payload;
    _ = buffer;
}

pub fn createPayload(allocator: std.mem.Allocator) ?*anyopaque {
    const ptr = allocator.create(ScanState) catch return null;
    ptr.* = ScanState.init(allocator);
    return ptr;
}

pub fn destroyPayload(allocator: std.mem.Allocator, payload: ?*anyopaque) void {
    if (payload) |p| {
        const self: *ScanState = @ptrCast(@alignCast(p));
        self.deinit();
        allocator.destroy(self);
    }
}

pub const external_scanner: language_mod.ExternalScanner = .{
    .payload = null,
    .scan = scan,
    .reset = resetPayload,
    .serialize = serializePayload,
    .deserialize = deserializePayload,
    .create = createPayload,
    .destroy = destroyPayload,
};
