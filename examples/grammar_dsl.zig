const std = @import("std");
const treesitter = @import("treesitter");

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    std.debug.print("1. Defining grammar in native Zig...\n", .{});
    var g = try treesitter.Grammar.init(gpa, "calc_demo");
    defer g.deinit(gpa);

    // Whitespace extra rule
    try g.addExtra(gpa, treesitter.Rule.pattern("\\s"));

    // Rules:
    // expression := binary_expr | primary_expr
    // binary_expr := expression ('+' | '-') expression
    // primary_expr := identifier | number
    try g.addRule(gpa, "expression", treesitter.Rule.choice(&.{
        treesitter.Rule.sym("binary_expr"),
        treesitter.Rule.sym("primary_expr"),
    }));

    try g.addRule(gpa, "binary_expr", treesitter.Rule.choice(&.{
        treesitter.Rule.seq(&.{ treesitter.Rule.sym("expression"), treesitter.Rule.str("+"), treesitter.Rule.sym("expression") }),
        treesitter.Rule.seq(&.{ treesitter.Rule.sym("expression"), treesitter.Rule.str("-"), treesitter.Rule.sym("expression") }),
    }));

    try g.addRule(gpa, "primary_expr", treesitter.Rule.choice(&.{
        treesitter.Rule.sym("number"),
        treesitter.Rule.sym("identifier"),
    }));

    try g.addRule(gpa, "number", treesitter.Rule.pattern("\\d+"));
    try g.addRule(gpa, "identifier", treesitter.Rule.pattern("[a-zA-Z_]\\w*"));

    std.debug.print("2. Compiling and validating grammar...\n", .{});
    var compiler = treesitter.GrammarCompiler.init(gpa, &g);
    defer compiler.deinit();
    try compiler.validate();

    var sets = try compiler.computeFirstFollow();
    defer sets.deinit();
    std.debug.print("   Expression first set size: {d}\n", .{sets.first.get("expression").?.count()});

    std.debug.print("3. Generating parser tables...\n", .{});
    var gen = treesitter.Generator.init(gpa, &g);
    defer gen.deinit();

    var data = try gen.generate();
    defer data.deinit();

    std.debug.print("   Generated {d} symbols, {d} states\n", .{ data.symbol_count, data.state_count });

    std.debug.print("4. Emitting native Zig source code...\n", .{});
    const zig_source = try data.emitZigSource(gpa);
    defer gpa.free(zig_source);

    std.debug.print("   Emitted {d} bytes of Zig source code\n", .{zig_source.len});
    std.debug.print("Grammar DSL and generator completed successfully!\n", .{});
}
