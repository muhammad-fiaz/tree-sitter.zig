const std = @import("std");
const core = @import("../core/core.zig");
const language_mod = @import("../language/language.zig");
const tables_mod = @import("../language/tables.zig");
const lexer_mod = @import("../lexer/lexer.zig");
const subtree_mod = @import("../tree/subtree.zig");
const tree_mod = @import("../tree/tree.zig");
const debug_mod = @import("../debug/debug.zig");
const input_mod = @import("../input/input.zig");
const unicode_mod = @import("../unicode/unicode.zig");
const query_mod = @import("../query/query.zig");
const query_cursor_mod = @import("../query/cursor.zig");
const lookahead_mod = @import("lookahead.zig");
const stack_mod = @import("stack.zig");
const actions_mod = @import("actions.zig");
const reduce_mod = @import("reduce.zig");
const recover_mod = @import("recover.zig");
const state_mod = @import("state.zig");

pub const ParserError = std.mem.Allocator.Error || error{
    NoLanguage,
    Aborted,
    InvalidRange,
} || unicode_mod.Utf16Error;

const Candidate = struct {
    old_index: u32,
    start_byte: u32,
    end_byte: u32,
    start_point: core.Point,
    end_point: core.Point,
    symbol: u16,
    reuse_state: u16,
};

