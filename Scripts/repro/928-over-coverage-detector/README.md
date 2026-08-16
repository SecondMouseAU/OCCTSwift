# #928: making `over` a reachable verdict

`Scripts/census-doc-occt-attribution.py` is the detector. This directory is its evidence: the
validation against every finding #808 and #809 established by hand, the sample the false-positive
rate is measured on, and the removal matrix proving the self-test's own cases are load-bearing.

## The problem

[#807](https://github.com/SecondMouseAU/OCCTSwift/issues/807) asks each lane pass for four verdicts,
`ok` / `under` / `over` / `deliberate, recorded`. Two passes shipped and neither could produce
`over`: both `classify()` functions return three of the four, and `over: 0` was printed by a loop
over a hardcoded name tuple. It would have read the same if every page under `docs/` were wrong.
Over-coverage was established instead by one hand read-through per lane, which is the failure mode
#807 exists to end.

## What the detector does

For every doc claim naming an OCCT class for a documented method, two mechanical checks:

1. **Does the class exist in the pinned kernel?** Asked of
   `Libraries/OCCT.xcframework/macos-arm64/Headers`, never of the `occt-refman` MCP cache. The
   refman carries prose the headers do not, but a live MCP call is not reproducible in CI and
   cannot be diffed, and the headers are what the bridge compiles against. `Libraries/` is absent in
   CI, where this half reports SKIPPED rather than passing silently.
2. **Does the bridge function implementing that method reach the class?** Reachability is
   `check-bridge-index.py`'s `reachable()`, reused rather than rewritten, because it already
   resolves the four indirections this bridge uses and each was added after a checker blind to it
   reported correct entries as wrong (#510, #565, #624).

Claims come from three channels: `- **OCCT:**` bullets (4,028), `///` doc comments in the bridge
headers (3,426), and two-column `| swift | OCCT |` table rows (1,264). A claim resolves to a bridge
function explicitly when it names one, and otherwise through the enclosing heading's Swift member.

## Result against the known findings

`validate_known_findings.py --matrix` puts both lanes in their fixed state, takes a baseline, then
reverts exactly one finding at a time:

| lane | findings | ISOLATED | SILENT | NOISY |
|---|---|---|---|---|
| #808 | 26 | 25 | 0 | 1 |
| #809 | 6 | 6 | 0 | 0 |

ISOLATED means reverting that finding, and nothing else, made the detector report it. #928 predicted
17 of #808's 26 would be catchable, on the grounds that 17 were the "class named nowhere in the
chain" shape; the other three shapes turn out to be catchable too, because the check is per class
rather than per claim, so an entry naming two classes is reported for whichever one is unreached.

The one NOISY row is `Shape.findSurface(tolerance:)`. It is reported with the correction in place as
well, because #808's correction explains itself in prose that names `BRepBuilderAPI_FindPlane` again
in a later sentence ("`BRepBuilderAPI_FindPlane` is wrapped, separately, by ..."). That is a real
false positive of the commentary kind, not a catch.

## False-positive rate: 41%

Measured, not estimated. `--sample 40 --seed 928` drew a uniform random sample of the run against
`origin/main`; each was read against the doc claim in context, the bridge function's whole body, its
helpers, and where the answer turned on kernel internals, `Libraries/occt-src`. The verdicts are in
`adjudicated-sample.tsv` and `score_sample.py` re-scores any later version of the detector against
the same rows.

```
uniform-40  : 39 rows reported, TRUE 23, FALSE 16  -> 41.0% false
  tier explicit : 15 rows, TRUE 10, FALSE  5  -> 33.3% false
  tier heading  : 24 rows, TRUE 13, FALSE 11  -> 45.8% false
```

`explicit` is a claim that names its own bridge symbol; `heading` is one resolved through the
enclosing heading's Swift member. Anyone proposing to promote this to a gate needs those two
numbers separately.

### The false-positive categories, each with a worked example

- **An accessor chain whose type is never spelled.** `OCCTBRepGraphSetFaceSurfaceRepId` calls
  `g->graph.Editor().Faces().SetSurface(...)`; `BRepGraph::Editor()` returns `EditorView&`, so
  `BRepGraph_EditorView` is genuinely in the chain and the identifier appears nowhere.
- **A base-class virtual on a subclass-typed field.** `Geom_Vector::Magnitude` is correct for a
  wrapper holding a `Handle(Geom_VectorWithMagnitude)`; `Geom_Geometry::Copy` is correct for
  `surface->surface->Copy()`, since `Copy()` is pure virtual only on `Geom_Geometry`.
- **A subject the heading resolves wrongly.** `docs/reference/Annotation.md:318` documents
  `AngleDimension.init?(face1:face2:)`, whose real function is `OCCTDimensionCreateAngleFromFaces`;
  the member index resolved the page's earlier `geometry` heading instead.
- **A cross-file helper or a bridge-to-bridge call.** `occtPlateApproxSurface` is defined in
  `OCCTBridge_ProjLib_NLPlate.mm` and called from `OCCTBridge_Healing.mm`; `OCCTMeshSubtract`
  delegates to `OCCTShapeSubtract`. `reachable()` follows neither.
- **A mention that is not an attribution.** `GC_MakeArcOfEllipse::Value()` returns a
  `Handle(Geom_TrimmedCurve)`, so the doc's `-> Geom_TrimmedCurve` is a result type; and
  `@param tolerance Precision for fixing` is English, not `Precision.hxx`.

Widening `reachable()` across files was built and measured against both the sample and the 32 known
findings, and is **not** kept:

```
no widening    31/32 known caught, 41.0% false, 493 findings
helpers only   29/32 known caught, 39.5% false, 488 findings
every callee   29/32 known caught, 37.8% false, 483 findings
```

Both widenings lose `Shape.moved -> BRepBuilderAPI_Transform` and `mergedMeshNodes -> BRep_Builder`,
two findings #808 confirmed by reading the code, to buy one or two points. The mechanism is that
`reachable()`'s per-function name set holds every identifier in the body, not only the functions it
calls, so a local variable sharing a name with a helper drags that helper's whole reach in. Recall
against a hand-built validation set is the criterion, because it is the one measurement not drawn
from the detector's own output.

## The retro pass: the two finished lanes are not equally complete

`validate_known_findings.py --retro` runs the detector restricted to each shipped lane with that
lane's own findings fixed. Ten of each lane's remaining findings were adjudicated the same way as
the uniform sample:

| lane | remaining findings | adjudicated | genuinely new |
|---|---|---|---|
| #808 | 45 | 10 | **0** |
| #809 | 24 | 10 | **4** |

(`--retro` prints 48 rather than 45 for #808 because it applies PR #926's diff, which rewords three
claims into new ones; 45 is the count on the plain tree, which is where the sample was drawn from.)

That is the first re-derivable evidence about the two read-throughs, and it is asymmetric. #808's
lane produced ten false positives out of ten: every one is an accessor chain, a cross-file
delegation, or a misresolved subject. #809's produced four real findings out of ten:

- `Shape-Builders-1.md:369` attributes `gp_Vec` to `Shape.translated(from:to:)`;
  `OCCTShapeTranslateByPoints` uses `GC_MakeTranslation(gp_Pnt, gp_Pnt)` and no `gp_Vec` appears
  anywhere in the chain.
- `Shape-Builders-2.md:763` attributes `gp_Vec2d::Crossed` to `vector2DCross`; `OCCTVector2DCross`
  is the inline arithmetic `ax * by - ay * bx`. (The sibling `vector2DDot` at `:779` has the same
  defect and was not in the sample.)
- `Geometry2D.md:964` attributes `gp_Torus::Axis` to `torusAxis`; `OCCTSurfaceTorusAxis` calls
  `Geom_ToroidalSurface::Axis()`, the inherited `Geom_ElementarySurface` accessor on a `gp_Ax3`.
- `Shape-Builders-1.md:1197` attributes `gp_Cylinder` to `faceFromCylinder`;
  `OCCTBRepLibMakeFaceFromCylinder` builds a `Geom_CylindricalSurface` and calls the
  `Handle(Geom_Surface)` overload of `BRepLib_MakeFace`.

So the 26-against-6 gap between the two lanes' findings is not only a difference in the lanes. #808
read 151 classes and found 26; #809 read 126 and found 6, and a ten-row sample of what it left
behind contains four more. These are **filed, not fixed here**: fixing them belongs in #809's own
lane with its `KNOWN_OVER_FINDINGS` table extended, so the regression check that pins the first six
pins these too, and this PR would otherwise be editing a lane it does not own.

## Running it

```bash
python3 Scripts/census-doc-occt-attribution.py                     # the census
python3 Scripts/census-doc-occt-attribution.py --self-test         # 20 cases, what CI runs
python3 Scripts/census-doc-occt-attribution.py --lane gp_,GC_      # one #807 lane
python3 Scripts/census-doc-occt-attribution.py --sample 40         # a reproducible sample

python3 Scripts/repro/928-over-coverage-detector/validate_known_findings.py
python3 Scripts/repro/928-over-coverage-detector/validate_known_findings.py --matrix
python3 Scripts/repro/928-over-coverage-detector/validate_known_findings.py --retro
python3 Scripts/repro/928-over-coverage-detector/score_sample.py
python3 Scripts/repro/928-over-coverage-detector/selftest_removal_matrix.py
```

`--matrix` and `--retro` apply and reverse PR #926's own documentation diff, so they need
`origin/fix/808-refman-shape-topology` fetched, and they refuse to start if `docs/` or `Sources/`
has uncommitted changes.

## The self-test is proved, not merely present

`selftest_removal_matrix.py` disables each of the detector's 15 guards in turn, in memory, and
re-runs the 20 self-test cases. Every guard fails at least one case. Five did not on the first pass,
and each was a case that proved nothing rather than a guard that did nothing:

- the clause splitter had no case where a contrastive tail sat beside a real attribution;
- the `Class::Member` fallback spelling had only a fixture reaching both spellings, so removing the
  joined one left it passing on the bare one;
- the wrapped-bullet, table-row and header-comment cases each constructed a `Claim` by hand and so
  exercised the rule while proving nothing about the parser that has to produce one.

All five are rewritten to go through the real parsers, and two seams (`gather_continuation`,
`attribution_names`) exist so the matrix has something to switch off.
