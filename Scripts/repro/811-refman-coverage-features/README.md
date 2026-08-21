# #811: refman coverage audit, features lane (Pass 4a of #807)

Four files:

| file | what it is |
|---|---|
| `derive_lane.py` | the lane, re-derived **by call**. #385's "32 bridge calls" is stale; it is 60. |
| `refman_census.py` | the census. 129 classes, four verdicts, two over-coverage checks, a family-count assertion, a lane re-derivation, and its own self-test. |
| `selftest_removal_matrix.py` | the proof that the self-test's guards are load-bearing. Its first run reported four shapes as decoration: `nested-type` and `base-class-walk` had cases passing for the wrong reason, and `alias-template` and `none-propagation` had no case at all. A fifth, `data-member`, was passing on a field that does not exist. |
| `probe_nlplate_parametrisation.mm` | the behaviour claims no detector can see, measured against the real bridge on three fixtures. `probe-transcript.txt` is its output. |

```bash
python3 Scripts/repro/811-refman-coverage-features/derive_lane.py             # the lane, by call
python3 Scripts/repro/811-refman-coverage-features/derive_lane.py --calls     # + every call, per .mm
python3 Scripts/repro/811-refman-coverage-features/derive_lane.py --substrate # + the unowned packages below it
python3 Scripts/repro/811-refman-coverage-features/refman_census.py           # the table
python3 Scripts/repro/811-refman-coverage-features/refman_census.py --verbose # + matching files
python3 Scripts/repro/811-refman-coverage-features/refman_census.py --reverify-lane
python3 Scripts/repro/811-refman-coverage-features/refman_census.py --verify-pins origin/main
python3 Scripts/repro/811-refman-coverage-features/refman_census.py --self-test
python3 Scripts/repro/811-refman-coverage-features/selftest_removal_matrix.py
```

All run from any cwd, in about three seconds. The checks that read the pinned headers report
SKIPPED rather than passing silently without `Libraries/OCCT.xcframework`, which is the case in CI
and in a fresh clone.

## Result

| verdict | count |
|---|---|
| `ok` | 82 |
| `deliberate, recorded` | 47 |
| `under` | 0 |
| `over` | 42 (the script derives it). 32 corrected here; 8 were fixed on `main` by #1069 mid-review and 2 were this pass's own wrong claims. |

**Before this PR the same table read `ok` 82, `deliberate, recorded` 0, `under` 47**, measured by
running the shipped `classify()` against a worktree at `origin/main`. Three of the 129 were named
somewhere in `docs/occtswift-wrapping-gaps.md`, and two of them, `ChFi3d_FilBuilder` and
`ChFi3d_ChBuilder`, were genuine recorded omissions sharing a bullet with a real reason; the
third, `BRepOffsetAPI_MakePipe`, is named as a wrapped class. All three classify `ok` anyway,
because they are documented elsewhere under `docs/`, so none was ever one of the 47. **Of the 47
classes that needed a reason, none had one.** That is the largest single finding of the pass and
the reason it writes a section rather than a footnote.

## What the lane actually is

#811's `## Lane` names six OCCT packages, 97 headers. Pass 4a (#385) separately settled a nine-file
Swift lane. The two were resolved against each other by `derive_lane.py`, and both moved:

- The nine Swift files call **60** distinct bridge functions, not the 32 #385's scope section
  states. That figure was taken when `GDTInfo.swift` was 29 lines; it is now `GDTRead.swift`
  at several hundred, and `DraftInfo.swift` is gone. **Line counts are deliberately not quoted
  here**: run `derive_lane.py`, which prints them. They moved four times during this pass, once
  for each commit that touched a lane file and once when `main` moved underneath, and each time
  a review round caught a stale figure in this paragraph. A number that changes whenever the
  tree does belongs in the script's output, not in prose beside it.
- The 60 land in six `.mm` files: `OCCTBridge_Document.mm` 32 (all GD&T),
  `OCCTBridge_ProjLib_NLPlate.mm` 15 (all Plate), `OCCTBridge_Curve3D.mm` 6 (Helix),
  `OCCTBridge_Topology.mm` 4, `OCCTBridge_BRepGraph.mm` 2, `OCCTBridge_Modeling.mm` **1**.
- **The inversion #385 warns about is visible in that last figure.** `OCCTBridge_Modeling.mm`, the
  file its first scope pointed at, backs one of the lane's sixty calls.
