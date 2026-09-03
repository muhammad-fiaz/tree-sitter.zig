const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expression_language;

/// UTF-16 input demo: inputs carrying `.utf16_le` / `.utf16_be`
/// encodings are transcoded to UTF-8 up front (tree offsets refer to
/// the UTF-8 form); conflicting BOMs and lone surrogates are errors.
pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    const utf16 = [_]u8{ 0xFF, 0xFE, '1', 0, ' ', 0, '+', 0, ' ', 0, '2', 0 };
    const State = struct {
        bytes: []const u8,
        fn read(payload: ?*anyopaque, byte_index: u32, position: treesitter.Point, bytes_read: *u32) ?[*]const u8 {
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
    var state = State{ .bytes = &utf16 };

    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(grammar);

    var tree = try parser.parseWithInput(null, null, .{
        .payload = &state,
        .read = State.read,
        .encoding = .utf16_le,
    });
    defer tree.deinit();
    std.debug.print("parsed utf16: {s} error={}\n", .{ tree.rootNode().text(), tree.hasError() });
}
