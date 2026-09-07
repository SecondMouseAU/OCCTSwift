# #1399, the `booleans` reading family

31 classes, read by hand against the bridge, the pinned 8.0.1 headers, OCCT's own sources under
`Libraries/occt-src`, and a probe (`probe_booleans.mm`, transcript in `probe-transcript.txt`).

```bash
python3 Scripts/repro/1399-refman-coverage-unlaned/derive_lane.py --family booleans
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1399-refman-coverage-unlaned/probe_booleans.mm -o /tmp/occt_1399_booleans
/tmp/occt_1399_booleans           # the transcript
/tmp/occt_1399_booleans --points  # the one call that faults, expected to die
```

## Result

| verdict | count |
|---|---|
| `ok` | 19 |
| `deliberate, recorded` | 6 |
| `under` | 1 |
| `over` | 5 |

Six findings across those six rows, five fixed here and four filed
([#1631](https://github.com/SecondMouseAU/OCCTSwift/issues/1631),
[#1632](https://github.com/SecondMouseAU/OCCTSwift/issues/1632),
[#1633](https://github.com/SecondMouseAU/OCCTSwift/issues/1633),
[#1635](https://github.com/SecondMouseAU/OCCTSwift/issues/1635)). Two of the four filed issues are
**not documentation defects at all**: `Shape.edgeFaceIntersection(with:)` finds nothing on any
input, and `ExtremaElSS.planeToSphere`/`sphereToSphere` cannot return a result on any input. Both
were found by asking what the docs claimed and then measuring the claim.

## The table

`uses` is `derive_lane.py`'s count, which is inflated by the shared include prologue every split
`.mm` file carries; the "live sites" column is the call sites that are not `#include` lines.

| class | verdict | live sites | evidence |
|---|---|---|---|
| `IntTools_Range` | `ok` | `fillCommonPart` (`Range1()`), `OCCTIntToolsBeanFaceIntersect` (`bfi.Result()`) | Reaches `CommonPart.param1Range` and `BeanFaceIntersection.ranges`; both documented in `Shape-Builders-2.md` and both true. |
| `IntTools_CommonPrt` | **`over`** | `fillCommonPart` | `param2Range` was documented as the range "on the second edge" for `edgeFaceIntersection`, which has no second edge and always reports `(0, 0)`. See F1. |
| `TopAbs_State` | `ok` | `mapTopAbsState` (5 Topology files), `OCCTIntToolsFClass2dPerform`, `occtShellIsInsideSolid` | Three Swift enums mirror it (`PointClassification`, `Shape.PointState`, `TopologicalState`), all with OCCT's own ordinals `IN=0, OUT=1, ON=2, UNKNOWN=3`, all documented, including the deliberate non-typealias in `Shape+Topology.swift`. `OCCTIntToolsFClass2dPerform` uses a different bridge-side ordering and `classifyPoint2d` remaps it case by case, which its own comment states. |
| `BOPAlgo_GlueEnum` | `ok` | `toGlueEnum` | `Shape.md:737` and `Document-Mesh-Fixing.md:3041` document both Swift spellings (`BooleanGlue`, `GlueMode`), their divergent raw values, and which bridge function each reaches. `toGlueEnum` itself is on no Swift call path, which `Document-Mesh-Fixing.md:3067` already says. |
| `Extrema_POnSurf` | **`over`** | `OCCTExtremaElSS*`, `OCCTExtremaExtPSPoint`, `OCCTExtremaExtSSPoint`, `OCCTExtremaExtCSPoint`, `OCCTExtremaElCSLin*` | `ExtremaResult.point1/point2` are documented as points on the two elements; on `ExtremaElSS.planeToPlane`'s parallel branch OCCT computes no `Extrema_POnSurf` at all and the bridge writes zeros. See F2. |
| `ExtremaPC_Curve` | **`over`** | `occtExtremaPCCurveImpl`, `OCCTExtremaPCMinDistance` | `Curve3D-Analysis.md` attributed all three entry points to `Extrema_ExtPC` (six sites, one of them "with bounded `GeomAdaptor_Curve`"), a class the bridge never constructs, and said nothing about the interior-only contract. See F3. |
| `IntTools_Context` | `deliberate, recorded` | `OCCTBOPToolsPointInFace` | Constructed once, only to satisfy `BOPTools_AlgoTools3D::PointInFace`'s required `Handle(IntTools_Context)` parameter. It is that algorithm's own adaptor/projector cache; no field of it reaches Swift, and a caller can neither supply nor observe one. |
| `IntTools_SequenceOfCommonPrts` | `deliberate, recorded` | `OCCTIntToolsEdgeEdge`, `OCCTIntToolsEdgeFace` | An `NCollection_Sequence` typedef read for `Length()` and element access. Documenting a container separately from its element would duplicate `IntTools_CommonPrt`'s row. |
| `Intf_Polygon2d` | `ok` | `OCCTSimplePolygon2d` (its concrete subclass), used by `OCCTIntfInterferencePolygon2d` / `OCCTIntfSelfInterferencePolygon2d` | The subclass reports `NbSegments() == count - 1`, an **open polyline**, which is exactly what `Shape-Builders-2.md`'s "ordered arrays of 2D vertices defining each polyline" says. Its silent 100-point output cap was undocumented and is now stated (F6). |
| `IntTools_Curve` | `ok` | `OCCTIntToolsFaceFace` | `HasBounds()`/`Bounds()` reach `FaceFaceCurve.start/end`, documented as `nil` "if the curve is unbounded". `IntTools_Curve::HasBounds()` is "TRUE if 3d curve is BoundedCurve", so the doc matches. |
| `IntTools_PntOn2Faces` | `ok` | `OCCTIntToolsFaceFace` | `P1()/P2()` reach `FaceFacePoint.pointOnFace1/pointOnFace2`, documented per field and true. |
| `IntTools_SequenceOfCurves` | `deliberate, recorded` | `OCCTIntToolsFaceFace` | Container, as `IntTools_SequenceOfCommonPrts`. |
| `IntTools_SequenceOfPntOn2Faces` | `deliberate, recorded` | `OCCTIntToolsFaceFace` | Container, as above. |
| `Extrema_POnCurv` | `ok` | `OCCTExtremaExtCCPoint`, `OCCTExtremaLocateExtCC`, `OCCTExtremaExtCSPoint`, `OCCTExtremaElC*`, `OCCTExtremaElCSLin*` | `Value()` reaches `ExtremaResult.point1/2` and `Parameter()` reaches `LocalExtremaResult.param1/param2` and `extremaCCPoint`'s pair, all documented in `Curve3D-Analysis.md` and `Document-BSpline-Extrema.md`. The `ExtremaElC` family reads `Value()` only, which is a wrapping choice rather than a doc gap. |
| `BOPAlgo_CheckResult` | `ok` | `OCCTShapeSelfIntersectsBounded`, `OCCTShapeSelfIntersectsDetailed` | `GetCheckStatus()` is what separates a genuine `BOPAlgo_SelfIntersect` from `BOPAlgo_BadType`/`OperationAborted`/`CheckUnknown`, and `Shape-Features.md:533` documents that distinction at length, with the measurement behind it. |
| `Extrema_POnCurv2d` | `ok` | `OCCTExtremaExtCC2d`, `OCCTExtremaLocateExtCC2d`, `OCCTExtremaExtElC2d*`, `OCCTExtremaExtPElC2d*` | The 2D counterpart of `Extrema_POnCurv`, documented through `Curve2DExtremaResult`'s per-field entries in `Curve2D-Analysis.md`. |
| `FilletSurf_StatusDone` | `ok` | `OCCTFilletSurfBuild` | `FilletSurfaceResult.status` reported `0=ok, 1=notOk, 2=partial`, which matches `FilletSurf_IsOk/IsNotOk/IsPartial`. The class was unnamed on the page; naming it is what makes F4's disambiguation readable, so it is fixed alongside, but the meaning was never wrong. |
| `FilletSurf_StatusType` | **`over`** | `OCCTFilletSurfBuild` (via `Start/EndSectionStatus()`), and `OCCTBridge_Modeling.h`'s field comment | `startStatus`/`endStatus` were documented on `FilletSurf_StatusDone`'s scale, and the bridge header's comment had the two `StatusType` names transposed and mis-spelled ("OnFace" for OCCT's "OnEdge"). See F4. |
| `IntRes2d_IntersectionPoint` | `ok` | `OCCTCurve2DIntersect`, `OCCTCurve2DSelfIntersect`, `OCCTBisectorInterPointPoint` | `Value()`, `ParamOnFirst()`, `ParamOnSecond()` reach `Curve2DIntersection` and `BisectorIntersection`, both documented per field, the latter naming the class explicitly (`Shape-Recognition.md:222, 230`). |
| `IntAna_Quadric` | **`over`** | `OCCTIntAnaLineSphere`, the six `OCCTIntAnaConeSphere*` / `OCCTIntAnaCylinderSphere*` entry points | The `coneSphere` doc entry attributed the computation to `IntAna_QuadQuadGeo`; the bridge builds an `IntAna_Quadric` and runs `IntAna_IntQuadQuad`. See F5. |
| `IntAna2d_IntPoint` | `ok` | `OCCTIntAna2dLinLin`, `LinCirc`, `CircCirc`, `OCCTConic2dLineCircleIntersect` | `Curve2D-Analysis.md` documents `Intersection2DPoint` and each `IntAna2d.*` entry point, including the zero-radius refusal (#553). Worth noting because it is a near miss: `ParamOnSecond()` throws `Standard_DomainError` when the second element is implicit, and the one bridge function that passes an `IntAna2d_Conic` (`OCCTConic2dLineCircleIntersect`) reads `Value()` only. Checked, not assumed. |
| `IntRes2d_Domain` | `ok` | `OCCTBisectorInterPointPoint` | `Shape-Recognition.md`'s `bisectorIntersections` entry documents the domain question in full (#1050: the search runs over each bisector's own `[0, Precision::Infinite()]` range, and why an unbounded domain is not the way to spell that). |
| `Geom2dInt_GInter` | `ok` | `OCCTCurve2DIntersect`, `OCCTCurve2DSelfIntersect` | Reached only through `Geom2dAPI_InterCurveCurve::Intersector()`, because the API class's own `Point(i)` returns a bare `gp_Pnt2d` with no parameters. The parameters it exists to reach are documented as `Curve2DIntersection.parameter1/parameter2`. |
| `Contap_IType` | `ok` | `OCCTContapContourLineType` | `ContourLineType`'s four cases match `Contap_Lin/Circle/Walking/Restriction` ordinal for ordinal, and `Shape-Builders-1.md:1790` documents what each means. |
| `Contap_Line` | **`under`** | `OCCTContapContourLinePoint`, `OCCTContapContourLinePointCount` | `NbPnts()`/`Point()` throw `Standard_DomainError` unless the line is `Contap_Walking`, so `pointCount`/`point`/`points` answer nothing for an analytic silhouette, which is the common case. Nothing said so. See F7. |
| `HatchGen_Domain` | `deliberate, recorded` | `OCCTCurve2DHatch` | Never leaves the bridge: the loop reads `HasFirstPoint()`/`HasSecondPoint()` and emits the two clipped endpoints, skipping infinite and semi-infinite domains. That gate is exactly `Curve2DGcc.hatch`'s documented contract, "each `Curve2DHatchSegment` is a line segment clipped to lie inside the boundary region". |
| `BOPDS_DS` | `ok` | `OCCTShapeSelfIntersects`, and named in `OCCTShapeSelfIntersectsBounded`'s comment | `Shape-Healing.md:470` and `Shape-Features.md:533` both name `BOPDS_DS::Interferences()` and describe what reading it means, including the `IsNewShape` filter and the `Clear()`-on-entry hazard. |
| `IntAna_ResultType` | `ok` | `OCCTIntAnaPlaneSphere` | `IntAna.ResultType`'s ten cases match the header ordinal for ordinal, and `Document-Math-Bounds.md:2336` plus `IntAna.swift:117` document the one case that surprises (`.circle`, not `.point`, for an ordinary plane-sphere secant, #1495). |
| `BOPAlgo_Operation` | `ok` | `OCCTShapeBooleanCheckPair`, `OCCTBOPAlgoAnalyzeArguments` | Both call paths are documented with OCCT's real ordinals (`Document-Transforms.md:1557`, `Shape-Builders-1.md:826`), including that the bridge passes the value through an unconditional `static_cast` (#1540). |
| `BOPDS_Pair` | `deliberate, recorded` | `OCCTShapeSelfIntersects` | The key type of `BOPDS_DS::Interferences()`, read only for `Indices()` so the `IsNewShape` filter can run. No index it carries reaches Swift; the filter it enables is documented at `Shape-Healing.md:470`. |
| `IntRes2d_IntersectionSegment` | `ok` | `OCCTBisectorInterPointPoint` | `Shape-Recognition.md`'s cause 4 ("they coincide, overlapping along their whole length. OCCT reports this as an intersection segment; the function now returns the segment's endpoints") documents exactly what `HasFirstPoint()`/`FirstPoint()`/`LastPoint()` are read for (#1070). |

## The findings

### F1. `CommonPart.param2Range` is a constant zero from `edgeFaceIntersection`. Fixed here.

`IntTools_CommonPrt`, `docs/reference/Shape-Builders-2.md`, `Sources/OCCTSwift/Shape+Analysis.swift`.

The struct is shared by `edgeEdgeIntersection(with:)` and `edgeFaceIntersection(with:)`, and its
table row read "Parameter range `(first, last)` on the second edge". A face is not an edge, and
`IntTools_EdgeFace.cxx` reflects that: it never calls `AppendRange2` or `SetVertexParameter2`, so
`Ranges2()` comes back empty and `VertexParameter2()` comes back as the `0.0` set by
`IntTools_CommonPrt`'s own constructor (`IntTools_CommonPrt.cxx:33`). `fillCommonPart` reads both
and passes them on, so `param2Range` is `(0, 0)` on that path whatever the geometry.

Measured on a common part `IntTools_EdgeFace` does find:

```
face 4, SetRange(0, 12)          Range=(0, 12)  IsDone=1  CommonParts=1
    part 1  Type=VERTEX  Range1=(1, 1)  Ranges2().Length()=0  VertexParameter2()=0
```

Fixed by saying so in the field table and in the `///` comment.

**Adjacent finding, filed as [#1631](https://github.com/SecondMouseAU/OCCTSwift/issues/1631).**
Getting that measurement took a `SetRange` call the bridge does not make.
`OCCTIntToolsEdgeFace` never calls `IntTools_EdgeFace::SetRange`, `IntTools_Range`'s default is
`(0, 0)`, and `Perform()` feeds `myRange` straight to
`IntTools_BeanFaceIntersector::SetBeanParameters`, so **`Shape.edgeFaceIntersection(with:)` returns
an empty array for every input**. All six faces of the cube report `CommonParts=0` without the
call and the two the edge really crosses report `1` with it. `IsDone()` is `true` either way, so
`nil` is not the signal. `IntTools_EdgeEdge` self-heals the same default in `Prepare()`
(`IntTools_EdgeEdge.cxx:97`), which is why only this one entry point is affected. The existing
test asserts `parts != nil` and nothing about the count, so an always-empty array passes it. That
needs a bridge change plus a real fixture, so it is filed rather than done here; the reference page
and the `///` comment now carry the warning.

### F2. `ExtremaElSS` answers one of its three pairs, and that one with zeroed points. Fixed here (docs), filed as [#1632](https://github.com/SecondMouseAU/OCCTSwift/issues/1632).

`Extrema_POnSurf`, `docs/reference/Document-BSpline-Extrema.md`,
`Sources/OCCTSwift/ExtremaTypes.swift`.

```
plane/plane, parallel      IsDone=1 IsParallel=1 NbExt=1 sqDist=25
plane/plane, crossing      IsDone=1 IsParallel=0 NbExt=0
plane/sphere               ctor THREW 23Standard_NotImplemented
sphere/sphere              ctor THREW 23Standard_NotImplemented
```

`Extrema_ExtElSS::Perform(gp_Pln, gp_Sphere)` and `Perform(gp_Sphere, gp_Sphere)` are
`throw Standard_NotImplemented();` in OCCT itself, so `ExtremaElSS.planeToSphere` and
`sphereToSphere` are wrappers around kernel entry points that do not exist: the throw lands in the
bridge's `catch (...)`, which returns `-1`, which Swift maps to `[]`. The page called all three
"closed-form extrema" with no caveat.

The plane/plane `Perform` fills `mySqDist` and leaves `myPOnS1`/`myPOnS2` as **null handles**, so
`Points(1, ...)` dereferences a null `NCollection_HArray1`. That is an OS fault rather than a
catchable exception (`probe_booleans.mm --points` takes the process down), which is why
`OCCTExtremaElSSPlanePlane` special-cases `IsParallel()` and writes zeros into the point fields.
The `ExtremaResult.point1/point2` doc said "closest/farthest point on the first/second geometric
element" with no exception, so the one row this family can return carries two values that read as
measurements and are not.

Fixed by documenting all four rows on the reference page and in the `///` comments. Removing or
reimplementing the two dead methods, and deciding what `planeToPlane`'s parallel points should be,
are behaviour changes and are filed.

### F3. `ExtremaPC` was attributed to `Extrema_ExtPC` in six places, and reports interior extrema only. Fixed here (docs), filed as [#1633](https://github.com/SecondMouseAU/OCCTSwift/issues/1633).

`ExtremaPC_Curve`, `docs/reference/Curve3D-Analysis.md`, `Sources/OCCTSwift/Curve3D.swift`.

The section heading knew the family name (`## ExtremaPC. Point-Curve Distance`) and every claim
under it named `Extrema_ExtPC`, including "`Extrema_ExtPC` with bounded `GeomAdaptor_Curve`". The
bridge constructs `ExtremaPC_Curve` from the `Geom_Curve` handle directly and builds no adaptor.
`census-doc-occt-attribution.py` had been reporting three of these six and nobody had read them;
`derive_lane.py` put `ExtremaPC_Curve` in this family precisely because no parsed claim named it.

The second half is behaviour. `ExtremaPC_Curve::Perform` is the interior solve;
`PerformWithEndpoints` is the one that includes endpoints, and nothing calls it:

```
Perform()               IsDone=1 NbExt=0
PerformWithEndpoints()  IsDone=1 NbExt=2 MinSquareDistance=100 (min distance 10)
true minimum distance from (20,0,0) to the segment [0,10] on +X is 10
```

So `Curve3D.minimumDistance(from:)` returns `nil` where the true answer is 10. Its documented
contract, "Returns `nil` when the algorithm fails to find any extremum", is true as written and
reads as "something went wrong". This is the same distinction #580 settled for
`Shape.pointEdgeExtrema`; the `Curve3D` family was not part of that pass.

Fixed by correcting all six attributions and stating the interior-only contract; the switch to
`PerformWithEndpoints` is filed.

### F4. `startStatus`/`endStatus` were documented on the other enum's scale. Fixed here.

`FilletSurf_StatusType`, `docs/reference/Shape-Builders-2.md`,
`Sources/OCCTBridge/include/OCCTBridge_Modeling.h`, `Sources/OCCTSwift/Shape+Modeling.swift`.

`FilletSurfaceInfo.startStatus`/`endStatus` carry `FilletSurf_Builder::StartSectionStatus()` /
`EndSectionStatus()`, whose enum is `FilletSurf_StatusType`. The doc table said
"`FilletSurf_Builder` status code at the fillet's start extremity (0 = ok, 1 = not ok, 2 = partial)",
which is `FilletSurf_StatusDone`, the enum on the sibling `FilletSurfaceResult.status`. The two
share the ordinals `0...2` and mean unrelated things, so reading one as the other is a silent
misread rather than an error:

```
FilletSurf_StatusDone: IsOk=0 IsNotOk=1 IsPartial=2
FilletSurf_StatusType: TwoExtremityOnEdge=0 OneExtremityOnEdge=1 NoExtremityOnEdge=2
```

The bridge header's own field comment had the same defect twice over:
`// FilletSurf_StatusType: 0=OneExtremityOnFace, 1=TwoExtremityOnFace, etc.` transposes the first
two names and writes "OnFace" for OCCT's "OnEdge".

Fixed in all three places. `firstParameter`/`lastParameter` were fixed in the same table: they come
from `FirstParameter()`/`LastParameter()`, which take no surface index, so the same pair is
repeated into every element rather than measured per surface, and the table did not list them at
all.

### F5. `coneSphere` was attributed to the wrong `IntAna` solver. Fixed here.

`IntAna_Quadric`, `docs/reference/Document-Geometry-Constructors.md`.

`QuadricIntersection.coneSphere` was attributed to `IntAna_QuadQuadGeo`. `OCCTIntAnaConeSphere`
builds an `IntAna_Quadric` from the sphere and runs `IntAna_IntQuadQuad`
(`OCCTBridge_Spatial_Intersection.mm:859`), a different class returning different objects: the
three `coneSphere*` entries immediately below already name `IntAna_Curve`, which is what
`IntAna_IntQuadQuad` hands back and what `IntAna_QuadQuadGeo` never returns. This was in
`census-doc-occt-attribution.py`'s output and unread.

### F6. The polygon-interference 100-point cap was silent. Fixed here.

`Intf_Polygon2d`, `docs/reference/Shape-Builders-2.md`, `Sources/OCCTSwift/Shape+Analysis.swift`.

`Shape.polygonInterference` and `polygonSelfInterference` size a fixed 100-element buffer and pass
its length as the maximum, so a polyline pair with more than 100 crossings loses the rest with no
signal. The sibling `Curve2D.intersections(with:)` documents its own 128 cap in the same style, so
this is an omission rather than a convention.

### F7. `ContapContourResult`'s point accessors are Walking-only. Fixed here (docs), filed as [#1635](https://github.com/SecondMouseAU/OCCTSwift/issues/1635).

`Contap_Line`, `docs/reference/Shape-Builders-1.md`,
`Sources/OCCTSwift/ContapContourResult.swift`.

`Contap_Line::NbPnts()` and `Point(Index)` both open with
`if (typL != Contap_Walking) { throw Standard_DomainError(); }` (`Contap_Line.lxx:53, 61`). The
bridge's `catch (...)` turns that into `0` and into a silent no-write, so `pointCount` is `0`,
`points` is `[]`, and `point(line:index:)` hands back `SIMD3(0, 0, 0)`, a zero that reads as a
measurement. The page said only "All indices are 1-based".

That is not an edge case. A cylinder's lateral face viewed along `(1, 0, 0)`, the textbook
silhouette, gives two `Contap_Lin` lines and no reachable point on either:

```
cylinder face, view direction (1,0,0): NbLines=2
  line 1  TypeContour=Contap_Lin (0, .line)  NbVertex=2  NbPnts() THREW 20Standard_DomainError
  line 2  TypeContour=Contap_Lin (0, .line)  NbVertex=2  NbPnts() THREW 20Standard_DomainError
```

`docs/reference/Shape-Builders-1.md:927` already states the same geometric fact for the other
silhouette API on that page. The analytic geometry OCCT does hold for those lines
(`Contap_Line::Line()`, `Circle()`, `NbVertex()`/`Vertex()`, `Arc()`) is not wrapped, which needs
new bridge functions, so that half is filed.

## What the attribution census had been reporting unread

The brief said the parsed-claim channels were "already covered". They are parsed and were not
adjudicated: `census-doc-occt-attribution.py` reported **431** findings on this branch's base
commit (`2b714c83`), and four of them were F3's, one was F5's.

This branch takes the census from **431 to 421 with no new findings added**, measured by running
the shipped census against a temporary worktree at `2b714c83` and diffing the finding lines:

| removed | why it was real |
|---|---|
| `Curve3D-Analysis.md` x3, `Extrema_ExtPC` | F3 |
| `Curve3D-Analysis.md`, `GeomAdaptor_Curve` | F3, the "bounded adaptor" half |
| `Document-Geometry-Constructors.md`, `IntAna_QuadQuadGeo` | F5 |
| `Document-Mesh-Fixing.md`, `Extrema_ExtPC` + `GeomAPI_ExtremaCurveCurve` (`projectPointAll`) | `OCCTExtremaPointCurve` runs `GeomAPI_ProjectPointOnCurve`. `GeomAPI_ExtremaCurveCurve` is curve-to-curve and was never on this path. |
| `Document-Mesh-Fixing.md`, `Extrema_ExtPS` (`locateNearestPoint`) | `OCCTExtremaLocateOnSurface` runs `Extrema_GenLocateExtPS`, the seeded local solver, not the global `Extrema_ExtPS`. |
| `Shape-Features.md` x2, `BRepAlgoAPI_BuilderAlgo` (`split`) | `OCCTShapeSplit` and `OCCTShapeSplitByPlane` both run `BRepAlgoAPI_Splitter`. It derives from `BRepAlgoAPI_BuilderAlgo`, so the census's base-class walk accepted it, but the base class is General Fuse, which treats every argument symmetrically and returns a compound of all split parts, a different operation with a different result. This is #367's trap in a doc page. |

**Three candidates were adjudicated and rejected**, none of them a defect:

- `OCCTBridge_Curve3D.h:2238`, `Extrema_LocateExtPC` / `Extrema_GenLocateExtPS`. The comment names
  `Extrema_LocateExtPC` **to disclaim it**: "Extrema_LocateExtPC, which the name echoes, does take
  a TolU, but #615 deliberately moved this off that path". The census cannot read a negation.
- `Mesh.md:352/381/404` and `API_REFERENCE.md:536-538`, `BRepAlgoAPI_Fuse`/`Cut`/`Common`.
  `OCCTMeshUnion` and friends forward to `occtMeshBoolean(..., OCCTShapeUnion)`, and `OCCTShapeUnion`
  does run `BRepAlgoAPI_Fuse`. The census does not follow a helper across files, the same single
  rejection #811 recorded.
- `Shape-Features.md:876/889/902` (`+`/`-`/`&` operators), `FeatureReconstructor.md:258/483`
  (`subject=init`, 100 candidate vias) and `SheetMetal.md:374` (`subject=build`). All are the
  census's misresolved-subject shape: it takes the backticked token nearest the claim and matches
  it against bridge function names, and picks the wrong function.

**Three census findings this pass introduced and then removed by rewording**, recorded because the
mechanism will recur. Writing `FilletSurf_Builder::FirstParameter` and `FilletSurf_StatusDone` into
a markdown **table cell** made the census resolve the subject from the cell's field name
(`firstParameter`, `status`) rather than from the enclosing section, and match it to
`OCCTCurve3DFirstParameter` and `OCCTFaceFixerStatus`. Moving those class names from the cells into
the prose paragraph below the table cleared all three and reads better. The same happened for
`IntAna_Curve` and `Extrema_ExtPC` when the corrected text named the wrong class in order to say it
was wrong; that "used to say X" note belongs in the CHANGELOG, not on the reference page, and was
moved there.

## For the integrator

Marked clearly rather than written into files this pass must not touch.

**`docs/occtswift-wrapping-gaps.md` candidates**, the six `deliberate, recorded` reasons in one
bullet, since they share a shape: `IntTools_Context`, `IntTools_SequenceOfCommonPrts`,
`IntTools_SequenceOfCurves`, `IntTools_SequenceOfPntOn2Faces`, `HatchGen_Domain` and `BOPDS_Pair`
are undocumented deliberately. Each is either an OCCT-internal cache the caller can neither supply
nor observe (`IntTools_Context`), an `NCollection` container whose element type carries the
documented payload (the three sequences, `BOPDS_Pair`), or a result object read and discarded
inside one bridge function while its payload surfaces as ordinary values (`HatchGen_Domain`).

**`docs/CHANGELOG.md` entry**: in the PR body, per `changelog-on-merge`.

**`docs/SEMVER.md`**: PATCH. Documentation, comments and one probe; no public API changed.

**`CLAUDE.md`, line 24, says the patch count is "twenty-three on disk"**. `ls Scripts/patches/*.patch | wc -l`
is 22 and `okf/references/carried-occt-patches.md:74` says twenty-two. Out of this family's scope
and in a file this pass must not touch, so it is reported rather than fixed.

**The family shrank from 31 to 28 while this pass ran, and that is the intended outcome.** Naming
the real class in a claim the census parses moves that class into the `machine-covered` bucket,
where it is re-checked on every run rather than needing a hand read. The three that moved are
`ExtremaPC_Curve` (F3), `FilletSurf_StatusType` (F4) and `IntAna_Quadric` (F5), which are exactly
the three `over` findings whose fix added a class name to a `- **OCCT:**` bullet or a field table.
The other two `over` rows (`IntTools_CommonPrt`, `Extrema_POnSurf`) stay in the family, because
their fix was a behaviour caveat rather than an attribution. So `--family booleans` prints 28 after
this merge where the brief said 31; `--self-test` stays 12/12 either way, and it is the count in
`no-family-is-empty-or-swallows-everything`'s detail line that moves.

**Overlap with the fifth agent.** The census work above reaches five classes outside this family's
31 (`Extrema_ExtPC`, `Extrema_ExtPS`, `GeomAPI_ExtremaCurveCurve`, `IntAna_QuadQuadGeo`,
`BRepAlgoAPI_BuilderAlgo`). They were worked here because the coordinator named the boolean and
extrema neighbourhood as this family's territory. Dedupe against the fifth agent's list before
merging.
