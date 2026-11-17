const std = @import("std");
const treesitter = @import("treesitter");

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    const expr_lang = treesitter.expressionLanguage;
    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(expr_lang);

    const source = "total = price * count + tax";
    var tree = try parser.parseString(source);
    defer tree.deinit();

    const query_src =
        \\(program) @local.scope
        \\(identifier) @local.definition
    ;

    var engine = try treesitter.LocalsEngine.init(gpa, expr_lang, query_src);
    defer engine.deinit();

    var table = try engine.analyze(&tree, source);
    defer table.deinit();

    std.debug.print("Local scope analysis for: '{s}'\n", .{source});
    std.debug.print("Found {d} lexical scopes:\n", .{table.scopes.items.len});
    for (table.scopes.items, 0..) |s, i| {
        std.debug.print("  Scope #{d} (parent: {?d}): {d} definitions\n", .{
            i,
            s.parent_id,
            s.definitions.items.len,
        });
        for (s.definitions.items) |def| {
            std.debug.print("    Def: '{s}' at [{d}..{d}]\n", .{
                def.name,
                def.node.startByte(),
                def.node.endByte(),
            });
        }
    }

    std.debug.print("Locals analysis demonstration completed successfully!\n", .{});
}
