# #812: refman coverage audit, Drawing / 2D-annotation lane (Pass 4b of #807)

Three files:

| file | what it is |
|---|---|
| `derive_lane.py` | the lane, re-derived **by call**. #812's own `## Lane` text names three things; the real Swift surface is four files, not the fourteen #386 (the sibling duplication-audit pass) settled on for a different question, and a fourth OCCT package the issue text never names. |
| `refman_census.py` | the census. 93 classes, four verdicts, an over-coverage sweep, a family-count assertion, a lane re-derivation, and its own self-test. |
| `selftest_removal_matrix.py` | the proof that the self-test's guards are load-bearing. Its first run found ONE real decoration bug: `data-member` had no case at all in the first draft of `SELF_TEST_CASES`, the same shape #811's matrix found four of on its own lane. |

```bash
python3 Scripts/repro/812-refman-coverage-drawing/derive_lane.py             # the lane, by call
python3 Scripts/repro/812-refman-coverage-drawing/derive_lane.py --calls     # + every lane-relevant call
python3 Scripts/repro/812-refman-coverage-drawing/refman_census.py           # the table
python3 Scripts/repro/812-refman-coverage-drawing/refman_census.py --verbose # + matching files
python3 Scripts/repro/812-refman-coverage-drawing/refman_census.py --reverify-lane
python3 Scripts/repro/812-refman-coverage-drawing/refman_census.py --self-test
python3 Scripts/repro/812-refman-coverage-drawing/selftest_removal_matrix.py
```

