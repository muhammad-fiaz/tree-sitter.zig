const std = @import("std");
const core = @import("../core/core.zig");

pub const ReadFn = *const fn (payload: ?*anyopaque, byte_index: u32, position: core.Point, bytes_read: *u32) ?[*]const u8;

pub const InputEncoding = enum {
    utf8,
    utf16_le,
    utf16_be,
    custom,
};

pub const Input = struct {
    payload: ?*anyopaque = null,
    read: ReadFn,
    encoding: InputEncoding = .utf8,

    pub fn chunk(self: Input, byte_index: u32, position: core.Point) ?struct { ptr: [*]const u8, len: u32 } {
        var n: u32 = 0;
        const ptr = self.read(self.payload, byte_index, position, &n);
        if (ptr == null or n == 0) return null;
        return .{ .ptr = ptr.?, .len = n };
    }
};

pub const memory = @import("memory.zig");
pub const reader = @import("reader.zig");
pub const source = @import("source.zig");
pub const stream = @import("stream.zig");

pub const MemorySource = memory.MemorySource;
pub const ReaderSource = reader.ReaderSource;
pub const Source = source.Source;
pub const StreamBuffer = stream.StreamBuffer;
pub const sourceFromBytes = source.sourceFromBytes;
pub const sourceFromInput = source.sourceFromInput;
