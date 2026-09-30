//
//  OCCTBridge_Modeling_Misc.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Modeling.mm (#396/#819): Section builder, CellsBuilder, XCAFDoc, Bnd,
//  BRepPreviewAPI. Public C surface unchanged; imports the same OCCTBridge_Modeling.h every sibling
//  file does. No symbol changes, pure file move -- see Scripts/repro/396-modeling-mm-split/ for
//  how.
//

//
//  OCCTBridge_Modeling.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm, issue #99.
//
//  Drawing + Advanced Modeling + Surfaces & Curves cluster:
//
//  - 2D Drawing / HLR projection (HLRBRep_Algo + HLRToShape, generates the
//    visible / hidden / sharp / smooth / outline edge stacks)
//  - Advanced modeling (v0.8.0): pipe shells along path, draft angle,
//    thick solid offset, defeaturing, fillet variants
//  - Surfaces & Curves (v0.9.0): BSpline surface construction, surface-of-
//    revolution / extrusion, planar face from Geom_Plane, edge length /
//    abscissa parameter helpers
//
//  These three areas live in one TU because they share a common dependency
//  set (BRepBuilderAPI primitives + Geom_BSpline + gp + TColgp), and
//  splitting them three ways would force near-duplicate header includes
//  in each file.
//
//  Public C surface unchanged. No symbol changes, pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <HLRAlgo_Projector.hxx>

#include <BRep_Builder.hxx>
#include <BRepLib_FindSurface.hxx>
#include <BRepLib.hxx>
#include <Geom_Plane.hxx>
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepFill.hxx>
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <LocOpe_CSIntersector.hxx>
#include <LocOpe_PntFace.hxx>
#include <LocOpe_DPrism.hxx>
#include <LocOpe_FindEdges.hxx>
#include <LocOpe_FindEdgesInFace.hxx>
#include <LocOpe_LinearForm.hxx>
#include <LocOpe_Pipe.hxx>
#include <LocOpe_Prism.hxx>
#include <LocOpe_Revol.hxx>
#include <LocOpe_RevolutionForm.hxx>
#include <LocOpe_SplitShape.hxx>
#include <BRepLib_MakePolygon.hxx>
#include <BRepLib_MakeWire.hxx>
#include <BRepLib_MakeSolid.hxx>
#include <GC_MakeMirror.hxx>
#include <GC_MakeScale.hxx>
#include <GC_MakeTranslation.hxx>
#include <Geom_Transformation.hxx>
#include <BRepFill_AdvancedEvolved.hxx>
#include <BRepFill_CompatibleWires.hxx>
#include <BRepFill_Draft.hxx>
#include <BRepFill_Generator.hxx>
#include <BRepFill_OffsetWire.hxx>
#include <BRepFill_Pipe.hxx>
#include <ChFi2d_AnaFilletAlgo.hxx>
#include <ChFi2d_FilletAlgo.hxx>
#include <LocOpe_BuildShape.hxx>
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BOPAlgo_CellsBuilder.hxx>
#include <BOPAlgo_Splitter.hxx>
#include <BRepBuilderAPI_MakeShapeOnMesh.hxx>
#include <BRepLib_MakeEdge.hxx>
#include <BRepLib_MakeFace.hxx>
#include <BRepLib_MakeShell.hxx>
#include <BOPAlgo_Section.hxx>
#include <BRepFeat_Builder.hxx>
#include <Law_BSplineKnotSplitting.hxx>
#include <Law_Composite.hxx>
#include <BOPAlgo_BuilderFace.hxx>
#include <BOPAlgo_BuilderSolid.hxx>
#include <BOPAlgo_ShellSplitter.hxx>
#include <BOPAlgo_WireSplitter.hxx>
#include <BRepFeat_Gluer.hxx>
#include <BRepFeat_MakeCylindricalHole.hxx>
#include <BiTgte_Blend.hxx>
#include <BRepPreviewAPI_MakeBox.hxx>
#include <BRepTools_CopyModification.hxx>
#include <BRepTools_GTrsfModification.hxx>
#include <BRepTools_TrsfModification.hxx>
#include <BRepFill_Evolved.hxx>
#include <BRepFill_NSections.hxx>
#include <BRepFill_OffsetAncestors.hxx>
#include <BRepAlgo_AsDes.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepBuilderAPI_FindPlane.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepTools.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <HLRAppli_ReflectLines.hxx>
#include <HLRBRep_TypeOfResultingEdge.hxx>
#include <BRepFeat_Status.hxx>
#include <ChFi2d_ChamferAPI.hxx>
#include <ChFi2d_FilletAPI.hxx>
#include <FilletSurf_Builder.hxx>
#include <FilletSurf_StatusDone.hxx>
#include <FilletSurf_ErrorTypeStatus.hxx>
#include <FilletSurf_StatusType.hxx>
#include <IntTools_BeanFaceIntersector.hxx>
#include <LocOpe_Gluer.hxx>
#include <BOPAlgo_Tools.hxx>
#include <BOPTools_AlgoTools.hxx>
#include <BOPTools_AlgoTools3D.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_Context.hxx>
#include <IntTools_Curve.hxx>
#include <IntTools_EdgeEdge.hxx>
#include <IntTools_EdgeFace.hxx>
#include <IntTools_FaceFace.hxx>
#include <IntTools_FClass2d.hxx>
#include <IntTools_PntOn2Faces.hxx>
#include <IntTools_Range.hxx>
#include <IntTools_SequenceOfCommonPrts.hxx>
#include <IntTools_SequenceOfCurves.hxx>
#include <IntTools_SequenceOfPntOn2Faces.hxx>
#include <BRepOffset_Offset.hxx>
#include <BRepOffset_SimpleOffset.hxx>
#include <BRepTools_Modifier.hxx>
#include <BRepTools_NurbsConvertModification.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <LocOpe_BuildWires.hxx>
#include <LocOpe_CurveShapeIntersector.hxx>
#include <LocOpe_Spliter.hxx>
#include <LocOpe_WiresOnShape.hxx>
#include <Poly_Array1OfTriangle.hxx>
#include <Poly_Triangulation.hxx>
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <Standard_ErrorHandler.hxx> // OCC_CATCH_SIGNALS (issue #175)
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <BRepOffset.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_TransitionMode.hxx>
#include <BRepFeat_MakeRevolutionForm.hxx>
#include <BRepFeat_MakeDPrism.hxx>
#include <BRepFeat_MakeRevol.hxx>
#include <BRepFeat_MakePipe.hxx>
#include <BRepFeat_MakePrism.hxx>
#include <BRepFeat_SplitShape.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepAlgoAPI_BuilderAlgo.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepProj_Projection.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <GeomAbs_JoinType.hxx>
#include <BRepOffsetAPI_MakeEvolved.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <ShapeFix_Face.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_HArray1OfBoolean.hxx>
#include <BRepBndLib.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <ShapeFix_Solid.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <gp_Ax1.hxx>
#include <Bnd_Box.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <ShapeFix_FreeBounds.hxx>
#include <gp_Pnt2d.hxx>

