---
description: Parsing FAQ — languages, errors, UTF-8, and parser reuse.
---

# Parsing FAQ

## Why use it instead of a regular parser?

Regular parsers start over on every change and fail on the first syntax error. This runtime reuses old work across edits and always returns a tree, which is what editors and tools need.

## How do I parse UTF-8?

Pass the bytes as-is. Offsets stay byte-exact; points track rows and byte-columns. See [Unicode & Positions](/guide/unicode-and-positions).

## How do I parse UTF-16?

Set `.encoding = .utf16_le` / `.utf16_be` on the `Input`. The runtime transcodes to UTF-8 up front (tree offsets refer to the UTF-8 form) and rejects conflicting BOMs and lone surrogates loudly. See [Custom Input](/guide/custom-input).

## How do I inspect errors?

`tree.hasError()`, then walk for `node.isError()` (skipped text) and `node.isMissing()` (inserted zero-width tokens). See [Error Recovery](/guide/error-recovery).

## Is the parser reusable?

Yes — one `Parser` serves unlimited parses, retaining scratch capacity. See [Parser Reuse](/guide/parser-reuse).

## What is a syntax tree / node / cursor?

A tree owns the result; nodes are lightweight handles into it; cursors walk it without allocating. See [Understanding Trees](/guide/understanding-trees).

## Is it thread-safe?

Parsers and trees are not internally synchronized. Use one parser per thread; immutable trees can be read from multiple threads once parsing finishes.

## How do I parse from a stream?

Use `parseStream` with an `Input` callback (or `ReaderSource`): bytes are pulled on demand with no pre-buffering. See [Custom Input](/guide/custom-input).
