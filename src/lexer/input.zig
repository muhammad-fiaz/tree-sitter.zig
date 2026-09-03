const std = @import("std");
const core = @import("../core/core.zig");
const input_mod = @import("../input/input.zig");
const unicode_mod = @import("../unicode/unicode.zig");

pub const ChunkReader = struct {
    source: input_mod.source.Source,
    direct: ?[]const u8 = null,
    chunk_ptr: ?[*]const u8 = null,
    chunk_start: usize = 0,
    chunk_len: usize = 0,

    pub fn init(source: input_mod.source.Source) ChunkReader {
        return switch (source) {
            .bytes => |b| .{ .source = source, .direct = b },
            .input => .{ .source = source },
        };
    }

    pub fn byteAt(self: *ChunkReader, offset: usize) ?u8 {
        if (self.direct) |b| {
            if (offset >= b.len) return null;
            return b[offset];
        }
        if (self.chunk_ptr != null and offset >= self.chunk_start and offset < self.chunk_start + self.chunk_len) {
            return self.chunk_ptr.?[offset - self.chunk_start];
        }
        const in = self.source.input;
        var n: u32 = 0;
        const pos = self.source.pointAt(offset);
        const byte32: u32 = if (offset > std.math.maxInt(u32)) std.math.maxInt(u32) else @as(u32, @intCast(offset));
        const ptr = in.read(in.payload, byte32, pos, &n);
        if (ptr == null or n == 0) return null;
        self.chunk_ptr = ptr.?;
        self.chunk_start = offset;
        self.chunk_len = n;
        return ptr.?[0];
    }

    pub fn sliceAt(self: *ChunkReader, start: usize, end: usize) ?[]const u8 {
        if (self.direct) |b| {
            if (end > b.len or start > end) return null;
            return b[start..end];
        }
        return null;
    }

    pub fn totalLen(self: *const ChunkReader) ?usize {
        if (self.direct) |b| return b.len;
        return null;
    }
};
