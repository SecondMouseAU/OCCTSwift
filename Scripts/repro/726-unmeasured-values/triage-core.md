# #763 triage: the non-Document/IO half (36 of 62 candidates)

Scope: `OCCTBridge_Topology.mm` (9), `OCCTBridge_Healing.mm` (9), `OCCTBridge_Properties.mm` (7),
`OCCTBridge_BRepGraph.mm` (4), `OCCTBridge_Surface.mm` (2), `OCCTBridge_Modeling.mm` (2),
`OCCTBridge_Spatial.mm` (1), `OCCTBridge_Geom2d.mm` (1), `OCCTBridge_Curve3D.mm` (1) — 36 lines
total. The sibling 26 (`OCCTBridge_Document.mm`/`OCCTBridge_IO.mm`) are triaged separately on
`chore/763-triage-document`.

File:line below is where `python3 Scripts/census-unmeasured-values.py` reported the candidate on
`refactor/381-pass1b` at `809f148` (branch point for this work), before any fix in this PR moved
lines around. Each row's evidence is independent verification per
`okf/policies/measure-dont-assume.md`: the function was read in full and, where an OCCT call is
involved, its real behaviour was checked against the header (or `occt-refman`), not inferred from
the identifier or the census's own pattern name.

An earlier census-only pass (`Scripts/repro/726-unmeasured-values/README.md`, written against an
earlier commit on this same branch) already adjudicated most of these sites. Its verdicts are
noted where they agree. **One of them is corrected here** — see the `hasExtent` rows below — which
is itself the point of re-verifying rather than transcribing: a previous "GOOD (already fixed)"
label turned out to be checking the wrong thing.

## Verdict counts

