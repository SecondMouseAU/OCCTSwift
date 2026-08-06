# Cluster D census (#513/#667): continuity handling across the kernel and the bridge

The census artifact `docs/v2.0.0-plan.md` names as a hard prerequisite before #437 or #438 starts.
#513 already wrote the finding as prose: 38 unaudited continuity-related bridge functions, four
incompatible request encodings, two live defects. This directory turns that prose into a committed,
executable artifact that measures the CURRENT tree, rather than a list in an issue body that goes
stale the next time someone touches this code (which, per #490/#480/#619, several PRs already have,
since #513 was filed).

**This directory is the census only. It does not fix #437, #438, or `BRepGraph.edgeMaxContinuity`'s
stub.** #490, #480, #398 and #619 are prior art on this exact area and are cited inline rather than
rederived, per this issue's own instruction not to rediscover them.

## Method

Two independent halves, matching Cluster A/B's own method:

1. **Dynamic (primary).** `Scripts/repro/censuses/ClusterD.swift`, run as the `cluster-d` subcommand
   of the shared `Censuses` executable target (`swift run Censuses cluster-d`), calls each
   identified entry point against real fixtures and prints the measured table below. A cell says a
   class name, a piece count, a face count or `nil` because it was *measured*, not because a doc
   comment or an issue's own table says so.
2. **Static (secondary cross-check).** `classify_continuity_sites.py` scans the bridge source for
   each named C function and classifies which of the three shared `occtGeomAbsFrom*` decoders
   (`Sources/OCCTBridge/src/OCCTBridge_Internal.h`, #490) its body calls, or whether it forwards the
   caller's integer as a literal order with no decode step at all. Unlike Cluster A/B, this
   classifier's function list was built by reading each site's source before writing either half of
   this census, so no disagreement between the two surfaced this time -- recorded as a finding in
   its own right below, not silently dropped.

```bash
swift run Censuses cluster-d
python3 Scripts/repro/cluster-d-continuity/classify_continuity_sites.py
python3 Scripts/repro/cluster-d-continuity/classify_continuity_sites.py --self-test
```

## How many entry points, measured against #513's 38

- **31 distinct entry points measured dynamically** (`ClusterD.swift`'s own running total, printed
  at the end of its output).
- **42 named bridge functions classified statically**: 34 request-side (take a continuity as
  input) + 8 result-side (report a measured continuity back to Swift). Adding the 3 trivial
  one-line alias forwards #485 already covered (`OCCTCurve3DContinuity`/`OCCTCurve2DContinuity`/
  `OCCTSurfaceContinuity`, each `return OCCTxxxGetContinuity(x);` and nothing else) gives **45**,
  close to #513's own opening count of 44. The two counts differ because #513 counted a function
  and its ABI-compatibility alias as two members of "44 total, 6 audited"; this census counts the
  alias as the same finding as the function it forwards to and reports it once.
- **#513's own "38 unaudited" is stale, not wrong at the time it was written.** #490's PR comment
  ("Flagged in #513's census; fixed here because it is the same defect this issue is about") shows
  at least two of #513's named live defects (`OCCTFilletBuilderSetContinuity`'s raw cast,
  `OCCTThruSectionsSetContinuity`'s old 0/1-only reading) were fixed as PART OF #490's own PR,
  which also consolidated 19 decoders into the 3 named above. Measuring the CURRENT tree rather
  than trusting #513's text is the entire point of this census, and it is why the table below
  looks different from #513's own.

## The four encodings, as measured (today: five families, one is not really a fourth "encoding")

| family | decoder | domain | saturates at |
|---|---|---|---|
| `SurfaceContinuity` (g0/g1/g2) | `occtGeomAbsFromSurfaceContinuity` | filling family (`OCCTFillingAddEdge`/`AddFreeEdge`/`AddEdgeWithSupport`, `OCCTShapeFill*`) | C1 (order >= 2) |
| `ParametricContinuity` (c0-c3) | `occtGeomAbsFromParametricContinuity` | 17 request-side sites (split/approx/restriction/loft/fillet/divide families) | CN (raw >= 4) |
| analysis order (0-4, interleaved) | `occtGeomAbsFromAnalysisOrder` | `LocalAnalysis_Curve/SurfaceContinuity` via `continuityWith(order:)` | C2 (raw >= 4, i.e. `.c3`/`.cN` both saturate to `.c2`) |
| literal derivative order (NOT a `GeomAbs_Shape`) | none -- #480 rules decoding this is a bug | the four `*KnotSplitting` analyzers, 9 Swift entry points | the geometry's own degree, not the enum's ceiling |
| literal `GeomPlate_PointConstraint`/`CurveConstraint` order (NOT a `GeomAbs_Shape` either) | none | `OCCTShapePlateCurves`/`PlatePointsAdvanced`/`PlateMixed` | `[-1, 2]`; anything outside is clamped, not decoded |

Measured today, this is **five families**, not four -- but two of the five (the knot-splitting
literal order and the plate literal order) are not "encodings" of a `GeomAbs_Shape` at all; they are
two DIFFERENT raw pass-throughs into two DIFFERENT OCCT APIs' own literal-integer conventions, which
happen to numerically coincide with `SurfaceContinuity`'s/`ParametricContinuity`'s own raw values at
the low end without ever being decoded through either. #480's own addendum comment on #513 already
flagged this as "a fifth request-side encoding" before this census existed; measuring confirms it and
adds that the plate family is a SIXTH such pass-through, structurally identical in kind to the
knot-splitting one but into a completely different OCCT class.

The genuinely interesting number is **3**: the three canonical `GeomAbs_Shape` decoders #490 already
converged the bridge onto. #513's "four incompatible encodings" pre-dates that convergence.

## Knot-splitting family: one contract, confirmed across all five entry points on one fixture

A cubic BSpline (4 simple interior knots, degree 3) fed identically to
`Curve3D.continuityBreaks`, `Curve2D.splitIndicesAtDiscontinuities`,
`LawFunction.knotSplitting`/`knotSplitParameters`, and `Surface.knotSplitting` (both directions at
once):

| continuity | Curve3D | Curve2D | LawFunction (indices) | LawFunction (params) | Surface (u/v) |
|---|---|---|---|---|---|
| c0 | 2 | 2 | 2 | 2 | 2/2 |
| c1 | 2 | 2 | 2 | 2 | 2/2 |
| c2 | 2 | 2 | 2 | 2 | 2/2 |
| c3 | 6 | 6 | 6 | 6 | 6/6 |

Byte-identical across every entry point at every level. #480's claim ("all four run a byte-for-byte
identical algorithm") is confirmed, not cited, and extended to the fifth entry point
(`LawFunction.knotSplitParameters`) #480's own text did not separately measure.

## ParametricContinuity: saturation confirmed live, at every raw-Int-reachable site

Probing `-1, 0, 1, 2, 3, 4, 5, 99` against a cubic BSpline with one genuine kink (multiplicity 3 at
one interior knot -- a real C0-but-not-C1 discontinuity):

`Curve3D.splitByContinuity(criterion:)` piece counts: `-1`->1, `0`->1, `1`->2, `2`->2, `3`->5,
`4`->5, `5`->5, `99`->5. Negative saturates to C0 (whole curve, one piece -- a BSpline is always at
least C0). `1`/`2` (C1/C2) both split only at the genuine kink (2 pieces). `3` and above all
saturate to the SAME 5-piece answer: a cubic can never be more than C2 at a simple knot, so "ask for
C3" and "ask for CN" both mean "split at every interior knot," identically.

`Surface.splitByContinuity` and `Surface.splitSurfaceByContinuity` -- **the #438-shaped duplicate
this census found beyond #513's own list**: two public Swift APIs, two separate bridge functions
(`OCCTSurfaceSplitByContinuity`, struct-return; `OCCTSplitSurfaceContinuity`, out-param return),
both wrapping `ShapeUpgrade_SplitSurfaceContinuity`. `Surface.swift`'s own doc comment on
`splitSurfaceByContinuity` already says the two "used to disagree" and "both now agree" (#490).
Measured across all 8 probes on the identical fixture: **AGREE at every probe.** #490's convergence
claim holds today.

`FilletBuilder.setContinuity`/`ThruSectionsBuilder.setContinuity`: both accept every probed value
without crashing (matching the doc comments' own claim that OCCT accepts every value here), but
neither produces an OBSERVABLE difference in the resulting volume on the fixtures tried (a
single-edge box fillet; a two-circle loft) -- this measures "does the fix survive an out-of-range
integer," not "which class did the request decode to," which the static classifier already answers
directly for both (`ParametricContinuity`, confirmed).

`bsplineRestriction` vs `bsplineRestrictionAdvanced` (typed): identical volumes at every
`ParametricContinuity` case on the same fixture. #490's headline claim (these two entry points used
to drive the identical OCCT operation off two different numberings) is confirmed fixed, not merely
asserted.

## SurfaceContinuity family: filling and plate agree on the RAW VALUE, disagree on WHAT consumes it

`Shape.fill(boundaries:parameters:)` on a 4-edge free-standing quad: `.g0` builds (area
108.451979); `.g1`/`.g2` both return `nil`. Expected, and documented: "Free-standing wires have no
surface to be tangent to, so fill positionally" is the API's own doc comment, and this fixture has
no support faces at all.

`FillingSurface.add(edge:continuity:)` on the first 4 edges of a plain box: `.g0`/`.g1`/`.g2` all
build, and `g0Error`/`g1Error`/`g2Error` all report exactly `0.0` regardless of the requested
continuity. This is a fixture limitation, reported as one rather than smoothed over: those 4 edges
plausibly bound one of the box's own planar faces, so any degree/segment budget fits it exactly at
every continuity asked -- the fixture cannot distinguish g0 from g2 here, not because the encoding
does not, but because a flat quad gives every continuity level the same trivial answer.

### #437, reproduced directly against the current tree

| constraint kind | g0 | g1 | g2 |
|---|---|---|---|
| point (`plateSurface(through:orders:)`) | built | built | **nil** |
| curve (`plateSurface(constrainedBy:continuity:)`) | built | nil | nil |

`.g2` fails for POINT constraints, matching #437 exactly (`GeomPlate_PointConstraint` throws above
order 1). The curve constraint's own `.g1`/`.g2` both return nil on THIS fixture (a plain circle,
which measures a separate, tolerance/geometry-shaped failure, not #437's own point-vs-curve claim --
#437's own ground-truth table already establishes curve constraints accept order 2 directly against
`GeomPlate_CurveConstraint`, so this fixture's g1/g2 failures are the `GeomPlate_BuildPlateSurface`
solver declining to converge on an unconstrained free circle, not the same defect).

