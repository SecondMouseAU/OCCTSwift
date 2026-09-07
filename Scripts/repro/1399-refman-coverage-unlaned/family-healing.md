# #1399, `healing` family: 31 classes read against the refman

`ShapeFix` / `ShapeAnalysis` / `ShapeUpgrade` / `ShapeCustom` / `ShapeExtend`, `BRepTools` /
`BRepLib` / `BRepTopAdaptor`, `BRepBndLib` / `BndLib` / `Bnd_*`, `BRepGProp` / `GProp_*`, and the
eight `BRepGraph_*` classes that moved into this family when `derive_lane.py` stopped assuming this
project had invented the `BRepGraph` package.

```bash
python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py --family healing
```

| verdict | count |
|---|---|
| `ok` | 5 |
| `deliberate, recorded` | 6 |
| `under` | 6 |
| `over` | 14 |

`over` dominating is the opposite of what the brief predicted, and the reason is worth stating: 70
of the 118 originally-unlaned classes are named nowhere in `docs/`, which reads as an under-coverage
problem, but for most of these the **capability** is documented and it is the **class** that is
missing, because a different class was named in its place. Nine of the fourteen `over` verdicts are
that shape. The class named is nearly always the one next door: `GProp_PGProps` for
`GProp_SelGProps`, `ShapeUpgrade_ShapeDivideArea` for `ShapeUpgrade_ShapeDivide`,
`BRepLib::UpdateEdgeTolerance` for `BRepLib::UpdateEdgeTol`,
`ShapeCustom_SweptToElementary` for `ShapeCustom::ConvertToRevolution`. That is
`measure-dont-assume.md`'s "the adjacent identifier reads as the one you need", found fourteen times
in one family.

## The table

`docs=` is `derive_lane.py`'s own column, which counts `docs/CHANGELOG.md`; where that inflates it,
the row says so.

