const std = @import("std");
const treesitter = @import("treesitter");

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    const json_lang = treesitter.jsonLanguage;
    var parser = treesitter.Parser.init(gpa);
    defer parser.deinit();
    try parser.setLanguage(json_lang);

    const source =
        \\{
        \\  "server": {
        \\    "host": "localhost",
        \\    "port": 8080
        \\  },
        \\  "database": {
        \\    "url": "postgres://localhost/db"
        \\  }
        \\}
    ;

    var tree = try parser.parseString(source);
    defer tree.deinit();

    const query_src =
        \\(pair (string) @name) @definition.field
    ;

    var engine = try treesitter.TagsEngine.init(gpa, json_lang, query_src);
    defer engine.deinit();

    const tags = try engine.generateTags(&tree, source);
    defer {
        for (tags) |t| {
            gpa.free(t.name);
            if (t.doc) |d| gpa.free(d);
        }
        gpa.free(tags);
    }

    std.debug.print("Extracted {d} code tags/symbols from source:\n", .{tags.len});
    for (tags) |t| {
        std.debug.print("  Symbol: {s:<15} kind={s:<10} line={d}:{d}\n", .{
            t.name,
            @tagName(t.kind),
            t.range.start_point.row + 1,
            t.range.start_point.column + 1,
        });
    }

    std.debug.print("Tags extraction demonstration completed successfully!\n", .{});
}
