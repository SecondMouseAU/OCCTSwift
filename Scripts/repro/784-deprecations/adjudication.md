# #784 deprecation adjudication

One row per `@available(*, deprecated, ...)` symbol in `Sources/OCCTSwift`, plus the one
`__attribute__((deprecated))` bridge symbol, as they stood on `origin/refactor/381-pass1b` at the
point this branch (`chore/784-deprecation-adjudication`) forked from it. The count was re-derived
rather than trusted from the issue text:

```
grep -rn '@available(\*, deprecated' Sources/OCCTSwift/ | wc -l   # 61
grep -rn '__attribute__((deprecated' Sources/OCCTBridge/           # 1 (OCCTFacesAreAdjacent)
```

Both match the issue's count exactly — nothing landed on the base branch between the count being
taken and this branch forking from it.

## Method

For each symbol: read its full declaration, doc comment and deprecation message; identify the
named replacement; confirm the replacement exists and is used correctly; search
`Sources/OCCTSwift`, `Sources/OCCTBridge`, `Tests/` and `Scripts/repro/censuses/` for callers
(`swift build --build-tests`'s own deprecation warnings gave the authoritative list of Sources/Tests
callers in one pass — zero warnings landed in `Sources/`, confirming zero internal production
callers for all 61 Swift symbols before any edits were made); and determined whether the *old* name
had ever shipped in a tagged release, by locating each symbol's introducing issue number in
`docs/CHANGELOG.md` and checking whether it falls under the `## Unreleased` section (this branch,
never shipped) or a versioned `### vX.Y.Z` heading (a real release).

**Verdict key**

1. **Remove.** Implemented in this PR.
2. **Keep deprecated**, with a removal version.
3. **Un-deprecate.** The replacement is worse or the deprecation was a mistake.

## Verdict-3 investigation (the bridge symbol)

`OCCTFacesAreAdjacent` is the case CLAUDE.md flags by name: PR #779 nearly deprecated it into
`OCCTFaceGetSharedEdgeSummary(...) > 0`, a replacement that costs a full walk of the face pair
where the original stopped at the first shared edge — exactly the shape of regression this task
asked to look for. Investigated directly rather than assumed clear:

- `AAG.buildGraph()` was `OCCTFacesAreAdjacent`'s *only* Swift caller, and it no longer calls it:
  since #783 it calls `OCCTFaceGetSharedEdgeSummary` directly, because it always needed the count
  and the first edge (for convexity) anyway — the "full walk" cost was already being paid by that
  caller before the deprecation, not newly imposed by it.
- Grep confirms zero remaining callers anywhere: not in `Sources/OCCTSwift` (one comment
  mentioning it by name, no call), not in `Sources/OCCTBridge` (only the definition itself and two
  historical comments), not in any test (three test files name it in doc comments describing the
  #761/#642/#699 investigations, none call it).
- No caller wanting *pure* adjacency without the count exists today, so the message's own caveat
  ("for a caller who genuinely wants only adjacency ... say so on #783 before this is removed")
  was never triggered.

Given zero callers and a real, adequate, already-adopted replacement, this is a genuine orphan, not
a worse-replacement case — the #779 near-miss was caught and fixed (by changing the caller, not by
keeping the old function), and nothing here reopens it. Verdict: Remove, following the `OCCTBridge`
orphan precedent #506/#651 already established in this repo (`OCCTBridge` is a build target, not an
SPM product — `useBridgePrebuilt` on this branch is hard-coded `false`, and even where the
prebuilt is used it is an internal build-speed convenience with no external consumer, so there is no
ABI to hold stable). `OCCTBRepGraphGeneration`, the bridge function backing `BRepGraph.generation`
(row 5 below), became a second orphan as a direct consequence of that removal and was deleted under
the same precedent in the same PR.

No other deprecation message names a replacement whose cost or correctness is worse than the
original on inspection — see the per-row evidence below. All are either pure label/rename
forwarders (no behavior change at all), or fix a measured defect in the old spelling (wrong value,
wrong tolerance, wrong geometry) with the new one measured correct. None were kept deprecated or
un-deprecated on that basis.