| class | uses | verdict | evidence |
|---|---:|---|---|
| `BRepTools` | 93 | `ok` | 15 statics reached (`OuterWire` x18, `UVBounds`, `Write`, `Read`, `EvalAndUpdateTol`, `Update`, `UpdateFaceUVPoints`, `RemoveInternals`, `Map3DEdges`, `DetectClosedness`, `Compare`, `Clean`, `CleanGeometry`, `RemoveUnusedPCurves`, `IsReallyClosed`). Every `BRepTools::X` docs name is in the pinned header and on a live path. `BRepTools::Dump` in `docs/guides/adding-features.md` is a debugging snippet, not an operation claim |
| `BRepBndLib` | 85 | `ok` | `Add` x43, `AddOptimal` x3, `AddOBB` x3, all three named in docs against the right subjects. One census candidate rejected, see Rejected below |
| `BRepLib` | 72 | **`over`** | `docs/reference/Document-BSpline-Extrema.md` named `BRepLib::UpdateEdgeTolerance`; the bridge calls `BRepLib::UpdateEdgeTol`. See **O8** |
| `BRepGraph` | 60 | `ok` | reached through `BRepGraph::ShapesView::Add`, `LayerRegistry()`, `CacheRegistry()`; five reference pages document it. Two census candidates rejected |
| `BRepGProp` | 45 | **`over`** | `Shape-Healing.md` attributed `recognizeCanonical` to `BRepGProp`; that path is `ShapeAnalysis_CanonicalRecognition` only. See **O13** |
| `Bnd_OBB` | 29 | `ok` | 11 member calls in `OCCTBridge_Topology_BoundingBox.mm`, 7 named in docs, all present in the pinned header |
| `ShapeCustom` | 29 | **`over`** | `ShapeCustom::ConvertToRevolution` documented as its own inverse. See **O1**, filed as #1634 |
| `ShapeFix_FreeBounds` | 20 | **`over`** | `fixedFreeBounds` attributed to `ShapeFix_Shape` / `ShapeAnalysis_FreeBounds`. See **O4**, filed as #1636 |
| `BndLib` | 19 | **`over`** | eight attributions naming `BndLib_Add3dCurve` / `BndLib_AddSurface` for calls that are `BndLib::Add`. See **O12** |
| `ShapeAnalysis` | 18 | **`over`** | the `checkOuterBound` entry still says #1073's two gaps are open; PR #1140 closed both in the bridge and never touched the page. See **O14** |
| `ShapeFix` | 15 | `deliberate, recorded` | **not reached at all.** None of its five statics (`SameParameter`, `EncodeRegularity`, `RemoveSmallEdges`, `FixVertexPosition`, `LeastEdgeSize`) is called. The 15 `uses` are 14 comments plus the string literal `"ShapeFix.FixSmallSolid.MSG0"` in `OCCTBridge_IO_Diagnostics.mm:840`. A package class the bridge never calls has no capability to document |
| `BRepLib_MakePolygon` | 14 | `deliberate, recorded` | reached only by `OCCTWireMakePolygonFromPoints`, which no Swift file, test or doc calls. `Wire.polygon3D` reaches the same algorithm through `BRepBuilderAPI_MakePolygon`, which holds a `BRepLib_MakePolygon myMakePolygon` member (`BRepBuilderAPI_MakePolygon.hxx:181`) and delegates. Dead code, filed as #1640 |
| `ShapeCustom_RestrictionParameters` | 12 | **`over`** | `Shape-Healing.md` said "each geometry is approximated as a BSpline"; the defaults convert no plane, cylinder, cone, sphere, torus or Bezier surface. See **O11**, filed as #1637 |
| `BRepTopAdaptor_TopolTool` | 11 | `deliberate, recorded` | the domain-classification tool `Contap_Contour::Perform(surf, tool)` requires, constructed and discarded inside `OCCTContapContourDirection` / `...Eye`. No caller sees it and nothing about it is configurable through the bridge |
| `Bnd_Box2d` | 11 | `deliberate, recorded` | a local accumulator in `OCCTCurve2DGetBoundingBox` and `OCCTCurve2DHatch`; the caller gets four doubles out of `box.Get(...)`. Its `docs=yes` is a single `docs/CHANGELOG.md` line about a deferred setter, not documentation of this use |
| `BRepGraph_Copy` | 10 | **`under`** (fixed) | `copy`, `copyFace` and `translated` named only the bridge function on their `- **OCCT:**` lines. See **U2** |
| `BRepGraph_ItemUID` | 10 | **`under`** (fixed) | attributed to "`BRepGraph` item-UID layer". See **U3** |
| `ShapeUpgrade_ClosedFaceDivide` | 10 | `deliberate, recorded` | reached only by `OCCTShapeUpgradeClosedFaceDivide`, which no Swift file, test or doc calls. A real capability with no way in, filed as #1640 |
| `ShapeAnalysis_Geom` | 9 | **`over`** + `under` | `nearestPlane` attributed to `gp_Pln`, its output type. And its refusal rule was documented nowhere. See **O9** and **U1** |
| `ShapeExtend_CompositeSurface` | 9 | **`over`** | `composeShell` "splits a face into sub-faces"; measured 1 face in, 1 out, on a 1 x 1 grid. See **O10**, filed as #1638 |
| `ShapeUpgrade_ShapeDivide` | 9 | **`over`** | `dividedByNumber` attributed to `ShapeUpgrade_ShapeDivideArea`. See **O7** |
| `BRepLib_CheckCurveOnSurface` | 8 | **`over`** | `curveOnSurfaceCheck` attributed to `ShapeAnalysis_Edge`. See **O6** |
| `BRepTools_PurgeLocations` | 8 | **`over`** | `purgedLocations` attributed to `BRepLib::SameParameter`. See **O5** |
| `ShapeExtend` | 8 | `ok` | `ShapeExtend::Init` x4, named correctly at `docs/reference/Document-Math-Solvers.md:435`, with the bridge's own comment explaining why that call is the chosen way to load the message set |
| `BRepGraph_UID` | 6 | **`under`** (fixed) | attributed to "`BRepGraph_NodeId` UID query". See **U3** |
| `GProp_SelGProps` | 5 | **`over`** | seven surface-area entries attributed to `GProp_PGProps` or `GProp_PEquation`. See **O2**, **O3** |
| `GProp_VelGProps` | 5 | **`over`** | four volume entries attributed to `GProp_PGProps` or `GProp_GProps`. See **O2**, **O3** |
| `BRepGraph_RefUID` | 4 | **`under`** (fixed) | attributed to "`BRepGraph_RefId` UID query". See **U3** |
| `BRepGraph_ItemId` | 2 | **`under`** (fixed) | named nowhere; it is what `UIDs().ItemIdFrom()` returns. See **U3** |
| `BRepGraph_SupplementIterator` | 2 | `deliberate, recorded` | used only by the file-static `bgSupplementCount` in `OCCTBridge_BRepGraph.mm:216`, which turns it into an `int32_t`. An iterator type that never crosses the bridge boundary |
| `BRepGraph_Transform` | 2 | **`under`** (fixed) | named nowhere in `docs/`, not even in `CHANGELOG.md`. See **U2** |

