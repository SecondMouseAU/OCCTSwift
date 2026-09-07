# #1399: the attribution census's 431 findings, adjudicated

`Scripts/census-doc-occt-attribution.py` reported **431 findings** and nobody had read one. #1399
counted 479 of its 643 unlaned classes as "machine-covered" because that detector checks them on
every run, which was true, and then treated the coverage as a result. Coverage by a detector
nobody reads is not coverage. This page is the read.

```bash
python3 Scripts/census-doc-occt-attribution.py     # 431 findings before, 230 after
```

## What was adjudicated, and what was not

| bucket | count |
|---|---:|
| findings reported at the start | 431 |
| skipped: the class belongs to a sibling lane's family (`healing`, `geometry`, `booleans`, `foundation`) | 8 |
| skipped: `docs/occtswift-wrapping-gaps.md`, the integrator's file | 1 |
| **adjudicated here** | **422** |

The sibling set comes from
`python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py --family <name>`, 134 classes
across the four families. Eight findings name one of them (`BRepGProp` x4, `BRepGraph` x2,
`BRepBndLib`, `BRepLib`) and are left to those lanes.

## The result, and a second data point on the false-positive rate

| verdict | count | share |
|---|---:|---:|
| real, doc corrected | 212 | 50.2% |
| false positive, recorded | 210 | 49.8% |

`Scripts/repro/928-over-coverage-detector/` measured **41.0%** over a 40-row hand-adjudicated
sample. This is the second data point: **49.8% over the whole 422**, so the sample was optimistic
by nine points but the right order. Reading the rest confirms what that sample implied, that the
detector reports rather than gates for a good reason.

The verdict is derived, not typed: a finding counts as real when the site it names no longer
appears in the census output after this branch's edits. Six are the exception and are counted real
by hand: `OCCTBridge_BRepGraph.h`'s six `Get*RefLocalLocation` comments were wrong (they promise a
`TopLoc_Location` the pinned kernel never returns), were corrected, and are still reported, because
the corrected text still names the class the accessor chain never spells.

## Why the false positives happen

Every code below is a shape of claim the census cannot resolve, not a shape of doc defect. Three of
them (`base`, `chain`, `helper`) are named in the script's own module docstring as measured
categories; the rest are new here.

| code | count | what the detector saw |
|---|---:|---|
| `heading` | 62 | the census resolved the enclosing heading to a bare Swift member name shared by other types, so `via` is a union that does not contain this entry's own bridge symbol |
| `enum` | 21 | the comment names the enum type of a value the function returns as a plain int, and never spells it |
| `base` | 21 | a base-class member called through a subclass-typed field or handle |
| `sibling-fn` | 19 | the OCCT call sits in a different bridge entry point the same Swift member also calls, or one that produced the value being read back |
| `helper` | 18 | the OCCT call sits in a helper `reachable()` does not follow (cross-file, or a lowercase file-local one) |
| `chain` | 14 | the class is the type of an accessor-chain result the bridge never names (`g->graph.Editor()`, `shape.Location()`, `DynamicType()`) |
| `contrastive` | 14 | the class is named in order to say it is NOT what runs, in a phrasing the marker lists do not catch |
| `scalar` | 11 | `Standard_Real` / `Standard_Boolean` / `Standard_Integer`, a scalar typedef named as a parameter type |
| `return-value` | 10 | the class name appears as an example of the string the function returns, not as a call |
| `param` | 9 | the class is a parameter, element or template type of the call, not the callee |
| `internal` | 9 | the claim describes an OCCT-internal step of the call it does name |
| `analogy` | 1 | the class is named as the OCCT concept a Swift field mirrors, not as a call |
| `precondition` | 1 | the class is named as a precondition the caller must have satisfied elsewhere |

`heading` is the largest single source by a wide margin, and it is a resolution artefact rather
than a reading problem: the census resolves a claim with no explicit `(via ...)` through the
enclosing heading's bare Swift member name, looked up in an index keyed on that name alone. A
heading of `` `init(points:)` `` resolves `init` to the union of every `OCCT*Create` in the bridge,
and `angle`, `point`, `apply`, `build`, `isEmpty` and `split` resolve just as widely. Sixty-two
findings are that union failing to contain the entry's own bridge symbol. `docs/API_REFERENCE.md`,
`docs/reference/FeatureReconstructor.md`, `docs/reference/Document-XCAF-Notes.md` and
`docs/reference/SheetMetal.md` are wholly explained by it: 42 findings between them, none real.

**If this census is ever promoted to a gate, `heading` is the sub-shape to re-resolve, not the
tier to drop.** The two tiers score almost the same overall: `explicit` (a claim naming its own
bridge symbol) is 106 real of 203, 52%; `heading` is 106 real of 219, 48%. The heading tier is
carried by `docs/reference/BRepGraph-Builders.md`, where 75 heading-resolved findings were all
real. Subtract that page and the heading tier is 31 real of 144, 22%, against `explicit`'s 52%.
So the resolution artefact is real and worth fixing, and it is not the whole tier.

## The 212 real ones

### A header file name is not a class name (109 findings, the three BRepGraph pages)

`BRepGraph_EditorView.hxx` declares `class BRepGraph::EditorView`, a class nested inside
`BRepGraph`, and the token `BRepGraph_EditorView` occurs in the pinned kernel **only** in that
filename and its include guard. `docs/reference/BRepGraph-Builders.md` named it 76 times.
The same page already used the correct convention in five entries
(`BRepGraph::Topo().CompSolids().Nb()`, `BRepGraph::ShapesView::Add`,
`BRepGraph::Mesh().Editor().Faces().Clear`), which is why those five were never reported.

Rewriting to `BRepGraph::Editor()...` is not the whole fix, and this is where per-entry reading
paid for itself:

- **Eleven named the wrong `Ops` sub-view.** The ref setters for wire, face, shell, solid and
  child live on `WireOps`, `FaceOps`, `ShellOps`, `SolidOps` and `GenOps`; the page attributed
  each to its *parent's* view (`setWireRef*` to `Faces()`, `setFaceRef*` to `Shells()`,
  `setShellRef*` to `Solids()`, `setSolidRef*` to `CompSolids()`, `setChildRef*` to
  `Compounds()`). Confirmed line by line against `BRepGraph_EditorView.hxx` in the pinned
  xcframework, not from the bridge alone.
- **Eight are not editor calls at all.** `edgeWires`, `edgeCoEdges`, `faceShellCount`,
  `faceShells`, `faceCompoundCount`, `shellCompoundCount`, `isShellClosed` and
  `solidCompoundCount` are read-only reverse lookups running `BRepGraph_WiresOfEdge`,
  `BRepGraph::Topo()` sub-views, `BRepGraph_ShellsOfFace`, the `BRepGraph_CompoundsOf*` iterators
  and `BRepGraph_Tool::Shell::IsClosed`.

`BRepGraph-Detail-History.md` and `BRepGraph-Editor-Identity.md` name eight more classes that do
not exist at all: `BRepGraph_CoEdge`, `BRepGraph_Shell`, `BRepGraph_Solid`, `BRepGraph_History`,
`BRepGraph_Face`, `BRepGraph_CoEdgeDef`, `BRepGraph_FaceDef`, `BRepGraph_RepStore`,
`BRepGraph_MeshCache`. The calls are `BRepGraph::Topo()` sub-views, `BRepGraph_Tool::CoEdge`,
`BRepGraph_SolidsOfShell` / `BRepGraph_CompSolidsOfSolid`, `BRepGraph_LayerHistory` and, for the
rep store, a bridge-side registry with no OCCT class behind it.