## Release status

Whether the *old* name had ever shipped, found by locating its issue number's entry in
`docs/CHANGELOG.md` and checking which side of the `## Unreleased` / `### v1.17.0` boundary
(line 16 vs line 6235 at the time of reading) it falls on:

| Symbols | Introduced | Shipped? |
|---|---|---|
| `BRepGraph.GraphUID/GraphRefUID/GraphItemUID.init(...)`, `.generation`, `TopologyGraph` | #295/#303/#333 | v1.12.0 – v1.15.0 (real releases, weeks old) |
| `ThreadBuild.boolean` | #254 | v1.8.1 (real release, over a month old) |
| `Shape.union(with:)` / `.intersection(with:)` / `.section(with:)` | #68 | ~v0.140s (real release, months old) |
| `Continuity.swift`'s 9 (SurfaceContinuity.c0/c1/c2, FillingContinuity, PlateConstraintOrder, GeometricContinuity, ApproxContinuity, Shape.BSplineContinuity, Curve3D.ContinuityOrder) | #398 | v1.17.0 (real release) |
| Every other row (42 Swift symbols + the bridge one) | #486/#490/#495/#498/#499/#503/#505/#536/#562/#651/#485, #783 | **Unreleased** — added and deprecated within this same branch's own refactor work, never in a tagged release |

The unreleased ones carry no external compatibility obligation at all: no consumer has ever seen a
release with the old name, so removing them is not a break any real caller experiences — it is
finishing a rename that was mid-flight when the branch's own tests were the only caller. That is
also why so many of the "Remove" verdicts below are not close calls: the deprecation shim's whole
job was to keep the branch's *own* long-lived history compiling across an in-progress rename, and
that job is done once the branch reaches `main`.

## The table