## Measured, not read

`probe_healing_claims.mm` beside this file replicates five bridge functions' exact call sequences
against the pinned kernel. `probe-healing-transcript.txt` is its output. Build it per CLAUDE.md's
"Compile a Ground Truth C++ Test".

Every behaviour claim below cites it. Three of the five blocks changed a verdict I had already
written from reading, and one of them (`nearestPlane`, "least-squares") **retracted** a finding
rather than supporting one, which is the whole reason the probe exists.

## The `over` findings

### O1. `ShapeCustom` runs the opposite of what `revolutionToElementary()` says, on all three layers

`OCCTShapeRevolutionToElementary` (`OCCTBridge_Healing_Fix.mm:913`) is one line,
`ShapeCustom::ConvertToRevolution(shape->shape)`. The pinned header
(`ShapeCustom.hxx:99`) says that returns "a new shape with all elementary periodic surfaces
converted to `Geom_SurfaceOfRevolution`", and the 8.0.1 refman says `ShapeCustom_ConvertToRevolution`
"Converts all elementary surfaces into surfaces of revolution". `ShapeCustom::SweptToElementary`,
the actual inverse, is on the next line of the same header and backs `sweptToElementary()`.

Measured:

```
=== 5. ShapeCustom::ConvertToRevolution, which direction does it run?
   cylinder, as built:          0 surface(s) of revolution, 3 elementary
   after ConvertToRevolution:   1 surface(s) of revolution, 2 elementary
   then SweptToElementary:      0 surface(s) of revolution, 3 elementary
```

