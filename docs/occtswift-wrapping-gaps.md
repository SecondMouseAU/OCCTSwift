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
README.md, `docs/API_REFERENCE.md` and, since #967, `docs/index.md` to. It still does **not** hold
this file, which is how the figure here sat at 3,333 from 2026-04-13 until v2.0.0 while the real
count grew past 4,200, and is why the figure above reads 4,256 against a derived 4,355 today.

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

- `ChFi3d_FilBuilder`, `ChFi3d_ChBuilder`, complex stateful builders with protected virtuals
- `Approx_FitAndDivide`, `Approx_FitAndDivide2d`, need `AppCont_Function` abstract impl
- `BRepBlend_AppSurface`: needs `Approx_SweepFunction` abstract impl

### Classes Not Wrapped Directly (reached only through another wrapper)

- `ShapeFix_Shell`: no bridge function constructs one. Shell repair is reached through
  `ShapeFix_Shape`, which drives `ShapeFix_Shell` internally; the header is `#include`d by the
  bridge's umbrella translation unit but never used. The cross-reference index in `OCCTBridge.h`
  claimed an `OCCTShapeFixShell` wrapper until #510 measured it and removed the entry. Wrapping it
  directly would mean exposing per-shell orientation/mode control (`FixFaceOrientation`,
  `SetNonManifoldFlag`) that `ShapeFix_Shape` currently chooses for the caller.
- `ShapeUpgrade_ConvertCurve3dToBezier`, `ShapeUpgrade_ConvertSurfaceToBezierBasis`, reached
  through `ShapeUpgrade_ShapeConvertToBezier`, the shape-level driver that owns both. The index
  entries carry a `(via …)` aside naming that driver.
- `BOPAlgo_RemoveFeatures`: reached through `BRepAlgoAPI_Defeaturing`, a forwarder to it. #536
  deleted the direct wrap that duplicated the forwarder.
- `LProp_AnalyticCurInf`: `OCCTLPropAnalyticCurInf` fills a `LProp_CurAndInf` from an inline scan
  of the analytic curve types rather than constructing the OCCT class.
