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
        \\  "script": "x = 10; y = 20;"
        \\}
    ;

    var tree = try parser.parseString(source);
    defer tree.deinit();

    std.debug.print("Host tree parsed: error={}\n", .{tree.hasError()});

    const query_src =
        \\((pair (string) @name (value) @injection.content)
        \\ (#set! injection.language "javascript"))
    ;

    var engine = try treesitter.InjectionEngine.init(gpa, json_lang, query_src);
    defer engine.deinit();

    const regions = try engine.collectInjections(&tree, source);
    defer {
        for (regions) |r| {
            gpa.free(r.language_name);
            gpa.free(r.ranges);
        }
        gpa.free(regions);
    }

    std.debug.print("Collected {d} language injection regions:\n", .{regions.len});
    for (regions, 0..) |r, i| {
        std.debug.print("  Region #{d}: target language '{s}', ranges count={d}\n", .{
            i + 1,
            r.language_name,
            r.ranges.len,
        });
        for (r.ranges) |range| {
            const snippet = source[range.start_byte..range.end_byte];
            std.debug.print("    Bytes [{d}..{d}]: '{s}'\n", .{ range.start_byte, range.end_byte, snippet });
        }
    }

    std.debug.print("Language injection demonstration completed successfully!\n", .{});
}