Three layers said the wrong thing: the Swift `///`, the bridge header comment, and
`docs/reference/Shape-Healing.md`'s summary, its "similar to `sweptToElementary()` but targets only
surfaces of revolution" line and its `- **OCCT:**` attribution. `grep -rn revolutionToElementary
Tests/` returns nothing, so nothing could have caught it.

**Compounding it:** `OCCTShapeCustomConvertToRevolution` (`OCCTBridge_Healing_Fix.mm:1036`) has a
byte-identical body, is wrapped as `withSurfacesAsRevolution()`, and is documented **correctly** at
`docs/reference/Shape-Measurement.md:894`. The repo holds the right name and the right sentence for
this operation twenty lines from the wrong one.

Fixed here: the reference page now says what the call does and links the correct sibling. Filed as
**#1634**: the rename is MAJOR and one of the two wrappers should go.

### O2. Six `GProp_PGProps` attributions for calls that are `GProp_SelGProps` / `GProp_VelGProps`

`docs/reference/Document-Analysis-Builders.md` attributed `cylinderSurfaceArea`, `cylinderVolume`,
`coneSurfaceArea`, `coneVolume`, `sphereSurfaceArea` and `sphereVolume` to `GProp_PGProps`. Read the
bridge (`OCCTBridge_Properties.mm:1970-2100`): every surface member builds `GProp_SelGProps` and
every volume member builds `GProp_VelGProps`. The refman: `GProp_SelGProps` "Computes the global
properties of a bounded elementary surface in 3D (surfaces from the gp package: Cylinder, Cone,
Sphere, Torus)"; `GProp_VelGProps` "Computes the global properties and the volume of a geometric
solid ... Supports elementary solids from the gp package". `GProp_PGProps` is the point-set class,
correctly named on the `pointSetCentroid` / `weightedCentroid` / `barycentre` entries on the same
page, which is presumably where the wrong name was copied from.

### O3. The torus pair attributed to `GProp_PEquation` and `GProp_GProps`

`docs/reference/Document-Geometry-Constructors.md` said `torusSurfaceArea` uses "`GProp_PEquation` /
`GProp_GProps` torus formulas" and `torusVolume` uses "`GProp_GProps` torus formulas". The bridge
uses `GProp_SelGProps` and `GProp_VelGProps` over a `gp_Torus`. `GProp_PEquation` classifies a point
cloud as coincident / collinear / coplanar / spatial and computes no areas at all; `GProp_GProps` is
the base class both real classes inherit and computes none of its own.

The two summaries ("Exact surface area of a full torus: 4π² R r", "2π² R r²") are **not** findings:
both agree with the page's own worked values and with the closed forms.

### O4. `fixedFreeBounds` attributed to `ShapeFix_Shape` / `ShapeAnalysis_FreeBounds`

`OCCTShapeFixFreeBounds` (`OCCTBridge_Healing_Fix.mm:970`) builds `ShapeFix_FreeBounds`, whose class
comment says it "complements" `ShapeAnalysis_FreeBounds` with the open-wire connection step.
`ShapeFix_Shape` is not on the path at all.

Reading it also turned up two things the entry did not say, both now on the page:

- the returned `Shape` is a **compound of the free-bound wires**, closed then open, not the repaired
  input shape. `ShapeFix_FreeBounds::GetShape()`, "returns modified source shape", is never called,
  and the class comment is explicit that the source shape *is* modified by the connection step. So
  the repair the name advertises is the one thing the caller cannot get. Filed as **#1636**.
- the pinned header's own precondition: `closetoler` must be **greater than** `sewtoler` or no
  connection is performed. Nothing enforces or reports it.

### O5. `purgedLocations` attributed to `BRepLib::SameParameter`

`OCCTShapePurgeLocations` (`OCCTBridge_Healing_Sewing.mm:915`) is `BRepTools_PurgeLocations` and
nothing else. The entry's own prose ("removes negative-scale and non-unit-scale transforms") is a
paraphrase of that class's header comment, so the prose was right and the attribution named an
unrelated class.

### O6. `curveOnSurfaceCheck` attributed to `ShapeAnalysis_Edge`

`OCCTShapeCheckCurveOnSurface` (`OCCTBridge_Surface_Surfaces.mm:1555`) constructs a
`BRepLib_CheckCurveOnSurface` per edge-face pair and reads `MaxDistance()` / `MaxParameter()`.
`BRep_Tool::CurveOnSurface`, the other half of the old attribution, is real but only skips pairs
with no pcurve. `ShapeAnalysis_Edge` is never constructed.

### O7. `dividedByNumber` attributed to `ShapeUpgrade_ShapeDivideArea`

`OCCTShapeDivideByNumber` (`OCCTBridge_Healing_Upgrade.mm:770`) builds a plain
`ShapeUpgrade_ShapeDivide` and installs a `ShapeUpgrade_FaceDivideArea` tool.
`ShapeUpgrade_ShapeDivideArea` is a real class the bridge really uses, in `OCCTShapeDivideByArea`
and `OCCTShapeDivideByParts` (`:831`, `:852`), which is exactly the adjacency that makes this kind
of mistake plausible.

The entry's prose was also pre-#1491: it said "approximately `parts` parametric patches", and since
#1491 the count is exact and per-axis and lands on U specifically. The Swift `///` was updated by
that PR; the reference page was not.

