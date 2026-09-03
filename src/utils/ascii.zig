const std = @import("std");

pub const isDigit = std.ascii.isDigit;
pub const isAlphabetic = std.ascii.isAlphabetic;
pub const isAlphanumeric = std.ascii.isAlphanumeric;
pub const isWhitespace = std.ascii.isWhitespace;
pub const isUpper = std.ascii.isUpper;
pub const toLower = std.ascii.toLower;

pub fn isLower(c: u8) bool {
    return c >= 'a' and c <= 'z';
}

pub fn isHexDigit(c: u8) bool {
    return std.ascii.isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

pub fn isIdentifierStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}

pub fn isIdentifierContinue(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

pub fn eqlIgnoreCase(a: u8, b: u8) bool {
    return std.ascii.toLower(a) == std.ascii.toLower(b);
}
