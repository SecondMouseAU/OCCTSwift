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
## Issue622AllocationBoundsTests.swift

One injection, G1, turns all five red: `occtTrsfFromMatrix12Grouped` in `Sources/OCCTBridge/src/OCCTBridge_Internal.h` reads the array positionally (INTERLEAVED) instead of GROUPED, the exact confusion #1009 exists to prevent. It is shared by `OCCTShapeTransformed`, `OCCTCurve3DParametricTransformation` and `OCCTDocumentAddComponentMatrix`, so every call site went red. Parity probe: `Scripts/repro/766-issue1009-matrix12-grouped/`; the earlier `Scripts/repro/1009-matrix12-grouped/` proves the three original readers identical.
Pure Swift: `Placement.lift` (`Sources/OCCTSwift/ConstructionEntity.swift`) and `SheetMetal.Flange.init` (`Sources/OCCTSwift/SheetMetal.swift`). One build carried L1 (lift drops the origin and swaps the axes: `p.x * yAxis + p.y * xAxis`) and L2 (Flange passes the raw `normal` to `Placement(zAxis:)`, the PR #997 finding). Parity uses the kernel's own frame mapping, `gp_Ax3` plus `gp_Trsf::SetTransformation`, in `Scripts/repro/766-issue972-lifting/`.
The clamp under test is Swift-side, `Sampling.capacity` (`Sources/OCCTSwift/Sampling.swift`), so it has no kernel counterpart. What the kernel does decide is the uncapped result count the clamped call must reproduce, and `Scripts/repro/766-issue622-allocation-bounds/` measures it with each bridge function's own OCCT call. The bridge counts are the default-capacity results printed from the Swift API in the same build. Injections: C1, `Sampling.capacity` returns 1 for every input (one build, with U1: `convertFromUnicode` returns "" rather than nil for a non-positive size, and LS1: `LogSample.sample` clamps its count instead of rejecting it). C1 left two tests green because their fixtures return zero results, so a capacity of 1 changes nothing; for those, C2 removed the lower clamp and the zero-capacity guard at the call site, and each test trapped in `Array(repeating:count: -1)`, the pre-#622 failure mode. They were run one test per process for that reason.

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
| Issue #622: result-buffer capacities bound the count a caller can supply | raycastCapacity | OCCTShapeRaycast | C1 | `Issue622AllocationBoundsTests.swift:71` `b.raycast(origin: origin, direction: direction, maxHits: 0).count == 0`, :72 | passes | PASS: 2 hits |
| Issue #622: result-buffer capacities bound the count a caller can supply | curve3DCapacities | OCCTCurve3DExtrema, OCCTCurve3DIntersectSurface, OCCTCurve3DSplitAtContinuity | C1 | `Issue622AllocationBoundsTests.swift:93` `a.extrema(with: b, maxCount: 0).count == 0`, :94, :101, :102, :107, :108 | passes | PASS: 1, 1, 1 |
| Issue #622: result-buffer capacities bound the count a caller can supply | curve2DSplitCapacity | OCCTCurve2DSplitAtContinuity | C1 | `Issue622AllocationBoundsTests.swift:117` `c.splitAtContinuity(maxSegments: 0).count == 0`, :118 | passes | PASS: 1 piece |
| Issue #622: result-buffer capacities bound the count a caller can supply | surfaceIntersectionCapacity | OCCTSurfaceIntersect | C1 | `Issue622AllocationBoundsTests.swift:128` `a.intersections(with: b, maxCurves: 0).count == 0`, :129 | passes | PASS: 1 line |
| Issue #622: result-buffer capacities bound the count a caller can supply | projectionCapacities | OCCTExtremaPointCurve, OCCTExtremaPointSurface | C1 | `Issue622AllocationBoundsTests.swift:139` `c.projectPointAll(q, maxResults: 0).count == 0`, :140, :147, :148 | passes | PASS: 1 and 1 |
| Issue #622: result-buffer capacities bound the count a caller can supply | allDistanceSolutionsCapacity | OCCTShapeAllDistanceSolutions | C1 | `Issue622AllocationBoundsTests.swift:165` `b.allDistanceSolutions(to: s, maxSolutions: 0)?.count == 0`, :167 | passes | PASS: 3 solutions |
| Issue #622: result-buffer capacities bound the count a caller can supply | selfIntersectionPairsCapacity | OCCTShapeSelfIntersectionPairs | C2 (C1 left it green: zero pairs) | trap: `Fatal error: Can't construct Array with count < 0` | passes | PASS: 0 pairs |
| Issue #622: result-buffer capacities bound the count a caller can supply | kdTreeCapacities | OCCTKDTreeKNearest, OCCTKDTreeRangeSearch, OCCTKDTreeBoxSearch | C1 | `Issue622AllocationBoundsTests.swift:185` `t.kNearest(to: .zero, k: 3).count == 3`, :186 to :188, :192, :193, :199, :200 | passes | PASS: 3, 3, 3 |
| Issue #622: result-buffer capacities bound the count a caller can supply | selectorPickCapacities | OCCTSelectorPick, OCCTSelectorPickRect, OCCTSelectorPickPoly | C2 (C1 left it green: zero hits) | trap: `Fatal error: Can't construct Array with count < 0` | passes | N/A: no hit to count |
| Issue #622: result-buffer capacities bound the count a caller can supply | hatchCapacity | OCCTHatchLines | C1 | `Issue622AllocationBoundsTests.swift:265` `HatchPattern.generate(..., maxSegments: 0).count == 0`, :270 (maxSegments: -1) | passes | N/A: bridge-side line generation |
| Issue #622: result-buffer capacities bound the count a caller can supply | unicodeCapacity | OCCTUnicodeConvertFromUnicode | U1 | `Issue622AllocationBoundsTests.swift:283` `UnicodeUtils.convertFromUnicode("hello", maxSize: 0) == nil`, :284 | passes | PASS: "hello" |
| Issue #622: result-buffer capacities bound the count a caller can supply | listingCapacities | OCCTFileList, OCCTDirectoryList | C1 | `Issue622AllocationBoundsTests.swift:308` `fileBaseline == 7`, :310, :311, :312, :316, :317 | passes | PASS: 7 files |
| Issue #622: result-buffer capacities bound the count a caller can supply | logSampleIsARequest | OCCTLogSample | LS1 | `Issue622AllocationBoundsTests.swift:329` `LogSample.sample(from: 1, to: 100, count: n).count == 0` (three of the five n) | passes | PASS: 16 samples, 1 to 100 |
