# #815: refman coverage audit, tests, geometry primitives (Pass 5a of #807)

Three files, following the `Scripts/repro/81{1,2,3}-refman-coverage-*` precedent's shape (a
`derive_lane.py`, a `refman_census.py`, a `selftest_removal_matrix.py`), but auditing a different
axis than any of them:

| file | what it is |
|---|---|
| `derive_lane.py` | the lane, derived from scratch. #815's own issue names four TEST TARGETS, not an OCCT package list, and unlike #808-#813 there is no #380-built class table to inherit (#380 was a duplication audit, not a refman-coverage one). This derives, mechanically, which Swift types/members the four targets actually own, then which OCCT classes each member's own bridge call reaches. |
| `refman_census.py` | the census: 1,288 members across 90 types (including 31 nested `NativeHandleView` property structs like `Curve2D.CircleProperties`), classified `ok`/`under`/`inconclusive`/`undocumented`/`pure-swift`, plus the 13-finding regression pin and the 1-finding over-coverage pin, plus its own `--self-test`. |
| `selftest_removal_matrix.py` | the proof that the self-test's five call-site shapes and two genericity valves are load-bearing, not decoration. All seven proved load-bearing on the first run (unlike #811's, which found three decorative shapes). |

```bash
python3 Scripts/repro/815-refman-coverage-tests-geometry/derive_lane.py                 # the lane
python3 Scripts/repro/815-refman-coverage-tests-geometry/derive_lane.py --members       # + per-type bridge-call counts
python3 Scripts/repro/815-refman-coverage-tests-geometry/derive_lane.py --classes       # + the type-level OCCT class table
python3 Scripts/repro/815-refman-coverage-tests-geometry/derive_lane.py --member-detail # + every member's tested status
python3 Scripts/repro/815-refman-coverage-tests-geometry/derive_lane.py --gaps          # ambiguous ties + #380's list checked
python3 Scripts/repro/815-refman-coverage-tests-geometry/refman_census.py               # the table
python3 Scripts/repro/815-refman-coverage-tests-geometry/refman_census.py --verbose     # + every non-ok member
python3 Scripts/repro/815-refman-coverage-tests-geometry/refman_census.py --self-test
python3 Scripts/repro/815-refman-coverage-tests-geometry/selftest_removal_matrix.py
```

