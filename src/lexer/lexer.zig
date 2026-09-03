const std = @import("std");
const core = @import("../core/core.zig");
const unicode_mod = @import("../unicode/unicode.zig");

pub const lex_state = @import("state.zig");
pub const lex_input = @import("input.zig");
pub const lex_unicode = @import("unicode.zig");
pub const external = @import("external.zig");

pub const Token = struct {
    symbol: u16 = 0,
    start_byte: u32 = 0,
    end_byte: u32 = 0,
    start_point: core.Point = .{},
    end_point: core.Point = .{},
    extra: bool = false,
    missing: bool = false,

    pub fn len(self: Token) u32 {
        return self.end_byte - self.start_byte;
    }

    pub fn isEof(self: Token, end_symbol: u16) bool {
        return self.symbol == end_symbol;
    }
};

pub const Lexer = struct {
    source: []const u8 = &.{},
    byte_offset: usize = 0,
    position: core.Point = .{},
    token_start: usize = 0,
    token_start_point: core.Point = .{},
    token_end: usize = 0,
    lookahead_size: usize = 0,

    pub fn reset(self: *Lexer, source: []const u8) void {
        self.source = source;
        self.byte_offset = 0;
        self.position = .{};
        self.token_start = 0;
        self.token_start_point = .{};
        self.token_end = 0;
        self.lookahead_size = 0;
    }

    pub fn resetAt(self: *Lexer, source: []const u8, offset: usize, point: core.Point) void {
        self.source = source;
        self.byte_offset = @min(offset, source.len);
        self.position = point;
        self.token_start = self.byte_offset;
        self.token_start_point = point;
        self.token_end = self.byte_offset;
        self.lookahead_size = 0;
    }

    pub fn eof(self: *const Lexer) bool {
        return self.byte_offset >= self.source.len;
    }

    pub fn currentByte(self: *const Lexer) ?u8 {
        if (self.byte_offset >= self.source.len) return null;
        return self.source[self.byte_offset];
    }

    pub fn currentChar(self: *const Lexer) ?u21 {
        if (self.byte_offset >= self.source.len) return null;
        const r = unicode_mod.decodeOne(self.source[self.byte_offset..]) catch
            return unicode_mod.utf8.replacement_char;
        return r.code_point;
    }

    pub fn advance(self: *Lexer) void {
        if (self.byte_offset >= self.source.len) return;
        const b = self.source[self.byte_offset];
        self.position = core.advancePoint(self.position, b);
        self.byte_offset += 1;
        self.lookahead_size += 1;
    }

    pub fn advanceBy(self: *Lexer, n: usize) void {
        var i: usize = 0;
        while (i < n and self.byte_offset < self.source.len) : (i += 1) self.advance();
    }

    pub fn markEnd(self: *Lexer) void {
        self.token_end = self.byte_offset;
    }

    pub fn startToken(self: *Lexer) void {
        self.token_start = self.byte_offset;
        self.token_start_point = self.position;
        self.token_end = self.byte_offset;
        self.lookahead_size = 0;
    }

    pub fn skipTo(self: *Lexer, offset: usize) void {
        const target = @min(offset, self.source.len);
        while (self.byte_offset < target) self.advance();
        self.startToken();
    }

    pub fn remaining(self: *const Lexer) []const u8 {
        return self.source[self.byte_offset..];
    }

    pub fn tokenText(self: *const Lexer) []const u8 {
        const end = @min(self.token_end, self.source.len);
        return self.source[self.token_start..end];
    }

    pub fn makeToken(self: *const Lexer, symbol: u16, extra: bool) Token {
        return .{
            .symbol = symbol,
            .start_byte = @as(u32, @intCast(self.token_start)),
            .end_byte = @as(u32, @intCast(@min(self.token_end, self.source.len))),
            .start_point = self.token_start_point,
            .end_point = self.positionAt(self.token_end),
            .extra = extra,
        };
    }

    fn positionAt(self: *const Lexer, offset: usize) core.Point {
        var point = self.token_start_point;
        const end = @min(offset, self.source.len);
        for (self.source[self.token_start..end]) |b| point = core.advancePoint(point, b);
        return point;
    }
};

test "lexer: byte and point tracking" {
    var lexer = Lexer{};
    lexer.reset("ab\ncd");
    try std.testing.expect(!lexer.eof());
    try std.testing.expectEqual(@as(u8, 'a'), lexer.currentByte().?);
    lexer.advance();
    lexer.advance();
    lexer.advance();
    try std.testing.expectEqual(@as(u32, 1), lexer.position.row);
    try std.testing.expectEqual(@as(u32, 0), lexer.position.column);
    lexer.advance();
    try std.testing.expectEqual(@as(u32, 1), lexer.position.column);
    try std.testing.expect(!lexer.eof());
    lexer.advance();
    try std.testing.expect(lexer.eof());
}

test "lexer: mark end and token text" {
    var lexer = Lexer{};
    lexer.reset("hello world");
    lexer.startToken();
    lexer.advanceBy(5);
    lexer.markEnd();
    try std.testing.expectEqualStrings("hello", lexer.tokenText());
    const tok = lexer.makeToken(1, false);
    try std.testing.expectEqual(@as(u32, 0), tok.start_byte);
    try std.testing.expectEqual(@as(u32, 5), tok.end_byte);
}

test "lexer: utf8 lookahead" {
    var lexer = Lexer{};
    lexer.reset("héllo");
    try std.testing.expectEqual(@as(u8, 'h'), lexer.currentByte().?);
    lexer.advance();
    const cp = lexer.currentChar().?;
    try std.testing.expectEqual(@as(u21, 0xE9), cp);
}

test "lexer: reset at offset" {
    var lexer = Lexer{};
    lexer.resetAt("aa bb", 3, .{ .row = 0, .column = 3 });
    try std.testing.expectEqual(@as(u8, 'b'), lexer.currentByte().?);
    try std.testing.expectEqual(@as(u32, 3), lexer.position.column);
}
