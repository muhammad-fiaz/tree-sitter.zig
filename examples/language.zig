const std = @import("std");
const treesitter = @import("treesitter");
const grammar = treesitter.expression_language;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    _ = gpa_state.allocator();

    const lang = grammar;
    std.debug.print("language: {s} abi={d} symbols={d} states={d}\n", .{
        lang.metadata.name,
        lang.metadata.abi_version,
        lang.symbolCount(),
        lang.table.stateCount(),
    });
    for (lang.symbols) |sym| {
        std.debug.print("  #{d} {s} named={} visible={}\n", .{ sym.id, sym.name, sym.metadata.named, sym.metadata.visible });
    }
    const plus = lang.symbolForName("+", false).?;
    std.debug.print("symbol for \"+\": {d}\n", .{plus});
    const left = lang.fieldIdForName("left").?;
    std.debug.print("field id for \"left\": {d} ({s})\n", .{ left, lang.fieldNameForId(left).? });
}
