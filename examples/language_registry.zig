const std = @import("std");
const treesitter = @import("treesitter");

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    std.debug.print("Initializing LanguageRegistry...\n", .{});
    var registry = treesitter.LanguageRegistry.init(gpa);
    defer registry.deinit();

    // Query registered languages
    std.debug.print("Registered {d} language entries.\n", .{registry.entries.items.len});

    const json_lookup = registry.getLanguage("json");
    std.debug.print("Lookup 'json': found={}\n", .{json_lookup != null});

    const file_lookup = registry.getLanguageForFile("data/config.json");
    std.debug.print("Lookup for file 'config.json': found={}\n", .{file_lookup != null});

    if (file_lookup) |lang| {
        var parser = treesitter.Parser.init(gpa);
        defer parser.deinit();
        try parser.setLanguage(lang);

        const source = "{\"service\": \"backend\", \"port\": 8080}";
        var tree = try parser.parseString(source);
        defer tree.deinit();

        std.debug.print("Parsed dynamically resolved JSON source: nodes={d}, error={}\n", .{
            tree.pool.nodes.items.len,
            tree.hasError(),
        });
    }

    std.debug.print("Language registry demonstration completed successfully!\n", .{});
}
