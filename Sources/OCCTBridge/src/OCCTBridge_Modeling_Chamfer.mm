//
//  OCCTBridge_Modeling_Chamfer.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Modeling.mm (#396/#819): ChFi2d, ChFiDS, ChFi3d, ChamferBuilder.
//  Public C surface unchanged; imports the same OCCTBridge_Modeling.h every sibling file does.
//  No symbol changes, pure file move -- see Scripts/repro/396-modeling-mm-split/ for how.
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

// #794: shared helper for ChamferBuilder history queries (Generated/Modified)
static int32_t occtChamferBuilderHistoryQuery(
  OCCTChamferBuilderRef builder,
  OCCTShapeRef          shape,
  OCCTShapeRef**        outShapes,
  const TopTools_ListOfShape& (BRepFilletAPI_MakeChamfer::*query)(const TopoDS_Shape&))
{
  if (!builder || !shape || !outShapes)
    return 0;
  *outShapes = nullptr;
  try
  {
    const TopTools_ListOfShape& list  = (builder->chamfer.*query)(shape->shape);
    int32_t                     count = static_cast<int32_t>(list.Size());
    if (count == 0)
      return 0;
    *outShapes = (OCCTShapeRef*)malloc(count * sizeof(OCCTShapeRef));
    int32_t i  = 0;
    for (auto it = list.cbegin(); it != list.cend(); ++it, ++i)
    {
      (*outShapes)[i] = new OCCTShape{*it};
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

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

OCCTAnaFilletResult OCCTChFi2dAnaFillet(OCCTShapeRef edge1,
                                        OCCTShapeRef edge2,
                                        double       planeOx,
                                        double       planeOy,
                                        double       planeOz,
                                        double       planeNx,
                                        double       planeNy,
                                        double       planeNz,
                                        double       radius)
{
  OCCTAnaFilletResult result = {};
  if (!edge1 || !edge2)
    return result;
  try
  {
    // #975: the same edge extraction OCCTChFi2dFilletAlgo above uses. See OCCTBridge_Internal.h.
    TopoDS_Edge e1 = occtEdgeAt(edge1->shape, 0);
    TopoDS_Edge e2 = occtEdgeAt(edge2->shape, 0);
    if (e1.IsNull() || e2.IsNull())
      return result;

    gp_Pln plane(gp_Pnt(planeOx, planeOy, planeOz), gp_Dir(planeNx, planeNy, planeNz));
    ChFi2d_AnaFilletAlgo fillet(e1, e2, plane);
    if (!fillet.Perform(radius))
      return result;

    TopoDS_Edge re1, re2;
    TopoDS_Edge filletEdge = fillet.Result(re1, re2);
    if (filletEdge.IsNull())
      return result;

    result.success     = true;
    auto* filletShape  = new OCCTShape();
    filletShape->shape = filletEdge;
    result.fillet      = filletShape;

    auto* e1Shape  = new OCCTShape();
    e1Shape->shape = re1;
    result.edge1   = e1Shape;

    auto* e2Shape  = new OCCTShape();
    e2Shape->shape = re2;
    result.edge2   = e2Shape;

    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return result;
  }
}

OCCTShapeRef _Nullable OCCTChFi2dAddFillet(OCCTShapeRef _Nonnull face,
                                           int32_t vertexIndex,
                                           double  radius)
{
  try
  {
    const TopoDS_Face& f = TopoDS::Face(face->shape);
    ChFi2d_Builder     builder(f);

    TopTools_IndexedMapOfShape vertexMap;
    TopExp::MapShapes(f, TopAbs_VERTEX, vertexMap);
    int32_t idx = vertexIndex + 1;
    if (idx < 1 || idx > vertexMap.Extent())
      return nullptr;
    TopoDS_Vertex v = TopoDS::Vertex(vertexMap(idx));

    builder.AddFillet(v, radius);
    if (builder.Status() != ChFi2d_IsDone)
      return nullptr;
    TopoDS_Face result = builder.Result();
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

OCCTShapeRef _Nullable OCCTChFi2dAddChamfer(OCCTShapeRef _Nonnull face,
                                            int32_t edge1Index,
                                            int32_t edge2Index,
                                            double  d1,
                                            double  d2)
{
  try
  {
    const TopoDS_Face& f = TopoDS::Face(face->shape);
    ChFi2d_Builder     builder(f);

    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(f, TopAbs_EDGE, edgeMap);
    int32_t idx1 = edge1Index + 1;
    int32_t idx2 = edge2Index + 1;
    if (idx1 < 1 || idx1 > edgeMap.Extent())
      return nullptr;
    if (idx2 < 1 || idx2 > edgeMap.Extent())
      return nullptr;
    TopoDS_Edge e1 = TopoDS::Edge(edgeMap(idx1));
    TopoDS_Edge e2 = TopoDS::Edge(edgeMap(idx2));

    builder.AddChamfer(e1, e2, d1, d2);
    if (builder.Status() != ChFi2d_IsDone)
      return nullptr;
    TopoDS_Face result = builder.Result();
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

OCCTShapeRef _Nullable OCCTChFi2dAddChamferAngle(OCCTShapeRef _Nonnull face,
                                                 int32_t edgeIndex,
                                                 int32_t vertexIndex,
                                                 double  distance,
                                                 double  angle)
{
  try
  {
    const TopoDS_Face& f = TopoDS::Face(face->shape);
    ChFi2d_Builder     builder(f);

    TopTools_IndexedMapOfShape edgeMap, vertexMap;
    TopExp::MapShapes(f, TopAbs_EDGE, edgeMap);
    TopExp::MapShapes(f, TopAbs_VERTEX, vertexMap);
    int32_t ei = edgeIndex + 1;
    int32_t vi = vertexIndex + 1;
    if (ei < 1 || ei > edgeMap.Extent())
      return nullptr;
    if (vi < 1 || vi > vertexMap.Extent())
      return nullptr;
    TopoDS_Edge   e = TopoDS::Edge(edgeMap(ei));
    TopoDS_Vertex v = TopoDS::Vertex(vertexMap(vi));

    builder.AddChamfer(e, v, distance, angle);
    if (builder.Status() != ChFi2d_IsDone)
      return nullptr;
    TopoDS_Face result = builder.Result();
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

OCCTShapeRef _Nullable OCCTChFi2dModifyFillet(OCCTShapeRef _Nonnull originalFace,
                                              OCCTShapeRef _Nonnull modifiedFace,
                                              int32_t filletEdgeIndex,
                                              double  newRadius)
{
  try
  {
    const TopoDS_Face& origF = TopoDS::Face(originalFace->shape);
    const TopoDS_Face& modF  = TopoDS::Face(modifiedFace->shape);
    ChFi2d_Builder     builder;
    builder.Init(origF, modF);

    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(modF, TopAbs_EDGE, edgeMap);
    int32_t idx = filletEdgeIndex + 1;
    if (idx < 1 || idx > edgeMap.Extent())
      return nullptr;
    TopoDS_Edge filletEdge = TopoDS::Edge(edgeMap(idx));

    builder.ModifyFillet(filletEdge, newRadius);
    if (builder.Status() != ChFi2d_IsDone)
      return nullptr;
    TopoDS_Face result = builder.Result();
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

OCCTShapeRef _Nullable OCCTChFi2dRemoveFillet(OCCTShapeRef _Nonnull originalFace,
                                              OCCTShapeRef _Nonnull modifiedFace,
                                              int32_t filletEdgeIndex)
{
  try
  {
    const TopoDS_Face& origF = TopoDS::Face(originalFace->shape);
    const TopoDS_Face& modF  = TopoDS::Face(modifiedFace->shape);
    ChFi2d_Builder     builder;
    builder.Init(origF, modF);

    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(modF, TopAbs_EDGE, edgeMap);
    int32_t idx = filletEdgeIndex + 1;
    if (idx < 1 || idx > edgeMap.Extent())
      return nullptr;
    TopoDS_Edge filletEdge = TopoDS::Edge(edgeMap(idx));

    builder.RemoveFillet(filletEdge);
    if (builder.Status() != ChFi2d_IsDone)
      return nullptr;
    TopoDS_Face result = builder.Result();
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

OCCTShapeRef _Nullable OCCTChFi2dRemoveChamfer(OCCTShapeRef _Nonnull originalFace,
                                               OCCTShapeRef _Nonnull modifiedFace,
                                               int32_t chamferEdgeIndex)
{
  try
  {
    const TopoDS_Face& origF = TopoDS::Face(originalFace->shape);
    const TopoDS_Face& modF  = TopoDS::Face(modifiedFace->shape);
    ChFi2d_Builder     builder;
    builder.Init(origF, modF);

    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(modF, TopAbs_EDGE, edgeMap);
    int32_t idx = chamferEdgeIndex + 1;
    if (idx < 1 || idx > edgeMap.Extent())
      return nullptr;
    TopoDS_Edge chamferEdge = TopoDS::Edge(edgeMap(idx));

    builder.RemoveChamfer(chamferEdge);
    if (builder.Status() != ChFi2d_IsDone)
      return nullptr;
    TopoDS_Face result = builder.Result();
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

OCCTChamfer2DResult OCCTChFi2dChamferEdges(OCCTShapeRef _Nonnull edge1,
                                           OCCTShapeRef _Nonnull edge2,
                                           double d1,
                                           double d2)
{
  OCCTChamfer2DResult result = {nullptr, nullptr, nullptr};
  try
  {
    TopoDS_Edge       e1 = TopoDS::Edge(edge1->shape);
    TopoDS_Edge       e2 = TopoDS::Edge(edge2->shape);
    ChFi2d_ChamferAPI chamfer(e1, e2);
    if (!chamfer.Perform())
      return result;
    TopoDS_Edge me1, me2;
    TopoDS_Edge chamferEdge = chamfer.Result(me1, me2, d1, d2);
    if (chamferEdge.IsNull())
      return result;
    result.chamferEdge   = new OCCTShape(chamferEdge);
    result.modifiedEdge1 = new OCCTShape(me1);
    result.modifiedEdge2 = new OCCTShape(me2);
    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return result;
  }
}

OCCTFillet2DResult OCCTChFi2dFilletEdges(OCCTShapeRef _Nonnull edge1,
                                         OCCTShapeRef _Nonnull edge2,
                                         double planeOx,
                                         double planeOy,
                                         double planeOz,
                                         double planeNx,
                                         double planeNy,
                                         double planeNz,
                                         double radius,
                                         double nearX,
                                         double nearY,
                                         double nearZ)
{
  OCCTFillet2DResult result = {nullptr, nullptr, nullptr, 0};
  try
  {
    TopoDS_Edge      e1 = TopoDS::Edge(edge1->shape);
    TopoDS_Edge      e2 = TopoDS::Edge(edge2->shape);
    gp_Pln           plane(gp_Pnt(planeOx, planeOy, planeOz), gp_Dir(planeNx, planeNy, planeNz));
    ChFi2d_FilletAPI fillet(e1, e2, plane);
    if (!fillet.Perform(radius))
      return result;
    gp_Pnt nearPt(nearX, nearY, nearZ);
    result.solutionCount = fillet.NbResults(nearPt);
    TopoDS_Edge me1, me2;
    TopoDS_Edge filletEdge = fillet.Result(nearPt, me1, me2);
    if (filletEdge.IsNull())
      return result;
    result.filletEdge    = new OCCTShape(filletEdge);
    result.modifiedEdge1 = new OCCTShape(me1);
    result.modifiedEdge2 = new OCCTShape(me2);
    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return result;
  }
}

OCCTChamferBuilderRef OCCTChamferBuilderCreate(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    return new OCCTChamferBuilder(shape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTChamferBuilderRelease(OCCTChamferBuilderRef builder)
{
  delete builder;
}

bool OCCTChamferBuilderAddEdge(OCCTChamferBuilderRef builder, OCCTEdgeRef edge, double dist)
{
  if (!builder || !edge)
    return false;
  try
  {
    builder->chamfer.Add(dist, edge->edge);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTChamferBuilderAddEdgeTwoDists(OCCTChamferBuilderRef builder,
                                       OCCTEdgeRef           edge,
                                       OCCTFaceRef           face,
                                       double                d1,
                                       double                d2)
{
  if (!builder || !edge || !face)
    return false;
  try
  {
    builder->chamfer.Add(d1, d2, edge->edge, face->face);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTChamferBuilderAddEdgeDistAngle(OCCTChamferBuilderRef builder,
                                        OCCTEdgeRef           edge,
                                        OCCTFaceRef           face,
                                        double                dist,
                                        double                angle)
{
  if (!builder || !edge || !face)
    return false;
  try
  {
    builder->chamfer.AddDA(dist, angle, edge->edge, face->face);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

OCCTShapeRef OCCTChamferBuilderBuild(OCCTChamferBuilderRef builder)
{
  if (!builder)
    return nullptr;
  try
  {
    builder->chamfer.Build();
    if (!builder->chamfer.IsDone())
      return nullptr;
    if (!occtBlendResultIsValid(builder->chamfer.Shape())) // #3200
      return nullptr;
    return new OCCTShape(builder->chamfer.Shape());
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

int32_t OCCTChamferBuilderNbContours(OCCTChamferBuilderRef builder)
{
  if (!builder)
    return 0;
  try
  {
    return builder->chamfer.NbContours();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

bool OCCTChamferBuilderIsDistAngle(OCCTChamferBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return false;
  try
  {
    return builder->chamfer.IsDistanceAngle(contourIndex);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int32_t OCCTChamferBuilderNbEdges(OCCTChamferBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return 0;
  try
  {
    return builder->chamfer.NbEdges(contourIndex);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

void OCCTChamferBuilderGetDist(OCCTChamferBuilderRef builder, int32_t contourIndex, double* dist)
{
  if (!builder || !dist)
    return;
  try
  {
    builder->chamfer.GetDist(contourIndex, *dist);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *dist = -1.0;
  }
}

void OCCTChamferBuilderGetDists(OCCTChamferBuilderRef builder,
                                int32_t               contourIndex,
                                double*               d1,
                                double*               d2)
{
  if (!builder || !d1 || !d2)
    return;
  try
  {
    builder->chamfer.Dists(contourIndex, *d1, *d2);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *d1 = -1.0;
    *d2 = -1.0;
  }
}

void OCCTChamferBuilderGetDistAngle(OCCTChamferBuilderRef builder,
                                    int32_t               contourIndex,
                                    double*               dist,
                                    double*               angle)
{
  if (!builder || !dist || !angle)
    return;
  try
  {
    builder->chamfer.GetDistAngle(contourIndex, *dist, *angle);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *dist  = -1.0;
    *angle = -1.0;
  }
}

bool OCCTChamferBuilderSetDist(OCCTChamferBuilderRef builder,
                               double                dist,
                               int32_t               contourIndex,
                               OCCTFaceRef           face)
{
  if (!builder || !face)
    return false;
  try
  {
    builder->chamfer.SetDist(dist, contourIndex, face->face);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTChamferBuilderSetDists(OCCTChamferBuilderRef builder,
                                double                d1,
                                double                d2,
                                int32_t               contourIndex,
                                OCCTFaceRef           face)
{
  if (!builder || !face)
    return false;
  try
  {
    builder->chamfer.SetDists(d1, d2, contourIndex, face->face);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTChamferBuilderSetDistAngle(OCCTChamferBuilderRef builder,
                                    double                dist,
                                    double                angle,
                                    int32_t               contourIndex,
                                    OCCTFaceRef           face)
{
  if (!builder || !face)
    return false;
  try
  {
    builder->chamfer.SetDistAngle(dist, angle, contourIndex, face->face);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

double OCCTChamferBuilderLength(OCCTChamferBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return -1.0;
  try
  {
    return builder->chamfer.Length(contourIndex);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1.0;
  }
}

bool OCCTChamferBuilderRemoveEdge(OCCTChamferBuilderRef builder, OCCTEdgeRef edge)
{
  if (!builder || !edge)
    return false;
  try
  {
    builder->chamfer.Remove(edge->edge);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

void OCCTChamferBuilderReset(OCCTChamferBuilderRef builder)
{
  if (!builder)
    return;
  try
  {
    builder->chamfer.Reset();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

bool OCCTChamferBuilderClosed(OCCTChamferBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return false;
  try
  {
    return builder->chamfer.Closed(contourIndex);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTChamferBuilderClosedAndTangent(OCCTChamferBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return false;
  try
  {
    return builder->chamfer.ClosedAndTangent(contourIndex);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTChamferBuilderIsSymmetric(OCCTChamferBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return false;
  try
  {
    return builder->chamfer.IsSymetric(contourIndex);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTChamferBuilderIsTwoDists(OCCTChamferBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return false;
  try
  {
    return builder->chamfer.IsTwoDistances(contourIndex);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

OCCTShapeRef OCCTChamferBuilderEdge(OCCTChamferBuilderRef builder,
                                    int32_t               contourIndex,
                                    int32_t               edgeIndex)
{
  if (!builder)
    return nullptr;
  try
  {
    const TopoDS_Edge& e = builder->chamfer.Edge(contourIndex, edgeIndex);
    if (e.IsNull())
      return nullptr;
    return new OCCTShape(e);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTShapeRef OCCTChamferBuilderFirstVertex(OCCTChamferBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return nullptr;
  try
  {
    TopoDS_Vertex v = builder->chamfer.FirstVertex(contourIndex);
    if (v.IsNull())
      return nullptr;
    return new OCCTShape(v);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTShapeRef OCCTChamferBuilderLastVertex(OCCTChamferBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return nullptr;
  try
  {
    TopoDS_Vertex v = builder->chamfer.LastVertex(contourIndex);
    if (v.IsNull())
      return nullptr;
    return new OCCTShape(v);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

int32_t OCCTChamferBuilderContour(OCCTChamferBuilderRef builder, OCCTEdgeRef edge)
{
  if (!builder || !edge)
    return 0;
  try
  {
    return builder->chamfer.Contour(edge->edge);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

double OCCTChamferBuilderAbscissa(OCCTChamferBuilderRef builder,
                                  int32_t               contourIndex,
                                  OCCTShapeRef          vertex)
{
  if (!builder || !vertex)
    return -1.0;
  try
  {
    return builder->chamfer.Abscissa(contourIndex, TopoDS::Vertex(vertex->shape));
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1.0;
  }
}

double OCCTChamferBuilderRelativeAbscissa(OCCTChamferBuilderRef builder,
                                          int32_t               contourIndex,
                                          OCCTShapeRef          vertex)
{
  if (!builder || !vertex)
    return -1.0;
  try
  {
    return builder->chamfer.RelativeAbscissa(contourIndex, TopoDS::Vertex(vertex->shape));
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1.0;
  }
}

int32_t OCCTChamferBuilderGenerated(OCCTChamferBuilderRef builder,
                                    OCCTShapeRef          shape,
                                    OCCTShapeRef**        outShapes)
{
  return occtChamferBuilderHistoryQuery(builder,
                                        shape,
                                        outShapes,
                                        &BRepFilletAPI_MakeChamfer::Generated);
}

int32_t OCCTChamferBuilderModified(OCCTChamferBuilderRef builder,
                                   OCCTShapeRef          shape,
                                   OCCTShapeRef**        outShapes)
{
  return occtChamferBuilderHistoryQuery(builder,
                                        shape,
                                        outShapes,
                                        &BRepFilletAPI_MakeChamfer::Modified);
}

bool OCCTChamferBuilderIsDeleted(OCCTChamferBuilderRef builder, OCCTShapeRef shape)
{
  if (!builder || !shape)
    return false;
  try
  {
    return builder->chamfer.IsDeleted(shape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

void OCCTChamferBuilderSetMode(OCCTChamferBuilderRef builder, int32_t mode)
{
  if (!builder)
    return;
  try
  {
    ChFiDS_ChamfMode chamfMode;
    switch (mode)
    {
      case 1:
        chamfMode = ChFiDS_ConstThroatChamfer;
        break;
      case 2:
        chamfMode = ChFiDS_ConstThroatWithPenetrationChamfer;
        break;
      default:
        chamfMode = ChFiDS_ClassicChamfer;
        break;
    }
    builder->chamfer.SetMode(chamfMode);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

bool OCCTChamferBuilderSimulate(OCCTChamferBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return false;
  try
  {
    builder->chamfer.Simulate(contourIndex);
    return true;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int32_t OCCTChamferBuilderNbSurf(OCCTChamferBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return 0;
  try
  {
    return builder->chamfer.NbSurf(contourIndex);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}