#include <Geom_BSplineSurface.hxx>
#include <GCPnts_AbscissaPoint.hxx>

#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <TColgp_Array2OfPnt.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

// Additional includes gathered from throughout the original file (#396):
#include <HelixBRep_BuilderHelix.hxx>
#include <BRepPrimAPI_MakeWedge.hxx>
#include <BRepOffsetAPI_NormalProjection.hxx>
#include <BRepPrimAPI_MakeHalfSpace.hxx>
#include <BOPAlgo_MakePeriodic.hxx>
#include <BRepOffsetAPI_MakeDraft.hxx>
#include <BRepBuilderAPI_GTransform.hxx>
#include <gp_GTrsf.hxx>
#include <gp_Mat.hxx>
#include <BRepBuilderAPI_MakeShell.hxx>
#include <BRepOffset_MakeSimpleOffset.hxx>
#include <BRepOffsetAPI_MiddlePath.hxx>
#include <BRepLib_FuseEdges.hxx>
#include <BOPAlgo_MakerVolume.hxx>
#include <BOPAlgo_MakeConnected.hxx>
#include <BRepTools_Quilt.hxx>
#include <BRepPrimAPI_MakeRevolution.hxx>
#include <BRepFeat_MakeLinearForm.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepBuilderAPI_MakeShape.hxx>
#include <TopoDS_Iterator.hxx>
#include <functional>
#include <memory>
#include <BRepOffset_MakeOffset.hxx>
#include <ShapeFix_Shape.hxx>
#include <Law_Function.hxx>
#include <Law_Constant.hxx>
#include <Law_Linear.hxx>
#include <Law_S.hxx>
#include <Law_Interpol.hxx>
#include <Law_BSpline.hxx>
#include <Law_BSpFunc.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepFilletAPI_MakeFillet2d.hxx>
#include <GProp_PEquation.hxx>
#include <BRepOffsetAPI_FindContigousEdges.hxx>
#include <IntTools_Tools.hxx>
#include <BRepAlgo_Image.hxx>
#include <BRepAlgo_Loop.hxx>
#include <Draft_Modification.hxx>
#include <gce_MakeMirror.hxx>
#include <gce_MakeRotation.hxx>
#include <gce_MakeScale.hxx>
#include <gce_MakeTranslation.hxx>
#include <gce_MakeMirror2d.hxx>
#include <gce_MakeRotation2d.hxx>
#include <gce_MakeScale2d.hxx>
#include <gce_MakeTranslation2d.hxx>
#include <gce_MakeDir2d.hxx>
#include <Law_Interpolate.hxx>
#include <BRepFill_PipeShell.hxx>
#include <BRepFill_TransitionStyle.hxx>
#include <BRepAlgo_NormalProjection.hxx>
#include <BOPAlgo_GlueEnum.hxx>
#include <Convert_CompPolynomialToPoles.hxx>
#include <sstream>
#include <gp_Lin.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#import <XCAFDoc_ShapeTool.hxx>
#include <ChFiDS_ChamfMode.hxx>
#include <gp_Trsf2d.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepOffsetAPI_MakePipe.hxx>
#include <Message_ProgressIndicator.hxx>
#include <Message_ProgressRange.hxx>
#include <Message_ProgressScope.hxx>
#include <chrono>
#include <BOPAlgo_CheckResult.hxx>
#include <BOPAlgo_CheckStatus.hxx>
#include <TopTools_HSequenceOfShape.hxx>