pub const Parser = struct {
    gpa: std.mem.Allocator,
    language: ?language_mod.Language = null,
    logger: debug_mod.Logger = .{},
    /// Optional structured trace sink (borrowed: the caller owns it and
    /// must keep it alive across parses; level-gating still applies via
    /// its own logger).
    tracer: ?*debug_mod.Tracer = null,
    ranges: std.ArrayList(core.Range) = .empty,
    stack: stack_mod.Stack = .{},
    scratch: std.ArrayList(u32) = .empty,
    candidates: std.ArrayList(Candidate) = .empty,
    reuse_tree: ?*const tree_mod.Tree = null,
    reuse_edit: ?core.InputEdit = null,
    /// Number of old-tree subtrees spliced into the most recent parse.
    reused_node_count: usize = 0,
    /// Scratch validity set for external scanners (symbol id -> valid
    /// in the current parser state). Retained across parses.
    valid_buf: std.ArrayList(bool) = .empty,

    pub fn init(gpa: std.mem.Allocator) Parser {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *Parser) void {
        self.stack.deinit(self.gpa);
        self.scratch.deinit(self.gpa);
        self.candidates.deinit(self.gpa);
        self.ranges.deinit(self.gpa);
        self.valid_buf.deinit(self.gpa);
        self.* = undefined;
    }

    pub fn setLanguage(self: *Parser, language: language_mod.Language) language_mod.Language.Error!void {
        try language.validate();
        self.language = language;
        self.stack.clearRetainingCapacity();
    }

    pub fn getLanguage(self: *const Parser) ?language_mod.Language {
        return self.language;
    }

    pub fn setLogger(self: *Parser, logger: debug_mod.Logger) void {
        self.logger = logger;
    }

    pub fn setTracer(self: *Parser, tracer: ?*debug_mod.Tracer) void {
        self.tracer = tracer;
    }

    fn trace(self: *Parser, event: debug_mod.TraceEvent, byte_offset: u32, symbol: u16, state: u16) void {
        if (self.tracer) |t| t.record(event, byte_offset, symbol, state);
    }

    /// Restrict parsing to the given byte/point ranges (editor visible
    /// regions, injections). Ranges must be sorted by `start_byte` and
    /// non-overlapping, otherwise `error.InvalidRange` is returned.
    /// The lexer enforces them: excluded gaps never produce tokens and
    /// nodes keep their original coordinates. An empty slice clears the
    /// restriction.
    pub fn setIncludedRanges(self: *Parser, ranges: []const core.Range) (std.mem.Allocator.Error || error{InvalidRange})!void {
        for (ranges, 0..) |r, i| {
            if (r.start_byte > r.end_byte) return error.InvalidRange;
            if (i > 0) {
                const prev = ranges[i - 1];
                if (r.start_byte < prev.start_byte) return error.InvalidRange;
                if (r.start_byte < prev.end_byte) return error.InvalidRange;
            }
        }
        self.ranges.clearRetainingCapacity();
        try self.ranges.appendSlice(self.gpa, ranges);
    }

    pub fn includedRanges(self: *const Parser) []const core.Range {
        return self.ranges.items;
    }

    pub fn reset(self: *Parser) void {
        self.stack.clearRetainingCapacity();
        self.scratch.clearRetainingCapacity();
        self.candidates.clearRetainingCapacity();
    }

    /// Fresh-source protocol for external scanners: notifies the
    /// language's reset hook (if any) at the start of every parse.
    /// Scanner payloads are caller-owned; see `outline_scanner.zig`.
    fn resetExternal(self: *Parser, language: language_mod.Language) void {
        _ = self;
        if (language.external_scanner) |scanner| {
            if (scanner.reset) |resetFn| resetFn(scanner.payload);
        }
    }

    /// Attach the current state's valid-symbol set to the tokenizer so
    /// an external scanner can make context-sensitive decisions. The
    /// set covers action symbols plus extras (extras are valid
    /// everywhere). Silent on allocation failure: the tokenizer then
    /// runs without external context for that step.
    fn syncExternal(
        self: *Parser,
        language: language_mod.Language,
        pst: *state_mod.ParseState,
        state: u16,
    ) std.mem.Allocator.Error!void {
        if (language.external_scanner == null) {
            pst.tokenizer.clearExternal();
            return;
        }
        const n = language.symbolCount();
        try self.valid_buf.resize(self.gpa, n);
        @memset(self.valid_buf.items, false);
        if (state < language.table.states.len) {
            for (language.table.states[state].actions) |entry| {
                if (entry.symbol < n) self.valid_buf.items[entry.symbol] = true;
            }
        }
        for (language.extra_symbols) |sym| {
            if (sym < n) self.valid_buf.items[sym] = true;
        }
        pst.tokenizer.setExternal(self.valid_buf.items);
    }

    pub fn queryCursor(self: *Parser) query_cursor_mod.QueryCursor {
        return query_cursor_mod.QueryCursor.init(self.gpa);
    }

    pub fn compileQuery(self: *Parser, source: []const u8) query_mod.QueryError!query_mod.Query {
        const language = self.language orelse return error.InvalidLanguage;
        return query_mod.Query.compile(self.gpa, language, source);
    }

    pub fn parseString(self: *Parser, source: []const u8) ParserError!tree_mod.Tree {
        return self.parse(null, null, source);
    }

    pub fn parse(
        self: *Parser,
        old_tree: ?*const tree_mod.Tree,
        edit: ?core.InputEdit,
        source: []const u8,
    ) ParserError!tree_mod.Tree {
        const language = self.language orelse return error.NoLanguage;
        return self.runParse(language, old_tree, edit, source);
    }

    pub fn parseWithInput(
        self: *Parser,
        old_tree: ?*const tree_mod.Tree,
        edit: ?core.InputEdit,
        reader_input: input_mod.Input,
    ) ParserError!tree_mod.Tree {
        var buf = std.ArrayList(u8).empty;
        defer buf.deinit(self.gpa);
        var offset: u32 = 0;
        while (true) {
            const chunk = reader_input.chunk(offset, .{}) orelse break;
            const bytes = chunk.ptr[0..chunk.len];
            try buf.appendSlice(self.gpa, bytes);
            if (chunk.len == 0) break;
            offset += chunk.len;
            if (offset >= std.math.maxInt(u32) - 4096) break;
        }
        // UTF-16 inputs are transcoded to UTF-8 up front; tree offsets
        // then refer to the UTF-8 form (documented in Input & I/O).
        // `.custom` is treated as raw UTF-8 bytes.
        switch (reader_input.encoding) {
            .utf16_le => {
                const utf8 = try unicode_mod.transcodeUtf16ToUtf8(self.gpa, buf.items, true);
                defer self.gpa.free(utf8);
                return self.parse(old_tree, edit, utf8);
            },
            .utf16_be => {
                const utf8 = try unicode_mod.transcodeUtf16ToUtf8(self.gpa, buf.items, false);
                defer self.gpa.free(utf8);
                return self.parse(old_tree, edit, utf8);
            },
            .utf8, .custom => {},
        }
        return self.parse(old_tree, edit, buf.items);
    }

    /// Parse directly from an `Input` callback without pre-buffering
    /// the whole text (true streaming): bytes are pulled on demand as
    /// the lexer advances, and the tree takes ownership of exactly the
    /// consumed prefix. Ideal for files, sockets, and decompressors
    /// behind `std.Io.Reader` (see `ReaderSource`).
    ///
    /// Subtree reuse needs the complete new text, so when `old_tree`
    /// is given the input is buffered first (same as `parseWithInput`)
    /// and the incremental path with reuse applies. Languages with an
    /// external scanner also buffer first: stateful scanners observe
    /// whole lines, which incremental pulling cannot guarantee. UTF-16
    /// inputs are transcoded first for the same reason. Pass null with
    /// a scanner-free UTF-8 language for a pure streaming parse.
    pub fn parseStream(
        self: *Parser,
        old_tree: ?*const tree_mod.Tree,
        edit: ?core.InputEdit,
        reader_input: input_mod.Input,
    ) ParserError!tree_mod.Tree {
        if (old_tree != null) return self.parseWithInput(old_tree, edit, reader_input);
        const language = self.language orelse return error.NoLanguage;
        if (language.external_scanner != null) return self.parseWithInput(null, null, reader_input);
        switch (reader_input.encoding) {
            .utf16_le, .utf16_be => return self.parseWithInput(null, null, reader_input),
            .utf8, .custom => {},
        }
        return self.runParseStream(language, reader_input);
    }

    fn runParseStream(
        self: *Parser,
        language: language_mod.Language,
        reader_input: input_mod.Input,
    ) ParserError!tree_mod.Tree {
        var pool = subtree_mod.SubtreePool{};
        errdefer pool.deinit(self.gpa);

        var stream = input_mod.StreamBuffer.init(self.gpa, reader_input);
        errdefer stream.deinit();

        var pst = state_mod.ParseState.init(language);
        defer pst.deinit(self.gpa);
        try pst.reset(self.gpa, stream.bytes());
        pst.tokenizer.stream = &stream;
        pst.tokenizer.setRanges(self.ranges.items);
        self.resetExternal(language);

        self.logger.info("parse start: streaming input", .{});
        self.trace(.parse_begin, 0, 0, language.table.start_state);

        self.candidates.clearRetainingCapacity();
        self.reuse_tree = null;
        self.reuse_edit = null;
        self.reused_node_count = 0;

        const root_idx = try self.parseLoop(language, &pst, &pool);

        const stream_root = pool.nodes.items[root_idx];
        self.logger.info("parse end: nodes={d} error={}", .{ pool.nodes.items.len, stream_root.has_error });
        self.trace(.parse_end, stream_root.end_byte, stream_root.symbol, pst.currentState());

        stream.truncate(pst.tokenizer.offset);
        const owned = try stream.takeOwned();
        errdefer self.gpa.free(owned);
        return .{
            .gpa = self.gpa,
            .language = language,
            .source = owned,
            .pool = pool,
            .root_index = root_idx,
        };
    }

    fn runParse(
        self: *Parser,
        language: language_mod.Language,
        old_tree: ?*const tree_mod.Tree,
        edit: ?core.InputEdit,
        source: []const u8,
    ) ParserError!tree_mod.Tree {
        var pool = subtree_mod.SubtreePool{};
        errdefer pool.deinit(self.gpa);

        var pst = state_mod.ParseState.init(language);
        defer pst.deinit(self.gpa);
        try pst.reset(self.gpa, source);
        pst.tokenizer.setRanges(self.ranges.items);
        self.resetExternal(language);

        self.logger.info("parse start: {d} bytes incremental={}", .{ source.len, old_tree != null });
        self.trace(.parse_begin, 0, 0, language.table.start_state);

        self.candidates.clearRetainingCapacity();
        self.reuse_tree = old_tree;
        self.reuse_edit = edit;
        self.reused_node_count = 0;
        defer {
            self.reuse_tree = null;
            self.reuse_edit = null;
        }
        if (old_tree) |ot| {
            if (ot.pool.nodes.items.len > 0 and ot.language.symbols.ptr == language.symbols.ptr) {
                self.collectReusable(ot, edit, source) catch {};
            }
        }

        const root_idx = try self.parseLoop(language, &pst, &pool);

        const root = pool.nodes.items[root_idx];
        self.logger.info("parse end: nodes={d} reused={d} error={}", .{ pool.nodes.items.len, self.reused_node_count, root.has_error });
        self.trace(.parse_end, root.end_byte, root.symbol, pst.currentState());

        const owned = try self.gpa.dupe(u8, source);
        errdefer self.gpa.free(owned);
        return .{
            .gpa = self.gpa,
            .language = language,
            .source = owned,
            .pool = pool,
            .root_index = root_idx,
        };
    }

    fn collectReusable(
        self: *Parser,
        old_tree: *const tree_mod.Tree,
        edit: ?core.InputEdit,
        new_source: []const u8,
    ) std.mem.Allocator.Error!void {
        const e = edit;
        var stack = std.ArrayList(u32).empty;
        defer stack.deinit(self.gpa);
        if (old_tree.pool.nodes.items.len == 0) return;
        try stack.append(self.gpa, old_tree.root_index);
        while (stack.pop()) |idx| {
            const n = old_tree.pool.nodes.items[idx];
            var start = n.start_byte;
            var end = n.end_byte;
            var sp = n.start_point;
            var ep = n.end_point;
            if (e) |ed| {
                start = ed.translateByte(n.start_byte);
                end = ed.translateByte(n.end_byte);
                sp = ed.translatePoint(n.start_point);
                ep = ed.translatePoint(n.end_point);
            }
            const intersects = if (e) |ed| blk: {
                if (n.start_byte == n.end_byte) {
                    break :blk n.start_byte > ed.start_byte and n.start_byte < ed.old_end_byte;
                }
                break :blk n.start_byte < ed.old_end_byte and n.end_byte > ed.start_byte;
            } else false;
            if (intersects) {
                pushChildrenReversed(&stack, self.gpa, old_tree.pool.childrenOf(n)) catch {};
                continue;
            }
            if (end > new_source.len) {
                pushChildrenReversed(&stack, self.gpa, old_tree.pool.childrenOf(n)) catch {};
                continue;
            }
            if (n.has_error or n.is_error or n.missing) {
                pushChildrenReversed(&stack, self.gpa, old_tree.pool.childrenOf(n)) catch {};
                continue;
            }
            try self.candidates.append(self.gpa, .{
                .old_index = idx,
                .start_byte = start,
                .end_byte = end,
                .start_point = sp,
                .end_point = ep,
                .symbol = n.symbol,
                .reuse_state = n.reuse_state,
            });
            if (n.child_count > 0) {
                pushChildrenReversed(&stack, self.gpa, old_tree.pool.childrenOf(n)) catch {};
            }
        }
        // Interval index: sort by start offset (longest span first) so
        // `tryReuse` can binary-search candidates instead of scanning.
        std.mem.sort(Candidate, self.candidates.items, {}, struct {
            fn lessThan(_: void, a: Candidate, b: Candidate) bool {
                if (a.start_byte != b.start_byte) return a.start_byte < b.start_byte;
                return a.end_byte > b.end_byte;
            }
        }.lessThan);
    }

    fn pushChildrenReversed(stack: *std.ArrayList(u32), gpa: std.mem.Allocator, children: []const u32) std.mem.Allocator.Error!void {
        var i = children.len;
        while (i > 0) {
            i -= 1;
            try stack.append(gpa, children[i]);
        }
    }

    fn tryReuse(
        self: *Parser,
        language: language_mod.Language,
        pst: *state_mod.ParseState,
        pool: *subtree_mod.SubtreePool,
        state: u16,
    ) std.mem.Allocator.Error!?bool {
        if (self.candidates.items.len == 0) return null;
        if (!pst.has_lookahead) {
            const tok = pst.tokenizer.nextToken();
            pst.lookahead = tok;
            pst.has_lookahead = true;
        }
        const tok = pst.lookahead;
        if (tok.symbol == reduce_mod.invalid_symbol) return null;
        if (tok.symbol == language.table.end_symbol) return null;
        switch (language.table.actionFor(state, tok.symbol)) {
            .shift => {},
            else => return null,
        }
        const source_len: u32 = @as(u32, @intCast(@min(pst.tokenizer.source.len, std.math.maxInt(u32))));
        const off: u32 = tok.start_byte;
        var best: ?Candidate = null;
        var i = lowerBoundStart(self.candidates.items, off);
        while (i < self.candidates.items.len and self.candidates.items[i].start_byte == off) : (i += 1) {
            const cand = self.candidates.items[i];
            if (cand.reuse_state != state) continue;
            if (cand.end_byte <= off) continue;
            if (cand.end_byte > source_len) continue;
            const target = if (language.table.gotoState(state, cand.symbol)) |g|
                g
            else switch (language.table.actionFor(state, cand.symbol)) {
                .shift => |t| t,
                else => continue,
            };
            if (target >= language.table.states.len and language.table.gotoState(state, cand.symbol) == null) continue;
            if (best == null or cand.end_byte > best.?.end_byte) best = cand;
        }
        const chosen = best orelse return null;
        const old_tree = self.reuse_tree orelse return null;
        const target = if (language.table.gotoState(state, chosen.symbol)) |g|
            g
        else switch (language.table.actionFor(state, chosen.symbol)) {
            .shift => |t| t,
            else => return null,
        };
        const idx = try self.cloneSubtree(old_tree, self.reuse_edit, pool, chosen.old_index, subtree_mod.no_parent);
        try pst.stack.push(self.gpa, target, idx);
        pst.tokenizer.offset = @as(usize, @intCast(chosen.end_byte));
        pst.tokenizer.position = chosen.end_point;
        pst.consumeLookahead();
        self.reused_node_count += 1;
        self.logger.debug("reuse: [{d}, {d}) sym={d}", .{ chosen.start_byte, chosen.end_byte, chosen.symbol });
        self.trace(.reuse_node, chosen.start_byte, chosen.symbol, target);
        return true;
    }

    fn cloneSubtree(
        self: *Parser,
        old_tree: *const tree_mod.Tree,
        edit: ?core.InputEdit,
        pool: *subtree_mod.SubtreePool,
        old_index: u32,
        parent: u32,
    ) std.mem.Allocator.Error!u32 {
        const old = old_tree.pool.nodes.items[old_index];
        var copied = old;
        if (edit) |ed| {
            copied.start_byte = ed.translateByte(old.start_byte);
            copied.end_byte = ed.translateByte(old.end_byte);
            copied.start_point = ed.translatePoint(old.start_point);
            copied.end_point = ed.translatePoint(old.end_point);
        }
        copied.parent = parent;
        copied.children_start = 0;
        copied.child_count = 0;
        const new_index = try pool.pushNode(self.gpa, copied);
        const children = old_tree.pool.childrenOf(old);
        if (children.len == 0) return new_index;
        // Clone each child (recursion appends whole subtrees into the
        // pool), collecting the direct child indices aside so they can
        // be appended contiguously afterwards. Recording positions
        // before/after recursion is wrong: descendants interleave with
        // direct children in the index list. The parser scratch buffer
        // is borrowed with mark/restore discipline (no per-node
        // allocation); nested levels restore to their own mark.
        const mark = self.scratch.items.len;
        defer self.scratch.items.len = mark;
        for (children) |c| {
            try self.scratch.append(self.gpa, try self.cloneSubtree(old_tree, edit, pool, c, new_index));
        }
        const direct = self.scratch.items[mark..];
        pool.nodes.items[new_index].children_start = @as(u32, @intCast(pool.child_indices.items.len));
        pool.nodes.items[new_index].child_count = @as(u32, @intCast(direct.len));
        try pool.child_indices.appendSlice(self.gpa, direct);
        return new_index;
    }

    fn pushNode(
        self: *Parser,
        pool: *subtree_mod.SubtreePool,
        node: subtree_mod.Subtree,
        children: []const u32,
        parent_updates: bool,
    ) std.mem.Allocator.Error!u32 {
        var n = node;
        if (children.len > 0) {
            const start_u = pool.child_indices.items.len;
            try pool.child_indices.appendSlice(self.gpa, children);
            n.children_start = @as(u32, @intCast(start_u));
            n.child_count = @as(u32, @intCast(children.len));
        }
        const index = try pool.pushNode(self.gpa, n);
        if (parent_updates) {
            for (children) |c| pool.nodes.items[c].parent = index;
        }
        return index;
    }

    fn drainErrors(
        self: *Parser,
        pst: *state_mod.ParseState,
        pool: *subtree_mod.SubtreePool,
        span_start: u32,
        span_end: u32,
        out: *std.ArrayList(u32),
        all: bool,
    ) std.mem.Allocator.Error!void {
        var i: usize = 0;
        while (i < pst.pending_errors.items.len) {
            const idx = pst.pending_errors.items[i];
            const n = pool.nodes.items[idx];
            const inside = n.start_byte >= span_start and n.end_byte <= span_end;
            if (all or inside) {
                try out.append(self.gpa, idx);
                _ = pst.pending_errors.orderedRemove(i);
            } else {
                i += 1;
            }
        }
        std.mem.sort(u32, out.items, pool, lessByPosition);
    }

    fn closeErrorSpan(
        self: *Parser,
        language: language_mod.Language,
        pst: *state_mod.ParseState,
        pool: *subtree_mod.SubtreePool,
    ) std.mem.Allocator.Error!void {
        if (!pst.error_span_open) return;
        pst.error_span_open = false;
        const end_byte: u32 = @as(u32, @intCast(@min(pst.tokenizer.offset, pst.source.len)));
        const end_point = pst.tokenizer.position;
        if (end_byte <= pst.error_start_byte) return;
        const node = reduce_mod.makeErrorLeaf(
            language.table.error_symbol,
            pst.error_start_byte,
            end_byte,
            pst.error_start_point,
            end_point,
        );
        const idx = try self.pushNode(pool, node, &.{}, false);
        try pst.pending_errors.append(self.gpa, idx);
        pst.error_cost += recover_mod.skipCost(end_byte - pst.error_start_byte);
        self.logger.debug("error span: [{d}, {d}) cost={d}", .{ pst.error_start_byte, end_byte, pst.error_cost });
    }

    fn openErrorSpan(self: *Parser, pst: *state_mod.ParseState, byte: u32, point: core.Point) void {
        _ = self;
        if (!pst.error_span_open) {
            pst.error_span_open = true;
            pst.error_start_byte = byte;
            pst.error_start_point = point;
        }
    }

    /// First index with `start_byte >= off` (binary search over the
    /// sorted candidate list).
    fn lowerBoundStart(cands: []const Candidate, off: u32) usize {
        var lo: usize = 0;
        var hi: usize = cands.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (cands[mid].start_byte < off) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return lo;
    }

    fn parseLoop(
        self: *Parser,
        language: language_mod.Language,
        pst: *state_mod.ParseState,
        pool: *subtree_mod.SubtreePool,
    ) std.mem.Allocator.Error!u32 {
        const table = language.table;
        const end_sym = table.end_symbol;
        var guard: u32 = 0;

        while (true) {
            // Live view: the streaming tokenizer grows this slice as it
            // pulls; buffered parses see a fixed slice.
            pst.source = pst.tokenizer.source;
            const src_len = pst.source.len;
            const guard_max: u32 = blk: {
                const est: usize = src_len * 8 + 1024;
                break :blk if (est > std.math.maxInt(u32)) std.math.maxInt(u32) else @as(u32, @intCast(est));
            };
            guard += 1;
            if (guard > guard_max and src_len > 0) break;
            const state = pst.currentState();
            self.syncExternal(language, pst, state) catch {};
            if (self.tryReuse(language, pst, pool, state) catch null) |reused| {
                _ = reused;
                continue;
            }

            pst.ensureLookahead();
            const lookahead = pst.lookahead;
            const action = if (lookahead.symbol == reduce_mod.invalid_symbol)
                tables_mod.Action.none
            else
                table.actionFor(state, lookahead.symbol);

            switch (action) {
                .accept => {
                    try self.closeErrorSpan(language, pst, pool);
                    self.logger.debug("accept at {d}", .{lookahead.start_byte});
                    self.trace(.accept, lookahead.start_byte, lookahead.symbol, state);
                    return try self.finishAccept(language, pst, pool);
                },
                .shift => |target| {
                    try self.closeErrorSpan(language, pst, pool);
                    const node = reduce_mod.makeTokenNode(language, lookahead, state);
                    const idx = try self.pushNode(pool, node, &.{}, false);
                    try pst.stack.push(self.gpa, target, idx);
                    pst.consumeLookahead();
                    self.logger.trace("shift sym={d} [{d}, {d}) -> {d}", .{ lookahead.symbol, lookahead.start_byte, lookahead.end_byte, target });
                    self.trace(.lex_token, lookahead.start_byte, lookahead.symbol, state);
                    self.trace(.shift, lookahead.start_byte, lookahead.symbol, target);
                },
                .reduce => |rule| {
                    const n: usize = @as(usize, @intCast(rule.child_count));
                    if (n >= pst.stack.depth() or n == 0) break;
                    const vals_start = pst.stack.values.items.len - n;
                    self.scratch.clearRetainingCapacity();
                    try self.scratch.appendSlice(self.gpa, pst.stack.values.items[vals_start..]);
                    const first_child = pool.nodes.items[self.scratch.items[0]];
                    const last_child = pool.nodes.items[self.scratch.items[self.scratch.items.len - 1]];
                    try self.drainErrors(pst, pool, first_child.start_byte, last_child.end_byte, &self.scratch, false);
                    pst.stack.popMany(n);
                    const parent_state = pst.currentState();
                    const first_reuse = pool.nodes.items[self.scratch.items[0]].reuse_state;
                    const node = reduce_mod.makeInteriorNode(
                        language,
                        pool,
                        rule.symbol,
                        rule.production_id,
                        self.scratch.items,
                        table.error_symbol,
                        first_reuse,
                    );
                    const idx = try self.pushNode(pool, node, self.scratch.items, true);
                    const goto = table.gotoState(parent_state, rule.symbol) orelse break;
                    try pst.stack.push(self.gpa, goto, idx);
                    self.logger.trace("reduce sym={d} kids={d} -> {d}", .{ rule.symbol, n, goto });
                    self.trace(.reduce, first_child.start_byte, rule.symbol, goto);
                },
                .none, .recover => {
                    const recovered = try self.recover(language, pst, pool, state, end_sym);
                    if (!recovered) break;
                },
            }
        }
        return try self.finalize(language, pst, pool);
    }

    fn recover(
        self: *Parser,
        language: language_mod.Language,
        pst: *state_mod.ParseState,
        pool: *subtree_mod.SubtreePool,
        state: u16,
        end_sym: u16,
    ) std.mem.Allocator.Error!bool {
        pst.recovery_ops += 1;
        if (pst.recovery_ops > recover_mod.max_recovery_ops) return false;
        const lookahead = pst.lookahead;

        if (lookahead.symbol == end_sym) {
            if (pst.missing_inserts < recover_mod.max_missing_inserts) {
                if (self.findMissingSymbol(language, state)) |miss| {
                    const byte: u32 = @as(u32, @intCast(@min(pst.tokenizer.offset, pst.source.len)));
                    const node = reduce_mod.makeMissingNode(language, miss.symbol, byte, pst.tokenizer.position, state);
                    const idx = try self.pushNode(pool, node, &.{}, false);
                    try pst.stack.push(self.gpa, miss.target, idx);
                    pst.missing_inserts += 1;
                    pst.error_cost += recover_mod.missingCost();
                    self.logger.debug("missing: sym={d} at {d}", .{ miss.symbol, byte });
                    self.trace(.recover, byte, miss.symbol, state);
                    return true;
                }
            }
            return false;
        }

        if (lookahead.symbol == reduce_mod.invalid_symbol) {
            self.openErrorSpan(pst, @as(u32, @intCast(@min(pst.tokenizer.offset, pst.source.len))), pst.tokenizer.position);
            pst.tokenizer.advanceBytes(1);
            pst.consumeLookahead();
            pst.error_cost += recover_mod.error_cost_per_skip;
            self.logger.trace("recover: skip byte at {d}", .{lookahead.start_byte});
            self.trace(.recover, lookahead.start_byte, lookahead.symbol, state);
            return true;
        }

        if (self.unwindToAction(language, pst, pool, lookahead.symbol)) {
            self.openErrorSpan(pst, lookahead.start_byte, lookahead.start_point);
            try self.closeErrorSpan(language, pst, pool);
            pst.consumeLookahead();
            pst.error_cost += recover_mod.error_cost_per_skip;
            return true;
        }

        self.openErrorSpan(pst, lookahead.start_byte, lookahead.start_point);
        pst.consumeLookahead();
        pst.error_cost += recover_mod.error_cost_per_skip;
        return true;
    }

    fn unwindToAction(
        self: *Parser,
        language: language_mod.Language,
        pst: *state_mod.ParseState,
        pool: *subtree_mod.SubtreePool,
        symbol: u16,
    ) bool {
        _ = pool;
        _ = self;
        var depth = pst.stack.depth();
        while (depth > 1) {
            const st = pst.stack.states.items[depth - 1];
            const action = language.table.actionFor(st, symbol);
            switch (action) {
                .none, .recover => {},
                else => return depth == pst.stack.depth(),
            }
            depth -= 1;
        }
        const st = pst.stack.states.items[0];
        const action = language.table.actionFor(st, symbol);
        return switch (action) {
            .none, .recover => false,
            else => true,
        };
    }

    const MissingPick = struct {
        symbol: u16,
        target: u16,
    };

    fn findMissingSymbol(self: *Parser, language: language_mod.Language, state: u16) ?MissingPick {
        _ = self;
        if (state >= language.table.states.len) return null;
        var fallback: ?MissingPick = null;
        for (language.table.states[state].actions) |entry| {
            const target = switch (entry.action) {
                .shift => |t| t,
                else => continue,
            };
            if (entry.symbol == language.table.end_symbol) continue;
            if (language.symbolIsExtra(entry.symbol)) continue;
            if (fallback == null) fallback = .{ .symbol = entry.symbol, .target = target };
            if (target < language.table.states.len) {
                for (language.table.states[target].actions) |a2| {
                    if (a2.symbol == language.table.end_symbol) {
                        switch (a2.action) {
                            .reduce, .accept => return .{ .symbol = entry.symbol, .target = target },
                            else => {},
                        }
                    }
                }
            }
        }
        return fallback;
    }

    fn finishAccept(
        self: *Parser,
        language: language_mod.Language,
        pst: *state_mod.ParseState,
        pool: *subtree_mod.SubtreePool,
    ) std.mem.Allocator.Error!u32 {
        if (pst.stack.values.items.len == 0) {
            const node = reduce_mod.makeEmptyNode(language, pst.start_symbol, 0, .{});
            return try self.pushNode(pool, node, &.{}, false);
        }
        const root_idx = pst.stack.values.items[pst.stack.values.items.len - 1];
        if (pst.pending_errors.items.len > 0) {
            self.scratch.clearRetainingCapacity();
            try self.scratch.appendSlice(self.gpa, pool.childrenOf(pool.nodes.items[root_idx]));
            try self.drainErrors(pst, pool, 0, std.math.maxInt(u32), &self.scratch, true);
            const root = &pool.nodes.items[root_idx];
            const start_u = pool.child_indices.items.len;
            try pool.child_indices.appendSlice(self.gpa, self.scratch.items);
            root.children_start = @as(u32, @intCast(start_u));
            root.child_count = @as(u32, @intCast(self.scratch.items.len));
            root.has_error = true;
            var named: u32 = 0;
            for (self.scratch.items) |c| {
                pool.nodes.items[c].parent = root_idx;
                if (pool.nodes.items[c].named) named += 1;
            }
            root.named_child_count = named;
        }
        return root_idx;
    }

    fn finalize(
        self: *Parser,
        language: language_mod.Language,
        pst: *state_mod.ParseState,
        pool: *subtree_mod.SubtreePool,
    ) std.mem.Allocator.Error!u32 {
        try self.closeErrorSpan(language, pst, pool);
        self.scratch.clearRetainingCapacity();
        try self.scratch.appendSlice(self.gpa, pst.stack.values.items);
        try self.drainErrors(pst, pool, 0, std.math.maxInt(u32), &self.scratch, true);
        std.mem.sort(u32, self.scratch.items, pool, lessByPositionFn);
        if (self.scratch.items.len == 0) {
            const off: u32 = @as(u32, @intCast(@min(pst.tokenizer.offset, pst.source.len)));
            const node = reduce_mod.makeEmptyNode(language, pst.start_symbol, off, pst.tokenizer.position);
            return try self.pushNode(pool, node, &.{}, false);
        }
        if (self.scratch.items.len == 1 and pst.pending_errors.items.len == 0) {
            return self.scratch.items[0];
        }
        const first = pool.nodes.items[self.scratch.items[0]];
        const last = pool.nodes.items[self.scratch.items[self.scratch.items.len - 1]];
        var named: u32 = 0;
        var descendants: u32 = @as(u32, @intCast(self.scratch.items.len));
        for (self.scratch.items) |c| {
            const n = pool.nodes.items[c];
            if (n.named) named += 1;
            descendants += n.descendant_count;
        }
        const info = language.symbolInfo(pst.start_symbol);
        const node = subtree_mod.Subtree{
            .symbol = pst.start_symbol,
            .start_byte = first.start_byte,
            .end_byte = last.end_byte,
            .start_point = first.start_point,
            .end_point = last.end_point,
            .named = if (info) |i| i.metadata.named else true,
            .visible = true,
            .has_error = true,
            .named_child_count = named,
            .descendant_count = descendants,
            .reuse_state = language.table.start_state,
        };
        return try self.pushNode(pool, node, self.scratch.items, true);
    }

    fn lessByPositionFn(pool: *const subtree_mod.SubtreePool, a: u32, b: u32) bool {
        const na = pool.nodes.items[a];
        const nb = pool.nodes.items[b];
        if (na.start_byte != nb.start_byte) return na.start_byte < nb.start_byte;
        return na.end_byte < nb.end_byte;
    }
};

