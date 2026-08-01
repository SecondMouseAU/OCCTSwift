---
nav_exclude: true
search_exclude: true
---

# OCCTSwift Wrapping Status

## Coverage

All user-facing OCCT classes are wrapped to method-level completeness: **3,333 operations** across **1,112 included headers**.

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

### Classes Not Wrapped At All

- `Geom2d_Direction`, `Geom2d_VectorWithMagnitude` — the headers are `#include`d but never used.
  `OCCTDirection2D*` and `OCCTVector2D*` are `gp_Dir2d`/`gp_Vec2d` arithmetic on bare doubles, not
  wrappers for the `Geom2d_` handle types; the cross-reference index claimed otherwise until #565
  measured it. Wrapping them would mean exposing a reference-counted handle for what is currently
  a value-type calculation.

### Constraint Solver Infrastructure (Complete)

All priority items from the original gap analysis are now wrapped:

- **P1 Math solvers**: math_FunctionSetRoot, math_BissecNewton, math_BFGS, math_Powell, math_Matrix, math_SVD, math_Householder, math_PSO, math_GlobOptMin
- **P2 Batch evaluation**: GeomEval grid evaluators, EvalD0/D1/D2/D3 for curves and surfaces
- **P3 Adaptor classes**: Geom2dAdaptor_Curve, BRepAdaptor_Curve, BRepAdaptor_Surface exposed
- **P4 Geometry analysis**: GeomLProp, BRepLProp, GCPnts_AbscissaPoint, ShapeAnalysis
- **P5 Topology exploration**: TopExp_Explorer, BRep_Tool, TopTools maps
