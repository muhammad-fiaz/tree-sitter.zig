const std = @import("std");

pub const replacement_char: u21 = 0xFFFD;
pub const max_code_point: u21 = 0x10FFFF;

pub const DecodeError = error{
    Truncated,
    InvalidStart,
    InvalidContinuation,
    Overlong,
    Surrogate,
    TooLarge,
};

pub const DecodeResult = struct {
    code_point: u21,
    len: u3,
};

pub fn decodeLength(first: u8) DecodeError!u3 {
    if (first < 0x80) return 1;
    if (first & 0xE0 == 0xC0) return 2;
    if (first & 0xF0 == 0xE0) return 3;
    if (first & 0xF8 == 0xF0) return 4;
    return error.InvalidStart;
}

pub fn decodeOne(bytes: []const u8) DecodeError!DecodeResult {
    if (bytes.len == 0) return error.Truncated;
    const first = bytes[0];
    if (first < 0x80) return .{ .code_point = first, .len = 1 };
    const len = try decodeLength(first);
    if (bytes.len < len) return error.Truncated;
    var cp: u21 = switch (len) {
        2 => @as(u21, first & 0x1F),
        3 => @as(u21, first & 0x0F),
        4 => @as(u21, first & 0x07),
        else => unreachable,
    };
    for (bytes[1..len]) |b| {
        if (b & 0xC0 != 0x80) return error.InvalidContinuation;
        cp = (cp << 6) | @as(u21, b & 0x3F);
    }
    const min: u21 = switch (len) {
        2 => 0x80,
        3 => 0x800,
        4 => 0x10000,
        else => unreachable,
    };
    if (cp < min) return error.Overlong;
    if (cp >= 0xD800 and cp <= 0xDFFF) return error.Surrogate;
    if (cp > max_code_point) return error.TooLarge;
    return .{ .code_point = cp, .len = len };
}

pub fn encodeLength(cp: u21) u3 {
    if (cp < 0x80) return 1;
    if (cp < 0x800) return 2;
    if (cp < 0x10000) return 3;
    return 4;
}

pub fn encodeOne(cp: u21, out: *[4]u8) []u8 {
    if (cp < 0x80) {
        out[0] = @as(u8, @intCast(cp));
        return out[0..1];
    } else if (cp < 0x800) {
        out[0] = @as(u8, @intCast(0xC0 | (cp >> 6)));
        out[1] = @as(u8, @intCast(0x80 | (cp & 0x3F)));
        return out[0..2];
    } else if (cp < 0x10000) {
        out[0] = @as(u8, @intCast(0xE0 | (cp >> 12)));
        out[1] = @as(u8, @intCast(0x80 | ((cp >> 6) & 0x3F)));
        out[2] = @as(u8, @intCast(0x80 | (cp & 0x3F)));
        return out[0..3];
    } else {
        out[0] = @as(u8, @intCast(0xF0 | (cp >> 18)));
        out[1] = @as(u8, @intCast(0x80 | ((cp >> 12) & 0x3F)));
        out[2] = @as(u8, @intCast(0x80 | ((cp >> 6) & 0x3F)));
        out[3] = @as(u8, @intCast(0x80 | (cp & 0x3F)));
        return out[0..4];
    }
}

pub fn isContinuation(b: u8) bool {
    return b & 0xC0 == 0x80;
}

pub fn stepBackToCharStart(source: []const u8, byte_index: usize) usize {
    var i = @min(byte_index, source.len);
    while (i > 0 and isContinuation(source[i - 1]) and (byte_index - i) < 4) {
        const back = byte_index - i;
        if (back >= 4) break;
        i -= 1;
        if (!isContinuation(source[i])) break;
    }
    return i;
}

pub fn countCodePoints(source: []const u8) usize {
    var n: usize = 0;
    var i: usize = 0;
    while (i < source.len) {
        const r = decodeOne(source[i..]) catch {
            i += 1;
            n += 1;
            continue;
        };
        i += r.len;
        n += 1;
    }
    return n;
}

test "unicode: ascii decode" {
    const r = try decodeOne("A");
    try std.testing.expectEqual(@as(u21, 'A'), r.code_point);
    try std.testing.expectEqual(@as(u3, 1), r.len);
}

test "unicode: multibyte decode" {
    const r = try decodeOne("é");
    try std.testing.expectEqual(@as(u21, 0xE9), r.code_point);
    try std.testing.expectEqual(@as(u3, 2), r.len);
    const euro = try decodeOne("€");
    try std.testing.expectEqual(@as(u21, 0x20AC), euro.code_point);
    try std.testing.expectEqual(@as(u3, 3), euro.len);
}

test "unicode: invalid sequences rejected" {
    try std.testing.expectError(error.Truncated, decodeOne(""));
    try std.testing.expectError(error.InvalidStart, decodeOne("\xFF"));
    try std.testing.expectError(error.Truncated, decodeOne("\xC3"));
    try std.testing.expectError(error.Overlong, decodeOne("\xC0\xAF"));
    try std.testing.expectError(error.Surrogate, decodeOne("\xED\xA0\x80"));
}

test "unicode: encode round trip" {
    const cases: []const u21 = &.{ 'A', 0xE9, 0x20AC, 0x1F600 };
    for (cases) |cp| {
        var buf: [4]u8 = undefined;
        const enc = encodeOne(cp, &buf);
        try std.testing.expectEqual(encodeLength(cp), enc.len);
        const dec = try decodeOne(enc);
        try std.testing.expectEqual(cp, dec.code_point);
    }
}

test "unicode: byte offsets stay exact" {
    const src = "aé中b";
    try std.testing.expectEqual(@as(usize, 4), countCodePoints(src));
    try std.testing.expectEqual(@as(usize, 7), src.len);
}