### Eight public setters that do nothing, documented as if they did

Found while adjudicating `BRepGraph-Editor-Identity.md`, and the reason the page named classes
that do not exist: the 8.0.0p1 kernel dropped the state they wrote, the bridge was rewritten to
no-ops **and says so in its own comments**, and the reference page was not touched.

| Swift member | bridge function | what the pinned kernel does |
|---|---|---|
| `setCoEdgeUVBox(_:u1:v1:u2:v2:)` | `OCCTBRepGraphSetCoEdgeUVBox` | empty body; a coedge's UV box is derived from the PCurve, not stored |
| `setVertexRefLocalLocation(_:matrix:)` | `OCCTBRepGraphSetVertexRefLocalLocation` | empty body; per-topology refs store no location in p1 |
| `setCoEdgeRefLocalLocation(_:matrix:)` | `OCCTBRepGraphSetCoEdgeRefLocalLocation` | empty body |
| `setWireRefLocalLocation(_:matrix:)` | `OCCTBRepGraphSetWireRefLocalLocation` | empty body |
| `setFaceRefLocalLocation(_:matrix:)` | `OCCTBRepGraphSetFaceRefLocalLocation` | empty body |
| `setShellRefLocalLocation(_:matrix:)` | `OCCTBRepGraphSetShellRefLocalLocation` | empty body |
| `setSolidRefLocalLocation(_:matrix:)` | `OCCTBRepGraphSetSolidRefLocalLocation` | empty body |
| `repSetPolygonOnTriTriangulationId(_:triRepId:)` | `OCCTBRepGraphRepSetPolygonOnTriTriangulationId` | empty body; the owning triangulation is resolved at attach time |

The six matching `get*RefLocalLocation` entry points return `false` unconditionally, and
`OCCTBridge_BRepGraph.h` documented them as getters with no note. Every one now carries the note
`setEdgeRegularity` already had. `repSetPolygonOnTriTriangulationId`'s reference entry even carried
a worked example telling the reader to call it.

