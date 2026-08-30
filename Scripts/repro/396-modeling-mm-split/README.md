# #396 / #1378: splitting `OCCTBridge_Modeling.mm`

`split_modeling_mm.py` is the one-shot migration script that split the 16,301-line
`Sources/OCCTBridge/src/OCCTBridge_Modeling.mm` into twelve `OCCTBridge_Modeling_<Bucket>.mm`
files (#1378, a sub-issue of #396). The script's own module docstring is the primary writeup:
the structural (brace-depth) scanner design, the three content classes a first pattern-matched
version silently dropped, the taxonomy table, and the CLI (`--report` / `--verify` / `--write` /
`--self-test`).

## Status: already run, not idempotent, not needed again for this file

The script already did its one job: `OCCTBridge_Modeling.mm` is deleted, the twelve output files
exist and are committed. Running `--write` again does nothing useful (the source file it reads is
gone). It is kept here rather than deleted for the same reason #395's own script was kept: #396
lists thirteen more `.mm` bridge files as breakout candidates, and while none of the
classification tables here (`NAME_PREFIX_BUCKET`, `BODY_PACKAGE_TO_BUCKET`, `CLASS_OVERRIDE_BUCKET`,
`NAME_BUCKET_OVERRIDE`) transfer to a different file's content, the *technique* does:

- a structural, brace-depth scanner instead of pattern-matching specific line shapes
- a `SHARED` bucket for every `struct`/`class`/literal-`static` helper, duplicated into every
  output file's preamble rather than single-bucketed (internal linkage makes the duplication safe,
  and it's what avoids restructuring cross-bucket call dependencies)
- a mandatory whole-file line-coverage check (`verify_full_coverage`) that fails loudly on any
  line not accounted for by exactly one of: the preamble, a scattered `#include`, or one classified
  code unit — this is what caught all three drops during development, and it is the part most
  worth reusing verbatim
- a real `--self-test` proving the scanner catches struct/class capture, scattered-include capture,
  template-prefixed functions, and an artificially-removed unit (the coverage check's own "prove it
  catches a drop" case)

## Two gate scripts needed matching fixes

`Scripts/derive-bridge-header-split.py` and `Scripts/check-bridge-index.py` both assumed a 1:1
`<stem>.mm` → `<stem>.h` mapping, which breaks for `OCCTBridge_Modeling_Fillet.mm` (etc.) →
`OCCTBridge_Modeling.h`. Both got a header-name-stripping fallback (strip one `_`-delimited
segment at a time until a real header matches). Whoever tackles the next file on #396's list will
likely need nothing further here, both scripts now already handle `<Domain>_<Bucket>.mm` in
general, not just the Modeling case, since the fallback isn't parametrized on "Modeling" — see
`domain_group()` in `check-bridge-index.py` and `target_header()` in
`derive-bridge-header-split.py`.

**One gotcha to repeat, not rediscover**: the first draft of `check-bridge-index.py`'s fix applied
the header-stripping fallback to `.h` files as well as `.mm` files. `OCCTBridge_Internal.h` has no
real header of its own to stop at, so it stripped all the way down to the genuinely-existing
`OCCTBridge.h` (the umbrella), silently re-keying the shared-helper `SHARED` constant's storage
away from the literal `OCCTBridge_Internal.h` key `reachable()` looks it up by, breaking 19
previously-clean entries in completely unrelated domains. The fix is restricted to `.mm` files
only; `check-bridge-index.py --self-test` (18/18) and the real check (`0 stale, 0 misfiled`) both
catch a regression here if it recurs.

## Verification (full detail in #1378 and the PR that closed it)

Full clean `swift build` + `swift test` (6005 tests), all eight gate scripts clean including both
fixed ones, `count-operations.py` unchanged (4,365, since this is a pure internal reorganization),
`Scripts/format-bridge.sh --check` clean at the pinned clang-format 22.1.8.
