# #1190 — `OCCTDrawingGetEdges`'s eight guard-then-add sites

`OCCTDrawingGetEdges` (`Sources/OCCTBridge/src/OCCTBridge_HLR.mm`) reimplemented
`if (!x.IsNull()) { builder.Add(compound, x); }` eight times across its three `switch` cases, one
per `TopoDS_Shape` field of `struct OCCTDrawing` a case might contribute (three for `.visible`,
three for `.hidden`, two more re-reading `visibleOutline`/`hiddenOutline` for `.outline`). All eight
blocks were byte-identical apart from which field they read, so a future change applied to fewer
than all eight would have no compiler or test signal — the risk the original duplication-audit
finding called out.

Fixed by collapsing all eight to a single shared helper, `occtAddShapeIfPresent`
(`Sources/OCCTBridge/src/OCCTBridge_Internal.h`), placed there rather than as a `static` helper
local to `OCCTBridge_HLR.mm` so any other bridge site with the same idiom (the issue also cites
`OCCTBridge_Healing.mm:1966-1969`/`:2013-2016`, out of scope for this fix) can reuse it.

## Why this needs a C++ test, not a Swift one

`OCCTDrawing`'s six `TopoDS_Shape` fields are bridge-internal — there is no Swift-visible getter for
any of them, and there should not be one added just to make this testable. Which fields a *real*
HLRBRep projection populates is a property of the input geometry, not something a Swift-level
fixture can hand-pick. Every existing Swift test (`Tests/OCCTDrawingTests/*.swift`) can only assert
"the aggregate `Shape?` is non-nil", which is exactly the gap #1190's own issue body documents: "no
test isolates a single guard block... coverage is at the 'does calling this edgeType return a
non-nil compound' granularity only". A test built that way cannot tell a dropped, duplicated, or
misrouted guard from correct behavior.

`occt_1190_test.mm` instead hand-constructs an `OCCTDrawing` with each of the six fields
independently null or a distinguishable single-vertex shape, then calls the **real, compiled**
`OCCTDrawingGetEdges` (this file is compiled alongside the actual `OCCTBridge_HLR.mm`, not a
reimplementation of it) for all three `OCCTEdgeType` values, and checks the returned compound by
exact vertex identity, not mere non-nullness. See `run.sh` for the build/run and
`occt_1190_test.mm`'s header comment for the full design.

## Prove-the-test-fails (`okf/policies/prove-the-test-fails.md`)

Two independent defects were injected against the fixed source, each run captured as a committed
transcript, then the source was restored and re-verified green:

1. **`broken-missing-site.txt`** — `OCCTBridge_HLR.mm`'s `.outline` case had its
   `occtAddShapeIfPresent(builder, compound, drawing->hiddenOutline);` line commented out,
   simulating "a future change... applied to only 7 of 8 sites" (the issue's own stated risk).
   Result: 2 clean, precisely targeted assertion failures (`outline: includes hiddenOutline`,
   `outline: exactly the two outline fields`) — everything else, including the unrelated
   `.visible`/`.hidden` cases, stayed green. Exit 1.

2. **`broken-guard-disabled.txt`** — `occtAddShapeIfPresent` itself had its `IsNull()` guard
   replaced with `if (true)`, so it always calls `BRep_Builder::Add`, including on a null
   `TopoDS_Shape`. Result: `BRep_Builder::Add` on a null shape SIGSEGVs (exit 139) rather than
   silently no-op'ing, so this defect is also caught, just via crash rather than a clean assertion.

3. **`fixed.txt`** — the same binary, subject restored, all 16 checks pass, exit 0.

`run.sh` reproduces all of this: edit in a defect from either paragraph above, run it, observe the
matching transcript, then `git checkout` the source files back.

## Files

- `occt_1190_test.mm` — the ground-truth C++ test.
- `run.sh` — compiles `occt_1190_test.mm` alongside the real `OCCTBridge_HLR.mm` against the pinned
  xcframework, and runs it.
- `fixed.txt` / `broken-missing-site.txt` / `broken-guard-disabled.txt` — captured transcripts, see
  above.