**This is a code question, not only a doc question**, and it is filed as
[#1652](https://github.com/SecondMouseAU/OCCTSwift/issues/1652): a public Swift setter that
accepts arguments, returns nothing, and silently discards the call is a poor shape for an API,
whatever the docs say.

### A class the pinned kernel does not have (28 findings outside BRepGraph)

Every `ABSENT` finding was real. The name occurs nowhere in
`Libraries/OCCT.xcframework/macos-arm64/Headers`, checked with `grep -rlw` per name.

| page | named | runs |
|---|---|---|
| `Curve2D.md` | `Geom2dGcc_Circ2d2TanPt`, `Circ2dTanPtRad`, `Circ2d2PtRad`, `Circ2d3Pt`, `Lin2dTanPt` | `Geom2dGcc_Circ2d3Tan`, `Geom2dGcc_Circ2d2TanRad`, `Geom2dGcc_Lin2d2Tan` |
| `Document-Math-Bounds.md` | `OSD_MemInfo_Heap`, `OSD_MemInfo_WSet`, `ValueMiB` | `OSD_MemInfo::MemHeapUsage` / `MemWorkingSet`, `ValuePreciseMiB` |
| `Document-Math-Solvers.md` | `math_Laguerre`, `math_DirectPolynomialRoots` | `MathPoly::Laguerre` |
| `Document-Transforms.md` | `math_EigenVectors`, `math_Polynomial`, `math_IntegGauss` | `math_EigenValuesSearcher`, `MathPoly::Linear/Quadratic/Cubic/Quartic`, `MathInteg::Gauss` |
| `Document-Mesh-Fixing.md` | `HelixGeom_Helix`, `HelixGeom_ApproxCurve`, `GeomAPI_PointsToBSpline` | `HelixGeom_BuilderHelix`, `HelixGeom_BuilderHelixCoil`, `HelixGeom_HelixCurve`, `HelixGeom_Tools::ApprHelix` |
| `Shape-Builders-2.md` | `LProp_AnalyticCurInf` | a bridge-side fill of `LProp_CurAndInf` |
| `Shape-Features.md` | `GCPnts_UniformParameter`, `Draft_MakeDraft` | a `Geom_Curve::Value` sampling loop, `BRepOffsetAPI_DraftAngle` |
| `Shape-Healing.md` | `ShapeUpgrade_ShapeSplitAngle` | `ShapeUpgrade_ShapeDivideAngle` |
| `Shape-Recognition.md` | `ShapeUpgrade_ConvertSurfaceToBSplineSurface` | `ShapeCustom_ConvertToBSpline` under `BRepTools_Modifier` |

`math_Laguerre` and `math_Polynomial` are the same mistake as `BRepGraph_EditorView` in a different
package: `MathPoly` and `MathInteg` are namespaces, and `MathPoly_Laguerre.hxx` is the header that
holds `MathPoly::Laguerre`.

### A class that exists and is not the one running (69 findings)

The recurring shape is a plausible neighbour. Selected, one row per correction; the full list is in
the table below.

| page | named | runs |
|---|---|---|
| `Document-Analysis-Builders.md` | `GProp_PGProps` (x6) | `GProp_SelGProps` (surface), `GProp_VelGProps` (volume) |
| `Document-Analysis-Builders.md`, `Document-Geometry-Constructors.md` | `BndLib_Add3dCurve`, `BndLib_AddSurface` (x8) | `BndLib::Add` |
| `Document-Geometry-Constructors.md` | `GProp_PEquation`, `IntAna_QuadQuadGeo`, `ShapeAnalysis_Edge::GetEndTangent2d` | `GProp_SelGProps`/`GProp_VelGProps`, `IntAna_IntQuadQuad`, `ShapeAnalysis_Edge::BoundUV` |
| `Shape-Healing.md` | `ShapeUpgrade_UnifySameDomain` / `BRepAlgo_FaceRestrictor` | `BRepLib_FuseEdges` |
| `Shape-Healing.md` | `ShapeAnalysis_Curve` / `BRepGProp` | `ShapeAnalysis_CanonicalRecognition` |
| `Shape-Healing.md` | `BRepOffset_SimpleOffset`, `ShapeFix_Shape`, `BRepBuilderAPI_Sewing`, `ShapeUpgrade_ShapeDivideArea` | `BRepOffset_MakeSimpleOffset`, `ShapeUpgrade_RemoveInternalWires`, `BRepOffsetAPI_FindContigousEdges`, `ShapeUpgrade_ShapeDivide` + `ShapeUpgrade_FaceDivideArea` |
| `Shape-Measurement.md` | `ShapeFix_Shape` / `ShapeAnalysis_FreeBounds`, `BRepLib::SameParameter`, `ShapeAnalysis_Edge` | `ShapeFix_FreeBounds`, `BRepTools_PurgeLocations`, `BRepLib_CheckCurveOnSurface` |
| `Document-Transforms.md` | `ProjLib::Project` (x3) | `ProjLib_Plane`, `ProjLib_Cylinder` |
| `Document-Mesh-Fixing.md` | `GeomAPI_ExtremaCurveCurve`, `Extrema_ExtPS`, `Quantity_Color` | `GeomAPI_ProjectPointOnCurve`, `Extrema_GenLocateExtPS`, `Quantity_NameOfColor` |
| `Shape-Builders-2.md` | `Adaptor3d_IsoCurve` (edge entries only), `ShapeUpgrade_ConvertCurve3dToBezier`, `ShapeUpgrade_ConvertSurfaceToBezierBasis` | `Geom_Surface::UIso`/`VIso` + `BRepBuilderAPI_MakeEdge`, `ShapeUpgrade_ShapeConvertToBezier` |
| `Curve2D.md`, `Curve3D.md`, `Curve3D-Analysis.md` | `Geom2dConvert_ApproxCurve`, `GeomAdaptor_TransformedCurve`, `GeomLProp_CLProps::Torsion`, `Extrema_ExtPC` | `Geom2dConvert_ApproxArcsSegments`, `Geom_Geometry::Copy`+`Transform`, `Geom_Curve::D3`, `ExtremaPC_Curve` |
| `Document.md` | `XCAFDoc_Location`, `STEPCAFControl_Reader` | `XCAFDoc_ShapeTool::GetLocation`, the `XCAFDoc_LengthUnit` attribute |
| `Shape-Completions.md` | `ShapeAnalysis_FreeBounds` (x2) | `TopExp::MapShapesAndAncestors` |

Note the `Adaptor3d_IsoCurve` row: two of the four entries naming it were right (the point
samplers do construct one) and two were wrong (the edge builders do not). A blanket substitution
would have broken the two correct ones, which is the argument for reading each site.

### An OCCT call where there is none (6 findings)

Six of the 75 non-BRepGraph, non-absent reals are this shape rather than a wrong class.

`Shape.md`'s `fromWire`, `fromEdge` and `fromFace` credited "`TopoDS` shape-type promotion". A
`TopoDS_Wire` **is** a `TopoDS_Shape`; the bridge does a plain C++ upcast and never calls
`TopoDS::`. `Shape-Builders-2.md`'s 2D magnitude and normalize named `gp_Vec2d` where the bridge
does the arithmetic inline, which their own `vector2DCross` and `vector2DDot` siblings already
said. `Document-Persistence-IO.md` named `XCAFDoc_Color::GetColor` for a `GetNOC` call.

## Every finding

Sites are given at their pre-edit line numbers, so they can be matched against a census run on
`origin/refactor/1399-unlaned-coverage`.

| site | claimed class | verdict | reason |
|---|---|---|---|
| `Sources/OCCTBridge/include/OCCTBridge_BRepGraph.h:576` | `BRepGraph_ShapesView::CollectHistoryInputs` | real | fixed |
| `Sources/OCCTBridge/include/OCCTBridge_BRepGraph.h:811` | `TopAbs_Orientation` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_BRepGraph.h:1265` | `BRepGraph_Tool::CoEdge` | false positive | contrastive |
| `Sources/OCCTBridge/include/OCCTBridge_BRepGraph.h:1329` | `TopLoc_Location` | real | fixed; still reported (chain) |
| `Sources/OCCTBridge/include/OCCTBridge_BRepGraph.h:1338` | `TopLoc_Location` | real | fixed; still reported (chain) |
| `Sources/OCCTBridge/include/OCCTBridge_BRepGraph.h:1343` | `TopLoc_Location` | real | fixed; still reported (chain) |
| `Sources/OCCTBridge/include/OCCTBridge_BRepGraph.h:1348` | `TopLoc_Location` | real | fixed; still reported (chain) |
| `Sources/OCCTBridge/include/OCCTBridge_BRepGraph.h:1353` | `TopLoc_Location` | real | fixed; still reported (chain) |
| `Sources/OCCTBridge/include/OCCTBridge_BRepGraph.h:1358` | `TopLoc_Location` | real | fixed; still reported (chain) |
| `Sources/OCCTBridge/include/OCCTBridge_Curve3D.h:2157` | `GeomAbs_Shape` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Curve3D.h:2215` | `GeomAbs_CurveType` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Curve3D.h:2238` | `Extrema_GenLocateExtPS` | false positive | contrastive |
| `Sources/OCCTBridge/include/OCCTBridge_Curve3D.h:2238` | `Extrema_LocateExtPC` | false positive | contrastive |
| `Sources/OCCTBridge/include/OCCTBridge_Curve3D.h:2389` | `Geom_Circle` | false positive | return-value |
| `Sources/OCCTBridge/include/OCCTBridge_Curve3D.h:2389` | `Geom_Line` | false positive | return-value |
| `Sources/OCCTBridge/include/OCCTBridge_Document.h:809` | `TDocStd_Modified` | false positive | internal |
| `Sources/OCCTBridge/include/OCCTBridge_Document.h:1676` | `XCAFView_ProjectionType` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Geom2d.h:482` | `MAT_Right` | false positive | contrastive |
| `Sources/OCCTBridge/include/OCCTBridge_Geom2d.h:1899` | `GeomAbs_Shape` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Geom2d.h:2207` | `Geom2d_Circle` | false positive | return-value |
| `Sources/OCCTBridge/include/OCCTBridge_Geom2d.h:2207` | `Geom2d_Line` | false positive | return-value |
| `Sources/OCCTBridge/include/OCCTBridge_Healing.h:950` | `BRep_Tool::SameParameter` | false positive | contrastive |
| `Sources/OCCTBridge/include/OCCTBridge_Healing.h:986` | `TopAbs_ShapeEnum` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Healing.h:1468` | `Geom2d_TrimmedCurve` | false positive | internal |
| `Sources/OCCTBridge/include/OCCTBridge_Healing.h:1478` | `BRepCheck_Status` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Healing.h:1496` | `BRep_Tool` | false positive | contrastive |
| `Sources/OCCTBridge/include/OCCTBridge_Healing.h:1602` | `ShapeFix_Root` | false positive | base |
| `Sources/OCCTBridge/include/OCCTBridge_IO.h:137` | `TopAbs_ShapeEnum` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Modeling.h:2387` | `BRepBuilderAPI_NurbsConvert` | false positive | contrastive |
| `Sources/OCCTBridge/include/OCCTBridge_Modeling.h:4128` | `ChFiDS_ErrorStatus` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Spatial.h:164` | `Intrv_Position` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Surface.h:1055` | `Geom_BSplineSurface::SetUPeriodic` | false positive | internal |
| `Sources/OCCTBridge/include/OCCTBridge_Surface.h:1142` | `Geom_BSplineSurface::Segment` | false positive | internal |
| `Sources/OCCTBridge/include/OCCTBridge_Surface.h:1813` | `GeomAbs_Shape` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Surface.h:2268` | `GeomAbs_SurfaceType` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Surface.h:2366` | `Geom_Plane` | false positive | return-value |
| `Sources/OCCTBridge/include/OCCTBridge_Surface.h:2366` | `Geom_SphericalSurface` | false positive | return-value |
| `Sources/OCCTBridge/include/OCCTBridge_Topology.h:861` | `BRepMesh_IncrementalMesh` | false positive | precondition |
| `Sources/OCCTBridge/include/OCCTBridge_Topology.h:1770` | `GeomAbs_CurveType` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Topology.h:1788` | `GeomAbs_SurfaceType` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Topology.h:2036` | `GeomAbs_Shape` | false positive | enum |
| `Sources/OCCTBridge/include/OCCTBridge_Topology.h:2044` | `GeomAbs_Shape` | false positive | enum |
| `docs/API_REFERENCE.md:536` | `BRepAlgoAPI_Fuse` | false positive | heading |
| `docs/API_REFERENCE.md:537` | `BRepAlgoAPI_Cut` | false positive | heading |
| `docs/API_REFERENCE.md:538` | `BRepAlgoAPI_Common` | false positive | heading |
| `docs/API_REFERENCE.md:566` | `GC_MakeSegment` | false positive | heading |
| `docs/API_REFERENCE.md:569` | `GC_MakeSegment` | false positive | heading |
| `docs/API_REFERENCE.md:620` | `GeomLProp_SLProps` | false positive | heading |
| `docs/API_REFERENCE.md:623` | `BRepGProp` | skipped | sibling lane's class |
| `docs/API_REFERENCE.md:630` | `GeomAdaptor_Curve` | false positive | heading |
| `docs/API_REFERENCE.md:631` | `GeomLProp_CLProps` | false positive | heading |
| `docs/API_REFERENCE.md:672` | `TDF_TagSource::NewTag` | false positive | heading |
| `docs/API_REFERENCE.md:701` | `STEPControl_Reader` | false positive | heading |
| `docs/API_REFERENCE.md:867` | `GeomConvert_CurveToAnaCurve` | false positive | heading |
| `docs/API_REFERENCE.md:868` | `GeomConvert_SurfToAnaSurf` | false positive | heading |
| `docs/API_REFERENCE.md:972` | `TopExp::MapShapes` | false positive | heading |
| `docs/occtswift-wrapping-gaps.md:1719` | `XCAFDoc_Datum::SetObject` | skipped | integrator's file |
| `docs/reference/Annotation.md:162` | `Standard_Real` | false positive | scalar |
| `docs/reference/Annotation.md:244` | `Standard_Real` | false positive | scalar |
| `docs/reference/Annotation.md:275` | `TopoDS_Edge` | false positive | param |
| `docs/reference/Annotation.md:320` | `TopoDS_Face` | false positive | param |
| `docs/reference/Annotation.md:375` | `Standard_Real` | false positive | scalar |
| `docs/reference/Annotation.md:453` | `Standard_Real` | false positive | scalar |
| `docs/reference/BRepGraph-Builders.md:31` | `BRepGraph_EditorView` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:51` | `BRepGraph_EditorView` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:91` | `BRepGraph_EditorView` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:105` | `BRepGraph_EditorView` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:123` | `BRepGraph_EditorView` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:138` | `BRepGraph_EditorView` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:151` | `BRepGraph_EditorView` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:171` | `BRepGraph_EditorView` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:205` | `BRepGraph_EditorView::Vertices` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:224` | `BRepGraph_EditorView::Shells` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:243` | `BRepGraph_EditorView::Solids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:257` | `BRepGraph_EditorView::Shells` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:277` | `BRepGraph_EditorView::Solids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:291` | `BRepGraph_EditorView::Compounds` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:311` | `BRepGraph_EditorView::CompSolids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:326` | `BRepGraph_EditorView::Gen` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:343` | `BRepGraph_EditorView::Gen` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:400` | `BRepGraph_EditorView::BeginDeferredInvalidation` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:413` | `BRepGraph_EditorView::EndDeferredInvalidation` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:431` | `BRepGraph_EditorView::IsDeferredMode` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:443` | `BRepGraph_EditorView::CommitMutation` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:459` | `BRepGraph_EditorView::Edges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:480` | `BRepGraph_EditorView::Wires` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:501` | `BRepGraph_EditorView::Gen` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:553` | `BRepGraph_EditorView::ValidateMutationBoundary` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:576` | `BRepGraph_EditorView::Vertices` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:589` | `BRepGraph_EditorView::Vertices` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:602` | `BRepGraph_EditorView::Edges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:615` | `BRepGraph_EditorView::Edges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:680` | `BRepGraph_EditorView::CoEdges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:693` | `BRepGraph_EditorView::CoEdges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:719` | `BRepGraph_EditorView::Faces` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:761` | `BRepGraph_EditorView::Supplement` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:782` | `BRepGraph_EditorView::Supplement` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:796` | `BRepGraph_EditorView::Shells` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:811` | `BRepGraph_EditorView::Solids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:825` | `BRepGraph_EditorView::Compounds` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:845` | `BRepGraph_EditorView::CompSolids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:861` | `BRepGraph_EditorView::Edges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:875` | `BRepGraph_EditorView::Edges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:889` | `BRepGraph_EditorView::Wires` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:904` | `BRepGraph_EditorView::Supplement` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:904` | `BRepGraph_LayerTopoSupplement` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:918` | `BRepGraph_EditorView::Faces` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:932` | `BRepGraph_EditorView::Shells` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:946` | `BRepGraph_EditorView::Shells` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:960` | `BRepGraph_EditorView::Solids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:974` | `BRepGraph_EditorView::Solids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:988` | `BRepGraph_EditorView::Compounds` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1002` | `BRepGraph_EditorView::CompSolids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1032` | `BRepGraph_EditorView::Vertices` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1042` | `BRepGraph_EditorView::Vertices` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1052` | `BRepGraph_EditorView::Edges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1062` | `BRepGraph_EditorView::Edges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1072` | `BRepGraph_EditorView::Edges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1082` | `BRepGraph_EditorView::Edges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1102` | `BRepGraph_EditorView::CoEdges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1112` | `BRepGraph_EditorView::CoEdges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1122` | `BRepGraph_EditorView::CoEdges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1132` | `BRepGraph_EditorView::CoEdges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1142` | `BRepGraph_EditorView::CoEdges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1154` | `BRepGraph_EditorView::CoEdges` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1174` | `BRepGraph_EditorView::Faces` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1184` | `BRepGraph_EditorView::Faces` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1194` | `BRepGraph_EditorView::Faces` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1204` | `BRepGraph_EditorView::Shells` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1214` | `BRepGraph_EditorView::Shells` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1224` | `BRepGraph_EditorView::Solids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1234` | `BRepGraph_EditorView::Solids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1244` | `BRepGraph_EditorView::CompSolids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1254` | `BRepGraph_EditorView::CompSolids` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1264` | `BRepGraph_EditorView` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1274` | `BRepGraph_EditorView` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1284` | `BRepGraph_EditorView::Compounds` | real | fixed |
| `docs/reference/BRepGraph-Builders.md:1294` | `BRepGraph_EditorView::Compounds` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:28` | `BRepGraph_CoEdge::Edge` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:46` | `BRepGraph_CoEdge::Face` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:64` | `BRepGraph_CoEdge::SeamPair` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:83` | `BRepGraph_CoEdge::HasPCurve` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:103` | `BRepGraph_CoEdge::Range` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:122` | `BRepGraph_Shell` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:140` | `BRepGraph_Shell` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:159` | `BRepGraph_Solid` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:177` | `BRepGraph_History::NbRecords` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:193` | `BRepGraph_History::IsEnabled` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:209` | `BRepGraph_History::Clear` | real | fixed |
| `docs/reference/BRepGraph-Detail-History.md:906` | `BRepGraph_Face::SameDomain` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:31` | `BRepGraph_CoEdgeDef` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:55` | `BRepGraph_LayerRegularity` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:83` | `BRepGraph_FaceDef` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:97` | `BRepGraph_RepStore` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:116` | `BRepGraph_CoEdgeDef` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:155` | `TopLoc_Location` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:155` | `gp_Trsf::SetValues` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:169` | `TopLoc_Location` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:181` | `TopLoc_Location` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:193` | `TopLoc_Location` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:205` | `TopLoc_Location` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:217` | `TopLoc_Location` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:383` | `BRepGraph_RepStore` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:395` | `BRepGraph_RepStore` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:407` | `BRepGraph_RepStore` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:419` | `BRepGraph_RepStore` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:431` | `BRepGraph_RepStore` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:443` | `BRepGraph_RepStore` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:455` | `BRepGraph_RepStore` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:468` | `BRepGraph_RepStore` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:492` | `BRepGraph_MeshCache` | real | fixed |
| `docs/reference/BRepGraph-Editor-Identity.md:809` | `GeomAdaptor_Curve` | real | fixed |
| `docs/reference/Color-Material.md:795` | `Graphic3d_MaterialAspect` | false positive | analogy |
| `docs/reference/Curve2D-Analysis.md:228` | `Geom2dAdaptor_Curve` | false positive | heading |
| `docs/reference/Curve2D.md:1063` | `Geom2dConvert_ApproxCurve` | real | fixed |
| `docs/reference/Curve2D.md:1225` | `Geom2dGcc_Circ2d2TanPt` | real | fixed |
| `docs/reference/Curve2D.md:1293` | `Geom2dGcc_Circ2dTanPtRad` | real | fixed |
| `docs/reference/Curve2D.md:1316` | `Geom2dGcc_Circ2d2PtRad` | real | fixed |
| `docs/reference/Curve2D.md:1337` | `Geom2dGcc_Circ2d3Pt` | real | fixed |
| `docs/reference/Curve2D.md:1388` | `Geom2dGcc_Lin2dTanPt` | real | fixed |
| `docs/reference/Curve3D-Analysis.md:124` | `GeomLProp_CLProps::Torsion` | real | fixed |
| `docs/reference/Curve3D-Analysis.md:1367` | `Extrema_ExtPC` | false positive | heading |
| `docs/reference/Curve3D-Analysis.md:1392` | `Extrema_ExtPC` | false positive | heading |
| `docs/reference/Curve3D-Analysis.md:1392` | `GeomAdaptor_Curve` | false positive | heading |
| `docs/reference/Curve3D-Analysis.md:1416` | `Extrema_ExtPC` | real | fixed |
| `docs/reference/Curve3D-Analytic-Types.md:217` | `gp_Circ::Location` | false positive | chain |
| `docs/reference/Curve3D-Analytic-Types.md:1130` | `GeomAbs_Shape` | false positive | enum |
| `docs/reference/Curve3D.md:247` | `Geom_TrimmedCurve` | false positive | return-value |
| `docs/reference/Curve3D.md:290` | `Geom_TrimmedCurve` | false positive | return-value |
| `docs/reference/Curve3D.md:1054` | `Geom_TrimmedCurve` | false positive | return-value |
| `docs/reference/Curve3D.md:1086` | `Geom_TrimmedCurve` | false positive | return-value |
| `docs/reference/Curve3D.md:1343` | `GeomAdaptor_TransformedCurve` | real | fixed |
| `docs/reference/DateTime.md:59` | `Quantity_Date` | false positive | heading |
| `docs/reference/DateTime.md:471` | `Quantity_Period` | false positive | heading |
| `docs/reference/DateTime.md:471` | `Quantity_Period::IsValid` | false positive | heading |
| `docs/reference/DateTime.md:495` | `Quantity_Period` | false positive | heading |
| `docs/reference/DateTime.md:495` | `Quantity_Period::IsValid` | false positive | heading |
| `docs/reference/Display.md:1236` | `Font_SystemFont` | false positive | param |
| `docs/reference/Display.md:1236` | `NCollection_List` | false positive | param |
| `docs/reference/Display.md:1255` | `Font_SystemFont::FontName` | false positive | chain |
| `docs/reference/Display.md:1278` | `Font_SystemFont::FontPath` | false positive | chain |
| `docs/reference/Display.md:1298` | `Font_SystemFont::HasFontAspect` | false positive | chain |
| `docs/reference/Document-Analysis-Builders.md:1282` | `BndLib_Add3dCurve` | real | fixed |
| `docs/reference/Document-Analysis-Builders.md:1307` | `BndLib_AddSurface` | real | fixed |
| `docs/reference/Document-Analysis-Builders.md:1486` | `GProp_PGProps` | real | fixed |
| `docs/reference/Document-Analysis-Builders.md:1498` | `GProp_PGProps` | real | fixed |
| `docs/reference/Document-Analysis-Builders.md:1511` | `GProp_PGProps` | real | fixed |
| `docs/reference/Document-Analysis-Builders.md:1523` | `GProp_PGProps` | real | fixed |
| `docs/reference/Document-Analysis-Builders.md:2003` | `GProp_PGProps` | real | fixed |
| `docs/reference/Document-Analysis-Builders.md:2015` | `GProp_PGProps` | real | fixed |
| `docs/reference/Document-BSpline-Extrema.md:255` | `TopoDS_TShape::NbChildren` | false positive | internal |
| `docs/reference/Document-BSpline-Extrema.md:342` | `Geom_BSplineSurface::NbUPoles` | false positive | internal |
| `docs/reference/Document-Geometry-Constructors.md:257` | `BndLib_Add3dCurve` | real | fixed |
| `docs/reference/Document-Geometry-Constructors.md:278` | `BndLib_AddSurface` | real | fixed |
| `docs/reference/Document-Geometry-Constructors.md:298` | `BndLib_Add3dCurve` | real | fixed |
| `docs/reference/Document-Geometry-Constructors.md:319` | `BndLib_Add3dCurve` | real | fixed |
| `docs/reference/Document-Geometry-Constructors.md:340` | `BndLib_Add3dCurve` | real | fixed |
| `docs/reference/Document-Geometry-Constructors.md:361` | `BndLib_Add3dCurve` | real | fixed |
| `docs/reference/Document-Geometry-Constructors.md:384` | `GProp_GProps` | real | fixed |
| `docs/reference/Document-Geometry-Constructors.md:384` | `GProp_PEquation` | real | fixed |
| `docs/reference/Document-Geometry-Constructors.md:403` | `GProp_GProps` | real | fixed |
| `docs/reference/Document-Geometry-Constructors.md:664` | `Standard_Boolean` | false positive | scalar |
| `docs/reference/Document-Geometry-Constructors.md:975` | `IntAna_QuadQuadGeo` | real | fixed |
| `docs/reference/Document-Geometry-Constructors.md:2159` | `BRep_Tool::CurveOnSurface` | real | fixed |
| `docs/reference/Document-Math-Bounds.md:571` | `Standard_Real` | false positive | scalar |
| `docs/reference/Document-Math-Bounds.md:863` | `OSD_MemInfo_Heap` | real | fixed |
| `docs/reference/Document-Math-Bounds.md:875` | `OSD_MemInfo_WSet` | real | fixed |
| `docs/reference/Document-Math-Bounds.md:887` | `OSD_MemInfo_Heap` | real | fixed |
| `docs/reference/Document-Math-Bounds.md:1748` | `XCAFDoc_AssemblyItemId` | false positive | chain |
| `docs/reference/Document-Math-Bounds.md:1748` | `XCAFDoc_AssemblyItemId::ToString` | false positive | chain |
| `docs/reference/Document-Math-Bounds.md:1907` | `OSD_Path::Name` | false positive | helper |
| `docs/reference/Document-Math-Bounds.md:1923` | `OSD_Path::Extension` | false positive | helper |
| `docs/reference/Document-Math-Bounds.md:1939` | `OSD_Path::Trek` | false positive | helper |
| `docs/reference/Document-Math-Bounds.md:1951` | `OSD_Path::SystemName` | false positive | helper |
| `docs/reference/Document-Math-Bounds.md:2642` | `Convert_CompPolynomialToPoles` | real | fixed |
| `docs/reference/Document-Math-Solvers.md:515` | `TopAbs_ShapeEnum` | false positive | enum |
| `docs/reference/Document-Math-Solvers.md:557` | `Geom_Geometry::Copy` | false positive | base |
| `docs/reference/Document-Math-Solvers.md:594` | `Geom2d_Geometry::Copy` | false positive | base |
| `docs/reference/Document-Math-Solvers.md:659` | `Geom_Geometry::Copy` | false positive | base |
| `docs/reference/Document-Math-Solvers.md:713` | `math_FunctionRoots` | real | fixed |
| `docs/reference/Document-Math-Solvers.md:1039` | `math_DirectPolynomialRoots` | real | fixed |
| `docs/reference/Document-Math-Solvers.md:1039` | `math_Laguerre` | real | fixed |
| `docs/reference/Document-Math-Solvers.md:1058` | `math_Laguerre` | real | fixed |
| `docs/reference/Document-Math-Solvers.md:1076` | `math_DirectPolynomialRoots` | real | fixed |
| `docs/reference/Document-Mesh-Fixing.md:120` | `RWMesh_ShapeIterator` | false positive | base |
| `docs/reference/Document-Mesh-Fixing.md:242` | `TopoDS_Vertex` | false positive | heading |
| `docs/reference/Document-Mesh-Fixing.md:516` | `TopLoc_Location::IsIdentity` | false positive | chain |
| `docs/reference/Document-Mesh-Fixing.md:557` | `TopAbs_ShapeEnum` | false positive | enum |
| `docs/reference/Document-Mesh-Fixing.md:647` | `TopoDS_Builder` | false positive | base |
| `docs/reference/Document-Mesh-Fixing.md:663` | `BRepCheck_Face::Status` | false positive | base |
| `docs/reference/Document-Mesh-Fixing.md:676` | `BRepCheck_Edge::Status` | false positive | base |
| `docs/reference/Document-Mesh-Fixing.md:689` | `BRepCheck_Vertex::Status` | false positive | base |
| `docs/reference/Document-Mesh-Fixing.md:960` | `Extrema_ExtPC` | real | fixed |
| `docs/reference/Document-Mesh-Fixing.md:960` | `GeomAPI_ExtremaCurveCurve` | real | fixed |
| `docs/reference/Document-Mesh-Fixing.md:989` | `Extrema_ExtPS` | real | fixed |
| `docs/reference/Document-Mesh-Fixing.md:2004` | `ShapeFix_Root::Status` | false positive | base |
| `docs/reference/Document-Mesh-Fixing.md:2017` | `ShapeFix_Root::SetMaxTolerance` | false positive | base |
| `docs/reference/Document-Mesh-Fixing.md:3431` | `Quantity_Color` | real | fixed |
| `docs/reference/Document-Mesh-Fixing.md:3574` | `Standard_Type::Name` | false positive | chain |
| `docs/reference/Document-Mesh-Fixing.md:3598` | `Standard_Type::Name` | false positive | chain |
| `docs/reference/Document-Mesh-Fixing.md:3623` | `Standard_Type::Name` | false positive | chain |
| `docs/reference/Document-Mesh-Fixing.md:3690` | `GeomAPI_PointsToBSpline` | real | fixed |
| `docs/reference/Document-Mesh-Fixing.md:3690` | `HelixGeom_Helix` | real | fixed |
| `docs/reference/Document-Mesh-Fixing.md:3723` | `HelixGeom_Helix` | real | fixed |
| `docs/reference/Document-Mesh-Fixing.md:3744` | `HelixGeom_Helix::Value` | real | fixed |
| `docs/reference/Document-Mesh-Fixing.md:3763` | `HelixGeom_Helix::D1` | real | fixed |
| `docs/reference/Document-Mesh-Fixing.md:3782` | `HelixGeom_Helix::D2` | real | fixed |
| `docs/reference/Document-Mesh-Fixing.md:3802` | `HelixGeom_ApproxCurve` | real | fixed |
| `docs/reference/Document-OCAF-Attributes.md:195` | `TDF_IDFilter` | false positive | heading |
| `docs/reference/Document-OCAF-Attributes.md:213` | `Standard_Boolean` | false positive | scalar |
| `docs/reference/Document-OCAF-Attributes.md:1218` | `Geom_Transformation` | false positive | heading |
| `docs/reference/Document-OCAF-Attributes.md:1330` | `gp_Trsf::Transforms` | false positive | heading |
| `docs/reference/Document-OCAF-Attributes.md:1593` | `TNaming_Tool` | false positive | contrastive |
| `docs/reference/Document-OCAF-Attributes.md:1607` | `TNaming_Tool` | false positive | contrastive |
| `docs/reference/Document-OCAF-Attributes.md:1757` | `Standard_Real` | false positive | scalar |
| `docs/reference/Document-OCAF-Attributes.md:1770` | `Standard_Integer` | false positive | scalar |
| `docs/reference/Document-OCAF-Attributes.md:2795` | `Standard_Real` | false positive | scalar |
| `docs/reference/Document-Persistence-IO.md:1024` | `RWMesh_CoordinateSystemConverter` | false positive | param |
| `docs/reference/Document-Persistence-IO.md:2008` | `Quantity_Color::Name` | real | fixed |
| `docs/reference/Document-Persistence-IO.md:2137` | `XCAFDoc_Note::UserName` | false positive | base |
| `docs/reference/Document-Transforms.md:681` | `math_EigenVectors` | real | fixed |
| `docs/reference/Document-Transforms.md:698` | `math_EigenVectors` | real | fixed |
| `docs/reference/Document-Transforms.md:824` | `math_Polynomial` | real | fixed |
| `docs/reference/Document-Transforms.md:837` | `math_Polynomial` | real | fixed |
| `docs/reference/Document-Transforms.md:850` | `math_Polynomial` | real | fixed |
| `docs/reference/Document-Transforms.md:863` | `math_Polynomial` | real | fixed |
| `docs/reference/Document-Transforms.md:883` | `math_IntegGauss` | real | fixed |
| `docs/reference/Document-Transforms.md:1270` | `ProjLib::Project` | real | fixed |
| `docs/reference/Document-Transforms.md:1285` | `ProjLib::Project` | real | fixed |
| `docs/reference/Document-Transforms.md:1301` | `ProjLib::Project` | real | fixed |
| `docs/reference/Document-Transforms.md:1449` | `BRepBndLib::AddOBB` | skipped | sibling lane's class |
| `docs/reference/Document-Transforms.md:1691` | `gp_Trsf::IsNegative` | false positive | chain |
| `docs/reference/Document-XCAF-Notes.md:370` | `XCAFDoc_AssemblyGraph` | false positive | heading |
| `docs/reference/Document-XCAF-Notes.md:508` | `XCAFDoc_AssemblyItemId` | false positive | heading |
| `docs/reference/Document-XCAF-Notes.md:594` | `XCAFView_Object` | false positive | heading |
| `docs/reference/Document-XCAF-Notes.md:913` | `XCAFNoteObjects_NoteObject` | false positive | heading |
| `docs/reference/Document-XCAF-Notes.md:1062` | `XCAFPrs_Style` | false positive | heading |
| `docs/reference/Document-XCAF-Notes.md:1080` | `XCAFPrs_Style::SetColorSurf` | false positive | heading |
| `docs/reference/Document-XCAF-Notes.md:1136` | `XCAFPrs_Style::IsEmpty` | false positive | heading |
| `docs/reference/Document.md:273` | `XCAFDoc_Location` | real | fixed |
| `docs/reference/Document.md:625` | `TNaming_Builder::Select` | false positive | contrastive |
| `docs/reference/Document.md:699` | `STEPCAFControl_Reader` | real | fixed |
| `docs/reference/Drawing.md:132` | `HLRBRep_HLRToShape` | false positive | sibling-fn |
| `docs/reference/Drawing.md:132` | `HLRBRep_PolyHLRToShape` | false positive | sibling-fn |
| `docs/reference/Drawing.md:148` | `HLRBRep_HLRToShape` | false positive | sibling-fn |
| `docs/reference/Drawing.md:148` | `HLRBRep_PolyHLRToShape` | false positive | sibling-fn |
| `docs/reference/Drawing.md:787` | `HLRBRep_HLRToShape` | false positive | sibling-fn |
| `docs/reference/Drawing.md:1655` | `Aspect_TypeOfDeflection` | false positive | enum |
| `docs/reference/Export-Vector.md:1122` | `Image_PixMap` | false positive | param |
| `docs/reference/Face.md:734` | `TopExp::MapShapes` | false positive | heading |
| `docs/reference/FeatureRecognition.md:146` | `ChFi3d::DefineConnectType` | false positive | heading |
| `docs/reference/FeatureReconstructor.md:142` | `BRepPrimAPI_MakeRevol` | false positive | heading |
| `docs/reference/FeatureReconstructor.md:200` | `BRepPrimAPI_MakePrism` | false positive | heading |
| `docs/reference/FeatureReconstructor.md:258` | `BRepAlgoAPI_Cut` | false positive | heading |
| `docs/reference/FeatureReconstructor.md:258` | `BRepPrimAPI_MakeCylinder` | false positive | heading |
| `docs/reference/FeatureReconstructor.md:483` | `BRepAlgoAPI_Common` | false positive | heading |
| `docs/reference/FeatureReconstructor.md:483` | `BRepAlgoAPI_Cut` | false positive | heading |
| `docs/reference/FeatureReconstructor.md:483` | `BRepAlgoAPI_Fuse` | false positive | heading |
| `docs/reference/Geometry2D.md:696` | `gp_Trsf2d::Transforms` | false positive | heading |
| `docs/reference/Geometry2D.md:934` | `BRepGProp::VolumeProperties` | skipped | sibling lane's class |
| `docs/reference/Geometry2D.md:964` | `Geom_ElementarySurface` | false positive | base |
| `docs/reference/Geometry2D.md:964` | `gp_Ax3` | false positive | internal |
| `docs/reference/Geometry2D.md:1017` | `Geom2d_AxisPlacement` | real | fixed |
| `docs/reference/Geometry2D.md:1017` | `gp_Dir2d` | real | fixed |
| `docs/reference/Geometry2D.md:1017` | `gp_Pnt2d` | real | fixed |
| `docs/reference/GeometrySolvers.md:1036` | `NCollection_KDTree` | false positive | heading |
| `docs/reference/GeometrySolvers.md:1036` | `gp_Pnt` | false positive | heading |
| `docs/reference/Measurement.md:36` | `BRepAdaptor_Curve::DN` | false positive | sibling-fn |
| `docs/reference/Measurement.md:114` | `GeomLProp_SLProps::Normal` | false positive | sibling-fn |
| `docs/reference/Measurement.md:221` | `BRepGraph` | skipped | sibling lane's class |
| `docs/reference/Measurement.md:254` | `BRepGraph` | skipped | sibling lane's class |
| `docs/reference/Mesh.md:352` | `BRepAlgoAPI_Fuse` | false positive | sibling-fn |
| `docs/reference/Mesh.md:352` | `BRepBuilderAPI_Sewing` | false positive | sibling-fn |
| `docs/reference/Mesh.md:352` | `BRepMesh_IncrementalMesh` | false positive | sibling-fn |
| `docs/reference/Mesh.md:381` | `BRepAlgoAPI_Cut` | false positive | sibling-fn |
| `docs/reference/Mesh.md:381` | `BRepBuilderAPI_Sewing` | false positive | sibling-fn |
| `docs/reference/Mesh.md:381` | `BRepMesh_IncrementalMesh` | false positive | sibling-fn |
| `docs/reference/Mesh.md:404` | `BRepAlgoAPI_Common` | false positive | sibling-fn |
| `docs/reference/Mesh.md:404` | `BRepBuilderAPI_Sewing` | false positive | sibling-fn |
| `docs/reference/Mesh.md:404` | `BRepMesh_IncrementalMesh` | false positive | sibling-fn |
| `docs/reference/Selection.md:481` | `SelectMgr_ViewerSelector` | false positive | helper |
| `docs/reference/Selection.md:702` | `SelectMgr_ViewerSelector::SetPixelTolerance` | false positive | helper |
| `docs/reference/Selection.md:731` | `SelectMgr_ViewerSelector::Pick` | false positive | helper |
| `docs/reference/Selection.md:761` | `SelectMgr_ViewerSelector::Pick` | false positive | helper |
| `docs/reference/Selection.md:793` | `SelectMgr_ViewerSelector::Pick` | false positive | helper |
| `docs/reference/Shape-Builders-1.md:1233` | `gp_Pln` | real | fixed |
| `docs/reference/Shape-Builders-1.md:1492` | `GCPnts_UniformDeflection` | false positive | helper |
| `docs/reference/Shape-Builders-1.md:1512` | `GCPnts_UniformDeflection` | false positive | helper |
| `docs/reference/Shape-Builders-2.md:178` | `Adaptor3d_IsoCurve` | real | fixed |
| `docs/reference/Shape-Builders-2.md:196` | `Adaptor3d_IsoCurve` | real | fixed |
| `docs/reference/Shape-Builders-2.md:668` | `ShapeUpgrade_ConvertCurve3dToBezier` | real | fixed |
| `docs/reference/Shape-Builders-2.md:689` | `ShapeUpgrade_ConvertSurfaceToBezierBasis` | real | fixed |
| `docs/reference/Shape-Builders-2.md:723` | `gp_Vec2d` | false positive | contrastive |
| `docs/reference/Shape-Builders-2.md:739` | `gp_Vec2d` | false positive | contrastive |
| `docs/reference/Shape-Builders-2.md:755` | `gp_Vec2d::Magnitude` | real | fixed |
| `docs/reference/Shape-Builders-2.md:771` | `gp_Vec2d::Normalized` | real | fixed |
| `docs/reference/Shape-Builders-2.md:875` | `LProp_AnalyticCurInf` | real | fixed |
| `docs/reference/Shape-Completions.md:827` | `GeomFill_SectionPlacement::Perform` | false positive | heading |
| `docs/reference/Shape-Completions.md:1442` | `ShapeAnalysis_FreeBounds` | real | fixed |
| `docs/reference/Shape-Completions.md:1454` | `ShapeAnalysis_FreeBounds` | real | fixed |
| `docs/reference/Shape-Completions.md:1479` | `BRepGProp::VolumeProperties` | skipped | sibling lane's class |
| `docs/reference/Shape-Completions.md:1653` | `ShapeFix_Root::SetPrecision` | false positive | base |
| `docs/reference/Shape-Completions.md:1665` | `ShapeFix_Root::SetMaxTolerance` | false positive | base |
| `docs/reference/Shape-Completions.md:1677` | `ShapeFix_Root::SetMinTolerance` | false positive | base |
| `docs/reference/Shape-Features.md:262` | `BRepAlgoAPI_BuilderAlgo` | false positive | heading |
| `docs/reference/Shape-Features.md:286` | `BRepAlgoAPI_BuilderAlgo` | false positive | heading |
| `docs/reference/Shape-Features.md:842` | `GCPnts_UniformParameter` | real | fixed |
| `docs/reference/Shape-Features.md:876` | `BRepAlgoAPI_Fuse` | false positive | heading |
| `docs/reference/Shape-Features.md:889` | `BRepAlgoAPI_Cut` | false positive | heading |
| `docs/reference/Shape-Features.md:902` | `BRepAlgoAPI_Common` | false positive | heading |
| `docs/reference/Shape-Features.md:1090` | `XCAFDoc_Centroid` | false positive | contrastive |
| `docs/reference/Shape-Features.md:1140` | `BRepExtrema_DistShapeShape` | false positive | heading |
| `docs/reference/Shape-Features.md:1194` | `TopExp::MapShapes` | false positive | sibling-fn |
| `docs/reference/Shape-Features.md:1455` | `Draft_MakeDraft` | real | fixed |
| `docs/reference/Shape-Features.md:1856` | `BOPAlgo_ArgumentAnalyzer` | false positive | sibling-fn |
| `docs/reference/Shape-Features.md:1856` | `ShapeAnalysis_CheckSmallFace` | false positive | sibling-fn |
| `docs/reference/Shape-Features.md:2399` | `GeomPlate_MakeApprox` | false positive | helper |
| `docs/reference/Shape-HLR-Geom.md:1589` | `Geom_Point::Distance` | false positive | base |
| `docs/reference/Shape-HLR-Geom.md:1607` | `Geom_Point::SquareDistance` | false positive | base |
| `docs/reference/Shape-HLR-Geom.md:1773` | `Geom_Vector::X` | real | fixed |
| `docs/reference/Shape-HLR-Geom.md:1785` | `Geom_Vector::Magnitude` | false positive | base |
| `docs/reference/Shape-HLR-Geom.md:1797` | `Geom_Vector::Dot` | false positive | base |
| `docs/reference/Shape-HLR-Geom.md:1809` | `gp_Vec::Added` | real | fixed |
| `docs/reference/Shape-Healing.md:114` | `ShapeCustom_DirectModification` | real | fixed |
| `docs/reference/Shape-Healing.md:136` | `ShapeCustom_TrsfModification` | real | fixed |
| `docs/reference/Shape-Healing.md:209` | `ShapeCustom_SweptToElementary` | real | fixed |
| `docs/reference/Shape-Healing.md:228` | `BRepTools_Modifier` | false positive | internal |
| `docs/reference/Shape-Healing.md:863` | `BRepOffset_SimpleOffset` | real | fixed |
| `docs/reference/Shape-Healing.md:908` | `BRepAlgo_FaceRestrictor` | real | fixed |
| `docs/reference/Shape-Healing.md:908` | `ShapeUpgrade_UnifySameDomain` | real | fixed |
| `docs/reference/Shape-Healing.md:1073` | `BRepGProp` | skipped | sibling lane's class |
| `docs/reference/Shape-Healing.md:1073` | `ShapeAnalysis_Curve` | real | fixed |
| `docs/reference/Shape-Healing.md:1100` | `BRepBuilderAPI_FindPlane` | false positive | contrastive |
| `docs/reference/Shape-Healing.md:1150` | `ShapeFix_Shape` | real | fixed |
| `docs/reference/Shape-Healing.md:1172` | `BRepBuilderAPI_Sewing` | real | fixed |
| `docs/reference/Shape-Healing.md:1649` | `BRepLProp_SLProps::TangentU` | false positive | heading |
| `docs/reference/Shape-Healing.md:1788` | `ShapeUpgrade_ShapeSplitAngle` | real | fixed |
| `docs/reference/Shape-Healing.md:2082` | `ShapeUpgrade_ShapeDivideArea` | real | fixed |
| `docs/reference/Shape-Healing.md:2170` | `BRepAlgoAPI_BuilderAlgo::Modified` | false positive | base |
| `docs/reference/Shape-Healing.md:2539` | `ShapeBuild_ReShape` | false positive | chain |
| `docs/reference/Shape-Healing.md:2592` | `ShapeBuild_ReShape` | false positive | chain |
| `docs/reference/Shape-Measurement.md:71` | `TopExp::MapShapes` | false positive | heading |
| `docs/reference/Shape-Measurement.md:176` | `TopExp::MapShapes` | false positive | heading |
| `docs/reference/Shape-Measurement.md:451` | `ShapeAnalysis_FreeBounds` | real | fixed |
| `docs/reference/Shape-Measurement.md:451` | `ShapeFix_Shape` | real | fixed |
| `docs/reference/Shape-Measurement.md:1137` | `BRepLib::SameParameter` | skipped | sibling lane's class |
| `docs/reference/Shape-Measurement.md:1176` | `ShapeAnalysis_Edge` | real | fixed |
| `docs/reference/Shape-Measurement.md:2539` | `BRepExtrema_ExtFF` | false positive | internal |
| `docs/reference/Shape-Recognition.md:905` | `ShapeUpgrade_ConvertSurfaceToBSplineSurface` | real | fixed |
| `docs/reference/Shape.md:1207` | `TopoDS` | real | fixed |
| `docs/reference/Shape.md:1229` | `TopoDS` | real | fixed |
| `docs/reference/Shape.md:1245` | `TopoDS` | real | fixed |
| `docs/reference/Shape.md:1349` | `Message_ProgressRange` | false positive | chain |
| `docs/reference/Shape.md:1414` | `GCPnts_TangentialDeflection` | false positive | helper |
| `docs/reference/Shape.md:1443` | `GCPnts_TangentialDeflection` | false positive | helper |
| `docs/reference/Shape.md:1694` | `BRepBuilderAPI_MakeSolid` | false positive | helper |
| `docs/reference/Shape.md:2012` | `BRepBuilderAPI_MakeShapeOnMesh` | false positive | helper |
| `docs/reference/Shape.md:2012` | `TopoDS_Face` | false positive | helper |
| `docs/reference/Shape.md:2047` | `BRepBuilderAPI_MakeSolid` | false positive | helper |
| `docs/reference/SheetMetal.md:374` | `BRepAlgoAPI_Fuse` | false positive | heading |
| `docs/reference/SheetMetal.md:374` | `BRepBuilderAPI_MakeWire` | false positive | heading |
| `docs/reference/SheetMetal.md:374` | `BRepPrimAPI_MakePrism` | false positive | heading |
| `docs/reference/SheetMetal.md:374` | `GC_MakeArcOfCircle` | false positive | heading |
| `docs/reference/SheetMetal.md:374` | `GC_MakeSegment` | false positive | heading |
| `docs/reference/Surface-Advanced.md:424` | `gp_Ax3` | false positive | param |
| `docs/reference/Surface-Advanced.md:479` | `gp_Ax3` | false positive | param |
| `docs/reference/Surface-Advanced.md:1396` | `Standard_Real` | false positive | scalar |
| `docs/reference/Surface-Analysis.md:718` | `GeomConvert_ApproxSurface` | false positive | heading |
| `docs/reference/Surface-BSpline-Bezier.md:65` | `TColgp_Array2OfPnt` | false positive | param |
| `docs/reference/Surface-BSpline-Bezier.md:406` | `GeomAbs_BSplKnotDistribution` | false positive | enum |
| `docs/reference/Wire.md:1107` | `ShapeAnalysis_Wire::CheckClosed` | false positive | heading |