A mixed call (one `.g2` point among otherwise-`.g0` constraints) fails the WHOLE call; one `.g2`
curve among otherwise-`.g0` constraints also fails on this fixture (see the curve caveat above).
Source read, not measured further: `OCCTShapePlateCurves`/`PlatePointsAdvanced`/`PlateMixed` all
clamp the raw `SurfaceContinuity` value directly into `GeomPlate_PointConstraint`/
`CurveConstraint`'s own literal order parameter (`if (order > 2) order = 2;`) -- there is no
`occtGeomAbsFrom*` call anywhere in any of the three, confirmed by the static classifier
independently.

## AnalysisOrder: saturates at C2, confirmed through the TYPED entry point alone

`ContinuityClass` is `CaseIterable` over all seven `GeomAbs_Shape` ordinals (through `.cN`), and
`continuityWith(order:)` takes it directly -- so `.c3`/`.cN`, which `occtGeomAbsFromAnalysisOrder`
saturates down to `.c2`, are reachable WITHOUT the deprecated raw-`Int` overloads #490 replaced. This
census does not exercise those deprecated overloads at all (see `ClusterD.swift`'s own header
comment on the point: the first draft reached for them before noticing the typed API already covers
the saturating cases).

`Curve3D.continuityWith`, smooth-junction fixture, every `ContinuityClass` requested, effective
order read back: `c0`->c0, `g1`->g1, `c1`->c1, `g2`->g2, `c2`->c2, `c3`->**c2**, `cN`->**c2**.

