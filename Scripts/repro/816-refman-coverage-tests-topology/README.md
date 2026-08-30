# #816: refman coverage audit, tests, Shape/Topology (Pass 5b of #807/#819)

Two files, plus this README:

| file | what it is |
|---|---|
| `derive_lane.py` | re-derives #808's 66 `ok` classes and traces class -> bridge function -> Swift declaration -> in-lane test usage, mechanically. |
| `refman_census.py` | the census: `classify()` resolves the 6 mechanical anomalies against a whole-suite check and two curated overrides; the over-coverage sweep scans the five lane targets' comments for claims about OCCT internals and adjudicates every one it finds. |

```bash
python3 Scripts/repro/816-refman-coverage-tests-topology/derive_lane.py                # the trace, by class
python3 Scripts/repro/816-refman-coverage-tests-topology/derive_lane.py --verbose      # + every (bridge fn, swift decl) pair, tagged tested/untested
python3 Scripts/repro/816-refman-coverage-tests-topology/derive_lane.py --reverify-808 # re-run #808's own lane check first
python3 Scripts/repro/816-refman-coverage-tests-topology/refman_census.py              # the full census: under-coverage table + over-coverage sweep
python3 Scripts/repro/816-refman-coverage-tests-topology/refman_census.py --over-coverage        # sweep only
python3 Scripts/repro/816-refman-coverage-tests-topology/refman_census.py --over-coverage --verbose  # + which ADJUDICATED_CLAIMS entry matched each candidate
python3 Scripts/repro/816-refman-coverage-tests-topology/refman_census.py --self-test   # proves every classification/detection mechanism is load-bearing
```

`derive_lane.py` takes ~25-30s (a reverse call-graph built once over every bridge function to trace
through internal `static`/`inline` helpers, not a fast gate-script loop); everything else is
seconds. Both scripts run from any cwd and report SKIPPED for the one check that wants
`Libraries/OCCT.xcframework` (`--reverify-808`), which this worktree does not have.

## The lane, and what "documented+wrapped" means here

#808 (Pass 2a) already answered the source-side question for Shape/Topology core: 151 OCCT classes
across `TopoDS_*`/`TopExp*`/`TopTools_*`/`BRep_*`/`BRepBuilderAPI_*`/`BRepPrimAPI_*`/
`BRepAlgoAPI_*`/`BRepCheck*`, of which **66 are `ok`** (documented AND wrapped) and 85 are
`deliberate, recorded`. Re-run here first (`derive_lane.py --reverify-808`) and confirmed clean
against the pinned headers on 2026-08-31 (SKIPPED in this worktree, which has no `Libraries/`;
confirmed instead by running #808's own script directly, which reports the same 66/85/0 split and a
clean `--reverify-lane`).

This pass's subject is exactly those 66. #816's own text draws the line precisely: "documented+
wrapped, no test" is this pass's finding; "not wrapped" or "not documented" is #808's. Re-litigating
either question here would blur which pass owns it, so the 85 `deliberate, recorded` classes are out
of scope by construction, not overlooked.

## The trace, and why it needed two rounds of fixing before the numbers meant anything

`derive_lane.py`'s docstring has the full mechanism (class -> bridge function -> Swift declaration
-> in-lane test), but the first working version of it was wrong twice, both caught by reading its
own output rather than trusting a clean run:

1. **The Swift-side function-boundary regex broke on a tuple parameter type.**
   `Shape.fromMesh(points:triangles:)` (`triangles: [(Int32, Int32, Int32)]`) has a `)` inside its
   own parameter list before the list's real close; the naive `\([^)]*\)` regex (the same shape
   `Scripts/census-unmeasured-values.py`'s own `SWIFT_FUNC` uses, which is fine for THAT script's
   purpose but not this one) closed on the tuple's `)` three characters early, so the whole
   declaration went undetected and `OCCTShapeFromMesh`'s very real call two lines below reported as
   "no Swift caller found". Fixed with a manual paren-balanced scanner instead of a bigger regex.
