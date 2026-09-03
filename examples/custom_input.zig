const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expression_language;

const Chunked = struct {
    chunks: []const []const u8,
    fn read(payload: ?*anyopaque, byte_index: u32, position: treesitter.Point, bytes_read: *u32) ?[*]const u8 {
        _ = position;
        const self: *@This() = @ptrCast(@alignCast(payload.?));
        var offset: usize = 0;
        for (self.chunks) |chunk| {
            if (@as(usize, @intCast(byte_index)) < offset + chunk.len) {
                const inner = @as(usize, @intCast(byte_index)) - offset;
                bytes_read.* = @as(u32, @intCast(chunk.len - inner));
                return chunk.ptr + inner;
            }
            offset += chunk.len;
        }
        bytes_read.* = 0;
        return null;
    }
};

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var feed = Chunked{ .chunks = &.{ "12 + ", "34" } };
    const input = treesitter.Input{ .payload = &feed, .read = Chunked.read };
    var tree = try parser.parseWithInput(null, null, input);
    defer tree.deinit();
    std.debug.print("parsed from chunks: {s} error={}\n", .{ tree.rootNode().text(), tree.hasError() });
}
