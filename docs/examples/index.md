---
description: Runnable examples for tree-sitter.zig - every example maps to a real file in examples/.
---

# Examples

Every example below is a real program in the repository's `examples/` directory. Build them all with `zig build examples`, run one with `zig build run-<name>` (e.g. `zig build run-basic_parse`), or run the whole set with `zig build run-all-examples`.

<ExampleCard title="Basics" description="Parse source, print trees, inspect nodes, and handle errors." link="/examples/basics" level="Beginner" />
<ExampleCard title="Trees" description="Walk trees recursively and with cursors." link="/examples/trees" level="Beginner" />
<ExampleCard title="Incremental" description="Edits, reuse, and changed ranges." link="/examples/incremental" level="Intermediate" />
<ExampleCard title="Input" description="Memory, callbacks, and reader-backed sources." link="/examples/input" level="Intermediate" />
<ExampleCard title="Languages" description="Inspect symbols, tables, and fields." link="/examples/languages" level="Intermediate" />
<ExampleCard title="Queries" description="Captures, predicates, and structural search." link="/examples/queries" level="Intermediate" />
<ExampleCard title="Unicode" description="UTF-8 offsets, points, and positions." link="/examples/unicode" level="Intermediate" />
<ExampleCard title="Debugging" description="Logging, tracing, and error inspection." link="/examples/debugging" level="Advanced" />
<ExampleCard title="Applications" description="Highlighting, navigation, and analysis patterns." link="/examples/applications" level="Advanced" />
<ExampleCard title="Concurrency & I/O" description="Multi-threading, thread isolation, shared immutable trees, and std.Io contexts." link="/examples/concurrency" level="Advanced" />

## Complete Examples Directory (25 Flat Examples)

| Example File | Run Step | Description |
|---|---|---|
| `examples/basic_parse.zig` | `zig build run-basic_parse` | Basic string parsing and node inspection |
| `examples/custom_input.zig` | `zig build run-custom_input` | Callback-driven custom input streams |
| `examples/custom_io.zig` | `zig build run-custom_io` | std.Io context configuration and timeouts |
| `examples/editor_workflow.zig` | `zig build run-editor_workflow` | Real-time buffer editing and dirty range tracking |
| `examples/error_recovery.zig` | `zig build run-error_recovery` | Syntax error recovery with ERROR and MISSING nodes |
| `examples/external_scanner.zig` | `zig build run-external_scanner` | Native external scanner implementation |
| `examples/grammar_dsl.zig` | `zig build run-grammar_dsl` | Native Zig grammar DSL, compilation, and generator |
| `examples/highlight.zig` | `zig build run-highlight` | Syntax highlighting via AST leaf classification |
| `examples/incremental_parse.zig` | `zig build run-incremental_parse` | Keystroke edit and syntax subtree reuse |
| `examples/json_parse.zig` | `zig build run-json_parse` | Native JSON grammar parser execution |
| `examples/language.zig` | `zig build run-language` | Language metadata, symbol tables, and fields |
| `examples/language_injections.zig` | `zig build run-language_injections` | Multi-language embedded island parsing |
| `examples/language_registry.zig` | `zig build run-language_registry` | Dynamic language registration and file extension lookup |
| `examples/large_file_parse.zig` | `zig build run-large_file_parse` | High-throughput parsing of 100,000+ node files |
| `examples/locals_analysis.zig` | `zig build run-locals_analysis` | Lexical scope, variable definitions, and references |
| `examples/logging.zig` | `zig build run-logging` | Tracer and debug parser event logging |
| `examples/multithreading.zig` | `zig build run-multithreading` | Concurrent parsing and thread-safe immutable queries |
| `examples/query.zig` | `zig build run-query` | Pattern captures and structural queries |
| `examples/query_directives.zig` | `zig build run-query_directives` | Query predicates (#eq?, #match?) and directives |
| `examples/sexp_parse.zig` | `zig build run-sexp_parse` | S-expression tree formatting and inspection |
| `examples/tags_extraction.zig` | `zig build run-tags_extraction` | Code symbol and tag extraction for ctags/IDE |
| `examples/tree_cursor.zig` | `zig build run-tree_cursor` | Allocation-free cursor tree navigation |
| `examples/tree_walk.zig` | `zig build run-tree_walk` | Recursive AST traversal and depth tracking |
| `examples/unicode.zig` | `zig build run-unicode` | Multilingual UTF-8 code point and byte position indexing |
| `examples/utf16_parse.zig` | `zig build run-utf16_parse` | Direct UTF-16 code unit parsing |