All run from any cwd, in under a minute (`refman_census.py`'s bare run is ~25s: it walks every
Swift source file and every test target's source once).

## This pass does double duty, and says so rather than hiding it

Passes 4a-4d (source-side) each got a settled class table from an earlier pass to check docs
against. #815's own issue body says to mirror "Pass 1a's source surface" (#380), but #380 was a
**duplication** audit ("reimplemented helpers, copy-pasted math, drifted doc comments"), not a
refman-coverage one, so there is no "documented?/wrapped?" table sitting in `docs/` waiting to be
checked against tests. Building that table (`derive_lane.py`) and auditing tests against it
(`refman_census.py`) both had to happen in this one pass, and that is narrower work per file than
811-813 got to do (their `LANE_CLASSES` were hand-curated over many review rounds; this lane's 1,288
members are classified mechanically). Said plainly, once, here: this is a single-pass audit, not a
multi-round one, and its class table is a byproduct of a call-derivation, not a hand-verified
enumeration the way #811's 129 classes were.

## The lane, as actually derived (not #380's file list)

The rule (`derive_lane.py`'s own docstring has the full mechanics): for every `public [final]
class|struct|enum` declared at file scope in `Sources/OCCTSwift`, count `\bTypeName\b` occurrences
in each of the 18 test targets' own source; if there is a STRICTLY unique maximum and it is one of
`OCCTCurveTests`/`OCCTGeom2dTests`/`OCCTSurfaceTests`/`OCCTMathTests`, and the total is at least 2,
the type is in this lane, owned by that target.

**Two of #380's 16 files are measurably NOT in this lane.** `BRepGraph.swift`'s primary owner is
`OCCTBRepGraphTests` (361 of 467 references; it has its own dedicated target and belongs to Pass
5b, Shape/Topology). `MedialAxis.swift`'s primary owner is `OCCTAnalysisTests` (21 of 28), which no
Pass 5 sub-issue names at all; flagged as an orphan, not silently dropped (see "What this pass did
not do").

**The real lane reaches 47 files #380 never named**, because #380 was never asked to be exhaustive:
`MathSolver.swift` (152 refs), `MathLibrary.swift`'s six `math_*` facades (`MathGauss`/`MathCrout`/
`MathSVD`/`MathJacobi`/`MathHouseholder`/`MathMatrix`), `GeomPrimitives.swift`'s five `gp_`-backed
classes (`GeomPoint3D`/`GeomVector3D`/`GeomDirection`/`Axis1Placement`/`Axis2Placement`),
`Continuity.swift`'s three enums, `ElLib.swift` (`ElCLib`/`ElSLib`), `Interval.swift`,
`Quaternion.swift`, `TransformFactory.swift`, `VectorMath.swift`, `TrigRoots.swift`,
`AnalyticGeometry.swift`, and 33 more. `derive_lane.py`'s own output prints the current, re-derived
counts; they are not repeated here as a static number because every one already moved once between
the first draft of this file and the version you are reading (adding the 31 nested property-view
structs, below, moved the member total from 1,175 to 1,288).

**31 nested `NativeHandleView` property structs were invisible to the file-scope-only scan
entirely**, and finding that was itself a real correction mid-pass, not a design decision made in
advance. `Curve2D.CircleProperties`, `.EllipseProperties`, `.HyperbolaProperties`,
`.ParabolaProperties`, `.LineProperties`, `.OffsetProperties`, `.BezierProperties` (7),
`Curve3D`'s five siblings, `Surface`'s six (`PlaneProperties`/`SphereProperties`/
`TorusProperties`/`CylinderProperties`/`ConeProperties`/`SweptProperties`) plus `BezierProperties`,
31 in the whole tree, are declared `public struct X: ... NativeHandleView { ... }` **inside an
`extension Curve2D { ... }` block**, one level deeper than `^public struct` can see. Measured, not
assumed, that this mattered: a member-count check against `Curve2D.swift` alone (246 raw `public
func/var/init` declarations across its primary body and 31 extensions) came back 196 before this
fix, a 50-member gap traced to exactly these seven nested structs. `derive_lane.py`'s
`nested_view_bodies()` extracts them separately and folds them into `lane_members()` under a
compound name (`Curve2D.CircleProperties`) sharing the outer type's owning target.

## A methodology defect found and fixed mid-pass: `reachable()` is unsound for this question

`check-bridge-index.py`'s `reachable()`, the tool #811/#928 already reuse for a **different**
question (a permissive "could this doc claim's class conceivably be reached" existence check),
was the first thing this pass tried for "which OCCT class does this member represent". It is wrong
for that question, and not by a small amount: `Curve3D.adjustEndpoints`'s own bridge function
(`OCCTShapeConstructAdjustCurve3D`, five lines, constructs exactly `ShapeConstruct_Curve` and
`gp_Pnt`) resolved through `reachable()` to **78** names including `TDocStd_Document`,
`XCAFDoc_ShapeTool`, `TDF_Label`, `TNaming_Scope`. Traced to a specific mechanism, not a vague
"it's noisy": the wrapper struct `OCCTCurve3D` holds `Handle(Geom_Curve) curve;`, so the bare token
`Handle` — OCCT's own smart-pointer macro, present in nearly every function that touches a handle
of anything — lands in every such function's name set. `reachable()`'s second expansion pass then
asks "is `Handle` ALSO the literal name of some function or type defined anywhere in the bridge",
and `OCCTBridge_Internal.h` happens to define an unrelated OCAF helper called exactly `Handle(...)`,
whose own reach is that 78-name OCAF cluster.

This is not a one-off collision: `Handle(...)` is one of the single most common tokens in the whole
bridge, so reusing `reachable()` unmodified would have shipped a class table where ordinary
`Curve3D`/`Curve2D`/`Surface` methods read as reaching XCAF/OCAF document classes, an error a
reviewer would catch on sight and one that would discredit every other entry in the table with it.
`derive_lane.py`'s `bridge_reach()` reimplements `reachable()`'s SAFE half (a function reaches what
its own wrapper struct field holds — genuinely useful, it's the only reason `Geom_Curve`/
`Geom_Surface`/`Geom2d_Curve` attribute correctly for methods whose own body never spells the class
name) and drops the unsafe half (the bare-name-collision expansion) entirely. The stated cost: a
class reached ONLY through a same-file helper BY NAME (not by wrapper field) is missed here where
`reachable()` would have found it, a narrower and less permissive table, which is the correct
direction to err for "what does this member actually represent" (the opposite of #811/#928's own
tradeoff, where over-approximating only hides a real over-coverage finding rather than inventing
one). Re-derived after the fix: the type-level class count dropped from 550 to 501, and the
`TDocStd`/`XCAFDoc`/`TDF_`/`TNaming` cluster is gone from every geometry-primitives member's
attribution.

## What "tested" means, and a second correction found the same way

The census unit is the **member**, not the class, because "an OCCT behaviour ... which no test
exercises" is a per-capability question: `Curve3D` alone is referenced 832 times in
`OCCTCurveTests`, so "is `Geom_Curve` tested" is true almost by definition and would hide the real
finding entirely. `lane_members()` walks every member's own bridge calls, resolves the OCCT
classes they reach (via the corrected `bridge_reach()`), and asks whether a call-site syntax
matching that member's kind (`.name(`, `Type.name(`, `.name`, `Type.name`, `Type(` for an
initializer) appears anywhere in test source, with a genericity valve: a name on a short blocklist
(`length`, `value`, `count`, ...) or shared by more than 3 lane types is reported `None`
("ambiguous, cannot say") rather than guessed either direction, since a false credit here would
hide a real gap and that is the wrong direction to be wrong in.

**Two signals are computed, `tested` and `tested_anywhere`, and only the second drives a
verdict.** `tested` asks the question #815's own `## Lane` literally poses (a call site in one of
the FOUR lane targets). The first cut of this census used only that signal, and **29 of its 42
"candidates" were a defect in the check, not in the tree**: `Curve3D.torsion`/`.localTangent`/
`.localNormal`/`.localCentreOfCurvature`/`.splitAt`/`.isPeriodicSA`/`.isClosedWithPrecision`/
`.convertToPeriodic`/`.adjustEndpoints`, `Curve2D.adjustEndpoints`/`.convertToBezierSegments`, and
17 `Surface` members (`.extremaPS`/`.extremaPSPoint`/`.extremaSS`/`.extremaSSPoint`/
`.localCurvatures`/`.localCurvatureDirections`/`.isUClosedSA`/`.isVClosedSA`/`.hasSingularitiesSA`/
`.singularityCountSA`/`.splitByAngle`/`.splitByArea`/`.splitSurfaceByContinuity`/
`.conversionGap`/`.convertToAnalytical`/`.convertToPeriodic`/`.intersectionCurves`/`.valueOfUV`)
and 6 nested-view members (`.yAxis`, `.directrix1`, `.focus2`, `.asymptote1`, `.lin`,
`.directrix`, `.apex`, `.coefficients`, `.pln` across various `*Properties` structs) are all
genuinely tested, correctly, in `OCCTAnalysisTests` (its differential-geometry batch suites) or
`OCCTShapeHealingTests`, following this repo's own Test Layout convention of filing a suite under
"the domain target that best matches it" rather than a type's own primary-usage target. Reporting
those as `under` would have been a false alarm from the check, and #815's own **Handling real
findings** section warns against exactly that overcorrection. `tested_anywhere` (a call site
anywhere in `Tests/`) is the signal that actually drives `classify()`; `tested` stays in the data
only as the "which target" annotation the README's finding list uses below.

## The verdict table

Run fresh against this branch:

```
#815 geometry-primitives TEST lane: 1288 members across 90 types (including nested property views)

verdicts:
  ok                     550
  under                  0
  deliberate, recorded   0
  inconclusive           219
  undocumented           37
  pure-swift             482

all 13 previously-fixed findings still tested_anywhere=True

the 1 corrected over-coverage finding has not reappeared
```

- **`pure-swift` (482)**: the member's own body calls no OCCT bridge function at all (a convenience
  overload, a computed combination of other members, ...). Not an "OCCT behaviour" by #815's own
  definition, so not part of the question.
- **`undocumented` (37)**: wrapped, and (mostly) tested, but carries no `///` doc comment, so it
  isn't the shape #815 defines ("documented, which we wrap AND document"). Spot-checked, not
  individually adjudicated: they are simple, self-evident geometric accessors
  (`Axis1Placement.direction`/`.location`, `GeomDirection.coordinates`, `GeomPoint3D.distance`,
  ...) whose names carry their own meaning; a real but minor documentation-completeness gap, out
  of scope for a test-coverage pass and not filed.
- **`inconclusive` (219)**: the genericity valve fired (a short/common name, or a name shared by
  more than 3 lane types) — not adjudicated by name in this pass; see "What this pass did not do".
- **`under` (0)** and **`deliberate, recorded` (0)**: zero, because the 13 real findings this pass
  found were fixed in the same branch (below), not because none existed to find.

## Before this branch: 13 real findings, all fixed here

Every one is documented+wrapped, was `tested_anywhere=False` (checked across all 18 targets, not
just the four lane ones), and now has a passing test that was proved to fail first
(`okf/policies/prove-the-test-fails.md`): the Swift wrapper was broken (return a wrong/zero value,
or force `false`), the new test's failure confirmed, the wrapper restored, and the pass reconfirmed.
All batched by module to keep the build/test cycle count down; each batch's own diff is in the
commit history.

| member | evidence | fix |
|---|---|---|
| `Curve3D.d2(at:)` | its sibling `d1(at:)` is tested two lines above; `d2` itself: 0 hits anywhere in `Tests/` | `Curve3DPrimitiveTests.swift`: for a circle at the origin, `d2(u) = -P(u)` exactly, for any `u` |
| `Curve3D.bsplineSetKnot(index:value:)` | its batch sibling `bsplineSetKnots` is tested; the singular setter: 0 hits | `BSplineCurve3DCompletionsV121Tests.swift`: set two knot indices, read back via `bsplineKnotSequence()` |
| `Curve2D.d2(at:)` | same shape as `Curve3D.d2` | `Curve2DTests.swift`: same relationship, 2D |
| `Curve2D.allExtrema(with:)` | 0 hits anywhere | `Issue815Curve2DExtremaSelfIntersectTests.swift`: two circles 20 apart, exact nearest (10) and farthest (30) distances |
| `Curve2D.selfIntersections(tolerance:)` | 0 hits anywhere; `OCCTCurve2DSelfIntersect` (the bridge fn) is a real, live entry point, not dead code | same file: a control-point loop measured (not derived analytically — a first hand-picked "bowtie" control polygon proved NOT to self-intersect, see below) to self-intersect at (2.5, 3.0), plus a circle control asserting zero hits |
| `OCCTPrecision.infinite` | its siblings `.confusion`/`.angular`/`.approximation`/`.isInfinite` are all tested; `.infinite` itself: 0 hits | `PrecisionTests.swift`: `isInfinite(.infinite)` and a magnitude floor, tied to the documented relationship rather than the literal `2e100` |
| `OCCTPrecision.pConfusion` | same pattern | `PrecisionTests.swift`: `pConfusion == confusion / 100` exactly, per occt-refman@8.0.1's own documented `PConfusion()` contract |
| `Surface.bsplineSetUKnot`/`.bsplineSetVKnot` | the batch `bsplineInsertUKnots`/`VKnots` are tested; the singular setters: 0 hits | `BSplineSurfaceCompletionsV121Tests.swift`: set + read back via `bsplineUKnots()`/`bsplineVKnots()` |
| `Surface.bsplineRemoveUKnot` | its V twin (`BSplineSurfaceRemoveVKnotTests.swift`) is tested; U: 0 hits | new `BSplineSurfaceRemoveUKnotTests.swift`, mirroring the V file, PLUS a genuinely-removable-knot case the V file's own test never had (insert then remove, asserting the boolean, not just survival) |
| `Surface.bsplineIncreaseVMultiplicity` | its U twin is tested; V: 0 hits | `BSplineSurfaceCompletionsV121Tests.swift`, mirroring the U test |
| `Surface.isUClosed`/`.isVClosed` | siblings `isUPeriodic`/`isVPeriodic` tested throughout `SurfaceAnalyticTests.swift`, `isUClosedSA`/`isVClosedSA` tested elsewhere; the plain, non-SA closure flags: 0 hits anywhere | `SurfaceAnalyticTests.swift`: plane/cylinder/sphere/torus against the pinned kernel's own header comments on `Geom_Plane`/`Geom_CylindricalSurface`/`Geom_SphericalSurface`/`Geom_ToroidalSurface` |

**The self-intersection fixture took two attempts, and the failed one is worth recording.** The
first control-point set tried, `(0,0)-(10,10)-(0,10)-(10,0)` (a "bowtie" quadrilateral whose EDGES
visibly cross), was proven by direct measurement against the real bridge to produce **zero**
self-intersections: a control polygon crossing itself does not make the curve it defines cross
itself, and a symbolic check (not shown here, done by hand) confirms this specific polygon is
symmetric in a way that pairs each point with a distinct mirror point at the same height rather
than looping through it. A small numeric probe against seven candidate control-point sets (not
committed — a throwaway `swift test` scratch file, deleted once it had answered the question) found
`(0,0)-(10,10)-(-5,10)-(5,0)` genuinely loops, confirmed at (2.5, 3.0). The lesson generalized into
the test's own comment, since the wrong intuition is an easy one to have again.

## One over-coverage finding, fixed

`Tests/OCCTSurfaceTests/SurfaceAnalyticTests.swift`'s `sphereProperties()` comment said "Sphere is
U-periodic (wraps around) and V-closed (pole to pole)". The pinned kernel's own header comment
(`Geom_SphericalSurface.hxx`, via the cached `OCCT.xcframework` this build resolved) is explicit:

```
//! Returns True.
Standard_EXPORT bool IsUClosed() const final;

//! Returns False.
Standard_EXPORT bool IsVClosed() const final;
```

A sphere's poles are DEGENERATE points, not a matching pair of points at the two ends of the V
range, which is what `IsVClosed()` actually tests for; "V-closed" was using the word colloquially
where the surrounding vocabulary (`isUPeriodic`, the sibling this test does assert) reads as the
technical predicate. No test ever asserted `isVClosed` on a sphere before this pass (that's part
of finding #13 above, `Surface.isUClosed`/`.isVClosed`), so this was a wrong COMMENT, not a wrong
assertion; fixed in place, and the new `closureFlags()` test added alongside it asserts the correct
value (`sphere.isVClosed == false`).

**A broader over-coverage sweep found nothing else.** Three checks, all against the four lane
targets' own test files:

1. A grep for explicit behavioral/numeric claims (`always`/`never`/`guarantee[sd]?`/`exactly
   [0-9]`/`invariant`) in `///`/`//` comments: 18 hits, all in already-extensively-investigated
   `Issue*Tests.swift` files (#398, #403, #485, #522, #548, #623, #791, #1049), each citing a
   specific, already-root-caused defect from `CLAUDE.md`'s own Known OCCT Bugs list. None read as
   a new, unverified claim.
2. A grep for hardcoded tolerance literals (`1e-N`) in doc comments: 36 hits, all describing THIS
   bridge's own hardcoded parameter choices (parity tests comparing this project's default
   tolerances against OCCT's), not claims about what OCCT itself promises, so not the shape #815's
   over-coverage direction targets.
3. A `` `Class::Member` `` attribution sweep (the same detector shape `census-doc-occt-
   attribution.py` uses, reused directly against the pinned `OCCT.xcframework` headers this
   build resolved, restricted to the four lane targets rather than `docs/`): 37 attributions, 0
   resolving to a member the pinned header does not declare.

Not a proof of zero remaining over-coverage (see "What this pass did not do"), but three
independent, real checks, not a single grep taken on faith.

## Verification

```
$ python3 Scripts/repro/815-refman-coverage-tests-geometry/refman_census.py --self-test
...
15 passed, 0 failed

$ python3 Scripts/repro/815-refman-coverage-tests-geometry/selftest_removal_matrix.py
baseline: 6/6 cases pass unmodified

  instance-var   disabled -> 1/6 cases fail  [load-bearing]
  instance-func  disabled -> 1/6 cases fail  [load-bearing]
  static-func    disabled -> 1/6 cases fail  [load-bearing]
  static-var     disabled -> 1/6 cases fail  [load-bearing]
  init           disabled -> 1/6 cases fail  [load-bearing]

valves (proved by construction, not by disabling code):
  load-bearing             GENERIC_MEMBER_NAMES: generic name -> None, otherwise-identical non-generic name -> True
  load-bearing             OVERLOAD_FANOUT: over threshold -> None, under threshold -> True

every shape and valve is load-bearing
```

Full `swift test` for all four touched targets, clean, after the 13 fixes:

```
OCCTCurveTests:   557 tests, 0 failures
OCCTGeom2dTests:  547 tests, 0 failures
OCCTSurfaceTests: 563 tests, 0 failures
OCCTMathTests:    352 tests, 0 failures
```

## What this pass did not do

- **The 219 `inconclusive` members were not individually adjudicated by name.** The genericity
  valve (a fixed blocklist plus an overload-fanout threshold) exists specifically because a
  name-based heuristic cannot safely resolve them either direction: a false `True` would hide a
  real gap, a false `False` would manufacture one. A human reading each of the 219 against its own
  member body was out of scope for one pass; #811 spent many review rounds on a table roughly a
  seventh this size. Flagged, not hidden: re-run with `--verbose` to get the full list.
- **The 37 `undocumented` members were spot-checked, not individually adjudicated.** All sampled
  were simple, self-evident geometric accessors; none looked like a hidden real gap, but "spot
  checked six, read as fine" is not the same claim as "all 37 are fine".
- **`MedialAxis.swift`'s orphan status is reported, not resolved.** Its primary test-target owner
  (`OCCTAnalysisTests`) is named by no Pass 5 sub-issue at all, the same shape #811's own
  `--substrate` handoff describes for source-side packages no pass names. Not this pass's call to
  make; noted for whoever eventually asks which Pass 5 lane (or Phase 6) owns `OCCTAnalysisTests`.
- **No attempt was made to enumerate every OCCT class the pinned refman documents for this
  package family and check it against what this lane's members reach**, the shape #808-#813 use
  for their own "under-coverage" (an OCCT class we neither wrap nor document). #815's own question
  is inverted (does a test exercise what we already wrap and document), so that class-enumeration
  direction genuinely does not apply here; noted so its absence does not read as an oversight.
- **The over-coverage sweep is three targeted checks, not an exhaustive one.** See the sweep's own
  section above for exactly what ran and did not.