fn lessByPosition(pool: *const subtree_mod.SubtreePool, a: u32, b: u32) bool {
    const na = pool.nodes.items[a];
    const nb = pool.nodes.items[b];
    if (na.start_byte != nb.start_byte) return na.start_byte < nb.start_byte;
    return na.end_byte < nb.end_byte;
}

test "parser: empty input produces program with missing token" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("");
    defer tree.deinit();
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
    try std.testing.expect(tree.hasError());
    var found_missing = false;
    var stack = std.ArrayList(tree_mod.Node).empty;
    defer stack.deinit(std.testing.allocator);
    try stack.append(std.testing.allocator, root);
    while (stack.pop()) |node| {
        if (node.isMissing()) found_missing = true;
        var i = node.childCount();
        while (i > 0) {
            i -= 1;
            try stack.append(std.testing.allocator, node.child(i).?);
        }
    }
    try std.testing.expect(found_missing);
}

test "parser: simple number" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("42");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqual(@as(u32, 0), root.startByte());
    try std.testing.expectEqual(@as(u32, 2), root.endByte());
    try std.testing.expectEqualStrings("42", root.text());
}

test "parser: precedence multiplication over addition" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 + 2 * 3");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    const expr = root.child(0).?;
    try std.testing.expectEqualStrings("expression", expr.nodeType());
    try std.testing.expectEqual(@as(u32, 3), expr.childCount());
    const right = expr.child(2).?;
    try std.testing.expectEqualStrings("term", right.nodeType());
    try std.testing.expectEqual(@as(u32, 3), right.childCount());
}

