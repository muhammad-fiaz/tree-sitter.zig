---
description: General FAQ — what tree-sitter.zig is and what it depends on.
---

# General FAQ

## What is tree-sitter.zig?

A native Zig implementation of the Tree-sitter parsing runtime: it turns source text into concrete syntax trees, updates them incrementally, and searches them structurally. Version 0.0.1, MIT licensed.

## Does it depend on C?

No. No C code, no `@cImport`, no linked C runtime — Zig and its standard library only.

## Does it depend on Rust?

No.

## Does it use the upstream Tree-sitter C runtime?

No. Upstream was studied as an algorithmic reference during development; the package vendors no upstream code and links nothing.

## Which Zig version?

Exactly 0.16.0.

## Where do I start?

[Getting Started](/guide/getting-started), then [Your First Parser](/guide/first-parser).