| # | File | Symbol | Deprecation says | Verdict | Evidence |
|---|---|---|---|---|---|
| 1 | BRepGraph.swift | `GraphUID.init(kind:counter:)` | renamed → `BRepGraph.uid(ofNodeKind:index:)` (graphID 0, resolves nowhere) | **Remove** | v1.12.0, released. Zero callers: the only test uses (`OCCTBRepGraphTests.swift`) call the internal 3-arg `init(kind:counter:graphID:)` via `@testable import`, not this public 2-arg one. |
| 2 | BRepGraph.swift | `GraphRefUID.init(kind:counter:)` | same shape as #1 | **Remove** | Same evidence as #1. |
| 3 | BRepGraph.swift | `GraphItemUID.init(domain:kind:counter:)` | same shape as #1 | **Remove** | Same evidence as #1. |
| 4 | BRepGraph.swift | `generation` | "Always 1" — OCCTSwift clears a graph once at build and never rebuilds; use `instanceID` | **Remove** | v1.12.0, released. One dedicated test, `generationIsAlwaysOne` (self-marked `@available(*, deprecated, message: "Exercises the deprecated generation on purpose.")`), deleted with the property. Its own bridge function `OCCTBRepGraphGeneration` was now orphaned (zero Swift callers) and removed too, per the #506/#651 orphan precedent. |
| 5 | BRepGraph.swift | `TopologyGraph` (typealias) | renamed → `BRepGraph` | **Remove** | v1.15.0, released (over 3 weeks old). Zero references anywhere in `Tests/`, `Scripts/`, or `Sources/` outside the typealias declaration itself. |
| 6 | Conic2D.swift | `fromCircle(center:direction:radius:)` | renamed → `circle(center:direction:radius:)` | **Remove** | Unreleased (#487). Zero callers anywhere. |
| 7 | Conic2D.swift | `fromLine(point:direction:)` | renamed → `line(point:direction:)` | **Remove** | Unreleased (#487). Zero callers anywhere. |
| 8 | Conic2D.swift | `fromEllipse(center:direction:majorRadius:minorRadius:)` | renamed → `ellipse(center:direction:majorRadius:minorRadius:)` | **Remove** | Unreleased (#487). Zero callers anywhere. The shared `.degenerate` fallback constant these three alone used was removed with them. |
| 9 | Curve3D.swift | `ContinuityAnalysis.status` | renamed → `order` (named as though it reported a measurement; never did) | **Remove** | Unreleased (#485). Zero callers found (build produced zero deprecation warnings for it; targeted grep for `.status` in Curve/Surface test files found only an unrelated `PipeShellBuilder.status`). |
| 10 | Curve3D.swift | `continuityWith(_:u1:u2:order: Int)` | message: pass a `ContinuityClass`, not a raw `GeomAbs_Shape` ordinal | **Remove** | Unreleased (#485/#490). Dedicated test `Issue495AnalysisOrderTests.deprecatedIntOverloadAgrees` deleted. Every other call site in `Tests/` already uses the typed `ContinuityClass` overload (verified: `Issue490ContinuityDecoderTests`, `OCCTCurveTests`, `Issue495AnalysisOrderTests` all pass `.c0`/`.g1`/`.c1`/`.g2`/`.c2`, never a bare `Int`). |
| 11 | Curve3D.swift | `closestParameter(to:)` | message: no `Double` can signal failure; used to return `0`, outside a trimmed curve's own domain; use `nearestParameter(to:)` | **Remove** | Unreleased (#500). Part of `Issue500Curve3DNearestParameterTests.deprecatedSpellingsAgree`, deleted (the file's other, non-deprecated tests of `nearestParameter(to:)`/`projectPoint(_:)` are untouched). |
| 12 | Curve3D.swift | `gridEvalD0(params:)` | renamed → `evaluateGrid(_:)` | **Remove** | Unreleased (#486). Dedicated suite `GridEvalCurve3DTests` (both tests self-marked) deleted; `Issue486Curve3DBatchTests`'s two comparison tests (`d0/d1SpellingsAgree`) deleted, its one non-deprecated test (`emptyParametersGiveEmptyResult`) kept; `batchD0` (Curve3DEvalTests) deleted, its siblings kept. |
| 13 | Curve3D.swift | `gridEvalD1(params:)` | message: use `evaluateGridD1(_:)`; labels the derivative `tangent`, not `d1` | **Remove** | Same evidence as #12. |
| 14 | Curve3D.swift | `evalBatchD0(params:)` | renamed → `evaluateGrid(_:)` | **Remove** | Same evidence as #12 (`batchD0`/`batchD1` in `Curve3DEvalTests`). |
| 15 | Curve3D.swift | `evalBatchD1(params:)` | message: use `evaluateGridD1(_:)` | **Remove** | Same evidence as #12. |
| 16 | Curve3D.swift | `parameterAtPoint(_:)` | message: used to return `firstParameter`, right or maximally wrong depending only on which end the point fell off; use `nearestParameter(to:)` | **Remove** | Unreleased (#500). Same test as #11. |
| 17 | Curve3D.swift | `localCurvature(at:)` | renamed → `curvature(at:)` (since #494 gave the two the same resolution, byte-identical call) | **Remove** | Unreleased (#595). Dedicated test `deprecatedLocalCurvatureForwards` (`OCCTAnalysisTests.swift`) deleted. |
| 18 | Continuity.swift | `SurfaceContinuity.c0` (static var) | renamed → `g0` | **Remove** | v1.17.0, released (#398). Sole test use (`Issue398ContinuityTests.retiredSpellingsStillResolve`, self-marked) deleted; the file's other tests (raw-value pins, type-distinctness, `.g2`-rejection) are untouched. |
| 19 | Continuity.swift | `SurfaceContinuity.c1` | renamed → `g1` | **Remove** | Same evidence as #18. |
| 20 | Continuity.swift | `SurfaceContinuity.c2` | renamed → `g2` | **Remove** | Same evidence as #18. |
| 21 | Continuity.swift | `FillingContinuity` (typealias) | renamed → `SurfaceContinuity` | **Remove** | Same evidence as #18. |
| 22 | Continuity.swift | `PlateConstraintOrder` (typealias) | renamed → `SurfaceContinuity` | **Remove** | Same evidence as #18. |
| 23 | Continuity.swift | `GeometricContinuity` (typealias) | renamed → `ParametricContinuity` | **Remove** | Same evidence as #18. |
| 24 | Continuity.swift | `ApproxContinuity` (typealias) | renamed → `ParametricContinuity` | **Remove** | Same evidence as #18. |
| 25 | Continuity.swift | `Shape.BSplineContinuity` (typealias) | renamed → `ParametricContinuity` | **Remove** | Same evidence as #18. |
| 26 | Continuity.swift | `Curve3D.ContinuityOrder` (typealias) | renamed → `ParametricContinuity` (old enum capped at `.c2`, made every order a no-op) | **Remove** | Same evidence as #18. Distinct from `Curve3D.continuityOrder` (lowercase instance property), already `@available(*, unavailable)` since #619 and out of this issue's scope. |
| 27 | Curve2D.swift | `approximated(first:last:toleranceU:toleranceV:maxDegree:maxSegments:)` | renamed → `approximatedInRange(...)` | **Remove** | Unreleased (#407). Dedicated test `deprecatedShimForwardsToApproximatedInRange` deleted; the unrelated, still-live `approximated(tolerance:continuity:maxSegments:maxDegree:)` overload (different labels, different OCCT algorithm) is untouched and still called with defaults elsewhere in the same file. |
| 28 | Curve2D.swift | `bsplineKnotSplits(continuity:)` | message: use `splitIndicesAtDiscontinuities(continuity:)?.count` | **Remove** | Unreleased (#562). Dedicated tests in `Issue480Curve2DKnotSplitContinuityTests` and `Issue562Curve2DKnotSplitDuplicateTests` deleted (each file's other, non-deprecated tests of `splitIndicesAtDiscontinuities` kept). |
| 29 | Curve2D.swift | `bsplineKnotSplitValues(continuity:)` | message: use `splitIndicesAtDiscontinuities(continuity:)`, returns `[Int]`/`nil` not `[Int32]`/`[]` | **Remove** | Same evidence as #28. |
| 30 | Curve2D.swift | `gridEvalD0(params:)` | renamed → `evaluateGrid(_:)` | **Remove** | Unreleased (#486). Dedicated suite `GridEvalCurve2DTests` deleted; `Issue486Curve2DBatchTests`'s two comparison tests deleted, `emptyParametersGiveEmptyResult` kept; `batchD0`/`batchD1` (`Curve2DEvalTests`) deleted, siblings kept. |
| 31 | Curve2D.swift | `gridEvalD1(params:)` | message: use `evaluateGridD1(_:)`, labels the derivative `tangent` | **Remove** | Same evidence as #30. |
| 32 | Curve2D.swift | `evalBatchD0(params:)` | renamed → `evaluateGrid(_:)` | **Remove** | Same evidence as #30. |
| 33 | Curve2D.swift | `evalBatchD1(params:)` | message: use `evaluateGridD1(_:)` | **Remove** | Same evidence as #30. |
| 34 | Curve2D.swift | `parameterAtPoint(_:)` | message: used to return `firstParameter`; use `nearestParameter(to:)` | **Remove** | Unreleased (#413/#500). Dedicated test `deprecatedScalarSpellingAgrees` (`Curve2DProjectionParityTests`) deleted; the suite's five other, non-deprecated projection-parity tests kept. |
| 35 | FilletBuilder.swift | `getBounds(contour:edge: Shape)` | message: pass the `Edge` itself; convert with `Edge(_:)` | **Remove** | Unreleased (#505). Only one of ~30 call sites in `Issue505FilletBuilderEdgeTypeTests.swift` used the `Shape`-typed overload (`deprecatedShapeSpellingsAgree`, self-marked) — every other call in that file and in `OCCTModelingTests.swift` already passes a real `Edge`. That one test deleted; the rest untouched. |
| 36 | FilletBuilder.swift | `getLaw(contour:edge: Shape)` | same reason as #35 | **Remove** | Same evidence as #35. |
| 37 | OSDPath.swift | `PathParser.trek(_:)` | renamed → `OSDPath.folder(_:)` (keeps trailing separator, non-empty for extension-less paths) | **Remove** | Unreleased (#499). Whole `PathParser` enum deleted. `PathParsingContractTests.swift` kept the pure-`OSDPath` coverage (dropped the `PathParser`-vs-`OSDPath` comparison half, trimmed `nonASCIIPathSurvivesParsing` to its `OSDPath`-only assertions since `OSDPath` never had that defect); `Tests/OCCTXCAFTests/OCCTXCAFTests.swift`'s `TDocStdPathParserTests` suite (3 tests, all `PathParser`-only) deleted outright. |
| 38 | OSDPath.swift | `PathParser.name(_:)` | renamed → `OSDPath.name(_:)` | **Remove** | Same evidence as #37. |
| 39 | OSDPath.swift | `PathParser.fileExtension(_:)` | renamed → `OSDPath.fileExtension(_:)` (leading dot) | **Remove** | Same evidence as #37. |
| 40 | Shape+Topology.swift | `continuityOfFaces(edge:face1:face2:tolerance:)` | renamed → `continuityClassOfFaces(...)` (doc comment claimed `5=CN`, wrong: CN is 6, 5/C3 unreachable) | **Remove** | Unreleased (#495). Dedicated test `deprecatedIntSpellingAgrees` deleted; the rest of `Issue495FaceContinuityTests.swift` untouched. |
| 41 | Shape+Topology.swift | `buildCurves3dAll(tolerance:)` | renamed → `buildCurves3d(tolerance:)` (second wrapper over a byte-identical C entry point, defaults had drifted 100x) | **Remove** | Unreleased (#498). Dedicated tests deleted from `BuildCurves3dTests.swift` (`deprecatedForwarderAgrees`) and `OCCTTopologyTests.swift` (`buildCurves3dAllDeprecatedSpelling`); each file's other tests of `buildCurves3d` kept. |
| 42 | Shape+Topology.swift | `nbEdges` | renamed → `edgeCount` (counted `TopExp_Explorer` occurrences — 24 on a 12-edge box — against docs that always described 12) | **Remove** | Unreleased (#651). Dedicated file `Issue651DeprecatedCounterTests.swift` (its whole purpose, per its own closing comment, is measuring this forwarding contract) deleted outright; dedicated test `shapeSubShapeCounts` (`OCCTTopologyTests.swift`) deleted. The census row in `Scripts/repro/censuses/ClusterA.swift` was dropped per its own committed comment: *"When the deprecation cycle removes the three properties this stops compiling, which is the right prompt to drop these rows."* `ShapeContentsExtended.nbEdges`/`nbFaces`/`nbVertices` (a different type, `ShapeAnalysis_ShapeContents`-backed) are unaffected — confirmed by reading each call site, not by name alone. |
| 43 | Shape+Topology.swift | `nbFaces` | renamed → `faceCount` | **Remove** | Same evidence as #42. |
| 44 | Shape+Topology.swift | `nbVertices` | renamed → `vertexCount` | **Remove** | Same evidence as #42. |
| 45 | Shape+Modeling.swift | `pipeShellWithTransition(...)` | renamed → `pipeShell(spine:profile:mode:transition:withContact:withCorrection:solid:)` (old spelling silently swept `.fixed`/`.auxiliary` as Frenet — a wrong-geometry bug, not merely a naming duplicate) | **Remove** | Unreleased (#503). Dedicated tests deleted from `Issue503PipeShellTests.swift` and `OCCTSurfaceTests.swift`; each file's non-deprecated `pipeShell` tests kept. |
| 46 | Shape+Modeling.swift | `section(with other: Shape)` | renamed → `section(_:)` | **Remove** | Real release, ~v0.140s (#68). The array-taking `section(with tools: [Shape])` and the tolerance-taking `section(with other: Shape, tolerance: Double)` overloads are distinct, non-deprecated methods sharing the `with:` label — confirmed by signature before touching any call site, and every call site fixed was verified single-`Shape`, no-tolerance before editing. |
| 47 | Shape+Modeling.swift | `removeFeatures(faces:)` | renamed → `defeature(faces:)` (measured byte-for-byte identical, `Scripts/repro/536-defeature-removefeatures-unify/`) | **Remove** | Unreleased (#536). Dedicated file `Issue536DefeaturingSpellingsTests.swift` (every test in it is a `removeFeatures`-vs-`defeature` parity check) deleted outright; `Issue578DefeatureFaceMembershipTests` (mentioned by name in that file's own doc comment as covering the surviving membership contract separately) is untouched. |
| 48 | Shape+Modeling.swift | `defeature(faces:tolerance:)` | message: `tolerance` is ignored — `BRepAlgoAPI_Defeaturing` has no fuzzy value | **Remove** | Unreleased. Dedicated test `toleranceIsInert` (`Issue497DefeaturingTests.swift`) deleted; the file's precondition tests (out-of-range index, etc.) kept. |
| 49 | Shape.swift | `union(with other: Shape)` | renamed → `union(_:)` (match `subtracting(_:)`/`Set.union(_:)`) | **Remove** | Real release, ~v0.140s (#68). ~45 test call sites across 10 files mechanically ported (`.union(with: x)` → `.union(x)`); verified against `Mesh.union(with:deflection:)`, a distinct non-deprecated method sharing the label, which was *not* touched (two accidentally-touched sites in `OCCTMeshTests.swift` were caught by the resulting compile error and reverted). |
| 50 | Shape.swift | `intersection(with other: Shape)` | renamed → `intersection(_:)` | **Remove** | Same evidence as #49, plus `Face.intersection(with other: Face, tolerance:)` and `Mesh.intersection(with:deflection:)`, two more distinct non-deprecated methods sharing the label — both confirmed untouched (two accidentally-touched `Face` sites in `OCCTAnalysisTests.swift` were caught by the resulting compile error and reverted). |
| 51 | Shape+ShapeHealing.swift | `dividedByContinuity(criterion:tolerance:)` | renamed → `divided(at:tolerance:)` (old one set only the boundary criterion; the survivor sets boundary+pcurve+surface together, the usage OCCT's own guide demonstrates) | **Remove** | Unreleased (#438). Dedicated tests deleted from `Issue438DivideContinuityUnificationTests.swift` (its two non-deprecated `divided(at:)`-only tests kept) and the whole `ShapeUpgradeDivideContinuityTests` suite (`OCCTShapeHealingTests.swift`, self-contained, deleted). Census row in `ClusterD.swift` dropped, following the same pattern `ClusterA.swift` set for #42. |
| 52 | Shape+ShapeHealing.swift | `bsplineRestrictionAdvanced(..., continuity3d: Int, continuity2d: Int, ...)` | message: pass a `ParametricContinuity`, not a raw int (four of seven values used to fail the whole call under the old `GeomAbs_Shape`-ordinal reading) | **Remove** | Unreleased (#490). Zero test callers of the Int-typed overload found: every call site in `Issue490ContinuityDecoderTests.swift`, `Issue570HealingApproxTests.swift`, `OCCTShapeHealingTests.swift` and `ClusterD.swift` either omits `continuity3d`/`continuity2d` (falls through to the typed overload's defaults) or passes a `ParametricContinuity` literal explicitly — confirmed by reading each call site's actual arguments, not by name. |
| 53 | ThreadFeatures.swift | `ThreadBuild.boolean` (case) | message: use `.auto`/`.direct` — no longer differs for buildable threads, forced cut path is faceted/unreliable | **Remove** | v1.8.1, released (over a month old, #254). Verified the claim directly rather than trusting the message: `threadedShaft`'s `build:` parameter is accepted but never read anywhere in the function body — every mode already takes the identical code path. Dedicated file `Issue254BuildModesTests.swift` (its entire purpose is proving `.boolean` matches `.direct`) deleted outright. |
| 54 | Surface.swift | `Continuity` (typealias, nested) | renamed → `ContinuityClass` | **Remove** | Unreleased (#485). Dedicated test `surfaceContinuityAliasStillResolves` (`Issue485SurfaceContinuityTests.swift`) deleted; the file's other `ContinuityClass` tests kept. |
| 55 | Surface.swift | `ContinuityAnalysis.status` | renamed → `order` | **Remove** | Unreleased (#485). Zero callers found (same check as #9). |
| 56 | Surface.swift | `continuityWith(_:u1:v1:u2:v2:order: Int)` | message: pass a `ContinuityClass` | **Remove** | Unreleased (#485/#490). Every `Surface.continuityWith` call site in `Tests/` (`Issue495AnalysisOrderTests.swift`, `OCCTSurfaceTests.swift`) already uses `ContinuityClass` literals (`.c1`, `.g1`); no Int-typed call found. |
| 57 | Surface.swift | `bsplineKnotSplitsU(continuity:)` | message: use `knotSplitting(uContinuity:vContinuity:).uSplitCount`, one analyzer call instead of three | **Remove** | Unreleased (#562). Dedicated test `deprecatedTrioForwards` (`Issue562SurfaceKnotSplitDuplicateTests.swift`) deleted; `nonBSplineSurface` trimmed to keep its non-deprecated `knotSplitting()` half. |
| 58 | Surface.swift | `bsplineKnotSplitsV(continuity:)` | same reason as #57 | **Remove** | Same evidence as #57. |
| 59 | Surface.swift | `bsplineKnotSplitValues(continuity:)` | message: use `knotSplitting(uContinuity:vContinuity:)`, which also gives the resolved parameters | **Remove** | Same evidence as #57. |
| 60 | Surface.swift | `gridEvalD0(uParams:vParams:)` | message: use `evaluateGrid(uParameters:vParameters:)`, returns `SurfaceGrid` not a flat array of unstated major order | **Remove** | Unreleased (#486). Dedicated suite `GridEvalSurfaceTests` (both tests self-marked) deleted; `deprecatedFlatSpellingsAreUMajor` (`Issue486SurfaceGridTests`) deleted, that suite's other tests of `evaluateGrid`/`evaluateGridD1` kept; `pipeCorrectedFrenetTransition` handled separately (see #45, same file). |
| 61 | Surface.swift | `gridEvalD1(uParams:vParams:)` | same reason as #60 | **Remove** | Same evidence as #60. |
| 62 | OCCTBridge_BRepGraph.h/.mm | `OCCTFacesAreAdjacent` (bridge, `__attribute__((deprecated))`) | message: use `OCCTFaceGetSharedEdgeSummary(shape, face1, face2, NULL) > 0` | **Remove** | Unreleased (#783, landed on this branch yesterday). See the dedicated verdict-3 investigation above — zero callers, adequate replacement already adopted by its one caller, orphan precedent #506/#651 applies. |

## Internal callers found

**None**, in `Sources/OCCTSwift` or `Sources/OCCTBridge`, for any of the 61 Swift symbols or the one
bridge symbol, before this PR's edits. This was measured, not assumed: `swift build --build-tests`
against the unmodified tree produced 45 deprecation warnings, and every one of them was in `Tests/`
or `Scripts/repro/censuses/` — zero in `Sources/`. That is the strongest form of evidence this task
asked for ("a deprecated symbol still called from inside `Sources/OCCTSwift` is a signal the
replacement is not adequate") reporting a clean result across the board: nothing here needed
routing, because nothing in production code was still calling the old spelling.

## What was NOT found: no verdict-2 or verdict-3 cases among the 61 Swift symbols

Every one of the 61 Swift deprecations is either (a) a pure syntactic forward — same bridge call,
same arguments, cosmetic rename or label change only — or (b) a fix for a measured defect in the
old spelling (wrong value, wrong tolerance, wrong geometry, silently swallowed a caller's request),
where the new spelling is strictly more correct and the old one is not something a caller could
prefer. Read every deprecation message for a claim the new spelling costs more (time, precision,
capability) than the old one, and found exactly one candidate — the bridge-side
`OCCTFacesAreAdjacent`, addressed above — which resolved to Remove once measured rather than to
Keep or Un-deprecate, because the caller that would have paid the claimed cost no longer exists.

No symbol was kept deprecated: every one either had zero internal callers (safe to remove
outright) or callers confined to tests whose sole purpose was proving the deprecated forwarding
contract itself (deleted along with the symbol, since that contract no longer exists to prove).