test "parser: nested parens" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("((1 + 2) * x)");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    try std.testing.expect(tree.rootNode().descendantCount() > 5);
}

test "parser: large input" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(std.testing.allocator);
    for (0..500) |i| {
        if (i > 0) try buf.appendSlice(std.testing.allocator, " + ");
        try buf.appendSlice(std.testing.allocator, "n");
    }
    var tree = try parser.parseString(buf.items);
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    try std.testing.expect(tree.rootNode().descendantCount() > 1000);
}

test "parser: reuse across parses" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var t1 = try parser.parseString("1");
    defer t1.deinit();
    var t2 = try parser.parseString("1 + 2 + 3");
    defer t2.deinit();
    try std.testing.expect(!t2.hasError());
    try std.testing.expectEqualStrings("program", t2.rootNode().nodeType());
}

test "parser: multiple parser instances are independent" {
    var a = Parser.init(std.testing.allocator);
    defer a.deinit();
    var b = Parser.init(std.testing.allocator);
    defer b.deinit();
    try a.setLanguage(language_mod.expression_language);
    try b.setLanguage(language_mod.expression_language);
    var ta = try a.parseString("1");
    defer ta.deinit();
    var tb = try b.parseString("2 + 3");
    defer tb.deinit();
    try std.testing.expectEqualStrings("1", ta.rootNode().text());
    try std.testing.expectEqualStrings("2 + 3", tb.rootNode().text());
}

