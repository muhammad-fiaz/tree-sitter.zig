---
description: API reference overview for tree-sitter.zig 0.0.1.
---

# API Reference

Every signature below is taken from the actual source (`src/`). Import everything through one module:

```zig
const treesitter = @import("treesitter");
```

<ApiCard name="Parser" description="Create parsers, load languages, parse source incrementally." link="/api/parser" signature="Parser.init(allocator) Parser" />
<ApiCard name="Tree" description="Own the syntax tree, its text, and its node pool." link="/api/tree" signature="Parser.parseString(source) Tree" />
<ApiCard name="Node" description="Lightweight, allocation-free handles into a tree." link="/api/node" signature="Tree.rootNode() Node" />
<ApiCard name="TreeCursor" description="Stateful traversal with depth and field tracking." link="/api/tree-cursor" signature="Tree.cursor() TreeCursor" />
<ApiCard name="Language" description="Generic grammar data: symbols, tables, fields, metadata." link="/api/language" signature="Parser.setLanguage(Language)" />
<ApiCard name="Query" description="Compiled structural patterns with captures and predicates." link="/api/query" signature="Parser.compileQuery(source) Query" />
<ApiCard name="QueryCursor" description="Execute queries and iterate matches." link="/api/query-cursor" signature="Parser.queryCursor() QueryCursor" />
<ApiCard name="Input" description="Memory, callback, and reader-backed sources." link="/api/input" signature="Parser.parseWithInput(old, edit, input)" />
