---
nav_exclude: true
search_exclude: true
---

# OCCTSwift Wrapping Status

## Coverage

All user-facing OCCT classes are wrapped to method-level completeness: **4,256 operations**
across **1,166 OCCT headers the bridge includes** (of 6,774 shipped in the xcframework).

Both numbers are derived, not maintained by hand: the first is
`python3 Scripts/count-operations.py`'s `DERIVED` row, which the `count-operations` gate holds
README.md and `docs/API_REFERENCE.md` to. It does **not** yet hold this file, which is how the
figure here sat at 3,333 from 2026-04-13 until v2.0.0 while the real count grew past 4,200.

### What's Wrapped

Every OCCT toolkit used for modeling, analysis, and data exchange:

- **TKernel / TKMath**: Standard, math solvers (Matrix, SVD, BFGS, PSO, GlobOptMin, Newton), OSD utilities
- **TKG2d / TKG3d**: Full Geom2d and Geom class coverage (curves, surfaces, all methods)
- **TKGeomBase**: GeomLib, GeomConvert, GCPnts, Adaptor classes
- **TKGeomAlgo**: GeomFill, GeomPlate, NLPlate, FairCurve, LocalAnalysis, Approx, GccAna, Intf
- **TKBRep / TKTopAlgo**: BRepBuilderAPI, BRepLib, TopExp, BRep_Tool, TopoDS_Builder
- **TKPrim**: All primitive builders
- **TKBO / TKBool**: BOPAlgo (Splitter, CellsBuilder, BuilderFace/Solid), IntTools
- **TKFillet**: Fillet, chamfer (2D and 3D), FilletSurf
- **TKOffset**: Offset, thick solid, draft, simple offset
- **TKFeat**: Feature-based modeling (prism, revolve, pipe, split, glue)
- **TKShHealing**: ShapeFix, ShapeAnalysis, ShapeUpgrade, ShapeConstruct, ShapeCustom, ShapeBuild
- **TKMesh**: BRepMesh, Poly_Triangulation, Poly_Connect
- **TKHLR**: Hidden line removal (HLRBRep, HLRAlgo)
- **TKXSBase / TKDEIGES / TKDESTEP / TKDEOBJ / TKDEPLY / TKDESTL / TKDEGLTF**: All I/O formats
- **TKLCAF / TKCAF / TKCDF / TKXCAF**: Full OCAF framework (TDF, TDataStd, TDataXtd, TFunction, TNaming, XCAFDoc)
- **TKV3d**: Quantity_Color, Graphic3d materials

### What's Not Wrapped (by design)

| Category | ~Count | Reason |
|----------|--------|--------|
| STEP/IGES internals | ~1,700 | Internal protocol/model classes, not user-facing |
| Visualization/OpenGL | ~500 | OCCTSwift targets Metal via OCCTSwiftViewport, not OCCT's OpenGL viewer |
| NCollection containers | ~900 | Template-only C++ (no exported symbols); used internally in bridge |
| Abstract base classes | ~200 | Cannot be instantiated; only concrete subclasses are wrapped |

### Classes Not Wrapped (require abstract subclass implementations)

These require implementing C++ abstract classes, which the bridge architecture doesn't support:

- `ChFi3d_FilBuilder`, `ChFi3d_ChBuilder` — complex stateful builders with protected virtuals
- `Approx_FitAndDivide`, `Approx_FitAndDivide2d` — need `AppCont_Function` abstract impl
- `BRepBlend_AppSurface` — needs `Approx_SweepFunction` abstract impl

### Classes Not Wrapped Directly (reached only through another wrapper)

- `ShapeFix_Shell` — no bridge function constructs one. Shell repair is reached through
  `ShapeFix_Shape`, which drives `ShapeFix_Shell` internally; the header is `#include`d by the
  bridge's umbrella translation unit but never used. The cross-reference index in `OCCTBridge.h`
  claimed an `OCCTShapeFixShell` wrapper until #510 measured it and removed the entry. Wrapping it
  directly would mean exposing per-shell orientation/mode control (`FixFaceOrientation`,
  `SetNonManifoldFlag`) that `ShapeFix_Shape` currently chooses for the caller.
- `ShapeUpgrade_ConvertCurve3dToBezier`, `ShapeUpgrade_ConvertSurfaceToBezierBasis` — reached
  through `ShapeUpgrade_ShapeConvertToBezier`, the shape-level driver that owns both. The index
  entries carry a `(via …)` aside naming that driver.
- `BOPAlgo_RemoveFeatures` — reached through `BRepAlgoAPI_Defeaturing`, a forwarder to it. #536
  deleted the direct wrap that duplicated the forwarder.
- `LProp_AnalyticCurInf` — `OCCTLPropAnalyticCurInf` fills a `LProp_CurAndInf` from an inline scan
  of the analytic curve types rather than constructing the OCCT class.
