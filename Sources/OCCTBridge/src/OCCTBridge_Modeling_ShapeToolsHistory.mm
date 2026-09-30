//
//  OCCTBridge_Modeling_ShapeToolsHistory.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Modeling.mm (#396/#819): BRep_Tool, BRep_Builder, BRepLib_FindSurface.
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

OCCTChFi2dFilletResult OCCTChFi2dFilletAlgo(OCCTShapeRef edge1,
                                            OCCTShapeRef edge2,
                                            double       planeOx,
                                            double       planeOy,
                                            double       planeOz,
                                            double       planeNx,
                                            double       planeNy,
                                            double       planeNz,
                                            double       radius)
{
  OCCTChFi2dFilletResult result = {};
  if (!edge1 || !edge2)
    return result;
  try
  {
    // #975: occtEdgeAt(shape, 0) is this bridge's one spelling of "the first edge of this shape",
    // and takes a bare edge as readily as a wire, face, solid or compound holding one. See
    // OCCTBridge_Internal.h.
    TopoDS_Edge e1 = occtEdgeAt(edge1->shape, 0);
    TopoDS_Edge e2 = occtEdgeAt(edge2->shape, 0);
    if (e1.IsNull() || e2.IsNull())
      return result;

    gp_Pln            plane(gp_Pnt(planeOx, planeOy, planeOz), gp_Dir(planeNx, planeNy, planeNz));
    ChFi2d_FilletAlgo fillet(e1, e2, plane);
    if (!fillet.Perform(radius))
      return result;

    gp_Pnt corner;
    // Find the intersection point of the two edges
    double             f1, l1, f2, l2;
    Handle(Geom_Curve) c1 = BRep_Tool::Curve(e1, f1, l1);
    Handle(Geom_Curve) c2 = BRep_Tool::Curve(e2, f2, l2);
    if (c1.IsNull() || c2.IsNull())
      return result;
    // Try endpoints
    gp_Pnt p1s = c1->Value(f1), p1e = c1->Value(l1);
    gp_Pnt p2s = c2->Value(f2), p2e = c2->Value(l2);
    if (p1s.Distance(p2s) < 1e-6)
      corner = p1s;
    else if (p1s.Distance(p2e) < 1e-6)
      corner = p1s;
    else if (p1e.Distance(p2s) < 1e-6)
      corner = p1e;
    else if (p1e.Distance(p2e) < 1e-6)
      corner = p1e;
    else
      corner = p1s; // fallback

    int nb             = fillet.NbResults(corner);
    result.resultCount = nb;
    if (nb < 1)
      return result;

    TopoDS_Edge re1, re2;
    TopoDS_Edge filletEdge = fillet.Result(corner, re1, re2);
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

OCCTShapeRef _Nullable OCCTBRepToolsModifierNurbsConvert(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(BRepTools_NurbsConvertModification) mod = new BRepTools_NurbsConvertModification();
    BRepTools_Modifier                         modifier(shape->shape);
    modifier.Perform(mod);
    if (!modifier.IsDone())
      return nullptr;
    return new OCCTShape(modifier.ModifiedShape(shape->shape));
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

void OCCTEdgeVertex1(OCCTShapeRef edge, double* x, double* y, double* z)
{
  if (!edge)
  {
    *x = *y = *z = 0;
    return;
  }
  try
  {
    TopoDS_Vertex v1, v2;
    TopExp::Vertices(TopoDS::Edge(edge->shape), v1, v2);
    if (v1.IsNull())
    {
      *x = *y = *z = 0;
      return;
    }
    gp_Pnt p = BRep_Tool::Pnt(v1);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *x = *y = *z = 0;
  }
}

void OCCTEdgeVertex2(OCCTShapeRef edge, double* x, double* y, double* z)
{
  if (!edge)
  {
    *x = *y = *z = 0;
    return;
  }
  try
  {
    TopoDS_Vertex v1, v2;
    TopExp::Vertices(TopoDS::Edge(edge->shape), v1, v2);
    if (v2.IsNull())
    {
      *x = *y = *z = 0;
      return;
    }
    gp_Pnt p = BRep_Tool::Pnt(v2);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *x = *y = *z = 0;
  }
}

// --- Quick pre-screen for self-intersection check complexity (#1068) ---
//
// Returns an estimate of the computational cost based on face count and surface types.
// outNumFaces: total number of faces
// outNumBSplineFaces: number of B-spline faces (most expensive to check)
// outNumPlaneFaces: number of planar faces (cheap to check)
// outEstimatedCost: relative cost estimate (higher = more expensive)
// Returns 0 on success, -1 on error
int32_t OCCTShapeSelfIntersectEstimateCost(OCCTShapeRef shape,
                                           int32_t*     outNumFaces,
                                           int32_t*     outNumBSplineFaces,
                                           int32_t*     outNumPlaneFaces,
                                           double*      outEstimatedCost)
{
  if (!shape)
    return -1;
  if (outNumFaces)
    *outNumFaces = 0;
  if (outNumBSplineFaces)
    *outNumBSplineFaces = 0;
  if (outNumPlaneFaces)
    *outNumPlaneFaces = 0;
  if (outEstimatedCost)
    *outEstimatedCost = 0.0;

  try
  {
    TopExp_Explorer exp(shape->shape, TopAbs_FACE);
    int32_t         numFaces        = 0;
    int32_t         numBSplineFaces = 0;
    int32_t         numPlaneFaces   = 0;

    while (exp.More())
    {
      TopoDS_Face          face = TopoDS::Face(exp.Current());
      Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
      numFaces++;
      if (!surf.IsNull())
      {
        // Check surface type
        if (surf->DynamicType()->IsKind(STANDARD_TYPE(Geom_BSplineSurface)))
        {
          numBSplineFaces++;
        }
        else if (surf->DynamicType()->IsKind(STANDARD_TYPE(Geom_Plane)))
        {
          numPlaneFaces++;
        }
        // Other surface types (cylinder, cone, sphere, torus, etc.) are intermediate cost
      }
      exp.Next();
    }

    if (outNumFaces)
      *outNumFaces = numFaces;
    if (outNumBSplineFaces)
      *outNumBSplineFaces = numBSplineFaces;
    if (outNumPlaneFaces)
      *outNumPlaneFaces = numPlaneFaces;

    // Cost model: BSpline faces are ~10x more expensive than analytical surfaces
    // Plane faces are ~1x (baseline)
    // Other analytical surfaces (cylinder, cone, sphere) are ~3x
    int32_t otherFaces = numFaces - numBSplineFaces - numPlaneFaces;
    double  cost       = numBSplineFaces * 10.0 + otherFaces * 3.0 + numPlaneFaces * 1.0;

    if (outEstimatedCost)
      *outEstimatedCost = cost;

    return 0;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

OCCTShapeRef OCCTShapeCreateCompound(const OCCTShapeRef* shapes, int32_t count)
{
  if (!shapes || count < 1)
    return nullptr;
  try
  {
    TopoDS_Compound compound;
    BRep_Builder    builder;
    builder.MakeCompound(compound);

    for (int32_t i = 0; i < count; i++)
    {
      // #1026: TopoDS_Builder::Add dereferences the component's TShape in its first statement, so
      // the pointer test alone was a SIGSEGV on Shape.compound([shape.nullified!]). Refusing the
      // whole call rather than skipping the element matches OCCTMakeWireFromEdges (#1008); the
      // twin of this function is OCCTShapeCompounded in OCCTBridge_Topology.mm.
      if (!occtShapeIsPresent(shapes[i]))
        return nullptr;
      builder.Add(compound, shapes[i]->shape);
    }

    return new OCCTShape(compound);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

int32_t OCCTShapeGetEdgePoints(OCCTShapeRef shape,
                               int32_t      edgeIndex,
                               double*      outPoints,
                               int32_t      maxPoints)
{
  if (!shape || !outPoints || maxPoints < 2 || edgeIndex < 0)
    return 0;

  try
  {
    // Use IndexedMap to match OCCTShapeGetTotalEdgeCount ordering
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

    if (edgeIndex >= edgeMap.Extent())
      return 0;

    TopoDS_Edge edge = TopoDS::Edge(edgeMap(edgeIndex + 1)); // OCCT is 1-based

    // Ensure 3D curve exists (lofted shapes may only have pcurves)
    BRepLib::BuildCurves3d(edge);

    // Get curve from edge
    Standard_Real      first, last;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
    if (curve.IsNull())
      return 0;

    // Sample points along the curve
    int32_t numPoints = std::min(maxPoints, (int32_t)20); // Max 20 points per edge
    for (int32_t i = 0; i < numPoints; i++)
    {
      double param         = first + (last - first) * i / (numPoints - 1);
      gp_Pnt pt            = curve->Value(param);
      outPoints[i * 3 + 0] = pt.X();
      outPoints[i * 3 + 1] = pt.Y();
      outPoints[i * 3 + 2] = pt.Z();
    }

    return numPoints;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

// Get all edge endpoints as a simple contour (for toolpath generation)
int32_t OCCTShapeGetContourPoints(OCCTShapeRef shape, double* outPoints, int32_t maxPoints)
{
  if (!shape || !outPoints || maxPoints < 1)
    return 0;

  try
  {
    int32_t pointCount = 0;

    TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
    while (explorer.More() && pointCount < maxPoints)
    {
      TopoDS_Edge edge = TopoDS::Edge(explorer.Current());

      // Get start and end vertices of the edge
      TopoDS_Vertex v1, v2;
      TopExp::Vertices(edge, v1, v2);

      if (!v1.IsNull())
      {
        gp_Pnt pt                     = BRep_Tool::Pnt(v1);
        outPoints[pointCount * 3 + 0] = pt.X();
        outPoints[pointCount * 3 + 1] = pt.Y();
        outPoints[pointCount * 3 + 2] = pt.Z();
        pointCount++;
      }

      explorer.Next();
    }

    return pointCount;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}