- The derivation strips Swift comments and string literals before looking for identifiers, and
  that is not cosmetic: three names #385's own scope table treats as calls
  (`OCCTFacesAreAdjacent`, `OCCTFaceGetSharedEdgeCount`, `OCCTFaceGetSharedEdges`) occur **only**
  in comments. `OCCTFacesAreAdjacent` was a real bridge function until #784 removed it; the
  other two are still real and still declared, and nothing in `Sources/OCCTSwift` calls them.
  That is where seven of this pass's over-coverage findings came from.

So the audited lane is **ten packages, 129 classes**: #811's six plus `Plate_`, `NLPlate_`,
`GeomPlate_` and `BRepMAT2d_`, which the Swift lane reaches and which no pass of #807 names.
Fifteen further packages below the lane's public API (the blend solver, the offset and draft
engines, the medial-axis substrate, and the sweep and fill families, **337** headers) are named by
no pass either; they are enumerated with measured reach by `derive_lane.py --substrate` and handed
off rather than absorbed, as #1045.

## What found the over-coverage, and how many candidates were rejected

| source | candidates | true | rejected | false rate |
|---|---|---|---|---|
| `census-doc-occt-attribution.py --lane ...` (#928) | 19 | 18 | 1 | 5.3% |
| `check_method_attributions()` (this file, new) | 5 | 5 | 0 | 0% |
| reading, first review round | 4 | 4 | 0 | |
| reading, second review round | 2 | 2 | 0 | |
| reading, third review round | 2 | 2 | 0 | |
| reading, eighth review round | 4 | 4 | 0 | |
| reading, tenth and eleventh rounds | 7 | 7 | 0 | |

Every candidate was adjudicated against the real bridge body, not against its name. The detector's
own measured rate is **41% over a 40-row uniform sample** (#928) and it was **47.1%** on #810's
lane, so 5.3% here is the outlier and worth saying why: this lane's claims are dense in
`- **OCCT:**` bullets naming one class each, which is the shape the detector resolves best, and
thin in the paired-table-cell and misresolved-subject shapes that produced most of #810's noise.

**The one rejection** is the cross-file shared-helper case. `docs/reference/Shape-Features.md:2272`
attributes `Shape.plateSurface(through:)` to `GeomPlate_MakeApprox`, and it is correct:
`OCCTShapePlatePoints` reaches it through `occtPlateApproxSurface`, declared in
`OCCTBridge_Internal.h` and defined in `OCCTBridge_ProjLib_NLPlate.mm`. The detector follows
helpers within a file and does not follow that one across.

**Unlike #810, the corrections created no new false positives.** Re-running #928 on this lane after
the fixes gives 1, the same rejected candidate, rather than #810's 22-from-16.

One narrowing, stated because it is invisible in that number. `--lane` takes prefixes, and the
underscore-suffixed form (`BRepFeat_`, `ChFi2d_`, ...) misses the four package-level classes that
carry no underscore at all: `BRepFeat`, `ChFi2d`, `ChFi3d`, `LocOpe`. So the 19 candidates cover
125 of the 129. Run without the underscores the count is 2, and the extra candidate
(`ChFi3d::DefineConnectType`, `docs/reference/FeatureRecognition.md`) is a false positive:
`OCCTBridge_BRepGraph.mm` does call it. The defect count is unchanged either way.

## #1069 landed mid-review and fixed eight of these independently

Worth recording, because it changes what this artifact is evidence of.

While this branch was in its review rounds, [#1069](https://github.com/SecondMouseAU/OCCTSwift/pull/1069)
fixed both behaviour defects this pass filed, #1046 (the output's parametrisation) and #1049 (the
double-added base surface), and corrected the same NLPlate doc claims in passing, more thoroughly
than this pass had: `main` now names `Geom_RectangularTrimmedSurface` and the `Plate_D1`/`D2`/`D3`
constraint payloads alongside the classes this pass had corrected.

So eight pins moved to `PRESENCE_EXEMPT_PINS`: the wrong text is no longer on `main`, and asking
`--verify-pins` whether it is there is the wrong question. They are kept rather than deleted, for
two reasons. A regression to the wrong text would be as wrong tomorrow as it was when this pass
found it. And the record of what an audit found should not shrink because someone else fixed it
first; the finding count is 42 either way, and the split says who fixed what.

**Two claims survived #1069 and are corrected here**, both self-contradictions inside entries #1069
itself edited. `docs/reference/Surface-Advanced.md` still called the solver's output a "displacement
field", once in `nlPlateDeformed`'s prose and once in `nlPlateDerivative`'s summary, three
paragraphs above the explanation #1069 added saying `NLPlate_NLPlate::Evaluate` seeds from the input
surface's own value and therefore returns the deformed point rather than an offset. A fix that
corrects a mechanism can leave the word for it behind, and neither detector reads a summary against
the paragraph below it.

## The findings

**The NLPlate constraint family, four methods (since fixed on `main` by #1069, see above).**
`docs/reference/Surface-Advanced.md` attributed
`nlPlateDeformedG1`/`G2`/`G3` to `NLPlate_HPG1Constraint`/`HPG2Constraint`/`HPG3Constraint`. The
pinned refman calls those "PinPoint **(no G0)**" constraints and their constructors take no
position at all (`NLPlate_HPG1Constraint(gp_XY UV, Plate_D1 D1T)`), while the bridge builds
`NLPlate_HPG0G1Constraint(uv, target, d1)`, the "PinPoint G0+G1" form. The page's own prose says
"position and tangent (NLPlate G0+G1)" two lines above, so the prose was right and the attribution
named its opposite. The same four entries also named `GeomPlate_MakeApprox` as the approximator;
`OCCTSurfaceNLPlateG0`/`G1`/`G2`/`G3`/`IncrementalG0` all use `GeomAPI_PointsToBSplineSurface`
(`OCCTBridge_ProjLib_NLPlate.mm:591, 709, 949, 1019, 1080`).

**A class that does not exist.** `Plate_FreeGthenCConstraint`. The pinned header is
`Plate_FreeGtoCConstraint`.

**Five member names that do not exist**, all in `docs/reference/Document-Builders-Fillet.md`, and
all the same mistake: the attribution was written from the **bridge function's own name** rather
than read from the OCCT header. `IsDistAngle` for `IsDistanceAngle`, `GetDists` for `Dists`,
`IsSymmetric` for `IsSymetric` (OCCT spells it with one m), `IsTwoDists` for `IsTwoDistances`, and
`BRepFilletAPI_MakeFillet::NbSimulatedSurf` for `NbSurf`. The bridge calls all five correctly, so
this is doc-only. `measure-dont-assume.md` names this shape exactly: the adjacent identifier reads
as the one you need.

**A behaviour claim, measured false (since fixed on `main` by #1069).**
`docs/reference/Surface-Advanced.md` said "Distinct from
fitting a fresh surface to a point set, the existing parametrisation is preserved."
`OCCTSurfaceNLPlateG0` samples the deformed surface on a fixed 20x20 grid and fits it with
`GeomAPI_PointsToBSplineSurface`, which is literally fitting a fresh surface to a point set.
`probe_nlplate_parametrisation.mm` calls the real bridge function on two fixtures:

When the finding was made, both fixtures returned a surface on `[0, 1] x [0, 1]` whatever the
input's domain was, with a periodic input coming back non-periodic, and the sample parameter fell
outside the output's own domain. The plane was the second construction the policy asks for: the
fixture a uniform point-grid fit is likeliest to reproduce by accident, and it failed too, so the
defect belonged to the fitting step rather than to the cylinder. Tracked as #1046.

**`probe-transcript.txt` beside this file no longer shows that, and that is the point of committing
it.** #1069 fixed #1046 while this branch was in review, so the same probe against the same bridge
now reports the caller's own domain back:

```
=== cylinder, radius 10 ===
input bounds   : u [0, 6.28319]  v [-2e+100, 2e+100]
output bounds  : u [0, 6.28319]  v [-10, 10]
sample (u=1.5708, v=0) inside the output's own domain: yes
```

The probe is a regression witness now rather than a demonstration. Re-run it and read the
transcript; do not read the prose above as current behaviour.

**A second defect, added after the first pre-PR review round and corrected after the twelfth
(also fixed on `main` by #1069).**
`OCCTSurfaceNLPlateG0` and `G1` add the input surface's own point to a value that already
contains it, because `NLPlate_NLPlate::Evaluate` returns the deformed point rather than an
offset, so every sampled point is `2 * base + plate`.

**That doubles size, not only position, and the first version of this probe said otherwise.**
It measured one off-origin fixture and printed no corners for the origin ones, which supported
"only a surface away from the origin is affected" for four review rounds and shipped that
sentence into two doc pages and two Swift doc comments. Measured on both fixtures and both
affected entry points:

When the finding was made, against a working domain of 20 by 20, `G0` on a plane at `x = 100`
returned centre `(200, 0, 5)` and corners `(180, -20) .. (220, 20)`, and `G0` on a plane through the
origin returned a correct centre and corners `(-20, -20) .. (20, 20)`: a 40-by-40 patch. That second
row is the one that mattered, and the one-fixture version of this probe could not see it, which is
how "only a surface away from the origin is affected" survived four review rounds. `G1` measured
identically.

**The committed transcript now shows the fixed behaviour**, since #1069 landed under this branch:

```
  G0, plane at x = 100               centre (100.0000, 0.0000, 5.0000), corners (90.0, -10.0) .. (110.0, 10.0)
  G0, plane through the origin       centre (0.0000, 0.0000, 5.0000), corners (-10.0, -10.0) .. (10.0, 10.0)
```

20 by 20 about the constraint point, on both fixtures and both entry points.

Filed as #1049 rather than fixed here, since it is a behaviour change wanting its own tests; the
reference page and the five in-source doc comments now warn about it. **The audit had rewritten the
doc line for that exact call and walked past it**, and what caught it was a reviewer asking what the
corrected sentence's own mechanism claim rested on. **A later reviewer then caught the correction
itself**, which is why the probe now measures four rows rather than one.

**Present-tense claims about a call path #783 and #784 replaced**, across
`FeatureRecognition.swift`, `docs/reference/FeatureRecognition.md` and three test files. The
count is deliberately not stated: it grew in five separate review rounds, each of which had
written the set up as complete, and every stated figure went stale within a round or two. Run
the census and read `KNOWN_OVER_FINDINGS`. All seven say `OCCTFaceGetSharedEdgeCount` sizes a buffer
that `OCCTFaceGetSharedEdges` then fills, or that `buildGraph()` sizes a buffer at all; since #783
it makes one `OCCTFaceGetSharedEdgeSummary` call and neither of the other two is on its path. Neither detector
can see a tense, and neither looks at a claim naming a **bridge** function rather than an OCCT
class. The bridge header's own comments were correct throughout, in the past tense, which is what
made the Swift-side copies checkable.

**Three were found in this pass's first review round, two more in its second, two more in its
third, and four more in its eighth**, each of those rounds having written the set up as closed.
The round-three pair were in the very file round two had just edited, and two of the round-eight
four were on `withBoss` and `withPocket`, twenty lines below the `withPrism` claim round one
corrected, naming the same wrong class. That is the argument for pinning a family in
`KNOWN_OVER_FINDINGS` rather than only fixing its members: it kept producing them after four
separate declarations that it was closed, and a count is the thing a reader trusts.

## Proving the detectors fail

`selftest_removal_matrix.py` switches off each accepting shape in turn:

```
declares_member baseline: 14/14 cases pass unmodified

  method-call          disabled -> 5/14 cases fail  [load-bearing]
  nested-type          disabled -> 1/14 cases fail  [load-bearing]
  data-member          disabled -> 1/14 cases fail  [load-bearing]
  base-class-walk      disabled -> 2/14 cases fail  [load-bearing]
  alias-template       disabled -> 1/14 cases fail  [load-bearing]
  none-propagation     disabled -> 1/14 cases fail  [load-bearing]

_ATTRIBUTION_RE baseline: 6/6 cases pass with the shipped pattern

  closing-backtick-anchor    imposed -> 2/6 cases fail  [load-bearing]
  no-leading-backtick        imposed -> 1/6 cases fail  [load-bearing]

classify baseline (real tree): {'ok': 82, 'deliberate, recorded': 47, 'under': 0}
  docs-first AND gaps.md-as-docs -> {'ok': 129, ...}  [load-bearing]
    ordering alone                -> {'ok': 82, ...}   [redundant on this lane]
    gaps.md-as-docs alone         -> {'ok': 82, ...}   [redundant on this lane]
```

**Three of those were decoration when first written, and the matrix is what found it.** The run
before this one reported `nested-type`, `base-class-walk`, `alias-template` and `none-propagation`
as NOT load-bearing:

- `ChFi3d_FilletShape::ChFi3d_Rational` was written as the nested-type case and was passing through
  the **method** shape, because a `//!` comment line reads `ChFi3d_Rational (default value)` and
  the space-then-paren matched. Replaced with `BRepOffsetAPI_MakeOffsetShape::OffsetAlgo_Type`, a
  genuine nested `enum` no other shape reaches.
- `BRepOffsetAPI_ThruSections::Build` was written as the base-class case and proves nothing:
  ThruSections declares its own `Build` at line 136. Replaced with `BRepFeat_MakeDPrism::Modified`,
  whose name does not occur in its own header at all.
- `Plate_Plate::myPlanarSurface` was written as the data-member case and names a field that does
  not exist. Replaced with `Plate_Plate::myConstraints`, and kept as the negative.
- `alias-template` and `none-propagation` had no case at all until `BRepLProp_CLProps::Value` was
  added. They are the two shapes #810's version lacks, and without them a tree-wide run reports 16
  false findings on `BRepLProp_` alone.

**And one ordering guard was found by the census failing, not by the matrix.**
`docs/occtswift-wrapping-gaps.md` is itself under `docs/`, so the moment this pass wrote reasons for
all 47 omissions, a "named anywhere under docs/" test read every one of them as DOCUMENTED and the
table came back **129 ok, 0 under, 0 recorded**. A file whose whole subject is what is NOT wrapped
cannot also be the evidence that something IS. Fixed two ways: consulting the curated tables
before the docs test, and excluding the file from the docs token set. **Neither half is
load-bearing alone on this lane and the combination is**, which the matrix prints as three lines
rather than one. Every one of the 47 recorded classes is in a curated table, so the ordering has
nothing to protect here and the exclusion has nothing to exclude; each covers the other's
absence. The first version of that variant flipped both at once and credited the whole swing to
the ordering, which is the decoration failure the file exists to catch, appearing in the file.

The regression check was proved the same way #810's was: run against a temporary worktree at
`origin/main`, `refman_census.py` reports every pinned string as a regression, all 5 method
findings, all 47 unders, and exits 1. Against this branch it exits 0.

**`--verify-pins origin/main` is that run, mechanised, and it exists because the manual version was
the only thing holding a real property.** `check_known_over_findings` asks only that a pinned string
is ABSENT from the working tree, so a pin with a typo, or one whose text never matched the file it
names, passes forever and protects nothing. `--verify-pins` asserts the opposite direction: every
pinned string must be PRESENT at the given ref. Proved by injecting a pin that matches nothing,
which reports `PINS THAT PROTECT NOTHING at origin/main` and exits 1; removed, exit 0. Run it
whenever a pin is added. The count is whatever
the script prints; it has grown four times as later review rounds found more, and quoting it
here went stale twice.

**That run is also what found a gap in the check itself.** The first attempt, when there were 24
strings, fired on 23. The
one that did not is the only pinned string spanning two lines of a `///` doc comment: collapsing
whitespace leaves the `///` sitting mid-string, so the finding could never match its own file.
`_collapse` now strips each line's leading comment marker first, and every pinned string fires.

## What this pass did not do

- **Fifteen packages below the lane, 337 headers, are audited by nobody** and are handed off by
  name with their measured reach rather than absorbed. `BRepFill_` (46 headers, 12 named in the
  bridge) and `GeomFill_` (68, 37) are the two that most want a lane of their own. Both counts
  include the bare `BRepFill.hxx` and `GeomFill.hxx` package headers, matching the 337 total
  above rather than the underscore-only convention this bullet first used.
- **Sixty-five method-attribution findings outside this lane.** Widened to every pinned class,
  the same check reported 70 findings before this PR; 5 were this lane's and are fixed here,
  leaving **65**. The denominator is not quoted for the same reason the line counts are not:
  it counts attributions in files this branch keeps editing, and it shipped stale in two
  consecutive review rounds. The finding count is what matters and it is stable. They belong to other passes and to
  Phase 6, are not adjudicated here, and are filed as #1044.
- **`Shape.withPrism`'s implementation (#1047).** The docs now say `BRepPrimAPI_MakePrism`, which
  is what the code runs. Whether a method named after a feature prism should instead use
  `BRepFeat_MakePrism` is a behaviour change and a separate question, the same split #810 recorded
  for #970.
