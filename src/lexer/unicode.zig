const std = @import("std");
const unicode_mod = @import("../unicode/unicode.zig");

pub fn lookaheadChar(source: []const u8, offset: usize) ?u21 {
    if (offset >= source.len) return null;
    const r = unicode_mod.decodeOne(source[offset..]) catch return unicode_mod.utf8.replacement_char;
    return r.code_point;
}

pub fn charWidthAt(source: []const u8, offset: usize) usize {
    if (offset >= source.len) return 0;
    const first = source[offset];
    if (first < 0x80) return 1;
    const r = unicode_mod.decodeOne(source[offset..]) catch return 1;
    return r.len;
}

pub fn isEof(source: []const u8, offset: usize) bool {
    return offset >= source.len;
}

pub fn advanceOffset(source: []const u8, offset: usize) usize {
    return offset + charWidthAt(source, offset);
}