Counted per census *line* (36 total, matching `census-unmeasured-values.py`'s own unit — one line
per flagged `(function, field)` pair, so `OCCTShapeSymmetryAxes`'s two `OCCTShapeAxis`
constructions at lines 694/713 share one line each for `extentMin`/`extentMax`/`hasExtent`/`kind`,
per the script's own (function, field-name) dedup):

| Verdict | Count | Lines |
|---|---|---|
| 1. Not an instance | 29 | all except the 7 below |
| 2. Compute it | 6 | `Topology.mm:653` `extentMin`/`extentMax`/`hasExtent`, `Topology.mm:694` `extentMin`/`extentMax`/`hasExtent` — one implementation (`occtComputeAxisExtent`, see below) covering both call sites |
| 3. Make absence representable | 0 | — |
| 4. Remove the field | 1 | `Healing.mm:303` `selfIntersectionCount` |

`Topology.mm:694`'s fourth field, `kind`, stays **verdict 1** even though it sits on the same line
as three verdict-2 fields — it is a real branch-selected constant (always 7, "symmetry"), not a
fabricated measurement, and untouched by the extent fix. So of `OCCTShapeSymmetryAxes`'s four
flagged fields at that line, three are verdict 2 and one is verdict 1; `OCCTShapeRevolutionAxes`'s
three flagged fields at `:653` are all verdict 2. 29 (verdict 1) + 6 (verdict 2) + 1 (verdict 4) =
36.

## Verdict 4: remove `selfIntersectionCount` — IMPLEMENTED

**`OCCTBridge_Healing.mm:303`, `OCCTShapeAnalyze()`: `result.selfIntersectionCount = 0;  // Would
require more expensive computation`.**

This is #726's own named seed instance. Verified independently before acting:

- Grepped every reference: the field was read by exactly two Swift call sites
  (`Shape+Analysis.swift`'s `analyze(tolerance:)` construction, and
  `ShapeAnalysisResult.totalProblems`'s sum), and by two test files
  (`Tests/OCCTShapeHealingTests/OCCTShapeHealingTests.swift`,
  `Tests/OCCTShapeHealingTests/Issue702SolidDemotionTests.swift`), both of which only re-derive
  `totalProblems` from the same fields `analyze()` returns — no test asserted a *specific*
  self-intersection count, because there was never a real one to assert.
- Confirmed `Shape.isSelfIntersecting(timeout:)` / `isSelfIntersecting(hardTimeout:)`
  (`Sources/OCCTSwift/Shape.swift:2107`/`2150`) already answer the question this field claims to,
  via `OCCTShapeSelfIntersectsBounded` → `BOPAlgo_ArgumentAnalyzer`'s real self-interference check
  (the #319 kernel work: `Intf_Interference`, cooperative and hard-timeout variants). This is a
  materially different, working computation, not a stub.
  `isSelfIntersecting(hardTimeout:)` additionally runs on a `deepCopy()` on a background thread
  with a real wall-clock deadline, TSan-verified per its doc comment.
- The field's own header comment already documented it as unimplemented and #702 (PR #717)
  documented the same on the Swift side. Nothing about the field can ever go from "false negative"
  to "true measurement" without becoming a duplicate, worse-typed version of
  `isSelfIntersecting`. There is no forward-compatible reason to keep it.

**Verdict: 4 — remove.** Implemented:

- `OCCTShapeAnalysisResult` (`OCCTBridge_Healing.h`): field deleted, aggregate initializer at
  `OCCTShapeAnalyze`'s top (`{0,0,0,0,0,0,false,false}` → `{0,0,0,0,0,false,false}`) updated to
  match the new 7-field layout.
  `OCCTBridge_Healing.mm:303`: assignment deleted.
- `ShapeAnalysisResult` (Swift, `ShapeAnalysisResult.swift`): stored property deleted;
  `totalProblems` no longer sums it (numerically a no-op, since the term was always 0 — the
  *type* is what changes, not any existing computed answer).
- `Shape+Analysis.swift`: construction call site updated; doc comment on `analyze(tolerance:)`
  updated to point at `isSelfIntersecting(timeout:)` without referencing the removed field.
- Docs: `docs/reference/Shape-Features.md`, `docs/guides/cookbook/healing-and-validity.md` — both
  named the field explicitly and are updated (see "Documentation" below).
- Tests: `OCCTShapeHealingTests.swift`'s `analysisResultProperties()` and
  `Issue702SolidDemotionTests.swift`'s `totalProblemsExcludingFreeFace(_:)` helper both dropped the
  term from their independently-recomputed `expectedTotal` (both still pass — see "Test results"
  below; this alone is not a strong regression check since the term contributed 0 either way, but
  it does prove the removal doesn't break either file's compile or its arithmetic).

**Not a `prove-the-test-fails` candidate in the injection sense**: this is a field *removal*, not
a new detector or a new positive check, so there is no "inject the defect, watch a test go red"
cycle that applies — the compiler is the enforcement (any code still reading the field fails to
build), and it did, twice, until the two test files and the aggregate initializer were updated.
Both are reported under "Build/compile fallout" below.

## Verdict 2: compute `ShapeAxis.extent` (`hasExtent`/`extentMin`/`extentMax`) — IMPLEMENTED

**`OCCTBridge_Topology.mm:653` (`OCCTShapeRevolutionAxes`) and `:694`/`:713`
(`OCCTShapeSymmetryAxes`, both `OCCTShapeAxis` constructions): `a.extentMin = 0; a.extentMax = 0;
a.hasExtent = false;` on every reached path, for both functions, unconditionally.**

**This is where the earlier census-only pass's verdict does not hold up, and it is worth being
explicit about why**, since `okf/policies/measure-dont-assume.md` is largely about this exact
trap. `Scripts/repro/726-unmeasured-values/README.md` (an earlier pass, written against an earlier
commit on this branch) labelled this "GOOD — known-negative control #2: gated into `nil` by
`ShapeAxis.swift:34`", i.e. verdict 1, on the reasoning that `self.extent = a.hasExtent ? (...) :
nil` is exactly the #583/#595/#609 "absence made representable" idiom.

Measured directly, independent of that reasoning:

```
grep -rn "hasExtent" Sources/OCCTBridge/src/*.mm Sources/OCCTBridge/include/*.h Sources/OCCTSwift/*.swift
```

`hasExtent` is assigned `false` at exactly three sites in the whole tree and **`true` at none**.
The #583/#595/#609 idiom requires a field that is `false` on some real paths and `true` on others,
established by real control flow (`isValid`/`success` flags elsewhere in this exact triage are the
correct version of that shape — see the "Not an instance" table below, where dozens of them are
verified to actually flip). `hasExtent` does not flip. It is the *same literal on every reached
path*, which the census script's own docstring names explicitly as "the dangerous shape... only a
field that is the SAME literal on EVERY assignment this script found... is the dangerous shape."
Wrapping a permanently-`false` flag in an `Optional` at the Swift layer does not change that the
underlying value was never computed — it changes what the "never measured" case looks like from
`0`/`0` to `nil`, one layer removed from `selfIntersectionCount`'s own shape, not a different
class of thing.

Confirmed the field was also **completely dead on the read side**: `grep -rn "\.extent\b"` across
`Sources/OCCTSwift/*.swift` and `Tests/**/*.swift` finds `ShapeAxis.extent` written (by its two
initializers) and never read anywhere in this repository, including its own test suite — no test
constructed a `ShapeAxis` by hand or asserted anything about `.extent`.

Checked the header's own contract before deciding what to implement (not inventing new semantics):
`OCCTBridge_Topology.h`'s `OCCTShapeAxis` struct already documented the exact intended contract —
`extentMin // along direction from origin (-inf as -DBL_MAX)`, `extentMax // +inf as DBL_MAX` —
years before this fix. This reads as an incomplete feature (the v0.137 axis-extraction release,
`docs/CHANGELOG.md`'s v0.137.0 entry, never mentions `extent` as delivered functionality at all),
not a deliberately deferred one like `selfIntersectionCount`'s "would require more expensive
computation".

**Verdict: 2 — compute it (non-breaking: `extent`'s type does not change, `ClosedRange<Double>?`
either way; only some previously-impossible non-nil values become reachable).**

### Implementation

New static helper `occtComputeAxisExtent` (`OCCTBridge_Topology.mm`, ahead of
`OCCTShapeRevolutionAxes`): computes `BRepBndLib::Add`'s geometric bounding box of the axis's own
shape (the face, for a revolution axis; the whole shape, for a symmetry axis), then projects all 8
corners onto the axis direction from the axis origin — the min and max of those 8 dot products is
the reported `extentMin`/`extentMax`. `Bnd_Box::IsVoid()` (no boundable geometry) reports
`hasExtent = false`; `Bnd_Box::IsOpen()` (untrimmed/unbounded geometry) reports `hasExtent = true`
with `+-std::numeric_limits<double>::max()`, honouring the header's own already-documented
`+-DBL_MAX` sentinel contract rather than treating `Bnd_Box`'s internal `Precision::Infinite()`
(1e100) as if it were a real measured bound.

This is exact wherever the bounding box is tight along the query direction — a bounded
cylindrical/conical face along its own axis (no curvature bulges past the two flat end caps along
that direction), a box along one of its own principal axes — and a safe enclosing interval
otherwise (curved geometry whose true extent along an arbitrary direction is less than its box's).
Both exact cases are the ones this PR's new tests check.

Wired into all three call sites: `OCCTShapeRevolutionAxes` (per-face, axis = the face's own
`gp_Ax1`), and both `OCCTShapeSymmetryAxes` constructions (whole-shape, axis origin = the
already-computed centre of mass, direction = the relevant principal axis).

`a.kind = 7` at these same two `OCCTShapeSymmetryAxes` sites is unaffected and **stays verdict
1**: it is a branch-selected classification constant (`.symmetry`, distinguishing these axes from
the revolution-axis kinds 1-5), not a fabricated measurement — every symmetry axis this function
returns genuinely is kind 7, by construction, the same as `OCCTShapeRecognizeCanonical`'s
`result.type` rows below.

### Tests (new, in `Tests/OCCTSurfaceTests/OCCTSurfaceTests.swift` and
`Tests/OCCTTopologyTests/OCCTTopologyTests.swift`)

- `ShapeRevolutionAxesTests.cylinderRevolutionAxisHasExtent`: a radius-5/height-20 cylinder's
  lateral face reports a non-nil `extent` whose span (`upperBound - lowerBound`) is `20`, matching
  `Shape.cylinder`'s own height. Asserts the *span* rather than absolute bounds because the axis
  direction's sign is not fixed (the pre-existing `cylinderOneAxis` test already accepts either
  sign), and the span is sign-independent while the absolute bounds are not.
- `ShapeSymmetryAxesTests.cylinderSymmetryAxisHasExtent`: the same cylinder's symmetry axis (whose
  origin is the shape's centre of mass, at half the height) reports `extent` of exactly
  `-10...10`, sign-independent for the same reason (a symmetric interval about zero is invariant
  under negating the projection direction).

**Prove the test fails** (`okf/policies/prove-the-test-fails.md`): both tests were run once with
the fix reverted (the three `occtComputeAxisExtent(...)` call sites replaced back with the
original `a.extentMin = 0; a.extentMax = 0; a.hasExtent = false;` literals), confirmed red, then
restored and confirmed green.

| State | `cylinderRevolutionAxisHasExtent` | `cylinderSymmetryAxisHasExtent` |
|---|---|---|
| Defect injected (`hasExtent` hardcoded `false`) | FAILED — "expected a non-nil extent on the cylinder's revolution axis" | FAILED — "expected a non-nil extent on the cylinder's symmetry axis" |
| Fix restored | PASSED | PASSED |

Restore verified byte-identical to the pre-injection file (`diff` against a backup) before
re-running.

### Documentation

- `Sources/OCCTBridge/include/OCCTBridge_Topology.h`: `hasExtent`'s field comment gained one line
  clarifying it is `false` only for a void bounding box, not for "unbounded but real" (which now
  gets the `+-DBL_MAX` sentinel and `hasExtent = true`).
- `docs/reference/Geometry2D.md`'s `ShapeAxis.extent` section: rewritten. It previously stated,
  as fact, `nil` for "most face types" and showed a worked example asserting `nil` for a
  cylinder's revolution axis — both true before this fix and wrong after it. Now documents which
  producers populate it (`revolutionAxes`/`symmetryAxes`, bounding-box-projection method) and
  which don't (`primaryAxis`, never wired to it), with measured example values from the new tests.

## Full per-candidate table (all 36)

Legend: **FLIP** = default-then-flip success/validity flag, driven by real control flow (the
#583/#595/#609 fix pattern, correctly applied). **GOOD** = already-representable absence, verified
to actually flip (not just structurally resemble the pattern). **TAG** = branch-selected
classification literal, not a fabrication. **CFG** = a local options/config struct passed as an
argument, never returned — outside #726's "returned through an API" scope entirely. **CTOR** = a
plain value constructor mirroring an upstream OCCT constructor's own signature exactly (verified
against the real header). **COMPUTE** / **REMOVE** = the two action verdicts above.

| File:line (original) | Function | Field | Verdict | Evidence |
|---|---|---|---|---|
| `BRepGraph.mm:218` | `OCCTBRepGraphCreate` | `opts.CreateAutoProduct` | 1 (CFG) | `opts` is a local `BRepGraph::ShapesView::Options`, passed by value into `Add()` two lines later; the function returns an `OCCTBRepGraphRef`, never `opts`. |
| `BRepGraph.mm:1964` | `OCCTBRepGraphBuilderAppendFlattenedShape` | `opts.CreateAutoProduct` | 1 (CFG) | Same `Options` shape; function is `void`. |
| `BRepGraph.mm:1965` | `OCCTBRepGraphBuilderAppendFlattenedShape` | `opts.Flatten` | 1 (CFG) | Same. |
| `BRepGraph.mm:1975` | `OCCTBRepGraphBuilderAppendFullShape` | `opts.CreateAutoProduct` | 1 (CFG) | Same; function is `void`. |
| `Curve3D.mm:2225` | `OCCTGeomConvertCurveToAnalytical` | `result.success` | 1 (FLIP) | `= true` only after `occtCurveToAnalytical(...)` returns `true` two lines above; every earlier path (`!curveRef`, conversion failure) returns with `success` at its `{...}` default `false`. |
| `Geom2d.mm:2593` | `OCCTBisectorPointOnBisCreate` | `result.isInfinite` | 1 (CTOR) | Read `Bisector_PointOnBis.hxx` directly: its real 5-arg constructor (`Param1,Param2,ParamBis,Distance,Point`) has no `IsInfinite` parameter either — `IsInfinite(bool)` is a separate setter this ctor doesn't call. The bridge mirrors the real constructor exactly. Also fully orphaned: not called from anywhere in the bridge, no Swift wrapper. |
| `Healing.mm:303` | `OCCTShapeAnalyze` | `result.selfIntersectionCount` | **4 — REMOVE** | See above. |
| `Healing.mm:306` | `OCCTShapeAnalyze` | `result.isValid` | 1 (FLIP) | `false` default, `= true` only at the end after the shell/edge/face/wire/gap scan completes without throwing. |
| `Healing.mm:1707-1709` | `OCCTShapeCheckSmallFaces` | `isSpotFace`/`isStripFace`/`isTwisted` | 1 (FLIP) | Each reset `false` per loop iteration, then individually flipped `true` a few lines below by its own real `checker.IsSpotFace`/`IsStripSupport`/`CheckTwisted` call. |
| `Healing.mm:1910` | `OCCTCheckFace` | `result.isValid` | 1 (FLIP) | Null-input guard (`if (!face)`); the census's own docstring names this exact function as the "conditional depth is a count, not an identity" blind spot — the computed sibling it's paired against (`result.errorCount++`) is in an unrelated branch of the same function, not this guard. Read in full: the guard clause has no computed sibling of its own; it's ordinary input validation. |
| `Healing.mm:1970` | `OCCTCheckSolid` | `result.isValid` | 1 (FLIP) | Same guard shape as `OCCTCheckFace`. |
| `Healing.mm:2124` | `checkSubShape` (static) | `result.isValid` | 1 (FLIP) | `false` default; `= true` unconditionally after a real `BRepCheck_*` constructor + `Minimum()` succeed, then conditionally flipped back `false` per real status code in the loop below. |
| `Healing.mm:2467` | `OCCTShapeNearestPlane` | `result.success` | 1 (FLIP) | `= true` only inside `if (ShapeAnalysis_Geom::NearestPlane(pts, pln, dmax))`, beside the real computed `maxDeviation`/normal/origin fields in the same block. |
| `Modeling.mm:5361` | `OCCTChFi2dFilletAlgo` | `result.success` | 1 (FLIP) | `= true` only after `fillet.Perform(radius)` succeeds AND the resulting `filletEdge` is non-null. |
| `Modeling.mm:5438` | `OCCTChFi2dAnaFillet` | `result.success` | 1 (FLIP) | Same shape, `ChFi2d_AnaFilletAlgo`. |
| `Properties.mm:519` | `OCCTFaceProjectPoint` | `result.isValid` | 1 (FLIP) | `false` default; `GeomAPI_ProjectPointOnSurf` — `= true` only after `proj.NbPoints() > 0`. |
| `Properties.mm:590` | `OCCTEdgeProjectPoint` | `result.isValid` | 1 (FLIP) | Same shape via `occtNearestPointOnCurveRange`. |
| `Properties.mm:760` | `OCCTWireGetCurveInfo` | `result.isValid` | 1 (FLIP) | `false` default; `= true` at the end after the real length/closed/periodic/endpoint computation. |
| `Properties.mm:896` | `OCCTWireGetCurvePointAt` | `result.isValid` | 1 (FLIP) | Same shape. |
| `Properties.mm:897` | `OCCTWireGetCurvePointAt` | `result.hasNormal` | 1 (GOOD) | Verified it actually flips: `= true` only when curvature is non-degenerate (`> 1e-10`) AND the normal-direction vector's own magnitude is non-degenerate — read the full branch (lines 918-951), both guards are real. Swift side (`Wire.swift`) gates this into `SIMD3<Double>?`. |
| `Properties.mm:1843` | `OCCTShapeGetProperties` | `result.isValid` | 1 (FLIP) | `false` default; `= true` only after `occtVolumeMassProperties` succeeds and volume/mass/inertia/area are all computed — the #609 fix (`occtVolumeMassProperties` itself refuses a zero-mass framework) is what this function relies on, already in place. |
| `Properties.mm:1980` | `OCCTShapeDistance` | `result.isValid` | 1 (FLIP) | `= true` only inside `if (distCalc.IsDone() && distCalc.NbSolution() > 0)`, beside the real distance/point fields set in the same block. |
| `Spatial.mm:2268` | `OCCTMathIntegKronrodAdaptive` | `config.Adaptive` | 1 (CFG) | `config` is a local `MathInteg::KronrodConfig` passed by value into `MathInteg::Kronrod(...)` on the next line; never returned. This is what makes the function the *Adaptive* variant, as opposed to the two-functions-above `OCCTMathIntegKronrod`, which doesn't set it at all. |
| `Surface.mm:1207` | `OCCTShapeRecognizeCanonical` | `result.type` | 1 (TAG) | `= 1` only inside `if (recog.IsPlane(tolerance, pln))`; siblings `= 2/3/4/5` guard cylinder/cone/sphere/line the same way, each behind its own real `recog.Is*` check. |
| `Surface.mm:2977` | `occtSurfToAnaSurfResult` (static) | `result.success` | 1 (FLIP) | `= true` only after `occtSurfaceToAnalytical(...)` returns `true`. |
| `Topology.mm:653` | `OCCTShapeRevolutionAxes` | `a.extentMin`/`extentMax`/`hasExtent` | **2 — COMPUTE** | See above. |
| `Topology.mm:694` | `OCCTShapeSymmetryAxes` | `a.extentMin`/`extentMax`/`hasExtent` | **2 — COMPUTE** | See above (both `OCCTShapeAxis` construction sites in this function). |
| `Topology.mm:694` | `OCCTShapeSymmetryAxes` | `a.kind` | 1 (TAG) | `= 7` unconditionally on both construction sites — genuinely always kind 7 (symmetry) for everything this function returns; not a skipped classification (contrast with `OCCTShapeRecognizeCanonical.type`, which selects among several literals). |
| `Topology.mm:1299` | `OCCTBRepExtremaExtPC` | `result.isValid` | 1 (FLIP) | `= true` at the end only after `occtNearestPointOnCurveRange` (the shared #539/#580 helper) succeeds; every earlier failure path (`edge.IsNull()`, `curve.IsNull()`, no nearest point) returns with `isValid` at its `{}` default `false`. |
| `Topology.mm:1362` | `OCCTShapePolyhedralDistance` | `result.success` | 1 (FLIP) | `= true` only inside `if (ok)`, `ok` being `BRepExtrema_Poly::Distance`'s own out-parameter success flag. |

## Documentation, in full

- `Sources/OCCTBridge/include/OCCTBridge_Healing.h` — `selfIntersectionCount` field deleted, one
  comment line left in its place explaining the removal and pointing at the replacement API.
- `Sources/OCCTBridge/include/OCCTBridge_Topology.h` — `hasExtent`'s comment extended (see above).
- `Sources/OCCTSwift/ShapeAnalysisResult.swift` — field deleted; `totalProblems`'s doc comment
  updated to stop citing the removed field and instead point at `isSelfIntersecting(timeout:)`.
- `Sources/OCCTSwift/Shape+Analysis.swift` — `analyze(tolerance:)`'s doc comment updated.
- `docs/reference/Shape-Features.md` — `ShapeAnalysisResult`'s field table and prose updated.
- `docs/guides/cookbook/healing-and-validity.md` — the `analyze(tolerance:)` snippet no longer
  prints the removed field.
- `docs/reference/Geometry2D.md` — `ShapeAxis.extent` section rewritten with the real contract and
  measured example values (see above).
- `docs/CHANGELOG.md` / `docs/SEMVER.md` — deliberately **not** touched, per
  `okf/policies/changelog-on-merge.md` / `okf/policies/semver-at-release.md`; both are carried in
  this PR's body instead (`## CHANGELOG entry`, `## SemVer impact`).

## Build/compile fallout from the removal

Removing `selfIntersectionCount` broke the build twice before it was clean, both caught by
`swift build` immediately:

1. `OCCTBridge_Healing.mm:195`'s positional aggregate initializer
   (`OCCTShapeAnalysisResult result = {0, 0, 0, 0, 0, 0, false, false};`) had one element too many
   for the now-7-field struct (`excess elements in struct initializer`). Fixed by dropping one
   `0`.
2. Two Swift test files referenced `analysis.selfIntersectionCount` directly in their own
   independently-recomputed `expectedTotal`/`totalProblemsExcludingFreeFace` sums
   (`OCCTShapeHealingTests.swift`, `Issue702SolidDemotionTests.swift`) — both updated to drop the
   term (see "Verdict 4" above).

## Test results

Full evidence, gate-by-gate and full-suite, is in the PR body. Summary:

- All 5 gate scripts (`check-bridge-index`, `check-null-handle-guards`, `check-docs-defaults`,
  `derive-bridge-header-split --verify`, `count-operations`) plus their `--self-test`s: clean.
- `census-unmeasured-values.py --self-test`: 10/10 (its own fixture battery, unrelated to this
  PR's specific fixes, unaffected).
- `census-unmeasured-values.py` (report mode) on this branch after the fix: 55 production
  candidates, down from the pre-fix 62 — the 7-candidate drop is exactly `selfIntersectionCount`
  (1) plus `extentMin`/`extentMax`/`hasExtent` at both call sites (6), matching this triage. The
  `OCCTShapeSymmetryAxes.kind` TAG candidate is still reported (now at a shifted line number, same
  (function, field) pair as before) — expected, since `kind` was never touched.
  `check-changelog-transcription.py`'s report is unrelated to this diff (it audits the branch's
  past merge history, not this PR).
- New tests (`cylinderRevolutionAxisHasExtent`, `cylinderSymmetryAxisHasExtent`): proven to fail
  with the defect injected, pass restored (table above).
- Full `swift test`: see PR body for the final count and pass/fail summary.