### O8. `updateEdgeTolerance` attributed to `BRepLib::UpdateEdgeTolerance`, and its behaviour claim measured false

`OCCTBRepLibUpdateEdgeTolerance` (`OCCTBridge_Topology_ShapeQueries.mm:1344`) calls
`BRepLib::UpdateEdgeTol(edge, tol, tol * 100.0)`. Both names exist in `BRepLib.hxx`, 13 lines apart:
`UpdateEdgeTol` takes a `TopoDS_Edge`, `UpdateEdgeTolerance` takes a `TopoDS_Shape` and sweeps every
edge, and the header warns it is "very slow".

The entry also said "Force the tolerance of a specific edge to the given value." Measured, on two
edges and four requested values:

```
   box edge        asked 1e-09    before 1e-07      returned true  after 1e-07      forced: NO
   box edge        asked 1e-05    before 1e-07      returned true  after 1e-07      forced: NO
   box edge        asked 0.5      before 1e-07      returned true  after 1e-07      forced: NO
   box edge        asked 2        before 1e-07      returned true  after 1e-07      forced: NO
   free line edge  asked 1e-09    before 1e-07      returned true  after 1e-07      forced: NO
   ...
```

`tolerance` is `MinToleranceRequest`, the sampling tolerance the deviation evaluation starts at, and
it is never written to the edge. Reading `BRepLib.cxx:493-687` explains the `true`: the function
ends with an unconditional `return true` after `TE->Tolerance(edge_tolerance)`, and
`edge_tolerance` starts at 0 and only grows from measured deviations, so an edge with no pcurves
never moves. `false` means only "degenerate, or already looser than the ceiling".

The hardcoded `* 100.0` ceiling is filed as **#1639**; the doc corrections are here.

### O9. `nearestPlane` attributed to `gp_Pln`

`gp_Pln` is the out-parameter `ShapeAnalysis_Geom::NearestPlane` writes into. It is a plain
geometric primitive with no fitting member. The algorithm is
`ShapeAnalysis_Geom::NearestPlane` through `GProp_PEquation`.

**A finding I retracted by measuring.** I had written the page's "uses least-squares fitting" up as
a second `over`, on the argument that a `GProp_PEquation` principal-axis fit is not least squares.
It is: the plane through the barycentre normal to the least-extent principal axis *is* the
orthogonal (total) least-squares plane. The sentence stands and I was wrong about it. What the
measurement did find is **U1** below.

### O10. `composeShell` "splits a face into sub-faces"

`OCCTShapeFixComposeShell` (`OCCTBridge_Healing_Fix.mm:1350`) wraps the face's own surface in a
`NCollection_HArray2<Handle(Geom_Surface)>(1, 1, 1, 1)`. `ShapeFix_ComposeShell` splits along the
joint lines *between* patches, and a one-patch grid has none. Measured on a cylinder's lateral face:

```
=== 2. ShapeFix_ComposeShell on a 1x1 grid, does the face split?
   Perform()               : true
   faces in: 1, faces out  : 1
   grid patches            : 1 x 1
```

`Perform()` returning true is what makes this survivable as a bug: the call succeeds and does the
wire rebuild, which is genuinely useful and is what the page now describes. Taking a real grid is
filed as **#1638**. No test asserts anything about this call's output topology.

### O11. `bsplineRestriction`'s "each geometry is approximated as a BSpline"

Both `ShapeCustom::BSplineRestriction` entry points pass a default-constructed
`ShapeCustom_RestrictionParameters` and expose none of its toggles. Read off the pinned kernel:

