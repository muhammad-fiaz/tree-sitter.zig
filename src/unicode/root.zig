pub const tables = @import("tables.zig");
pub const utf8 = @import("utf8.zig");
pub const utf16 = @import("utf16.zig");

pub const DecodeError = utf8.DecodeError;
pub const DecodeResult = utf8.DecodeResult;
pub const decodeOne = utf8.decodeOne;
pub const decodeLength = utf8.decodeLength;
pub const encodeOne = utf8.encodeOne;
pub const encodeLength = utf8.encodeLength;
pub const countCodePoints = utf8.countCodePoints;
pub const Utf16Error = utf16.Utf16Error;
pub const transcodeUtf16ToUtf8 = utf16.transcodeToUtf8;
pub const isWhitespaceCodePoint = tables.isWhitespaceCodePoint;
pub const isLetterCodePoint = tables.isLetterCodePoint;
pub const isWordCodePoint = tables.isWordCodePoint;
