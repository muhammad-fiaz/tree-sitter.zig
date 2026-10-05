---
description: Acknowledgement of the reference Tree-sitter project and algorithms.
---

# Acknowledgement

> [!NOTE]
> This project is an independent implementation developed from scratch and written natively in pure Zig. The original Tree-sitter project was used as the reference for algorithms, behavior, architecture, and feature compatibility.
>
> Reference: https://github.com/tree-sitter/tree-sitter

## Project Independence

`tree-sitter.zig` is an independent pure-Zig implementation and is not affiliated with, maintained by, or endorsed by the original Tree-sitter project or its authors.

The runtime algorithms—including LR state table parsing, subtree reuse for incremental parsing, changed-ranges calculation, error recovery with cost heuristics, and S-expression query execution—are implemented natively in Zig conforming to Tree-sitter's semantics and design.
