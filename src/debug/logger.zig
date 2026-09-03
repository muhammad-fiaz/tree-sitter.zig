const std = @import("std");

pub const Level = enum(u8) {
    off = 0,
    err = 1,
    warn = 2,
    info = 3,
    debug = 4,
    trace = 5,
};

pub const Logger = struct {
    level: Level = .off,
    prefix: []const u8 = "treesitter",

    pub fn enabled(self: Logger, level: Level) bool {
        return @intFromEnum(level) <= @intFromEnum(self.level);
    }

    pub fn log(self: Logger, level: Level, comptime fmt: []const u8, args: anytype) void {
        if (!self.enabled(level)) return;
        std.debug.print("[{s}] " ++ fmt ++ "\n", .{self.prefix} ++ args);
    }

    pub fn err(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.err, fmt, args);
    }

    pub fn warn(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.warn, fmt, args);
    }

    pub fn info(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.info, fmt, args);
    }

    pub fn debug(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.debug, fmt, args);
    }

    pub fn trace(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.trace, fmt, args);
    }

    pub fn writeToIo(self: Logger, writer: *std.Io.Writer, level: Level, comptime fmt: []const u8, args: anytype) void {
        if (!self.enabled(level)) return;
        writer.print("[{s}] " ++ fmt ++ "\n", .{self.prefix} ++ args) catch {};
    }
};

pub const null_logger = Logger{ .level = .off };

test "logger: level gating" {
    const off = Logger{ .level = .off };
    try std.testing.expect(!off.enabled(.err));
    const info = Logger{ .level = .info };
    try std.testing.expect(info.enabled(.err));
    try std.testing.expect(info.enabled(.info));
    try std.testing.expect(!info.enabled(.debug));
    const all = Logger{ .level = .trace };
    try std.testing.expect(all.enabled(.trace));
    try std.testing.expect(!null_logger.enabled(.err));
}
