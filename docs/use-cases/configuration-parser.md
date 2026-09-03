---
description: Parsing configuration files and DSLs with tree-sitter.zig.
---

# Configuration Parser

## Problem

Config formats and small DSLs still need positions for error messages and structure for validation.

## Why tree-sitter.zig helps

Even a tiny grammar gets full positions, error recovery (report all errors, not just the first), and queries for validation rules. The bundled `json_language` covers JSON directly — pairs expose `key`/`value` fields, so config readers navigate without manual descent (see `examples/json_parse.zig`).

## API

`Parser`, `Node` navigation, `Query` validation rules, `hasError` aggregation.

## Architecture

```text
Parse config → collect errors via isError/isMissing → query-validate → typed values
```

## Next steps

- [Language Definition](/guide/language-definition), [Error Recovery](/guide/error-recovery)
