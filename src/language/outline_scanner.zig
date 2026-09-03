const std = @import("std");
const language_mod = @import("language.zig");
const outline_mod = @import("outline.zig");

/// External scanner for the bundled outline grammar: newline tracking,
/// indentation stack, blank-line skipping.
///
/// Protocol (see `Parser.syncExternal`): the parser attaches the symbols
/// valid in the current state and calls `scan` at each lex point with
/// monotonically increasing offsets within a parse (plus save/restore
/// peeks, which never move the payload backward past cached lines).
/// `resetPayload` runs at the start of every parse because a new source
/// invalidates cached line data.
///
/// Payload ownership: scanner state is caller-owned. Copy
/// `outline_language`, point its `external_scanner.payload` at a live
/// `ScanState`, and pass the copy to `setLanguage`:
///
/// ```zig
/// var lang = treesitter.outline_language;
/// var state = treesitter.OutlineScanState.init(gpa);
/// defer state.deinit();
/// lang.external_scanner.?.payload = &state;
/// try parser.setLanguage(lang);
/// ```
///
/// Indentation rules: leading spaces set the level (tabs count as one
/// column each; spaces recommended). A deeper level emits one `indent`
/// covering the whitespace run; a shallower level emits one zero-width
/// `dedent` per popped level per call; equal levels lex internally.
/// Blank lines (whitespace only) become `blank` extras. A final line
/// without a newline gets a virtual zero-width `newline` at EOF, then
/// pending dedents unwind.
pub const ScanState = struct {
    gpa: std.mem.Allocator,
    lines: std.ArrayList(LineInfo) = .empty,
    stack: std.ArrayList(u16) = .empty,
    /// Lines reflected in `stack`.
    stacked: usize = 0,

    pub const LineInfo = struct {
        start: usize,
        indent: u16,
        blank: bool,
    };

    pub fn init(gpa: std.mem.Allocator) ScanState {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *ScanState) void {
        self.lines.deinit(self.gpa);
        self.stack.deinit(self.gpa);
        self.* = undefined;
    }

    pub fn resetState(self: *ScanState) void {
        self.lines.clearRetainingCapacity();
        self.stack.clearRetainingCapacity();
        self.stacked = 0;
    }

    fn ensureBase(self: *ScanState) std.mem.Allocator.Error!void {
        if (self.stack.items.len == 0) try self.stack.append(self.gpa, 0);
    }
};

pub fn resetPayload(payload: ?*anyopaque) void {
    const self: *ScanState = @ptrCast(@alignCast(payload orelse return));
    self.resetState();
}

fn validAt(valid: []const bool, symbol: u16) bool {
    if (symbol >= valid.len) return false;
    return valid[symbol];
}