test "parser: requires language" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    const result = parser.parseString("1");
    try std.testing.expectError(error.NoLanguage, result);
}

test "parser: utf8 identifiers and positions" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("a + b");
    defer tree.deinit();
    const root = tree.rootNode();
    try std.testing.expectEqual(core.Point{ .row = 0, .column = 5 }, root.endPoint());
}

test "recovery: unexpected operator produces error node" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 + * 2");
    defer tree.deinit();
    try std.testing.expect(tree.hasError());
    var found_error = false;
    var stack = std.ArrayList(tree_mod.Node).empty;
    defer stack.deinit(std.testing.allocator);
    try stack.append(std.testing.allocator, tree.rootNode());
    while (stack.pop()) |node| {
        if (node.isError()) found_error = true;
        var i = node.childCount();
        while (i > 0) {
            i -= 1;
            try stack.append(std.testing.allocator, node.child(i).?);
        }
    }
    try std.testing.expect(found_error);
}

test "recovery: invalid character is skipped" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 @ 2");
    defer tree.deinit();
    try std.testing.expect(tree.hasError());
}

test "recovery: trailing operator" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 +");
    defer tree.deinit();
    try std.testing.expect(tree.rootNode().endByte() >= 2);
}

test "recovery: unclosed paren inserts missing node" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("(1 + 2");
    defer tree.deinit();
    var found_missing = false;
    var stack = std.ArrayList(tree_mod.Node).empty;
    defer stack.deinit(std.testing.allocator);
    try stack.append(std.testing.allocator, tree.rootNode());
    while (stack.pop()) |node| {
        if (node.isMissing()) found_missing = true;
        var i = node.childCount();
        while (i > 0) {
            i -= 1;
            try stack.append(std.testing.allocator, node.child(i).?);
        }
    }
    try std.testing.expect(found_missing);
}

test "recovery: empty parens" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("()");
    defer tree.deinit();
    try std.testing.expect(tree.hasError());
}

test "recovery: parser usable after error" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var bad = try parser.parseString("1 + + 2");
    defer bad.deinit();
    try std.testing.expect(bad.hasError());
    var good = try parser.parseString("1 + 2");
    defer good.deinit();
    try std.testing.expect(!good.hasError());
}

test "edit: tree positions shift after insertion" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("1 + 2");
    defer tree.deinit();
    tree_mod.edit_mod.applyEdit(&tree, .{
        .start_byte = 0,
        .old_end_byte = 0,
        .new_end_byte = 4,
        .start_point = .{},
        .old_end_point = .{},
        .new_end_point = .{ .row = 0, .column = 4 },
    });
    try std.testing.expectEqual(@as(u32, 4), tree.rootNode().startByte());
    try std.testing.expectEqual(@as(u32, 9), tree.rootNode().endByte());
}

test "edit: deletion shrinks positions" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("aaa + b");
    defer tree.deinit();
    tree_mod.edit_mod.applyEdit(&tree, .{
        .start_byte = 0,
        .old_end_byte = 2,
        .new_end_byte = 0,
        .start_point = .{},
        .old_end_point = .{ .row = 0, .column = 2 },
        .new_end_point = .{},
    });
    try std.testing.expectEqual(@as(u32, 0), tree.rootNode().startByte());
}

test "edit: incremental parse reuses structure" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var old_tree = try parser.parseString("alpha + beta * gamma");
    defer old_tree.deinit();
    const edit = core.InputEdit{
        .start_byte = 0,
        .old_end_byte = 5,
        .new_end_byte = 5,
        .start_point = .{},
        .old_end_point = .{ .row = 0, .column = 5 },
        .new_end_point = .{ .row = 0, .column = 5 },
    };
    var new_tree = try parser.parse(&old_tree, edit, "ALPHA + beta * gamma");
    defer new_tree.deinit();
    try std.testing.expect(!new_tree.hasError());
    try std.testing.expectEqualStrings("ALPHA + beta * gamma", new_tree.rootNode().text());
}