2. **The class-mention test only looked inside `OCCT*`-prefixed function bodies**, missing a class
   referenced only from an internal `static`/`inline` helper the public functions call (
   `BRepCheck_Edge`/`Wire`/`Shell`/`Vertex`, constructed in `checkSubShape()`, called by
   `OCCTCheckEdge`/`Wire`/`Shell`/`Vertex`). Fixed by building a reverse call graph over every C
   function in the bridge (not just the `OCCT*`-named ones) and walking it from each class's direct
   mentions back up to the public entry points that reach them, transitively.

Both were caught by manually reading the 11 anomalies the first clean run produced and finding real
mechanisms behind each, not by assuming a clean run meant a correct one. After both fixes, 6
anomalies remained, and every one of those got the same treatment: read, not classified by the
tool's first answer.

## Result

| verdict | count |
|---|---|
| `ok` | 65 |
| `deliberate, recorded` | 0 |
| `under` | 1 (filed as [#1392](https://github.com/SecondMouseAU/OCCTSwift/issues/1392)) |

Of the 65 `ok`: 60 are tested directly by one of the five lane targets, 4 are tested correctly in a
SIBLING domain target this lane does not own, and 1 (`BRepBuilderAPI_MakeShape`) is a mechanical
false negative the trace cannot see by construction, confirmed tested in-lane by hand.

## The under-coverage findings, in detail

**Five of the six mechanical "untested" hits are not findings.** Each capability IS tested, just by
a different domain target than this lane's five, and that placement is *correct* per CLAUDE.md's
own Test Layout ("add a new suite to the domain target that best matches it"):

| class | Swift surface | untested by this lane; tested in |
|---|---|---|
| `BRepBuilderAPI_GTransform` | `Shape.gTransformed`/`nonUniformScaled` | `OCCTMathTests/{NonUniformScaleTests,TransformExpansionTests}.swift` |
| `BRepBuilderAPI_MakeEdge2d` | `Shape.edge2dFromCircle`/`edge2dFromLine`/`edge2d` | `OCCTGeom2dTests/{MakeEdge2dTests,Issue553GccZeroRadiusTests}.swift` |
| `BRepBuilderAPI_MakeShapeOnMesh` | `Shape.fromMesh` | `OCCTMeshTests/OCCTMeshTests.swift` |
| `BRepPrimAPI_MakeRevolution` | `Shape.revolution(meridian:...)` | `OCCTSurfaceTests/{SurfaceSweptTests,RevolutionFromCurveTests}.swift` |

A stricter reading of "no test in this lane's five targets" would flag all four as `under`. That
reading was rejected on purpose: filing a "missing test" issue for a capability with real, correct,
on-target tests would be exactly the manufactured-finding failure #816's own instructions warn
against ("Do not manufacture findings to look thorough"). `refman_census.py`'s `classify()` checks
the whole `Tests/` tree as a second pass specifically so this is a visible, evidenced verdict rather
than a silent assumption -- see its docstring and `SIBLING_DOMAIN_NOTE`.

**The sixth, `BRepBuilderAPI_MakeShape`, is a real mechanical false negative**, not a lane-placement
artifact. The class name appears in this bridge only inside a constructor parameter type
(`OCCTBooleanHistory(std::unique_ptr<BRepBuilderAPI_MakeShape> theOp, ...)`,
`OCCTBridge_Modeling_Boolean.mm`) and a field declaration of the same type, never inside any
function's *executable body text*, which is the only place the trace's class-mention test looks (by
design; widening it to scan whole-file text, like #808's own `_is_wrapped`, would have hidden the
one genuine finding below behind noise). The capability it represents -- a type-erased base letting
`OCCTBooleanUnionWithHistory`/`SubtractWithHistory`/`IntersectWithHistory`/`SplitWithHistory` (and
five more) report `Generated()`/`Modified()` history uniformly -- is heavily tested **in this lane**:
`Tests/OCCTModelingTests/{BooleanHistoryTests,BooleanFullHistoryTests,HistoryExtendedTests,
Tier2HistoryTests}.swift` all exercise `Shape.unionWithFullHistory`/`subtractedWithFullHistory`/
`fuseWithHistory` and siblings, confirmed by grep and by reading the call sites, not assumed from
the class's name. `NO_DIRECT_MENTION` in `refman_census.py` is the curated override, with its
evidence.

**The one real finding: `BRepCheck_Solid`.** `OCCTCheckSolid`
(`OCCTBridge_Healing_Analysis.mm:1057`) is a real, working, already-implemented bridge function --
it walks every `TopAbs_SOLID` in a shape and runs `BRepCheck_Solid` on each, mirroring
`OCCTCheckEdge`/`Wire`/`Shell`/`Vertex` (`OCCTBridge_Healing_Fix.mm`) -- declared publicly in
`OCCTBridge_Healing.h:631`, and **has zero Swift callers anywhere in `Sources/OCCTSwift`**, checked
by grep across the whole tree, not just this lane. So this is not merely untested, it is untestable
as things stand: there is no Swift entry point for a test to call. `OCCTCheckShape`
(`OCCTBridge_Healing_Analysis.mm:1097`, backing the well-tested `Shape.checkResult`) localizes
errors by walking only `TopAbs_FACE` and `TopAbs_EDGE` results from its `BRepCheck_Analyzer`, never
`TopAbs_SOLID`, so a solid-only defect could in principle report `isValid: false, errorCount: 0,
firstError: nil`, the same internally-contradictory shape this project's `#726`/`#609`/`#583`
census entries exist to catch elsewhere -- **unconfirmed on a real fixture**, plausible from reading
the code, not asserted as fact.

**Disposition: filed, not fixed here.** [#1392](https://github.com/SecondMouseAU/OCCTSwift/issues/1392).
The missing wrapper is small (a few lines, following `checkEdge`/`checkWire`'s exact pattern), but a
test proving it actually *works* needs a genuinely invalid solid `BRepCheck_Solid` specifically
would flag (not one a face/edge check already catches), which is real reproduction work outside a
test-coverage census, following this project's established file-and-defer practice for a finding
that needs its own investigation (`#905`, `#913`, `#1018` are the same shape: found during an audit,
filed with the evidence, deferred to a dedicated pass). `docs/occtswift-wrapping-gaps.md` was
deliberately NOT touched for this: that file's convention is an OCCT capability we do not wrap at
all, and `BRepCheck_Solid` IS wrapped (that is why #808 marked it `ok`); the gap this pass found is
narrower and different -- a wrapped bridge function with no Swift entry point -- and #1392 is where
it is tracked.

## The over-coverage sweep

`find_over_coverage_candidates()` scans every `///`/`//` (and block-comment `*`-continuation)
comment line in the five lane targets for a claim-word (`always`, `never`, `guarantee(s/d)`,
`invariant`, `exactly`, `cannot`, `must be/equal/not/match/satisfy`, `is defined as`, `by
definition`, `per the OCCT/refman`, `OCCT guarantees/promises/documents/defines/requires`, `own
header documents`) or a tolerance-shaped number (scientific notation, or `0.00...`) co-occurring
with a mention of an OCCT class family this bridge actually uses (`TopoDS`, `BRep*`, `ShapeFix`,
`ShapeAnalysis`, `ShapeUpgrade`, `Geom*`, `GCPnts`, `GProp`, `BOPAlgo`, `Standard`, ...).

**37 candidates, on 2026-08-31, over 612 files / ~47,300 lines in the five targets.**

| verdict | count |
|---|---|
| confirmed accurate (checked against `occt-refman@8.0.1` or, where the refman has no entry, the pinned kernel source) | 8 |
| historical narrative about an already-fixed bug in this project's OWN code, not an OCCT contract claim | 29 |
| confirmed OVER-coverage (a claim the refman contradicts) | **0** |

Every one of the 37 is hand-adjudicated in `ADJUDICATED_CLAIMS`, keyed by `(file, distinctive
substring)` so a re-wrapped comment still matches and a genuinely NEW candidate (the lane's text
changed since) is reported as "needs a human read" rather than silently passed or silently failed.
Eight got a real refman/source check because they make a specific, checkable claim about an OCCT
class's own behaviour that this project's docs/tests do not already carry evidence for:

| claim | checked against | verdict |
|---|---|---|
| `BRepLib::ContinuityOfFaces` never returns `GeomAbs_C3` (`Issue495FaceContinuityTests.swift`) | pinned source, `BRepLib.cxx:2197-2419` | confirmed -- every explicit assignment in the function is C0/G1/C1/G2/C2, plus an elementary-seam early return of CN and a C2->CN promotion; C3 is assigned nowhere |
| `BRep_Tool::MaxTolerance` returns 0 for `TopAbs_SOLID` (`Issue833MaxToleranceEncodingTests.swift`) | pinned source, `BRep_Tool.cxx:1830-1862` | confirmed -- the function branches on FACE/EDGE/VERTEX only; SOLID falls through every arm with the accumulator at its initial 0.0 |
| `BRepFilletAPI_MakeFillet::Add` silently skips an unfilletable edge (`Issue639FilletDeclinedEdgeReportTests.swift`) | `occt-refman@8.0.1` | not a refman claim: the comment says "measured" and cites its own probe; the refman's `Add()` entries document only what a successful call builds, contradicting nothing |
| `BRepGProp::SurfaceProperties`'s `Eps > 0.001` triggers non-adaptive integration (`Issue885TotalAreaDivergenceTests.swift`) | `occt-refman@8.0.1` | confirmed, verbatim: "WARNING: if Eps > 0.001 algorithm performs non-adaptive integration" |
| `ShapeAnalysis_FreeBounds.hxx:98`'s `checkinternaledges` defaults `false` (`Issue655FreeBoundsInternalOrientationTests.swift`) | pinned header, line 98 | confirmed, exact line |
| `ShapeFix_Shape::FixFreeFaceMode()` defaults to on (`Issue837FixDetailedModeFlagsTests.swift`) | pinned header | confirmed: "Returns (modifiable) the mode for applying fixes of ShapeFix_Face, by default True" |
| `BRepFeat_HoleTooLong` is set in exactly two places in the kernel (`Issue496CylindricalHoleTests.swift`) | pinned source, `BRepFeat_MakeCylindricalHole.cxx` | confirmed, lines 526 and 667 |
| `BRep_Tool::CurveOnSurface` projects onto a plane with no stored pcurve (`Issue1058OuterBoundRefusalTests.swift`) | the file's own cited probe, `Scripts/repro/1058-outer-bound-refusal/` | backed by its own investigation (a guard-by-guard prove-the-test-fails table sits in the same file); not re-derived here |

Three of these (`ContinuityOfFaces`, `MaxTolerance`, `FixFreeFaceMode`) came back **empty** from
`occt-refman@8.0.1` via the `context` MCP -- static-utility-style methods with thin or no indexed
doc text -- so the pinned kernel source (`Libraries/occt-src/src/.../*.cxx`/`.hxx`, only present in
the main checkout, not this worktree) is what actually settled them, per CLAUDE.md's own fallback
order.

**The other 29 are historical narrative**, each describing an already-fixed bug in this project's
own bridge code, a Swift struct field, or a test fixture (most cite their own issue number and/or a
`Scripts/repro/` probe directly), not a claim that OCCT's refman promises something. Read in full
context, not matched by keyword alone -- e.g. `Issue772SelfIntersectionAnalysisTests.swift`'s "was
always 0 and never computed" is about `ShapeAnalysisResult.selfIntersectionCount`, this project's
OWN struct field, not an OCCT method; `SelfIntersectingProfileGuard263.swift`'s "OCC_CATCH_SIGNALS
is inert" restates CLAUDE.md's own standing note rather than asserting anything new. None of the 29
states or implies a refman-sourced guarantee, so none needed the deeper check the other eight got.
Every one still has its own `ADJUDICATED_CLAIMS` entry recording *why*, not just a tally.

**Net result: zero over-coverage findings in this lane.** Every claim this sweep found that makes a
checkable statement about OCCT's own documented or source-confirmed behaviour turned out to be
accurate. This is reported as the real, useful result it is, not dressed up as more than it is:
`--over-coverage`'s own output says exactly this ("Confirmed over-coverage... 0").

## Proving the detectors, not just running them

Per `okf/policies/prove-the-test-fails.md`, every mechanism below was broken in the real source,
watched fail, then restored -- not merely reasoned about:

| mechanism | injected defect | self-test result |
|---|---|---|
| `classify()`'s `in_lane_tested` branch | removed the early return | case `1a` failed (`got 'under', want 'ok'`) |
| `find_over_coverage_candidates()`'s comment-line gate | removed `if not is_comment_line(line): continue` | **the intended case passed anyway** -- see below |
| `find_over_coverage_candidates()`'s OCCT-class-mention gate | removed `if not has_class: continue` | two cases failed as expected |

**The comment-gate injection caught a real decorative fixture, on the first try.** The case meant to
prove it (`"claim+class only in CODE, not a comment"`) built a careful fixture string
(`not_a_comment`, `let x = TopoDS_Shape.self  // always true, TopoDS_Shape guarantee`) and then
called `scan()` on an unrelated placeholder (`alwaysTrueForTopoDS_Shape()`, one unbroken identifier
with no word boundary before either token) instead of using it. That placeholder matches neither the
claim-word nor the class-name regex regardless of the comment gate, so removing the gate changed
nothing and the self-test reported PASS while proving nothing -- exactly the failure mode
`prove-the-test-fails.md` describes ("a green removal row is ambiguous, not reassuring") and the two
occasions it cites from this project's own history. Fixed by actually using `not_a_comment` in the
`scan()` call; re-running the same injection against the corrected case failed as it should
(`got 1, want 0`), and restoring the gate returned it to green. The corrected case and its own
in-line comment record this so a future reader does not "clean up" the fixture back into looking
decorative again.

The three curated-table/`gaps.md` branches (`NO_DIRECT_MENTION`, `NO_SWIFT_CALLER`, the
`gaps_text` check) are proven the same way `_selftest_classify()` proves them: pop the real dict
entry, re-run `classify()` on the real key, confirm the verdict (or, for `NO_SWIFT_CALLER`, the
NOTE) changes, restore. Not run as a separate source-editing exercise since they are pure data, and
popping/restoring a dict entry inside the self-test IS the injection for a curated table the same
way editing a source line is the injection for a code branch.

## What this pass did not do

Following #816's own permission to be narrower than the source-side precedent (#811) and say so
plainly, rather than inventing false rigor:

- **No multi-round review history.** This is a single pass's findings, not a record of several
  human review rounds correcting each other over time the way #811's README is. Where this pass's
  OWN self-test caught a real decorative fixture (the comment-gate case above), that is reported
  as what it is: one round, caught once, fixed once.
- **The mechanical trace does not follow a Swift-side shared helper across files** the way #811
  found for `occtPlateApproxSurface`. Not observed in this lane's 66 classes (checked: every
  `tested`/`under` verdict was read against the real call chain, not just trusted from the tool's
  first pass), but not exhaustively searched for either.
- **A class name resolving only to a common word** (`value`, `count`, `type`, ...) is flagged
  `ambiguous-name` by `derive_lane.py`'s design, but the real run found zero such cases in this
  lane's 66 classes, so that path is implemented and self-tested (see `_selftest_classify` and
  `derive_lane.py`'s own `COMMON_NAMES`) but has no real example to show.
- **The over-coverage sweep is scoped to comments and test/suite NAMES**, per #816's own text, not
  to arbitrary `#expect` assertions. A test could in principle pin an over-strict numeric bound with
  no comment at all; that is a different, larger sweep (closer to `census-unmeasured-values.py`'s
  sub-kind 2) and out of scope here.
- **No attempt was made to determine whether `OCCTCheckShape`'s missing SOLID walk is a live bug**
  on a real fixture -- that is explicitly left to whoever picks up #1392, alongside the missing
  `checkSolid` wrapper itself, since both need the same invalid-solid geometry to settle.