// Shared private structs/helpers (#396): every one of the twelve split files gets this
// identical block, compiled independently per TU -- see this split's own README for why.

// OCCTBooleanHistory struct definition
struct OCCTBooleanHistory
{
  // Builder kept alive for the lifetime of the handle. unique_ptr because
  // BRepBuilderAPI_MakeShape carries large internal state and is not
  // safely copyable. Upcast from concrete Fuse / Cut / Common / Splitter.
  // Null when `prebuilt` is used instead (sewing / quilting / healing,
  // issue #327, those algorithms don't derive from BRepBuilderAPI_MakeShape).
  std::unique_ptr<BRepBuilderAPI_MakeShape> op;

  // The shapes the builder ran on. Retained because BRepTools_History's
  // template constructor needs the argument list to know which subshapes to
  // walk, and a type-erased BRepBuilderAPI_MakeShape cannot report its own
  // inputs. See OCCTBooleanHistoryAsBRepToolsHistory. Unused when `prebuilt`
  // is set.
  TopTools_ListOfShape args;

  // Already-complete history for algorithms that expose one natively
  // (BRepTools_ReShape::History(), used by sewing and healing) or that need
  // hand-built history (quilting). Set instead of `op`/`args`.
  Handle(BRepTools_History) prebuilt;

  OCCTBooleanHistory(std::unique_ptr<BRepBuilderAPI_MakeShape> theOp,
                     const TopTools_ListOfShape&               theArgs)
      : op(std::move(theOp)),
        args(theArgs)
  {
  }

  explicit OCCTBooleanHistory(const Handle(BRepTools_History)& thePrebuilt)
      : prebuilt(thePrebuilt)
  {
  }
};

struct OCCTLawFunction
{
  Handle(Law_Function) law;

  OCCTLawFunction() {}

  OCCTLawFunction(const Handle(Law_Function)& l)
      : law(l)
  {
  }
};