test "edit: trailing edit reuses old subtrees" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var old_tree = try parser.parseString("alpha + beta * gamma + delta");
    defer old_tree.deinit();
    const edit = core.InputEdit{
        .start_byte = 23,
        .old_end_byte = 28,
        .new_end_byte = 30,
        .start_point = .{ .row = 0, .column = 23 },
        .old_end_point = .{ .row = 0, .column = 28 },
        .new_end_point = .{ .row = 0, .column = 30 },
    };
    var new_tree = try parser.parse(&old_tree, edit, "alpha + beta * gamma + EPSILON");
    defer new_tree.deinit();
    try std.testing.expect(!new_tree.hasError());
    try std.testing.expect(parser.reused_node_count > 0);
    try std.testing.expectEqualStrings("alpha + beta * gamma + EPSILON", new_tree.rootNode().text());
}

test "edit: results equal fresh parse" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var old_tree = try parser.parseString("1 + 2");
    defer old_tree.deinit();
    const edit = core.InputEdit{
        .start_byte = 4,
        .old_end_byte = 5,
        .new_end_byte = 7,
        .start_point = .{ .row = 0, .column = 4 },
        .old_end_point = .{ .row = 0, .column = 5 },
        .new_end_point = .{ .row = 0, .column = 7 },
    };
    var inc = try parser.parse(&old_tree, edit, "1 + 234");
    defer inc.deinit();
    var fresh = try parser.parseString("1 + 234");
    defer fresh.deinit();
    try std.testing.expectEqual(fresh.rootNode().endByte(), inc.rootNode().endByte());
    try std.testing.expectEqual(fresh.rootNode().descendantCount(), inc.rootNode().descendantCount());
    try std.testing.expectEqual(!fresh.hasError(), !inc.hasError());
}

test "changed ranges: insertion reports narrow range" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var old_tree = try parser.parseString("1 + 2");
    defer old_tree.deinit();
    const edit = core.InputEdit{
        .start_byte = 5,
        .old_end_byte = 5,
        .new_end_byte = 8,
        .start_point = .{ .row = 0, .column = 5 },
        .old_end_point = .{ .row = 0, .column = 5 },
        .new_end_point = .{ .row = 0, .column = 8 },
    };
    var new_tree = try parser.parse(&old_tree, edit, "1 + 200");
    defer new_tree.deinit();
    const ranges = try tree_mod.changed_ranges_mod.changedRanges(std.testing.allocator, &old_tree, &new_tree);
    defer tree_mod.changed_ranges_mod.freeRanges(std.testing.allocator, ranges);
    try std.testing.expect(ranges.len > 0);
    try std.testing.expect(ranges.len < 5);
    for (ranges) |r| {
        try std.testing.expect(r.start_byte <= 8);
    }
}

test "changed ranges: identical trees report nothing" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var t1 = try parser.parseString("1 + 2");
    defer t1.deinit();
    var t2 = try parser.parseString("1 + 2");
    defer t2.deinit();
    const ranges = try tree_mod.changed_ranges_mod.changedRanges(std.testing.allocator, &t1, &t2);
    defer tree_mod.changed_ranges_mod.freeRanges(std.testing.allocator, ranges);
    try std.testing.expectEqual(@as(usize, 0), ranges.len);
}

test "changed ranges: deletion" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var old_tree = try parser.parseString("1 + 22 + 333");
    defer old_tree.deinit();
    const edit = core.InputEdit{
        .start_byte = 3,
        .old_end_byte = 9,
        .new_end_byte = 3,
        .start_point = .{ .row = 0, .column = 3 },
        .old_end_point = .{ .row = 0, .column = 9 },
        .new_end_point = .{ .row = 0, .column = 3 },
    };
    var new_tree = try parser.parse(&old_tree, edit, "1 +33");
    defer new_tree.deinit();
    try std.testing.expect(!new_tree.hasError());
    const ranges = try tree_mod.changed_ranges_mod.changedRanges(std.testing.allocator, &old_tree, &new_tree);
    defer tree_mod.changed_ranges_mod.freeRanges(std.testing.allocator, ranges);
    try std.testing.expect(ranges.len > 0);
}

test "changed ranges: unicode replacement" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var old_tree = try parser.parseString("a +\nb");
    defer old_tree.deinit();
    const edit = core.InputEdit{
        .start_byte = 0,
        .old_end_byte = 1,
        .new_end_byte = 1,
        .start_point = .{},
        .old_end_point = .{ .row = 0, .column = 1 },
        .new_end_point = .{ .row = 0, .column = 1 },
    };
    var new_tree = try parser.parse(&old_tree, edit, "z +\nb");
    defer new_tree.deinit();
    try std.testing.expect(!new_tree.hasError());
    try std.testing.expectEqualStrings("z", new_tree.rootNode().child(0).?.namedChild(0).?.text());
}

test "integration: full pipeline" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);

    var tree = try parser.parseString("sum + 40 * (2 - x)");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());

    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());

    var query = try query_mod.Query.compile(
        std.testing.allocator,
        language_mod.expression_language,
        "(identifier) @var",
    );
    defer query.deinit();

    var cursor = query_cursor_mod.QueryCursor.init(std.testing.allocator);
    defer cursor.deinit();
    try cursor.execute(language_mod.expression_language, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 2), cursor.matchCount());

    const edit = core.InputEdit{
        .start_byte = 0,
        .old_end_byte = 3,
        .new_end_byte = 5,
        .start_point = .{},
        .old_end_point = .{ .row = 0, .column = 3 },
        .new_end_point = .{ .row = 0, .column = 5 },
    };
    var tree2 = try parser.parse(&tree, edit, "total + 40 * (2 - x)");
    defer tree2.deinit();
    try std.testing.expect(!tree2.hasError());

    const ranges = try tree_mod.changed_ranges_mod.changedRanges(std.testing.allocator, &tree, &tree2);
    defer tree_mod.changed_ranges_mod.freeRanges(std.testing.allocator, ranges);
    try std.testing.expect(ranges.len >= 1);
}

test "integration: simplified allocator API" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);

    var tree = try parser.parseString("x + 42");
    defer tree.deinit();

    var cursor = tree.cursor();
    defer cursor.deinit();
    try std.testing.expect(cursor.gotoFirstChild());

    var query = try parser.compileQuery("(identifier) @id");
    defer query.deinit();

    var qcursor = parser.queryCursor();
    defer qcursor.deinit();
    try qcursor.execute(language_mod.expression_language, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 1), qcursor.matchCount());

    var tree2 = try parser.parseString("x + 43");
    defer tree2.deinit();
    const ranges = try tree.getChangedRanges(&tree2);
    defer tree.freeChangedRanges(ranges);
}

test "integration: custom input callback" {
    const State = struct {
        bytes: []const u8,
        fn read(payload: ?*anyopaque, byte_index: u32, position: core.Point, bytes_read: *u32) ?[*]const u8 {
            _ = position;
            const self: *@This() = @ptrCast(@alignCast(payload.?));
            const i: usize = @as(usize, @intCast(byte_index));
            if (i >= self.bytes.len) {
                bytes_read.* = 0;
                return null;
            }
            bytes_read.* = @as(u32, @intCast(self.bytes.len - i));
            return self.bytes.ptr + i;
        }
    };
    var state = State{ .bytes = "7 * 8" };
    const input = input_mod.Input{ .payload = &state, .read = State.read };
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseWithInput(null, null, input);
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    try std.testing.expectEqualStrings("7 * 8", tree.rootNode().text());
}

test "integration: utf16 input is transcoded" {
    const State = struct {
        bytes: []const u8,
        fn read(payload: ?*anyopaque, byte_index: u32, position: core.Point, bytes_read: *u32) ?[*]const u8 {
            _ = position;
            const self: *@This() = @ptrCast(@alignCast(payload.?));
            const i: usize = @as(usize, @intCast(byte_index));
            if (i >= self.bytes.len) {
                bytes_read.* = 0;
                return null;
            }
            bytes_read.* = @as(u32, @intCast(self.bytes.len - i));
            return self.bytes.ptr + i;
        }
    };
    // "1 + 2" in UTF-16LE with BOM.
    const utf16 = [_]u8{ 0xFF, 0xFE, '1', 0, ' ', 0, '+', 0, ' ', 0, '2', 0 };
    var state = State{ .bytes = &utf16 };
    const input = input_mod.Input{ .payload = &state, .read = State.read, .encoding = .utf16_le };
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseWithInput(null, null, input);
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    try std.testing.expectEqualStrings("1 + 2", tree.rootNode().text());

    // Conflicting BOM fails loudly.
    const bad = [_]u8{ 0xFE, 0xFF, 0, '1' };
    var bad_state = State{ .bytes = &bad };
    const bad_input = input_mod.Input{ .payload = &bad_state, .read = State.read, .encoding = .utf16_le };
    try std.testing.expectError(error.UnexpectedBOM, parser.parseWithInput(null, null, bad_input));
}

