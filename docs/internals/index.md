---
description: Internals overview — how each runtime subsystem is implemented.
---

# Internals

For contributors and advanced users. Each page explains the actual source behind a subsystem:

- [Parser Runtime](/internals/parser-runtime)
- [Lexer Runtime](/internals/lexer-runtime)
- [Stack Runtime](/internals/stack-runtime)
- [Subtree Runtime](/internals/subtree-runtime)
- [Tree Runtime](/internals/tree-runtime)
- [Query Runtime](/internals/query-runtime)
- [Incremental Runtime](/internals/incremental-runtime)
- [Memory Runtime](/internals/memory-runtime)
- [Upstream Conformance](/internals/upstream-conformance)

```text
Parser
 ├── Lexer
 ├── Parser Stack
 ├── Parse Actions
 ├── Reductions
 ├── Error Recovery
 └── Subtree Construction

Tree
 ├── Subtree
 ├── Node
 └── Cursor

Query
 ├── Query Parser
 ├── Patterns
 ├── Captures
 ├── Predicates
 ├── Matcher
 └── Query Cursor
```
