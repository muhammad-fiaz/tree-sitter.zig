const std = @import("std");
const logger_mod = @import("logger.zig");

pub const TraceEvent = enum {
    parse_begin,
    parse_end,
    shift,
    reduce,
    accept,
    recover,
    lex_token,
    reuse_node,
};

pub const TraceEntry = struct {
    event: TraceEvent,
    byte_offset: u32 = 0,
    symbol: u16 = 0,
    state: u16 = 0,
};

pub const Tracer = struct {
    logger: logger_mod.Logger = .{},
    entries: std.ArrayList(TraceEntry) = .empty,
    gpa: ?std.mem.Allocator = null,

    pub fn init(gpa: std.mem.Allocator, logger: logger_mod.Logger) Tracer {
        return .{ .logger = logger, .gpa = gpa };
    }

    pub fn deinit(self: *Tracer) void {
        if (self.gpa) |gpa| self.entries.deinit(gpa);
        self.* = undefined;
    }

    pub fn record(self: *Tracer, event: TraceEvent, byte_offset: u32, symbol: u16, state: u16) void {
        self.logger.debug("trace {s} byte={d} sym={d} state={d}", .{ @tagName(event), byte_offset, symbol, state });
        if (self.gpa) |gpa| {
            self.entries.append(gpa, .{ .event = event, .byte_offset = byte_offset, .symbol = symbol, .state = state }) catch {};
        }
    }

    pub fn count(self: *const Tracer) usize {
        return self.entries.items.len;
    }
};

test "trace: record and count" {
    var tracer = Tracer.init(std.testing.allocator, .{ .level = .off });
    defer tracer.deinit();
    try std.testing.expectEqual(@as(usize, 0), tracer.count());
    tracer.record(.parse_begin, 0, 0, 0);
    tracer.record(.shift, 3, 2, 5);
    try std.testing.expectEqual(@as(usize, 2), tracer.count());
    try std.testing.expectEqual(TraceEvent.shift, tracer.entries.items[1].event);
}
