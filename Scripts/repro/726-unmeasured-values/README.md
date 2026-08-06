# OCCTSwift#726, first pass: values that were never computed but are returned as if measured

Census only. No source under `Sources/` or `Tests/` is touched by this pass, since five other PRs
are in flight against `refactor/381-pass1b` that do, and this pass's whole output is a measured
list for those to draw from, not a diff. The detector is
[`Scripts/census-unmeasured-values.py`](../../census-unmeasured-values.py); this file records what
running it against `refactor/381-pass1b` (`d2ae082`) actually found, and the per-site verdict for
every candidate, because #726 itself lists five prior censuses in this exact family that reported a
number nobody had measured: #558 said 14, measured 28; #571 said 3, measured 6; #583 said five,
measured six; #595 said six, measured nine; #640 said 13, measured 20.

## Measured counts

Sub-kind 2's raw count moved mid-pass, and both numbers matter: **68 is what the detector found
before its own blind spot was found and fixed; 47 is what it finds now.** See "A mid-pass fix"
below the sub-kind 2 table for the mechanism and the guard-removal proof.

```
sub-kind 1 (production): 64 candidate(s)
sub-kind 2 (tests): 47 candidate(s)   (68 before the mid-pass verifying_helpers() fix)
```

Of those 111 current raw candidates, adjudicated by hand below:

| | count | meaning |
|---|---|---|
| **Confirmed real instances (sub-kind 1)** | **2** (3 sites) | `selfIntersectionCount` (the known seed), plus a new pair, `errorReached`/`absoluteError` in `OCCTBRepGPropVinertGK` |
| Known-good "absence made representable" pattern | 7 | already fixed, per the #583/#595/#609 idiom; controls, not findings |
| Legitimate default-then-flip status/success flag | 26 | `isValid`/`success`/`isSet` etc., toggles across real control flow |
| Legitimate branch-selected classification tag | 2 | `type`/`kind`, a different literal per branch, not a fabrication |
| Structural default for an alpha-less color quantity | 2 | `Quantity_Color`/glTF `EmissiveFactor` have no alpha; `1.0` is a domain fact |
| Out of scope: local config/options struct, not a returned result | 5 | syntactically identical shape, semantically a different thing |
| Out of scope: plain value-type constructor, not a measurement API | 19 | echoes its own parameters; nothing was "skipped" |
| **Confirmed real instances (sub-kind 2)** | **11** | needs a follow-up issue each; see the per-file table below |
| Sub-kind 2: low-risk (deterministic/inspectable fixture) | 31 | construction makes the geometric relationship verifiable by reading the test |
| Sub-kind 2: already verified, script still can't see it | 5 | an abbreviated identifier or a different counting property defeats the keyword scan; found by reading the site |

## Known-positive and known-negative controls

Required by the task brief: at least one independently-confirmed real instance the detector must
catch, and at least one literal that is genuinely correct that it must not flag.

**Known positive (sub-kind 1), independently confirmed before the detector ran:**
`Sources/OCCTBridge/src/OCCTBridge_Healing.mm:248`, `OCCTShapeAnalyze`:
`result.selfIntersectionCount = 0;  // Would require more expensive computation`. This is #726's
own seed instance, already documented in `Sources/OCCTBridge/include/OCCTBridge_Healing.h:26` and
`Sources/OCCTSwift/ShapeAnalysisResult.swift:17`. The detector reports it.

**Known positive (sub-kind 2), independently confirmed by reading PR #720 (open against this same
base, not yet merged) before the detector ran:** `Tests/OCCTModelingTests/OCCTModelingTests.swift`,
`detectPocket()` (in `struct AAGTests`). The pre-#720 fixture places a pocket tool box at
`origin: SIMD3(5, 5, 10)` against a `Shape.box(width: 20, height: 20, depth: 20)`. `Shape.box`
centres its box, so the outer box spans -10...10 on every axis and the tool's z-range (10...25)
never overlaps it at all. `#expect(pockets.count >= 1)` passed anyway, for the wrong reason: the
same `OCCTEdgeGetConvexity` face1/face2 order-dependence #703 fixed made even a **plain, uncut**
box falsely report a pocket. PR #720's own fix adds exactly the missing check:
`#expect((result.volume ?? 0) < (box.volume ?? 0), "pocket tool must actually remove material, or
this fixture proves nothing")`. Nothing in the pre-#720 test checked that. The detector reports it.

**Known negative #1 (a real computation that happens to be zero, not a placeholder):**
`OCCTCurve3DCircleEccentricity` (`OCCTBridge_Curve3D.mm:3442`):
```cpp
double OCCTCurve3DCircleEccentricity(OCCTCurve3DRef curve) {
    if (!curve) return 0;
    try {
        Handle(Geom_Circle) c = Handle(Geom_Circle)::DownCast(curve->curve);
        if (c.IsNull()) return 0;
        return c->Eccentricity();   // the success path is a REAL OCCT call
    } catch (...) { return 0; }
}
```
A circle's eccentricity genuinely is `0`; the value comes from `Geom_Circle::Eccentricity()`, not a
literal. This function is outside the detector's own shape entirely (a scalar return, not a
`var.field =` aggregate), so it does not appear in the candidate list at all, which is itself the
correct answer for this site, confirmed here by inspection rather than reported as a `0/N`
result the detector cannot produce for something it structurally cannot see.

