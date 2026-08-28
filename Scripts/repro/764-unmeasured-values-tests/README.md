# #764: sub-kind 2 (test pinned-count) full adjudication

Part of #726's unmeasured-values phase. Gates Passes 5a-5d (#389-#392) per
`okf/policies/prove-the-test-fails.md`.

The issue text cited 73 candidates. A fresh `python3 Scripts/census-unmeasured-values.py --tests`
run at the start of this work reported **100** (the number had already moved since filing, from new
suites landing between then and now), so 100 is the real starting count this adjudication worked
against, not 73.

All 100 were read in full (the actual test function, its fixture-builder helpers, and any same-file
verification helper) and adjudicated individually, not sampled. **11 were genuine gaps** and are
fixed in this PR, each verified with a real prove-the-test-fails injection (see "Prove the test
fails" below). **89 were not gaps**: either an existing assertion in the same test already catches
the no-op this census flags as a risk (frequently a *different counting property* — a face count
alongside a solid count, a per-item loop, a geometric dot-product check — that the detector's
ten-word keyword scan (`volume|area|length|mass|distance|delta|deviation|thickness|extent|overlap`)
cannot see), or the pinned count *is* the test's own declared subject and a no-op producing the same
count is not a live risk for that fixture. Zero were left "uncertain": every candidate reached a
confident verdict.

Adjudication was done by 8 independent read-only passes over disjoint file groups (7 dispatched
subagents plus one done directly), each given the same worked-example calibration (the two already-
adjudicated `Issue443FirstOfNTests.swift` NOT-GAP cases from `okf/policies/prove-the-test-fails.md`
and this repo's own #703 precedent) so verdicts were reached independently rather than by one pass
skimming 100 candidates.

## Tally

| | count |
|---|---|
| Candidates examined | 100 |
| Genuine gaps (fixed) | 11 |
| Not a gap | 89 |
| Uncertain | 0 |

## Full verdict table

Columns: candidate # · file:line (as reported by the census run this adjudication started from) ·
function · verdict · reasoning.

| # | file:line | function | verdict | reasoning |
|---|---|---|---|---|
| 1 | Issue617FaceGridLayoutTests.swift:273 | `squareAndSingleGridsStillWork` | NOT-GAP | Trigger is the test's own `fixture()` helper matching `fix*`, a false positive unrelated to `ShapeFix`. The 4×4 case's `positions.count == 16` is cross-checked per-sample against `f.surface.point(atU:v:)` at 1e-9 tolerance; the 1×1 case's `count == 1` is definitional (a 1×1 grid always yields exactly 1 sample). |
| 2 | OCCTBRepGraphTests.swift:769 | `shellSolids` | NOT-GAP | `shellSolidCount`/`shellSolids` ARE the thing under test on a plain box (no risky boolean/heal op runs at all). `solids.count == 1` is cross-checked against a separate query (`shellSolidCount(0) == 1`) and content identity (`solids[0] == 0`). |
| 3 | OCCTCurveTests.swift:19 | `loftedShapeEdgePolylines` | NOT-GAP | The declared subject is a self-referential API invariant: does `allEdgePolylines().count` always equal `edgeCount`, both read off the SAME lofted shape? A no-op loft would still satisfy this identity. Loft geometric correctness is out of this test's scope (covered elsewhere). |
| 4 | OCCTDrawingTests.swift:2216 | `reflexRaysDrawTheShortArc` | NOT-GAP | Trigger is the local var `sweepDeg` matching `sweep*`, unrelated to any OCCT sweep (pure 2D drawing math). `#expect(sweeps.count == 1)` only guards `.first`; the real check is the very next line, an exact-angle assertion (`abs(sweepDeg - 160.0) < 1e-6`) that is the actual #1169 regression guard. |
| 5 | OCCTIOTests.swift:1855 | `stepProgressCallbackFires` | NOT-GAP | Trigger is the local `imported` matching `import*`. `recorder.events.count >= 1` IS the test's entire declared subject ("STEP import calls progress callback at least once"); there is no separate no-op risk to guard against. |
| 6 | OCCTIntegrationTests.swift:196 | `cylinderWithHolesSlicing` | NOT-GAP | `midWires.count == 4` (outer + 3 holes) is an exact-equality count generated from a Z-slice; a no-op on any of the 3 `drilled` calls collapses it to 1, so this exact check is self-defending against the no-op risk it was flagged for. |
| 7 | OCCTIntegrationTests.swift:244 | `plateWithHolesSection` | NOT-GAP | Same shape as #6: `wires.count == 5` (outer + 4 holes), exact equality, self-sensitive to any of the 4 `drilled` calls no-op'ing (an undrilled box's Z=0 section has exactly 1 wire). |
| 8 | OCCTIntegrationTests.swift:361 | `pocketSectionAndOffset` | NOT-GAP | Contains a real, keyword-invisible volume-delta check earlier in the body (`#expect(pv < ov)`, abbreviated `pv`/`ov` for pocket/outer volume) that directly catches a no-op `subtracting()`. The flagged `wires.count >= 1` is a weak sanity check downstream of that, not standing in for the no-op risk. |
| 9 | Issue1089PocketFeatureIsOpenCompoundTests.swift:26 | `pocketIsOpenOnCompoundWithSolidGroupsNil` | NOT-GAP | `pieces.count == 2`/`pockets.count == 2` fail hard under a no-op split/subtract (1 piece, 0 pockets). The test's real subject (`isOpen` under the `solidGroups == nil` fallback) is checked directly by an independent boolean loop. |
| 10 | Issue1089PocketFeatureIsOpenCompoundTests.swift:104 | `pocketIsOpenOnDisjointSolidsWithCountMismatch` | NOT-GAP | Both flagged counts depend on `boxA.subtracting(tool)` actually creating a pocket; a no-op leaves 0 pockets, failing `>= 1` directly. `openPockets.count >= 1` is also this control's own declared subject. |
| 11 | Issue1089PocketFeatureIsOpenCompoundTests.swift:144 | `nonManifoldEdgeAdjacentFaces` | NOT-GAP | Same split/subtract fixture-integrity argument as #9. The real subject (a non-manifold edge shared by >2 faces) is independently verified via `foundNonManifold`/`maxFaces >= 3`, real per-edge measurement. |
| 12 | Issue497DefeaturingTests.swift:87 | `outOfRangeIndexFails` | NOT-GAP | Trigger words come from a separate fixture helper (`Self.filletedBox()`) used only to derive an out-of-range index; `realFaces.count == 6` is a deterministic sanity check on a plain, unmutated box. The real subject (rejecting an out-of-range index) is checked directly via `== nil`. |
| 13 | Issue497DefeaturingTests.swift:126 | `withoutSmallFacesKeepsEverything` | NOT-GAP | Correct behavior under test IS a no-op (nothing small enough to remove); the actual risk (over-aggressive removal) is caught by BOTH `faces().count == 6` and an exact-volume check (`abs(v - 1000.0) < 1e-6`, abbreviated `v`, keyword-invisible only). |
| 14 | Issue505FilletBuilderEdgeTypeTests.swift:69 | `edgeFromAnotherContourIsRejected` | NOT-GAP | Trigger is the class under test (`FilletBuilder`), not a prior risky op. `edges.count == 12` is a deterministic box fact; the real regression (rejecting a foreign edge) is checked directly via `== nil`/`!= nil`. |
| 15 | Issue578DefeatureFaceMembershipTests.swift:72 | `foreignFaceInMixedRequestFails` | NOT-GAP | `alone.faces().count == 6` directly measures whether `defeature(faces:)` removed the fillet face (7→6 against the fixture's own 7-face precondition); a no-op leaves 7, failing outright. The real subject (mixed/foreign request fails whole call) is checked via `== nil`. |
| 16 | Issue612FilletContourSelectionTests.swift:89 | `fixtureHasATangentContinuousRim` | NOT-GAP | The declared subject is a topological fact: adding only `pair.line` still makes `pair.arc` a member of the same contour (`contour(for: pair.arc) == 1`), an independent property a broken tangency-detector would directly break. |
| 17 | Issue639FilletDeclinedEdgeReportTests.swift:41 | `filletedWithReportNamesDeclinedEdges` | NOT-GAP | Flagged pin (`edges.count == 12`, false-triggered via `shell`) is a fixture sanity check. The real assertion, `Set(report.declinedEdgeIndices) == Set(Self.declinedIndices)`, validates against a known census answer directly; a `surfaceArea` cross-check (keyword-invisible: "Area" sits mid-identifier in `surfaceArea` with no word boundary before it, so the detector's `\barea\w*\b` never matches) confirms geometry is unchanged. |
| 18 | Issue639FilletDeclinedEdgeReportTests.swift:157 | `historyRecordNamesDeclinedEdges` | NOT-GAP | Same shape as #17. Real verification is `Set(declined) == Set(Self.declinedIndices)` via an independent mechanism (`ShapeHistoryRecord`), plus a per-edge loop and a check that at least one declined edge shows `modified`. |
| 19 | Issue639FilletDeclinedEdgeReportTests.swift:207 | `declinedEdgeNamedTwiceIsReportedTwice` | NOT-GAP | The count (`== 2`) IS the test's declared subject (guards against silent dedup of a repeated request entry); cross-validated by a `Set` equality confirming both entries name the correct edge. |
| 20 | Issue642AAGNodeIdentityTests.swift:80 | `detectPocketsAgreesAcrossOrder` | NOT-GAP | Fixture is proven, by the file's own cross-referenced bug history (#642→#699→#703), to have zero real pockets (two boxes glued face-to-face, no concavity). The pinned value has moved three times as real fixes landed, direct evidence it's sensitive to regressions, not inert. |
| 21 | Issue642AAGNodeIdentityTests.swift:105 | `upwardHorizontalCountAgreesAcrossOrder` | NOT-GAP | Pinned count (2, non-trivial) is documented (outer top face + shared wall's upward side); a broken/empty graph gives 0, not 2. |
| 22 | Issue642AAGNodeIdentityTests.swift:144 | `sharedWallNodesShareDistinctIndexAndOpposeUpward` | NOT-GAP | `shared.count == 1` is cross-validated by two further in-test assertions (`sides.map(\.isUpward)` sorted equals `[false, true]`, `sides.allSatisfy(\.isHorizontal)`), which a broken classifier or a reverted fix would fail directly. |
| 23 | Issue655SectionWiresOrientationTests.swift:86 | `internalEdgeExcluded` | NOT-GAP | `wires.count == 1` IS the direct #655 defect under test, cross-validated within the same function by `only.edges().count == 4` and `only.curveInfo?.isClosed == true`. |
| 24 | Issue655SectionWiresOrientationTests.swift:103 | `forwardEdgeNotExcluded` | NOT-GAP | Explicit "prove the test fails" control for #23: `wires.count == 2` is the declared subject, proving the exclusion is orientation-specific. |
| 25 | Issue655SectionWiresOrientationTests.swift:117 | `externalEdgeExcluded` | **GAP — FIXED** | Unlike its sibling `internalEdgeExcluded` (#23), had only the bare `wires.count == 1`, no check the surviving wire is the correct, undamaged square. A partial/wrong exclusion (dropping one of the square's own edges instead of the floating edge) could still land on `wires.count == 1`. Fix: copied the sibling's own `edges().count == 4` / `curveInfo?.isClosed == true` checks. |
| 26 | Issue699AAGSolidScopedAdjacencyTests.swift:78 | `detectPocketsAgreesAcrossOrder` | NOT-GAP | Same reasoning as #20 on the vertical-cut fixture (0 real pockets by construction); this file's own `nodeCountUnaffected`/`edgeCountIsTwoIndependentBoxGraphs` independently verify the AAG graph for this exact fixture is non-trivially, correctly constructed. |
| 27 | Issue699AAGSolidScopedAdjacencyTests.swift:100 | `nodeCountUnaffected` | NOT-GAP | The count (12) IS the declared subject (a narrow regression guard that #699's edge-scoping change didn't also touch node construction); non-trivial, a broken graph gives 0. |
| 28 | Issue699AAGSolidScopedAdjacencyTests.swift:118 | `edgeCountIsTwoIndependentBoxGraphs` | NOT-GAP | This IS #699's headline defect check: the pinned 24 (= 2×12) is precisely the mechanism under test; a reverted fix gives a higher, order-dependent number, a broken graph gives 0. |
| 29 | Issue699AAGSolidScopedAdjacencyTests.swift:200 | `horizontalFixtureStillAgreesAtCorrectedCount` | NOT-GAP | Same cross-referenced-to-bug-history reasoning as #20/#26; declared subject is order-invariance at the corrected count. |
| 30 | Issue699AAGSolidScopedAdjacencyTests.swift:245 | `countMismatchFallsBackToUnrestrictedComparison` | NOT-GAP | The flagged `mixed.detectPocketsAAG().count == 0` is preceded, in the same function, by `aag.nodes.count == total` (a non-trivial fixture-derived value); a broken graph fails that first. |
| 31 | Issue699AAGSolidScopedAdjacencyTests.swift:279 | `threeSolidCompoundPartitions` | NOT-GAP | Preceded, in the same function, by `straight.buildAAG().nodes.count == 18` (3 solids × 6 faces, non-trivial); the trailing pocket-count check rides on an already-verified graph. |
| 32 | Issue703EdgeConvexityOrderTests.swift:54 | `gluedBoxesHaveNoConcaveEdgesEitherOrder` | NOT-GAP | Already asserts `aag.edges.allSatisfy { $0.convexity != .concave }` before the count-pin, a direct, independent classification check. No material-removal op is even involved. |
| 33 | Issue703EdgeConvexityOrderTests.swift:76 | `genuinePocketStillReportsConcaveEdges` | NOT-GAP | Contains an explicit, already-present volume-delta check (`resultVolume < boxVolume`, keyword-invisible only via variable naming) that is exactly the #703/#720 no-op guard. |
| 34 | Issue703EdgeConvexityOrderTests.swift:135 | `throughHoleHasNoConcaveEdges` | NOT-GAP | `aag.edges.count == 14` is a structural cross-check: an undrilled plate has 12 edges (per this file's own `plainBoxHasNoPockets` pin), so a no-op drill would fail this before the concave/pocket counts are reached. |
| 35 | Issue703EdgeConvexityOrderTests.swift:160 | `squarePocketHasExactlyEightConcaveEdges` | NOT-GAP | The pinned value (8 concave edges) is self-verifying: a plain, undrilled box has 0 (per #703's own stated invariant), so a no-op pocket tool produces 0, not 8. The count is the declared subject. |
| 36 | Issue724PocketGroupingFloorTests.swift:39 | `blindCylindricalPocketReportsOne` | NOT-GAP | Already has both a `zLevel ≈ 0` check and `wallFaceIndices.count == 1`, explicitly added (per its own comment) to rule out keeping the wrong candidate floor. |
| 37 | Issue724PocketGroupingFloorTests.swift:68 | `holdsAcrossToolHeight` | **GAP — FIXED** | Only `count == 1`, for 3 tool heights. Unlike its sibling at line 39, no `zLevel` check: a regression that kept the *wrong* candidate floor while still discarding the other could still report exactly 1 pocket. Fix: added the same `zLevel ≈ 0` check the sibling test uses. |
| 38 | Issue724PocketGroupingFloorTests.swift:87 | `genuineFourWalledPocketKeepsAllWalls` | NOT-GAP | `wallFaceIndices.count == 4` IS the declared subject (guards #724's fix against over-filtering a genuinely-shared wall); a no-op subtraction yields `pockets.first == nil`, failing both assertions. |
| 39 | Issue724PocketGroupingFloorTests.swift:106 | `pinnedSquarePocketFixtureUnaffected` | **GAP — FIXED** | Only `count == 1` across 3 depths, for a fixture whose full structure is already pinned elsewhere (`Issue703EdgeConvexityOrderTests`), but lacked the sibling's own `wallFaceIndices.count == 4` check, so #724's Z-filter silently dropping 1-3 of the 4 walls could pass undetected. Fix: added the same `wallFaceIndices.count == 4` check `genuineFourWalledPocketKeepsAllWalls` uses. |
| 40 | Issue733MeshTriangulationBoundsTests.swift:41 | `meshingDoesNotDropTheCylindricalPocket` | NOT-GAP | Already has full `zLevel`/`wallFaceIndices.count == 1` cross-checks, matching the established idiom. |
| 41 | Issue733MeshTriangulationBoundsTests.swift:61 | `unmeshedFixtureStillReportsThePocket` | NOT-GAP | Uses the byte-identical fixture as the immediately-preceding sibling test in the same file, which already fully validates `zLevel`/`wallFaceIndices` for this exact geometry; this test's sole purpose is confirming the unmeshed baseline still detects it at all. |
| 42 | Issue733MeshTriangulationBoundsTests.swift:142 | `absurdlyTightToleranceRejectsRealPocket` | NOT-GAP | Self-verifying pair: `count == 1` at default tolerance rules out a no-op (would give 0); `count == 0` at `tolerance: 1e-12` is only reachable if the tolerance parameter is actually wired through. The count is the declared subject. |
| 43 | Issue733MeshTriangulationBoundsTests.swift:155 | `aagDetectPocketsHonorsTolerance` | NOT-GAP | Identical reasoning to #42, via `AAG.detectPockets(tolerance:)` directly instead of the `Shape` wrapper. |
| 44 | Issue733MeshTriangulationBoundsTests.swift:169 | `generousToleranceStillFindsPocket` | NOT-GAP | Self-verifying: a no-op `subtracting` gives a plain box (0 concave edges → 0 pockets), failing this exact assertion. No mechanism makes a generous tolerance manufacture a false pocket on unmodified geometry. |
| 45 | Issue735PocketEnclosureTests.swift:46 | `cylindricalPocketIsEnclosed` | NOT-GAP | A no-op `subtracting` leaves a plain box (0 concave edges under the AAG scheme), failing the already-present `pockets.count == 1` assertion. |
| 46 | Issue735PocketEnclosureTests.swift:66 | `squarePocketIsEnclosed` | NOT-GAP | Same mechanism as #45. |
| 47 | Issue735PocketEnclosureTests.swift:87 | `openThreeWalledSlotIsNotEnclosed` | NOT-GAP | Same mechanism as #45. |
| 48 | Issue735PocketEnclosureTests.swift:108 | `closedThreeWalledTriangularPocketIsEnclosed` | NOT-GAP | Same mechanism as #45 (via extrude + subtracting). |
| 49 | Issue735PocketEnclosureTests.swift:135 | `twoWalledThroughSlotIsNotEnclosed` | NOT-GAP | Same mechanism as #45. |
| 50 | Issue735PocketEnclosureTests.swift:181 | `openPocketWithFloorBossIsNotEnclosed` | NOT-GAP | Base (bossless) fixture's wall count is independently pinned at 3 elsewhere in this file (identical box/tool); a no-op `union` leaves `wallFaceIndices.count == 3`, failing the asserted `== 4`. `isOpen` is the test's declared subject. |
| 51 | Issue735PocketEnclosureTests.swift:211 | `enclosedPocketWithFloorBossIsStillEnclosed` | NOT-GAP | Base fixture's wall count is independently pinned at 4 elsewhere in this file; same mechanism as #50. |
| 52 | Issue735PocketEnclosureTests.swift:259 | `offCenterPocketIsEnclosed` | NOT-GAP | Same mechanism as #45. |
| 53 | Issue735PocketEnclosureTests.swift:307 | `filletedJunctionPocketIsDetected` | **GAP — FIXED** | A no-op `filleted(...)` leaves the sharp geometry unchanged, which the same test's own `prePockets` (and the identical box/tool used at #46) already proves reports `wallFaceIndices.count == 4`/`!isOpen` on its own. Fix: added a face-count-must-rise check (`filleted.faces().count > cut.faces().count`), matching the idiom `Issue762FilletedPocketDetectionTests.swift`'s `expectShapeChanged` already uses for the same fixture. |
| 54 | Issue747DetectHolesConvexClassifierTests.swift:46 | `blindHoleReportsExactlyOneHole` | NOT-GAP | Tool genuinely overlaps the box; a no-op cut leaves no cylindrical face, so `holes.count` reads 0, not 1, catching it directly. Radius/depth checks (keyword-invisible) add further verification. |
| 55 | Issue747DetectHolesConvexClassifierTests.swift:64 | `throughHoleReportsExactlyOneHole` | NOT-GAP | Same shape as #54; tool clearly spans the whole box. |
| 56 | Issue747DetectHolesConvexClassifierTests.swift:174 | `pipeInnerBoreIsAHoleOuterWallIsNot` | NOT-GAP | Per this file's own control (`standaloneCylinderIsNotAHole`), a solid cylinder reports 0 holes, contradicting the pinned 1 under a no-op. |
| 57 | Issue747DetectHolesConvexClassifierTests.swift:197 | `horizontalHoleIsDetected` | NOT-GAP | Same reasoning as #54: genuine geometric overlap, no-op cut gives 0 holes. |
| 58 | Issue762FilletedPocketDetectionTests.swift:58 | `sharpPocketIsDetectedAndEnclosed` | NOT-GAP | Sharp control, no fillet/chamfer risk applies; per this file's own `sharpBoxHasNoPockets` control, a plain box reports 0 pockets under a no-op `subtracting`. |
| 59 | Issue762FilletedPocketDetectionTests.swift:76 | `filletedJunctionPocketIsDetected` | NOT-GAP | Already calls `expectShapeChanged(cut, filleted, ...)` (face-count-must-rise) right before `detectPocketsAAG()`, exactly the check that catches a no-op fillet — this file's own docstring names #764 explicitly as the reason this helper exists. |
| 60 | Issue762FilletedPocketDetectionTests.swift:106 | `chamferedJunctionPocketIsDetected` | **GAP — FIXED** | The one fillet/chamfer test in this file missing the `expectShapeChanged` call every sibling fillet test has. Fix: added `expectShapeChanged(cut, chamfered, "chamfered on cut")` after the chamfer call, matching the file's own established idiom exactly. |
| 61 | Issue762FilletedPocketDetectionTests.swift:141 | `partiallyFilletedPocketIsDetected` | NOT-GAP | `expectShapeChanged` called before `detectPocketsAAG()`. |
| 62 | Issue762FilletedPocketDetectionTests.swift:209 | `sharpLShapedPocketReportsTwoOpenFloors` | NOT-GAP | Sharp control, no fillet. A no-op `union` (dropping the second tool box) yields a single rectangular pocket, not an L-shape, differing from the pinned count of 2 in a diagnostic way; a no-op `subtracting` yields 0. |
| 63 | Issue762FilletedPocketDetectionTests.swift:226 | `filletedReflexCornerPocketIsStillMeasured` | NOT-GAP | `expectShapeChanged` called after the fillet. |
| 64 | Issue762FilletedPocketDetectionTests.swift:289 | `deadEndSharpWallIsStillFoundThroughItsOwnJunction` | NOT-GAP | `expectShapeChanged` called after the fillet. |
| 65 | Issue762FilletedPocketDetectionTests.swift:365 | `verticalCornerBlendCylinderIsExcludedFromWalls` | NOT-GAP | Both fillet calls individually wrapped in `expectShapeChanged`; additionally a `surfaceType == .plane` check on every reported wall directly verifies the corner-blend cylinder wasn't mis-promoted. |
| 66 | Issue762FilletedPocketDetectionTests.swift:438 | `fullyRoundedPocketFindsExactlyFourWalls` | NOT-GAP | Same as #65: both fillet calls covered by `expectShapeChanged`, plus the `surfaceType == .plane` check. |
| 67 | Issue762FilletedPocketDetectionTests.swift:487 | `sharpThroughSlotIsNotEnclosed` | NOT-GAP | Sharp control, no fillet; tool genuinely spans past the box, no-op cut gives a plain box (0 pockets) per `sharpBoxHasNoPockets`. |
| 68 | Issue762FilletedPocketDetectionTests.swift:507 | `filletedThroughSlotIsNotEnclosed` | NOT-GAP | `expectShapeChanged` called after the fillet. |
| 69 | Issue762FilletedPocketDetectionTests.swift:545 | `sharpBossReportsOpenNotZero` | NOT-GAP | Sharp control, no fillet; a no-op `union` (dropping the boss) leaves a flat plate, which per `sharpBoxHasNoPockets`'s pattern reports 0 pockets, contradicting the pinned 1. |
| 70 | Issue762FilletedPocketDetectionTests.swift:563 | `filletedBossIsNeverFalselyEnclosed` | NOT-GAP | Two layers: a pre-fillet `baseEdges.count == 4` check already fails if `union` no-op'd, and `expectShapeChanged` catches a no-op fillet. The final loop deliberately has no count pin at all (both "absorbed" and "not reported" are valid outcomes). |
| 71 | Issue777PocketEnclosureCoveringEdgesTests.swift:38 | `squarePocket` | NOT-GAP | A no-op `subtracting` makes `detectPockets().first` nil, so `try #require` throws before either flagged count is reached; the fixture-helper is not itself an `@Test`. |
| 72 | Issue777PocketEnclosureCoveringEdgesTests.swift:76 | `edgeOfANonCoveringFaceIsNotAMember` | NOT-GAP | Real claim is a per-edge loop (`!covering.contains(edge)`), independent per-item verification the keyword scan can't see; upstream no-op risk caught the same way as #71. |
| 73 | Issue777PocketEnclosureCoveringEdgesTests.swift:159 | `multiFaceBoundaryEdgeDoesNotFakeAnEnclosure` | NOT-GAP | Flagged pins are fixture-validity checks (a no-op split/subtract changes them); the real subject (falsely reporting "enclosed") is asserted directly via `pocket.isOpen` per pocket. |
| 74 | Issue974QuiltSharedPathTests.swift:23 | `quiltProducesAShell` | NOT-GAP | The file's own comment explicitly reasons through this exact #703-style risk and states why the added assertion (a shell-count check that a no-op quilt would fail) exists. |
| 75 | OCCTModelingTests.swift:1075 | `detectPocket` | NOT-GAP | Already contains a real `resultVolume < boxVolume` fixture-validity assertion, literally the #703 fix, cited in the function's own comment; flagged only because of camelCase capitalization (`resultVolume` doesn't contain lowercase `"volume"`). |
| 76 | OCCTModelingTests.swift:1252 | `loftedEdgePolylines` | **GAP — FIXED** | `polylines.count >= 4` and `edgeCount > 0` are both satisfiable by a loft that silently used only the `bottom` profile (a flat 4-edge, 1-face cap). Fix: added `shape.subShapes(ofType: .face).count > 1`, which only a genuine multi-profile loft can satisfy. |
| 77 | OCCTModelingTests.swift:3188 | `splitSingleShell` | **GAP — FIXED** | `#expect(r.count >= 1)` had no upper bound: an over-fragmenting `splitShell()` defect (one piece per face) would satisfy it. Fix: tightened to `r.count == 1` (a single connected box shell has nothing to split) plus a per-piece face-count check. |
| 78 | OCCTModelingTests.swift:5319 | `modified` | **GAP — FIXED** | `#expect(mod.count >= 0)` is a tautology, a count is never negative, so it could never fail regardless of what `modified(from:)` returns. Fix: replaced with `faces.contains { builder.modified(from: $0).count > 0 }`, since at least one of the box's own faces must be touched by a real fillet. |
| 79 | Issue1058OuterBoundRefusalTests.swift:143 | `disconnectedEdgeWireIsRefused` | NOT-GAP | `wire.subShapes(ofType: .edge).count == 2` is itself the deliberately-added guard (already validated per `prove-the-test-fails.md`, per its own comment) proving the two disconnected edges were actually added, not the fixture-verification the census wants. The real subject follows immediately via `== nil`. |
| 80 | Issue442FixSolidMultiBodyTests.swift:319 | `documentedUnclosedCheck` | **GAP — FIXED** | `twoBoxes()` is already two valid, separate solids; every pinned count in the function is satisfiable by a pure pass-through (unlike its sibling `fixSolidMultiBody`, which additionally pins volume). Fix: added `expectVolume(healed, 2000.0, ...)`, matching the sibling's own idiom on the same fixture. |
| 81 | Issue443FirstOfNTests.swift:139 | `solidFromKeepsOpenBody` | NOT-GAP | Worked example from the task brief. `solid.solids.count == 2` AND `solid.subShapeCount(ofType: .face) == 11` cross-validate each other: a silent drop of either shell independently fails one count or the other. |
| 82 | Issue443FirstOfNTests.swift:342 | `solidWithHistoryQueryableForEveryBody` | NOT-GAP | Worked example from the task brief. `result.solids.count == 2` plus a real per-face loop (`!history.record(of: face).isDeleted` for every face of both input boxes) a no-op/drop would fail. |
| 83 | Issue443FirstOfNTests.swift:386 | `solidWithHistoryKeepsOpenBody` | NOT-GAP | Same dual-count cross-validation shape as #81, verified independently for this specific function's own body (`result.solids.count == 2` and `result.subShapeCount(ofType: .face) == 11`). |
| 84 | Issue484ConnectedFacesTests.swift:98 | `genuinelyDisconnectedFacesGetConnected` | NOT-GAP | Immediately followed by `connected.edgeCount == 7` (down from the fixture's proven 8), real, independent, keyword-invisible verification (the property is spelled `edgeCount`, not `.count`) that a no-op `connectedFaces()` would fail. |
| 85 | Issue484FaceFixContextTests.swift:22 | `periodicConicalFaceSurvivesFaceFix` | NOT-GAP | The #317/#484 defect this guards is an uncatchable SIGSEGV (null `Context()` deref): either the fix is present (no crash, valid face) or it isn't (guaranteed crash, failing the whole process). There is no silent-no-op middle ground for this exact code path. |
| 86 | Issue484FaceFixContextTests.swift:70 | `unhealedPeriodicConicalUVFaceSurvivesFaceFix` | NOT-GAP | Same mechanism as #85; the test's own comment states its scope is exactly "the call completes and returns a face", which IS what `faces().count == 1` measures. |
| 87 | Issue484FaceFixContextTests.swift:100 | `wellFormedBoxFacesUnaffected` | NOT-GAP | The test's own docstring states its guard is "already-well-formed faces come back unchanged", which IS the no-op — there is no wrong-but-identical-count scenario to distinguish it from. |
| 88 | Issue839SmallEdgeToleranceAlignmentTests.swift:43 | `defaultsAgreeOnBorderlineEdge` | **GAP — FIXED** | At this exact fixture (a 3e-7 edge), the correct answer at the aligned default is "not dropped" — indistinguishable from what a complete no-op (never drops anything, at ANY tolerance) would also produce. Fix: added a check that the same edge SHOULD be, and is, dropped at the old outlier 1e-6 tolerance, proving the drop path itself fires. |
| 89 | Issue999OuterBoundTests.swift:15 | `verdictVariesWithTheWire` | NOT-GAP | Flagged only because the English word "fixture" (in an `Issue.record` string) matches `fix*`, a pure false trigger. The two pinned counts (`filter{true}.count==1`, `filter{false}.count==1`) ARE the exact test that a constant-answer no-op (the #999 bug) would fail (would give 2/0, not 1/1). |
| 90 | OCCTSurfaceTests.swift:5944 | `coaxialDedup` | **GAP — FIXED** | Cylinder (r=5) and torus (major 10, minor 2, tube spans radius 8-12) never geometrically overlap, so `cyl.union(torus)` silently dropping the torus is plausible, and `axes.count` would still read 1 (the cylinder's own axis) — nothing proved the torus was actually present. Fix: added a volume-additivity check (`combinedVol == cylVol + torusVol`). |
| 91 | Issue1008WireFromEdgesTypeGuardTests.swift:89 | `theSupportedInputsStillWork` | NOT-GAP | This IS the "guard did not swallow the supported input" test, per its own `// MARK:` comment; the pinned counts directly detect the one plausible defect (guard accepts input but produces an empty/incomplete container). |
| 92 | Issue1088SelfIntersectsAnswerTests.swift:51 | `overlapFixtureActuallyOverlaps` | NOT-GAP | Its entire declared purpose, per its own doc comment, IS being the volume-based fixture verification for the whole suite; flagged only because locals are abbreviated (`va`/`vb`/`vf`) so the detector's literal-word scan misses them. |
| 93 | Issue211OuterShellTests.swift:57 | `innerShells` | NOT-GAP | An immediately-following bounding-box check (`abs((bb.max.x - bb.min.x) - 8.0) < 1e-3`) independently proves the returned shell is the correct 8-cube cavity, not e.g. the 20-cube outer shell mislabeled. Keyword-invisible only (no "extent"/"length" literally spelled). |
| 94 | Issue439OuterShellMultiSolidTests.swift:85 | `multiSolidInnerShellsEmpty` | NOT-GAP | Three cross-validating assertions: a per-solid cavity check proves the fixture's cavity is independently detectable, `comp.innerShells.isEmpty` is the actual #439-style regression guard, and a flat-map check proves the documented workaround still reaches the same cavity. |
| 95 | Issue439OuterShellMultiSolidTests.swift:102 | `outerShellsPerSolid` | NOT-GAP | Independent bounding-span checks (`spans[0].min.x == 0`, `spans[1].max.x == 30`) prove the two returned shells span the full compound, catching a duplicate/wrong-shell defect `count == 2` alone would miss. Keyword-invisible only. |
| 96 | Issue502SubShapeTraversalTests.swift:182 | `indexedAndArrayAccessMatch` | NOT-GAP | `shells.count == 2` is cross-checked via a per-index `isSame(as:)` equality loop and out-of-range boundary checks (`nil` at index `count`/`-1`); a silent drop of either shell independently fails the count, and a wrong-index mapping fails the equality loop. |
| 97 | Issue613IndexContractTests.swift:103 | `concaveEdgeIsTheConcaveEdge` | NOT-GAP | `concave.count == 1` is cross-validated by `concave.map(\.index) == [corner]`, an array-equality check against a geometrically-located edge, independent of the count; the historical #613 bug (an empty `concaveEdges()`) fails the count directly, an index-misalignment bug fails the array equality. |
| 98 | Issue614FaceOrientationTests.swift:120 | `sharedWallFacesOutOfBothSolids` | NOT-GAP | Multiple independent, real geometric checks follow the count-pins: a `Set` equality on orientations (`{.forward, .reversed}`, the exact thing #614 was about) and a per-solid dot-product test that the shared wall's normal points outward for EACH solid — a real boolean measurement, not a count. |
| 99 | OCCTTopologyTests.swift:1360 | `boxShells` | NOT-GAP | No risky producer operation is even present (a plain, unmodified `Shape.box()`); trigger is a false positive via the property names `shellCount`/`shells`. A box's shell count is a deterministic topological fact for an unaltered primitive, not the product of an operation that could no-op. |
| 100 | Issue1030DatumLookupGuardTests.swift:167 | `pointWithPlaneLocationStillReads` | NOT-GAP | Guards against over-refusal (a false-positive rejection of a valid datum); `datum != nil` and `datum?.name == "Datum1030"` independently confirm the SPECIFIC datum is readable and correctly named, not just that some count of 1 exists. The fixture-builder itself has no plausible silent-no-op path (`writeTriple`'s own failure bails the whole test via `guard...else return`). |

## Prove the test fails

Every one of the 11 fixes was verified per `okf/policies/prove-the-test-fails.md`: the operation (or
production code) under test was temporarily reverted to something that would produce the same pinned
count without doing the real work, the new assertion was confirmed to fail, then the change was
reverted and the test confirmed to pass again. Full transcripts of each injection/failure/restoration
cycle are in this PR's own session; summarized:

| # | Test | Injection | Result before revert |
|---|---|---|---|
| 25 | `externalEdgeExcluded` | Swapped `wires` for a hand-built 3-edge open wire (simulating an exclusion bug dropping one of the square's own edges, same count=1) | Both new assertions failed (`edges().count → 3 != 4`, `isClosed → false != true`); `wires.count == 1` stayed green |
| 37 | `holdsAcrossToolHeight` | Corrupted the reported `zLevel` in production code (`FeatureRecognition.swift`, `+5.0` offset) while leaving `wallIndices`/pocket count untouched | New `zLevel` check failed at all 3 heights; pre-existing `count == 1` stayed green |
| 39 | `pinnedSquarePocketFixtureUnaffected` | Dropped one wall from the reported `wallFaceIndices` in production code while leaving pocket count untouched | New `wallFaceIndices.count == 4` check failed at all 3 depths; pre-existing `count == 1` stayed green |
| 53 | `filletedJunctionPocketIsDetected` (735) | Simulated a no-op fillet (`let filleted = cut`) | New face-count-rise check failed (`11 > 11` false); the rest of the test would have coincidentally passed |
| 60 | `chamferedJunctionPocketIsDetected` | Simulated a no-op chamfer (`let chamfered = cut`) | `expectShapeChanged` failed (`11 > 11` false) |
| 76 | `loftedEdgePolylines` | Simulated a loft using only `bottom` (`Shape.face(from: bottom)`) | New face-count check failed (`1 > 1` false); pre-existing `polylines.count >= 4` stayed green |
| 77 | `splitSingleShell` | Simulated over-splitting (one `Shape` per box face) | Tightened `r.count == 1` failed (`6 != 1`); per-piece face-count check failed too |
| 78 | `modified` | Simulated `modified(from:)` always answering empty | New `anyModified` assertion failed cleanly (previously the tautology `mod.count >= 0` could never have caught this) |
| 80 | `documentedUnclosedCheck` | Simulated a corrupted (1.5×-scaled) result, preserving every topology count | New `expectVolume` check failed (`4750.0` delta); all topology-count assertions stayed green |
| 88 | `defaultsAgreeOnBorderlineEdge` | Simulated a drop path that never removes anything, at any tolerance | New old-default checks failed (`6 != 5`) at both `droppingSmallEdges` and `fixSmallEdges`; pre-existing aligned-default checks stayed green |
| 90 | `coaxialDedup` | Simulated a union that dropped the torus operand (`let combined = cyl`) | New volume-delta check failed (`789.57` delta, exactly the torus's own volume); `axes.count == 1` would have stayed green |

Six of the eleven (`holdsAcrossToolHeight`, `pinnedSquarePocketFixtureUnaffected`,
`filletedJunctionPocketIsDetected`/735, `chamferedJunctionPocketIsDetected`,
`documentedUnclosedCheck`, `coaxialDedup`) show the pre-existing pinned-count assertion staying
green while the new assertion alone catches the injected defect — direct, isolated proof the new
assertion adds real, independent detection the old one did not have.

## Census re-run

`python3 Scripts/census-unmeasured-values.py --tests` reported 100 before this PR and **98** after.
Not 89 (100 - 11): only 2 of the 11 fixes made a candidate drop off the list entirely
(`documentedUnclosedCheck`, whose new assertion calls the same-file `expectVolume` helper the
detector's `verifying_helpers()` mechanism already recognizes; `modified`, whose fix replaced the
only count-pin `#expect` in the function with a plain boolean, so the function no longer has a
`.count`-comparing `#expect` for the detector's `COUNT_PIN` regex to match at all). The other 9
fixes remain flagged, because the census's fixture-verification keyword scan only recognizes ten
specific nouns (`volume|area|length|mass|distance|delta|deviation|thickness|extent|overlap`) inside
an `#expect(...)`, and none of the added assertions happen to use one: `wallFaceIndices.count`,
`zLevel`, a face-count comparison, a wire's own `edges().count`/`isClosed`, and an old-tolerance
edge-count are all real, independent, working fixture verification, just not spelled with one of
those ten words. This is the exact "different counting property standing in as verification is
invisible too" blind spot the census's own module docstring documents (see
`Scripts/census-unmeasured-values.py`'s "WHAT THIS STILL CANNOT SEE" section), and it is confirmed
directly above, per fix, by the prove-the-test-fails table: each of the 9 still-flagged fixes was
independently shown to catch its targeted defect.
