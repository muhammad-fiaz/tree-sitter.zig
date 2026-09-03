const std = @import("std");
const core = @import("../core/core.zig");
const input_mod = @import("input.zig");

/// Incremental pull buffer over an `Input` callback.
///
/// `StreamBuffer` feeds the parser without pre-buffering the whole
/// input: bytes are pulled through `Input.chunk` on demand as the lexer
/// advances, and retained in one append-only cache. Peak memory stays
/// proportional to the bytes actually consumed (plus one chunk of
/// read-ahead), and parsing can start before the producer has delivered
/// EOF — the property that makes `Parser.parseStream` suitable for
/// files, sockets, and decompressors behind `std.Io.Reader`.
///
/// Offsets are `u32`, so inputs are limited to 4 GiB, matching the rest
/// of the runtime.
pub const StreamBuffer = struct {
    gpa: std.mem.Allocator,
    input: input_mod.Input,
    cache: std.ArrayList(u8) = .empty,
    /// Source position of `cache.items.len` (start of unread input).
    end_point: core.Point = .{},
    eof_seen: bool = false,

    pub fn init(gpa: std.mem.Allocator, input: input_mod.Input) StreamBuffer {
        return .{ .gpa = gpa, .input = input };
    }

    pub fn deinit(self: *StreamBuffer) void {
        self.cache.deinit(self.gpa);
        self.* = undefined;
    }

    /// Bytes buffered so far. The returned slice is invalidated by the
    /// next `require` call (the cache may reallocate); re-read it after
    /// every `require`.
    pub fn bytes(self: *const StreamBuffer) []const u8 {
        return self.cache.items;
    }

    /// Pull chunks until `[0, end)` is buffered or the callback reports
    /// EOF (returns null). Never pulls past `end` plus one chunk.
    pub fn require(self: *StreamBuffer, end: usize) std.mem.Allocator.Error!void {
        const limit: usize = @min(end, std.math.maxInt(u32));
        while (self.cache.items.len < limit and !self.eof_seen) {
            const off = self.cache.items.len;
            const chunk = self.input.chunk(@as(u32, @intCast(off)), self.end_point);
            const c = chunk orelse {
                self.eof_seen = true;
                return;
            };
            const slice = c.ptr[0..c.len];
            try self.cache.appendSlice(self.gpa, slice);
            for (slice) |b| self.end_point = core.advancePoint(self.end_point, b);
        }
    }

    /// Discard everything from `len` on, keeping `[0, len)`. Used to
    /// trim unread read-ahead before transferring ownership to a tree.
    pub fn truncate(self: *StreamBuffer, len: usize) void {
        const keep = @min(len, self.cache.items.len);
        self.cache.items.len = keep;
        self.end_point = core.pointForBytes(self.cache.items, keep);
    }

    /// Transfer cache ownership to the caller (e.g. `Tree.source`).
    /// The buffer must not be used afterwards.
    pub fn takeOwned(self: *StreamBuffer) std.mem.Allocator.Error![]u8 {
        return self.cache.toOwnedSlice(self.gpa);
    }
};

test "stream: pulls on demand and retains bytes" {
    const State = struct {
        bytes: []const u8,
        calls: usize = 0,
        fn read(payload: ?*anyopaque, byte_index: u32, position: core.Point, bytes_read: *u32) ?[*]const u8 {
            _ = position;
            const self: *@This() = @ptrCast(@alignCast(payload.?));
            self.calls += 1;
            const i: usize = @as(usize, @intCast(byte_index));
            if (i >= self.bytes.len) {
                bytes_read.* = 0;
                return null;
            }
            // One byte per chunk: forces many pull rounds.
            bytes_read.* = 1;
            return self.bytes.ptr + i;
        }
    };
    var state = State{ .bytes = "hello" };
    const input = input_mod.Input{ .payload = &state, .read = State.read };
    var buf = StreamBuffer.init(std.testing.allocator, input);
    defer buf.deinit();
    try buf.require(2);
    try std.testing.expectEqualStrings("he", buf.bytes());
    try std.testing.expect(!buf.eof_seen);
    try buf.require(100);
    try std.testing.expectEqualStrings("hello", buf.bytes());
    try std.testing.expect(buf.eof_seen);
    try std.testing.expect(state.calls > 2);
}

test "stream: truncate and takeOwned" {
    const State = struct {
        bytes: []const u8,
        fn read(payload: ?*anyopaque, byte_index: u32, position: core.Point, bytes_read: *u32) ?[*]const u8 {
            _ = position;
            const self: *@This() = @ptrCast(@alignCast(payload.?));
            const i: usize = @as(usize, @intCast(byte_index));
            if (i >= self.bytes.len) {
                bytes_read.* = 0;
                return null;
            }
            bytes_read.* = @as(u32, @intCast(self.bytes.len - i));
            return self.bytes.ptr + i;
        }
    };
    var state = State{ .bytes = "abcdef" };
    const input = input_mod.Input{ .payload = &state, .read = State.read };
    var buf = StreamBuffer.init(std.testing.allocator, input);
    defer buf.deinit();
    try buf.require(6);
    buf.truncate(3);
    try std.testing.expectEqualStrings("abc", buf.bytes());
    const owned = try buf.takeOwned();
    defer std.testing.allocator.free(owned);
    try std.testing.expectEqualStrings("abc", owned);
}
