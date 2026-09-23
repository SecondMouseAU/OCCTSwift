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

## Issue622AllocationBoundsTests.swift

The clamp under test is Swift-side, `Sampling.capacity` (`Sources/OCCTSwift/Sampling.swift`), so it has no kernel counterpart. What the kernel does decide is the uncapped result count the clamped call must reproduce, and `Scripts/repro/766-issue622-allocation-bounds/` measures it with each bridge function's own OCCT call. The bridge counts are the default-capacity results printed from the Swift API in the same build. Injections: C1, `Sampling.capacity` returns 1 for every input (one build, with U1: `convertFromUnicode` returns "" rather than nil for a non-positive size, and LS1: `LogSample.sample` clamps its count instead of rejecting it). C1 left two tests green because their fixtures return zero results, so a capacity of 1 changes nothing; for those, C2 removed the lower clamp and the zero-capacity guard at the call site, and each test trapped in `Array(repeating:count: -1)`, the pre-#622 failure mode. They were run one test per process for that reason.

| Suite | Test | Bridge / Swift function | Injection | Red (failing expectation) | Green | Parity |
|---|---|---|---|---|---|---|
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