test "ownership: tree owns source and pool" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("10 + 20");
    const text_before = tree.rootNode().text();
    try std.testing.expectEqualStrings("10 + 20", text_before);
    var dup = try tree.copy();
    defer dup.deinit();
    tree.deinit();
    try std.testing.expectEqualStrings("10 + 20", dup.rootNode().text());
}

test "ownership: parser owns scratch across parses" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var t1 = try parser.parseString("1");
    defer t1.deinit();
    parser.reset();
    var t2 = try parser.parseString("2 + 3");
    defer t2.deinit();
    try std.testing.expectEqualStrings("2 + 3", t2.rootNode().text());
}

test "incremental: growth reparse matches fresh parse structurally" {
    const sexp_mod = @import("../tree/sexp.zig");
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var old_tree = try parser.parseString("1 + 2");
    defer old_tree.deinit();
    const edit = core.InputEdit{
        .start_byte = 5,
        .old_end_byte = 5,
        .new_end_byte = 6,
        .start_point = .{ .row = 0, .column = 5 },
        .old_end_point = .{ .row = 0, .column = 5 },
        .new_end_point = .{ .row = 0, .column = 6 },
    };
    var inc = try parser.parse(&old_tree, edit, "1 + 22");
    defer inc.deinit();
    try std.testing.expect(parser.reused_node_count > 0);
    var fresh = try parser.parseString("1 + 22");
    defer fresh.deinit();
    const a = try sexp_mod.toSexp(std.testing.allocator, inc.rootNode());
    defer std.testing.allocator.free(a);
    const b = try sexp_mod.toSexp(std.testing.allocator, fresh.rootNode());
    defer std.testing.allocator.free(b);
    try std.testing.expectEqualStrings(b, a);
}

test "ranges: single range restricts parsing" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    try parser.setIncludedRanges(&.{.{
        .start_byte = 0,
        .end_byte = 5,
        .start_point = .{},
        .end_point = .{ .row = 0, .column = 5 },
    }});
    try std.testing.expectEqual(@as(usize, 1), parser.includedRanges().len);
    var tree = try parser.parseString("1 + 2 + 3");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    try std.testing.expectEqual(@as(u32, 0), tree.rootNode().startByte());
    try std.testing.expectEqual(@as(u32, 5), tree.rootNode().endByte());
    try std.testing.expectEqualStrings("1 + 2", tree.rootNode().text());
}

test "ranges: invalid ranges are rejected" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    // Overlapping.
    try std.testing.expectError(error.InvalidRange, parser.setIncludedRanges(&.{
        .{ .start_byte = 0, .end_byte = 5 },
        .{ .start_byte = 4, .end_byte = 9 },
    }));
    // Unsorted.
    try std.testing.expectError(error.InvalidRange, parser.setIncludedRanges(&.{
        .{ .start_byte = 6, .end_byte = 9 },
        .{ .start_byte = 0, .end_byte = 3 },
    }));
    // Empty end before start.
    try std.testing.expectError(error.InvalidRange, parser.setIncludedRanges(&.{
        .{ .start_byte = 9, .end_byte = 3 },
    }));
    // Empty slice clears the restriction.
    try parser.setIncludedRanges(&.{});
    try std.testing.expectEqual(@as(usize, 0), parser.includedRanges().len);
    var tree = try parser.parseString("1 + 2");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
}

test "stream: parseStream matches buffered parse" {
    const State = struct {
        bytes: []const u8,
        fn read(payload: ?*anyopaque, byte_index: u32, position: core.Point, bytes_read: *u32) ?[*]const u8 {
            _ = position;
            const self: *@This() = @ptrCast(@alignCast(payload.?));
            const i: usize = @as(usize, @intCast(byte_index));
            if (i >= self.bytes.len) {
                bytes_read.* = 0;
                return null;
            }
            // One byte per chunk: the parser must pull repeatedly.
            bytes_read.* = 1;
            return self.bytes.ptr + i;
        }
    };
    var state = State{ .bytes = "1 + 2 * 3" };
    const input = input_mod.Input{ .payload = &state, .read = State.read };
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseStream(null, null, input);
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    try std.testing.expectEqualStrings("1 + 2 * 3", tree.rootNode().text());
    try std.testing.expectEqualStrings("1 + 2 * 3", tree.sourceText());
    var fresh = try parser.parseString("1 + 2 * 3");
    defer fresh.deinit();
    try std.testing.expectEqual(fresh.rootNode().descendantCount(), tree.rootNode().descendantCount());
}

test "stream: parseStream with old tree buffers for reuse" {
    const State = struct {
        bytes: []const u8,
        fn read(payload: ?*anyopaque, byte_index: u32, position: core.Point, bytes_read: *u32) ?[*]const u8 {
            _ = position;
            const self: *@This() = @ptrCast(@alignCast(payload.?));
            const i: usize = @as(usize, @intCast(byte_index));
            if (i >= self.bytes.len) {
                bytes_read.* = 0;
                return null;
            }
            bytes_read.* = @as(u32, @intCast(self.bytes.len - i));
            return self.bytes.ptr + i;
        }
    };
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var old_tree = try parser.parseString("1 + 2");
    defer old_tree.deinit();
    const edit = core.InputEdit{
        .start_byte = 5,
        .old_end_byte = 5,
        .new_end_byte = 6,
        .start_point = .{ .row = 0, .column = 5 },
        .old_end_point = .{ .row = 0, .column = 5 },
        .new_end_point = .{ .row = 0, .column = 6 },
    };
    var state = State{ .bytes = "1 + 22" };
    var inc = try parser.parseStream(&old_tree, edit, .{ .payload = &state, .read = State.read });
    defer inc.deinit();
    try std.testing.expect(!inc.hasError());
    try std.testing.expectEqualStrings("1 + 22", inc.rootNode().text());
}

test "sexp: nested lists parse and alias applies" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.sexp_language);
    var tree = try parser.parseString("(add 1 (mul 2 3))");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
    const items = root.child(0).?;
    try std.testing.expectEqualStrings("items", items.nodeType());
    const expr = items.child(0).?;
    try std.testing.expectEqualStrings("expression", expr.nodeType());
    try std.testing.expectEqual(@as(u32, 3), expr.childCount());
    // The middle child of `( items )` is aliased to `sequence`.
    const seq = expr.child(1).?;
    try std.testing.expectEqualStrings("sequence", seq.nodeType());
    try std.testing.expect(seq.isNamed());
}

test "sexp: empty list and bare atoms" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.sexp_language);
    var empty = try parser.parseString("()");
    defer empty.deinit();
    try std.testing.expect(!empty.hasError());
    try std.testing.expectEqualStrings("program", empty.rootNode().nodeType());
    var atoms = try parser.parseString("foo 42");
    defer atoms.deinit();
    try std.testing.expect(!atoms.hasError());
    var query = try query_mod.Query.compile(std.testing.allocator, language_mod.sexp_language, "(identifier) @id");
    defer query.deinit();
    var qc = query_cursor_mod.QueryCursor.init(std.testing.allocator);
    defer qc.deinit();
    try qc.execute(language_mod.sexp_language, query.patterns(), query.nodes(), query.captureNames(), &atoms);
    try std.testing.expectEqual(@as(usize, 1), qc.matchCount());
}

test "json: objects, arrays, and literals" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.json_language);
    var tree = try parser.parseString("{\"a\": 1, \"b\": [true, null]}");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
    const pair = root.child(0).?.child(0).?.child(1).?.child(0).?.child(0).?;
    try std.testing.expectEqualStrings("pair", pair.nodeType());
    try std.testing.expectEqualStrings("\"a\"", pair.childByFieldName("key").?.text());
    try std.testing.expectEqualStrings("1", pair.childByFieldName("value").?.text());
}

