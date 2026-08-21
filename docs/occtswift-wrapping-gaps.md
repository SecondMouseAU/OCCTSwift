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
  `GCE2d_MakeSegment`: but **left it unrenamed**: that file is grandfathered on
  `Scripts/style-manifest-bridge.txt`, and `check-style-manifest.py` mechanically requires bringing
  the *whole* file into `clang-format` compliance (a ~24,000-line diff) the moment any line in it
  changes, the same situation #917 already tracks (deferred from PR #912). The rename is
  behavior-identical (the deprecated name is literally a type alias for the one it would become) and
  is noted on #917 to land with that file's eventual compliance sweep, not forced in here. So one
  `GCE2d_*` reference remains in the bridge as of this entry; current docs (outside
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
