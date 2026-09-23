# Phase 3: OCCTMiscTests injection matrix (#1989)

**Target**: every `@Test` in `Tests/OCCTMiscTests/` (119 across six files).
**Policy**: `okf/policies/prove-the-test-fails.md`: inject a defect in the code the test exercises,
watch the named expectation fail, restore, watch it pass.

This file was rewritten from scratch for #1989. The nine rows it held before named five bridge
functions that do not exist (`OCCTShapeProject`, `OCCTKDTreeSearch`, `OCCTHatchPatternGenerate`,
`OCCTUnicodeConvert`, `OCCTDirectoryListing`), ticked every Red and Green cell without quoting a
single failing expectation, and waived the other 110 tests. Every row below was run: the Red
column quotes the expectation that failed under the injection, file:line as Swift Testing printed
it, and Green is the same test passing after the injection was reverted.

Kernel parity for each row is in `../../766-execution/kernel-parity/OCCTMiscTests.json`, with the
probe that produced it under `Scripts/repro/766-*/`.

## Issue972LiftingTests.swift

Pure Swift: `Placement.lift` (`Sources/OCCTSwift/ConstructionEntity.swift`) and `SheetMetal.Flange.init` (`Sources/OCCTSwift/SheetMetal.swift`). One build carried L1 (lift drops the origin and swaps the axes: `p.x * yAxis + p.y * xAxis`) and L2 (Flange passes the raw `normal` to `Placement(zAxis:)`, the PR #997 finding). Parity uses the kernel's own frame mapping, `gp_Ax3` plus `gp_Trsf::SetTransformation`, in `Scripts/repro/766-issue972-lifting/`.

| Suite | Test | Bridge / Swift function | Injection | Red (failing expectation) | Green | Parity |
|---|---|---|---|---|---|---|
| Issue972 2D-to-3D lifting | liftMatchesTheFormula | Placement.lift | L1 | `Issue972LiftingTests.swift:22` `abs(lifted.y - 7) < 1e-12`, `Issue972LiftingTests.swift:23` `abs(lifted.z - 3) < 1e-12` | passes | PASS: gp_Ax3 frame gives (5, 7, 3) |
| Issue972 2D-to-3D lifting | liftRespectsARotatedBasis | Placement.lift | L1 | `Issue972LiftingTests.swift:34` `abs(lifted.x - s2) < 1e-12` | passes | PASS: gp_Ax3 frame gives (0.7071, 0.7071, 0) |
| Issue972 2D-to-3D lifting | flangeNormalAgreesWithItsPlacement | SheetMetal.Flange.init | L2 | `Issue972LiftingTests.swift:52` `simd_length(d) < 1e-12` | passes | PASS: gp_Dir(0, 0, 7) normalises to (0, 0, 1) |
