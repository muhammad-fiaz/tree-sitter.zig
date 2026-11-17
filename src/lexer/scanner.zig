const std = @import("std");
const abi = @import("../language/abi.zig");
const core = @import("../core/root.zig");

pub const ExternalToken = struct {
    symbol: u16,
    length: usize,
};

pub const NativeScanner = struct {
    payload: ?*anyopaque = null,
    scan: *const fn (payload: ?*anyopaque, lexer: *abi.LexerInterface, valid_symbols: []const bool) bool,
    serialize: ?*const fn (payload: ?*anyopaque, buffer: []u8) usize = null,
    deserialize: ?*const fn (payload: ?*anyopaque, buffer: []const u8) void = null,
    reset: ?*const fn (payload: ?*anyopaque) void = null,
    destroy: ?*const fn (payload: ?*anyopaque) void = null,
};

/// Native Zig implementation of the classic indentation scanner
/// used by Python, Nim, and other indentation-sensitive grammars.
pub const IndentationScanner = struct {
    indent_stack: std.ArrayList(u32),
    allocator: std.mem.Allocator,

    pub const INDENT: u16 = 0;
    pub const DEDENT: u16 = 1;
    pub const NEWLINE: u16 = 2;

    pub fn init(allocator: std.mem.Allocator) IndentationScanner {
        var s = IndentationScanner{
            .indent_stack = std.ArrayList(u32).empty,
            .allocator = allocator,
        };
        s.indent_stack.append(allocator, 0) catch {};
        return s;
    }

    pub fn deinit(self: *IndentationScanner) void {
        self.indent_stack.deinit(self.allocator);
    }

    pub fn reset(self: *IndentationScanner) void {
        self.indent_stack.clearRetainingCapacity();
        self.indent_stack.append(self.allocator, 0) catch {};
    }

    pub fn serialize(self: *const IndentationScanner, buffer: []u8) usize {
        var written: usize = 0;
        for (self.indent_stack.items) |val| {
            if (written + 4 > buffer.len) break;
            std.mem.writeInt(u32, buffer[written..][0..4], val, .little);
            written += 4;
        }
        return written;
    }

    pub fn deserialize(self: *IndentationScanner, buffer: []const u8) void {
        self.indent_stack.clearRetainingCapacity();
        var offset: usize = 0;
        while (offset + 4 <= buffer.len) : (offset += 4) {
            const val = std.mem.readInt(u32, buffer[offset..][0..4], .little);
            self.indent_stack.append(self.allocator, val) catch break;
        }
        if (self.indent_stack.items.len == 0) {
            self.indent_stack.append(self.allocator, 0) catch {};
        }
    }

    pub fn scan(self: *IndentationScanner, lexer: *abi.LexerInterface, valid_symbols: []const bool) bool {
        const can_newline = if (valid_symbols.len > NEWLINE) valid_symbols[NEWLINE] else false;
        const can_indent = if (valid_symbols.len > INDENT) valid_symbols[INDENT] else false;
        const can_dedent = if (valid_symbols.len > DEDENT) valid_symbols[DEDENT] else false;

        // Skip spaces and tabs
        var indent_length: u32 = 0;
        while (!lexer.eof(lexer)) {
            const ch = lexer.lookahead;
            if (ch == ' ') {
                indent_length += 1;
                lexer.advance(lexer, true);
            } else if (ch == '\t') {
                indent_length = (indent_length + 8) & ~@as(u32, 7);
                lexer.advance(lexer, true);
            } else if (ch == '\r') {
                lexer.advance(lexer, true);
            } else if (ch == '\n') {
                indent_length = 0;
                lexer.advance(lexer, true);
                if (can_newline) {
                    lexer.result_symbol = NEWLINE;
                    lexer.mark_end(lexer);
                    return true;
                }
            } else {
                break;
            }
        }

        const current_indent = if (self.indent_stack.items.len > 0)
            self.indent_stack.items[self.indent_stack.items.len - 1]
        else
            0;

        if (indent_length > current_indent and can_indent) {
            self.indent_stack.append(self.allocator, indent_length) catch return false;
            lexer.result_symbol = INDENT;
            lexer.mark_end(lexer);
            return true;
        }

        if (indent_length < current_indent and can_dedent) {
            _ = self.indent_stack.pop();
            lexer.result_symbol = DEDENT;
            lexer.mark_end(lexer);
            return true;
        }

        return false;
    }
};

test "scanner: indentation scanner lifecycle" {
    var scanner = IndentationScanner.init(std.testing.allocator);
    defer scanner.deinit();

    var buf: [64]u8 = undefined;
    scanner.indent_stack.append(std.testing.allocator, 4) catch {};
    scanner.indent_stack.append(std.testing.allocator, 8) catch {};

    const len = scanner.serialize(&buf);
    try std.testing.expectEqual(@as(usize, 12), len);

    var restored = IndentationScanner.init(std.testing.allocator);
    defer restored.deinit();
    restored.deserialize(buf[0..len]);

    try std.testing.expectEqual(@as(usize, 3), restored.indent_stack.items.len);
    try std.testing.expectEqual(@as(u32, 0), restored.indent_stack.items[0]);
    try std.testing.expectEqual(@as(u32, 4), restored.indent_stack.items[1]);
    try std.testing.expectEqual(@as(u32, 8), restored.indent_stack.items[2]);
}
