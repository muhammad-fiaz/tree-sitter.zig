const std = @import("std");
const language_mod = @import("root.zig");
const package_mod = @import("package.zig");
const Language = language_mod.Language;

pub const LanguageEntry = struct {
    name: []const u8,
    language: Language,
    scope: ?[]const u8 = null,
    file_types: []const []const u8 = &.{},
    highlights_query: ?[]const u8 = null,
    injections_query: ?[]const u8 = null,
    locals_query: ?[]const u8 = null,
    tags_query: ?[]const u8 = null,
};

pub const LanguageRegistry = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(LanguageEntry),

    pub fn init(allocator: std.mem.Allocator) LanguageRegistry {
        var reg = LanguageRegistry{
            .allocator = allocator,
            .entries = std.ArrayList(LanguageEntry).empty,
        };

        // Register default bundled languages
        reg.registerBuiltins() catch {};

        return reg;
    }

    pub fn deinit(self: *LanguageRegistry) void {
        const gpa = self.allocator;
        for (self.entries.items) |e| {
            gpa.free(e.name);
            if (e.scope) |s| gpa.free(s);
            for (e.file_types) |ft| gpa.free(ft);
            gpa.free(e.file_types);
            if (e.highlights_query) |h| gpa.free(h);
            if (e.injections_query) |inj| gpa.free(inj);
            if (e.locals_query) |loc| gpa.free(loc);
            if (e.tags_query) |t| gpa.free(t);
        }
        self.entries.deinit(gpa);
    }

    fn registerBuiltins(self: *LanguageRegistry) !void {
        try self.register("expression", language_mod.expression_language, "source.expr", &.{ "expr", "calc" });
        try self.register("json", language_mod.json_language, "source.json", &.{ "json", "avsc", "geojson" });
        try self.register("sexp", language_mod.sexp_language, "source.sexp", &.{ "scm", "lisp", "sexp" });
        try self.register("outline", language_mod.outline_language, "source.outline", &.{"outline"});
    }

    pub fn register(
        self: *LanguageRegistry,
        name: []const u8,
        lang: Language,
        scope: ?[]const u8,
        file_types: []const []const u8,
    ) !void {
        const gpa = self.allocator;
        var fts = try gpa.alloc([]const u8, file_types.len);
        for (file_types, 0..) |ft, i| {
            fts[i] = try gpa.dupe(u8, ft);
        }

        try self.entries.append(gpa, .{
            .name = try gpa.dupe(u8, name),
            .language = lang,
            .scope = if (scope) |s| try gpa.dupe(u8, s) else null,
            .file_types = fts,
        });
    }

    pub fn getLanguage(self: *const LanguageRegistry, name: []const u8) ?Language {
        for (self.entries.items) |e| {
            if (std.ascii.eqlIgnoreCase(e.name, name)) return e.language;
        }
        return null;
    }

    pub fn getLanguageForFile(self: *const LanguageRegistry, path: []const u8) ?Language {
        const ext_with_dot = std.fs.path.extension(path);
        const ext = if (ext_with_dot.len > 0 and ext_with_dot[0] == '.')
            ext_with_dot[1..]
        else
            ext_with_dot;

        for (self.entries.items) |e| {
            for (e.file_types) |ft| {
                if (std.ascii.eqlIgnoreCase(ft, ext)) return e.language;
            }
        }
        return null;
    }

    pub fn getLanguageForScope(self: *const LanguageRegistry, scope: []const u8) ?Language {
        for (self.entries.items) |e| {
            if (e.scope) |s| {
                if (std.mem.eql(u8, s, scope)) return e.language;
            }
        }
        return null;
    }
};

test "registry: lookup by name and extension" {
    var reg = LanguageRegistry.init(std.testing.allocator);
    defer reg.deinit();

    const json_lang = reg.getLanguage("json");
    try std.testing.expect(json_lang != null);

    const from_file = reg.getLanguageForFile("data/config.json");
    try std.testing.expect(from_file != null);

    const from_scope = reg.getLanguageForScope("source.json");
    try std.testing.expect(from_scope != null);
}
