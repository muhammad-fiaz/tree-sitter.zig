const std = @import("std");
const core = @import("../core/core.zig");
const input_mod = @import("input.zig");
const memory_mod = @import("memory.zig");

pub const Source = union(enum) {
    bytes: []const u8,
    input: input_mod.Input,

    pub fn byteLen(self: Source) ?usize {
        return switch (self) {
            .bytes => |b| b.len,
            .input => null,
        };
    }

    pub fn byteAt(self: Source, index: usize) ?u8 {
        switch (self) {
            .bytes => |b| {
                if (index >= b.len) return null;
                return b[index];
            },
            .input => return null,
        }
    }

    pub fn slice(self: Source, start: usize, end: usize) ?[]const u8 {
        switch (self) {
            .bytes => |b| {
                if (end > b.len or start > end) return null;
                return b[start..end];
            },
            .input => return null,
        }
    }

    pub fn pointAt(self: Source, byte_index: usize) core.Point {
        switch (self) {
            .bytes => |b| return core.pointForBytes(b, @min(byte_index, b.len)),
            .input => return .{},
        }
    }
};

pub fn sourceFromBytes(bytes: []const u8) Source {
    return .{ .bytes = bytes };
}

pub fn sourceFromInput(in: input_mod.Input) Source {
    return .{ .input = in };
}
