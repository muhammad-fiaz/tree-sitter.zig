const std = @import("std");
const core = @import("../core/core.zig");
const language_mod = @import("../language/language.zig");
const lexer_mod = @import("../lexer/lexer.zig");
const stream_mod = @import("../input/stream.zig");
const external_mod = @import("../lexer/external.zig");

/// Table-driven tokenizer: longest-match over the language's token
/// matchers, with extras (whitespace/comments) skipped between tokens.
///
/// Optional modes compose on top of plain slice lexing:
///
/// - Included ranges (`setRanges`): only bytes inside the parser's
///   ranges produce tokens. Gaps are skipped silently and every node
///   keeps its original coordinates.
/// - Streaming (`stream`): bytes are pulled from an `Input` callback on
///   demand instead of requiring the full text upfront.
/// - External scanner (`setExternal`): a language-provided callback that
///   runs before the built-in matchers. It receives the symbols valid in
///   the current parser state and may return context-sensitive tokens
///   (indentation, heredocs) the matchers cannot express.
pub const Tokenizer = struct {
    language: language_mod.Language,
    source: []const u8 = &.{},
    offset: usize = 0,
    position: core.Point = .{},
    ranges: []const core.Range = &.{},
    use_ranges: bool = false,
    stream: ?*stream_mod.StreamBuffer = null,
    ext: external_mod.ExternalState = .{},
    ext_valid: ?[]const bool = null,
    /// Scan-result cache: the scanner mutates its payload (indent
    /// stack), so re-scanning the same offset could decline a token it
    /// just produced. Results are cached per offset; any offset change
    /// or validity change invalidates.
    ext_cached_at: ?usize = null,
    ext_cached_tok: ?external_mod.ExternalToken = null,

    pub fn init(language: language_mod.Language) Tokenizer {
        return .{ .language = language };
    }

    pub fn reset(self: *Tokenizer, source: []const u8) void {
        self.source = source;
        self.offset = 0;
        self.position = .{};
        self.stream = null;
        self.ext_valid = null;
        self.ext_cached_at = null;
        self.ext_cached_tok = null;
    }

    pub fn resetAt(self: *Tokenizer, source: []const u8, offset: usize, position: core.Point) void {
        self.source = source;
        self.offset = @min(offset, source.len);
        self.position = position;
        self.stream = null;
        self.ext_valid = null;
        self.ext_cached_at = null;
        self.ext_cached_tok = null;
    }

    /// Attach an external scan context for the current parser state.
    /// `valid` maps symbol id to validity (action symbols plus extras).
    pub fn setExternal(self: *Tokenizer, valid: []const bool) void {
        self.ext_valid = valid;
        self.ext_cached_at = null;
        self.ext_cached_tok = null;
    }

    pub fn clearExternal(self: *Tokenizer) void {
        self.ext_valid = null;
        self.ext_cached_at = null;
        self.ext_cached_tok = null;
    }

    /// Restrict lexing to `ranges`. The parser validates ordering and
    /// overlap; the tokenizer assumes sorted, non-overlapping ranges.
    pub fn setRanges(self: *Tokenizer, ranges: []const core.Range) void {
        self.ranges = ranges;
        self.use_ranges = ranges.len > 0;
    }

    pub fn eof(self: *const Tokenizer) bool {
        return self.offset >= self.source.len;
    }

    /// Re-read the live slice after the stream pulled more bytes.
    fn syncSource(self: *Tokenizer) void {
        if (self.stream) |s| self.source = s.bytes();
    }

    /// Ensure `[0, end)` is buffered when streaming; no-op otherwise.
    fn fill(self: *Tokenizer, end: usize) void {
        if (self.stream) |s| {
            s.require(end) catch {};
            self.syncSource();
        }
    }

    fn matchAt(self: *const Tokenizer, symbol: u16) ?usize {
        for (self.language.token_matchers) |m| {
            if (m.symbol == symbol) return m.match(self.source, self.offset);
        }
        return null;
    }

    /// Index of the range containing `off`, if any.
    fn rangeContaining(self: *const Tokenizer, off: u32) ?usize {
        for (self.ranges, 0..) |r, i| {
            if (off >= r.start_byte and off < r.end_byte) return i;
        }
        return null;
    }

    /// Skip bytes outside the included ranges, keeping `position` exact.
    /// Excluded gaps never produce tokens and never produce errors.
    fn clampToRanges(self: *Tokenizer) void {
        if (!self.use_ranges) return;
        while (true) {
            const off: u32 = @as(u32, @intCast(@min(self.offset, std.math.maxInt(u32))));
            if (self.rangeContaining(off) != null) return;
            var next_start: ?usize = null;
            for (self.ranges) |r| {
                if (r.start_byte > off) {
                    const s: usize = @as(usize, @intCast(r.start_byte));
                    if (next_start == null or s < next_start.?) next_start = s;
                }
            }
            if (next_start) |ns| {
                self.fill(ns);
                const target = @min(ns, self.source.len);
                if (target <= self.offset) {
                    // Input ended inside the gap: force EOF.
                    self.advanceBy(self.source.len - self.offset);
                    return;
                }
                self.advanceBy(target - self.offset);
                continue;
            }
            self.advanceBy(self.source.len - self.offset);
            return;
        }
    }

    pub fn skipExtras(self: *Tokenizer) void {
        while (true) {
            self.fill(self.offset + 1);
            self.clampToRanges();
            // External extras first: the scanner owns whitespace-sensitive
            // decisions (indentation); zero-length extras are ignored so
            // skipping always makes progress. A non-extra result ends
            // skipping at once so internal extras cannot consume bytes
            // belonging to the scanner's token.
            if (self.scanExternal()) |tok| {
                if (self.language.symbolIsExtra(tok.symbol)) {
                    if (tok.length == 0) return;
                    self.advanceBy(@min(tok.length, self.source.len - self.offset));
                    // The offset moved: cached scan no longer applies.
                    self.ext_cached_at = null;
                    self.ext_cached_tok = null;
                    continue;
                }
                return;
            }
            var best_len: usize = 0;
            for (self.language.extra_symbols) |sym| {
                if (self.matchAt(sym)) |len| {
                    if (len > best_len) best_len = len;
                }
            }
            if (best_len == 0) return;
            self.advanceBy(best_len);
        }
    }

    /// Ask the language's external scanner for a token at the current
    /// offset. Returns null when no scanner applies, no valid set is
    /// attached, or the scanner declines. Results are cached per offset
    /// because scanners may mutate payload state when deciding.
    fn scanExternal(self: *Tokenizer) ?external_mod.ExternalToken {
        if (self.language.external_scanner == null) return null;
        const valid = self.ext_valid orelse return null;
        if (self.ext_cached_at) |at| {
            if (at == self.offset) return self.ext_cached_tok;
        }
        self.fill(self.offset + 1);
        const tok = self.ext.scan(self.language, self.source, self.offset, valid);
        self.ext_cached_at = self.offset;
        self.ext_cached_tok = tok;
        return tok;
    }

    /// Whether the scanner's result names a currently-valid symbol.
    fn extSymbolValid(self: *const Tokenizer, symbol: u16) bool {
        const valid = self.ext_valid orelse return false;
        if (symbol >= valid.len) return false;
        return valid[symbol];
    }

    /// Convert a scanner result into a positioned token.
    fn externalToken(self: *Tokenizer, tok: external_mod.ExternalToken, start_offset: usize, start_point: core.Point) lexer_mod.Token {
        return self.emitToken(tok.symbol, start_offset, tok.length, start_point);
    }

    pub fn nextToken(self: *Tokenizer) lexer_mod.Token {
        self.fill(self.offset + 1);
        self.clampToRanges();
        self.skipExtras();
        self.clampToRanges();
        const start_offset = self.offset;
        const start_point = self.position;
        // External scanner first: context-sensitive tokens win over the
        // built-in longest match, including zero-width structural tokens
        // at end of input (dedents). Zero-length results are legal for
        // structural tokens (indent/dedent); extras must consume input.
        if (self.scanExternal()) |ext| {
            const is_extra = self.language.symbolIsExtra(ext.symbol);
            if ((!is_extra or ext.length > 0) and self.extSymbolValid(ext.symbol)) {
                const start_u32: u32 = @as(u32, @intCast(@min(start_offset, std.math.maxInt(u32))));
                const end_u32: u32 = @as(u32, @intCast(@min(start_offset + ext.length, std.math.maxInt(u32))));
                if (!self.use_ranges or self.tokenInRanges(start_u32, end_u32)) {
                    return self.externalToken(ext, start_offset, start_point);
                }
            }
        }
        const at_end = self.offset >= self.source.len and
            (self.stream == null or self.stream.?.eof_seen);
        if (at_end) {
            return .{
                .symbol = self.language.table.end_symbol,
                .start_byte = @as(u32, @intCast(@min(start_offset, std.math.maxInt(u32)))),
                .end_byte = @as(u32, @intCast(@min(start_offset, std.math.maxInt(u32)))),
                .start_point = start_point,
                .end_point = start_point,
            };
        }
        // When streaming, a match that touches the buffered end may be
        // a truncated prefix: pull more input and retry until the match
        // is strictly interior or the callback reports EOF.
        while (true) {
            const found = self.longestMatch();
            if (found == null) {
                return .{
                    .symbol = std.math.maxInt(u16),
                    .start_byte = @as(u32, @intCast(@min(start_offset, std.math.maxInt(u32)))),
                    .end_byte = @as(u32, @intCast(@min(start_offset, std.math.maxInt(u32)))),
                    .start_point = start_point,
                    .end_point = start_point,
                };
            }
            const best_symbol = found.?.symbol;
            const best_len = found.?.len;
            const end = start_offset + best_len;
            const complete = self.stream == null or self.stream.?.eof_seen or end < self.source.len;
            if (!complete) {
                const before = self.source.len;
                self.fill(before + 1);
                if (self.source.len == before) {
                    // No progress: treat the buffered bytes as final.
                    return self.emitToken(best_symbol, start_offset, best_len, start_point);
                }
                continue;
            }
            if (self.use_ranges and !self.tokenInRanges(@as(u32, @intCast(@min(start_offset, std.math.maxInt(u32)))), @as(u32, @intCast(@min(end, std.math.maxInt(u32)))))) {
                return .{
                    .symbol = std.math.maxInt(u16),
                    .start_byte = @as(u32, @intCast(@min(start_offset, std.math.maxInt(u32)))),
                    .end_byte = @as(u32, @intCast(@min(start_offset, std.math.maxInt(u32)))),
                    .start_point = start_point,
                    .end_point = start_point,
                };
            }
            return self.emitToken(best_symbol, start_offset, best_len, start_point);
        }
    }

    const Match = struct {
        symbol: u16,
        len: usize,
    };

    fn longestMatch(self: *Tokenizer) ?Match {
        var best_symbol: u16 = 0;
        var best_len: usize = 0;
        var found = false;
        for (self.language.token_matchers) |m| {
            if (self.language.symbolIsExtra(m.symbol)) continue;
            if (m.match(self.source, self.offset)) |len| {
                if (len > best_len) {
                    best_len = len;
                    best_symbol = m.symbol;
                    found = true;
                }
            }
        }
        if (!found or best_len == 0) return null;
        return .{ .symbol = best_symbol, .len = best_len };
    }

    /// A token must lie within a single included range.
    fn tokenInRanges(self: *const Tokenizer, start: u32, end: u32) bool {
        for (self.ranges) |r| {
            if (start >= r.start_byte and end <= r.end_byte) return true;
        }
        return false;
    }

    fn emitToken(self: *Tokenizer, symbol: u16, start_offset: usize, len: usize, start_point: core.Point) lexer_mod.Token {
        var end_point = start_point;
        const end_offset = @min(start_offset + len, self.source.len);
        for (self.source[start_offset..end_offset]) |b| {
            end_point = core.advancePoint(end_point, b);
        }
        self.offset = end_offset;
        self.position = end_point;
        return .{
            .symbol = symbol,
            .start_byte = @as(u32, @intCast(@min(start_offset, std.math.maxInt(u32)))),
            .end_byte = @as(u32, @intCast(@min(end_offset, std.math.maxInt(u32)))),
            .start_point = start_point,
            .end_point = end_point,
        };
    }

    fn advanceBy(self: *Tokenizer, n: usize) void {
        const target = @min(self.offset + n, self.source.len);
        while (self.offset < target) {
            self.position = core.advancePoint(self.position, self.source[self.offset]);
            self.offset += 1;
        }
    }

    pub fn advanceBytes(self: *Tokenizer, n: usize) void {
        self.advanceBy(n);
    }
};