// MARK: - BRepOffsetAPI_MakeFilling (v0.45, converged onto BRepOffsetAPI_MakeFilling by #434)
//
// This used to hold a BRepFill_Filling directly. #430/#432 already routed every Add() here
// through occtFillingAddConstraint to dodge BRepFill_Filling's untrimmed-pcurve SIGSEGV, and
// #431 already reimplemented BRepOffsetAPI_MakeFilling's own correctly-bound construction
// (OCCTShapeFillMakeBuilder in OCCTBridge_Healing.mm) once for OCCTShapeFill*, so the two
// entry points were independently reaching for the same fix. #434 converges them: this struct
// now holds the same BRepOffsetAPI_MakeFilling that OCCTShapeFill* does, built through the same
// occtFillingMakeBuilder, and every Add() below shares occtFillingAddConstraint outright rather
// than each having its own copy of the same defensive logic. BRepOffsetAPI_MakeFilling is a
// thin forwarder to a private BRepFill_Filling (BRepOffsetAPI_MakeFilling.hxx), so nothing
// observable changes for a caller other than gaining BRepBuilderAPI_MakeShape's Generated()
// history for free.
struct OCCTFilling
{
  BRepOffsetAPI_MakeFilling filler;
  // #482: how many Add* calls were refused. A refused constraint is one that is NOT in
  // `filler`. Building over the rest would answer a different question than the caller
  // asked, so the refusal is sticky and OCCTFillingBuild fails on it. See the note there.
  int32_t refusedCount = 0;
};

struct OCCTCellsBuilder
{
  BOPAlgo_CellsBuilder builder;
};

// MARK: - IntTools EdgeEdge / EdgeFace / FaceFace / FClass2d (v0.70)
// MARK: - BOPAlgo BuilderFace / BuilderSolid / ShellSplitter / EdgesToWires / WiresToFaces (v0.70)
// MARK: - BOPTools NormalOnEdge / PointInFace / IsEmptyShape / IsOpenShell (v0.70)
// MARK: - BRepFill_OffsetAncestors (v0.79)
// --- BRepFill_OffsetAncestors ---
struct OffsetAncestorsOpaque
{
  BRepFill_OffsetWire      offsetWire;
  BRepFill_OffsetAncestors ancestors;
  bool                     isDone;
};

// MARK: - BRepFill_NSections (v0.79)
// --- BRepFill_NSections ---
struct NSectionsOpaque
{
  Handle(BRepFill_NSections) nsec;
};

struct OCCTBRepAlgoImage
{
  BRepAlgo_Image image;
};

struct OCCTPipeShell
{
  Handle(BRepFill_PipeShell) ps;
};

// OCCTSewing struct duplicated in main bridge (ODR-safe across TUs)
struct OCCTSewing
{
  BRepBuilderAPI_Sewing sewing;

  OCCTSewing(double tol)
      : sewing(tol)
  {
  }
};

struct OCCTNormalProjection
{
  BRepAlgo_NormalProjection proj;

  OCCTNormalProjection(const TopoDS_Shape& s)
      : proj(s)
  {
  }
};

struct OCCTAsDes
{
  Handle(BRepAlgo_AsDes) ad;

  OCCTAsDes()
      : ad(new BRepAlgo_AsDes())
  {
  }
};

struct OCCTWireBuilder
{
  BRepBuilderAPI_MakeWire maker;
};

struct OCCTThruSections
{
  BRepOffsetAPI_ThruSections* builder;
  int                         sectionCount = 0;
  // #910: neither IsDone() nor GetStatus() alone is a reliable "did the last Build() succeed"
  // signal on a REUSED builder. Build()'s two punctual-section WrongUsage returns skip
  // NotDone(), so IsDone() can stay stale-true past a failed rebuild; the AND-form here is what
  // Shape()/GeneratedFace() gate on instead of re-deriving it from OCCT state per call. Every
  // mutator (AddWire/AddVertex/the six Set*/CheckCompatibility calls) resets this to false, and
  // GeneratedFace() separately confirms the face it finds is still part of the current Shape()
  //, see each of those functions' own comments for why. OCCTSectionBuilder (below in this same
  // file) has the identical unfixed bug as of this writing (#916), not a working precedent to
  // copy, a sibling still waiting on this same fix.
  //
  // Bridge-side, not a kernel patch: the WrongUsage-skips-NotDone() gap IS a real upstream OCCT
  // defect (unlike #905/#913's memory corruption, nothing here is unsafe to leave as-is), but
  // fixing it in Build() wouldn't remove the need for this pattern. GetStatus()/IsDone() only
  // answer "what did the last Build() call decide", and this bridge's own contract is "did the
  // last build() call on THIS Swift-visible instance succeed", which needs bridge-owned state
  // regardless of how precise OCCT's own bookkeeping is.
  bool built = false;
};

