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

## Issue1009Matrix12GroupedTests.swift
## Issue972LiftingTests.swift

One injection, G1, turns all five red: `occtTrsfFromMatrix12Grouped` in `Sources/OCCTBridge/src/OCCTBridge_Internal.h` reads the array positionally (INTERLEAVED) instead of GROUPED, the exact confusion #1009 exists to prevent. It is shared by `OCCTShapeTransformed`, `OCCTCurve3DParametricTransformation` and `OCCTDocumentAddComponentMatrix`, so every call site went red. Parity probe: `Scripts/repro/766-issue1009-matrix12-grouped/`; the earlier `Scripts/repro/1009-matrix12-grouped/` proves the three original readers identical.
Pure Swift: `Placement.lift` (`Sources/OCCTSwift/ConstructionEntity.swift`) and `SheetMetal.Flange.init` (`Sources/OCCTSwift/SheetMetal.swift`). One build carried L1 (lift drops the origin and swaps the axes: `p.x * yAxis + p.y * xAxis`) and L2 (Flange passes the raw `normal` to `Placement(zAxis:)`, the PR #997 finding). Parity uses the kernel's own frame mapping, `gp_Ax3` plus `gp_Trsf::SetTransformation`, in `Scripts/repro/766-issue972-lifting/`.

| Suite | Test | Bridge / Swift function | Injection | Red (failing expectation) | Green | Parity |
|---|---|---|---|---|---|---|
| One GROUPED 12-double reader, shared by all three call sites (#1009) | shapeTransformedAppliesTheGroupedTranslation | OCCTShapeTransformed | G1 | `Issue1009Matrix12GroupedTests.swift:56` `abs((after.min.x - before.min.x) - 5) < 1e-9` and :57 to :61 | passes | PASS: kernel bbox shifts by (5, 6, 7) |
| One GROUPED 12-double reader, shared by all three call sites (#1009) | groupedAgreesWithItsInterleavedConversion | OCCTShapeTransformed, OCCTShapeTransformFromMatrix | G1 | `Issue1009Matrix12GroupedTests.swift:78` `abs(a.min.x - b.min.x) < 1e-9` and :79 to :83 | passes | PASS: kernel bboxes identical, min (-1.830, -0.830, 2.000) |
| One GROUPED 12-double reader, shared by all three call sites (#1009) | curve3dParametricTransformationReadsTheGroupedLayout | OCCTCurve3DParametricTransformation | G1 | `Issue1009Matrix12GroupedTests.swift:102` `abs(scale2 - 2) < 1e-9`, `Issue1009Matrix12GroupedTests.swift:107` `abs(translated - 1) < 1e-9`, :124 to :126 | passes | PASS: kernel 2 and 1 |
| One GROUPED 12-double reader, shared by all three call sites (#1009) | documentAddComponentReadsTheGroupedLayout | OCCTDocumentAddComponentMatrix | G1 | `Issue1009Matrix12GroupedTests.swift:145` `abs((after.min.x - before.min.x) - 5) < 1e-9`, :146, :147 | passes | PASS: located box shifts by (5, 6, 7) |
| One GROUPED 12-double reader, shared by all three call sites (#1009) | documentAddComponentAcceptsAReflection | OCCTDocumentAddComponentMatrix | G1 | `Issue1009Matrix12GroupedTests.swift:175` `abs(after.min.x - -11) < 1e-6`, `Issue1009Matrix12GroupedTests.swift:176` `abs(after.max.x - -1) < 1e-6` | passes | PASS: kernel x in [-11, -1], IsNegative, ScaleFactor -1 |
| Issue972 2D-to-3D lifting | liftMatchesTheFormula | Placement.lift | L1 | `Issue972LiftingTests.swift:22` `abs(lifted.y - 7) < 1e-12`, `Issue972LiftingTests.swift:23` `abs(lifted.z - 3) < 1e-12` | passes | PASS: gp_Ax3 frame gives (5, 7, 3) |
| Issue972 2D-to-3D lifting | liftRespectsARotatedBasis | Placement.lift | L1 | `Issue972LiftingTests.swift:34` `abs(lifted.x - s2) < 1e-12` | passes | PASS: gp_Ax3 frame gives (0.7071, 0.7071, 0) |
| Issue972 2D-to-3D lifting | flangeNormalAgreesWithItsPlacement | SheetMetal.Flange.init | L2 | `Issue972LiftingTests.swift:52` `simd_length(d) < 1e-12` | passes | PASS: gp_Dir(0, 0, 7) normalises to (0, 0, 1) |
