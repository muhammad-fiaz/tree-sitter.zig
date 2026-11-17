const std = @import("std");

pub const GrammarConfig = struct {
    name: []const u8,
    scope: []const u8,
    path: []const u8 = ".",
    file_types: []const []const u8 = &.{},
    highlights: []const []const u8 = &.{},
    injections: []const []const u8 = &.{},
    locals: []const []const u8 = &.{},
    tags: []const []const u8 = &.{},
    injection_regex: ?[]const u8 = null,

    pub fn deinit(self: *GrammarConfig, gpa: std.mem.Allocator) void {
        gpa.free(self.name);
        gpa.free(self.scope);
        gpa.free(self.path);
        for (self.file_types) |f| gpa.free(f);
        gpa.free(self.file_types);
        for (self.highlights) |h| gpa.free(h);
        gpa.free(self.highlights);
        for (self.injections) |inj| gpa.free(inj);
        gpa.free(self.injections);
        for (self.locals) |l| gpa.free(l);
        gpa.free(self.locals);
        for (self.tags) |t| gpa.free(t);
        gpa.free(self.tags);
        if (self.injection_regex) |r| gpa.free(r);
    }
};

pub const PackageConfig = struct {
    grammars: []GrammarConfig,

    pub fn deinit(self: *PackageConfig, gpa: std.mem.Allocator) void {
        for (self.grammars) |*g| g.deinit(gpa);
        gpa.free(self.grammars);
    }
};

pub const PackageParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PackageParser {
        return .{ .allocator = allocator };
    }

    pub fn parse(self: *PackageParser, json_text: []const u8) !PackageConfig {
        const gpa = self.allocator;
        const parsed = try std.json.parseFromSlice(std.json.Value, gpa, json_text, .{});
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidTreeSitterJSON;

        var grammars_list = std.ArrayList(GrammarConfig).empty;
        errdefer {
            for (grammars_list.items) |*g| g.deinit(gpa);
            grammars_list.deinit(gpa);
        }

        if (root.object.get("grammars")) |grammars_val| {
            if (grammars_val == .array) {
                for (grammars_val.array.items) |gval| {
                    if (gval == .object) {
                        const name_val = gval.object.get("name") orelse continue;
                        if (name_val != .string) continue;
                        const scope_val = gval.object.get("scope");
                        const scope_str = if (scope_val != null and scope_val.? == .string) scope_val.?.string else "";
                        const path_val = gval.object.get("path");
                        const path_str = if (path_val != null and path_val.? == .string) path_val.?.string else ".";

                        var file_types = std.ArrayList([]const u8).empty;
                        errdefer {
                            for (file_types.items) |f| gpa.free(f);
                            file_types.deinit(gpa);
                        }
                        if (gval.object.get("file-types")) |ft_val| {
                            if (ft_val == .array) {
                                for (ft_val.array.items) |item| {
                                    if (item == .string) {
                                        try file_types.append(gpa, try gpa.dupe(u8, item.string));
                                    }
                                }
                            }
                        }

                        var highlights = std.ArrayList([]const u8).empty;
                        errdefer {
                            for (highlights.items) |h| gpa.free(h);
                            highlights.deinit(gpa);
                        }
                        if (gval.object.get("highlights")) |hl_val| {
                            try self.parsePaths(hl_val, &highlights);
                        }

                        var injections = std.ArrayList([]const u8).empty;
                        errdefer {
                            for (injections.items) |inj| gpa.free(inj);
                            injections.deinit(gpa);
                        }
                        if (gval.object.get("injections")) |inj_val| {
                            try self.parsePaths(inj_val, &injections);
                        }

                        var locals = std.ArrayList([]const u8).empty;
                        errdefer {
                            for (locals.items) |l| gpa.free(l);
                            locals.deinit(gpa);
                        }
                        if (gval.object.get("locals")) |loc_val| {
                            try self.parsePaths(loc_val, &locals);
                        }

                        var tags = std.ArrayList([]const u8).empty;
                        errdefer {
                            for (tags.items) |t| gpa.free(t);
                            tags.deinit(gpa);
                        }
                        if (gval.object.get("tags")) |tags_val| {
                            try self.parsePaths(tags_val, &tags);
                        }

                        var inj_regex: ?[]const u8 = null;
                        if (gval.object.get("injection-regex")) |ir_val| {
                            if (ir_val == .string) {
                                inj_regex = try gpa.dupe(u8, ir_val.string);
                            }
                        }

                        try grammars_list.append(gpa, .{
                            .name = try gpa.dupe(u8, name_val.string),
                            .scope = try gpa.dupe(u8, scope_str),
                            .path = try gpa.dupe(u8, path_str),
                            .file_types = try file_types.toOwnedSlice(gpa),
                            .highlights = try highlights.toOwnedSlice(gpa),
                            .injections = try injections.toOwnedSlice(gpa),
                            .locals = try locals.toOwnedSlice(gpa),
                            .tags = try tags.toOwnedSlice(gpa),
                            .injection_regex = inj_regex,
                        });
                    }
                }
            }
        }

        return .{
            .grammars = try grammars_list.toOwnedSlice(gpa),
        };
    }

    fn parsePaths(self: *PackageParser, val: std.json.Value, out: *std.ArrayList([]const u8)) !void {
        const gpa = self.allocator;
        if (val == .string) {
            try out.append(gpa, try gpa.dupe(u8, val.string));
        } else if (val == .array) {
            for (val.array.items) |item| {
                if (item == .string) {
                    try out.append(gpa, try gpa.dupe(u8, item.string));
                }
            }
        }
    }
};

test "package: parse tree-sitter.json" {
    const sample =
        \\{
        \\  "grammars": [
        \\    {
        \\      "name": "json",
        \\      "scope": "source.json",
        \\      "file-types": ["json", "avsc", "geojson"],
        \\      "highlights": "queries/highlights.scm"
        \\    }
        \\  ]
        \\}
    ;

    var parser = PackageParser.init(std.testing.allocator);
    var pkg = try parser.parse(sample);
    defer pkg.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), pkg.grammars.len);
    try std.testing.expectEqualStrings("json", pkg.grammars[0].name);
    try std.testing.expectEqualStrings("source.json", pkg.grammars[0].scope);
    try std.testing.expectEqual(@as(usize, 3), pkg.grammars[0].file_types.len);
    try std.testing.expectEqualStrings("json", pkg.grammars[0].file_types[0]);
}
