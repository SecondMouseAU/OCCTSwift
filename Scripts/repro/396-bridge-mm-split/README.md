# #1380: splitting the remaining `.mm` bridge implementation files

`split_bridge_mm.py` generalizes `Scripts/repro/396-modeling-mm-split/split_modeling_mm.py` (the
`OCCTBridge_Modeling.mm` split, #1378) into a config-driven tool that works on any
`OCCTBridge_<Domain>.mm`, instead of being hardcoded to Modeling.

## What's shared, what's per-domain

The scanner (`scan_structural`), name/kind detection (`name_and_kind`, `code_only`), the mandatory
whole-file line-coverage check (`verify_full_coverage`), the SHARED-bucket design for every
`struct`/`class`/`namespace`/literal-`static` item, and the preamble/write-files machinery are all
in `split_bridge_mm.py` itself and domain-agnostic — proven correct once (by the Modeling split's
own bug history) rather than re-derived per file.

Each domain's taxonomy lives in its own `domains/domain_<name>.py`: the bucket list, one-line
descriptions, and the four classification tables (`name_prefix_bucket`, `body_package_to_bucket`,
`class_override_bucket`, `name_bucket_override`). Built the same way every time: run `--report`,
read `UNCLASSIFIED`, add overrides (investigating each one, not guessing), repeat until 0
unresolved and 0 unclassified, then `--verify` for full-file coverage, then `--write`.

```
python3 split_bridge_mm.py --domain IO --report     # classification only, writes nothing
python3 split_bridge_mm.py --domain IO --verify      # + full-file coverage check
python3 split_bridge_mm.py --domain IO --write       # creates the per-bucket files
python3 split_bridge_mm.py --self-test               # domain-agnostic scanner/coverage self-test
```

## One new structural pattern this generalization found

`OCCTBridge_IO.mm` has two anonymous `namespace { ... }` blocks (wrapping a progress-indicator
class and a path-component helper) — a pattern `OCCTBridge_Modeling.mm` never used, so the
Modeling-specific scanner never needed to handle it. Content inside an anonymous namespace has no
external linkage, the same reasoning that makes a literal `static` helper safe to duplicate across
every split file's preamble, so `name_and_kind` now recognizes `namespace { ... }` and routes it
SHARED unconditionally, deriving a cosmetic name from the first `struct`/`class`/`enum` or function
identifier found inside (for report readability and duplicate-name bookkeeping only — never
load-bearing). Proven with the "prove the test fails" discipline: the self-test's namespace fixture
case was run once against the scanner with the namespace branch disabled (`if False and
NAMESPACE_START.match(...)`), confirmed it failed with the exact original symptom (`UNRESOLVED`,
then `uncovered` lines once the coverage check ran), then restored and confirmed it passes.

**A second, narrower gotcha, not new to this generalization but re-encountered**: `igesMutex()` in
`OCCTBridge_IO.mm` is a lowercase, call-shaped, non-`static` function — the same external-linkage
shape as Modeling's `occtDefeaturingFacesFromShapes`/`occtDefeaturePerform` (declared in
`OCCTBridge_Internal.h` so every split file's TU shares one mutex via the linker). The scanner
already handles this correctly (it checks for the literal `static` keyword, not just a lowercase
name, before routing SHARED), so `igesMutex` correctly fell to `UNCLASSIFIED` rather than
`SHARED` — it just needed a `name_bucket_override` entry like any other unclassified function,
not a scanner fix.

## Per-domain results so far

- **IO** (#1380): `OCCTBridge_IO.mm` (4,714L) → 7 files (`StepFormat`, `IgesFormat`,
  `MeshFormats`, `NativeFormats`, `Diagnostics`, `OSDUtilities`, `Misc`). First run of the
  generalized script: 0 unresolved / 0 unclassified after 3 config-tuning passes, clean
  compile+link on the first `swift build --target OCCTBridge` (no cross-bucket dependency bugs
  and no external-linkage-duplication bugs this time, unlike Modeling's own history — the SHARED
  design and the `static`-keyword check both already existed going in).

See #1380 for the remaining files and which ones are expected to resolve as "no split needed"
(cohesive, single-dominant-package files, the same criterion #663/#687 applied to the Swift-file
candidates, adapted for `.mm` files: see #1380's own body for the distinction).