struct OCCTUnifySameDomain
{
  ShapeUpgrade_UnifySameDomain* usd = nullptr;
  // #446: the algorithm rewrites its input, so it is given a private copy. The copier, and with
  // it the copy and the modifier's sub-shape map, is held for the builder's whole lifetime, not
  // just the copy call: that is what KeepShape needs to map the caller's own sub-shapes onto
  // their counterparts inside the copy. Costs one duplicated shape per live builder.
  BRepBuilderAPI_Copy copier;
};

struct OCCTFilletBuilder
{
  BRepFilletAPI_MakeFillet fillet;

  OCCTFilletBuilder(const TopoDS_Shape& s)
      : fillet(s)
  {
  }
};

struct OCCTChamferBuilder
{
  BRepFilletAPI_MakeChamfer chamfer;

  OCCTChamferBuilder(const TopoDS_Shape& s)
      : chamfer(s)
  {
  }
};

struct OCCTSectionBuilder
{
  BRepAlgoAPI_Section section;
  // #916, the same class of bug #910/PR #912 fixed for OCCTThruSections (predates it, though,
  // this struct's `built` field is the older of the two). Section() is a BOPAlgo-backed op:
  // AncestorFaceOn1/2 read intersection data (myDSFiller) that Build() never clears on a failed
  // rebuild, so `built` has to be tracked and reset explicitly rather than re-derived from
  // IsDone() per accessor. Set true only on success; every Build()/Init* path that invalidates
  // the last build's result must reset it to false, or a reused builder keeps answering from a
  // prior successful build (or worse: a builder that failed via a null/too-few-arguments early
  // return in BOPAlgo_PaveFiller::Init() leaves its PaveFiller's myDS unset, and
  // HasAncestorFaceOn1/2 dereferencing it uncatchably SIGSEGVs, not just returns stale data).
  bool built;

  OCCTSectionBuilder()
      : section(),
        built(false)
  {
  }

  OCCTSectionBuilder(const TopoDS_Shape& s1, const TopoDS_Shape& s2)
      : section(s1, s2, false),
        built(false)
  {
  }
};

// Wall-clock watchdog: asks the BOP to stop once a deadline passes. OCCT's
// BRepAlgoAPI_*::Build(range) polls UserBreak() at scope boundaries and leaves
// IsDone() == false when it trips, so a pathological operand that would
// otherwise spin forever (#206: self-intersecting B-spline loft) returns
// promptly instead of hanging. Verified to interrupt the real #206 operands.
class OCCTBoolTimeoutBreaker : public Message_ProgressIndicator
{
public:
  explicit OCCTBoolTimeoutBreaker(double seconds)
      : myDeadline(std::chrono::steady_clock::now()
                   + std::chrono::duration_cast<std::chrono::steady_clock::duration>(
                     std::chrono::duration<double>(seconds)))
  {
  }

  Standard_Boolean UserBreak() override
  {
    if (std::chrono::steady_clock::now() >= myDeadline)
    {
      myTripped = true;
      return Standard_True;
    }
    return Standard_False;
  }

  void Show(const Message_ProgressScope&, const Standard_Boolean) override {}

  bool tripped() const { return myTripped; } // deadline was hit at least once

  bool deadlinePassed() const { return std::chrono::steady_clock::now() >= myDeadline; }

  DEFINE_STANDARD_RTTI_INLINE(OCCTBoolTimeoutBreaker, Message_ProgressIndicator)
private:
  std::chrono::steady_clock::time_point myDeadline;
  bool                                  myTripped = false;
};

