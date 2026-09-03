---
description: Language examples — inspecting symbols, tables, and fields.
---

# Languages

## What you'll learn

- How to introspect any loaded language.

## Complete example

`examples/language.zig` prints the bundled grammar's metadata, all 15 symbols with flags, and resolves a symbol and a field by name.

## Running the example

```sh
zig build run-language
```

## Expected output

```text
language: expression abi=15 symbols=15 states=18
  #0 end named=false visible=false
  #1 identifier named=true visible=true
  #2 number named=true visible=true
  #3 + named=false visible=true
  #4 - named=false visible=true
  #5 * named=false visible=true
  #6 / named=false visible=true
  #7 ( named=false visible=true
  #8 ) named=false visible=true
  #9 whitespace named=false visible=false
  #10 program named=true visible=true
  #11 expression named=true visible=true
  #12 term named=true visible=true
  #13 factor named=true visible=true
  #14 ERROR named=true visible=true
symbol for "+": 3
field id for "left": 1 (left)
```

## How it works

Symbols 0–9 are terminals (tokens), 10–13 the grammar's non-terminals, 14 the error symbol. Anonymous tokens (`+`, `(`) are visible but not named — they appear in trees without counting as named children. `left`/`right` fields are bound on the binary productions.

A second bundled grammar, `sexp_language`, covers nested lists — try `zig build run-sexp_parse`:

```text
root: program [0, 17]
grouped list aliased to: sequence text='add 1 (mul 2 3)'
sequence matches: 2
```

A third, `json_language`, covers real JSON — try `zig build run-json_parse`:

```text
root: program has_error=false
first pair: key="name" value="ada"
strings: 4
  "name"
  "ada"
  "scores"
  "admin"
```

And `outline_language` demonstrates external scanners — try `zig build run-external_scanner`:

```text
root: program has_error=false
header: # Shopping
header: # Fruit
```

## API used

- [Language](/api/language), [Symbols](/api/symbols), [Fields](/api/fields).

## Related guides

- [Language Definition](/guide/language-definition)