```
   ConvertPlane            : false      ConvertRevolutionSurf   : true
   ConvertCylindricalSurf  : false      ConvertExtrusionSurf    : true
   ConvertConicalSurf      : false      ConvertOffsetSurf       : true
   ConvertSphericalSurf    : false      GMaxDegree              : 15
   ConvertToroidalSurf     : false      GMaxSeg                 : 10000
   ConvertBezierSurf       : false
   cylinder out: 0 BSpline face(s), 3 still elementary
```

A cylinder through this call gets nothing converted, silently. The page now carries the table;
exposing the toggles is **#1637**.

`Shape.bsplineRestrictionAdvanced(...)` is not the escape hatch: its `approxSurface` /
`approxCurve3d` / `approxCurve2d` are `ShapeCustom_BSplineRestriction`'s own coarse toggles, not
these fifteen.

### O12. Eight `BndLib` attributions naming the adaptor classes

`OCCTBridge_Spatial_Bounding.mm` calls `BndLib::Add` overloads at `:511, 540, 565, 595, 624, 708,
736, 763, 794, 824, 855`, and `BndLib_Add3dCurve::Add` at exactly one site (`:652`,
`OCCTBndLibEdge`) and `BndLib_AddSurface::Add` at exactly one (`:680`, `OCCTBndLibFace`). Those two
entries are correctly attributed. The other eight (`ellipse`, `cone`, `circleArc`, `ellipseArc`,
`parabolaArc`, `hyperbolaArc` in `Document-Geometry-Constructors.md`; `line`, `sphere` in
`Document-Analysis-Builders.md`) named `BndLib_Add3dCurve` or `BndLib_AddSurface` for calls that are
`BndLib::Add`. Every overload used is present in `BndLib.hxx:74-245`.

### O13. `recognizeCanonical` attributed to `BRepGProp`

`OCCTShapeRecognizeCanonical` (`OCCTBridge_Surface_Analysis.mm:566-687`) constructs one
`ShapeAnalysis_CanonicalRecognition` and asks `IsPlane`, `IsCylinder`, `IsCone`, `IsSphere`,
`IsCircle`, `IsLine`, `IsEllipse`, reading `GetGap()` after each acceptance. Neither `BRepGProp` nor
`ShapeAnalysis_Curve`, the other half of the old attribution, appears anywhere in the function.

This is the one finding `census-doc-occt-attribution.py` contributed, out of seven candidates it
raised for this family.

### O14. `checkOuterBound` still documents #1073's two gaps as open; PR #1140 closed both

