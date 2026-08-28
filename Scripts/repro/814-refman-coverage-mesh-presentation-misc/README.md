# #814: refman coverage audit, Mesh/presentation/misc lane (Pass 4d of #807)

Three files:

| file | what it is |
|---|---|
| `derive_lane.py` | the Swift-side call surface, re-derived by call per #814's own warning that Pass 4d's duplication work (#388) closed the same day this pass started and changed `PresentationMesh.swift`/`OCCTBridge_Mesh.mm`. Nine files, not three; `Annotation.swift` is in this lane (AIS_TextLabel) even though #814's own shorthand ("Mesh"/"Display"/"PixMap") doesn't name it. |
| `refman_census.py` | the census. **368 classes, the largest lane in the whole programme** (nearly 4x #811's/#812's 93, larger than #983's 342), four verdicts, an over-coverage sweep (12 confirmed findings, 6 rejected candidates), a family-count assertion, a lane re-derivation, and its own self-test — including a fifth `declares_member` shape (enum-value membership) this lane's own first run surfaced live. |
| `selftest_removal_matrix.py` | the proof that the self-test's guards are load-bearing, including the new enum-value shape. Its first run found two real bugs in this file's own removal-matrix implementation (see below), not in `refman_census.py` itself. |

```bash
python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/derive_lane.py
python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/derive_lane.py --calls
python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/refman_census.py
python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/refman_census.py --verbose
python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/refman_census.py --reverify-lane
python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/refman_census.py --self-test
python3 Scripts/repro/814-refman-coverage-mesh-presentation-misc/selftest_removal_matrix.py
```

All run from any cwd, in about a second. The checks that read the pinned headers report SKIPPED
rather than passing silently without `Libraries/OCCT.xcframework` (a fresh clone or CI has neither).

## Result

| verdict | count |
|---|---|
| `ok` | 45 |
| `deliberate, recorded` | 323 (3 pre-existing via #810/#982, 320 new in this PR) |
| `under` | 0 |
| `over` | 0 (12 confirmed findings, all fixed in this PR; 6 candidates investigated and rejected) |

**Before this PR the same table read `ok` 45, `deliberate, recorded` 3, `under` 320.**

## What the lane actually is

#814's own `## Lane` text names all nine packages with per-package header counts that match the
pinned kernel exactly (368 total, confirmed by `derive_lane.py`'s own header-count table and
`refman_census.py --reverify-lane`), so unlike #811's/#812's lanes there is no package-list
re-derivation to do. What #814 explicitly warns needs re-deriving is the **Swift-side call
surface**: Pass 4d's duplication work (#388) closed the same day this pass started, gaining
`PresentationMesh.swift` two new private helpers (`buildShadedMeshData`/`buildEdgeMeshData`) and
rewriting `OCCTBridge_Mesh.mm`'s STL writers to delegate elsewhere. Re-derived rather than assumed:
`derive_lane.py` confirms neither change adds or removes an OCCT class this lane reaches, both are
pure refactors of already-accounted call surface. The real Swift surface is **nine files**, not
#814's own three-name shorthand ("Mesh"/"Display"/"PixMap"): `Mesh.swift`,
`MeshCoordinateSystem.swift`, `MeshIterators.swift`, `MeshTypes.swift`, `PixMap.swift`,
`PresentationMesh.swift`, `Shape+Mesh.swift`, `DisplayDrawer.swift`, and `Annotation.swift`
(`AIS_TextLabel`) — the last one is IN this lane, unlike the identical file's `AIS_`/`PrsDim_` calls
in #812's HLR lane, because `AIS_` is this lane's own package.

## The two boundary questions, and how they were handled

- **`StdPrs_` (28 headers): confirmed, not trusted from the issue text.** `grep -rn StdPrs
  Sources/OCCTBridge/ docs/` (excluding this pass's own new gaps.md section) returned nothing at
  all before this PR — zero wrapped, zero documented, exactly #814's own claim ("the largest single
  block of unrecorded omission in the lane"). Recorded as **one family-level entry** in
  `docs/occtswift-wrapping-gaps.md`, matching #983's precedent for a large uniform family
  (`STDPRS_PRESENTATION_BUILDER_FAMILY`), not 28 individual reasons. One exception flagged by name
  within that entry rather than folded in silently: `StdPrs_BRepFont`/`StdPrs_BRepTextBuilder`
  convert a font glyph to real B-Rep geometry, a genuine capability with no dependency on the
  `Prs3d_Presentation` pipeline the rest of the family serves, and this bridge builds text as a flat
  Metal-facing label (`AIS_TextLabel`), never as geometry.
- **`StdSelect_` (11 headers, 2 wrapped): audited for OCCT-class coverage only.**
  `StdSelect_BRepSelectionTool`/`StdSelect_BRepOwner` are both wrapped and both named in
  `docs/reference/Selection.md`, #809's own Swift surface. This pass does not re-derive
  `Selection.swift`'s API — the census's `classify()` only ever asks "is this OCCT class named
  somewhere," never "does `Selection.swift` expose the right members" — per #814's own explicit
  warning that re-treading #809's territory would be the cross-lane double-count #928/#1044 already
  flagged once. The other 9 `StdSelect_` classes are curated by OCCT-class reasoning alone
  (`STDSELECT_FILTERS`/`STDSELECT_MISC`/`STDSELECT_PACKAGE_UTILITY`).
- **`SelectMgr_` is out of scope entirely**, per #814's own text (Phase 6's, #820, unless claimed
  first). Not one `SelectMgr_` class appears in `LANE_CLASSES`; it is named in two curated reasons
  only in prose (explaining why an unused `AIS_`/`StdSelect_` class sits on top of it), never as a
  class this census claims to audit or count.

## The over-coverage lead #814 flags, and what was found instead

8.0.1's `BRepMesh_BaseMeshAlgo` periodic-seam change (#654, upstream OCCT#1338) is already correctly
recorded in `docs/occt-upgrades.md` ("creates seam constraints only for the current wire occurrence's
pcurve"), and a grep for any hardcoded node/triangle count elsewhere in this lane's docs found none
that could have gone stale from it. **Not a finding.**

The real over-coverage came from `Scripts/census-doc-occt-attribution.py --lane
BRepMesh_,Poly_,IMeshData_,IMeshTools_,AIS_,Graphic3d_,Image_,StdPrs_,StdSelect_`: 11 candidates,
5 confirmed TRUE and 6 rejected as the same false-positive shape #811's/#812's own candidates were
(a class only reachable through a sibling call or named only in a parameter-type parenthetical, the
checker's `reachable()` walker requires it inside the *named* function's own body). All 5 true
candidates share one root cause, and reading the surrounding doc section by hand found 6 more of the
identical shape the detector missed: **a doc line citing `Poly_Triangulation` for a method actually
declared and called on a different class the bridge reaches through it.**

- `docs/reference/Document-Mesh-Fixing.md`'s six `MeshFaceIterator` accessors all wrap
  `RWMesh_FaceIterator` (confirmed: `struct OCCTMeshFaceIter { RWMesh_FaceIterator iter; };`), not
  `Poly_Triangulation` directly — `nodeCount`→`NbNodes`, `triangleCount`→`NbTriangles`,
  `node(at:)`→`NodeTransformed` (declared on the base `RWMesh_ShapeIterator`),
  `hasNormals`→`HasNormals`, `normal(at:)`→`NormalTransformed`, `triangle(at:)`→`TriangleOriented`.
- `docs/reference/Document.md`'s five `Document.triangulation*` accessors all wrap
  `TDataXtd_Triangulation` (a `TDF_Attribute`, confirmed at the pinned header to declare its own
  complete `NbNodes`/`NbTriangles`/`Node`/`Normal`/`HasNormals`/`Deflection` set, with zero relation
  to `Poly_Triangulation`), not `Poly_Triangulation` at all.

A twelfth, found by hand rather than by the detector: `docs/API_REFERENCE.md`'s `PointCloud` row
attributed `AIS_PointCloud`. `OCCTPointCloudCreate` (`OCCTBridge_AIS.mm`) builds a bridge-internal
`OCCTPointCloud` struct (plain coordinate/color arrays, bridge-computed bounds) and never touches
`AIS_PointCloud` anywhere in the tree — confirmed by `grep -rn AIS_PointCloud
Sources/OCCTBridge/`, empty before this PR's fix. `docs/visualization-research.md` already said as
much ("No standard OCCT widgets ... `AIS_PointCloud` ... none of these exist as ready-made
objects"), directly contradicting the row this PR fixes.

**All 12 are fixed in this PR, docs-only.** The 6 rejected candidates (`Graphic3d_MaterialAspect`
via a heading/subject collision between two same-named `ambientColor` fields, `Image_PixMap` named
only in a parameter-type parenthetical, and 3x `BRepMesh_IncrementalMesh` via a two-hop call the
checker doesn't chase) are recorded, not fixed, in `REJECTED_OVER_CANDIDATES`.

## A detector gap found on this lane's first real run, not invented

Verifying the fixes above with this lane's own `check_method_attributions()` surfaced a genuine
false FAILURE: `docs/reference/Display.md`'s `` `Graphic3d_Camera::Projection_Perspective` `` is a
**real, correct citation** — `Projection_Perspective` is a value of `Graphic3d_Camera::Projection`,
an unscoped nested `enum`, confirmed at the pinned header — but every prior lane's `declares_member`
only ever asked "is MEMBER a declared *name*" (method, nested type, data member), never "is MEMBER
one of an enum's own *values*." Fixed by adding a fifth shape, `_is_enum_value`, proven load-bearing
by `selftest_removal_matrix.py` (disabling it fails 1/13 cases) rather than merely reasoned about.

## The findings (under-coverage): 320 classes in 32 family-level buckets, not 320 individual reasons

Following #983's own precedent rather than #811's/#812's mostly-per-class tables — #983's body
predicted "expect this to be answered once for the whole driver family rather than per class," and
the same call applies here, more so, at nearly 4x #983's own scale relative to #811/#812. Every
bucket, with its full class list spelled out (not abbreviated — #983's own README records that an
abbreviated list fails the census's literal `\bClassName\b` check), is in
`docs/occtswift-wrapping-gaps.md`'s new "Mesh/presentation/misc lane" section, not repeated here so
this README going stale cannot make the gate pass on the wrong evidence. Summary of the shape:

- **`BRepMesh_`/`Poly_`/`IMeshData_`/`IMeshTools_` (52+10+13+10 = 85 classes)**: the meshing
  engine's own internal machinery underneath the wrapped `BRepMesh_IncrementalMesh` entry point —
  range splitters, Delaunay data structures, algorithm-selection factories, tessellation-pipeline
  stages, and two full abstract-interface layers. One real gap: `Poly_TriangulationParameters`
  (records what tolerance produced a mesh; recorded, not wrapped, since #814 is a coverage audit).
- **`AIS_` (59 classes)**: almost entirely OCCT's own `AIS_InteractiveContext`-driven live 3D
  viewer (animation, selection filters/owners, `AIS_InteractiveObject` subclasses, mode enums,
  viewer infrastructure) this bridge's Metal renderer never builds — the sole
  `AIS_InteractiveObject` subclass constructed is `AIS_TextLabel`, never through a live context.
- **`Graphic3d_` (129 classes)**: overwhelmingly one mechanism, OCCT's OpenGl-based
  `Graphic3d_GraphicDriver` live-viewer pipeline, the same fact #812's README established for
  `Prs3d_` and #982's for `TPrsStd_`. 72 pipeline classes (scene graph/buffers/primitive
  arrays/textures/shaders/camera/frame-stats), 41 unread enums, 8 deprecated aliases, 4 exception
  typedefs, 4 value-type aliases.
- **`Image_` (10 classes)**: the compressed-texture pipeline for the same unused `Graphic3d_`
  texture subsystem, `Image_PixMap`'s own storage internals, and three misc (an FFmpeg live-view
  recorder, OCCT's own image-diff regression tool, an unused pixel-color value type).
- **`StdPrs_` (28 classes, ONE bucket)**: see "the two boundary questions" above.
- **`StdSelect_` (9 classes)**: `SelectMgr_Filter`/`SelectMgr_EntityOwner`-based live-viewer
  selection machinery this bridge bypasses (picking goes through `StdSelect_BRepSelectionTool`/
  `StdSelect_BRepOwner`, both wrapped, into `Selection.swift`'s own model), a bare package-utility
  header, and one alias (`StdSelect_ViewerSelector3d`) this bridge's own `OCCTHeadlessSelector`
  subclasses `SelectMgr_ViewerSelector` directly instead of using.

## Proving the detectors fail

`selftest_removal_matrix.py` switches off each accepting shape in turn:

```
declares_member baseline: 13/13 cases pass unmodified
_ATTRIBUTION_RE baseline: 6/6 cases pass unmodified

  method-call        disabled -> 6/13 cases fail  [load-bearing]
  nested-type        disabled -> 1/13 cases fail  [load-bearing]
  data-member        disabled -> 1/13 cases fail  [load-bearing]
  enum-value         disabled -> 1/13 cases fail  [load-bearing]
  base-class-walk    disabled -> 1/13 cases fail  [load-bearing]

_ATTRIBUTION_RE baseline: 6/6 cases pass with the shipped pattern
  closing-backtick-anchor    imposed -> 2/6 cases fail  [load-bearing]
  no-leading-backtick        imposed -> 1/6 cases fail  [load-bearing]

classify baseline (real tree): {'ok': 45, 'deliberate, recorded': 3, 'under': 320}
  docs-first AND gaps.md-as-docs -> {'ok': 48, 'deliberate, recorded': 0, 'under': 320}  [load-bearing]
    ordering alone                -> {'ok': 45, 'deliberate, recorded': 3, 'under': 320}  [redundant on this lane]
```

**Two real bugs were found and fixed on this matrix's own first run, both in this file, not in
`refman_census.py`.** First, `HLRAlgo_Projector::myPersp` (a boundary probe reused from #812, kept
here to confirm `declares_member`'s header-reading path is lane-agnostic by design) was given the
wrong expected value, `None` instead of `True` — the case's own comment already argued for `True`
("declares_member ... still resolves it True"), the tuple just didn't match the prose, and the
self-test correctly reported it `FAIL`. Second, the two `_ATTRIBUTION_RE` variants were wired
backwards: `_RE_NO_CLOSING_BACKTICK_ANCHOR` (no anchor at all) was labelled "closing-backtick-anchor
imposed," and a positive lookbehind requiring a leading backtick (`_RE_LEADING_BACKTICK_REQUIRED`,
functionally almost identical to the shipped pattern) was labelled "no-leading-backtick imposed" —
so the second variant reported `0/6 fail [DECORATION]`, a false "this shape doesn't matter" result
from a mis-wired test, not a real gap in `_ATTRIBUTION_RE`. Fixed by writing what each variant name
actually claims: `_RE_CLOSING_BACKTICK_IMPOSED` adds a trailing backtick requirement (breaks the
`RWMesh_FaceIterator::TriangleOriented()` case, where `()` sits before the closing backtick),
`_RE_NO_LEADING_BACKTICK_IMPOSED` drops the leading-backtick literal entirely (breaks the
unbackticked-prose negative case, which starts false-matching). Re-run: both now correctly load-
bearing at 2/6 and 1/6, the exact numbers #812's own matrix reports on its lane.

The gaps.md check and the `KNOWN_OVER_FINDINGS` regression check were both proved by injection, not
merely reasoned about: `` `BRepMesh_FastDiscret` `` was temporarily replaced with a placeholder in
`docs/occtswift-wrapping-gaps.md` and the census re-run, reporting it `under` and exiting 1;
restoring the file returned it to `deliberate, recorded` and exit 0. One of the fixed
`Poly_Triangulation::HasNormals` lines in `docs/reference/Document-Mesh-Fixing.md` was reverted to
its pre-fix wording and the census re-run, reporting the matching `REGRESSION:` line and exiting 1;
restoring the file returned to a clean exit 0.

`wrapped-before-curated` reports 0 lane classes on this lane (none of the 45 wrapped/documented
classes appear in any curated table) — kept anyway, since the property under test is the RULE, not
that this particular lane has a live instance of it; every prior lane keeps the same check for the
identical reason.

## What this pass did not do

- **No general-purpose gate promotion.** Same status every prior lane leaves
  `census-doc-occt-attribution.py` in: still a report, not a gate. 11/12 checked candidates true
  on this lane (the 12th found by hand), the highest hit rate of the four lanes it has now run on.
- **`Poly_TriangulationParameters` was recorded, not wrapped.** See "the findings" above.
- **No `SelectMgr_` class was added, audited, or counted**, per #814's own explicit carve-out.
