const std = @import("std");
const utf8_mod = @import("utf8.zig");

/// UTF-16 decoding errors.
pub const Utf16Error = error{
    /// Fewer than 2 bytes remain for a unit, or a high surrogate lacks its pair.
    Truncated,
    /// A surrogate half appears without its partner.
    LoneSurrogate,
    /// A byte-order mark conflicts with the declared encoding.
    UnexpectedBOM,
};

pub const DecodeResult = struct {
    code_point: u21,
    /// UTF-16 code units consumed (1 or 2).
    units: u2,
};

fn readUnit(bytes: []const u8, at: usize, little_endian: bool) u16 {
    if (little_endian) {
        return @as(u16, bytes[at]) | (@as(u16, bytes[at + 1]) << 8);
    }
    return (@as(u16, bytes[at]) << 8) | @as(u16, bytes[at + 1]);
}

fn isHighSurrogate(u: u16) bool {
    return u >= 0xD800 and u <= 0xDBFF;
}

fn isLowSurrogate(u: u16) bool {
    return u >= 0xDC00 and u <= 0xDFFF;
}

/// Decode one code point at byte offset `start`. Returns the code
/// point and the number of UTF-16 units consumed.
pub fn decodeOne(bytes: []const u8, start: usize, little_endian: bool) Utf16Error!DecodeResult {
    if (start + 2 > bytes.len) return error.Truncated;
    const first = readUnit(bytes, start, little_endian);
    if (isHighSurrogate(first)) {
        if (start + 4 > bytes.len) return error.Truncated;
        const second = readUnit(bytes, start + 2, little_endian);
        if (!isLowSurrogate(second)) return error.LoneSurrogate;
        const high: u21 = @as(u21, @intCast(first - 0xD800));
        const low: u21 = @as(u21, @intCast(second - 0xDC00));
        return .{ .code_point = 0x10000 + (high << 10) + low, .units = 2 };
    }
    if (isLowSurrogate(first)) return error.LoneSurrogate;
    return .{ .code_point = @as(u21, @intCast(first)), .units = 1 };
}

/// Transcode UTF-16 (`little_endian` selects LE vs BE) to owned UTF-8.
/// A matching byte-order mark is stripped; a conflicting one is an
/// error. Lone surrogates and truncation are errors, never silent
/// replacement — malformed input must fail loudly at the boundary.
pub fn transcodeToUtf8(gpa: std.mem.Allocator, bytes: []const u8, little_endian: bool) (std.mem.Allocator.Error || Utf16Error)![]u8 {
    var start: usize = 0;
    if (bytes.len >= 2) {
        const bom_le = bytes[0] == 0xFF and bytes[1] == 0xFE;
        const bom_be = bytes[0] == 0xFE and bytes[1] == 0xFF;
        if (little_endian and bom_be) return error.UnexpectedBOM;
        if (!little_endian and bom_le) return error.UnexpectedBOM;
        if ((little_endian and bom_le) or (!little_endian and bom_be)) start = 2;
    }
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(gpa);
    var i = start;
    while (i < bytes.len) {
        if (i + 2 > bytes.len) return error.Truncated;
        const r = try decodeOne(bytes, i, little_endian);
        var buf: [4]u8 = undefined;
        const enc = utf8_mod.encodeOne(r.code_point, &buf);
        try out.appendSlice(gpa, enc);
        i += @as(usize, @intCast(r.units)) * 2;
    }
    return out.toOwnedSlice(gpa);
}

test "utf16: little-endian ascii" {
    const bytes = [_]u8{ '1', 0, ' ', 0, '+', 0, ' ', 0, '2', 0 };
    const out = try transcodeToUtf8(std.testing.allocator, &bytes, true);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("1 + 2", out);
}

test "utf16: big-endian ascii" {
    const bytes = [_]u8{ 0, 'a', 0, '+' };
    const out = try transcodeToUtf8(std.testing.allocator, &bytes, false);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("a+", out);
}

test "utf16: bom handling" {
    const le_bom = [_]u8{ 0xFF, 0xFE, 'x', 0 };
    const out = try transcodeToUtf8(std.testing.allocator, &le_bom, true);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("x", out);
    const conflict = [_]u8{ 0xFE, 0xFF, 0, 'x' };
    try std.testing.expectError(error.UnexpectedBOM, transcodeToUtf8(std.testing.allocator, &conflict, true));
}

test "utf16: astral pair" {
    // U+1F600 = D83D DE00.
    const bytes = [_]u8{ 0x3D, 0xD8, 0x00, 0xDE };
    const out = try transcodeToUtf8(std.testing.allocator, &bytes, true);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqual(@as(usize, 4), out.len);
    const dec = try utf8_mod.decodeOne(out);
    try std.testing.expectEqual(@as(u21, 0x1F600), dec.code_point);
}

test "utf16: malformed input errors" {
    const lone = [_]u8{ 0x00, 0xD8, 'A', 0 };
    try std.testing.expectError(error.LoneSurrogate, transcodeToUtf8(std.testing.allocator, &lone, true));
    const lone_low = [_]u8{ 0x00, 0xDC };
    try std.testing.expectError(error.LoneSurrogate, transcodeToUtf8(std.testing.allocator, &lone_low, true));
    const trunc = [_]u8{'a'};
    try std.testing.expectError(error.Truncated, transcodeToUtf8(std.testing.allocator, &trunc, true));
    const trunc_pair = [_]u8{ 0x00, 0xD8 };
    try std.testing.expectError(error.Truncated, transcodeToUtf8(std.testing.allocator, &trunc_pair, true));
    const empty: []const u8 = &.{};
    const out = try transcodeToUtf8(std.testing.allocator, empty, true);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqual(@as(usize, 0), out.len);
}