All run from any cwd, in about a second. The checks that read the pinned headers report SKIPPED
rather than passing silently without `Libraries/OCCT.xcframework` (this worktree symlinks
`Libraries/` to the sibling checkout at `/Users/elb/Projects/OCCTSwift/Libraries`, pinned to the
same `V8_0_1` + patches asset as this branch's own `Package.swift`; a fresh clone or CI has neither).

## Result

| verdict | count |
|---|---|
| `ok` | 7 |
| `deliberate, recorded` | 86 |
| `under` | 0 |
| `over` | 0 (the script derives it: 0 pinned, 3 candidates investigated and rejected) |

**Before this PR the same table read `ok` 7, `deliberate, recorded` 2, `under` 84.** The 2 were an
accident, not a genuine reason: `docs/occtswift-wrapping-gaps.md`'s summary table already said
"**TKHLR**: Hidden line removal (HLRBRep, HLRAlgo)", and the bare-package classes `HLRAlgo`/
`HLRBRep` happen to share their name with the toolkit's own prose mention, so the name-match test
found them "recorded" with no reason ever written for the specific fact that the *bare package
utility class* is unwrapped. This PR's new gaps.md section gives both a real, specific reason
(`PACKAGE_UTILITY`) rather than leaving that accident as the evidence.

## What the lane actually is

#812's `## Lane` text names two OCCT package prefixes (`HLRBRep_*`, `HLRAlgo_*`) plus a
qualified third (`Prs3d_* where it backs 2D output`) and the `Drawing`/`DrawingAnnotation`/
`DrawingSheet` Swift surface. Both halves moved once `derive_lane.py` traced actual calls instead
of trusting either list, and the move is bigger in one direction than #811's was:

- **`Prs3d_*` contributes zero classes.** The only two `Prs3d_*` construction sites in the whole
  bridge (`Prs3d_Drawer`, `Prs3d_Presentation`) sit behind `DisplayDrawer.swift`, whose own doc
  comment says the settings "affect mesh generation quality" in a Metal renderer — 3D display, not
  2D drawing-sheet output, which is exactly what the lane's own qualifier excludes.
  `grep -rn TypeOfHLR Sources/ docs/` (the one Prs3d_ enum that sounds 2D-drawing-shaped) returns
  nothing either: nothing in this bridge reads it. Stating a package as "zero classes" rather than
  silently dropping it from the table is deliberate: #812's own body warns that much of this lane
  is pure Swift with nothing to wrap, and the same discipline applies to a *package* contributing
  nothing, not only to a Swift file.
- **The real Swift surface driving OCCT calls is four files, not #386's fourteen and not the three
  the issue text names.** #386 (Pass 4b's own *duplication-audit* pass, closed just before this
  issue opens) settled a 14-file Swift scope for a different question ("what 2D-drawing-generation
  code exists to de-duplicate"), and #812 explicitly warns not to trust that list for *this*
  question ("what OCCT classes back it") without re-checking bridge calls. Re-checked: ten of the
  fourteen call **zero** `OCCT*` symbols at all (`grep -oE '\bOCCT[A-Za-z0-9_]*'` on each returns
  nothing) — pure Swift ISO 128/3098/5455 drafting-convention code, exactly what #812's own body
  predicts. The other four split two ways:
    - `Drawing.swift` and `DrawingAutoCenterlines.swift` call `OCCTDrawingCreate`/
      `OCCTDrawingCreatePoly`/`OCCTDrawingGetEdges`/`OCCTDrawingRelease`, all four defined in
      `OCCTBridge_HLR.mm`, #1071's own split (PR #1130) of this exact surface out of what was a
      17,045-line `OCCTBridge_Modeling.mm`.
    - `Shape+Topology.swift` (never in #386's list at all — it is 3354 lines, almost all of it
      unrelated Topology surface) has one `// MARK: - v0.73.0: TKHlr. Extended HLR, ReflectLines,
      TopCnx, Intrv` section calling `OCCTHLRGetEdgesByCategory`/`OCCTHLRPolyGetEdgesByCategory`/
      `OCCTHLRCompoundOfEdges`. All three are defined in `OCCTBridge_Modeling.mm`, NOT
      `OCCTBridge_HLR.mm`: a second, independent HLR call path #1071's split never migrated.
      Documented at `docs/reference/Shape-HLR-Geom.md`.
    - `Shape+Drawing.swift` is split down the middle. Its first half
      (`normalProjection`/`projectWire`) is `BRepOffsetAPI_NormalProjection`, #811's lane
      (Pass 4a), already audited there and not re-audited here. Its second half calls
      `OCCTHLRReflectLines`/`OCCTHLRReflectLinesFiltered`, which construct
      `HLRAppli_ReflectLines`, in the same `OCCTBridge_Modeling.mm` block two functions below the
      `Shape+Topology.swift` calls.
- **A fourth package is audited that the issue text does not name, for the same reason #811 added
  `Plate_`/`NLPlate_`/`GeomPlate_`/`BRepMAT2d_`.** `HLRAppli_` (one class,
  `HLRAppli_ReflectLines`) is reached directly by this lane's own calls, sitting in the exact
  bridge block described above. `TopCnx_`, named two words later in the very doc section heading
  this capability shares ("Extended HLR, ReflectLines, TopCnx, Intrv"), is deliberately NOT added:
  edge-face transition classification for BOP/healing, a different capability that shipped in the
  same v0.73.0 release batch, not a hidden-line-removal one.

So the audited lane is **three packages, 93 classes**: `HLRAlgo_` (29, including the bare
`HLRAlgo.hxx` package-utility header), `HLRBRep_` (63, including the bare `HLRBRep.hxx`),
`HLRAppli_` (1). `derive_lane.py --reverify-lane` is not a flag on this script (that check lives on
`refman_census.py`, matching #811's split); `refman_census.py --reverify-lane` re-derives the same
93 from a fresh `ls` of the pinned headers and diffs it against the embedded `LANE_CLASSES` table.

## What found the over-coverage, and what happened to each candidate

`Scripts/census-doc-occt-attribution.py --lane HLRBRep_,HLRAlgo_,HLRAppli_,Prs3d_` (#928) surfaced
**5 candidates at 3 locations**, **0 true**, all in `docs/reference/Drawing.md`, all one shape:

```
docs/reference/Drawing.md:132  HLRBRep_HLRToShape / HLRBRep_PolyHLRToShape  via=OCCTDrawingGetEdges
docs/reference/Drawing.md:148  HLRBRep_HLRToShape / HLRBRep_PolyHLRToShape  via=OCCTDrawingGetEdges
docs/reference/Drawing.md:787  HLRBRep_HLRToShape                          via=OCCTDrawingGetEdges
```

Read against the real code: `OCCTDrawingGetEdges` (`OCCTBridge_HLR.mm`) takes an already-built
`OCCTDrawingRef` and reads compound fields (`visibleSharp`/`hiddenOutline`/...) a SIBLING function
(`OCCTDrawingCreate`/`OCCTDrawingCreatePoly`) populated earlier via a shared helper
(`occtDrawingPopulate`) that DOES construct `HLRBRep_HLRToShape`/`HLRBRep_PolyHLRToShape` and calls
their compound accessors. The doc prose is careful about this: "compound accessors ... selected
via `OCCTEdgeType` in `OCCTDrawingGetEdges`" describes the switch statement that picks among
already-extracted results, not a claim that `OCCTDrawingGetEdges` itself builds either class. The
detector's `reachable()` walker needs the class inside the *named* function's own body and cannot
follow a value cached across a sibling call, the exact shape of #811's one rejected candidate
(a cross-file shared-helper case it also could not follow). Unlike #811's finding, this is not a
detector blind spot worth teaching the walker: the doc claim is accurate as written, and "which of
two functions in a pipeline literally calls the constructor" is not itself a coverage question.

Beyond the automated pass, every remaining `- **OCCT:**` bullet touching this lane was read against
the pinned headers by hand: `HLRAlgo_Projector`'s two constructor overloads (`Projector(CS)`,
`Projector(CS, Focus)`, both confirmed at `HLRAlgo_Projector.hxx:53,57`), `HLRBRep_TypeOfResultingEdge`'s
six ordinals (`Undefined=0` through `Sharp=5`, matching `HLREdgeType`'s Swift mirror exactly),
`HLREdgeCategory`'s eleven cases, and both `reflectLines`/`reflectLinesFiltered` descriptions. No
further finding. `docs/occt-upgrades.md` names no `HLR*` class at all, so unlike Pass 4d's
`BRepMesh_BaseMeshAlgo` note, the 8.0.1 kernel bump did not touch this lane's documented behaviour.

## The findings (under-coverage)

Almost none of the 86 unwrapped-and-undocumented classes is a genuine capability gap. Hidden-line
removal is one nontrivial geometric algorithm (compute the visible/hidden silhouette of a shape
from a viewpoint) with five public entry classes as its wrapped surface and roughly sixty classes
of its own internal machinery underneath: a curve/curve and curve/surface intersection engine
(`HLRBRep_CInter`/`HLRBRep_InterCSurf` and 18 template-instantiation classes named in OCCT's
generic-intersection-macro style, `HLRBRep_The<X>Of<Y>`/`HLRBRep_My<X>Of<Y>`), a
triangulation-internal polygon/edge-status data structure the poly algorithm drives through
`HLRAlgo_PolyAlgo` (16 classes), the exact algorithm's own edge/face/interference cursor state
driven through `HLRBRep_Data` (21 classes), template-policy "Tool" adaptors providing static
geometric evaluators to both engines (7 classes), 5 alias templates to `GeomLProp_*Base`
instantiations, 15 deprecated `Standard_HEADER_DEPRECATED` collection typedefs, 2 bare
package-utility classes, 1 unread bit-flag enum, and 1 header declaring no class of its own name.
Every bucket, and every reason, is in `docs/occtswift-wrapping-gaps.md`'s new "Drawing /
2D-annotation lane" section, not repeated here; that is the file the census checks against, and
this README going stale must not be able to make the gate pass on the wrong evidence.

Two class pages were pulled from `occt-refman@8.0.1` through the `context` MCP specifically to
confirm the "internal engine state, no independent capability" read rather than assert it from the
name: `HLRAlgo_PolyInternalData`'s own summary is "to Update OutLines"; `HLRBRep_Data`'s listed
public methods are `AboveInterference`/`Edge`/`HidingTheFace`/`InitInterference`/
`IsBadFace`/`RejectedInterference`/`SimpleHidingFace`/`Tolerance`/`Update`, an edge-hiding cursor
with no capability beyond the algorithm that owns it.

## Adjacent, not in this lane

Recorded in the gaps.md section too, so a later pass does not re-derive it: `HatchPattern.swift`'s
`OCCTHatchLines` builds a `Hatch_Hatcher` (package `Hatch_`, not named by #812, not audited here).
`Annotation.swift`'s `OCCTDimensionCreate*`/`OCCTTextLabelCreate`/`OCCTPointCloudCreate` all reach
`OCCTBridge_AIS.mm` (`AIS_*`/`PrsDim_*`), 3D-interactive/Metal per its own doc comments ("for Metal
rendering"), not the 2D drawing-sheet surface — nothing under `Drawing*.swift` uses its types
(`grep -rln DimensionGeometry Sources/OCCTSwift` finds only `Annotation.swift` itself).

## Proving the detectors fail

`selftest_removal_matrix.py` switches off each accepting shape in turn:

```
declares_member baseline: 13/13 cases pass unmodified

  method-call          disabled -> 6/13 cases fail  [load-bearing]
  nested-type          disabled -> 1/13 cases fail  [load-bearing]
  data-member          disabled -> 1/13 cases fail  [load-bearing]
  base-class-walk      disabled -> 2/13 cases fail  [load-bearing]
  alias-template       disabled -> 1/13 cases fail  [load-bearing]
  none-propagation     disabled -> 1/13 cases fail  [load-bearing]

_ATTRIBUTION_RE baseline: 6/6 cases pass with the shipped pattern

  closing-backtick-anchor    imposed -> 2/6 cases fail  [load-bearing]
  no-leading-backtick        imposed -> 1/6 cases fail  [load-bearing]

classify baseline (real tree): {'ok': 7, 'deliberate, recorded': 86, 'under': 0}
  docs-first AND gaps.md-as-docs -> {'ok': 93, ...}  [load-bearing]
    ordering alone                -> {'ok': 7, ...}   [redundant on this lane]
    gaps.md-as-docs alone         -> {'ok': 7, ...}   [redundant on this lane]
```

**One of those was decoration when first written, and the matrix is what found it, the same shape
#811's matrix found four of on its own lane.** The first run of `data-member` reported `0/13 cases
fail` — `SELF_TEST_CASES` had eleven cases and none of them exercised the data-member acceptance
branch at all, so the guard existed in the shipped code with nothing proving it does anything.
Fixed by adding a real positive/negative pair: `HLRAlgo_Projector::myPersp` (a genuine private
`bool` field at `HLRAlgo_Projector.hxx:116`, matched by neither the method-call shape, since
nothing follows it with `(`, nor the nested-type one) and `HLRAlgo_Projector::myPerspective` (a
plausible-sounding name that does not exist — the real field is the abbreviated `myPersp`), the
same positive/negative role #811's `Plate_Plate::myConstraints`/`myPlanarSurface` pair plays there.
Re-run after the fix: `1/13 cases fail` with `data-member` disabled, `[load-bearing]`.

The `classify()` ordering-plus-gaps.md-exclusion result reproduces #811's own finding on a second
lane, for the same reason: every one of the 86 recorded classes is in a curated table, so the
ordering has nothing to protect and the exclusion has nothing to exclude, on THIS lane, and both
report `[redundant on this lane]` alone. Kept anyway, same as #811 keeps it: the property under
test is "does the combination change the count on the real tree", not "does the tree currently
contain the shape it would catch". Injected directly, not only reasoned about:
`docs-first AND gaps.md-as-docs` on the real tree gives `{'ok': 93, 'deliberate, recorded': 0,
'under': 0}`, all 86 non-wrapped classes misread as `ok` the moment the gaps file's own summary
line ("TKHLR: Hidden line removal (HLRBRep, HLRAlgo)") counts as evidence that all 93 individual
classes are documented, exactly the trap #811 found on its own lane and this one reproduces on a
different set of curated classes.

The main check was proved the same way: `docs/occtswift-wrapping-gaps.md`'s new section was
temporarily stripped of one class name (`HLRBRep_TypeDef.hxx` -> `XXXREMOVEDXXX`, a plain-text
substitution) and `refman_census.py` re-run. It reported `HLRBRep_TypeDef` as `under` with "no line
in occtswift-wrapping-gaps.md" and exited 1; restoring the file returns it to `deliberate,
recorded` and exit 0. `wrapped-before-curated` reports 0 lane classes on this lane (unlike #810's
six genuinely-called-and-deprecated headers) — kept anyway, since the property under test is the
RULE ("wrapped beats curated"), not that this particular lane has a live instance of it; #811
keeps the same check for the identical reason on its own lane.

## What this pass did not do

- **No general-purpose gate promotion.** Same status as #811 left `census-doc-occt-attribution.py`
  in: still a report, not a gate, per CLAUDE.md's own accounting of its measured false-positive
  rate (41% over a 40-row sample, 5.3% on #811's lane; 0/5, i.e. 0%, on this one, the lowest of the
  three lanes it has now run on, because this lane's five candidates were all one repeated shape).
- **`HLRAppli_ReflectLines`'s `SetAxes`/`Perform`/`GetResult`/`GetCompoundOf3dEdges` were the only
  members of this lane's classes checked by `check_method_attributions()`** (2 attributions found
  tree-wide naming a lane class with `::`); the other 91 classes have zero `Class::Member` doc or
  bridge-comment attributions naming them at all, which is consistent with 86 of them being
  internal machinery nobody writes prose about.