- `BRepExtrema_ElementFilter`, `BRepExtrema_ProximityDistTool`, `BRepExtrema_ProximityValueTool`,
  `BRepExtrema_TriangleSet`, `BRepExtrema_OverlapTool` — internal building blocks of
  `BRepExtrema_ShapeProximity` (the wrapped, documented entry point for mesh-level overlap/proximity
  detection). `OverlapTool` and `TriangleSet` are the raw BVH primitive-set/traversal classes
  `ShapeProximity` builds internally from a triangulated shape; `ElementFilter` is an abstract
  customization hook for that traversal; `ProximityDistTool`/`ProximityValueTool` are
  `ShapeProximity`'s own internal distance-accumulation helpers. `OverlapTool`'s header is
  `#include`d in `OCCTBridge_Properties.mm` but never instantiated — same shape as
  `Geom2d_Direction` below. (#809)
- `BRepClass_Edge`, `BRepClass_FaceExplorer`, `BRepClass_FacePassiveClassifier`,
  `BRepClass_FClass2dOfFClassifier`, `BRepClass_Intersector`, `BRepClass3d_BndBoxTree`,
  `BRepClass3d_Intersector3d`, `BRepClass3d_SolidExplorer`, `BRepClass3d_SolidPassiveClassifier` —
  internal plumbing of the point-classification algorithms `BRepClass_FaceClassifier`/
  `BRepClass_FClassifier` (2D, point-in-face) and `BRepClass3d_SolidClassifier`/`BRepClass3d`
  (3D, point-in-solid) already wrap: edge/face wrappers the classifier walks, the ray/segment
  intersector it queries, the bounding-box tree it searches, and a "passive" (single-shot,
  non-incremental) strategy variant of each classifier that OCCT itself doesn't recommend over the
  wrapped one. `BRepClass3d_SolidExplorer` is constructed internally wherever
  `BRepClass3d_SolidClassifier` is (its own required constructor argument) but never named as a
  standalone capability. (#809)
- `GC_MakeRotation`, `GC_MakeRotation2d`, `GC_MakeMirror2d`, `GC_MakeScale2d`,
  `GC_MakeTranslation2d` — the rotation/mirror/scale/translation-transform capability each provides
  is already wrapped via the corresponding `gce_Make*`/`gce_Make*2d` class (`TransformFactory3D`/
  `TransformFactory2D`, `docs/reference/Document-Analysis-Builders.md`'s "gce Transform Factories"
  section) — a different OCCT package (`gce_*`, outside this lane's `GC_*`/`GCE2d_*` prefixes)
  building the same `gp_Trsf`/`gp_Trsf2d` result. None of the five is `#include`d or referenced
  anywhere in the bridge. (The 3D mirror/scale/translation siblings, `GC_MakeMirror`/`GC_MakeScale`/
  `GC_MakeTranslation`, ARE wrapped directly — `Shape.mirror`/`Shape.scale`/`Shape.translate` via
  `OCCTShapeMirrorAboutAxis`/`OCCTShapeMirrorAboutPoint`/`OCCTShapeScaleAboutPoint`/
  `OCCTShapeTranslateByPoints` — so only the 2D forms and 3D rotation follow this "covered by a
  sibling package" reasoning.) (#809)
- `GC_Root` — the common `Status()`/`IsDone()`/`Value()` base class every already-wrapped
  `GC_Make*` subclass inherits; never separately constructed.
- `BRepExtrema_SolutionElem` — OCCT's own internal per-solution representation for a
  `BRepExtrema_DistShapeShape` result. The data (nearest point + support type) is exposed through
  `DistShapeShape`'s own accessor methods (`PointOnShape1`/`SupportTypeShape1`/…) without the
  bridge ever constructing or naming this class; its header is `#include`d in
  `OCCTBridge_Topology.mm` but never used, same shape as `Geom2d_Direction` below. (#809)

### Classes Not Wrapped At All

- `Geom2d_Direction`, `Geom2d_VectorWithMagnitude` — the headers are `#include`d but never used.
  `OCCTDirection2D*` and `OCCTVector2D*` are `gp_Dir2d`/`gp_Vec2d` arithmetic on bare doubles, not
  wrappers for the `Geom2d_` handle types; the cross-reference index claimed otherwise until #565
  measured it. Wrapping them would mean exposing a reference-counted handle for what is currently
  a value-type calculation.
- `gp_TrsfNLerp`, `GC_MakeLine`, `GC_MakeArcOfEllipse2d`, `GC_MakeArcOfHyperbola2d`,
  `GC_MakeArcOfParabola2d` — the headers are `#include`d (`OCCTBridge_Spatial.mm`,
  `OCCTBridge.mm`, `OCCTBridge_Geom2d.mm`) but never constructed, the same shape as
  `Geom2d_Direction` above. `gp_TrsfNLerp`'s sibling rotation-only interpolators,
  `gp_QuaternionNLerp`/`gp_QuaternionSLerp`, ARE wrapped (`OCCTQuaternionNLerp`/
  `OCCTQuaternionSLerp`, `MathSolver.swift`) — full-transform (translation + scale + rotation)
  interpolation is not. `GC_MakeLine`'s segment-with-validation sibling `GC_MakeSegment` is wrapped
  and documented; the raw infinite-line constructor is not. The angle-bounded 2D elliptical/
  hyperbolic/parabolic arc CAPABILITY the other three provide is still available —
  `OCCTCurve2DCreateArcOfEllipse`/`CreateArcOfHyperbola`/`CreateArcOfParabola` build the trimmed
  arc directly from `Geom2d_Ellipse`/`Geom2d_Hyperbola`/`Geom2d_Parabola` + `Geom2d_TrimmedCurve`
  instead of going through these Make helpers (`docs/reference/Curve2D.md`'s `arcOfEllipse`/
  `arcOfHyperbola`/`arcOfParabola` entries name the correct backing classes as of #809) — only the
  specific Make-helper *class* goes unused, not the underlying arc construction. (#809)
- `gp_Vec2f`, `gp_Vec3f`, `BRepExtrema_MapOfIntegerPackedMapOfInteger`, `BRepExtrema_SeqOfSolution`,
  `BRepClass3d_MapOfInter` — deprecated since OCCT 8.0.0, each a `using`/`typedef` alias for a
  single-precision `NCollection_Vec{2,3}<float>` or an `NCollection_DataMap`/`NCollection_Sequence`
  instantiation, not a distinct constructible type. Same "NCollection containers" and (for the two
  `Vec` aliases) single-precision-vs-this-project's-double-precision rationale the summary table
  above already gives; none has any live use in the bridge. (#809)
- `gp_VectorWithNullMagnitude`, `BRepExtrema_UnCompatibleShape` — `Standard_DomainError` exception
  types (`DEFINE_STANDARD_EXCEPTION`), not constructible geometry. `gp_VectorWithNullMagnitude` is
  what `gp_Vec`/`gp_Dir`'s own constructor throws for a zero-length input, already absorbed by the
  bridge-wide `catch (...)` sweep the #345 entry in `CLAUDE.md`'s Known OCCT Bugs describes;
  `BRepExtrema_UnCompatibleShape` is `BRepExtrema`'s equivalent for a shape-type mismatch, caught
  the same way at every `BRepExtrema_*` call site. Neither is something to "wrap" as a value. (#809)
- The entire `GCE2d_*` package (`GCE2d_MakeArcOfCircle`, `GCE2d_MakeArcOfEllipse`,
  `GCE2d_MakeArcOfHyperbola`, `GCE2d_MakeArcOfParabola`, `GCE2d_MakeCircle`, `GCE2d_MakeEllipse`,
  `GCE2d_MakeHyperbola`, `GCE2d_MakeLine`, `GCE2d_MakeMirror`, `GCE2d_MakeParabola`,
  `GCE2d_MakeRotation`, `GCE2d_MakeScale`, `GCE2d_MakeSegment`, `GCE2d_MakeTranslation`, and
  `GCE2d_Root`) —
  every header in the package has been a `using GCE2d_X = GC_X2d` (or `= GC_Root`) deprecated
  compatibility alias since OCCT 8.0.0, not a distinct class; the refman generates no page for any
  of them (queried via the `context` MCP's `occt-refman@8.0.0-p1`, #809). v0.156.0 already migrated
  every internal use onto the canonical `GC_*2d` names, and #809's own sweep found and fixed the one
  site that regressed back to the deprecated spelling (`OCCTBridge_Modeling.mm`'s
  `OCCTShapeCreateFaceFromSurfaceUVPolygon`, `GCE2d_MakeSegment` → `GC_MakeSegment2d` — a behavior-
  identical rename, since the deprecated name was always literally a type alias for the one it now
  spells directly) and six `docs/reference/Curve2D.md`/`Curve2D-Analysis.md` entries that still
  named the deprecated `GCE2d_Make*` class as the backing implementation for a Swift method that,
  per direct inspection of the bridge, either used the canonical `GC_*2d` name already
  (`arcThrough`) or never used any `GC_`/`GCE2d_` Make helper at all, constructing the `Geom2d_*`
  primitive directly (`arcOfCircle`, `arcOfEllipse`, `arcOfHyperbola`, `arcOfParabola`, the
  `Point2D`-taking `segment` overload) — the exact `GCE2d_*`/`GC_*` prefix confusion #508 warned
  future audits to watch for. Nothing in the bridge or current docs (outside `docs/CHANGELOG.md`,
  a historical record) references any `GCE2d_*` symbol as of this entry. (#809)

### Constraint Solver Infrastructure (Complete)

All priority items from the original gap analysis are now wrapped:

- **P1 Math solvers**: math_FunctionSetRoot, math_BissecNewton, math_BFGS, math_Powell, math_Matrix, math_SVD, math_Householder, math_PSO, math_GlobOptMin
- **P2 Batch evaluation**: GeomEval grid evaluators, EvalD0/D1/D2/D3 for curves and surfaces
- **P3 Adaptor classes**: Geom2dAdaptor_Curve, BRepAdaptor_Curve, BRepAdaptor_Surface exposed
- **P4 Geometry analysis**: GeomLProp, BRepLProp, GCPnts_AbscissaPoint, ShapeAnalysis
- **P5 Topology exploration**: TopExp_Explorer, BRep_Tool, TopTools maps
