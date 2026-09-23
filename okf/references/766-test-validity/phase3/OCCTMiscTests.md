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

## Issue1565SheetMetalBendDefectsTests.swift

`SheetMetal.Builder` in `Sources/OCCTSwift/SheetMetal.swift`. S1 inverts the sign mapping in `resolvedDirection` (`angle > 0 ? .convex : .concave`); S2 removes the #1565 finding-3 guard in `intersect(bend:a:b:)` (`guard true else`), restoring the pre-fix "not u-aligned means v-aligned" assumption. S1 and S2 were first run together, which confounded the two angle tests (both threw 'no shared seam edge'); S1 was then run alone and the rows below quote that run.

| Suite | Test | Bridge / Swift function | Injection | Red (failing expectation) | Green | Parity |
|---|---|---|---|---|---|---|
| Issue1565 SheetMetal bend defects | negativeAngleOverridesAutoToConvex | SheetMetal.Builder.resolvedDirection | S1 | `Issue1565SheetMetalBendDefectsTests.swift:80` `abs(vAngle - vConvex) < 1e-3`, `Issue1565SheetMetalBendDefectsTests.swift:83` `abs(vAngle - vConcave) > 1.0` | passes | N/A: composite Swift construction |
| Issue1565 SheetMetal bend defects | positiveAngleMatchesGeometricDefault | SheetMetal.Builder.resolvedDirection | S1 | `Issue1565SheetMetalBendDefectsTests.swift:107` `abs(vAngle - vDefault) < 1e-3` | passes | N/A: composite Swift construction |
| Issue1565 SheetMetal bend defects | diagonalSeamFallsBackToNoSplitInsteadOfThrowing | SheetMetal.Builder.intersect(bend:a:b:) | S2 | `Issue1565SheetMetalBendDefectsTests.swift:125` Caught error: SheetMetal: flange 'a' has a stepped seam but a non-rectangular profile (nonRectangularStepFlange, as the test's doc comment predicts) | passes | N/A: composite Swift construction |