`Surface.continuityWith` needed a fixture with curvature in BOTH parametric directions, not one:

- **Identical planes** (the existing `identicalPlanes` test's own fixture): `.c2` and above return
  `nil`. Expected and documented (`identicalPlanes`'s own comment: "Planes have no second
  derivative, so the `.c2` default is NullSecondDerivative").
- **Identical cylinders**, tried next: `.c2` and above STILL return `nil`. Reading
  `LocalAnalysis_SurfaceContinuity::SurfC2` directly (`Libraries/occt-src`, not shipped in this
  release's own headers) explains why: it requires a nonzero SECOND derivative in BOTH parametric
  directions on BOTH surfaces. A cylinder's height parametrization is a straight line, so `D2V` is
  exactly zero even though `D2U` (around the curved direction) is not -- the same failure mode as a
  plane, from the other axis.
- **Identical spheres** (curvature in both directions): `c0`->c0, `g1`->g1, `c1`->c1, `g2`->g2,
  `c2`->c2, `c3`->**c2**, `cN`->**c2**. Saturation confirmed, matching the curve side exactly.

## Result side: two different OCCT calls answer "what continuity across this edge," one migrated

`Shape.continuity(edge:face1:face2:)` (`OCCTBRepToolContinuity`, `BRep_Tool::Continuity`, raw `Int`,
NOT migrated) vs `Shape.continuityClassOfFaces(edge:face1:face2:)` (`OCCTBRepLibContinuityOfFaces`,
`BRepLib::ContinuityOfFaces`, `ContinuityClass`, migrated by #495):

| fixture | `Shape.continuity` (raw) | `continuityClassOfFaces` |
|---|---|---|
| box sharp edge | 0 | c0 |
| filleted box, G1 join | 1 | g1 |
| cylinder seam (self-pair) | **0** | **cN** |

The first two agree (0 and c0 are the same class; 1 and g1 are the same class). **The cylinder
seam disagrees.** Two hypotheses were tried, in order, and reported honestly rather than settling
for the first plausible one:

1. *"`BRep_Tool::Continuity` reads a cached flag `BRepLib::EncodeRegularity` has to write first,
   and a raw `Shape.cylinder()` never ran it."* Tested directly: `Shape.encodingRegularity()` on
   the same cylinder, then re-measuring the identical self-paired seam edge. **Still reports 0.**
   This hypothesis does not hold.
2. Reading `Issue495FaceContinuityTests`'s own comment again narrows it instead:
   `BRepLib::ContinuityOfFaces` "short-circuits to `GeomAbs_CN` when the two faces are the same
   face and the surface is elementary" -- a special case in THAT function's own algorithm, not a
   generic cached-vs-computed distinction. `BRep_Tool::Continuity` has no such shortcut, and a seam
   edge apparently never receives an explicit stored continuity value through either code path.

This is reported as a **narrowed, unconfirmed mechanism**, not a finding dressed up as settled: the
source for `BRep_Tool::Continuity`'s own storage lookup is not shipped in this release's headers
(only `.hxx`, no `.cxx`), so it could not be traced further inside the time this census had. The
disagreement itself, plus the disproof of the first hypothesis, is the useful output.

`Shape.maxContinuity(edge:)` on the same box edge: 0, agreeing with the box row above.

Raw `continuity`/typed `continuityClass` on analytic fixtures: an analytic line (3D and 2D) and an
analytic plane all report `6`/`cN`. A BSpline curve built with a mult-2 interior knot on a cubic
(the exact fixture `Continuity.swift`'s own doc comment for `continuityClass` uses) reports `2`/`c1`,
matching that doc comment's own worked example exactly. `Curve3D.bezierContinuity` on a cubic Bezier
reports `6` (a Bezier curve is analytic -- CN -- by construction).

## `BRepGraph.edgeMaxContinuity`: the live stub, confirmed rather than assumed

`OCCTBRepGraphEdgeMaxContinuity` (`OCCTBridge_BRepGraph.mm`) reads, in full:

```cpp
int32_t OCCTBRepGraphEdgeMaxContinuity(OCCTBRepGraphRef, int32_t) { return 0; }
```

0 is also `GeomAbs_C0`, an ordinary answer, so a single call proves nothing by itself -- the stub
and a real C0 measurement are indistinguishable at one call site. What proves it: **every edge on a
shape whose seam is genuinely CN reports 0 through the graph** (measured: all 3 edges of a cylinder,
via `BRepGraph(shape:).edgeMaxContinuity(_:)`), while `Shape.maxContinuity(edge:)` -- the
shape-based sibling `OCCTBRepGraphEdgeMaxContinuity`'s own comment names as the working replacement
-- reports `[0, 6, 0]` for the identical cylinder's three edges. The graph path is not reporting a
boring C0; it cannot report anything else.

**It is blocked upstream, not merely unattended**, which changes what the follow-up is. The comment
directly above the stub says so:

> OCCT 8.0.0p1: edge continuity is conceptually the `BRepGraph_LayerRegularity` layer, but that
> class is broken in p1 (uncompilable header, absent from `libOCCT`), so the graph path is
> unavailable. Use the shape-based `Shape.maxContinuity` (`BRep_Tool::MaxContinuity`) instead.

Measured against the pinned `V8_0_1` rather than the p1 that comment describes, and it is **stronger
than the comment says**: `BRepGraph_LayerRegularity` is not broken there, it is **absent**. Zero
files under `Libraries/occt-src` match the name, zero source files reference it, and it is not in
the shipped `OCCT.xcframework` headers.

So the follow-up is not "write the implementation" and not "re-check whether it compiles". The class
does not exist in the kernel this tree pins, so the graph path cannot be implemented at all until
upstream adds it. That makes the honest-stub doc comment the whole of the near-term work, and the
implementation an upstream question rather than a local one.

This is #513's one live defect that has NOT been fixed since #513 was filed (`FilletBuilder.
setContinuity` and `OCCTThruSectionsSetContinuity` were, as part of #490's own PR). It has also not
been given the honest-stub documentation treatment its sibling `OCCTBRepGraphSetEdgeRegularity` /
`BRepGraph.setEdgeRegularity(_:face1:face2:continuity:)` already has (a `- Important:` doc comment
stating plainly "This always returns `false`... tracked by #513"). `edgeMaxContinuity`'s own doc
comment still reads "Get the maximum continuity order of an edge (GeomAbs_Shape enum as Int)," with
no caveat, which is the more urgent gap: a caller has no way to discover this from the API surface
alone.

## Guard-removal matrix

`classify_continuity_sites.py --self-test` proves each classification by removing the textual cue
and confirming the label actually moves, not just that it once printed correctly:

```
extract_body: call-site-only text has no definition to find                          : pass
extract_body: finds the real definition                                              : pass
SurfaceContinuity fixture classifies SurfaceContinuity                               : pass
SurfaceContinuity GUARD REMOVED classifies RAW (proves the case, not a fixed label)  : pass
ParametricContinuity fixture classifies ParametricContinuity                         : pass
ParametricContinuity GUARD REMOVED classifies RAW                                    : pass
AnalysisOrder fixture classifies AnalysisOrder                                       : pass
AnalysisOrder GUARD REMOVED classifies RAW                                           : pass
special-case fixture classifies ParametricContinuity + special-case                  : pass
special-case GUARD REMOVED (decoder call kept) classifies plain ParametricContinuity : pass
raw pass-through fixture (no decoder, #480's own contract) classifies RAW            : pass
result-cast fixture classifies RAW CAST (int32_t)                                    : pass
result-cast GUARD REMOVED classifies OTHER                                           : pass

All 13 self-test checks passed.
```

Every one of the classifier's five output labels (`SurfaceContinuity`, `ParametricContinuity`,
`AnalysisOrder`, the special-case suffix, `RAW (no decoder call)`) has its own present/removed pair
above except the RAW label itself, which is the documented baseline (#480's own contract, not a
guard to remove) and the result-side `RAW CAST`/`OTHER` pair, which has one of its own. No label is
asserted only by a fixture that happens to produce it; each one's removal is shown to change the
answer.

## Where the two methods disagree

**Nowhere, this time.** Cluster A and Cluster B's own static classifiers were each written before
full verification and each found genuine blind spots against the dynamic measurement. This
classifier's function list was assembled by reading every site's source first (recorded inline in
`ClusterD.swift`'s own comments, e.g. the `occtApproxCurve`/`occtApproxSurface` static-helper
indirection, and `OCCTShapeUpgradeDivideContinuity`'s special case), so by the time it existed there
was nothing left for it to discover that the dynamic half had not already confirmed. Recorded here
rather than omitted, since a census that only ever reports disagreements would misrepresent how
often they actually occur.

## Are #437 and #438 the same defect?

**No -- and #667's framing ("the other members are instances of that [shared root], not independent
bugs") is right for one and wrong for the other.**

- **#437 IS an instance of the shared root.** It fires because `SurfaceContinuity`'s raw value is
  forwarded as a LITERAL `GeomPlate_PointConstraint`/`CurveConstraint` order with no `GeomAbs_Shape`
  decode step at all -- one of the two raw-pass-through families this census's own table lists
  alongside the three canonical decoders. The defect (`.g2` rejected for point constraints) is a
  genuine OCCT domain restriction (`GeomPlate_PointConstraint` throws above order 1) surfacing
  through that pass-through, exactly the shape #513/#667 describe.
- **#438 is NOT an instance of it.** `divided(at:)` and `dividedByContinuity(criterion:)` both
  correctly decode their continuity argument through the SAME canonical
  `occtGeomAbsFromParametricContinuity` (confirmed by the static classifier, and by this census's
  own measurement: `Shape.ContinuityLevel`'s c0-c3 values agree with `ParametricContinuity`'s at
  every probed level in the divide grid above). The reason they disagree (`nil`/4 faces/4
  faces/25 faces vs a flat 4 faces at every level, in the divide-family measurement above) is that
  the two set DIFFERENT criteria on `ShapeUpgrade_ShapeDivideContinuity` -- `divided(at:)` sets
  boundary, pcurve AND surface criteria plus surface-segment mode; `dividedByContinuity` sets only
  the boundary criterion, with a tolerance the other omits. That is an API-surface duplication
  question (which #438's own title names correctly: "two public APIs over one OCCT class"), not an
  encoding mismatch. Fixing #437 (give the plate family a genuine decode step, or document the
  domain restriction) would not touch #438 at all, and vice versa.

## Should #513 close?

**Yes**, once this PR merges. #513's own ask was to turn its prose census into an executable
artifact; that now exists under this directory and `Scripts/repro/censuses/ClusterD.swift`. Beyond
that:

- Its two named "live defects" are one fixed (`FilletBuilder.setContinuity`,
  `OCCTThruSectionsSetContinuity`, both landed as part of #490's own PR, which cites #513 by number
  in its own source comment) and one still open (`BRepGraph.edgeMaxContinuity`'s stub) -- small
  enough to track as a follow-up rather than block this issue's own closure.
- Its "four incompatible encodings" framing predates #490's consolidation to three canonical
  decoders; measured today, the honest count is "three decoders plus two structurally different
  literal pass-throughs," which is a different (and better) shape than #513's own text describes.
- Its two named instances (#437, #438) remain open on their own, correctly -- this census does not
  fix either, per #667's own instruction.
- The one open decision #513 raised and this census did not resolve -- the null/failure sentinel
  policy on the result side (0 is both "genuine C0" and "failed/null," on every raw-cast result
  function measured above) -- is a design decision, not a census finding, and is better tracked
  under its own follow-up than kept open against a census issue whose own job is done.

## Corrections to #513's own text

- **"44 continuity-related bridge functions... 38 unaudited"**: measured as 42 distinct functions
  (34 request + 8 result) plus 3 trivial aliases = 45 total, not 44 -- close, not exact, and #513's
  own text already anticipated this kind of drift ("a scan turned up... in total"), not a claim to
  hold it to precisely.
- **"Four incompatible request encodings"**: today, three canonical decoders (post-#490) plus two
  structurally different raw pass-throughs (knot-splitting's literal derivative order; the plate
  family's literal `GeomPlate` order) -- five families if every one is counted, three if only the
  actual `GeomAbs_Shape` decoders count. #480's own addendum comment on #513 already flagged the
  fifth; this census confirms it and adds the plate family as a sixth structurally-identical-in-kind
  pass-through #480's comment did not separately name.
- **The `FilletBuilder.setContinuity`/`OCCTThruSectionsSetContinuity` live defects**: fixed since
  #513 was filed, as part of #490's own PR (confirmed by reading the current source, which cites
  #513 by number at both sites).

## Verify

```bash
swift build                                    # 0 errors, no OCCTSWIFT_LOCAL, pinned v2.0.0-kernel.1
swift test                                     # full suite
swift run Censuses cluster-a                   # still 45 rows, byte-identical
swift run Censuses cluster-b                   # still 16 rows, byte-identical
swift run Censuses cluster-d                   # this census
python3 Scripts/check-bridge-index.py
python3 Scripts/check-null-handle-guards.py
python3 Scripts/check-docs-defaults.py
python3 Scripts/count-operations.py
python3 Scripts/check-bridge-index.py --self-test
python3 Scripts/check-null-handle-guards.py --self-test
python3 Scripts/check-docs-defaults.py --self-test
python3 Scripts/repro/cluster-d-continuity/classify_continuity_sites.py --self-test
```
