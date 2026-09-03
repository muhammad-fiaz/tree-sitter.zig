---
description: Conformance process — the differential corpus harness.
---

# Conformance

Upstream Tree-sitter (C) is a behavioral reference, not a dependency: no C compiles into the package and no symbols are linked. Conformance is enforced by a differential corpus harness, not just hand-written tests.

## The corpus

Cases live in `src/debug/corpus/*.txt`. Parse cases declare a grammar, a source, and the expected S-expression:

```text
# grammar: expression
# name: precedence
---source---
1 + 2 * 3
---sexp---
(program (expression (expression (term (factor (number "1")))) "+" ...))
```

Incremental cases declare an edit triple plus the new source, and require the incremental reparse to be byte-identical to a fresh parse:

```text
# grammar: expression
# name: trailing growth
---source---
1 + 2
---edit---
5 5 6
---source---
1 + 22
```

## Running it

```sh
zig build conformance   # human-readable PASS/FAIL report (exit 1 on failure)
zig build test          # the same cases run as the "conformance: corpus cases pass" test
```

The case list is embedded once (`conformance.corpus_files`), so the report and the test suite cannot drift apart. This harness caught a real reuse-cloning bug during development (bushy subtree clones corrupted incremental trees while weak count assertions passed) — see [Incremental Runtime](/internals/incremental-runtime).

## Adding a case

Add a `*.txt` file in `src/debug/corpus/`, list it in `corpus_files`, and run both commands. Verify the expected S-expression against the grammar tables by hand before locking it in — the corpus is a reference, not an oracle.

Related: [Upstream Conformance](/internals/upstream-conformance), [Testing](/development/testing), [S-expressions](/api/tree).