`docs/reference/Document-Geometry-Constructors.md` said, of the cancellation and partial-pcurve
cases: "**Neither is fixed**, because the fix is a magnitude threshold against the face's own UV
scale and nobody has measured what it should be." That threshold is in the bridge:
`OCCTWireCheckOuterBound` (`OCCTBridge_Healing_Analysis.mm:1979`) requires **every** edge to carry a
pcurve on the probe face, then computes `faceAreaScale` from `ShapeAnalysis::GetFaceUVBounds` and
refuses when `|TotCross2D| < faceAreaScale * 1e-12`. #1073 is closed; `git log -S faceAreaScale`
puts it in `a307a31f` (PR #1140, 2026-08-26), which touched no reference page.

So the entry understated the guard, listed four `nil` cases where there are five, and told a reader
that a defect exists which does not. Corrected here. `ShapeAnalysis::GetFaceUVBounds`, the third of
that class's three statics reached by the bridge, is now named, which it was not before.

## The `under` findings

### U1. `nearestPlane`'s refusal rule was documented nowhere

`ShapeAnalysis_Geom::NearestPlane` (`ShapeAnalysis_Geom.cxx:27`) refuses unless the smallest
principal extent is strictly less than half of **each** of the other two. The doc said only "or
fitting fails". Measured:

```
   flat square                      -> fitted, maxDist 0.0000, normal (0.000, 0.000, 1.000)
   square + one point 3 units off   -> fitted, maxDist 0.7652, normal (0.150, -0.150, 0.977)
   square + one point 8 units off   -> fitted, maxDist 2.1319, normal (0.382, -0.382, 0.842)
   cube corners                     -> REFUSED
   -- refusal sweep, 10 x 10 corners lifted to +z --
   thickness 0     -> fitted, maxDist 0.0000
   thickness 4.9   -> fitted, maxDist 2.4500
   thickness 5     -> fitted, maxDist 2.5000
   thickness 5.1   -> REFUSED
   thickness 9     -> REFUSED
```

The cutoff on a 10-wide sheet is a thickness of 5, which is nowhere near "not planar". A caller
using a non-nil result as a planarity test is wrong for every cloud in between. `maxDeviation` is
the field that answers the question, and the page now says to gate on it. The sweep is the second
construction: the four named fixtures establish the behaviour and the sweep locates the boundary,
and they agree.

### U2. `BRepGraph_Copy` and `BRepGraph_Transform`

`copy(copyGeometry:)`, `copyFace(_:copyGeometry:)` and `translated(dx:dy:dz:copyGeometry:)` in
`docs/reference/BRepGraph-Detail-History.md` each had an `- **OCCT:**` line naming **only the bridge
function**, no OCCT class. `BRepGraph_Transform` appears nowhere in `docs/`, `CHANGELOG.md`
included.

Verified against the pinned source before writing the replacements: `BRepGraph_Copy.cxx:1192-1226`'s
`copyUIDAndGraphStateIdentity` transplants every node and ref UID counter plus `Generation` and
`GraphGUID`, and `BRepGraph_Transform.cxx:662` delegates to `BRepGraph_Copy::Perform`. So
`BRepGraph-Editor-Identity.md:845`'s claim that both "transplant the counter space, Generation and
GraphGUID" is **correct**, and the three entries now link to it and say which of `Perform` /
`CopyNode` each reaches, which is what makes `copyFace`'s fresh identity legible from its own entry.

### U3. The four UID types

The identity entries attributed the UID query and reverse lookup to `BRepGraph_NodeId` /
`BRepGraph_RefId` (the *inputs*), and to "`BRepGraph` item-UID layer" (not a class).
`BRepGraph_UID` appears in `docs/` exactly once, in `CHANGELOG.md`; `BRepGraph_RefUID`,
`BRepGraph_ItemUID` and `BRepGraph_ItemId` appear nowhere.

The eight lines now name the registry call each function makes, read off the bridge rather than
guessed: `UIDs().Of(...)`, `UIDs().NodeIdFrom(...)`, `UIDs().RefIdFrom(...)`,
`UIDs().ItemIdFrom(...)`, `UIDs().Has(...)`, and `BRepGraph_ItemId::ItemDomain()` for the domain
discriminator.

This is the `under` the brief predicted, and it is worth noting that the capability itself was
already documented **well**: `BRepGraph-Editor-Identity.md`'s scope section, its per-graph rule and
its inherited-versus-fresh table are all correct against the kernel. What was missing was only which
OCCT type each Swift struct wraps.

## The `deliberate, recorded` reasons

Six classes, each with a reason that can be stated rather than assumed:

- **`ShapeFix`** is not reached. Fourteen comments and one message-key string.
- **`BRepTopAdaptor_TopolTool`** is a domain-classification tool `Contap_Contour::Perform` demands
  as its second argument; it is constructed and destroyed inside two bridge functions and nothing
  about it reaches a caller.
- **`Bnd_Box2d`** is a local accumulator; the caller gets four doubles.
- **`BRepGraph_SupplementIterator`** is used by one file-static counting helper.
- **`BRepLib_MakePolygon`** and **`ShapeUpgrade_ClosedFaceDivide`** are reached only by bridge
  functions nothing calls, so no capability reaches the Swift surface for a doc to describe. Both
  are filed as #1640 rather than being papered over: the first is a duplicate that should be
  deleted, the second is a real capability that should be wrapped.

## Rejected candidates

`census-doc-occt-attribution.py` names one of my classes in seven findings. Adjudicated against the
real bridge body, **one is true** (O13) and six are not:

| finding | why rejected |
|---|---|
| `Document-Transforms.md:1449` `BRepBndLib::AddOBB` / `orientedBoundingBoxCorners` | accurate cross-function prose: "`Bnd_OBB::GetVertex` over the box built by `BRepBndLib::AddOBB`". The `AddOBB` call is in `OCCTShapeOrientedBoundingBox`, one function earlier. The census does not follow across bridge functions, the same rejection #811 recorded |
| `Geometry2D.md:934` and `Shape-Completions.md:1497` `BRepGProp::VolumeProperties` | both reach it through the shared helper `occtVolumeMassProperties` (`OCCTBridge_Properties.mm:81`), which is `BRepGProp::VolumeProperties(shape, props, true)`. Cross-file helper, the #811 rejection shape |
| `API_REFERENCE.md:623` `BRepGProp` / `surfaceType` | a paired table cell: `face.surfaceType` / `face.area(tolerance:)` maps to `GeomAdaptor_Surface` / `BRepGProp`. The census resolves the wrong half |
| `Measurement.md:221` and `:254` `BRepGraph` / `angle` | "Pure-Swift over `BRepGraph.resolve`", the OCCTSwift type, not the OCCT package |

That is a 14% true rate on this family, against the detector's measured 41% over a uniform sample.
The reason is the same one #811 gave for its outlier in the other direction: this family's claims
are dense in the shapes the detector resolves worst (shared helpers across files, paired table
cells) and thin in the one-class-per-bullet shape it resolves best. **The corrections here create no
new candidates**: every replacement names a class the bridge function's own body constructs.

## Anything I would have put in `gaps.md`, for the integrator

Two items, kept here per the brief's instruction not to touch `docs/occtswift-wrapping-gaps.md`:

1. **`ShapeFix`'s five statics are wrapped by nothing.** `SameParameter`, `EncodeRegularity`,
   `RemoveSmallEdges`, `FixVertexPosition` and `LeastEdgeSize`. Two of the five have same-named
   siblings in `BRepLib` that *are* wrapped (`BRepLib::SameParameter`, `BRepLib::EncodeRegularity`)
   and are not the same functions, which is worth a line wherever the gap is recorded so the next
   reader does not conclude they are covered.
2. **`BRepLib::UpdateEdgeTolerance`, the whole-shape tolerance sweep, is wrapped by nothing**, and
   until this PR the docs claimed it was. Its header warns it is "very slow as it checks all", so
   not wrapping it may well be right; it just was not recorded anywhere.

## Corrections to the brief

- **`over` was expected to be rare here and is the largest verdict class**, 14 of 31. The brief's
  reasoning ("the parsed-claim channels are already covered") does not hold for a class in *this*
  family, because the claim that misattributes `GProp_SelGProps` names `GProp_PGProps`, and it is
  `GProp_PGProps`'s coverage the census provides, not `GProp_SelGProps`'s. The two directions meet
  in the middle: the census asks "is the named class reached", this pass asks "is the reached class
  named", and both are needed.
- **The parsed-claim channel is covered but not clean.** 431 findings tree-wide were sitting
  unread; the coordinator corrected this mid-pass. Seven name this family's classes and are
  adjudicated above.
- **`derive_lane.py`'s `docs=` column counts `docs/CHANGELOG.md`.** Three of this family's
  `docs=yes` rows (`Bnd_Box2d`, `BRepGraph_UID`, and `BRepGraph_Copy` in part) are CHANGELOG-only.
  A changelog entry is a record that something once happened, not documentation of a current
  capability, and #811's own lane hit the same class of problem with `gaps.md`. Worth excluding, or
  at least splitting into a second column.
