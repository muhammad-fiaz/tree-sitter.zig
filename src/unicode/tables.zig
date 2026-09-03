const std = @import("std");

pub fn isWhitespaceCodePoint(cp: u21) bool {
    return switch (cp) {
        0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x1680 => true,
        0x2000...0x200A => true,
        0x2028, 0x2029, 0x202F, 0x205F, 0x3000 => true,
        else => false,
    };
}

pub fn isLetterCodePoint(cp: u21) bool {
    if (cp < 0x80) return std.ascii.isAlphabetic(@as(u8, @intCast(cp)));
    return (cp >= 0xC0 and cp <= 0xD6) or
        (cp >= 0xD8 and cp <= 0xF6) or
        (cp >= 0xF8 and cp <= 0x02AF) or
        (cp >= 0x0370 and cp <= 0x1FFF) or
        (cp >= 0x2C00 and cp <= 0xD7FF) or
        (cp >= 0xF900 and cp <= 0xFDCF) or
        (cp >= 0x10000 and cp <= 0x10FFFF);
}

pub fn isDigitCodePoint(cp: u21) bool {
    if (cp < 0x80) return std.ascii.isDigit(@as(u8, @intCast(cp)));
    return (cp >= 0x660 and cp <= 0x669) or
        (cp >= 0x6F0 and cp <= 0x6F9) or
        (cp >= 0x0966 and cp <= 0x096F);
}

pub fn isWordCodePoint(cp: u21) bool {
    return isLetterCodePoint(cp) or isDigitCodePoint(cp) or cp == '_';
}