- `BRepExtrema_ElementFilter`, `BRepExtrema_ProximityDistTool`, `BRepExtrema_ProximityValueTool`,
  `BRepExtrema_TriangleSet`, `BRepExtrema_OverlapTool`, internal building blocks of
  `BRepExtrema_ShapeProximity` (the wrapped, documented entry point for mesh-level overlap/proximity
  detection). `OverlapTool` and `TriangleSet` are the raw BVH primitive-set/traversal classes
  `ShapeProximity` builds internally from a triangulated shape; `ElementFilter` is an abstract
  customization hook for that traversal; `ProximityDistTool`/`ProximityValueTool` are
  `ShapeProximity`'s own internal distance-accumulation helpers. `OverlapTool`'s header is
  `#include`d in `OCCTBridge_Properties.mm` but never instantiated, same shape as
  `Geom2d_Direction` below. (#809)
- `BRepClass_Edge`, `BRepClass_FaceExplorer`, `BRepClass_FacePassiveClassifier`,
  `BRepClass_FClass2dOfFClassifier`, `BRepClass_Intersector`, `BRepClass3d_BndBoxTree`,
  `BRepClass3d_Intersector3d`, `BRepClass3d_SolidExplorer`, `BRepClass3d_SolidPassiveClassifier`,
  internal plumbing of the point-classification algorithms `BRepClass_FaceClassifier`/
  `BRepClass_FClassifier` (2D, point-in-face) and `BRepClass3d_SolidClassifier`/`BRepClass3d`
  (3D, point-in-solid) already wrap: edge/face wrappers the classifier walks, the ray/segment
  intersector it queries, the bounding-box tree it searches, and a "passive" (single-shot,
  non-incremental) strategy variant of each classifier that OCCT itself doesn't recommend over the
  wrapped one. `BRepClass3d_SolidExplorer` is constructed internally wherever
  `BRepClass3d_SolidClassifier` is (its own required constructor argument) but never named as a
  standalone capability. (#809)
- `GC_MakeRotation`, `GC_MakeRotation2d`, `GC_MakeMirror2d`, `GC_MakeScale2d`,
  `GC_MakeTranslation2d`: the rotation/mirror/scale/translation-transform capability each provides
  is already wrapped via the corresponding `gce_Make*`/`gce_Make*2d` class (`TransformFactory3D`/
  `TransformFactory2D`, `docs/reference/Document-Analysis-Builders.md`'s "gce Transform Factories"
  section), a different OCCT package (`gce_*`, outside this lane's `GC_*`/`GCE2d_*` prefixes)
  building the same `gp_Trsf`/`gp_Trsf2d` result. None of the five is `#include`d or referenced
  anywhere in the bridge. (The 3D mirror/scale/translation siblings, `GC_MakeMirror`/`GC_MakeScale`/
  `GC_MakeTranslation`, ARE wrapped directly, `Shape.mirror`/`Shape.scale`/`Shape.translate` via
  `OCCTShapeMirrorAboutAxis`/`OCCTShapeMirrorAboutPoint`/`OCCTShapeScaleAboutPoint`/
  `OCCTShapeTranslateByPoints`: so only the 2D forms and 3D rotation follow this "covered by a
  sibling package" reasoning.) (#809)
- `GC_Root`: the common `Status()`/`IsDone()`/`Value()` base class every already-wrapped
  `GC_Make*` subclass inherits; never separately constructed.
- `BRepExtrema_SolutionElem`: OCCT's own internal per-solution representation for a
  `BRepExtrema_DistShapeShape` result. The data (nearest point + support type) is exposed through
  `DistShapeShape`'s own accessor methods (`PointOnShape1`/`SupportTypeShape1`/…) without the
  bridge ever constructing or naming this class; its header is `#include`d in
  `OCCTBridge_Topology.mm` but never used, same shape as `Geom2d_Direction` below. (#809)
- `BRep_Curve3D`, `BRep_CurveOn2Surfaces`, `BRep_CurveOnClosedSurface`, `BRep_CurveOnSurface`,
  `BRep_PointOnCurve`, `BRep_PointOnCurveOnSurface`, `BRep_PointOnSurface`, `BRep_Polygon3D`,
  `BRep_PolygonOnClosedSurface`, `BRep_PolygonOnClosedTriangulation`, `BRep_PolygonOnSurface`,
  `BRep_PolygonOnTriangulation`, `BRep_TEdge`, `BRep_TFace`, `BRep_TVertex`, `TopoDS_TCompSolid`,
  `TopoDS_TCompound`, `TopoDS_TFace`, `TopoDS_TShell`, `TopoDS_TSolid`, `TopoDS_TWire`: the
  concrete B-Rep storage records behind a `TopoDS_Shape`. A `TopoDS_Shape` is a handle onto one of
  the `T*` records, and each record holds a list of `BRep_CurveRepresentation` /
  `BRep_PointRepresentation` entries. Everything a caller can do with them is already reached
  through `BRep_Tool` (read) and `BRep_Builder`/`TopoDS_Builder` (write), both wrapped;
  `TopoDS_TShape`'s own header settles the intent, "Users have no direct access to the classes
  derived from TShape". `BRep_TEdge` is named once in a bridge comment and constructed nowhere.
  (#808)
- `BRepAlgoAPI_Algo`, `BRepAlgoAPI_BooleanOperation`, `BRepBuilderAPI_Command`,
  `BRepBuilderAPI_ModifyShape`, `BRepPrimAPI_MakeOneAxis`, `BRepPrimAPI_MakeSweep`,
  `BRep_CurveRepresentation`, `BRep_GCurve`, `BRep_PointRepresentation`, `BRep_PointsOnSurface`,
  `TopoDS_TShape`, `TopoDS_TEdge`, `TopoDS_TVertex`: abstract bases, each with a pure virtual or a
  protected-only constructor in the pinned header, matching the "Abstract base classes" row in the
  summary table above. Every concrete subclass a caller would want is wrapped:
  `BRepAlgoAPI_Common`/`Cut`/`Fuse`/`Section` under `BooleanOperation`,
  `BRepBuilderAPI_Copy`/`Transform`/`GTransform`/`NurbsConvert` under `ModifyShape`,
  `BRepPrimAPI_MakeCone`/`MakeCylinder`/`MakeSphere`/`MakeTorus`/`MakeRevolution` under
  `MakeOneAxis`, and `BRepPrimAPI_MakePrism`/`MakeRevol` plus `BRepOffsetAPI_MakePipe`/
  `MakePipeShell` under `MakeSweep`. (#808)
- `BRepCheck` (the package class), `BRepBuilderAPI_BndBoxTreeSelector`,
  `BRepBuilderAPI_VertexInspector`, `TopTools_LocationSet`, `TopTools_LocationSetPtr`,
  `TopTools_ShapeSet`, `TopoDS_AlertAttribute`, `TopoDS_AlertWithShape`: internal plumbing of an
  already-wrapped entry point. `BRepCheck` itself is two statics that append a `BRepCheck_Status`
  to a result list, while every checker in the package (`BRepCheck_Analyzer`, `_Edge`, `_Face`,
  `_Wire`, `_Shell`, `_Solid`, `_Vertex`, `_Result`, `_Status`) is wrapped. `TopTools_ShapeSet` and
  its `TopTools_LocationSet` are the BREP file's shape and location tables, reached through
  `BRepTools::Write`/`Read`; both are cited by file and line in the docs and in the bridge as the
  source of the `IsSame` sub-shape enumeration (#541), and neither is ever constructed.
  `BRepBuilderAPI_VertexInspector`'s only consumer in the whole pinned header set is the deprecated
  `BRepBuilderAPI_CellFilter` typedef, and `BRepBuilderAPI_BndBoxTreeSelector` has none at all, so
  both are reachable only from OCCT's own `.cxx`. `TopoDS_AlertWithShape`/`TopoDS_AlertAttribute`
  carry a `TopoDS_Shape` on a `Message_Alert`; the wrapped `Message_Report` surface reads alert
  text, not attached shapes, so exposing them would mean adding a shape-valued attribute channel to
  that surface rather than wrapping a class. (#808)
- `BRepBuilderAPI_Collect`, `TopoDS_HShape`: the capability is wrapped through a different class.
  `BRepBuilderAPI_Collect` accumulates `Modified`/`Generated` history across successive
  `BRepBuilderAPI_MakeShape` runs, and its one consumer in the pinned headers is a private member
  of `BRepBuilderAPI_GTransform`; the same capability is wrapped as `BRepTools_History`
  (`History.merge`, `replaceGenerated`, `replaceModified`, `getModifiedShapes`,
  `getGeneratedShapes`). `TopoDS_HShape` is a `Standard_Transient` handle wrapper around a
  `TopoDS_Shape`, and OCCTSwift's own `Shape` is already a reference-counted wrapper over the same
  value, so a second handle type adds a lifetime to manage and no capability. (#808)

- `XCAFApp_Application`: **not used on purpose, and the pinned refman says the opposite.** This is
  the clearest divergence between what OCCT documents and what this project does, so it is recorded
  in full rather than as a line. `XCAFApp_Application.hxx`'s own comment on `GetApplication()` reads
  "This is the only valid method to get `XCAFApp_Application` object, and it should be called at
  least once before any actions with documents", and the class's constructor is protected, so that
  static really is the only route to one. Since v1.15.17 (#371) `OCCTDocument`'s constructor does
  `app = new TDocStd_Application()` instead, and `XCAFApp_Application` is constructed nowhere in
  `Sources/OCCTBridge`; the only mention left is one comment recording the change. The reason is
  measured rather than stylistic: `GetApplication()` hands every caller the same process-wide
  instance, and that sharing is what made the #341 / #344 / #349 / #353 race cluster reachable at
  all, four separate crashes in state the headers declare per-instance
  (`CDF_Directory::myDocuments`, `CDF_Application::myReaders`/`myWriters`,
  `CDM_Application::myMetaDataLookUpTable`) and which a private application per document makes
  exclusive to one document by construction. Upstream maintainer gkv311's review of
  [OCCT#1396](https://github.com/Open-Cascade-SAS/OCCT/issues/1396) reaches the same conclusion from
  the other side: `GetApplication()` "exists solely for compatibility reasons", and OCCT's own
  guidance since 7.1 is a private `TDocStd_Application` per caller. Nothing is lost by the swap:
  `XCAFApp_Application` adds only `ResourcesName()` and `InitDocument()` over its base, the bridge
  registers the XDE drivers and attaches `XCAFDoc_DocumentTool` itself, and a ground-truth C++ test
  confirmed the two routes behave identically for this surface before the change landed. Nothing
  became lock-free either: `ocafStoreMutex()` still serialises save/load/format registration,
  because a private instance per document is what first makes `Resource_Manager`'s and
  `Storage_Schema`'s process-wide state concurrent (#374). The four
  `docs/reference/Document-Persistence-IO.md` entries that still named `XCAFApp_Application` as the
  backing class were corrected in #810, and that page now carries a "Why not `XCAFApp_Application`"
  section with this reasoning. The upstream kernel PRs for #344/#349/#353 stand: they fix real bugs
  in the pattern OCCT's own header still recommends, and every other consumer following that
  recommendation is still exposed. (#371, #810)
- `TDF_Attribute`, `TDF_AttributeDelta`, `TDataStd_GenericEmpty`, `TDataStd_GenericExtString`,
  `CDF_Application`, `CDF_MetaDataDriver`, `CDF_MetaDataDriverFactory`, `CDM_Application`,
  `CDM_Document`, `XCAFPrs_Driver`: abstract bases, each with a pure virtual or a constructor
  declared only after `protected:` in the pinned header, matching the "Abstract base classes" row in
  the summary table above. Every concrete subclass a caller would want is wrapped:
  `TDocStd_Application` under `CDF_Application`/`CDM_Application`, `TDocStd_Document` under
  `CDM_Document`, the whole per-attribute `Document` API under `TDF_Attribute`, and
  `XCAFDoc_ShapeTool`/`ColorTool`/`LayerTool` and the rest of the XDE tool set under
  `TDataStd_GenericEmpty`. `TDataStd_GenericExtString` is the ancestor of `TDataStd_Name`,
  `TDataStd_Comment` and `TDataStd_AsciiString`, all three wrapped. `CDF_MetaDataDriver` is, per its
  own header, "the method that must be available for a specific DBMS", and OCCT selects its own
  `CDF_FWOSDriver` implementation without any caller naming either. `XCAFPrs_Driver` exists solely
  to return an `XCAFPrs_AISObject`, which is display and therefore Pass 4d's lane (#814). (#810)
- `TDocStd_ApplicationDelta`, `TDocStd_CompoundDelta`, `TDF_DefaultDeltaOnModification`,
  `TDF_DefaultDeltaOnRemoval`, `TDF_DeltaOnAddition`, `TDF_DeltaOnForget`,
  `TDF_DeltaOnModification`, `TDF_DeltaOnRemoval`, `TDF_DeltaOnResume`,
  `TDataStd_DeltaOnModificationOfByteArray`, `TDataStd_DeltaOnModificationOfExtStringArray`,
  `TDataStd_DeltaOnModificationOfIntArray`, `TDataStd_DeltaOnModificationOfIntPackedMap`,
  `TDataStd_DeltaOnModificationOfRealArray`, `TNaming_DeltaOnModification`,
  `TNaming_DeltaOnRemoval`: the undo/redo record hierarchy. OCAF produces one of these per changed
  attribute during a commit and files them under a `TDF_Delta`, which **is** wrapped:
  `OCCTDocumentCommitWithDelta` returns one and `TransactionDelta` reads its attribute count and
  label list. Nothing constructs an individual record, and a caller who wants per-record detail is
  asking for the delta's contents to be enumerated by kind, which is a new API rather than a wrap of
  these classes. (#810)
- `TDF_LabelNode`, `TDF_LabelNodePtr`, `TDF_HAllocator`, `TDocStd_XLinkPtr`,
  `TDataStd_PtrTreeNode`, `TNaming_PtrAttribute`, `TNaming_PtrNode`, `TNaming_PtrRefShape`,
  `CDM_DocumentPointer`, `TNaming_RefShape`, `TNaming_ShapesSet`, `TNaming_IteratorOnShapesSet`,
  `TNaming_UsedShapes`, `TDocStd_Owner`, `TDocStd_XLinkRoot`, `XCAFDoc_PartId`, `CDM_MetaData`:
  the framework's own storage records and the raw-pointer typedefs onto them. A `TDF_Label` is a
  handle onto a `TDF_LabelNode`, whose whole surface is friend-only; the six `*Ptr`/`*Pointer`
  entries are one-line `typedef X* Y;` aliases (`TNaming_PtrNode`'s target, `TNaming_Node`, ships no
  header at all). `TNaming_UsedShapes` and `TDocStd_XLinkRoot` are single per-document root-label
  attributes, both described as such by their own headers, written by the wrapped `TNaming_Builder`
  and `TDocStd_XLink`; `TDocStd_Owner` is a back reference to the document the bridge already holds.
  `CDM_MetaData` is the per-file metadata record whose race is #353 and patch `0015`. (#810)
- `TDocStd`, `TDF`, `TDataStd`, `TDataXtd`, `TNaming`, `XCAFDoc`, `XCAFPrs`: the seven package
  classes, each a bag of statics (GUID accessors, `Print`/`Dump` helpers) over attributes that are
  themselves separately wrapped. Same treatment `BRepCheck` gets above. (#810)
- `TDF_Data`, `TDF_Transaction`, `TDF_TagSource`, `TDF_CopyTool`, `TDF_RelocationTable`,
  `TDF_ClosureTool`, `TDF_ClosureMode`, `TDF_Tool`, `TDF_DerivedAttribute`, `TDocStd_Context`,
  `TDocStd_Modified`, `TDocStd_XLinkIterator`, `TNaming_Identifier`, `TNaming_Localizer`,
  `TNaming_Name`, `TNaming_NamingTool`, `TNaming_TranslateTool`, `XCAFDoc_AssemblyTool`,
  `XCAFPrs_DocumentIdIterator`, `CDF_Directory`, `CDF_DirectoryIterator`, `CDF_FWOSDriver`,
  `CDF_Store`, `CDF_StoreList`, `CDM_Reference`, `CDM_ReferenceIterator`: internal plumbing of an
  already-wrapped entry point. Six of these have their header `#include`d in
  `OCCTBridge_Document.mm` and the class never named in code, the same dead-include shape as
  `Geom2d_Direction` below: `TDF_Data`, `TDF_Transaction`, `TDF_TagSource`, `TDF_CopyTool`,
  `TDF_RelocationTable` and `TDocStd_Modified`. Three of those six are worth spelling out because
  the capability **is** reached, just not by naming the class. `TDF_Label::NewChild()`, which the
  bridge calls, is literally `TDF_TagSource::NewChild(*this)`. `TDF_Data`'s services (root label,
  transaction open/commit, delta generation) are all reached through `TDocStd_Document`.
  `TDF_CopyTool` is the engine behind `TDF_CopyLabel`, which is wrapped as
  `OCCTDocumentCopyLabel` and owns its own relocation table. Of the rest, `TDocStd_Modified` is the
  root-label attribute registering modified labels and is **not** what
  `OCCTDocumentIsLabelModified` reads (it reads `TDocStd_Document::GetModified()`, a different
  mechanism); the bridge header comment that says otherwise is #971. `TDocStd_XLinkIterator` is the
  one real enumeration gap in this group: `TDocStd_XLink` and `TDocStd_XLinkTool` are both wrapped,
  so a caller can read and write an external link on a label but must walk labels to find them
  rather than ask the document. `CDM_ReferenceIterator` marks the larger one: cross-document
  reference **resolution** is not exposed at all, only the `TDocStd_XLink` attribute that records a
  link. (#810)
- `TDataStd_HDataMapOfStringByte`, `TDataStd_HDataMapOfStringHArray1OfInteger`,
  `TDataStd_HDataMapOfStringHArray1OfReal`, `TDataStd_HDataMapOfStringInteger`,
  `TDataStd_HDataMapOfStringReal`, `TDataStd_HDataMapOfStringString`: handle wrappers for one
  `NCollection_DataMap` instantiation each, per their own headers. They are the storage inside
  `TDataStd_NamedData`, which is wrapped, and a caller reaches every entry through that attribute's
  own typed accessors rather than through the map. (#810)
- `TDocStd_PathParser`: **deliberately removed, not merely unwrapped.** #499 unified the bridge's
  four path parsers onto `OSD_Path`, and `OCCTBridge_IO.h` records the reason in place:
  `TDocStd_PathParser::Parse()` is wrong outright for extension-less paths. The header is
  `#include`d nowhere and only the two comments explaining the removal name it. (#499, #810)
- `TDocStd_MultiTransactionManager`: synchronises one transaction across several documents. The
  bridge drives transactions per document through `TDocStd_Document`, which covers the
  single-document behaviour; the one thing the manager has that the document API does not is
  `CommitCommand(name)`, the only named-transaction API in the framework, and that gap is what makes
  `Document.openNamedTransaction(_:)` drop its argument (#970). (#810)
- `XCAFDoc_View`, `XCAFDoc_ViewTool`: the per-view attribute and the document-level view table.
  `XCAFView_Object`, the value type the attribute stores, **is** wrapped (`ViewObject`), and the
  bridge reads and writes views through it by label; neither the attribute wrapper nor the tool is
  constructed. The capability a caller wants (enumerate a document's views) is therefore reachable
  only by walking labels, which is the same shape as the `TDocStd_XLinkIterator` gap above. (#810)
- `XCAFPrs_AISObject`, `XCAFPrs_Texture`: in this lane's package but belonging to Pass 4d's
  subject matter (#814). `XCAFPrs_AISObject` is an `AIS_ColoredShape` presenting a whole XDE
  document, and OCCTSwift's display surface renders a `Shape` rather than a document;
  `XCAFPrs_Texture` is a `Graphic3d_Texture2D`, and the bridge reads `XCAFDoc_VisMaterial`'s texture
  paths as strings instead. Recorded here rather than left between two lanes. (#810)

### Classes Not Wrapped At All

- `Geom2d_Direction`, `Geom2d_VectorWithMagnitude`, the headers are `#include`d but never used.
  `OCCTDirection2D*` and `OCCTVector2D*` are `gp_Dir2d`/`gp_Vec2d` arithmetic on bare doubles, not
  wrappers for the `Geom2d_` handle types; the cross-reference index claimed otherwise until #565
  measured it. Wrapping them would mean exposing a reference-counted handle for what is currently
  a value-type calculation.
- `gp_TrsfNLerp`, `GC_MakeLine`, `GC_MakeArcOfEllipse2d`, `GC_MakeArcOfHyperbola2d`,
  `GC_MakeArcOfParabola2d`: the headers are `#include`d (`OCCTBridge_Spatial.mm`,
  `OCCTBridge.mm`, `OCCTBridge_Geom2d.mm`) but never constructed, the same shape as
  `Geom2d_Direction` above. `gp_TrsfNLerp`'s sibling rotation-only interpolators,
  `gp_QuaternionNLerp`/`gp_QuaternionSLerp`, ARE wrapped (`OCCTQuaternionNLerp`/
  `OCCTQuaternionSLerp`, `MathSolver.swift`), full-transform (translation + scale + rotation)
  interpolation is not. `GC_MakeLine`'s segment-with-validation sibling `GC_MakeSegment` is wrapped
  and documented; the raw infinite-line constructor is not. The angle-bounded 2D elliptical/
  hyperbolic/parabolic arc CAPABILITY the other three provide is still available,
  `OCCTCurve2DCreateArcOfEllipse`/`CreateArcOfHyperbola`/`CreateArcOfParabola` build the trimmed
  arc directly from `Geom2d_Ellipse`/`Geom2d_Hyperbola`/`Geom2d_Parabola` + `Geom2d_TrimmedCurve`
  instead of going through these Make helpers (`docs/reference/Curve2D.md`'s `arcOfEllipse`/
  `arcOfHyperbola`/`arcOfParabola` entries name the correct backing classes as of #809), only the
  specific Make-helper *class* goes unused, not the underlying arc construction. (#809)
- `gp_Vec2f`, `gp_Vec3f`, `BRepExtrema_MapOfIntegerPackedMapOfInteger`, `BRepExtrema_SeqOfSolution`,
  `BRepClass3d_MapOfInter`: deprecated since OCCT 8.0.0, each a `using`/`typedef` alias for a
  single-precision `NCollection_Vec{2,3}<float>` or an `NCollection_DataMap`/`NCollection_Sequence`
  instantiation, not a distinct constructible type. Same "NCollection containers" and (for the two
  `Vec` aliases) single-precision-vs-this-project's-double-precision rationale the summary table
  above already gives; none has any live use in the bridge. (#809)
- `gp_VectorWithNullMagnitude`, `BRepExtrema_UnCompatibleShape`, `Standard_DomainError` exception
  types (`DEFINE_STANDARD_EXCEPTION`), not constructible geometry. `gp_VectorWithNullMagnitude` is
  what `gp_Vec`/`gp_Dir`'s own constructor throws for a zero-length input, already absorbed by the
  bridge-wide `catch (...)` sweep the #345 entry in `CLAUDE.md`'s Known OCCT Bugs describes;
  `BRepExtrema_UnCompatibleShape` is `BRepExtrema`'s equivalent for a shape-type mismatch, caught
  the same way at every `BRepExtrema_*` call site. Neither is something to "wrap" as a value. (#809)
- The entire `GCE2d_*` package (`GCE2d_MakeArcOfCircle`, `GCE2d_MakeArcOfEllipse`,
  `GCE2d_MakeArcOfHyperbola`, `GCE2d_MakeArcOfParabola`, `GCE2d_MakeCircle`, `GCE2d_MakeEllipse`,
  `GCE2d_MakeHyperbola`, `GCE2d_MakeLine`, `GCE2d_MakeMirror`, `GCE2d_MakeParabola`,
  `GCE2d_MakeRotation`, `GCE2d_MakeScale`, `GCE2d_MakeSegment`, `GCE2d_MakeTranslation`, and
  `GCE2d_Root`),
  every header in the package has been a `using GCE2d_X = GC_X2d` (or `= GC_Root`) deprecated
  compatibility alias since OCCT 8.0.0, not a distinct class; the refman generates no page for any
  of them (queried via the `context` MCP's `occt-refman@8.0.0-p1`, #809). v0.156.0 already migrated
  most internal use onto the canonical `GC_*2d` names, and #809's own sweep found six
  `docs/reference/Curve2D.md`/`Curve2D-Analysis.md` entries that still named the deprecated
  `GCE2d_Make*` class as the backing implementation for a Swift method that, per direct inspection
  of the bridge, either used the canonical `GC_*2d` name already (`arcThrough`) or never used any
  `GC_`/`GCE2d_` Make helper at all, constructing the `Geom2d_*` primitive directly (`arcOfCircle`,
  `arcOfEllipse`, `arcOfHyperbola`, `arcOfParabola`, the `Point2D`-taking `segment` overload), the
  exact `GCE2d_*`/`GC_*` prefix confusion #508 warned future audits to watch for; all six corrected
  here. #809's sweep also found one site that regressed back to the deprecated spelling,
  `OCCTBridge_Modeling.mm`'s `OCCTShapeCreateFaceFromSurfaceUVPolygon` still calls
  `GCE2d_MakeSegment`: but **left it unrenamed**, because at the time that file was grandfathered on
  `Scripts/style-manifest-bridge.txt` and `check-style-manifest.py` mechanically required bringing
  the *whole* file into `clang-format` compliance (a ~24,000-line diff) the moment any line in it
  changed, the same situation #917 then tracked (deferred from PR #912). **That blocker is gone**:
  #917 is closed, `OCCTBridge_Modeling.mm` is compliant, and `Scripts/style-manifest-bridge.txt` is
  now empty, so the file costs nothing extra to touch. The rename itself was never done, so one
  `GCE2d_*` reference still remains in the bridge (`OCCTBridge_Modeling.mm:3035`, plus its include
  at `:174`); it is behavior-identical (the deprecated name is a type alias for the one it would
  become) and now needs only its own change, not a sweep. Current docs (outside
  `docs/CHANGELOG.md`, a historical record) reference none. (#809, #917)
- Thirty deprecated collection typedefs: `BRepBuilderAPI_CellFilter`,
  `BRepCheck_DataMapOfShapeListOfStatus`, `BRepCheck_IndexedDataMapOfShapeResult`,
  `BRep_ListOfCurveRepresentation`, `BRep_ListOfPointRepresentation`,
  `TopTools_Array1OfListOfShape`, `TopTools_Array1OfShape`, `TopTools_Array2OfShape`,
  `TopTools_DataMapOfIntegerListOfShape`, `TopTools_DataMapOfIntegerShape`,
  `TopTools_DataMapOfOrientedShapeInteger`, `TopTools_DataMapOfOrientedShapeShape`,
  `TopTools_DataMapOfShapeBox`, `TopTools_DataMapOfShapeInteger`,
  `TopTools_DataMapOfShapeListOfInteger`, `TopTools_DataMapOfShapeListOfShape`,
  `TopTools_DataMapOfShapeReal`, `TopTools_DataMapOfShapeSequenceOfShape`,
  `TopTools_DataMapOfShapeShape`, `TopTools_HArray1OfListOfShape`, `TopTools_HArray1OfShape`,
  `TopTools_HArray2OfShape`, `TopTools_IndexedDataMapOfShapeAddress`,
  `TopTools_IndexedDataMapOfShapeReal`, `TopTools_IndexedDataMapOfShapeShape`,
  `TopTools_IndexedMapOfOrientedShape`, `TopTools_ListOfListOfShape`,
  `TopTools_MapOfOrientedShape`, `TopTools_MapOfShape`, `TopTools_SequenceOfShape`. Each header
  carries both `Standard_HEADER_DEPRECATED` at file scope and `Standard_DEPRECATED` on the typedef,
  all "deprecated since OCCT 8.0.0", and each is a `typedef` for an `NCollection_*` instantiation
  rather than a distinct class, so the "NCollection containers" row in the summary table above
  already covers them. **Five more headers in the same deprecated family are still called by the
  bridge** and so are not listed here: `TopTools_ListOfShape`, `TopTools_IndexedMapOfShape`,
  `TopTools_IndexedDataMapOfShapeListOfShape`, `TopTools_HSequenceOfShape` and
  `BRepCheck_ListOfStatus`. `docs/occt-upgrades.md`'s GA breaking-change table names only the
  second of those as "not yet migrated"; the migration to the canonical `NCollection_*` spelling is
  outstanding for all five, and none of the five is a wrapping gap, only a spelling one. (#808)
- `TopoDS_FrozenShape`, `TopoDS_LockedShape`, `TopoDS_UnCompatibleShapes`: `Standard_DomainError`
  exception types (`DEFINE_STANDARD_EXCEPTION`), not constructible topology. The first two are what
  a `TopoDS_Shape` modification raises when the shape, or its geometry, is already shared or
  protected; the third is what `TopoDS_Builder::Add` raises for an incorrect insertion. All three
  are absorbed by the bridge-wide `catch (...)` the #345 entry in `CLAUDE.md`'s Known OCCT Bugs
  describes, the same treatment `gp_VectorWithNullMagnitude` gets above. (#808)
- `BRepBuilderAPI_WireError`, `BRepBuilderAPI_PipeError`, `BRepBuilderAPI_TransitionMode`,
  `TopTools_FormatVersion`: enums whose **values** the Swift surface already mirrors, without the
  bridge ever naming the type. `WireBuilder.WireError`, `PipeShellStatus` and `PipeTransitionMode`
  each mirror their enum case for case in ordinal order (checked against the pinned headers), and
  the bridge passes the ordinal through as an `int32_t`. `TopTools_FormatVersion` is the one
  partial case: `BRepTools::Write` is always called with `TopTools_FormatVersion_CURRENT`, so
  writing an **older** BREP format version is not exposed. That is a deliberate gap rather than an
  oversight, since an older version is only useful for interoperating with an older OCCT and the
  reader side handles every version already; a caller who needs it should open an issue. (#808)
- `BRepBuilderAPI_FaceError`, `BRepBuilderAPI_ShellError`, `BRepBuilderAPI_EdgeError`,
  `BRepBuilderAPI_ShapeModification`: enums nothing in the tree reads. The first three are the
  `Error()` status of `BRepBuilderAPI_MakeFace`, `MakeShell` and `MakeEdge`/`MakeEdge2d`
  respectively (each enum's only consumer in the pinned header set), and the corresponding Swift
  factories report failure as a `nil` `Shape` and drop the reason, unlike `WireBuilder.error` which
  surfaces it. Surfacing the other three means changing those factories' return types, which is a
  public API change rather than a wrap, so it is recorded here rather than done.
  `BRepBuilderAPI_ShapeModification` is different again: **no** header in the pinned xcframework
  names it, so OCCT 8.0.1 has no entry point returning it and there is nothing to wrap. (#808)

- Fifty deprecated collection typedefs in the OCAF/XDE lane: `TDocStd_LabelIDMapDataMap`,
  `TDocStd_SequenceOfApplicationDelta`, `TDocStd_SequenceOfDocument`, `TDF_AttributeArray1`,
  `TDF_AttributeDataMap`, `TDF_AttributeDeltaList`, `TDF_AttributeDoubleMap`, `TDF_AttributeList`,
  `TDF_AttributeMap`, `TDF_AttributeSequence`, `TDF_DeltaList`, `TDF_GUIDProgIDMap`,
  `TDF_HAttributeArray1`, `TDF_IDList`, `TDF_IDMap`, `TDF_LabelDataMap`, `TDF_LabelDoubleMap`,
  `TDF_LabelIndexedMap`, `TDF_LabelIntegerMap`, `TDF_LabelList`, `TDataStd_DataMapOfStringByte`,
  `TDataStd_DataMapOfStringHArray1OfInteger`, `TDataStd_DataMapOfStringHArray1OfReal`,
  `TDataStd_DataMapOfStringReal`, `TDataStd_DataMapOfStringString`, `TDataStd_HLabelArray1`,
  `TDataStd_LabelArray1`, `TDataStd_ListOfByte`, `TDataStd_ListOfExtendedString`,
  `TDataXtd_Array1OfTrsf`, `TDataXtd_HArray1OfTrsf`, `TNaming_DataMapOfShapePtrRefShape`,
  `TNaming_DataMapOfShapeShapesSet`, `TNaming_ListOfIndexedDataMapOfShapeListOfShape`,
  `TNaming_ListOfMapOfShape`, `TNaming_ListOfNamedShape`, `TNaming_MapOfNamedShape`,
  `TNaming_NCollections`, `XCAFDoc_DataMapOfShapeLabel`,
  `XCAFDimTolObjects_DataMapOfToleranceDatum`, `XCAFDimTolObjects_DatumModifiersSequence`,
  `XCAFDimTolObjects_DimensionModifiersSequence`,
  `XCAFDimTolObjects_GeomToleranceModifiersSequence`, `XCAFPrs_DataMapOfStyleShape`,
  `XCAFPrs_DataMapOfStyleTransient`, `XCAFPrs_IndexedDataMapOfShapeStyle`, `CDM_ListOfDocument`,
  `CDM_ListOfReferences`, `CDM_MapOfDocument`, `CDM_NamesDirectory`. Each header carries
  `Standard_HEADER_DEPRECATED` at file scope, all "deprecated since OCCT 8.0.0", and each is a
  `typedef` for an `NCollection_*` instantiation rather than a distinct class, so the "NCollection
  containers" row in the summary table above already covers them. **Two more headers in the same
  deprecated family are still called by the bridge** and so are not listed here: `TDF_LabelSequence`
  (five bridge functions build one, including every GD&T count) and `TDF_LabelMap`. Neither is a
  wrapping gap, only an outstanding spelling migration, the same one the five `TopTools_*` entries
  below carry.

  **The file-scope test is what separates this list from a wrong one.** Grepping the lane's headers
  for `Standard_DEPRECATED` returns fifty-six, and five of those six extras are live, current,
  wrapped classes carrying a per-method deprecation on one accessor: `TDocStd_Application`
  (`GetDocument` by reference), `TDF_LabelSequence`, `TDataStd_Real`, `TDataStd_Variable` and
  `XCAFDoc_VisMaterial` (`IsDoubleSided`/`SetDoubleSided`, superseded by `FaceCulling`). Filing any
  of those as a deprecated alias would have been wrong in the most misleading direction, since each
  is something a caller uses today. (#810)
- Nine enums nothing in the tree reads. Exactly one is a GD&T enum,
  `XCAFDimTolObjects_ToleranceZoneAffectedPlane`, which is the type of a geometric tolerance's
  affected plane; it stays unbound because `GetAffectedPlaneType` and `GetAffectedPlane` are not
  wrapped, and the type on its own would be half an answer (see the two #1004 sections below).
  Twelve of the thirteen this bullet used to name are now bound and gated against the pinned
  headers by `Scripts/derive-gdt-enums.py`: `XCAFDimTolObjects_DimensionFormVariance` and
  `XCAFDimTolObjects_DimensionGrade` as `Document.DimensionFormVariance` and
  `Document.DimensionGrade` (#996); `XCAFDimTolObjects_DimensionQualifier`,
  `XCAFDimTolObjects_AngularQualifier` and `XCAFDimTolObjects_DimensionModif` as
  `Document.DimensionQualifier`, `Document.AngularQualifier` and `Document.DimensionModifier`;
  and `XCAFDimTolObjects_GeomToleranceTypeValue`, `XCAFDimTolObjects_GeomToleranceMatReqModif`,
  `XCAFDimTolObjects_GeomToleranceZoneModif`, `XCAFDimTolObjects_GeomToleranceModif`,
  `XCAFDimTolObjects_DatumSingleModif`, `XCAFDimTolObjects_DatumModifWithValue` and
  `XCAFDimTolObjects_DatumTargetType` as `Document.GeomToleranceValueType`,
  `Document.MaterialRequirement`, `Document.GeomToleranceZoneModifier`,
  `Document.GeomToleranceModifier`, `Document.DatumModifier`, `Document.DatumModifierWithValue`
  and `Document.DatumTargetType` (#1004). Four more are `CDF_Store`'s own statuses,
  `CDF_StoreSetNameStatus`, `CDF_SubComponentStatus`, `CDF_TryStoreStatus` and
  `CDF_TypeOfActivation`: the bridge saves through `TDocStd_Application::SaveAs`, which reports
  `PCDM_StoreStatus`, and that **is** wrapped as `StoreStatus`, so these are reachable only by
  driving `CDF_Store` directly. `CDM_CanCloseStatus` is `TDocStd_Document::CanClose`'s verdict, and
  the bridge closes documents unconditionally and drops the reason. `TDocStd_FormatVersion` is the
  OCAF document format version: a storage format is selected by name (`BinOcaf`, `XmlOcaf`,
  `BinXCAF` and the rest) and never by version, so writing an **older** document version is not
  exposed, exactly the `TopTools_FormatVersion` case above and deliberate for the same reason.
  `TDataStd_RealEnum` is the unit tag on a `TDataStd_Real`, which the attribute is wrapped without.
  `TNaming_NameType` is the naming resolver's rule kind: `TNaming_Naming` is wrapped as an opaque
  attribute, so which rule resolved a name is not surfaced. (#810)

### Features lane, every unwrapped class recorded (#811)

#811 is #807's Pass 4a: the features lane audited against the pinned refman
(`occt-refman@8.0.1` through the `context` MCP) in both directions. The lane is ten OCCT packages
and **129 classes**: the six #811's own body names (`BRepFeat_`, `BRepFilletAPI_`,
`BRepOffsetAPI_`, `ChFi2d_`, `ChFi3d_`, `LocOpe_`) plus four that no pass of #807 names at all,
each added for its own measured reason rather than as a block:

- `Plate_` is reached by the lane's own calls: 15 of its 60 are `OCCTPlate*`, and those
  construct `Plate_*` and nothing else.
- `NLPlate_` and `GeomPlate_` are constructed in `OCCTBridge_ProjLib_NLPlate.mm`, the one bridge
  file Pass 4a assigns to this lane whole. The lane's nine Swift files do not call the functions
  that build them (`Surface.swift` and `Shape.swift` do), so this is a file claim rather than a
  call claim, and it is stated as one.
- `BRepMAT2d_` is reached by neither. It sits in `OCCTBridge_Geom2d.mm` behind `MedialAxis.swift`.
  It is here because no pass names it and the medial axis is the nearest subject to this lane,
  which is a judgement rather than a measurement, and the alternative was leaving five classes
  unaudited by anyone.

**82 of the 129 are wrapped or documented, and 47 were neither.** Three of the 129 were named in
this file before this entry, and it is worth being exact about them, because two are genuine
recorded omissions: `ChFi3d_FilBuilder` and `ChFi3d_ChBuilder` share a bullet under "Classes Not
Wrapped (require abstract subclass implementations)" with the reason "complex stateful builders
with protected virtuals", and `BRepOffsetAPI_MakePipe` is named as a wrapped class rather than an
omission. **Neither ChFi3d builder was ever one of the 47**, because both are documented
elsewhere under `docs/`. So of the 47 classes that actually needed a reason, none had one, which
is the largest single result of that pass.

The census is committed and re-runnable at
[`Scripts/repro/811-refman-coverage-features/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/811-refman-coverage-features);
it exits 1 if any class below loses its reason here.

**Deprecated collection aliases (24).** Each header carries `Standard_HEADER_DEPRECATED` at file
scope saying the alias is deprecated since OCCT 8.0.0 and to use the `NCollection_*` template
directly. Wrapping a deprecated typedef is not a capability, and it is the same "NCollection
containers" line the summary table above already gives:
`BRepMAT2d_DataMapOfBasicEltShape`, `BRepMAT2d_DataMapOfShapeSequenceOfBasicElt`,
`BRepOffsetAPI_SequenceOfSequenceOfReal`, `BRepOffsetAPI_SequenceOfSequenceOfShape`,
`GeomPlate_Array1OfHCurve`, `GeomPlate_Array1OfSequenceOfReal`, `GeomPlate_HArray1OfHCurve`,
`GeomPlate_HArray1OfSequenceOfReal`, `GeomPlate_HSequenceOfCurveConstraint`,
`GeomPlate_HSequenceOfPointConstraint`, `GeomPlate_SequenceOfAij`,
`GeomPlate_SequenceOfCurveConstraint`, `GeomPlate_SequenceOfPointConstraint`,
`LocOpe_DataMapOfShapePnt`, `LocOpe_SequenceOfCirc`, `LocOpe_SequenceOfLin`,
`LocOpe_SequenceOfPntFace`, `NLPlate_SequenceOfHGPPConstraint`, `NLPlate_StackOfPlate`,
`Plate_Array1OfPinpointConstraint`, `Plate_HArray1OfPinpointConstraint`,
`Plate_SequenceOfLinearScalarConstraint`, `Plate_SequenceOfLinearXYZConstraint`,
`Plate_SequenceOfPinpointConstraint`.

**Abstract bases (5).** Not constructible, so the bridge wraps the concrete subclasses instead,
the same rule the "require abstract subclass implementations" section above states.
`BRepFeat_Form` (pure virtual, the base the `BRepFeat_Make*` forms share),
`BRepFilletAPI_LocalOperation` (pure virtual, the base `MakeFillet` and `MakeChamfer` share),
`LocOpe_GeneratedShape` and `NLPlate_HGPPConstraint` (both pure virtual with a protected
constructor), and `BRepFeat_RibSlot`, which a pure-virtual test alone misses: it declares none, and
its only constructor sits at `BRepFeat_RibSlot.hxx:113`, two lines after `protected:`.

**Enums (4).** `ChFi2d_ConstructionError` is read, by value rather than by type name:
`builder.Status() != ChFi2d_IsDone` at ten sites, six in `OCCTBridge_Modeling.mm` and four in
`OCCTBridge_Healing.mm`. It is listed here because a name-based coverage test cannot see that,
not because it is a gap. The other three are unread, and two of them are
**unsurfaced rather than unreachable**, which a first draft of this paragraph got wrong in both
cases by reasoning from the class name instead of the header:

- `BRepFeat_StatusError` is what `BRepFeat_Form::CurrentStatusError()` returns, and that method is
  **public** (`BRepFeat_Form.hxx:134`, two lines before `protected:`), inherited by
  `BRepFeat_MakePrism`, `BRepFeat_MakeRevol` and `BRepFeat_MakeDPrism`, all three of which the
  bridge constructs. A caller wanting the error code for a failed `withPrism` cannot get it, and
  that is a small real gap rather than nothing to wrap.
- `LocOpe_Operation` is the return type of `LocOpe_Gluer::OpeType()` and
  `BRepFeat_Gluer::OpeType()`, both public getters on classes the bridge constructs. It is not a
  mode a caller sets, which is what an earlier draft said; it is a verdict the bridge does not
  pass on.
- `BRepFeat_PerfSelection` is the one that really is unreachable: it appears only on protected
  members of `BRepFeat_Form` and `BRepFeat_RibSlot`, with no public accessor anywhere.

**Covered by a sibling (1).** `BRepOffsetAPI_Sewing` is a one-line
`typedef BRepBuilderAPI_Sewing`, and the sibling is wrapped.

**Not a class (1).** `ChFi3d_Builder_0.hxx` declares no class of its own name. It is free helper
functions for `ChFi3d_Builder.cxx`, so there is nothing to wrap.

**Internal helpers (7).** Each serves one already-wrapped entry point and has no independent use:
`BRepMAT2d_LinkTopoBilo` (maps `BRepMAT2d_Explorer` input back to `MAT_BasicElt`),
`ChFi3d_SearchSing` (a `math_FunctionWithDerivative` `ChFi3d_Builder` solves internally),
`GeomPlate_Aij` (two normal indexes and their cross product, `GeomPlate_BuildAveragePlane`'s own
record), `GeomPlate_PlateG0Criterion` and `GeomPlate_PlateG1Criterion` (`AdvApp2Var_Criterion`
subclasses `GeomPlate_MakeApprox` constructs for itself), and `LocOpe_Generator` and
`LocOpe_GluedShape` (the generator and its generated-shape subclass that `BRepFeat_Gluer` drives).

**Real capability gaps, recorded as such (5 classes, 4 of them gaps).** The heading counts
classes, like every heading above it, so the seven category counts still sum to 47. Four of
the five are things a CAD consumer could reasonably want and this package does not offer. The
fifth, the second bullet, sat here as a gap until this pass's fifth review round measured it
and found it reached; it is kept, marked, because it is the reason the other number is four:

- `Plate_SampledCurveConstraint` is the one `Plate_Plate::Load` overload of nine that no bridge
  function reaches by any route. The count wants care, and a first draft of this bullet got it
  wrong by reading the header instead of the call sites. Four overloads are invoked directly
  (`Plate_PinpointConstraint`, `Plate_LinearXYZConstraint`, `Plate_LinearScalarConstraint`,
  `Plate_GtoCConstraint`) and four more are reached by decomposition, because
  `Plate_PlaneConstraint`, `Plate_LineConstraint` and `Plate_FreeGtoCConstraint` each hand back
  a `Plate_LinearScalarConstraint` from `LSC()` and `Plate_GlobalTranslationConstraint` hands
  back a `Plate_LinearXYZConstraint` from `LXYZC()`, and the bridge loads those (four
  `p->Load(...LSC())` and `pp->Load(...LXYZC())` sites in `OCCTBridge_ProjLib_NLPlate.mm`;
  `grep -n 'Load(' ` rather than a line number, because #1069 moved all four by fifty lines
  while this audit was in review). So the sampled-curve constraint,
  which fits a plate through a curve rather than through points, is the gap. Folded into
  #1021's `Plate_Plate` row rather than filed separately.
- `Plate_LinearScalarConstraint` is the opposite case and is listed for the same reason
  `ChFi2d_ConstructionError` is: it is constructed and loaded three times over, and its name
  never appears in the bridge, so a coverage test that greps for the class reports it missing.
  Nothing is unwrapped here.
- `NLPlate_HPG1Constraint`, `NLPlate_HPG2Constraint` and `NLPlate_HPG3Constraint` are the "(no G0)"
  constraints: the pinned refman describes `NLPlate_HPG1Constraint` as a "PinPoint (no G0) G1
  Constraint" and its constructor takes `(gp_XY UV, Plate_D1 D1T)` with no position at all, while
  `NLPlate_HPG0G1Constraint` is "PinPoint G0+G1" and takes `(gp_XY UV, gp_XYZ Value, Plate_D1
  D1T)`. `Surface.nlPlateDeformedG1`/`G2`/`G3` take a target point, so the bridge builds the
  `HPG0Gn` form, and that is correct. Constraining a tangent, curvature or third derivative
  *without* pinning the point is a different capability and is not offered. Until #811 the docs
  named the no-G0 classes as the ones backing those three methods, which was wrong in the opposite
  direction and is corrected in the same PR.

### Drawing / 2D-annotation lane, every unwrapped class recorded (#812)

#812 is #807's Pass 4b: the Drawing/2D-annotation lane audited against the pinned refman
(`occt-refman@8.0.1` through the `context` MCP) in both directions. The lane's own `## Lane` text
names `HLRBRep_*`, `HLRAlgo_*`, `Prs3d_* where it backs 2D output`, and the
`Drawing`/`DrawingAnnotation`/`DrawingSheet` Swift surface; re-derived by call
(`Scripts/repro/812-refman-coverage-drawing/derive_lane.py`) it is **three** packages and **93**
classes, not the two the issue text names: `HLRAlgo_` (29, including the bare `HLRAlgo.hxx`
package-utility header), `HLRBRep_` (63, including the bare `HLRBRep.hxx`), and `HLRAppli_` (1,
`HLRAppli_ReflectLines`, reached two functions below `OCCTHLRCompoundOfEdges` in the same
`OCCTBridge_Modeling.mm` block that `Shape+Topology.swift`'s HLR calls reach, and named by no pass
of #807). `Prs3d_` contributes **zero** classes: the only two `Prs3d_*` construction sites in the
whole bridge (`Prs3d_Drawer`, `Prs3d_Presentation`) sit behind `DisplayDrawer.swift`, which is Metal
tessellation-quality control for 3D display, exactly what the lane's own "where it backs 2D output"
qualifier excludes.

**7 of the 93 are wrapped, 86 were neither wrapped nor documented before this entry.** The five
public entry points a CAD consumer actually calls are `HLRBRep_Algo`/`HLRBRep_HLRToShape` (exact
HLR), `HLRBRep_PolyAlgo`/`HLRBRep_PolyHLRToShape` (poly/triangulation HLR), `HLRAlgo_Projector`
(shared by both), plus `HLRAppli_ReflectLines` and the `HLRBRep_TypeOfResultingEdge` enum (read by
value, not by name, in `OCCTBridge_Modeling.mm`). Unlike #811's lane, almost none of the remaining
86 is a real capability gap: hidden-line removal is one nontrivial geometric algorithm with those
five classes as its public surface and roughly sixty classes of its own internal machinery
underneath (a curve/curve and curve/surface intersection engine, a triangulation-internal polygon
data structure, template-policy "Tool" adaptors, deprecated collection typedefs, alias templates to
`GeomLProp_*Base` template instantiations). The census is committed and re-runnable at
[`Scripts/repro/812-refman-coverage-drawing/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/812-refman-coverage-drawing);
it exits 1 if any class below loses its reason here.

**Package-utility classes (2).** The bare `<Package>.hxx` headers are all-static-method classes
(`DEFINE_STANDARD_ALLOC`, no instance state) serving their own package's public algorithm classes,
not something a caller instantiates: `HLRAlgo` (packed min/max-box arithmetic --
`UpdateMinMax`/`EnlargeMinMax`/`EncodeMinMax`/`DecodeMinMax`/`SizeBox`/`AddMinMax` -- for
`HLRAlgo_EdgesBlock`'s internal state) and `HLRBRep` (`MakeEdge`/`MakeEdge3d`, HLR-curve-to-
`TopoDS_Edge` construction for `HLRBRep_Algo`'s own internal use, and
`PolyHLRAngleAndDeflection` for `HLRBRep_PolyAlgo`'s).

**Deprecated collection aliases (15).** Each header carries `Standard_HEADER_DEPRECATED` at file
scope saying the alias is deprecated since OCCT 8.0.0 and to use the `NCollection_*` template
directly, the same "NCollection containers" line the summary table at the top of this file already
gives: `HLRAlgo_Array1OfPHDat`, `HLRAlgo_Array1OfPINod`, `HLRAlgo_Array1OfPISeg`,
`HLRAlgo_Array1OfTData`, `HLRAlgo_HArray1OfPHDat`, `HLRAlgo_HArray1OfPINod`,
`HLRAlgo_HArray1OfPISeg`, `HLRAlgo_HArray1OfTData`, `HLRAlgo_InterferenceList`,
`HLRAlgo_ListOfBPoint`, `HLRBRep_Array1OfEData`, `HLRBRep_Array1OfFData`, `HLRBRep_ListOfBPnt2D`,
`HLRBRep_ListOfBPoint`, `HLRBRep_SeqOfShapeBounds`.

**Alias templates (5).** A `using X = Template<...>;` header, declaring no `class`/`struct` of its
own name, each one an internal local-properties or extremum/locator evaluator the HLR curve-tool
engine builds for itself, the same shape #811's `declares_member` needed a "cannot say" answer for
at the method level, here at the lane-membership level instead: `HLRBRep_CLProps` (`using
HLRBRep_CLProps = GeomLProp_CLPropsBase<gp_Pnt2d, gp_Vec2d, gp_Dir2d, const HLRBRep_Curve*,
LProp_CurveUtils::ToolAccess<HLRBRep_CLPropsATool>>`, 2D curve local-property evaluation for edge
sampling), `HLRBRep_SLProps` (the surface sibling), and the three-class family
`HLRBRep_PCLocFOfTheLocateExtPCOfTheProjPCurOfCInter` / `HLRBRep_TheCurveLocatorOfTheProjPCurOfCInter`
/ `HLRBRep_TheLocateExtPCOfTheProjPCurOfCInter`, the extremum-locator machinery
`HLRBRep_CInter.hxx` includes as one internal group.

**Not a class (1).** `HLRBRep_TypeDef.hxx` declares no class of its own name: two `typedef void*`
aliases (`HLRBRep_CurvePtr`, `HLRBRep_SurfacePtr`) for the generic template-instantiation interface,
nothing to wrap.

**An enum, unread (1).** `HLRAlgo_PolyMask`'s 13 bit-flag values
(`EMskOutLin1`...`FMskFrBack`) are packed into `HLRAlgo_EdgesBlock`'s internal per-edge state;
nothing outside `HLRAlgo` itself reads them, by value or by name.

**Internal engine helpers (62), four measured sub-mechanisms.** Each concrete class serves the
algorithm engine behind an already-wrapped entry point, with no independent capability a CAD
consumer could reach; confirmed against `occt-refman@8.0.1`'s own class pages rather than inferred
from the name (`HLRAlgo_PolyInternalData`'s own summary is "to Update OutLines", `HLRBRep_Data`'s
public methods are `AboveInterference`/`HidingTheFace`/`InitInterference`/`RejectedInterference`/
`SimpleHidingFace`/`Edge`/`Tolerance`, an edge-hiding cursor with no capability beyond it).

- *Poly (triangulation) HLR engine's own internal data (16)*, the mesh-internal state
  `HLRBRep_PolyAlgo` drives through `HLRAlgo_PolyAlgo`: `HLRAlgo_PolyAlgo`, `HLRAlgo_BiPoint`,
  `HLRAlgo_Coincidence`, `HLRAlgo_EdgeIterator`, `HLRAlgo_EdgeStatus`, `HLRAlgo_EdgesBlock`,
  `HLRAlgo_Interference`, `HLRAlgo_Intersection`, `HLRAlgo_PolyData`, `HLRAlgo_PolyHidingData`,
  `HLRAlgo_PolyInternalData`, `HLRAlgo_PolyInternalNode`, `HLRAlgo_PolyInternalSegment`,
  `HLRAlgo_PolyShellData`, `HLRAlgo_TriangleData`, `HLRAlgo_WiresBlock`.
- *Exact HLR engine's own internal state (21)*, the edge/face/interference cursor state
  `HLRBRep_Algo` drives through `HLRBRep_Data`: `HLRBRep_AreaLimit`, `HLRBRep_BiPnt2D`,
  `HLRBRep_BiPoint`, `HLRBRep_CInter`, `HLRBRep_Curve`, `HLRBRep_Data`, `HLRBRep_EdgeBuilder`,
  `HLRBRep_EdgeData`, `HLRBRep_EdgeFaceTool`, `HLRBRep_EdgeIList`, `HLRBRep_EdgeInterferenceTool`,
  `HLRBRep_FaceData`, `HLRBRep_FaceIterator`, `HLRBRep_Hider`, `HLRBRep_InterCSurf`,
  `HLRBRep_InternalAlgo`, `HLRBRep_Intersector`, `HLRBRep_ShapeBounds`, `HLRBRep_ShapeToHLR`,
  `HLRBRep_Surface`, `HLRBRep_VertexList`.
- *Template-policy "Tool" adaptors (7)*, static geometric-evaluator methods the two engines above
  are instantiated over, not classes a caller constructs: `HLRBRep_BCurveTool`,
  `HLRBRep_BSurfaceTool`, `HLRBRep_CLPropsATool`, `HLRBRep_CurveTool`, `HLRBRep_LineTool`,
  `HLRBRep_SLPropsATool`, `HLRBRep_SurfaceTool`.
- *`HLRBRep_CInter`'s/`HLRBRep_InterCSurf`'s own intersection-engine template instantiations (18)*,
  OCCT's generic-intersection-macro naming for this toolkit ("The\<X\>Of\<Y\>"/"My\<X\>Of\<Y\>"),
  macro-generated 2D curve/curve or curve/surface intersection internals with no independent use
  outside that engine: `HLRBRep_ExactIntersectionPointOfTheIntPCurvePCurveOfCInter`,
  `HLRBRep_IntConicCurveOfCInter`,
  `HLRBRep_MyImpParToolOfTheIntersectorOfTheIntConicCurveOfCInter`,
  `HLRBRep_TheCSFunctionOfInterCSurf`, `HLRBRep_TheDistBetweenPCurvesOfTheIntPCurvePCurveOfCInter`,
  `HLRBRep_TheExactInterCSurf`, `HLRBRep_TheIntConicCurveOfCInter`,
  `HLRBRep_TheInterferenceOfInterCSurf`, `HLRBRep_TheIntersectorOfTheIntConicCurveOfCInter`,
  `HLRBRep_TheIntPCurvePCurveOfCInter`, `HLRBRep_ThePolygon2dOfTheIntPCurvePCurveOfCInter`,
  `HLRBRep_ThePolygonOfInterCSurf`, `HLRBRep_ThePolygonToolOfInterCSurf`,
  `HLRBRep_ThePolyhedronOfInterCSurf`, `HLRBRep_ThePolyhedronToolOfInterCSurf`,
  `HLRBRep_TheProjPCurOfCInter`, `HLRBRep_TheQuadCurvExactInterCSurf`,
  `HLRBRep_TheQuadCurvFuncOfTheQuadCurvExactInterCSurf`.

**Adjacent, not in this lane, worth recording so a future pass does not re-derive it.**
`HatchPattern.swift`'s `OCCTHatchLines` builds a `Hatch_Hatcher` (package `Hatch_`, not named by
#812's own lane text and not audited here). `Annotation.swift`'s `OCCTDimensionCreate*`/
`OCCTTextLabelCreate`/`OCCTPointCloudCreate` all reach `OCCTBridge_AIS.mm` (`AIS_*`/`PrsDim_*`),
3D-interactive/Metal per its own doc comments ("for Metal rendering"), not the 2D drawing-sheet
surface; nothing under `Drawing*.swift` uses its types. `TopCnx_`, named in the very doc section
heading `HLRAppli_` was justified from ("Extended HLR, ReflectLines, TopCnx, Intrv"), is edge-face
transition classification for BOP/healing, a different capability that shipped in the same v0.73.0
release batch, not a hidden-line-removal one, and is not added to this lane.

### OCAF framework layer, every unwrapped class recorded (#982)

#982 is #807's Pass 3b: the OCAF framework layer above the document API (#810) and below the
persistence drivers (#983, not audited here) audited against the pinned refman (`occt-refman@8.0.1`
through the `context` MCP) in both directions. The lane is five packages the issue text names
directly, consumed from `Scripts/repro/973-ocaf-package-partition/partition_census.py --pass 982`
rather than re-derived by grep: `TFunction_` (14 headers), `TPrsStd_` (12), `TObj_` (23), `AppStd_`
(1), `AppStdL_` (1) -- **51 classes total**, all in one bridge file
(`Sources/OCCTBridge/src/OCCTBridge_Document.mm`) and four Swift files (`DriverTable.swift`,
`TObjApplication.swift`, and the TFunction-prefixed sections of `Document.swift` and
`AssemblyNode.swift`; `Scripts/repro/982-refman-coverage-ocaf-framework/derive_lane.py` walks the
exact call surface, including two nearby, same-file, differently-packaged attribute families that
are NOT this lane: `Document.swift`'s `TDataXtd_Presentation` section and `AssemblyNode.swift`'s
`XCAFDoc_GraphNode` section, both confirmed via their own bridge `#include`s).

**9 of the 51 are wrapped, 42 were neither wrapped nor documented before this entry.** The census is
committed and re-runnable at
[`Scripts/repro/982-refman-coverage-ocaf-framework/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/982-refman-coverage-ocaf-framework);
it exits 1 if any class below loses its reason here. Six curated categories cover all 42, each
measured against the pinned header rather than guessed from the name:

**Deprecated collection aliases (8).** Each header carries `Standard_HEADER_DEPRECATED` at file
scope saying the alias is deprecated since OCCT 8.0.0 and to use the `NCollection_*` template
directly, the same "NCollection containers" line the summary table at the top of this file already
gives: `TFunction_Array1OfDataMapOfGUIDDriver`, `TFunction_DataMapOfGUIDDriver`,
`TFunction_DataMapOfLabelListOfLabel`, `TFunction_DoubleMapOfIntegerLabel`,
`TFunction_HArray1OfDataMapOfGUIDDriver`, `TObj_Container`, `TObj_SequenceOfIterator` (both declare
no class of their own header-basename name, only deprecated typedefs, the same "not a class" shape
as `HLRBRep_TypeDef` in the Drawing lane section above), `TPrsStd_DataMapOfGUIDDriver`.

**Requires an application-specific subclass (4).** A protected constructor, or a pure-virtual
method with no default body, each confirmed directly at the class's own header rather than assumed
from "abstract-sounding": `TFunction_Driver` (pure-virtual `Execute()`, `= 0` at
`TFunction_Driver.hxx:68`, the regeneration logic every driver must implement -- the bridge
registers drivers by GUID, `TFunction_DriverTable::HasDriver`/`Clear`, wrapped, but never subclasses
this itself), `TObj_Object` (protected constructor, `TObj_Object.hxx:99`, "the base class for OCAF
based TObj models"), `TObj_Model` (protected constructor, same pattern one level up the framework),
`TObj_Partition` (protected constructor, `TObj_Partition.hxx:46`, same pattern). Same limitation
this file's own "Classes Not Wrapped (require abstract subclass implementations)" section above
already names for `ChFi3d_FilBuilder`/`Approx_FitAndDivide`/`BRepBlend_AppSurface`: the bridge
architecture doesn't support implementing a C++ abstract class or a protected-constructor base.

**TObj object-model internal machinery (17).** A concrete `TObj_` class that takes or returns a
`Handle(TObj_Object)`/`Handle(TObj_Model)`/`TDF_Label` under that framework's own tree structure, or
walks one, with no capability independent of an application's own subclass of the framework root
(the four classes immediately above), which nothing in this bridge provides -- only
`TObj_Application`, the already-wrapped singleton entry point, is reached. Six iterator classes
(`TObj_LabelIterator`, `TObj_ModelIterator`, `TObj_ObjectIterator`, `TObj_OcafObjectIterator`,
`TObj_ReferenceIterator`, `TObj_SequenceIterator`), six label-attribute storage classes
`TObj_Object`'s own persistence writes (`TObj_TObject`, `TObj_TReference`, `TObj_TXYZ`,
`TObj_TNameContainer`, `TObj_TModel`, `TObj_TIntSparseArray`), four model-registry/checker/
root-partition helpers (`TObj_Assistant`, a static save/load bookkeeping interface keyed by
`Handle(TObj_Model)`; `TObj_CheckModel`, a consistency checker constructed from a
`Handle(TObj_Model)`; `TObj_Persistence`, "a root of tools ... to manage persistence of objects
inherited from TObj_Object"; `TObj_HiddenPartition`, a `TObj_Partition` subclass), and one enum
parameter of `TObj_Object`'s own delete-family methods, `TObj_DeletingMode`.

**OCCT's own live-viewer presentation pipeline, not ours (10).** Populates, or is reached only
through, `AIS_InteractiveContext`/`V3d_Viewer` (confirmed: neither type is referenced anywhere in
`Sources/OCCTBridge` or `docs/`) -- OCCTSwift's display layer is Metal via OCCTSwiftViewport, the
same fact the Drawing lane section above rests its `Prs3d_` finding on, confirmed independently
here rather than inherited. `TPrsStd_AISPresentation` (its own header: "associate an
AIS_InteractiveObject to a label in an AIS viewer... works in collaboration with
TPrsStd_AISViewer") and `TPrsStd_AISViewer` ("stores an interactive context at the root label")
both directly `#include <AIS_InteractiveContext.hxx>`/take a `Handle(AIS_InteractiveContext)`. The
six standard `TPrsStd_Driver` subclasses `TPrsStd_DriverTable::InitStandardDrivers()` registers by
GUID (`TPrsStd_AxisDriver`, `TPrsStd_ConstraintDriver`, `TPrsStd_GeometryDriver`,
`TPrsStd_NamedShapeDriver`, `TPrsStd_PlaneDriver`, `TPrsStd_PointDriver`), the abstract
`TPrsStd_Driver` interface they implement (`virtual bool Update(const
TDF_Label&, Handle(AIS_InteractiveObject)&)`), and its static helper `TPrsStd_ConstraintTools`
(builds an `AIS_InteractiveObject` for constraint display) are none of them named directly by the
bridge, even though `DriverTable.initStandard()` activates all six by GUID registration -- the same
"reached, but never named, by an already-wrapped entry point" shape the Drawing lane's internal HLR
engine classes have.

**Legacy resource-name subclasses (2).** `AppStd_Application` and `AppStdL_Application`, whose own
header doc comments read, verbatim, "Legacy class defining resources name for standard/lite OCAF
documents" -- each a `TDocStd_Application` subclass overriding only `ResourcesName()` to point at a
different resource file. Since #371 this bridge already constructs `TDocStd_Application` directly
(`new TDocStd_Application()`) rather than any subclass singleton; neither legacy subclass adds a
capability that direct instantiation lacks.

**A real capability gap, recorded as one rather than folded into a curated excuse it doesn't fit
(1).** `TFunction_Iterator` -- "Iterator of the graph of functions" per its own header doc comment,
the class that actually WALKS the regeneration dependency graph in execution order
(`More`/`Next`/`Current`, `GetMaxNbThreads` for parallel batches) -- has a public constructor
(`TFunction_Iterator(const TDF_Label&)`, no subclassing needed) and is `#include`d at
`OCCTBridge_Document.mm:10324` and never constructed: `OCCTDocumentFunctionScopeCount` reads
`scope->GetFunctions().Extent()` directly instead. This bridge wraps every OTHER piece of the
regeneration mechanism (`TFunction_Function` to mark a label driven, `TFunction_DriverTable` to
register a driver by GUID, `TFunction_GraphNode` for dependency edges, `TFunction_Logbook` for
change tracking) but not the class that would let a caller actually walk them in dependency order.
An earlier hand read of this bridge during #982 assumed the `#include` meant the class was wrapped;
the census script's own `named_in_bridge` test caught that assumption wrong, which is the point of
running one. Recording it here rather than wrapping it, since #982 is a coverage audit, not a
wrapping pass (`docs/v2.0.0-plan.md`'s own scope note); a future wrapping-focused release is where
`Document`/`AssemblyNode` would gain a `functionIterator()`-shaped entry point.

**Two over-coverage findings, both fixed in this same PR (docs-only, no Swift/bridge/kernel
change).** `docs/reference/Document-XCAF-Notes.md` attributed `TObjApplication.createDocument()` to
`TObj_Application::NewDocument`, a real method -- but the wrong one: it is inherited, unused, from
`TDocStd_Application`, while the bridge (`OCCTTObjApplicationCreateDocument`) calls
`TObj_Application`'s own `CreateNewDocument` override. Neither `census-doc-occt-attribution.py`
(the class `TObj_Application` genuinely is named in that bridge function's body) nor this pass's own
`check_method_attributions()` (the cited method genuinely IS declared, on the base class) can catch
a wrong-attribution-between-two-real-methods shape; it was found reading the header directly. The
same doc also attributed `DriverTable.initStandard()` to `TPrsStd_DriverTable::Get` +
"`TPrsStd_AISPresentation` standard driver registration"; `InitStandardDrivers()`'s own body binds
the six driver classes named above and never touches `TPrsStd_AISPresentation` at all, the textbook
shape `census-doc-occt-attribution.py --lane` is built to catch, and did.

### OCAF persistence and format drivers lane, family-level (#983)

#983 is #807's Pass 3c: the storage/retrieval drivers, persistent object model, schema/stream
layer and plugin loader underneath the OCAF document API, one driver package per attribute family
per format. The lane is **38 packages, 342 headers/classes** (already derived and committed by
#973's `Scripts/repro/973-ocaf-package-partition/partition_census.py --pass 983`, consumed rather
than re-derived here): `BinDrivers_`, `BinLDrivers_`, `BinMDF_`, `BinMDataStd_`, `BinMDataXtd_`,
`BinMDocStd_`, `BinMFunction_`, `BinMNaming_`, `BinObjMgt_`, `BinTObjDrivers_`, `BinMXCAFDoc_`,
`BinXCAFDrivers_`, `XmlDrivers_`, `XmlLDrivers_`, `XmlMDF_`, `XmlMDataStd_`, `XmlMDataXtd_`,
`XmlMDocStd_`, `XmlMFunction_`, `XmlMNaming_`, `XmlObjMgt_`, `XmlTObjDrivers_`, `XmlMXCAFDoc_`,
`XmlXCAFDrivers_`, `StdDrivers_`, `StdLDrivers_`, `PCDM_`, `Storage_`, `StdStorage_`, `StdObjMgt_`,
`StdObject_`, `StdPersistent_`, `StdLPersistent_`, `ShapePersistent_`, `FSD_`, `LDOM_`, `Plugin_`,
`UTL_`.

**This lane's own shape is different from #811's and #812's, deliberately.** #983's own body says
so: "expect this to be answered once for the whole driver family rather than per class, and expect
that to be the correct answer: an attribute driver is not a callable capability, it is what makes
an attribute survive a round trip." Measured against that prediction: **9 of the 342 are wrapped or
documented** (the eight classes the bridge actually names -- `BinDrivers`, `BinLDrivers`,
`XmlDrivers`, `XmlLDrivers`, `BinXCAFDrivers`, `XmlXCAFDrivers`, `PCDM_ReaderStatus`,
`PCDM_StoreStatus` -- plus the bare `PCDM` package header, incidentally named by the
"PCDM Status Enums" section heading in `docs/reference/Document-Persistence-IO.md`), and every one
of the other 333 is machinery those eight plus the six `OCCTDocumentDefineFormat*` functions and
the `OCCTDocumentSaveOCAF*`/`OCCTDocumentLoadOCAF` entry points configure, curated below in
thirteen family-level buckets rather than 333 individual reasons. The census is committed and
re-runnable at
[`Scripts/repro/983-ocaf-persistence-drivers/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/983-ocaf-persistence-drivers);
it exits 1 if any class below loses its reason here.

**Driver-table subclasses (18).** The concrete `PCDM_StorageDriver`/`PCDM_Reader` subclass each
already-wrapped format's own `DefineFormat` registers with the target application; reached on every
save/load without ever being constructed by name in the bridge, one level down from the
package-utility class that names it: `BinDrivers_DocumentRetrievalDriver`,
`BinDrivers_DocumentStorageDriver`, `BinDrivers_Marker`, `BinLDrivers_DocumentRetrievalDriver`,
`BinLDrivers_DocumentSection`, `BinLDrivers_DocumentStorageDriver`, `BinLDrivers_Marker`,
`BinLDrivers_VectorOfDocumentSection`, `BinXCAFDrivers_DocumentRetrievalDriver`,
`BinXCAFDrivers_DocumentStorageDriver`, `XmlDrivers_DocumentRetrievalDriver`,
`XmlDrivers_DocumentStorageDriver`, `XmlLDrivers_DocumentRetrievalDriver`,
`XmlLDrivers_DocumentStorageDriver`, `XmlLDrivers_NamespaceDef`,
`XmlLDrivers_SequenceOfNamespaceDef`, `XmlXCAFDrivers_DocumentRetrievalDriver`,
`XmlXCAFDrivers_DocumentStorageDriver`.

**Attribute drivers (109).** One driver class per already-wrapped OCAF attribute type for one
format; `AddDrivers` (called from that format's own `DocumentStorageDriver`/
`DocumentRetrievalDriver` above, itself reached only through the wrapped `DefineFormat`) registers
the whole table at once, so the bridge reaches every class in these twelve packages without ever
naming one. Existence, not being called by name, is what lets the attribute survive a save/load
round trip, #983's own framing for this lane. `BinMDataStd`, `BinMDataStd_AsciiStringDriver`,
`BinMDataStd_BooleanArrayDriver`, `BinMDataStd_BooleanListDriver`, `BinMDataStd_ByteArrayDriver`,
`BinMDataStd_ExpressionDriver`, `BinMDataStd_ExtStringArrayDriver`,
`BinMDataStd_ExtStringListDriver`, `BinMDataStd_GenericEmptyDriver`,
`BinMDataStd_GenericExtStringDriver`, `BinMDataStd_IntPackedMapDriver`,
`BinMDataStd_IntegerArrayDriver`, `BinMDataStd_IntegerDriver`, `BinMDataStd_IntegerListDriver`,
`BinMDataStd_NamedDataDriver`, `BinMDataStd_RealArrayDriver`, `BinMDataStd_RealDriver`,
`BinMDataStd_RealListDriver`, `BinMDataStd_ReferenceArrayDriver`,
`BinMDataStd_ReferenceListDriver`, `BinMDataStd_TreeNodeDriver`, `BinMDataStd_UAttributeDriver`,
`BinMDataStd_VariableDriver`; `BinMDataXtd`, `BinMDataXtd_ConstraintDriver`,
`BinMDataXtd_GeometryDriver`, `BinMDataXtd_PatternStdDriver`, `BinMDataXtd_PositionDriver`,
`BinMDataXtd_PresentationDriver`, `BinMDataXtd_TriangulationDriver`; `BinMDocStd`,
`BinMDocStd_XLinkDriver`; `BinMFunction`, `BinMFunction_FunctionDriver`,
`BinMFunction_GraphNodeDriver`, `BinMFunction_ScopeDriver`; `BinMNaming`,
`BinMNaming_NamedShapeDriver`, `BinMNaming_NamingDriver`; `BinMXCAFDoc`,
`BinMXCAFDoc_AssemblyItemRefDriver`, `BinMXCAFDoc_CentroidDriver`, `BinMXCAFDoc_ColorDriver`,
`BinMXCAFDoc_DatumDriver`, `BinMXCAFDoc_DimTolDriver`, `BinMXCAFDoc_GraphNodeDriver`,
`BinMXCAFDoc_LengthUnitDriver`, `BinMXCAFDoc_LocationDriver`, `BinMXCAFDoc_MaterialDriver`,
`BinMXCAFDoc_NoteBinDataDriver`, `BinMXCAFDoc_NoteCommentDriver`, `BinMXCAFDoc_NoteDriver`,
`BinMXCAFDoc_VisMaterialDriver`, `BinMXCAFDoc_VisMaterialToolDriver`; and the ten identical Xml
siblings, each with the same per-attribute `*Driver` set as its Bin twin above (`XmlMNaming`
additionally carries `XmlMNaming_Shape1`, an XML-only helper with no Bin counterpart):
`XmlMDataStd`, `XmlMDataStd_AsciiStringDriver`, `XmlMDataStd_BooleanArrayDriver`,
`XmlMDataStd_BooleanListDriver`, `XmlMDataStd_ByteArrayDriver`, `XmlMDataStd_ExpressionDriver`,
`XmlMDataStd_ExtStringArrayDriver`, `XmlMDataStd_ExtStringListDriver`,
`XmlMDataStd_GenericEmptyDriver`, `XmlMDataStd_GenericExtStringDriver`,
`XmlMDataStd_IntPackedMapDriver`, `XmlMDataStd_IntegerArrayDriver`, `XmlMDataStd_IntegerDriver`,
`XmlMDataStd_IntegerListDriver`, `XmlMDataStd_NamedDataDriver`, `XmlMDataStd_RealArrayDriver`,
`XmlMDataStd_RealDriver`, `XmlMDataStd_RealListDriver`, `XmlMDataStd_ReferenceArrayDriver`,
`XmlMDataStd_ReferenceListDriver`, `XmlMDataStd_TreeNodeDriver`, `XmlMDataStd_UAttributeDriver`,
`XmlMDataStd_VariableDriver`; `XmlMDataXtd`, `XmlMDataXtd_ConstraintDriver`,
`XmlMDataXtd_GeometryDriver`, `XmlMDataXtd_PatternStdDriver`, `XmlMDataXtd_PositionDriver`,
`XmlMDataXtd_PresentationDriver`, `XmlMDataXtd_TriangulationDriver`; `XmlMDocStd`,
`XmlMDocStd_XLinkDriver`; `XmlMFunction`, `XmlMFunction_FunctionDriver`,
`XmlMFunction_GraphNodeDriver`, `XmlMFunction_ScopeDriver`; `XmlMNaming`,
`XmlMNaming_NamedShapeDriver`, `XmlMNaming_NamingDriver`, `XmlMNaming_Shape1`; `XmlMXCAFDoc`,
`XmlMXCAFDoc_AssemblyItemRefDriver`, `XmlMXCAFDoc_CentroidDriver`, `XmlMXCAFDoc_ColorDriver`,
`XmlMXCAFDoc_DatumDriver`, `XmlMXCAFDoc_DimTolDriver`, `XmlMXCAFDoc_GraphNodeDriver`,
`XmlMXCAFDoc_LengthUnitDriver`, `XmlMXCAFDoc_LocationDriver`, `XmlMXCAFDoc_MaterialDriver`,
`XmlMXCAFDoc_NoteBinDataDriver`, `XmlMXCAFDoc_NoteCommentDriver`, `XmlMXCAFDoc_NoteDriver`,
`XmlMXCAFDoc_VisMaterialDriver`, `XmlMXCAFDoc_VisMaterialToolDriver`.

**TObj_-based format drivers (16).** The driver-per-attribute-type family for the `TObj_`-based
custom document format. Each package's own `DefineFormat` has the same shape as bucket one above and
registers a distinct `BinTObj`/`XmlTObj` format GUID, but `TObj_` itself is barely wrapped (only
`TObj_Application`, #982's lane) and no bridge function ever builds a `TObj_`-based document, so
there is nothing this format's own storage/retrieval driver is ever asked to persist:
`BinTObjDrivers`, `BinTObjDrivers_DocumentRetrievalDriver`, `BinTObjDrivers_DocumentStorageDriver`,
`BinTObjDrivers_IntSparseArrayDriver`, `BinTObjDrivers_ModelDriver`, `BinTObjDrivers_ObjectDriver`,
`BinTObjDrivers_ReferenceDriver`, `BinTObjDrivers_XYZDriver`, `XmlTObjDrivers`,
`XmlTObjDrivers_DocumentRetrievalDriver`, `XmlTObjDrivers_DocumentStorageDriver`,
`XmlTObjDrivers_IntSparseArrayDriver`, `XmlTObjDrivers_ModelDriver`, `XmlTObjDrivers_ObjectDriver`,
`XmlTObjDrivers_ReferenceDriver`, `XmlTObjDrivers_XYZDriver`.

**Driver-table infrastructure (17).** The driver-table container (`ADriverTable`) and its own
bootstrap drivers (`TagSourceDriver`, `ReferenceDriver`, `DerivedDriver`) that every attribute-driver
package above registers into via `AddDrivers`; internal registration machinery for the driver
table, not a capability of its own: `BinMDF` and `BinMDF_ADriver`, `BinMDF_ADriverTable`,
`BinMDF_DerivedDriver`, `BinMDF_ReferenceDriver`, `BinMDF_StringIdMap`, `BinMDF_TagSourceDriver`,
`BinMDF_TypeADriverMap`, `BinMDF_TypeIdMap`; and `XmlMDF` and `XmlMDF_ADriver`,
`XmlMDF_ADriverTable`, `XmlMDF_DerivedDriver`, `XmlMDF_MapOfDriver`, `XmlMDF_ReferenceDriver`,
`XmlMDF_TagSourceDriver`, `XmlMDF_TypeADriverMap`.

**Stream primitives (19).** The low-level scalar/array/relocation-table read-write primitives
(ints, reals, strings, byte arrays, cross-reference relocation) every attribute driver above calls
to serialize its own attribute's fields; internal implementation of the wire format, not a
capability a caller reaches directly: `BinObjMgt_PByte`, `BinObjMgt_PChar`, `BinObjMgt_PExtChar`,
`BinObjMgt_PInteger`, `BinObjMgt_PReal`, `BinObjMgt_PShortReal`, `BinObjMgt_Persistent`,
`BinObjMgt_Position`, `BinObjMgt_RRelocationTable`, `BinObjMgt_SRelocationTable`, `XmlObjMgt`,
`XmlObjMgt_Array1`, `XmlObjMgt_DOMString`, `XmlObjMgt_Document`, `XmlObjMgt_Element`,
`XmlObjMgt_GP`, `XmlObjMgt_Persistent`, `XmlObjMgt_RRelocationTable`,
`XmlObjMgt_SRelocationTable`.

**Persistent schema and stream layer (98).** The persistent-object schema and type-binding layer
`TDocStd_Application::SaveAs`/`Open` (already wrapped, see the format-registration surface above)
walk internally to convert the OCAF label tree to and from a `Storage_Data`; never named or
configured by a caller. `Storage_` itself is the base this whole tier and `PCDM_`'s own drivers are
defined in terms of, #973's own reason for filing it in this lane. `ShapePersistent`,
`ShapePersistent_BRep`, `ShapePersistent_Geom`, `ShapePersistent_Geom2d`,
`ShapePersistent_Geom2d_Curve`, `ShapePersistent_Geom_Curve`, `ShapePersistent_Geom_Surface`,
`ShapePersistent_HArray1`, `ShapePersistent_HArray2`, `ShapePersistent_HSequence`,
`ShapePersistent_Poly`, `ShapePersistent_TopoDS`, `ShapePersistent_TriangleMode`;
`StdLPersistent`, `StdLPersistent_Collection`, `StdLPersistent_Data`, `StdLPersistent_Dependency`,
`StdLPersistent_Document`, `StdLPersistent_Function`, `StdLPersistent_HArray1`,
`StdLPersistent_HArray2`, `StdLPersistent_HString`, `StdLPersistent_NamedData`,
`StdLPersistent_Real`, `StdLPersistent_TreeNode`, `StdLPersistent_Value`,
`StdLPersistent_Variable`, `StdLPersistent_Void`, `StdLPersistent_XLink`;
`StdObjMgt_Attribute`, `StdObjMgt_MapOfInstantiators`, `StdObjMgt_Persistent`,
`StdObjMgt_ReadData`, `StdObjMgt_SharedObject`, `StdObjMgt_WriteData`; `StdObject_Location`,
`StdObject_Shape`, `StdObject_gp_Axes`, `StdObject_gp_Curves`, `StdObject_gp_Surfaces`,
`StdObject_gp_Trsfs`, `StdObject_gp_Vectors`; `StdPersistent`, `StdPersistent_DataXtd`,
`StdPersistent_DataXtd_Constraint`, `StdPersistent_DataXtd_PatternStd`, `StdPersistent_HArray1`,
`StdPersistent_Naming`, `StdPersistent_PPrsStd`, `StdPersistent_TopLoc`, `StdPersistent_TopoDS`;
`StdStorage`, `StdStorage_BacketOfPersistent`, `StdStorage_Data`, `StdStorage_HSequenceOfRoots`,
`StdStorage_HeaderData`, `StdStorage_MapOfRoots`, `StdStorage_MapOfTypes`, `StdStorage_Root`,
`StdStorage_RootData`, `StdStorage_SequenceOfRoots`, `StdStorage_TypeData`; and `Storage`,
`Storage_ArrayOfCallBack`, `Storage_ArrayOfSchema`, `Storage_BaseDriver`,
`Storage_BucketOfPersistent`, `Storage_CallBack`, `Storage_Data`, `Storage_DefaultCallBack`,
`Storage_Error`, `Storage_HArrayOfCallBack`, `Storage_HArrayOfSchema`, `Storage_HPArray`,
`Storage_HSeqOfRoot`, `Storage_HeaderData`, `Storage_InternalData`, `Storage_Macros`,
`Storage_MapOfCallBack`, `Storage_MapOfPers`, `Storage_OpenMode`, `Storage_PArray`,
`Storage_PType`, `Storage_Position`, `Storage_Root`, `Storage_RootData`, `Storage_Schema`,
`Storage_SeqOfRoot`, `Storage_SolveMode`, `Storage_StreamExtCharParityError`,
`Storage_StreamFormatError`, `Storage_StreamModeError`, `Storage_StreamReadError`,
`Storage_StreamTypeMismatchError`, `Storage_StreamUnknownTypeError`, `Storage_StreamWriteError`,
`Storage_TypeData`, `Storage_TypedCallBack`. `Storage_Schema` is worth naming individually: it is
the class behind `docs/thread-safety.md`'s #374 writeup (`Storage_Schema::ICurrentData`), recorded
there, not re-litigated here; see the carve-out entry below for the one respect in which that
writeup is now stale.

**Physical file layer (7).** The physical file open/read/write/seek primitives `Storage_`'s and
`PCDM_`'s own drivers open through to reach disk; selected by the format's own driver, never by the
caller: `FSD_BStream`, `FSD_Base64`, `FSD_BinaryFile`, `FSD_CmpFile`, `FSD_FStream`, `FSD_File`,
`FSD_FileHeader`.

**Plugin loader (4).** The GUID-to-factory resolver `CDF_Application` and every `*Drivers` package's
own `Factory()` static call internally to instantiate the right driver by format GUID; never
invoked by name from the bridge, which selects a format by calling `DefineFormat` directly instead
of through the plugin registry: `Plugin`, `Plugin_Failure`, `Plugin_Macro`,
`Plugin_MapOfFunctions`.

**XML DOM (24).** The XML DOM implementation the `Xml*` driver families and `XmlObjMgt_` parse and
write the on-disk XML persistence format through; internal implementation detail of the XML format,
not a capability a caller configures: `LDOMBasicString`, `LDOMParser`, `LDOMString`, `LDOM_Attr`,
`LDOM_BasicAttribute`, `LDOM_BasicElement`, `LDOM_BasicNode`, `LDOM_BasicText`,
`LDOM_CDATASection`, `LDOM_CharReference`, `LDOM_CharacterData`, `LDOM_Comment`,
`LDOM_DeclareSequence`, `LDOM_Document`, `LDOM_DocumentType`, `LDOM_Element`,
`LDOM_LDOMImplementation`, `LDOM_MemManager`, `LDOM_Node`, `LDOM_NodeList`, `LDOM_OSStream`,
`LDOM_Text`, `LDOM_XmlReader`, `LDOM_XmlWriter`.

**Package utility (1).** `UTL`: a bare package header, an all-static string/name utility class
OCCT's own OCAF persistence machinery calls internally; no instance, nothing a caller constructs.

**Cross-document reference bookkeeping (2).** `PCDM_Reference`, `PCDM_ReferenceIterator`: the
on-disk file-reference bookkeeping behind a cross-document `TDocStd_XLink`, the persistence-layer
counterpart of `CDM_Reference`/`CDM_ReferenceIterator`, which this file's Pass 3 section (#810)
already records as unexposed ("cross-document reference resolution is not exposed at all, only the
`TDocStd_XLink` attribute that records a link"). The same recorded gap, extended to its file-level
twin, not re-litigated here.

**Driver abstract bases and plumbing (14).** Abstract driver base classes and internal read/write
plumbing `TDocStd_Application::SaveAs`/`Open` (already wrapped) drives on the caller's behalf, the
same "abstract base"/"internal plumbing of an already-wrapped entry point" shape this file's Pass 3
section (#810) already uses throughout for `CDF_`/`CDM_`/`TDF_`'s own equivalents:
`PCDM_BaseDriverPointer`, `PCDM_DOMHeaderParser`, `PCDM_Document`, `PCDM_DriverError`,
`PCDM_ReadWriter`, `PCDM_ReadWriter_1`, `PCDM_Reader` (the abstract base every concrete
`*Drivers_DocumentRetrievalDriver` above subclasses), `PCDM_ReaderFilter`, `PCDM_RetrievalDriver`,
`PCDM_SequenceOfDocument`, `PCDM_SequenceOfReference`, `PCDM_StorageDriver` (the abstract base
every concrete `*Drivers_DocumentStorageDriver` above subclasses), `PCDM_TypeOfFileDriver`,
`PCDM_Writer`.

**Real capability gap, recorded as such (4 classes, a family-level gap, per #983's own framing).**
`StdDrivers`/`StdDrivers_DocumentRetrievalDriver` and `StdLDrivers`/
`StdLDrivers_DocumentRetrievalDriver`: `StdDrivers::DefineFormat`/`StdLDrivers::DefineFormat` have
the identical shape as the six format-registration entry points already wrapped, registering the
legacy `"MDTV-Standard"` and `"OCC-StdLite"` OCAF formats respectively (per their own header
comments), and neither is called anywhere in the bridge. Both are **read-only** at the OCCT level:
each package ships only a `*_DocumentRetrievalDriver`, no `*_DocumentStorageDriver` (confirmed
against the pinned headers), so even a caller who registered them could open an old-format document
but never save one in that format. This is the finding #983's own body asks this lane to look for:
a gap in the **format-registration surface**, not a per-driver gap. Narrow in practice, since
`"MDTV-Standard"`/`"OCC-StdLite"` predate the `Bin`/`Xml` (and their `L`ite successors) formats this
project already wraps, but real: importing an OCAF document written by pre-"lite" (pre-6.3-era)
OCCT-based software is not supported by `Document.defineFormat*()`/`loadOCAF(from:)`. Not scheduled
for wrapping here (a genuine but low-value, low-demand format most consumers will never meet, and
neither format can round-trip a document it opens, since neither ships a storage driver); recorded
so a future pass does not have to re-derive it.

**Over-coverage: two stale claims found and NOT fixed here, per this task's own carve-out.**
`Scripts/census-doc-occt-attribution.py --lane <this lane's 38 packages>` found 0 candidates (this
lane is barely documented outside the classes above, so the detector's `Class::Method` attribution
shape has almost nothing to check). The real finding came from reading `docs/thread-safety.md` by
hand, per #983's own pointer at the `#349`/`#353`/`#374` cluster it describes "in terms of carried
kernel patches." Both are genuine, and both are **filed rather than fixed**
([#1232](https://github.com/SecondMouseAU/OCCTSwift/issues/1232)), because a human is concurrently
building reproducers for open thread-safety issues in this exact file and touching it here would
collide with that work. Summarized: (1) the `### Resource_Manager::Debug /
Storage_Schema::ICurrentData() races, fixed (issue #374)` section, about `Storage_Schema`, a class
in this lane, still describes the FIRST, superseded version of that fix (an `ICurrentDataMutex()`
mutex), which `Scripts/patches/README.md`'s own `0016` entry and issue #518 (closed) record was
revised on upstream review to a `myCurrentData` per-instance field with no mutex at all, confirmed
directly against `Scripts/patches/0016-*.patch`'s current contents; (2) the `Scripts/tsan.supp`
suppression-policy paragraph, about `CDM_Application`/`CDM_MetaData` (Pass 3's lane, #810, not this
one, named here only because #983's own body points at the same three-issue cluster), cites the
`#353` metadata-map suppression as a "current example," but `tsan.supp` itself says that
suppression was removed in v1.15.11 once patch `0015` landed, and `0015` is in fact carried. See
#1232 for the full detail, including the exact stale text quoted and what the correction should
say.

### GD&T dimension accessors left unwrapped (#1004)

#1004 measured `XCAFDimTolObjects_DimensionObject`'s 42 public accessors against what
`Document.Dimension` exposes. The first PR wrapped the five that change what a dimension's number
means (`GetQualifier`/`HasQualifier`, `GetAngularQualifier`/`HasAngularQualifier`, `GetModifiers`,
`GetNbOfDecimalPlaces`, plus the two static `IsDimensionalLocation`/`IsDimensionalSize`
classifiers). The rest are listed here with the reason each was left, so the question is not
re-asked from scratch.

Every accessor below was measured against the pinned kernel in
[`Scripts/repro/1004-gdt-accessors/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/1004-gdt-accessors),
not read off a header comment.

| Accessor | Why it is not wrapped |
|---|---|
| `GetSemanticName` / `SetSemanticName` | **Absence is not representable, and the value is a marker string.** The semantic name is stored in the dimension label's own `TDataStd_Name`, which `XCAFDoc_DimTolTool::AddDimension()` initialises to the literal `"DGT:Dimension"`. `GetObject` reads that attribute back, so a dimension that never had a semantic name reports `"DGT:Dimension"` rather than nothing. `SetObject`'s `setString` helper returns early on a null handle, so the name also cannot be cleared once set. Wrapping it would surface OCCT's own table marker as if it were the caller's text. The same applies to `XCAFDoc_GeomTolerance` (`"DGT:Tolerance"`) and `XCAFDoc_Datum` (`"DGT:Datum"`). |
| `GetDirection` | **No presence predicate, and a fabricated vector.** `GetDirection(gp_Dir&)` returns `true` unconditionally (`XCAFDimTolObjects_DimensionObject.cxx:419-423`) and writes `myDir`, which the constructor never initialises; measured, an object that never had a direction reports `(1,0,0)`, the default-constructed `gp_Dir`. `XCAFDoc_Dimension::SetObject` stores the direction only for `DimensionType_Location_Oriented`, so even the round trip is type-conditional. Surfacing this would be exactly the fabricated-magnitude shape #609 exists to catch. |
| `GetPath` / `SetPath` | Returns a `TopoDS_Edge`, so it needs an `OCCTEdgeRef` on the read side and an edge argument on the write side. Worth wrapping, and it is the one omission here with real interpretive value, since `.locationWithPath` and `.sizeWithPath` cannot be read without it. Deferred rather than declined: it is a handle-lifetime change to the read struct, not a field. |
| `GetPlane` / `HasPlane`, `GetPointTextAttach` / `HasTextPoint` | The annotation plane and the text anchor are presentation placement, and both need `gp_Ax2` / `gp_Pnt` plumbing into a `Hashable` read struct. Both carry a real predicate, so they are wrappable correctly; deferred on proportion, not on correctness. |
| `GetPoint` / `HasPoint` / `IsPointConnection` / `GetConnectionAxis` / `GetConnectionName` and the five `*2` siblings | Ten accessors describing where a location dimension's two ends attach. They only mean anything together (the `IsPointConnection` flag decides whether the stored `gp_Ax2` is a bare point or a frame), so they want one modelled `Connection` type rather than ten fields. Deferred as a unit. |
| `GetPresentation` / `GetPresentationName` | The annotation's graphical presentation shape. Only STEP/XCAF readers populate it, and this package has no write path for one, so a wrapped read could only ever be tested against an imported fixture this repo does not carry. |
| `HasDescriptions` / `NbDescriptions` / `GetDescription` / `GetDescriptionName` | A parallel pair of string arrays, zero-indexed (measured: `GetDescription(0)` is the first entry, and an out-of-range index answers an empty string rather than throwing). Needs a count-plus-index bridge pair per array plus an `AddDescription` write path. Deferred on proportion. |
| `GetValues` / `SetValues` | The raw values array. `Dimension.Bounds` already mirrors it through OCCT's own predicates (#996), and exposing the array as well would give two spellings of one fact, which is the duplication #996 removed. |
| `SetType`, `SetValue`, `SetUpperBound`, `SetLowerBound`, `SetUpperTolValue`, `SetLowerTolValue`, `SetClassOfTolerance`, `AddModifier`, `RemoveDescription`, `SetPoint`, `SetPoint2`, `SetConnectionAxis`, `SetConnectionAxis2`, `SetConnectionName`, `SetConnectionName2`, `SetPresentation`, `AddDescription`, `SetPointTextAttach`, `SetPlane`, `SetDirection` | Mutators for the reads above. Each ships with its own read accessor when that one lands, per the rule in `GDTWrite.swift`: a read this package cannot author has no way to be tested against a document of our own. |
| `DumpJson` | OCCT's debug dump, not an API surface this wrapper exposes for any class. |

`XCAFDimTolObjects_GeomToleranceObject` (22 accessors, 2 exposed) and
`XCAFDimTolObjects_DatumObject` (21 accessors, 1 exposed) are #1004's second PR and are not
adjudicated here yet.

**One accessor is blocked by a kernel defect rather than by scope.** `XCAFDoc_Datum::GetObject`
builds the datum's point from the annotation plane's location array, and dereferences a null handle
when the datum has a point and no plane. That was an uncatchable SIGSEGV reachable from
`Document.datums`; it is #1022, with a reproducer in the same directory. The bridge now refuses
that datum instead of reading it (#1030), on both GD&T tables, so `Document.datums` omits it and
every datum mutator returns `false` for it. Wrapping the point accessor still waits on a kernel
carrying `Scripts/patches/0029-*`, because the guard prevents the crash and cannot recover the
stored point: the kernel returns the plane's X for any datum that has both.

### GD&T tolerance and datum accessors left unwrapped (#1004)

The sibling of the dimension section above, for `XCAFDimTolObjects_GeomToleranceObject` (22 public
accessors, 2 exposed before #1004) and `XCAFDimTolObjects_DatumObject` (21, 1 exposed). #1004's
second PR wrapped the semantics on both and left the geometry and presentation, each measured
against the pinned kernel in
[`Scripts/repro/1004-gdt-accessors/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/1004-gdt-accessors).

**Wrapped on `GeomTolerance`:** `GetTypeOfValue`, `GetMaterialRequirementModifier`,
`GetZoneModifier` with `GetValueOfZoneModifier`, `GetMaxValueModifier`, `GetModifiers`.
**Wrapped on `Datum`:** `GetPosition`, `GetModifiers`, `GetModifierWithValue`, `IsDatumTarget`,
`GetDatumTargetType`, `GetDatumTargetNumber`, `GetDatumTargetLength`, `GetDatumTargetWidth`,
`HasDatumTargetParams`.

| Accessor | Why it is not wrapped |
|---|---|
| `GetSemanticName` / `SetSemanticName` on both classes | Same defect as the dimension case above. `XCAFDoc_DimTolTool::AddGeomTolerance()` and `AddDatum()` initialise the new label's `TDataStd_Name` to `"DGT:Tolerance"` and `"DGT:Datum"`, and `GetObject` reads that same attribute back, so an unnamed entry reports the GD&T table's own marker string. Measured: `transcript.txt`'s part 2 rows. |
| `GetAffectedPlane` / `GetAffectedPlaneType` / `HasAffectedPlane` | `HasAffectedPlane()` is a real predicate and the type enum has only three members, so this one is wrappable correctly. It needs `gp_Pln` plumbing into a `Hashable` read struct, and the type without the plane would say which kind of plane the zone is qualified against while withholding the plane. Deferred as a unit rather than half-wrapped; this is the one `XCAFDimTolObjects` enum still unbound. |
| `GetAxis` / `HasAxis` on the tolerance, `GetDatumTargetAxis` on the datum | Both are `gp_Ax2` placements. The datum one has a write path here already (`setDatumTargetPlacement(at:location:normal:reference:length:width:)` sets it, because OCCT's three target setters share one presence flag and writing any of them alone reports the other two as present), but no read: reading it back wants the same `gp_Ax2` plumbing as the annotation planes, and is deferred with them. |
| `GetPlane` / `HasPlane`, `GetPoint` / `HasPoint`, `GetPointTextAttach` / `HasPointText` on both classes | Annotation placement, six accessors per class. Each carries a real predicate, so all are wrappable correctly; deferred on proportion, alongside the dimension class's identical group. |
| `GetPresentation` / `GetPresentationName` on both classes | The annotation's graphical presentation shape. Only STEP/XCAF readers populate it, and this package has no write path for one, so a wrapped read could only be tested against an imported fixture this repo does not carry. |
| `GetDatumTarget` / `SetDatumTarget(TopoDS_Shape)` | The `.area` target's own shape. `XCAFDoc_Datum::SetObject` stores it only for `DatumTargetType_Area` and takes the placement branch otherwise, so a wrapped read would answer `nil` for four of the five target types. It needs an `OCCTShapeRef` on the read side, the same handle-lifetime change `GetPath` needs on the dimension. Deferred with it. |
| `SetType`, `SetValue`, `SetName`, `AddModifier`, `SetAffectedPlane`, `SetAxis`, `SetPlane`, `SetPoint`, `SetPointTextAttach`, `SetPresentation`, `SetDatumTargetAxis` alone | Mutators for the reads above, or (for `AddModifier` and the lone axis setter) narrower spellings of a mutator that already ships. Each arrives with its own read accessor. |
| `DumpJson` on both | OCCT's debug dump, not an API surface this wrapper exposes for any class. |

### DimTolTool coverage: the linkage half is a real gap (#1021)

[#1021](https://github.com/SecondMouseAU/OCCTSwift/issues/1021) measured `XCAFDoc_DimTolTool` at 9 of 39
public methods reached, and asked for a decision rather than a wrap. Measured directly rather than
inherited from the sample: the bridge calls `Set`, `AddDimension`, `AddGeomTolerance`, `AddDatum`,
`SetDimension`, `SetGeomTolerance`, `GetDimensionLabels`, `GetGeomToleranceLabels` and
`GetDatumLabels`, and nothing else. Split three ways.

**A real gap: the reverse lookups and the datum-to-tolerance association.** `GetRefDimensionLabels`,
`GetRefGeomToleranceLabels`, `GetRefDatumLabel`, `GetRefShapeLabel`, `GetDatumOfTolerLabels`,
`GetDatumWithObjectOfTolerLabels`, `GetTolerOfDatumLabels`, `SetDatumToGeomTol`, the two `SetDatum`
overloads and `FindDatum`. These are what answer "which dimensions apply to this face" and "which
datums does this positional tolerance reference, in what order", and the second is what turns a
tolerance plus three datums into an `A|B|C` frame. `Document.dimensions` / `geomTolerances` /
`datums` are three flat sequences today with no edge between them and no edge to the geometry, so
this is the largest missing piece of the GD&T surface, larger than anything #1004 wrapped. Not
scheduled here.

**A deliberate omission: the legacy `XCAFDoc_DimTol` API.** `IsDimTol`, `GetDimTolLabels`, the two
`FindDimTol` overloads, the two `AddDimTol` overloads, `SetDimTol` and `GetDimTol` drive the
pre-AP242 kind/values/name/description model. That model *is* wrapped, through `XCAFDoc_DimTol`
directly (`OCCTDocumentSetDimTol`, `OCCTDocumentGetDimTolKind`, `OCCTDocumentGetDimTolName`,
`OCCTDocumentGetDimTolDescription`, `OCCTDocumentGetDimTolValues`), so routing it through the tool
as well would be a second spelling of one capability, which is what #377 exists to remove.

**Not a gap at all: the classifiers, the lock and the plumbing.** `IsDimension`,
`IsGeomTolerance` and `IsDatum` classify an arbitrary label; the bridge addresses entries by
position in the tool's own label sequence and never holds a label whose kind it does not already
know. `IsLocked` / `Lock` / `Unlock` are a GUI editing lock with no counterpart in a Swift value
API. `GetGDTPresentations` / `SetGDTPresentations` are the bulk form of the per-object presentation
shapes the table above already declines. `BaseLabel`, `ShapeTool`, `GetID`, `ID`, `DumpJson` and the
constructor are plumbing every wrapped OCAF attribute has and none exposes.

**On the metric itself.** #1021's own caveat holds here: the denominator counts `Set*` and
`DumpJson`, and 8 of the 30 unreached methods are the legacy model plus the plumbing, which no
coverage figure should have counted against this class. The row is worth acting on for the linkage
methods and for nothing else, which is the answer #1021 asked for.


### Pass 4a coverage audit: eight classes at 12-50% (#1021)

[#1021](https://github.com/SecondMouseAU/OCCTSwift/issues/1021) measured 8 OCCT classes with low
method-level coverage (12-50%) by the bridge. For each, the decision is recorded as **deliberate
omission** (by design, documented reason) or **unexamined gap** (not yet wrapped, could be).

| OCCT Class | Coverage | Verdict | Reason |
|------------|----------|---------|--------|
| `GeomPlate_BuildPlateSurface` | 12% (4/34) | **Deliberate omission** | Only the plate builder entry point (`Shape.fill` / `FillingSurface`) is exposed. The 30 unreached methods are internal builder state (`AddConstraint`/`Load` overloads, tolerance setters, `myTol2d`/`myTol3d`, `SetDegree`/`SetNbPtsOnCur`/`SetNbIter`, `SetContinuity`, error accessors `G0Error`/`G1Error`/`G2Error`). All are builder configuration knobs the Swift API hardcodes for `Shape.fill` defaults. Exposing them would mean a separate `PlateBuilder` type, which is a separate API design issue (#430). |
| `Plate_Plate` | 17% (4/23) | **Deliberate omission** | Only the solver entry point (`Plate_Plate::SolveTI` / `Solve`, `IsDone`, `Continuity`) is invoked by `NLPlate_NLPlate`. The 19 unreached methods include 9 `Load` overloads (constraint builders), `SetTol2d`/`SetTol3d`, `SetMaxDegree`, `SetMaxSegments`, `SetContinuity`, `GetTol2d`/`GetTol3d`, `GetMaxDegree`, `GetMaxSegments`, `GetContinuity`, `GetDegree`, `GetNbPtsOnCur`, `GetNbIter`, `GetTolerance`, `GetError`, `GetG0Error`/`G1Error`/`G2Error`. All are internal solver configuration. One gap recorded separately: `Plate_SampledCurveConstraint` is the one `Load` overload (of 9) the bridge never reaches (#1021, folded into `Plate_Plate` row). |
| `BRepFeat_Gluer` | 22% (2/9) | **Deliberate omission** | Only `Perform()` is called. The 7 unreached methods are `OpeType()`, `GlueSolid()`, `GlueShell()`, `GlueFace()`, `GlueWire()`, `GlueEdge()`, `GlueVertex()`. `OpeType()` is a read-only status getter the bridge does not surface (the Swift API returns the result shape directly). The `Glue*` methods are redundant entry points to the same `Perform()` logic. Not a capability gap. |
| `BRepFeat_MakeDPrism` | 23% (3/13) | **Deliberate omission** | Only `Perform()` is called (via `Shape.withPrism`). The 10 unreached methods are `SetOperation()`, `PerformThruNext()`, `PerformUntilEnd()`, `Perform(Radius, PFrom, PTo)`, `PerformBlind()`, `AddFace()`, `AddWire()`, `AddVertex()`, `AddEdge()`, `AddShape()`. All are legacy extent/face-selection entry points the Swift API does not expose (`withPrism` uses `BRepPrimAPI_MakePrism` + boolean, not `BRepFeat_MakeDPrism`). Recorded in #1047. |
| `XCAFDoc_DimTolTool` | 23% (9/39) | **Partial gap / deliberate** | Split three ways (see detailed section above): (1) **Real gap**: linkage methods (`GetRefDimensionLabels`, `GetRefGeomToleranceLabels`, `GetRefDatumLabel`, `GetRefShapeLabel`, `GetDatumOfTolerLabels`, `GetDatumWithObjectOfTolerLabels`, `GetTolerOfDatumLabels`, `SetDatumToGeomTol`, `SetDatum` overloads, `FindDatum`) — largest missing piece of GD&T surface. (2) **Deliberate**: legacy `XCAFDoc_DimTol` API (`IsDimTol`, `GetDimTolLabels`, `FindDimTol`, `AddDimTol`, `SetDimTol`, `GetDimTol`) — second spelling of `XCAFDoc_DimTol` wrapped directly. (3) **Not a gap**: classifiers/plumbing (`IsDimension`, `IsGeomTolerance`, `IsDatum`, `IsLocked`/`Lock`/`Unlock`, `GetGDTPresentations`/`SetGDTPresentations`, `BaseLabel`, `ShapeTool`, `GetID`, `ID`, `DumpJson`). |
| `GeomPlate_MakeApprox` | 33% (1/3) | **Deliberate omission** | Only `Perform()` is called. The 2 unreached methods are `GetMaxDegree()` and `GetNbPatches()`. Both are read-only getters for post-approximation metadata the Swift API does not surface (the approximator's internal patch count/degree). Not a capability gap. |
| `BRepMAT2d_BisectingLocus` | 45% (5/11) | **Deliberate omission** | Only `Compute()` is called (via `MedialAxis(of:)`). The 6 unreached methods are `LineIndex()`, `ASide()`, `BJoinType()`, `GetResult()`, `GetResult1()`, `GetResult2()`. `Compute()` is the single entry point the Swift API exposes (`bisector2D`); the rest are internal state getters. Not a capability gap. |
| `NLPlate_NLPlate` | 50% (6/12) | **Partial gap / deliberate** | (1) **Deliberate**: `Evaluate()`, `EvaluateDerivative()`, `GetDeformedPoint()`, `GetDeformedTangent()`, `GetDeformedNormal()`, `GetDeformedPosition()` are evaluator methods the Swift API does not expose directly — the bridge samples `Evaluate` on a grid and refits with `GeomAPI_PointsToBSplineSurface` (`Surface.nlPlateDeformed`), which is the intended API. (2) **Real gap**: `SetTolerance()`, `SetMaxDegree()`, `SetMaxSegments()`, `SetContinuity()`, `SetDegree()`, `GetDegree()`, `GetContinuity()`, `GetTolerance()`, `GetNbPatches()`, `GetMaxDegree()`, `GetMaxSegments()` — solver configuration methods the Swift API hardcodes. Exposing them would mean a `NLPlateBuilder` type, which is a separate API design issue. |

**On the metric.** #1021's caveat holds across all rows: the denominator counts `Set*` and
`DumpJson`, inflating the gap. The linkage methods in `XCAFDoc_DimTolTool` are the only actionable
gap; all other rows are deliberate omissions documented here.

### NLPlate deformation returns a refit BSpline (#1046)

`Surface.nlPlateDeformed` and its four siblings (`nlPlateDeformedG1`, `nlPlateDeformedG2`,
`nlPlateDeformedG3`, `nlPlateDeformedIncremental`) do not hand back the deformed surface itself.
`NLPlate_NLPlate` has no surface to hand back: it is an evaluator, and the only way out of it is
`Evaluate(uv)` a point at a time. The bridge samples that on a grid and fits the samples with
`GeomAPI_PointsToBSplineSurface`, so the result is a fresh approximation of the deformation, not
the input surface with a displacement applied to it.

Three consequences, all measured in
[`Scripts/repro/1049-nlplate-double-base/`](https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/1049-nlplate-double-base)
rather than reasoned about. The first is fixed; the second and third are not, and are recorded here
so the question is not re-asked from scratch.

- **The parametrisation is restored, by a linear knot map.** The fit lands on `[0, 1] x [0, 1]`,
  and the returned surface's knots are then mapped linearly onto the working domain the samples
  were taken over. Poles are untouched, so this changes the parametrisation and nothing about the
  geometry, and the `(u, v)` a constraint was written at addresses the same place on the result as
  it did on the input. Before this, a cylinder deformed at `u = pi/2` came back with that same
  `u = pi/2` outside the returned surface's own domain.
- **Periodicity is not restored.** A deformed cylinder comes back as a plain BSpline that does not
  close on itself. Restoring it would mean fitting a periodic surface, which
  `GeomAPI_PointsToBSplineSurface` does not offer, or building a `GeomPlate_Surface` and going
  through `GeomPlate_MakeApprox` instead. That second route is what the documentation used to
  claim already happened, and it was never implementable as written: `GeomPlate_MakeApprox` takes
  a `Handle(GeomPlate_Surface)`, which comes from `GeomPlate_BuildPlateSurface`, not from
  `NLPlate_NLPlate`.
- **The 20x20 sample grid is fixed, so `tolerance` describes a fit the caller cannot resolve.**
  Same family as #479 and #558. It shows on a cylinder: `NLPlate_NLPlate` hits the constraint
  target exactly, the fitted surface misses it by 13.5, and the worst deviation between the fit and
  the solver anywhere on the domain is 52.3. Twenty samples across a full turn of a radius-10
  cylinder cannot carry a plate whose own excursions reach 128.8. Exposing the grid size is a public
  API addition, so it waits for its own issue rather than riding this fix.

**The working domain itself is derived, not the input's own domain, whenever the input is
unbounded.** Each direction is taken from the input surface where the input bounds it, and from
the span of the constraint parameters padded by 10 where it does not. A plane bounds neither, so a
single constraint gives a 20-by-20 patch around it; a cylinder bounds `u` at `[0, 2pi]` and leaves
only `v` derived. The pad of 10 is a fixed number with no basis in the input's scale, which is a
real limitation for a model whose features are much larger or much smaller than that.

### Constraint Solver Infrastructure (Complete)

All priority items from the original gap analysis are now wrapped:

- **P1 Math solvers**: math_FunctionSetRoot, math_BissecNewton, math_BFGS, math_Powell, math_Matrix, math_SVD, math_Householder, math_PSO, math_GlobOptMin
- **P2 Batch evaluation**: GeomEval grid evaluators, EvalD0/D1/D2/D3 for curves and surfaces
- **P3 Adaptor classes**: Geom2dAdaptor_Curve, BRepAdaptor_Curve, BRepAdaptor_Surface exposed
- **P4 Geometry analysis**: GeomLProp, BRepLProp, GCPnts_AbscissaPoint, ShapeAnalysis
- **P5 Topology exploration**: TopExp_Explorer, BRep_Tool, TopTools maps
