---
description: Code transformation — structured rewrites with verification.
---

# Code Transformation

## Problem

Automated rewrites (migrations, codemods) must preserve everything they do not intend to change.

## Why tree-sitter.zig helps

Match ranges are exact, unaffected regions reuse their subtrees, and reparsing the result verifies the output parses cleanly.

## API

`Query` matches → text edits → `Parser.parse` → `hasError` check on the result.

## Architecture

```text
Match → compute edits → apply → reparse → verify no errors
```

## Next steps

- [Refactoring Tools](/use-cases/refactoring-tools), [Error Recovery](/guide/error-recovery)