test "json: empty containers and nesting" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.json_language);
    var empty = try parser.parseString("[{}, []]");
    defer empty.deinit();
    try std.testing.expect(!empty.hasError());
    var nested = try parser.parseString("{\"o\": {\"x\": [1, 2.5]}, \"s\": \"a\\nb\"}");
    defer nested.deinit();
    try std.testing.expect(!nested.hasError());
    var query = try query_mod.Query.compile(std.testing.allocator, language_mod.json_language, "(string) @s");
    defer query.deinit();
    var qc = query_cursor_mod.QueryCursor.init(std.testing.allocator);
    defer qc.deinit();
    try qc.execute(language_mod.json_language, query.patterns(), query.nodes(), query.captureNames(), &nested);
    try std.testing.expect(qc.matchCount() >= 3);
}

test "json: malformed input produces errors" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.json_language);
    var bad = try parser.parseString("{\"a\": 1,}");
    defer bad.deinit();
    try std.testing.expect(bad.hasError());
    var bad_num = try parser.parseString("[01]");
    defer bad_num.deinit();
    try std.testing.expect(bad_num.hasError());
}

//
// Scanner payloads are caller-owned: copy the language, point it at a
// live ScanState, and set the copy.

test "outline: headers and items parse" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    var lang = language_mod.outline_language;
    var scan_state = language_mod.outline_scanner.ScanState.init(std.testing.allocator);
    defer scan_state.deinit();
    lang.external_scanner.?.payload = &scan_state;
    try parser.setLanguage(lang);
    var tree = try parser.parseString("# Title\n- one\n- two\n");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    const root = tree.rootNode();
    try std.testing.expectEqualStrings("program", root.nodeType());
    const header = root.child(0).?.child(0).?.child(0).?;
    try std.testing.expectEqualStrings("header", header.nodeType());
    try std.testing.expectEqualStrings("# Title", header.text());
}

test "outline: nested sub-headers indent" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    var lang = language_mod.outline_language;
    var scan_state = language_mod.outline_scanner.ScanState.init(std.testing.allocator);
    defer scan_state.deinit();
    lang.external_scanner.?.payload = &scan_state;
    try parser.setLanguage(lang);
    var tree = try parser.parseString("# Title\n  # Sub\n  - deep\n- two\n");
    defer tree.deinit();
    try std.testing.expect(!tree.hasError());
    var query = try query_mod.Query.compile(std.testing.allocator, lang, "(header) @h");
    defer query.deinit();
    var qc = query_cursor_mod.QueryCursor.init(std.testing.allocator);
    defer qc.deinit();
    try qc.execute(lang, query.patterns(), query.nodes(), query.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 2), qc.matchCount());
}

test "outline: orphan items are errors" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    var lang = language_mod.outline_language;
    var scan_state = language_mod.outline_scanner.ScanState.init(std.testing.allocator);
    defer scan_state.deinit();
    lang.external_scanner.?.payload = &scan_state;
    try parser.setLanguage(lang);
    var tree = try parser.parseString("- orphan\n");
    defer tree.deinit();
    try std.testing.expect(tree.hasError());
}

test "outline: incremental reparse matches fresh" {
    const sexp_mod = @import("../tree/sexp.zig");
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    var lang = language_mod.outline_language;
    var scan_state = language_mod.outline_scanner.ScanState.init(std.testing.allocator);
    defer scan_state.deinit();
    lang.external_scanner.?.payload = &scan_state;
    try parser.setLanguage(lang);
    var old_tree = try parser.parseString("# T\n- a\n");
    defer old_tree.deinit();
    try std.testing.expect(!old_tree.hasError());
    const edit = core.InputEdit{
        .start_byte = 7,
        .old_end_byte = 7,
        .new_end_byte = 8,
        .start_point = .{ .row = 1, .column = 3 },
        .old_end_point = .{ .row = 1, .column = 3 },
        .new_end_point = .{ .row = 1, .column = 4 },
    };
    var inc = try parser.parse(&old_tree, edit, "# T\n- ab\n");
    defer inc.deinit();
    var fresh = try parser.parseString("# T\n- ab\n");
    defer fresh.deinit();
    const a = try sexp_mod.toSexp(std.testing.allocator, inc.rootNode());
    defer std.testing.allocator.free(a);
    const b = try sexp_mod.toSexp(std.testing.allocator, fresh.rootNode());
    defer std.testing.allocator.free(b);
    try std.testing.expectEqualStrings(b, a);
}

test "predicates: any-of and is filter matches" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tree = try parser.parseString("foo + bar");
    defer tree.deinit();
    const lang = language_mod.expression_language;

    var q_any = try query_mod.Query.compile(std.testing.allocator, lang, "((identifier) @x (#any-of? @x \"foo\"))");
    defer q_any.deinit();
    var c_any = query_cursor_mod.QueryCursor.init(std.testing.allocator);
    defer c_any.deinit();
    try c_any.execute(lang, q_any.patterns(), q_any.nodes(), q_any.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 1), c_any.matchCount());

    var q_not_any = try query_mod.Query.compile(std.testing.allocator, lang, "((identifier) @x (#not-any-of? @x \"foo\"))");
    defer q_not_any.deinit();
    var c_not_any = query_cursor_mod.QueryCursor.init(std.testing.allocator);
    defer c_not_any.deinit();
    try c_not_any.execute(lang, q_not_any.patterns(), q_not_any.nodes(), q_not_any.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 1), c_not_any.matchCount());

    var q_is = try query_mod.Query.compile(std.testing.allocator, lang, "((identifier) @x (#is? @x named))");
    defer q_is.deinit();
    var c_is = query_cursor_mod.QueryCursor.init(std.testing.allocator);
    defer c_is.deinit();
    try c_is.execute(lang, q_is.patterns(), q_is.nodes(), q_is.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 2), c_is.matchCount());

    var q_is_not = try query_mod.Query.compile(std.testing.allocator, lang, "((identifier) @x (#is-not? @x anonymous))");
    defer q_is_not.deinit();
    var c_is_not = query_cursor_mod.QueryCursor.init(std.testing.allocator);
    defer c_is_not.deinit();
    try c_is_not.execute(lang, q_is_not.patterns(), q_is_not.nodes(), q_is_not.captureNames(), &tree);
    try std.testing.expectEqual(@as(usize, 2), c_is_not.matchCount());
}

test "conformance: corpus cases pass" {
    const conformance_mod = @import("../debug/conformance.zig");
    for (conformance_mod.corpus_files) |text| {
        var case = try conformance_mod.parseCase(std.testing.allocator, text);
        defer case.deinit();
        conformance_mod.runCase(std.testing.allocator, &case) catch |err| {
            std.debug.print("conformance case [{s}] {s} failed: {s}\n", .{ case.grammar, case.name, @errorName(err) });
            return err;
        };
    }
}

test "logging: tracer records parse lifecycle" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    parser.setLogger(.{ .level = .debug, .prefix = "test" });
    var tracer = debug_mod.Tracer.init(std.testing.allocator, .{ .level = .off });
    defer tracer.deinit();
    parser.setTracer(&tracer);
    var tree = try parser.parseString("1 + 2");
    defer tree.deinit();
    try std.testing.expect(tracer.count() > 0);
    var saw_begin = false;
    var saw_accept = false;
    for (tracer.entries.items) |entry| {
        if (entry.event == .parse_begin) saw_begin = true;
        if (entry.event == .accept) saw_accept = true;
    }
    try std.testing.expect(saw_begin and saw_accept);
    parser.setTracer(null);
    parser.setLogger(.{});
}

test "logging: tracer records incremental reuse" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();
    try parser.setLanguage(language_mod.expression_language);
    var tracer = debug_mod.Tracer.init(std.testing.allocator, .{ .level = .off });
    defer tracer.deinit();
    parser.setTracer(&tracer);
    var old_tree = try parser.parseString("alpha + beta * gamma + delta");
    defer old_tree.deinit();
    const edit = core.InputEdit{
        .start_byte = 23,
        .old_end_byte = 28,
        .new_end_byte = 30,
        .start_point = .{ .row = 0, .column = 23 },
        .old_end_point = .{ .row = 0, .column = 28 },
        .new_end_point = .{ .row = 0, .column = 30 },
    };
    const before = tracer.count();
    var new_tree = try parser.parse(&old_tree, edit, "alpha + beta * gamma + EPSILON");
    defer new_tree.deinit();
    try std.testing.expect(tracer.count() > before);
    var saw_reuse = false;
    for (tracer.entries.items[before..]) |entry| {
        if (entry.event == .reuse_node) saw_reuse = true;
    }
    try std.testing.expect(saw_reuse);
}