/// Extend the line cache so it covers `offset`, then return its line.
fn lineOf(self: *ScanState, source: []const u8, offset: usize) std.mem.Allocator.Error!usize {
    const off = @min(offset, source.len);
    while (true) {
        if (self.lines.items.len > 0) {
            const last = self.lines.items[self.lines.items.len - 1];
            const line_end = lineEnd(source, last.start);
            if (off <= line_end) break;
            const next_start = line_end + 1;
            if (next_start > source.len) break;
            try self.lines.append(self.gpa, measureLine(source, next_start));
        } else {
            try self.lines.append(self.gpa, measureLine(source, 0));
        }
    }
    // Binary search: last line with start <= off.
    var lo: usize = 0;
    var hi: usize = self.lines.items.len;
    while (lo + 1 < hi) {
        const mid = lo + (hi - lo) / 2;
        if (self.lines.items[mid].start <= off) {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    return lo;
}

fn lineEnd(source: []const u8, start: usize) usize {
    var i = start;
    while (i < source.len and source[i] != '\n') : (i += 1) {}
    return i;
}

fn measureLine(source: []const u8, start: usize) ScanState.LineInfo {
    var i = start;
    var indent: usize = 0;
    while (i < source.len and (source[i] == ' ' or source[i] == '\t')) : (i += 1) {
        indent += 1;
    }
    const blank = i >= source.len or source[i] == '\n';
    return .{
        .start = start,
        .indent = @as(u16, @intCast(@min(indent, std.math.maxInt(u16)))),
        .blank = blank,
    };
}

/// Replay cached indents into the stack through `line` (exclusive).
/// Blank lines never touch the stack. Deterministic, so backward peeks
/// rebuild by resetting first.
fn syncStack(self: *ScanState, line: usize) std.mem.Allocator.Error!void {
    try self.ensureBase();
    if (line < self.stacked) {
        self.stack.items.len = 1;
        self.stacked = 0;
    }
    while (self.stacked < line and self.stacked < self.lines.items.len) {
        const info = self.lines.items[self.stacked];
        if (!info.blank) {
            while (self.stack.items.len > 1 and self.stack.items[self.stack.items.len - 1] > info.indent) {
                _ = self.stack.pop();
            }
            const top = self.stack.items[self.stack.items.len - 1];
            if (top < info.indent) try self.stack.append(self.gpa, info.indent);
        }
        self.stacked += 1;
    }
}

fn contentStart(source: []const u8, line_start: usize) usize {
    var i = line_start;
    while (i < source.len and (source[i] == ' ' or source[i] == '\t')) : (i += 1) {}
    return i;
}

pub fn scan(
    payload: ?*anyopaque,
    source: []const u8,
    start: usize,
    valid_symbols: []const bool,
) ?language_mod.ExternalScanner.ExternalToken {
    const self: *ScanState = @ptrCast(@alignCast(payload orelse return null));
    return scanInner(self, source, start, valid_symbols) catch null;
}

fn scanInner(
    self: *ScanState,
    source: []const u8,
    start: usize,
    valid: []const bool,
) std.mem.Allocator.Error!?language_mod.ExternalScanner.ExternalToken {
    const NL = outline_mod.sym_newline;
    const IND = outline_mod.sym_indent;
    const DED = outline_mod.sym_dedent;
    const BLK = outline_mod.sym_blank;
    if (start > source.len) return null;

    // End of input: virtual newline for an unterminated content line,
    // then unwind open levels one dedent per call.
    if (start >= source.len) {
        if (source.len > 0 and source[source.len - 1] != '\n') {
            const line = try lineOf(self, source, source.len);
            try syncStack(self, line);
            const info = self.lines.items[line];
            if (!info.blank and validAt(valid, NL)) {
                return .{ .symbol = NL, .length = 0 };
            }
        }
        try self.ensureBase();
        if (self.stack.items.len > 1 and validAt(valid, DED)) {
            _ = self.stack.pop();
            return .{ .symbol = DED, .length = 0 };
        }
        return null;
    }

    const line = try lineOf(self, source, start);
    const info = self.lines.items[line];
    try syncStack(self, line);
    try self.ensureBase();
    const top = self.stack.items[self.stack.items.len - 1];

    // Blank line: consume through the newline as an extra.
    if (info.blank) {
        if (!validAt(valid, BLK)) return null;
        const end = lineEnd(source, info.start);
        const len = @min(end + 1, source.len) - start;
        return .{ .symbol = BLK, .length = len };
    }

    // Indentation change at this line: one level per call (zero-width
    // dedents re-enter at the same offset).
    if (top > info.indent) {
        if (!validAt(valid, DED)) return null;
        _ = self.stack.pop();
        return .{ .symbol = DED, .length = 0 };
    }
    if (top < info.indent) {
        if (!validAt(valid, IND)) return null;
        try self.stack.append(self.gpa, info.indent);
        const content = contentStart(source, info.start);
        return .{ .symbol = IND, .length = content - info.start };
    }

    // Same level: newline right after content, otherwise internal lexing
    // (ws extras eat stale indent runs; header/item match the content).
    if (source[start] == '\n') {
        if (!validAt(valid, NL)) return null;
        return .{ .symbol = NL, .length = 1 };
    }
    return null;
}

test "scanner: newline and blank lines" {
    var valid_buf: [15]bool = [_]bool{true} ** 15;
    var state = ScanState.init(std.testing.allocator);
    defer state.deinit();
    const src = "- a\n\n- b\n";
    const t0 = scan(&state, src, 3, &valid_buf).?;
    try std.testing.expectEqual(outline_mod.sym_newline, t0.symbol);
    try std.testing.expectEqual(@as(usize, 1), t0.length);
    const t1 = scan(&state, src, 4, &valid_buf).?;
    try std.testing.expectEqual(outline_mod.sym_blank, t1.symbol);
    try std.testing.expectEqual(@as(usize, 1), t1.length);
    // Content line at equal indent: internal lexing takes over.
    try std.testing.expect(scan(&state, src, 5, &valid_buf) == null);
    const t2 = scan(&state, src, 8, &valid_buf).?;
    try std.testing.expectEqual(outline_mod.sym_newline, t2.symbol);
}

test "scanner: indent and dedent levels" {
    var valid_buf: [15]bool = [_]bool{true} ** 15;
    // Drive: NEWLINE after "# T", then line 1 indented.
    var state = ScanState.init(std.testing.allocator);
    defer state.deinit();
    const src = "# T\n  - a\n- b\n";
    const t0 = scan(&state, src, 3, &valid_buf).?;
    try std.testing.expectEqual(outline_mod.sym_newline, t0.symbol);
    const t1 = scan(&state, src, 4, &valid_buf).?;
    try std.testing.expectEqual(outline_mod.sym_indent, t1.symbol);
    try std.testing.expectEqual(@as(usize, 2), t1.length);
    // Indent consumed its spaces; content lexes internally (null).
    try std.testing.expect(scan(&state, src, 6, &valid_buf) == null);
    const t2 = scan(&state, src, 9, &valid_buf).?;
    try std.testing.expectEqual(outline_mod.sym_newline, t2.symbol);
    const t3 = scan(&state, src, 10, &valid_buf).?;
    try std.testing.expectEqual(outline_mod.sym_dedent, t3.symbol);
    try std.testing.expectEqual(@as(usize, 0), t3.length);
}

test "scanner: nested dedent re-entry" {
    var valid_buf: [15]bool = [_]bool{true} ** 15;
    var state = ScanState.init(std.testing.allocator);
    defer state.deinit();
    const src = "# Title\n  # Sub\n  - deep\n- two";
    // Newlines after each content line.
    try std.testing.expectEqual(outline_mod.sym_newline, scan(&state, src, 7, &valid_buf).?.symbol);
    // Indented sub-header: indent covering two spaces.
    const ind = scan(&state, src, 8, &valid_buf).?;
    try std.testing.expectEqual(outline_mod.sym_indent, ind.symbol);
    try std.testing.expectEqual(@as(usize, 2), ind.length);
    // Content lexes internally.
    try std.testing.expect(scan(&state, src, 10, &valid_buf) == null);
    try std.testing.expectEqual(outline_mod.sym_newline, scan(&state, src, 15, &valid_buf).?.symbol);
    try std.testing.expect(scan(&state, src, 16, &valid_buf) == null);
    try std.testing.expectEqual(outline_mod.sym_newline, scan(&state, src, 24, &valid_buf).?.symbol);
    // Back to base: exactly one dedent, zero-width, same offset re-entry.
    const ded = scan(&state, src, 25, &valid_buf).?;
    try std.testing.expectEqual(outline_mod.sym_dedent, ded.symbol);
    try std.testing.expectEqual(@as(usize, 0), ded.length);
}
