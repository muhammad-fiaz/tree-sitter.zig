const std = @import("std");
const treesitter = @import("treesitter");
const unicode = treesitter.unicodeTypes;

pub fn main() !void {
    // 1-byte ASCII sequence: 'A' (U+0041)
    const ascii = try unicode.decodeOne("A");
    std.debug.print("ASCII: U+{X:0>4} (len {d})\n", .{ ascii.code_point, ascii.len });

    // 2-byte sequence: 'é' (U+00E9)
    const e_acute = try unicode.decodeOne("é");
    std.debug.print("é:     U+{X:0>4} (len {d})\n", .{ e_acute.code_point, e_acute.len });

    // 3-byte sequence: '€' (U+20AC)
    const euro = try unicode.decodeOne("€");
    std.debug.print("€:     U+{X:0>4} (len {d})\n", .{ euro.code_point, euro.len });

    // 4-byte sequence: '😀' (U+1F600)
    const emoji = try unicode.decodeOne("😀");
    std.debug.print("😀:    U+{X:0>4} (len {d})\n", .{ emoji.code_point, emoji.len });

    // Round-trip encoding
    var buf: [4]u8 = undefined;
    const encoded = unicode.encodeOne(0x1F600, &buf);
    const decoded = try unicode.decodeOne(encoded);
    std.debug.print("round-trip: U+{X:0>4} matches={}\n", .{ decoded.code_point, decoded.code_point == 0x1F600 });
}