OCCTShapeRef* OCCTShapeSplitByPlane(OCCTShapeRef shape,
                                    double       planeX,
                                    double       planeY,
                                    double       planeZ,
                                    double       normalX,
                                    double       normalY,
                                    double       normalZ,
                                    int32_t*     outCount)
{
  if (!shape || !outCount)
    return nullptr;
  *outCount = 0;

  try
  {
    // Create plane
    gp_Pnt pnt(planeX, planeY, planeZ);
    gp_Dir normal(normalX, normalY, normalZ);
    gp_Pln plane(pnt, normal);

    // Create a large face from the plane for cutting
    // Get shape bounds to size the cutting plane
    Bnd_Box bounds;
    BRepBndLib::Add(shape->shape, bounds);
    double xmin, ymin, zmin, xmax, ymax, zmax;
    bounds.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    double size = std::sqrt((xmax - xmin) * (xmax - xmin) + (ymax - ymin) * (ymax - ymin)
                            + (zmax - zmin) * (zmax - zmin))
                  * 2;

    BRepBuilderAPI_MakeFace makeFace(plane, -size, size, -size, size);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Shape planeFace = makeFace.Face();

    // Use splitter
    BRepAlgoAPI_Splitter splitter;

    TopTools_ListOfShape arguments;
    arguments.Append(shape->shape);
    splitter.SetArguments(arguments);

    TopTools_ListOfShape tools;
    tools.Append(planeFace);
    splitter.SetTools(tools);

    splitter.Build();
    if (!splitter.IsDone())
      return nullptr;

    TopoDS_Shape result = splitter.Shape();
    if (result.IsNull())
      return nullptr;

    // Extract solids from result
    std::vector<TopoDS_Shape> solids;
    for (TopExp_Explorer exp(result, TopAbs_SOLID); exp.More(); exp.Next())
    {
      solids.push_back(exp.Current());
    }

    if (solids.empty())
    {
      for (TopExp_Explorer exp(result, TopAbs_SHELL); exp.More(); exp.Next())
      {
        solids.push_back(exp.Current());
      }
    }

    if (solids.empty())
    {
      solids.push_back(result);
    }

    *outCount            = static_cast<int32_t>(solids.size());
    OCCTShapeRef* shapes = new OCCTShapeRef[*outCount];
    for (int32_t i = 0; i < *outCount; i++)
    {
      shapes[i] = new OCCTShape(solids[i]);
    }

    return shapes;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *outCount = 0;
    return nullptr;
  }
}

