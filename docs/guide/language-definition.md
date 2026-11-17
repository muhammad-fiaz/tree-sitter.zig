---
description: Define languages for tree-sitter.zig - symbols, token matchers, LR tables, fields, and metadata.
---

# Language Definition

## What you'll learn

- What a `Language` value contains and how the runtime consumes it.
- How to inspect symbols, tables, and fields.

## A Language is data

The runtime never hard-codes syntax. A `Language` bundles:

| Part | Role |
|------|------|
| `symbols` | Id, name, kind (terminal / non-terminal / external / end), and visibility/named/extra flags |
| `token_matchers` | Zig functions mapping `(source, offset)` to a token length (longest match wins) |
| `extra_symbols` | Whitespace/comments skipped between tokens |
| `table` | LR states: per-state action lists (shift / reduce / accept) plus goto entries |
| `fields` | Field names plus per-production child bindings |
| `aliases` / `supertype_map` | Sparse per-production renames (applied on reduce) and supertype→subtype lists (expanded in queries) |
| `metadata` | Name, ABI version (13-15 accepted), symbol/state/field counts |
| `external_scanner` | Optional Zig scanner for context-sensitive tokens |

`examples/language.zig` prints all of this for the bundled expression grammar:

```text
language: expression abi=15 symbols=15 states=18
  #0 end named=false visible=false
  #1 identifier named=true visible=true
  ...
symbol for "+": 3
field id for "left": 1 (left)
```

## How it works

- The tokenizer tries every non-extra matcher at each offset and takes the longest match; extras are skipped first.
- The parser looks up `(state, symbol)` actions and `(state, non-terminal)` gotos - the same table-driven loop for every language.
- `setLanguage` rejects incompatible ABI versions with `error.IncompatibleAbiVersion` instead of mis-parsing.

The bundled `expression` grammar (identifiers, numbers, `+ - * /`, parentheses, left-associative precedence) exists so tests, examples, and benchmarks run without external grammars. Use it as `treesitter.expression_language` (the old `test_grammar.test_language` path still works as a compatibility shim). A second bundled grammar, `treesitter.sexp_language`, parses nested parenthesized lists (`(add 1 (mul 2 3))`) and demonstrates alias substitution: the grouped-list production renames its middle child to `sequence`, so `(sequence) @list` queries match grouped lists. A third bundled grammar, `treesitter.json_language`, covers real-world JSON - objects, arrays, strict strings/numbers, literals - with `key`/`value` fields on pairs (27 states; see `examples/json_parse.zig`). A fourth, `treesitter.outline_language`, is the indentation-sensitive external-scanner demo (see [External Scanners](/guide/external-scanners)). Production languages provide equivalent tables for their own grammars.

## Native Grammar Authoring and Parser Generation

`tree-sitter.zig` includes a complete native Zig grammar compiler and parser generator. You can define grammars programmatically in native Zig:

```zig
var g = try treesitter.Grammar.init(allocator, "calc");
defer g.deinit(allocator);

// Define rules using the fluent Rule builder
try g.addRule(allocator, "expression", Rule.choice(&[_]Rule{
    Rule.sym("number"),
    Rule.seq(&[_]Rule{ Rule.sym("expression"), Rule.str("+"), Rule.sym("expression") }),
}));
```

### Compiling and Generating Parsers

1. **Compile grammar**: `var compiler = treesitter.GrammarCompiler.init(allocator); try compiler.compile(&g);`
2. **Generate native Zig parser tables and code**: `var gen = treesitter.Generator.init(allocator, &g); const zig_code = try gen.generate();`

### Loading Upstream Tree-sitter Grammars (grammar.json)

`tree-sitter.zig` includes `DSLParser` to parse real upstream Tree-sitter `grammar.json` definitions directly into native `Grammar` ASTs:

```zig
var parser = treesitter.DSLParser.init(allocator);

// Load grammar from an in-memory JSON slice:
var grammar = try parser.parseJSON(json_text);
defer grammar.deinit(allocator);

// Or load grammar directly from a file:
var json_grammar = try parser.parseFile(io, "grammar.json");
defer json_grammar.deinit(allocator);
```

### Standalone Grammar Packages (grammars/)

> [!IMPORTANT]
> **No C Compatibility**:
> `tree-sitter.zig` does not require or maintain compatibility with the original C Tree-sitter library or C compilers. All grammar packages use their own pure native Zig configurations, parse tables, and scanners.

Grammars are organized as standalone, modular native Zig packages under [`grammars/`](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars) (including [C](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/c), [C++](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/cpp), [Python](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/python), [JavaScript](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/javascript), [TypeScript](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/typescript), [Rust](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/rust), [Go](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/go), [HTML](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/html), [CSS](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/css), [JSON](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/json), [Java](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/java), [Ruby](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/ruby), [PHP](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/php), [Zig](https://github.com/muhammad-fiaz/tree-sitter.zig/tree/main/grammars/zig)). Each package provides:
- A standalone `build.zig`
- A native Zig parser and `Language` definition in `src/parser.zig`
- A native Zig external scanner in `src/scanner.zig`
- Upstream grammar specification in `src/grammar.json`
- Node types metadata in `src/node-types.json`
- Syntax queries in `queries/*.scm`
- An example executable in `examples/main.zig`

Run all grammar examples sequentially with:
```bash
zig build run-all-grammars
```

Run the grammar generator demonstration with:
```bash
zig build run-grammar_dsl
```

## API used

- [Language](/api/language), [Symbols](/api/symbols), [Fields](/api/fields), [Parser](/api/parser) - `setLanguage`.

## Related guides

- [External Scanners](/guide/external-scanners), [Languages example](/examples/languages)
- [Grammar & Language](/concepts/grammar-language), [Language Tables](/concepts/language-tables)