**Known negative #2, inside the detector's actual shape (a literal correctly gating a real
absence, the #583/#595/#609 idiom the detector's own candidates get adjudicated against):**
`OCCTShapeRevolutionAxes`/`OCCTShapeSymmetryAxes` (`OCCTBridge_Topology.mm:653`, `:694`):
`a.extentMin = 0; a.extentMax = 0; a.hasExtent = false;` sits beside real computed fields
(`a.originX = p.X(); ...`) in the same `for` loop, and the detector DOES flag it (correctly, per
its own stated shape: a literal beside a same-depth computed sibling). The adjudication is what
says it is not a bug: `Sources/OCCTSwift/ShapeAxis.swift:34` reads
`self.extent = a.hasExtent ? (a.extentMin...a.extentMax) : nil`, so absence is already
representable as `nil`, which is the fix this whole issue family (#583/#595/#609) established as
correct. The detector gets this one right in the only sense a structural, non-semantic detector
can: it produces the candidate for a human to look at, and does not silently drop it either.

## Guard-removal matrix

Per `okf/policies/prove-the-test-fails.md`: a `--self-test` proves nothing by existing. Each of the
7 structural mechanisms below was deleted from a working copy of the script in turn, the
`--self-test` suite re-run, and the case count confirmed to drop, then the file was restored from
an untouched backup and `diff`'d byte-identical before moving to the next one. All fixtures pass
before every experiment and after every restore; only the experiment column differs. Mechanism 7
was added mid-pass, after the first real run's 68 sub-kind-2 candidates were being read by hand and
turned out to include a systematic false-positive family (see "A mid-pass fix" below); mechanisms
1-6 were proven against the original 9-fixture self-test, mechanism 7 against the resulting
10-fixture one.

| # | Mechanism removed | Fixture(s) that flip | Before | During | Confirms |
|---|---|---|---|---|---|
| 1 | Catch-block exclusion (`catch_spans` returns `[]`) | "field set ONLY inside catch" | clean | **wrongly flagged** | An exception-recovery literal is not "never measured" |
| 2 | Depth-matching (`if d in computed_depths` becomes always true) | "literal only inside a checked if, no same-depth sibling" (`sewingApplied`) | clean | **wrongly flagged** | A literal gated by a real condition is not a fabrication |
| 3 | "Needs *a* computed sibling at all" (the `continue` guard removed, depth check also bypassed) | the same `sewingApplied` fixture, and the plain-constructor fixture | clean, clean | **both wrongly flagged** | A pure-literal constructor (no aggregate measurement at all) needs this gate |
| 4 | Curated `RISKY_PRODUCER` list (becomes: matches any receiver) | "a count-pin whose receiver is not on the curated list" (`box.faces().count == 6`) | clean | **wrongly flagged** | An unscoped version floods on primitive topology counts (565/850 raw sites, measured separately) |
| 5 | `VERIFICATION` exclusion (becomes: never matches) | the volume-verified pocket fixture | clean | **wrongly flagged** | Without it, a test that DOES verify its fixture gets flagged anyway |
| 6 | `COUNT_PIN` regex (becomes: never matches) | the #703-shaped fixture itself | flagged | **NOT REPORTED** | The core detection signal for sub-kind 2 |
| 7 | `verifying_helpers()` (becomes: returns an empty set unconditionally) | the `expectVolume`-style helper-call fixture | clean | **wrongly flagged** | Without it, a verification performed through a same-file helper is invisible, which is exactly the 21-site false-positive family below |

Each row was run individually (edit, `python3 Scripts/census-unmeasured-values.py --self-test`,
restore, `diff` confirms identical to backup) before the next. Full transcript is reproducible by
re-running the same 7 edits described in the mechanism column against
`Scripts/census-unmeasured-values.py` as committed; the self-test's own fixtures
(`PROD_MISSED`/`PROD_CLEAN`/`TEST_MISSED`/`TEST_CLEAN`) are the ones exercised.

No mechanism removal left its target fixture's classification unchanged: every mechanism this
script has is load-bearing for at least one fixture, which is the bar this policy sets, not merely
"the self-test passes."

## A mid-pass fix: verification performed through a helper call

The first full run of the sub-kind 2 detector reported 68 candidates. Reading every one of them by
hand (see the per-site table below) found a single mechanism accounting for 21 of the 68, all in
two files: `Tests/OCCTShapeHealingTests/Issue442FixSolidMultiBodyTests.swift` and
`Issue443FirstOfNTests.swift` both define a private helper,

```swift
private func expectVolume(_ shape: Shape, _ expected: Double, _ what: String,
                          sourceLocation: SourceLocation = #_sourceLocation) {
    guard let volume = shape.volume else {
        Issue.record("\(what): volume is nil, the solid came back inverted", sourceLocation: sourceLocation)
        return
    }
    #expect(abs(volume - expected) < 1e-6, "\(what): volume \(volume), expected \(expected)",
            sourceLocation: sourceLocation)
}
```

and every call site reads `expectVolume(healed, 2000.0, "two boxes")`, a plain function call, not a
`#expect(...)` call. The detector's `VERIFICATION` check only ever read text inside `#expect(...)`
bodies, so a verification performed one call frame away was invisible; every count-pinned test in
those two files that also called `expectVolume` was a false positive.

Fixed by adding `verifying_helpers(text)`: it scans every function in the file, and any whose OWN
body contains a VERIFICATION-matching `#expect` is registered by name; a test calling one of those
names by name is treated the same as writing the check inline. This dropped the sub-kind 2 raw
count from 68 to 47 with zero new sites appearing (verified by diffing the two runs' site lists;
see the guard-removal matrix's mechanism 7 for proof the fix is load-bearing, not decorative).

**What this does not fix, because a keyword scan cannot:** 5 of the 68 already have a real,
independent verification that the detector still cannot see, called out individually in the table
below. Two shapes recur: an abbreviated identifier defeats the keyword match even inline
(`#expect(abs(v - 1000.0) < 1e-6)`, `#expect(pv < ov)` for "pocket volume" against "outer volume"),
and a different counting property stands in as the verification
(`#expect(connected.edgeCount == 7)`, proving two faces actually merged, is not one of the ten
nouns `VERIFICATION` looks for). Both were found by reading the site, not by the script.

## Sub-kind 1: full per-site table (64 candidates)

Legend: **REAL** = confirmed instance of the class, needs a follow-up issue. **GOOD** = known-good
"absence made representable" pattern, a control not a finding. **FLIP** = legitimate
default-then-flip status/success flag. **TAG** = legitimate branch-selected classification literal.
**ALPHA** = structural default for a color quantity with no alpha channel upstream. **CFG** = a
local config/options struct passed as an argument, not a value returned to the caller (out of
`#726`'s scope: it is never "returned through an API"). **CTOR** = a plain value-type constructor
echoing its own parameters, not a measurement API.

| Site | Field | Verdict | Why |
|---|---|---|---|
| `OCCTBridge_BRepGraph.mm:216` `OCCTBRepGraphCreate` | `opts.CreateAutoProduct` | CFG | `BRepGraph::ShapesView::Options` passed into `Add()`, never returned |
| `OCCTBridge_BRepGraph.mm:1962` `OCCTBRepGraphBuilderAppendFlattenedShape` | `opts.CreateAutoProduct` | CFG | same `Options` shape |
| `OCCTBridge_BRepGraph.mm:1963` `OCCTBRepGraphBuilderAppendFlattenedShape` | `opts.Flatten` | CFG | same |
| `OCCTBridge_BRepGraph.mm:1973` `OCCTBRepGraphBuilderAppendFullShape` | `opts.CreateAutoProduct` | CFG | same |
| `OCCTBridge_Curve3D.mm:2208` `OCCTGeomConvertCurveToAnalytical` | `result.success` | FLIP | `true` only after `occtCurveToAnalytical(...)` genuinely succeeds |
| `OCCTBridge_Document.mm:427` `OCCTDocumentGetLabelColor` | `result.isSet` | FLIP | `true` only when `colorTool->GetColor` actually found a color |
| `OCCTBridge_Document.mm:520` `OCCTDocumentGetLabelMaterial` | `result.baseColor.isSet` | FLIP | `true` only inside the PBR-material-found branch |
| `OCCTBridge_Document.mm:530` `OCCTDocumentGetLabelMaterial` | `result.emissive.a` | ALPHA | `pbr.EmissiveFactor` is a `Graphic3d_Vec3` (glTF emissive has no alpha); `1.0` is opaque by definition |
| `OCCTBridge_Document.mm:531` `OCCTDocumentGetLabelMaterial` | `result.emissive.isSet` | FLIP | same branch as `baseColor.isSet` |
| `OCCTBridge_Document.mm:775` `OCCTDocumentGetDimensionInfo` | `info.isValid` | FLIP | default before the label/attribute lookup, flipped `true` only on full success (`:798`) |
| `OCCTBridge_Document.mm:807` `OCCTDocumentGetGeomToleranceInfo` | `info.isValid` | FLIP | same pattern |
| `OCCTBridge_Document.mm:3050` `OCCTDocumentGetShapeColor` | `result.a` | ALPHA | `Quantity_Color` (not `ColorRGBA`) has no alpha channel; `1.0` is the domain default |
| `OCCTBridge_Document.mm:3051` `OCCTDocumentGetShapeColor` | `result.isSet` | FLIP | `true` only when `GetColor` found one |
| `OCCTBridge_Document.mm:4290-4325` `OCCTXCAFPrsStyleCreate*` (11 fields across 3 functions) | `surfR/G/B`, `hasSurfColor`, `curvR/G/B`, `hasCurvColor`, `isEmpty` | CTOR | plain style-value constructors; `hasSurfColor`/`hasCurvColor` already gate `PresentationStyle.swift`'s optional `surfaceColor`/`curveColor` into `nil` |
| `OCCTBridge_Geom2d.mm:2593` `OCCTBisectorPointOnBisCreate` | `result.isInfinite` | CTOR | plain point-value constructor from caller-supplied params, not a computation |
| `OCCTBridge_Healing.mm:248` `OCCTShapeAnalyze` | `result.selfIntersectionCount` | **REAL** | the known seed: `0` on every call, comment admits "would require more expensive computation" |
| `OCCTBridge_Healing.mm:251` `OCCTShapeAnalyze` | `result.isValid` | FLIP | `true` after the shell/edge/face/wire scan completes |
| `OCCTBridge_Healing.mm:1632-1634` `OCCTShapeCheckSmallFaces` | `isSpotFace`, `isStripFace`, `isTwisted` | FLIP | each initialised `false` per loop iteration, flipped `true` a few lines below by a real `checker.Is*`/`CheckTwisted` call |
| `OCCTBridge_Healing.mm:1835` `OCCTCheckFace` | `result.isValid` | FLIP | input-validation guard (`if (!face)`); see the depth-coincidence note below |
| `OCCTBridge_Healing.mm:1895` `OCCTCheckSolid` | `result.isValid` | FLIP | same guard shape |
| `OCCTBridge_Healing.mm:2049` `checkSubShape` | `result.isValid` | FLIP | set `true` then conditionally flipped back `false` per real status code |
| `OCCTBridge_Healing.mm:2413` `OCCTShapeNearestPlane` | `result.success` | FLIP | `true` only inside `if (ShapeAnalysis_Geom::NearestPlane(...))`, alongside real computed fields |
| `OCCTBridge_IO.mm:828` `OCCTImportSTEPWithDiagnostics` | `result.solidCreated` | FLIP | `true` only inside `if (solidsCreated > 0)`, beside the real `result.solidsCreated = solidsCreated` |
| `OCCTBridge_Modeling.mm:5361` `OCCTChFi2dFilletAlgo` | `result.success` | FLIP | reached only after `fillet.NbResults`/`fillet.Result` both succeed |
| `OCCTBridge_Modeling.mm:5438` `OCCTChFi2dAnaFillet` | `result.success` | FLIP | reached only after `fillet.Perform(radius)` succeeds |
| `OCCTBridge_Properties.mm:519` `OCCTFaceProjectPoint` | `result.isValid` | FLIP | default before `GeomAPI_ProjectPointOnSurf`, flipped on `proj.NbPoints() > 0` |
| `OCCTBridge_Properties.mm:590` `OCCTEdgeProjectPoint` | `result.isValid` | FLIP | same pattern |
| `OCCTBridge_Properties.mm:760` `OCCTWireGetCurveInfo` | `result.isValid` | FLIP | default before the real length/closed/periodic/endpoint computation, flipped at `:787` |
| `OCCTBridge_Properties.mm:896` `OCCTWireGetCurvePointAt` | `result.isValid` | FLIP | flipped `true` at the end after real position/tangent/curvature work |
| `OCCTBridge_Properties.mm:897` `OCCTWireGetCurvePointAt` | `result.hasNormal` | **GOOD** | flipped `true` only when the normal is well-defined (`:945`), the same "absence made representable" idiom as `hasExtent` |
| `OCCTBridge_Properties.mm:1341` `OCCTBRepGPropVinertGK` | `result.errorReached` | **REAL** | `0.0` on every call; comment reads `// GetErrorReached is inline-only in OCCT 8.0.0`, a real technical constraint, but the field still reads as measured and never is |
| `OCCTBridge_Properties.mm:1342` `OCCTBRepGPropVinertGK` | `result.absoluteError` | **REAL** | same function, same story, no comment at all on this one |
| `OCCTBridge_Properties.mm:1844` `OCCTShapeGetProperties` | `result.isValid` | FLIP | default before volume/mass/inertia/area, flipped at `:1879` |
| `OCCTBridge_Properties.mm:1981` `OCCTShapeDistance` | `result.isValid` | FLIP | `true` only inside `if (distCalc.IsDone() && ...)` |
| `OCCTBridge_Spatial.mm:2268` `OCCTMathIntegKronrodAdaptive` | `config.Adaptive` | CFG | `MathInteg::KronrodConfig` passed into `Kronrod(...)`, never returned |
| `OCCTBridge_Surface.mm:1207` `OCCTShapeRecognizeCanonical` | `result.type` | TAG | `1` for the plane branch, `2` for cylinder, etc.; a branch-selected classification, not a fabrication |
| `OCCTBridge_Surface.mm:2932` `occtSurfToAnaSurfResult` | `result.success` | FLIP | `true` only after `occtSurfaceToAnalytical(...)` succeeds |
| `OCCTBridge_Topology.mm:653` `OCCTShapeRevolutionAxes` | `extentMin`, `extentMax`, `hasExtent` | **GOOD** | known-negative control #2 above: gated into `nil` by `ShapeAxis.swift:34` |
| `OCCTBridge_Topology.mm:694` `OCCTShapeSymmetryAxes` | `extentMin`, `extentMax`, `hasExtent` | **GOOD** | same gate, same file |
| `OCCTBridge_Topology.mm:694` `OCCTShapeSymmetryAxes` | `kind` | TAG | `7` marks "symmetry-derived axis" as a class distinct from the revolution-axis kinds 1-5, not a skipped classification |
| `OCCTBridge_Topology.mm:713` `OCCTShapeSymmetryAxes` | `extentMin`, `extentMax`, `hasExtent`, `kind` | GOOD/TAG | identical shape and verdict to `:694`, on a second `OCCTShapeAxis a;` in the `HasSymmetryAxis()` branch; the script counts one report per (function, field name), so this line is deduplicated out of the 64 rather than double-counted, not missed |
| `OCCTBridge_Topology.mm:1299` `OCCTBRepExtremaExtPC` | `result.isValid` | FLIP | `true` at the end after real point/parameter/distance/count work |
| `OCCTBridge_Topology.mm:1362` `OCCTShapePolyhedralDistance` | `result.success` | FLIP | `true` only inside `if (ok)`, beside real distance/point fields |

**A structural note on the three `FLIP` sites at `OCCTBridge_Healing.mm:1835/1895/2049`:** these are
flagged because a computed sibling exists at the SAME NUMERIC CONDITIONAL DEPTH elsewhere in the
same function (e.g. `OCCTCheckFace`'s per-status-code loop body, `result.errorCount++`), not because
the guard clause itself has a computed sibling. The detector counts nesting depth, not branch
identity; see "WHAT THIS STILL CANNOT SEE" in the script's own docstring. Adjudicated FLIP because
reading the surrounding branches shows the guard clause is ordinary null-input validation.

**Follow-up recommendation:** file one new issue for `OCCTBRepGPropVinertGK`'s `errorReached`/
`absoluteError` (both `OCCTBridge_Properties.mm:1341-1342`), in the same spirit as
`selfIntersectionCount`'s own existing entry. Not filed as part of this census-only pass.

## Sub-kind 2: full per-site table (68 candidates from the first run, 47 flagged today)

Every candidate the first run reported, in that run's order, read individually against its own
test file. **Still flagged** says whether today's script (after the mid-pass fix above) still
reports the site; the 21 rows marked "no" are exactly the `expectVolume`-helper family the fix
targets. Verdicts: **LOW-RISK** (the fixture's geometric relationship is verifiable by construction
or already re-derived from known structure), **NEEDS-FOLLOWUP** (not verifiable by inspection,
and nothing else in the test would catch a silent no-op), **ALREADY-FIXED** (a real, independent
verification exists that the detector cannot see, inline or through a helper).

| Site | Function | Verdict | Still flagged | Why |
|---|---|---|---|---|
| `Issue617FaceGridLayoutTests.swift:254` | `squareAndSingleGridsStillWork` | LOW-RISK | yes | count is `uSamples x vSamples`, deterministic, and cross-checked against a computed expected point |
| `OCCTBRepGraphTests.swift:717` | `shellSolids` | LOW-RISK | yes | plain box trivially has 1 shell / 1 solid by construction, no risky op involved |
| `OCCTCurveTests.swift:20` | `loftedShapeEdgePolylines` | NEEDS-FOLLOWUP | yes | both profile circles default to z=0 despite a comment claiming different Z heights; the loft may be a degenerate, coplanar shape |
| `OCCTIOTests.swift:1757` | `stepProgressCallbackFires` | LOW-RISK | yes | companion `stepRoundTripPreservesGeometry` (same file) already verifies STEP roundtrip volume/area/face/edge fidelity |
| `OCCTIntegrationTests.swift:186` | `cylinderWithHolesSlicing` | LOW-RISK | yes | holes at r=10 are clearly inside the r=25 cylinder and drilled through; a no-op would give 1 wire, not 4 |
| `OCCTIntegrationTests.swift:233` | `plateWithHolesSection` | LOW-RISK | yes | holes at (+-25, +-25) are clearly inside the 100x100 plate and drilled through; wire count of 5 follows by construction |
| `OCCTIntegrationTests.swift:346` | `pocketSectionAndOffset` | ALREADY-FIXED | yes | the test already checks `pv < ov` (pocket volume less than outer volume); the abbreviated names defeat `VERIFICATION`'s keyword match |
| `Issue497DefeaturingTests.swift:112` | `outOfRangeIndexFails` | LOW-RISK | yes | `realFaces.count == 6` is a plain box's deterministic face count, not a risky-op output |
| `Issue497DefeaturingTests.swift:150` | `withoutSmallFacesKeepsEverything` | ALREADY-FIXED | yes | the same block also asserts `abs(v - 1000.0) < 1e-6`; the abbreviated `v` defeats the keyword match |
| `Issue505FilletBuilderEdgeTypeTests.swift:64` | `edgeFromAnotherContourIsRejected` | LOW-RISK | yes | `edges.count == 12` is a box's deterministic edge count; the real guard logic is a nil/non-nil check |
| `Issue578DefeatureFaceMembershipTests.swift:68` | `foreignFaceInMixedRequestFails` | LOW-RISK | yes | the fixture's face was chosen precisely because removing it restores the plain box's known volume |
| `Issue612FilletContourSelectionTests.swift:81` | `fixtureHasATangentContinuousRim` | LOW-RISK | yes | extruding an explicit 2-line/2-arc profile deterministically gives matching top/bottom rim counts |
| `Issue639FilletDeclinedEdgeReportTests.swift:40` | `filletedWithReportNamesDeclinedEdges` | LOW-RISK | yes | declined set matches an exact, pre-measured index set; `edges.count == 12` is the box's known count |
| `Issue639FilletDeclinedEdgeReportTests.swift:149` | `historyRecordNamesDeclinedEdges` | LOW-RISK | yes | `Set(declined) == Set(declinedIndices)` is an exact match; accepted edges also independently checked |
| `Issue639FilletDeclinedEdgeReportTests.swift:194` | `declinedEdgeNamedTwiceIsReportedTwice` | LOW-RISK | yes | `Set(declinedEdgeIndices) == [declined]` pins the specific edge; the count of 2 cannot pass by coincidence |
| `Issue642AAGNodeIdentityTests.swift:55` | `detectPocketsAgreesAcrossOrder` | NEEDS-FOLLOWUP | yes | `detectPocketsAAG().count` pinned to 1 with no volume/area check that a real pocket exists |
| `Issue642AAGNodeIdentityTests.swift:77` | `upwardHorizontalCountAgreesAcrossOrder` | NEEDS-FOLLOWUP | yes | an `isUpward && isHorizontal` node count pinned to 2 with no independent geometric confirmation |
| `Issue642AAGNodeIdentityTests.swift:115` | `sharedWallNodesShareDistinctIndexAndOpposeUpward` | LOW-RISK | yes | exactly one shared face is deterministic for a single plane-split box; `isUpward`/`isHorizontal` checked directly |
| `Issue655SectionWiresOrientationTests.swift:82` | `internalEdgeExcluded` | LOW-RISK | yes | explicit square plus a disjoint floating edge; also checks the surviving wire has 4 edges and is closed |
| `Issue655SectionWiresOrientationTests.swift:98` | `forwardEdgeNotExcluded` | LOW-RISK | yes | contrast case for the row above; simple explicit coordinates make the wire count inspectable |
| `Issue655SectionWiresOrientationTests.swift:112` | `externalEdgeExcluded` | LOW-RISK | yes | same explicit, inspectable fixture as the two rows above, only the orientation flag differs |
| `Issue699AAGSolidScopedAdjacencyTests.swift:69` | `detectPocketsAgreesAcrossOrder` | NEEDS-FOLLOWUP | yes | same `detectPocketsAAG().count` pinning concern as the Issue642 version, on a vertical-cut fixture |
| `Issue699AAGSolidScopedAdjacencyTests.swift:89` | `nodeCountUnaffected` | LOW-RISK | yes | split into exactly 2 pieces by an earlier guard; 12 nodes = 2 boxes x 6 faces is deterministic |
| `Issue699AAGSolidScopedAdjacencyTests.swift:106` | `edgeCountIsTwoIndependentBoxGraphs` | LOW-RISK | yes | a companion test in the same file confirms no cross-solid adjacency via neighbor-set disjointness |
| `Issue699AAGSolidScopedAdjacencyTests.swift:180` | `horizontalFixtureStillAgreesAtCorrectedCount` | NEEDS-FOLLOWUP | yes | same `detectPocketsAAG` count-pin concern, reused at the "corrected" value 1 |
| `Issue699AAGSolidScopedAdjacencyTests.swift:225` | `countMismatchFallsBackToUnrestrictedComparison` | NEEDS-FOLLOWUP | yes | `detectPocketsAAG().count == 2` pinned on a fallback fixture; the test's own comment admits it proves little |
| `Issue699AAGSolidScopedAdjacencyTests.swift:253` | `threeSolidCompoundPartitions` | LOW-RISK | yes | 3 disjoint, known boxes; `solids.count == 3` and `nodes == 18` (3x6) are deterministic construction facts |
| `OCCTModelingTests.swift:1047` | `detectPocket` | **NEEDS-FOLLOWUP** | yes | the confirmed #726/#703 anchor bug, still live: the pocket tool's z-range never overlaps the box's own |
| `OCCTModelingTests.swift:1199` | `loftedEdgePolylines` | NEEDS-FOLLOWUP | yes | bottom and top rectangles both default to z=0; the loft fixture may be coplanar/degenerate, unverified |
| `OCCTModelingTests.swift:3053` | `splitSingleShell` | NEEDS-FOLLOWUP | yes | the sole assertion sits inside `if let`, so a nil/failed split silently skips all verification |
| `OCCTModelingTests.swift:5160` | `modified` | NEEDS-FOLLOWUP | yes | `mod.count >= 0` is vacuously true for any array; it verifies nothing about whether the face was modified |
| `Issue442FixSolidMultiBodyTests.swift:64` | `fixSolidMultiBody` | ALREADY-FIXED | no | calls the private `expectVolume(healed, 2000.0, ...)` helper |
| `Issue442FixSolidMultiBodyTests.swift:83` | `fixSolidSingleBody` | ALREADY-FIXED | no | `expectVolume` helper, target 1000.0 |
| `Issue442FixSolidMultiBodyTests.swift:99` | `fixSolidHollow` | ALREADY-FIXED | no | `expectVolume` helper, target 7000.0 |
| `Issue442FixSolidMultiBodyTests.swift:115` | `fixSolidMulticonnex` | ALREADY-FIXED | no | `expectVolume` helper, target 2000.0 |
| `Issue442FixSolidMultiBodyTests.swift:182` | `solidFromShellSkipsCavity` | ALREADY-FIXED | no | `expectVolume` helper, target 8000.0 |
| `Issue442FixSolidMultiBodyTests.swift:201` | `solidFromShellMulticonnex` | ALREADY-FIXED | no | `expectVolume` helper, target 2000.0 |
| `Issue442FixSolidMultiBodyTests.swift:223` | `solidFromShellCavityWithWiderSibling` | ALREADY-FIXED | no | `expectVolume` helper, target 35000.0 |
| `Issue442FixSolidMultiBodyTests.swift:251` | `solidFromShellFreeShells` | ALREADY-FIXED | no | `expectVolume` helper, target 2000.0 |
| `Issue442FixSolidMultiBodyTests.swift:273` | `solidFromShellDeduplicates` | ALREADY-FIXED | no | `expectVolume` helper, target 1000.0 |
| `Issue442FixSolidMultiBodyTests.swift:314` | `documentedUnclosedCheck` | LOW-RISK | yes | reuses `twoBoxes().fixSolid()`, already volume-verified by the companion `fixSolidMultiBody` in the same file |
| `Issue442FixSolidMultiBodyTests.swift:390` | `reproducerTable` | ALREADY-FIXED | no | the loop body calls `expectVolume(shape, 2000.0, label)` for every row |
| `Issue443FirstOfNTests.swift:69` | `solidFromSewnMultiBody` | ALREADY-FIXED | no | private `expectVolume` helper (same pattern), target 2000.0 |
| `Issue443FirstOfNTests.swift:89` | `solidFromAgreesWithSibling` | ALREADY-FIXED | no | two `expectVolume` calls, one per code path, both target 2000.0 |
| `Issue443FirstOfNTests.swift:107` | `solidFromSingleShell` | ALREADY-FIXED | no | `expectVolume` helper, target 1000.0 |
| `Issue443FirstOfNTests.swift:134` | `solidFromKeepsOpenBody` | LOW-RISK | yes | face count 11 = 6+5 is derived from the fixture's own explicit face slicing; rules out a dropped body |
| `Issue443FirstOfNTests.swift:151` | `solidFromSkipsCavity` | ALREADY-FIXED | no | `expectVolume` helper, target 8000.0 |
| `Issue443FirstOfNTests.swift:170` | `solidFromMulticonnex` | ALREADY-FIXED | no | `expectVolume` helper, target 2000.0 |
| `Issue443FirstOfNTests.swift:210` | `sewnHollowIsOneBody` | ALREADY-FIXED | no | loop calls `expectVolume(result, 8000.0, ...)` for both code paths |
| `Issue443FirstOfNTests.swift:232` | `sewnAndUnsewnHollowAgree` | ALREADY-FIXED | no | two `expectVolume` calls, both target 8000.0 |
| `Issue443FirstOfNTests.swift:281` | `touchingBodiesNotPruned` | ALREADY-FIXED | no | `expectVolume` helper, target 2000.0 |
| `Issue443FirstOfNTests.swift:303` | `solidWithHistoryMultiBody` | ALREADY-FIXED | no | `expectVolume` helper, target 2000.0 |
| `Issue443FirstOfNTests.swift:335` | `solidWithHistoryQueryableForEveryBody` | LOW-RISK | yes | every face of both boxes is individually checked `!isDeleted` in the shared history, stronger than a count |
| `Issue443FirstOfNTests.swift:379` | `solidWithHistoryKeepsOpenBody` | LOW-RISK | yes | same open-shell reasoning as `solidFromKeepsOpenBody`: face count 11 rules out a dropped body |
| `Issue443FirstOfNTests.swift:464` | `upgradedHollow` | ALREADY-FIXED | no | two `expectVolume` calls (input 7000.0, result 8000.0) |
| `Issue443FirstOfNTests.swift:482` | `upgradedNestedBody` | ALREADY-FIXED | no | `expectVolume` helper, target 8512.0 |
| `Issue484ConnectedFacesTests.swift:87` | `genuinelyDisconnectedFacesGetConnected` | ALREADY-FIXED | yes | also checks `connected.edgeCount == 7` (down from a confirmed 8); `edgeCount` is not one of `VERIFICATION`'s ten nouns |
| `Issue484FaceFixContextTests.swift:21` | `periodicConicalFaceSurvivesFaceFix` | LOW-RISK | yes | fixing one face deterministically yields one face; the #317 regression concern was a crash, not a miscount |
| `Issue484FaceFixContextTests.swift:59` | `unhealedPeriodicConicalUVFaceSurvivesFaceFix` | LOW-RISK | yes | the doc's own claim is "completes and returns a face"; `count == 1` states exactly that |
| `Issue484FaceFixContextTests.swift:82` | `wellFormedBoxFacesUnaffected` | LOW-RISK | yes | box face count (6) is deterministic; per-face `fixed().count == 1` is a structural invariant of the operation |
| `OCCTSurfaceTests.swift:5667` | `coaxialDedup` | NEEDS-FOLLOWUP | yes | nothing confirms both a cylindrical and a toroidal face actually survive the union before dedup is asserted to 1 axis |
| `Issue211OuterShellTests.swift:42` | `innerShells` | ALREADY-FIXED | yes | a bounding-box check (`bb.max.x - bb.min.x` around 8.0) confirms the found shell is the cavity, not the outer body; bbox spans are not a `VERIFICATION` noun |
| `Issue439OuterShellMultiSolidTests.swift:68` | `multiSolidInnerShellsEmpty` | LOW-RISK | yes | subtracting one fully-enclosed cavity from a box deterministically gives exactly 1 cavity shell |
| `Issue439OuterShellMultiSolidTests.swift:81` | `outerShellsPerSolid` | ALREADY-FIXED | yes | bounding-box spans confirm the two shells match the two known box positions; same bbox blind spot as `innerShells` |
| `Issue502SubShapeTraversalTests.swift:176` | `indexedAndArrayAccessMatch` | LOW-RISK | yes | `shells.count == 2` is the well-established hollow-box (20-cube minus an enclosed 8-cube) deterministic shell count |
| `Issue613IndexContractTests.swift:102` | `concaveEdgeIsTheConcaveEdge` | LOW-RISK | yes | `concave.map(\.index) == [corner]` pins the exact, geometrically located edge, not merely a count of 1 |
| `Issue614FaceOrientationTests.swift:117` | `sharedWallFacesOutOfBothSolids` | LOW-RISK | yes | counts deterministic for a one-plane box split; the outward-normal claim is confirmed via a dot-product check |
| `OCCTTopologyTests.swift:1348` | `boxShells` | LOW-RISK | yes | a plain box's shell count is trivially 1 by construction, no risky operation involved |

**Follow-up recommendation:** file one issue per cluster among the 11 NEEDS-FOLLOWUP rows, not one
issue per site: (1) the confirmed, still-live #726/#703 anchor at `OCCTModelingTests.swift:1047`
`detectPocket()`, matching PR #720's own fix; (2) the `detectPocketsAAG()`/AAG-node-count family
with no geometric backstop (`Issue642AAGNodeIdentityTests.swift:55,77`,
`Issue699AAGSolidScopedAdjacencyTests.swift:69,180,225`, the last of which has a comment already
admitting it proves little); (3) two loft fixtures whose "different Z heights" intent is not
actually in the code (`OCCTCurveTests.swift:20`, `OCCTModelingTests.swift:1199`); (4) three
structurally weak assertions with no shared cause (`OCCTModelingTests.swift:3053`'s `if let`-gated
check, `OCCTModelingTests.swift:5160`'s vacuous `count >= 0`, `OCCTSurfaceTests.swift:5667`'s
unconfirmed dedup input).

## Methodology notes

- **The starting-point grep is not the detector.** `grep -rniE "would require|not implemented|
  placeholder|hardcod" Sources/` (the task's own seed) returns 16 lines on this tree; 15 of them are
  comments describing an ALREADY-FIXED historical defect (documented in `CLAUDE.md`'s "Known OCCT
  Bugs"), and only one, the seed itself, is live. Neither of this pass's two real production finds
  (`errorReached`/`absoluteError`) uses any of those four words: the comment reads "GetErrorReached
  is inline-only in OCCT 8.0.0", which the keyword grep cannot see. This is exactly why #726 calls
  the grep "the STARTING point, not the answer".
- **A name-prefix census would have been wrong here too.** Filtering candidates by field name
  (`*Count`, `*Error`, `is*`) would have caught `selfIntersectionCount` and `errorReached` but also
  every `isValid`/`isSet`/`success` FLIP site and every `hasExtent`/`hasNormal` GOOD site. The
  behavioural signal (same-depth literal beside a same-depth computed sibling, single value versus
  toggling across branches) is what separates them, not the name.
- Full self-test transcript, guard-removal matrix, and this table are reproducible by running
  `python3 Scripts/census-unmeasured-values.py --self-test` and
  `python3 Scripts/census-unmeasured-values.py` from the repo root.