OCCTCellsBuilderRef OCCTCellsBuilderCreate(const OCCTShapeRef* shapes, int32_t count)
{
  if (!shapes || count <= 0)
    return nullptr;
  try
  {
    auto* cb    = new OCCTCellsBuilder();
    int   added = 0;
    for (int32_t i = 0; i < count; i++)
    {
      if (shapes[i] && !shapes[i]->shape.IsNull())
      {
        cb->builder.AddArgument(shapes[i]->shape);
        added++;
      }
    }
    // Need at least one valid shape to partition
    if (added == 0)
    {
      delete cb;
      return nullptr;
    }
    cb->builder.Perform();
    if (cb->builder.HasErrors())
    {
      delete cb;
      return nullptr;
    }
    return cb;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTCellsBuilderRelease(OCCTCellsBuilderRef builder)
{
  delete builder;
}

void OCCTCellsBuilderAddAllToResult(OCCTCellsBuilderRef builder, int32_t material)
{
  if (!builder)
    return;
  try
  {
    builder->builder.AddAllToResult(material, true);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTCellsBuilderRemoveAllFromResult(OCCTCellsBuilderRef builder)
{
  if (!builder)
    return;
  try
  {
    builder->builder.RemoveAllFromResult();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTCellsBuilderRemoveInternalBoundaries(OCCTCellsBuilderRef builder)
{
  if (!builder)
    return;
  try
  {
    builder->builder.RemoveInternalBoundaries();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

OCCTShapeRef OCCTCellsBuilderGetResult(OCCTCellsBuilderRef builder)
{
  if (!builder)
    return nullptr;
  try
  {
    TopoDS_Shape result = builder->builder.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTCellsBuilderAddToResultSelective(OCCTCellsBuilderRef builder,
                                          const OCCTShapeRef* takeShapes,
                                          int32_t             takeCount,
                                          const OCCTShapeRef* avoidShapes,
                                          int32_t             avoidCount,
                                          int32_t             material,
                                          bool                update)
{
  if (!builder)
    return;
  try
  {
    NCollection_List<TopoDS_Shape> take, avoid;
    for (int32_t i = 0; i < takeCount; i++)
    {
      if (takeShapes[i])
        take.Append(takeShapes[i]->shape);
    }
    for (int32_t i = 0; i < avoidCount; i++)
    {
      if (avoidShapes[i])
        avoid.Append(avoidShapes[i]->shape);
    }
    builder->builder.AddToResult(take, avoid, material, update);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTCellsBuilderRemoveFromResult(OCCTCellsBuilderRef builder,
                                      const OCCTShapeRef* takeShapes,
                                      int32_t             takeCount,
                                      const OCCTShapeRef* avoidShapes,
                                      int32_t             avoidCount)
{
  if (!builder)
    return;
  try
  {
    NCollection_List<TopoDS_Shape> take, avoid;
    for (int32_t i = 0; i < takeCount; i++)
    {
      if (takeShapes[i])
        take.Append(takeShapes[i]->shape);
    }
    for (int32_t i = 0; i < avoidCount; i++)
    {
      if (avoidShapes[i])
        avoid.Append(avoidShapes[i]->shape);
    }
    builder->builder.RemoveFromResult(take, avoid);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

OCCTShapeRef OCCTCellsBuilderGetAllParts(OCCTCellsBuilderRef builder)
{
  if (!builder)
    return nullptr;
  try
  {
    const TopoDS_Shape& parts = builder->builder.GetAllParts();
    if (parts.IsNull())
      return nullptr;
    return new OCCTShape{parts};
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTCellsBuilderMakeContainers(OCCTCellsBuilderRef builder)
{
  if (!builder)
    return;
  try
  {
    builder->builder.MakeContainers();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

OCCTShapeRef _Nullable OCCTPreviewBox(double dx, double dy, double dz)
{
  try
  {
    BRepPreviewAPI_MakeBox preview;
    preview.Init(dx, dy, dz);
    preview.Build();
    if (!preview.IsDone())
      return nullptr;
    TopoDS_Shape result = preview.Shape();
    if (result.IsNull())
      return nullptr;
    auto* ref  = new OCCTShape();
    ref->shape = result;
    return ref;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTDocumentShapeToolIsFree(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return false;
  try
  {
    TDF_Label lab = doc->getLabel(labelId);
    if (lab.IsNull())
      return false;
    return XCAFDoc_ShapeTool::IsFree(lab);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentShapeToolIsSimpleShape(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return false;
  try
  {
    TDF_Label lab = doc->getLabel(labelId);
    if (lab.IsNull())
      return false;
    return XCAFDoc_ShapeTool::IsSimpleShape(lab);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentShapeToolIsComponent(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return false;
  try
  {
    TDF_Label lab = doc->getLabel(labelId);
    if (lab.IsNull())
      return false;
    return XCAFDoc_ShapeTool::IsComponent(lab);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentShapeToolIsCompound(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return false;
  try
  {
    TDF_Label lab = doc->getLabel(labelId);
    if (lab.IsNull())
      return false;
    return XCAFDoc_ShapeTool::IsCompound(lab);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentShapeToolIsSubShape(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return false;
  try
  {
    TDF_Label lab = doc->getLabel(labelId);
    if (lab.IsNull())
      return false;
    return XCAFDoc_ShapeTool::IsSubShape(lab);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTDocumentShapeToolIsExternRef(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return false;
  try
  {
    TDF_Label lab = doc->getLabel(labelId);
    if (lab.IsNull())
      return false;
    return XCAFDoc_ShapeTool::IsExternRef(lab);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int32_t OCCTDocumentShapeToolGetUsers(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return 0;
  try
  {
    TDF_Label lab = doc->getLabel(labelId);
    if (lab.IsNull())
      return 0;
    NCollection_Sequence<TDF_Label> users;
    return (int32_t)XCAFDoc_ShapeTool::GetUsers(lab, users);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

void OCCTDocumentShapeToolComputeShapes(OCCTDocumentRef doc, int64_t labelId)
{
  if (!doc)
    return;
  try
  {
    auto      shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->doc->Main());
    TDF_Label lab       = doc->getLabel(labelId);
    if (lab.IsNull())
      return;
    shapeTool->ComputeShapes(lab);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

int32_t OCCTDocumentShapeToolNbComponents(OCCTDocumentRef doc, int64_t labelId, bool getSubChildren)
{
  if (!doc)
    return 0;
  try
  {
    TDF_Label lab = doc->getLabel(labelId);
    if (lab.IsNull())
      return 0;
    return (int32_t)XCAFDoc_ShapeTool::NbComponents(lab, getSubChildren);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

OCCTSectionBuilderRef OCCTSectionBuilderCreate(void)
{
  try
  {
    return new OCCTSectionBuilder();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTSectionBuilderRef OCCTSectionBuilderCreateFromShapes(OCCTShapeRef shape1, OCCTShapeRef shape2)
{
  if (!shape1 || !shape2)
    return nullptr;
  try
  {
    return new OCCTSectionBuilder(shape1->shape, shape2->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTSectionBuilderRelease(OCCTSectionBuilderRef builder)
{
  delete builder;
}

void OCCTSectionBuilderInit1Shape(OCCTSectionBuilderRef builder, OCCTShapeRef shape)
{
  if (!builder || !shape)
    return;
  try
  {
    builder->section.Init1(shape->shape);
    builder->built = false;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTSectionBuilderInit1Plane(OCCTSectionBuilderRef builder,
                                  double                a,
                                  double                b,
                                  double                c,
                                  double                d)
{
  if (!builder)
    return;
  try
  {
    gp_Pln plane(a, b, c, d);
    builder->section.Init1(plane);
    builder->built = false;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTSectionBuilderInit1Surface(OCCTSectionBuilderRef builder, OCCTSurfaceRef surface)
{
  if (!builder || !surface || surface->surface.IsNull())
    return;
  try
  {
    builder->section.Init1(surface->surface);
    builder->built = false;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTSectionBuilderInit2Shape(OCCTSectionBuilderRef builder, OCCTShapeRef shape)
{
  if (!builder || !shape)
    return;
  try
  {
    builder->section.Init2(shape->shape);
    builder->built = false;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTSectionBuilderInit2Plane(OCCTSectionBuilderRef builder,
                                  double                a,
                                  double                b,
                                  double                c,
                                  double                d)
{
  if (!builder)
    return;
  try
  {
    gp_Pln plane(a, b, c, d);
    builder->section.Init2(plane);
    builder->built = false;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTSectionBuilderInit2Surface(OCCTSectionBuilderRef builder, OCCTSurfaceRef surface)
{
  if (!builder || !surface || surface->surface.IsNull())
    return;
  try
  {
    builder->section.Init2(surface->surface);
    builder->built = false;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTSectionBuilderSetApproximation(OCCTSectionBuilderRef builder, bool approx)
{
  if (!builder)
    return;
  try
  {
    builder->section.Approximation(approx);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTSectionBuilderComputePCurveOn1(OCCTSectionBuilderRef builder, bool compute)
{
  if (!builder)
    return;
  try
  {
    builder->section.ComputePCurveOn1(compute);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTSectionBuilderComputePCurveOn2(OCCTSectionBuilderRef builder, bool compute)
{
  if (!builder)
    return;
  try
  {
    builder->section.ComputePCurveOn2(compute);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

OCCTShapeRef OCCTSectionBuilderBuild(OCCTSectionBuilderRef builder)
{
  if (!builder)
    return nullptr;
  try
  {
    builder->section.Build();
    // #916: a failed rebuild must clear `built`, not just skip setting it, see the struct's
    // own comment. Without this, a builder that already built successfully once keeps
    // AncestorFaceOn1/2 answering (or, worse, uncatchably SIGSEGVing, measured, not assumed:
    // see Scripts/repro/916-sectionbuilder-built-flag-stale/) past a build that failed.
    if (!builder->section.IsDone())
    {
      builder->built = false;
      return nullptr;
    }
    builder->built = true;
    return new OCCTShape{builder->section.Shape()};
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    builder->built = false;
    return nullptr;
  }
}

OCCTShapeRef OCCTSectionBuilderAncestorFaceOn1(OCCTSectionBuilderRef builder, OCCTShapeRef edge)
{
  if (!builder || !edge || !builder->built)
    return nullptr;
  try
  {
    TopoDS_Shape face;
    if (builder->section.HasAncestorFaceOn1(edge->shape, face))
    {
      return new OCCTShape{face};
    }
    return nullptr;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTShapeRef OCCTSectionBuilderAncestorFaceOn2(OCCTSectionBuilderRef builder, OCCTShapeRef edge)
{
  if (!builder || !edge || !builder->built)
    return nullptr;
  try
  {
    TopoDS_Shape face;
    if (builder->section.HasAncestorFaceOn2(edge->shape, face))
    {
      return new OCCTShape{face};
    }
    return nullptr;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}
