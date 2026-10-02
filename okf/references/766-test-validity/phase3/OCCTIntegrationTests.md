# Phase 3: OCCTIntegrationTests Injection Matrix

**Target**: `OCCTIntegrationTests` (19 tests, one file: `Tests/OCCTIntegrationTests/OCCTIntegrationTests.swift`)
**Policy**: `prove-the-test-fails.md`: inject defect, confirm red, restore, confirm green
**Issue**: #1988

Every row below was run. The previous version of this page (PR #2021) was removed rather than
amended: none of its rows had been run, three named bridge functions that do not exist
(`OCCTShapeOBB`, `OCCTShapeWriteBREP`/`ReadBREP`, `OCCTSurfaceCurvature`), and its injections
could not have produced the failures it claimed (a "skip union" injection said to fail
`vUnion > 0`, which the base plate alone satisfies).

Kernel values: `Scripts/repro/766-integration-tests/probe.mm`, output in `transcript.txt` beside it.

Injections were applied in seven rounds by a script and reverted with a checkout of `Sources/`
after each; within a round, every test listed is reached by only one of that round's injected
functions, so each red is attributable. Green after the last revert: 19 of 19. Line numbers are
those of the committed file; `swift-format` re-wrapped two `guard`s after the runs, a
whitespace-only change, and the numbers here are shifted to match.

## Rewritten tests

Fourteen tests were rewritten or tightened: they had assertions nested in `if let` on the result
of the step they claimed to check, or thresholds a wrong answer also met. They now assert
unconditionally against probed values.
Measured on the original code: the bracket's fillet and chamfer, the fluent chain's shell and the
bottle's shell all return nil, so those steps never ran; an OBB that fell back to the axis-aligned
box (volume 12500) passed `obbVolume <= aabbVolume * 1.01` (12625); a union that dropped the wall
still leaves a drilled plate with more than 6 faces and 12 edges, which was all the old bracket
test asked of the final shape.

Three of the fourteen read section-wire lengths (`cylinderWithHolesSlicing`,
`pocketSectionAndOffset`, `cylinderConsistentCircularSections`) and were blind to a wire whose
`length` is nil: a nil is dropped (`compactMap`, `if let`), the array comes out short, and the
length checks after it run on nothing. Each now asserts the number of lengths read before it
checks their values. Measured before the count assertions: with one wire per test reporting no
length (the 2 pi 25 circle and the 240 pocket wall) all three stayed green; with every wire
reporting none, `cylinderWithHolesSlicing` and `cylinderConsistentCircularSections` stayed green
and `pocketSectionAndOffset` failed only through its "No 400-long outer wire" guard. After: all
three are red under both, at `:250`, `:431` and `:581`.

Unchanged: `integrateSin`, `adaptive`, `integrate2D`, `integrateSet`, `plateWithHolesSection`.
Each already failed under its injection.

## Injection Matrix

| Test | Bridge function | Injection | Red (first failing line) | Green |
|------|-----------------|-----------|--------------------------|-------|
| KronrodIntegration::integrateSin | `OCCTMathKronrodIntegration` | value x 0.5 | `:20 abs(r.value - 2.0) < 1e-6` | yes |
| KronrodIntegration::adaptive | `OCCTMathKronrodIntegrationAdaptive` | value + 1e-6 | `:28 abs(r.value - 2.0) < 1e-8` | yes |
| GaussMultipleIntegration::integrate2D | `OCCTMathGaussMultipleIntegration` | value + 1e-4 | `:39 abs(r - 2.0 / 3.0) < 1e-6` | yes |
| GaussSetIntegration::integrateSet | `OCCTMathGaussSetIntegration` | result equations swapped | `:60 abs(r[0] - 2.0) < 1e-9` | yes |
| Integration: Mounting Bracket::mountingBracketFullWorkflow | `OCCTShapeUnionEx` | return shape1 (fuse skipped) | `:114 near(bracket.volume ?? -1, 28000)` | yes |
| | `OCCTShapeFillet` | return input (fillet skipped) | `:123 bracket.filleted(radius: 1.0) == nil` | yes |
| | `OCCTShapeChamfer` | return input (chamfer skipped) | `:151 current.chamfered(distance: 0.5) == nil` | yes |
| | `OCCTShapeCreateBox` | depth x 1.0001 | `:95 near(basePlate.volume ?? -1, 16000)` | yes |
| Integration: Fluent Composition Chain::fluentChainVolumeDecreases | `OCCTShapeFillet` | return input | `:176 near(v2, 3958.4188669627, 1e-8)` | yes |
| | `OCCTShapeChamfer` | return input | `:199 near(v4, 3673.9225194390, 1e-8)` | yes |
| | `OCCTShapeShell` | return input (shell skipped) | `:204 chamfered.shelled(thickness: -1.0) == nil` | yes |
| | `OCCTShapeDrillHole` | return nil | `:184 Issue recorded` (drill guard) | yes |
| Integration: Z-Level Slicing::cylinderWithHolesSlicing | `OCCTShapeSectionWiresAtZ` | plane at z + 1000 | `:241 shape.sectionWiresAtZ(z).count == 4` | yes |
| | `OCCTShapeDrillHole` | return nil | `:229 Issue recorded` | yes |
| | `OCCTWireGetLength` | length x 1.01 | `:252 near(lengths[k], 2 * Double.pi * 3, 1e-9)` | yes |
| | `OCCTWireGetLength` | the 2 pi 25 circle reports no length (nil) | `:250 lengths.count == 4` | yes |
| Integration: Hole Detection::plateWithHolesSection | `OCCTShapeSectionWiresAtZ` | plane at z + 1000 | `:287 wires.count == 5` | yes |
| | `OCCTShapeDrillHole` | return nil | `:287 wires.count == 5` | yes |
| Integration: Degenerate Resilience::oversizedFilletReturnsNil | `OCCTShapeFillet` | return input | `:303 box.filleted(radius: 20) == nil` | yes |
| Integration: Degenerate Resilience::zeroDepthDrill | `OCCTShapeDrillHole` | return nil | `:316 Issue recorded` | yes |
| Integration: Degenerate Resilience::selfUnion | `OCCTShapeUnionEx` | return nil | `:330 Issue recorded` | yes |
| | `OCCTShapeUnionEx` | return shape1 | stays green: shape1 is the right answer to A union A | n/a |
| Integration: OBB Tightness::obbTighterThanAABBForRotatedShape | `OCCTShapeOrientedBoundingBox` | AABB returned as OBB | `:370 abs(halves[1] - 5) < 1e-6` | yes |
| Integration: Memory Stress::thousandBoxesNoLeak | `OCCTShapeCreateBox` | depth x 1.0001 | `:394 volumes.allSatisfy { $0 == 6000 }` | yes |
| Integration: Pocket Clearing::pocketSectionAndOffset | `OCCTShapeSubtractEx` | return shape1 (cut skipped) | `:425 near(pocket.volume ?? -1, 300_000 - 72_000)` | yes |
| | `OCCTShapeSectionWiresAtZ` | plane at z + 1000 | `:429 wires.count == 2` | yes |
| | `OCCTWireGetLength` | length x 1.01 | `:433 near(lengths[0], 240)` | yes |
| | `OCCTWireGetLength` | the 240 pocket wall reports no length (nil) | `:431 lengths.count == 2` | yes |
| | `OCCTWireOffset` | distance sign flipped | `:447 offsetWire.length.map { near($0, 360) } ?? false` | yes |
| Integration: Scallop Analysis::surfaceCurvatureVariation | `OCCTSurfaceGetGaussianCurvature` | mean curvature returned | `:477 abs(gauss - expectedGaussian) < 1e-15` | yes |
| Integration: Bottle Profile::bottleShapeWorkflow | `OCCTShapeUnionEx` | return shape1 | `:538 near(solidVolume, ...)` | yes |
| | `OCCTShapeFillet` | return input | `:546 near(filleted.volume ?? -1, 35264.4238509306, 1e-8)` | yes |
| | `OCCTShapeShell` | return input | `:550 filleted.shelled(thickness: -2.0) == nil` | yes |
| Integration: Cross-Section Regression::cylinderConsistentCircularSections | `OCCTShapeSectionWiresAtZ` | plane at z + 1000 | `:573 wires.count >= 1` | yes |
| | `OCCTWireGetLength` | length x 1.01 | `:585 abs(len - expectedCircumference) < 1.0` | yes |
| | `OCCTWireGetLength` | the 2 pi 25 circle reports no length (nil) | `:581 lengths.count == nLevels` | yes |
| Integration: Tolerance Cascade::booleanWithSharedEdgeAndGap | `OCCTShapeUnionEx` | return shape1 | `:619 near(combined.volume ?? -1, 2000)` | yes |
| Integration: Format Fidelity BREP::brepStringRoundTrip | `OCCTShapeToBREPString` | writes the shape reversed | `:684 abs(rVol - origVolume) < 1e-6` | yes |
| | `OCCTShapeFillet` | return input | `:663 near(origVolume, 8363.4129559647, 1e-8)` | yes |

## Kernel parity

19 of 19 MATCH (records in `okf/references/766-execution/kernel-parity/OCCTIntegrationTests.json`).
`thousandBoxesNoLeak` has parity for its volume only: nothing in it can observe a leak.

## Side findings (not fixed here)

- **A truncated BREP string crashes the process.** The first injection tried for
  `brepStringRoundTrip` handed `OCCTShapeFromBREPString` the first half of a valid string, and
  the test process aborted (`SIGSEGV ... no catch was found`). The probe reproduces it in the
  kernel: `BRepTools::Read` on that half aborts even with `OSD::SetSignal` installed. So
  `Shape.fromBREPString` on truncated input takes the caller down.
- **`OCCTShapeFillet` passes through an invalid shape** for radii just above the half-edge
  limit: on the 10-cube, r = 5.1 and r = 6 report done and return a shape `BRepCheck_Analyzer`
  rejects, with zero volume. r = 5 and r = 20 return nil.
- **The bracket chamfer SIGSEGVs inside `BRepFilletAPI_MakeChamfer`** when `OSD::SetSignal` is
  not installed. The bridge installs it on the first boolean, so from Swift it reads as nil.
