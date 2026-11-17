const std = @import("std");
const treesitter = @import("treesitter");
const language_mod = treesitter.language_mod;
const py_parser = @import("parser.zig");

pub const ScanState = struct {
    gpa: std.mem.Allocator,
    lines: std.ArrayList(LineInfo) = .empty,
    stack: std.ArrayList(u16) = .empty,
    stacked: usize = 0,

    pub const LineInfo = struct {
        start: usize,
        indent: u16,
        blank: bool,
    };

    pub fn init(gpa: std.mem.Allocator) ScanState {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *ScanState) void {
        self.lines.deinit(self.gpa);
        self.stack.deinit(self.gpa);
        self.* = undefined;
    }

    pub fn resetState(self: *ScanState) void {
        self.lines.clearRetainingCapacity();
        self.stack.clearRetainingCapacity();
        self.stacked = 0;
    }

    fn ensureBase(self: *ScanState) std.mem.Allocator.Error!void {
        if (self.stack.items.len == 0) try self.stack.append(self.gpa, 0);
    }
};

pub fn resetPayload(payload: ?*anyopaque) void {
    const self: *ScanState = @ptrCast(@alignCast(payload orelse return));
    self.resetState();
}

pub fn serializePayload(payload: ?*anyopaque, buffer: []u8) usize {
    const self: *ScanState = @ptrCast(@alignCast(payload orelse return 0));
    var written: usize = 0;
    for (self.stack.items) |indent| {
        if (written + 2 > buffer.len) break;
        std.mem.writeInt(u16, buffer[written..][0..2], indent, .little);
        written += 2;
    }
    return written;
}

pub fn deserializePayload(payload: ?*anyopaque, buffer: []const u8) void {
    const self: *ScanState = @ptrCast(@alignCast(payload orelse return));
    self.resetState();
    var offset: usize = 0;
    while (offset + 2 <= buffer.len) : (offset += 2) {
        const indent = std.mem.readInt(u16, buffer[offset..][0..2], .little);
        self.stack.append(self.gpa, indent) catch return;
    }
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

fn validAt(valid: []const bool, symbol: u16) bool {
    if (symbol >= valid.len) return false;
    return valid[symbol];
}

fn measureLine(source: []const u8, start: usize) ScanState.LineInfo {
    var i = start;
    var indent: usize = 0;
    while (i < source.len and (source[i] == ' ' or source[i] == '\t')) : (i += 1) {
        indent += 1;
    }
    const blank = i >= source.len or source[i] == '\n' or source[i] == '\r';
    return .{
        .start = start,
        .indent = @as(u16, @intCast(@min(indent, std.math.maxInt(u16)))),
        .blank = blank,
    };
}

pub fn scan(
    payload: ?*anyopaque,
    source: []const u8,
    start: usize,
    valid_symbols: []const bool,
) ?language_mod.ExternalScanner.ExternalToken {
    const self: *ScanState = @ptrCast(@alignCast(payload orelse return null));
    self.ensureBase() catch return null;
    const NL = py_parser.sym_newline;
    const IND = py_parser.sym_indent;
    const DED = py_parser.sym_dedent;

    if (start >= source.len) {
        if (self.stack.items.len > 1 and validAt(valid_symbols, DED)) {
            _ = self.stack.pop();
            return .{ .symbol = DED, .length = 0 };
        }
        if (validAt(valid_symbols, NL)) {
            return .{ .symbol = NL, .length = 0 };
        }
        return null;
    }

    if (source[start] == '\n' or source[start] == '\r') {
        var i = start;
        if (source[i] == '\r' and i + 1 < source.len and source[i + 1] == '\n') {
            i += 2;
        } else {
            i += 1;
        }
        if (validAt(valid_symbols, NL)) {
            return .{ .symbol = NL, .length = i - start };
        }
        const next_line = measureLine(source, i);
        if (next_line.blank) return null;
        const current_indent = self.stack.items[self.stack.items.len - 1];
        if (next_line.indent > current_indent and validAt(valid_symbols, IND)) {
            self.stack.append(self.gpa, next_line.indent) catch return null;
            return .{ .symbol = IND, .length = i - start + next_line.indent };
        } else if (next_line.indent < current_indent and validAt(valid_symbols, DED)) {
            _ = self.stack.pop();
            return .{ .symbol = DED, .length = 0 };
        }
    }

    const current_line = measureLine(source, start);
    if (!current_line.blank) {
        const current_indent = self.stack.items[self.stack.items.len - 1];
        if (current_line.indent > current_indent and validAt(valid_symbols, IND)) {
            self.stack.append(self.gpa, current_line.indent) catch return null;
            return .{ .symbol = IND, .length = current_line.indent };
        } else if (current_line.indent < current_indent and validAt(valid_symbols, DED)) {
            _ = self.stack.pop();
            return .{ .symbol = DED, .length = 0 };
        }
    }

    return null;
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
