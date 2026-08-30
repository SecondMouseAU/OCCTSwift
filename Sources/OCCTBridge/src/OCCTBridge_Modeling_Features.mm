//
//  OCCTBridge_Modeling_Features.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Modeling.mm (#396/#819): BRepFeat, Draft, LocOpe, Helix, patterns.
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
#include <LocOpe_SplitDrafts.hxx>
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
#include <Geom_BSplineCurve.hxx>
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
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>

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

static bool occtDrawingReachAlongDirection(const TopoDS_Shape& shape,
                                           const gp_Dir&       viewDir,
                                           double&             outReach)
{
  Bnd_Box bounds;
  BRepBndLib::Add(shape, bounds);
  if (bounds.IsVoid())
    return false;

  double xmin, ymin, zmin, xmax, ymax, zmax;
  bounds.Get(xmin, ymin, zmin, xmax, ymax, zmax);
  outReach = (viewDir.X() > 0 ? xmax : xmin) * viewDir.X()
             + (viewDir.Y() > 0 ? ymax : ymin) * viewDir.Y()
             + (viewDir.Z() > 0 ? zmax : zmin) * viewDir.Z();
  return true;
}

// #794: shared helper for ShapeMakePeriodic / ShapeRepeat
static OCCTShapeRef occtShapePeriodicImpl(OCCTShapeRef shape,
                                          bool         xPeriodic,
                                          double       xPeriod,
                                          int32_t      xTimes,
                                          bool         yPeriodic,
                                          double       yPeriod,
                                          int32_t      yTimes,
                                          bool         zPeriodic,
                                          double       zPeriod,
                                          int32_t      zTimes,
                                          bool         useRepeatedShape)
{
  if (!shape)
    return nullptr;
  try
  {
    BOPAlgo_MakePeriodic maker;
    maker.SetShape(shape->shape);
    if (xPeriodic)
      maker.MakeXPeriodic(true, xPeriod);
    if (yPeriodic)
      maker.MakeYPeriodic(true, yPeriod);
    if (zPeriodic)
      maker.MakeZPeriodic(true, zPeriod);
    maker.Perform();
    if (maker.HasErrors())
      return nullptr;

    if (useRepeatedShape)
    {
      if (xPeriodic && xTimes > 0)
        maker.XRepeat(xTimes);
      if (yPeriodic && yTimes > 0)
        maker.YRepeat(yTimes);
      if (zPeriodic && zTimes > 0)
        maker.ZRepeat(zTimes);
      return new OCCTShape(maker.RepeatedShape());
    }
    else
    {
      return new OCCTShape(maker.Shape());
    }
  }
  catch (...)
  {
    return nullptr;
  }
}

// #974: OCCTShapeQuilt and OCCTShapeQuiltWithHistory (further down this file) fed the same quilt
// the same way and differed only in what they assembled afterwards, so the feeding loop and the
// shell it takes live here once. The quilt is the caller's, not this helper's: the history variant
// reads it again after this returns (IsCopied/Copy), so it is passed by reference rather than
// created here.
//
// File-static rather than shared through OCCTBridge_Internal.h because BRepTools_Quilt has exactly
// these two call sites, both in this file: measured by grep over Sources/OCCTBridge, the class
// appears in no other .mm and in no header. Move it to OCCTBridge_Internal.h as `inline` the
// moment a second file quilts, since a static copy in another translation unit is one that can
// never converge on this one (#943, #957).
//
// Returns a null shape when an entry is null or the quilt produced nothing. Both callers turn
// either into a null return, which is what they did as separate copies.
static TopoDS_Shape occtQuiltShells(BRepTools_Quilt&    quilt,
                                    const OCCTShapeRef* shapes,
                                    int32_t             count)
{
  for (int32_t i = 0; i < count; i++)
  {
    if (!shapes[i])
      return TopoDS_Shape();
    quilt.Add(shapes[i]->shape);
  }
  return quilt.Shells();
}

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

// Convenience for the common 1- and 2-argument builders.
static TopTools_ListOfShape occtArgList(const TopoDS_Shape& a)
{
  TopTools_ListOfShape l;
  l.Append(a);
  return l;
}

static TopTools_ListOfShape occtArgList(const TopoDS_Shape& a, const TopoDS_Shape& b)
{
  TopTools_ListOfShape l;
  l.Append(a);
  l.Append(b);
  return l;
}

// 3D points sampled along a wire in traversal order, `samplesPerEdge + 1` per edge (both
// endpoints included, so consecutive edges repeat their shared point). Arc-aware: sampling the
// parametric range is what lets a curved edge contribute its true bulge rather than just its two
// vertices, the distinction #397 turned on. Degenerate edges, and edges carrying no 3D curve, are
// skipped rather than throwing.
static std::vector<gp_Pnt> occtSampleWirePoints(const TopoDS_Wire& wire, int samplesPerEdge)
{
  std::vector<gp_Pnt> pts;
  for (BRepTools_WireExplorer explorer(wire); explorer.More(); explorer.Next())
  {
    const TopoDS_Edge& edge = explorer.Current();
    if (BRep_Tool::Degenerated(edge))
      continue;
    try
    {
      BRepAdaptor_Curve curve(edge);
      const double      f = curve.FirstParameter();
      const double      l = curve.LastParameter();
      // Walk the curve in the edge's traversal direction within the wire.
      const bool reversed = (edge.Orientation() == TopAbs_REVERSED);
      for (int s = 0; s <= samplesPerEdge; s++)
      {
        const double t = (double)s / (double)samplesPerEdge;
        pts.push_back(curve.Value(reversed ? (l + (f - l) * t) : (f + (l - f) * t)));
      }
    }
    catch (...)
    {
      continue;
    } // no 3D curve on this edge, nothing to sample
  }
  return pts;
}

// Signed area of a (nominally planar) wire measured in the plane spanned by pln's
// X/Y directions, as a shoelace sum over the sampled polyline. The magnitude is only an
// approximation, but the SIGN, all we use it for, is robust for simple loops.
// A positive result means the wire winds counter-clockwise about pln's normal.
static double occtSignedWireAreaInPlane(const TopoDS_Wire& wire, const gp_Pln& pln)
{
  const gp_Pnt origin = pln.Location();
  const gp_Dir xDir   = pln.Position().XDirection();
  const gp_Dir yDir   = pln.Position().YDirection();

  auto projectUV = [&](const gp_Pnt& p, double& u, double& v) {
    const gp_Vec d(origin, p);
    u = d.Dot(gp_Vec(xDir));
    v = d.Dot(gp_Vec(yDir));
  };

  double area    = 0.0;
  bool   hasPrev = false;
  double u0 = 0.0, v0 = 0.0;       // first sampled point (to close the loop)
  double uPrev = 0.0, vPrev = 0.0; // previous sampled point

  for (const gp_Pnt& p : occtSampleWirePoints(wire, 24))
  {
    double u, v;
    projectUV(p, u, v);
    if (!hasPrev)
    {
      u0 = uPrev = u;
      v0 = vPrev = v;
      hasPrev    = true;
    }
    else
    {
      area += (uPrev * v - u * vPrev);
      uPrev = u;
      vPrev = v;
    }
  }
  if (hasPrev)
  {
    area += (uPrev * v0 - u0 * vPrev); // close the loop
  }
  return 0.5 * area;
}

// The plane a face's boundary lies in, if it has one: the face's own surface when it is planar,
// else a plane fitted to its outer wire. Used to compare hole/outer winding (#274, #397).
static bool occtFacePlane(const TopoDS_Face& face, gp_Pln& plane)
{
  Handle(Geom_Plane) planar = Handle(Geom_Plane)::DownCast(BRep_Tool::Surface(face));
  if (!planar.IsNull())
  {
    plane = planar->Pln();
    return true;
  }
  BRepBuilderAPI_FindPlane finder(BRepTools::OuterWire(face));
  if (finder.Found())
  {
    plane = finder.Plane()->Pln();
    return true;
  }
  return false;
}

// Shared by both pattern history functions: apply `count` transforms (the i-th
// given by `trsfForIndex`) to `shape`, add each instance to a compound, and fold
// each instance's Modified/Generated for the original sub-shapes into one
// BRepTools_History. Returns the compound in `outResult` and the history handle,
// or nullptr if no instance succeeded.
static OCCTBooleanHistoryRef occtPatternHistory(OCCTShapeRef                           shape,
                                                int32_t                                count,
                                                const std::function<gp_Trsf(int32_t)>& trsfForIndex,
                                                OCCTShapeRef*                          outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape || count < 1)
    return nullptr;
  try
  {
    BRep_Builder    builder;
    TopoDS_Compound compound;
    builder.MakeCompound(compound);

    TopTools_IndexedMapOfShape subMap;
    TopExp::MapShapes(shape->shape, subMap);

    Handle(BRepTools_History) hist    = new BRepTools_History();
    bool                      anyDone = false;
    for (int32_t i = 0; i < count; i++)
    {
      BRepBuilderAPI_Transform xform(shape->shape, trsfForIndex(i), Standard_True);
      if (!xform.IsDone())
        continue;
      anyDone = true;
      builder.Add(compound, xform.Shape());

      for (int32_t j = 1; j <= subMap.Extent(); j++)
      {
        const TopoDS_Shape& sub = subMap(j);
        if (!BRepTools_History::IsSupportedType(sub))
          continue;
        for (TopTools_ListIteratorOfListOfShape it(xform.Modified(sub)); it.More(); it.Next())
        {
          hist->AddModified(sub, it.Value());
        }
        for (TopTools_ListIteratorOfListOfShape it(xform.Generated(sub)); it.More(); it.Next())
        {
          hist->AddGenerated(sub, it.Value());
        }
      }
    }
    if (!anyDone)
      return nullptr;

    if (outResult)
      *outResult = new OCCTShape(compound);
    return new OCCTBooleanHistory(hist);
  }
  catch (...)
  {
    return nullptr;
  }
}

// #794: shared helper for WireInterpolate (base vs WithTangents)
static OCCTWireRef occtWireInterpolateImpl(const double* points,
                                           int32_t       count,
                                           double        tolerance,
                                           bool          closed,
                                           double        startTanX,
                                           double        startTanY,
                                           double        startTanZ,
                                           double        endTanX,
                                           double        endTanY,
                                           double        endTanZ,
                                           bool          hasTangents)
{
  if (!points || count < 2)
    return nullptr;

  try
  {
    // Build array of points
    Handle(TColgp_HArray1OfPnt) hPoints = new TColgp_HArray1OfPnt(1, count);
    for (int32_t i = 0; i < count; i++)
    {
      hPoints->SetValue(i + 1, gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]));
    }

    // Create interpolator
    GeomAPI_Interpolate interpolator(hPoints, closed ? Standard_True : Standard_False, tolerance);

    if (hasTangents)
    {
      gp_Vec startTangent(startTanX, startTanY, startTanZ);
      gp_Vec endTangent(endTanX, endTanY, endTanZ);
      interpolator.Load(startTangent, endTangent);
    }

    interpolator.Perform();

    if (!interpolator.IsDone())
      return nullptr;

    Handle(Geom_BSplineCurve) curve = interpolator.Curve();
    if (curve.IsNull())
      return nullptr;

    // Create edge from curve
    BRepBuilderAPI_MakeEdge makeEdge(curve);
    if (!makeEdge.IsDone())
      return nullptr;

    // Create wire from edge
    BRepBuilderAPI_MakeWire makeWire(makeEdge.Edge());
    if (!makeWire.IsDone())
      return nullptr;

    return new OCCTWire(makeWire.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

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
static void fillCommonPart(const IntTools_CommonPrt& cp, OCCTCommonPart& out)
{
  out.type          = (cp.Type() == TopAbs_VERTEX) ? 0 : 1;
  IntTools_Range r1 = cp.Range1();
  out.param1First   = r1.First();
  out.param1Last    = r1.Last();
  // Range2 is a sequence; use first element if available
  if (cp.Ranges2().Length() > 0)
  {
    out.param2First = cp.Ranges2()(1).First();
    out.param2Last  = cp.Ranges2()(1).Last();
  }
  else
  {
    out.param2First = cp.VertexParameter2();
    out.param2Last  = cp.VertexParameter2();
  }
  if (cp.Type() == TopAbs_VERTEX)
  {
    out.param1First = cp.VertexParameter1();
    out.param1Last  = cp.VertexParameter1();
    out.param2First = cp.VertexParameter2();
    out.param2Last  = cp.VertexParameter2();
  }
  // Bounding points
  gp_Pnt bp1, bp2;
  cp.BoundingPoints(bp1, bp2);
  // Use midpoint as representative point
  out.pointX = (bp1.X() + bp2.X()) / 2.0;
  out.pointY = (bp1.Y() + bp2.Y()) / 2.0;
  out.pointZ = (bp1.Z() + bp2.Z()) / 2.0;
}

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

static void _storeTrsf(const gp_Trsf& t, double* matrix)
{
  for (int r = 1; r <= 3; r++)
    for (int c = 1; c <= 4; c++)
      matrix[(r - 1) * 4 + (c - 1)] = t.Value(r, c);
}

static void _storeTrsf2d(const gp_Trsf2d& t, double* matrix)
{
  for (int r = 1; r <= 2; r++)
    for (int c = 1; c <= 3; c++)
      matrix[(r - 1) * 3 + (c - 1)] = t.Value(r, c);
}

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

static BOPAlgo_GlueEnum toGlueEnum(int32_t mode)
{
  switch (mode)
  {
    case 0:
      return BOPAlgo_GlueShift;
    case 1:
      return BOPAlgo_GlueFull;
    default:
      return BOPAlgo_GlueOff;
  }
}

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

// #794: shared helper for FilletBuilder history queries (Generated/Modified)
static int32_t occtFilletBuilderHistoryQuery(
  OCCTFilletBuilderRef builder,
  OCCTShapeRef         shape,
  OCCTShapeRef**       outShapes,
  const TopTools_ListOfShape& (BRepFilletAPI_MakeFillet::*query)(const TopoDS_Shape&))
{
  if (!builder || !shape || !outShapes)
    return 0;
  *outShapes = nullptr;
  try
  {
    const TopTools_ListOfShape& list  = (builder->fillet.*query)(shape->shape);
    int                         count = static_cast<int>(list.Size());
    if (count == 0)
      return 0;
    OCCTShapeRef* shapes = (OCCTShapeRef*)malloc(count * sizeof(OCCTShapeRef));
    if (!shapes)
      return 0;
    int i = 0;
    for (auto it = list.cbegin(); it != list.cend(); ++it, ++i)
    {
      shapes[i] = new OCCTShape(*it);
    }
    *outShapes = shapes;
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

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

OCCTWireRef OCCTWireCreateHelix(double originX,
                                double originY,
                                double originZ,
                                double axisX,
                                double axisY,
                                double axisZ,
                                double radius,
                                double pitch,
                                double turns,
                                bool   clockwise)
{
  try
  {
    gp_Pnt origin(originX, originY, originZ);
    gp_Dir dir(axisX, axisY, axisZ);
    if (!clockwise)
      dir.Reverse();
    gp_Ax3 axis(origin, dir);

    double diameter = radius * 2.0;

    NCollection_Array1<double> pitchArr(1, 1);
    pitchArr.SetValue(1, pitch);
    NCollection_Array1<double> nbTurnsArr(1, 1);
    nbTurnsArr.SetValue(1, turns);

    HelixBRep_BuilderHelix builder;
    builder.SetParameters(axis, diameter, pitchArr, nbTurnsArr);
    builder.Perform();

    if (builder.ErrorStatus() != 0)
      return nullptr;

    const TopoDS_Shape& shape = builder.Shape();
    if (shape.IsNull())
      return nullptr;

    return new OCCTWire(TopoDS::Wire(shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateHelixTapered(double originX,
                                       double originY,
                                       double originZ,
                                       double axisX,
                                       double axisY,
                                       double axisZ,
                                       double startRadius,
                                       double endRadius,
                                       double pitch,
                                       double turns,
                                       bool   clockwise)
{
  try
  {
    gp_Pnt origin(originX, originY, originZ);
    gp_Dir dir(axisX, axisY, axisZ);
    if (!clockwise)
      dir.Reverse();
    gp_Ax3 axis(origin, dir);

    double startDiam = startRadius * 2.0;
    double endDiam   = endRadius * 2.0;

    NCollection_Array1<double> pitchArr(1, 1);
    pitchArr.SetValue(1, pitch);
    NCollection_Array1<double> nbTurnsArr(1, 1);
    nbTurnsArr.SetValue(1, turns);

    HelixBRep_BuilderHelix builder;
    builder.SetParameters(axis, startDiam, endDiam, pitchArr, nbTurnsArr);
    builder.Perform();

    if (builder.ErrorStatus() != 0)
      return nullptr;

    const TopoDS_Shape& shape = builder.Shape();
    if (shape.IsNull())
      return nullptr;

    return new OCCTWire(TopoDS::Wire(shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeSplitByWire(OCCTShapeRef shape, OCCTWireRef wire, int32_t faceIndex)
{
  if (!shape || !wire)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
    int32_t idx = faceIndex + 1; // Convert 0-based to 1-based
    if (idx < 1 || idx > faceMap.Extent())
      return nullptr;
    TopoDS_Face         face = TopoDS::Face(faceMap(idx));
    BRepFeat_SplitShape splitter(shape->shape);
    splitter.Add(wire->wire, face);
    splitter.Build();
    if (!splitter.IsDone())
      return nullptr;
    TopoDS_Shape result = splitter.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapePipeFeature(OCCTShapeRef shape,
                                  int32_t      profileFaceIndex,
                                  int32_t      sketchFaceIndex,
                                  OCCTWireRef  spine,
                                  int32_t      fuse)
{
  if (!shape || !spine)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

    int32_t profIdx   = profileFaceIndex + 1;
    int32_t sketchIdx = sketchFaceIndex + 1;
    if (profIdx < 1 || profIdx > faceMap.Extent())
      return nullptr;
    if (sketchIdx < 1 || sketchIdx > faceMap.Extent())
      return nullptr;

    TopoDS_Face profileFace = TopoDS::Face(faceMap(profIdx));
    TopoDS_Face sketchFace  = TopoDS::Face(faceMap(sketchIdx));

    BRepFeat_MakePipe maker(shape->shape, profileFace, sketchFace, spine->wire, fuse, true);
    maker.Perform();
    if (!maker.IsDone())
      return nullptr;

    TopoDS_Shape result = maker.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapePipeFeatureFromProfile(OCCTShapeRef baseShape,
                                             OCCTShapeRef profileShape,
                                             int32_t      sketchFaceIndex,
                                             OCCTWireRef  spine,
                                             int32_t      fuse)
{
  if (!baseShape || !profileShape || !spine)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(baseShape->shape, TopAbs_FACE, faceMap);

    int32_t sketchIdx = sketchFaceIndex + 1;
    if (sketchIdx < 1 || sketchIdx > faceMap.Extent())
      return nullptr;

    TopoDS_Face sketchFace = TopoDS::Face(faceMap(sketchIdx));

    BRepFeat_MakePipe maker(baseShape->shape,
                            profileShape->shape,
                            sketchFace,
                            spine->wire,
                            fuse,
                            true);
    maker.Perform();
    if (!maker.IsDone())
      return nullptr;

    TopoDS_Shape result = maker.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapePrismUntilFace(OCCTShapeRef baseShape,
                                     OCCTShapeRef profileShape,
                                     int32_t      sketchFaceIndex,
                                     double       dirX,
                                     double       dirY,
                                     double       dirZ,
                                     int32_t      fuse,
                                     int32_t      untilFaceIndex)
{
  if (!baseShape || !profileShape)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(baseShape->shape, TopAbs_FACE, faceMap);

    int32_t sketchIdx = sketchFaceIndex + 1;
    if (sketchIdx < 1 || sketchIdx > faceMap.Extent())
      return nullptr;

    TopoDS_Face sketchFace = TopoDS::Face(faceMap(sketchIdx));
    gp_Dir      dir(dirX, dirY, dirZ);

    BRepFeat_MakePrism maker(baseShape->shape, profileShape->shape, sketchFace, dir, fuse, true);

    if (untilFaceIndex < 0)
    {
      // Thru-all
      maker.PerformThruAll();
    }
    else
    {
      int32_t untilIdx = untilFaceIndex + 1;
      if (untilIdx < 1 || untilIdx > faceMap.Extent())
        return nullptr;
      TopoDS_Face untilFace = TopoDS::Face(faceMap(untilIdx));
      maker.Perform(untilFace);
    }

    if (!maker.IsDone())
      return nullptr;
    TopoDS_Shape result = maker.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeDrillHole(OCCTShapeRef shape,
                                double       posX,
                                double       posY,
                                double       posZ,
                                double       dirX,
                                double       dirY,
                                double       dirZ,
                                double       radius,
                                double       depth)
{
  // The drilling preconditions live in OCCTBridge_Internal.h so that this function and the
  // BRepFeat_MakeCylindricalHole family cannot drift apart on what a drillable request is (#496).
  // The radius bound is what changed here: `radius > 0` let a sub-Precision::Confusion radius
  // through to a cut that removed nothing and reported success.
  if (!shape)
    return nullptr;
  if (!occtValidDrillDirection(dirX, dirY, dirZ))
    return nullptr;
  if (!occtValidDrillRadius(radius))
    return nullptr;

  try
  {
    gp_Vec direction(dirX, dirY, dirZ);
    direction.Normalize();

    // Determine depth - if depth is 0 or negative, make it through the shape
    double actualDepth = depth;
    if (actualDepth <= 0)
    {
      // Calculate shape extent for through hole
      Bnd_Box bounds;
      BRepBndLib::Add(shape->shape, bounds);
      double xmin, ymin, zmin, xmax, ymax, zmax;
      bounds.Get(xmin, ymin, zmin, xmax, ymax, zmax);
      double diagonal = std::sqrt((xmax - xmin) * (xmax - xmin) + (ymax - ymin) * (ymax - ymin)
                                  + (zmax - zmin) * (zmax - zmin));
      actualDepth     = diagonal * 2; // Make sure it goes through
    }

    // Build the cutting cylinder ALONG the requested (normalized) drill
    // direction, with its base at the drill entry point and extending into
    // the shape for actualDepth. Using the oriented constructor keeps the
    // cylinder's axis aligned with `direction`; the previous code built the
    // cylinder hardcoded along +Z (via OCCTShapeCreateCylinderAt), so any
    // non-Z direction drilled the wrong axis (issue #272).
    OCCTShapeRef cylRef = OCCTShapeCreateCylinderOriented(posX,
                                                          posY,
                                                          posZ,
                                                          direction.X(),
                                                          direction.Y(),
                                                          direction.Z(),
                                                          radius,
                                                          actualDepth);
    if (!cylRef)
      return nullptr;

    // Subtract using the existing working function
    OCCTShapeRef result = OCCTShapeSubtract(shape, cylRef);
    OCCTShapeRelease(cylRef);

    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - LocOpe_Prism (v0.46)
OCCTShapeRef OCCTLocOpePrism(OCCTShapeRef face, double dx, double dy, double dz)
{
  if (!face)
    return nullptr;
  try
  {
    LocOpe_Prism prism(face->shape, gp_Vec(dx, dy, dz));
    TopoDS_Shape result = prism.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTLocOpePrismWithTranslation(OCCTShapeRef face,
                                            double       dx,
                                            double       dy,
                                            double       dz,
                                            double       tx,
                                            double       ty,
                                            double       tz)
{
  if (!face)
    return nullptr;
  try
  {
    LocOpe_Prism prism(face->shape, gp_Vec(dx, dy, dz), gp_Vec(tx, ty, tz));
    TopoDS_Shape result = prism.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTLocOpeRevol(OCCTShapeRef profile,
                             double       axisOriginX,
                             double       axisOriginY,
                             double       axisOriginZ,
                             double       axisDirX,
                             double       axisDirY,
                             double       axisDirZ,
                             double       angle)
{
  if (!profile)
    return nullptr;
  try
  {
    gp_Ax1       axis(gp_Pnt(axisOriginX, axisOriginY, axisOriginZ),
                      gp_Dir(axisDirX, axisDirY, axisDirZ));
    LocOpe_Revol revol;
    revol.Perform(profile->shape, axis, angle);
    TopoDS_Shape result = revol.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTLocOpeRevolWithOffset(OCCTShapeRef profile,
                                       double       axisOriginX,
                                       double       axisOriginY,
                                       double       axisOriginZ,
                                       double       axisDirX,
                                       double       axisDirY,
                                       double       axisDirZ,
                                       double       angle,
                                       double       angledec)
{
  if (!profile)
    return nullptr;
  try
  {
    gp_Ax1       axis(gp_Pnt(axisOriginX, axisOriginY, axisOriginZ),
                      gp_Dir(axisDirX, axisDirY, axisDirZ));
    LocOpe_Revol revol;
    revol.Perform(profile->shape, axis, angle, angledec);
    TopoDS_Shape result = revol.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTLocOpeDPrism(OCCTFaceRef spineFace, double height1, double height2, double angle)
{
  if (!spineFace)
    return nullptr;
  try
  {
    LocOpe_DPrism dprism(spineFace->face, height1, height2, angle);
    if (!dprism.IsDone())
      return nullptr;
    TopoDS_Shape result = dprism.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTLocOpeDPrismSingleHeight(OCCTFaceRef spineFace, double height, double angle)
{
  if (!spineFace)
    return nullptr;
  try
  {
    LocOpe_DPrism dprism(spineFace->face, height, angle);
    if (!dprism.IsDone())
      return nullptr;
    TopoDS_Shape result = dprism.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - LocOpe Form/Split/Find/Intersect (v0.48)
OCCTShapeRef OCCTLocOpePipe(OCCTShapeRef shape, OCCTShapeRef spineWire)
{
  // #1026: the ShapeType() reads below are unguarded myTShape dereferences, so the shape needs
  // testing as well as the pointer. occtShapeIsPresent is in OCCTBridge_Internal.h.
  if (!occtShapeIsPresent(shape) || !occtShapeIsPresent(spineWire))
    return nullptr;
  try
  {
    // Extract wire from spine shape
    TopoDS_Wire wire;
    if (spineWire->shape.ShapeType() == TopAbs_WIRE)
    {
      wire = TopoDS::Wire(spineWire->shape);
    }
    else
    {
      for (TopExp_Explorer exp(spineWire->shape, TopAbs_WIRE); exp.More(); exp.Next())
      {
        wire = TopoDS::Wire(exp.Current());
        break;
      }
    }
    if (wire.IsNull())
      return nullptr;

    LocOpe_Pipe  pipe(wire, shape->shape);
    TopoDS_Shape result = pipe.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTLocOpeLinearForm(OCCTShapeRef shape,
                                  double       dx,
                                  double       dy,
                                  double       dz,
                                  double       p1x,
                                  double       p1y,
                                  double       p1z,
                                  double       p2x,
                                  double       p2y,
                                  double       p2z)
{
  if (!shape)
    return nullptr;
  try
  {
    gp_Vec direction(dx, dy, dz);
    gp_Pnt pnt1(p1x, p1y, p1z);
    gp_Pnt pnt2(p2x, p2y, p2z);

    LocOpe_LinearForm linearForm;
    linearForm.Perform(shape->shape, direction, pnt1, pnt2);

    TopoDS_Shape result = linearForm.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTLocOpeRevolutionForm(OCCTShapeRef shape,
                                      double       axisOriginX,
                                      double       axisOriginY,
                                      double       axisOriginZ,
                                      double       axisDirX,
                                      double       axisDirY,
                                      double       axisDirZ,
                                      double       angle)
{
  if (!shape)
    return nullptr;
  try
  {
    gp_Ax1 axis(gp_Pnt(axisOriginX, axisOriginY, axisOriginZ),
                gp_Dir(axisDirX, axisDirY, axisDirZ));

    LocOpe_RevolutionForm revolForm;
    revolForm.Perform(shape->shape, axis, angle);

    TopoDS_Shape result = revolForm.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTLocOpeSplitShapeByWire(OCCTShapeRef shape, int32_t faceIndex, OCCTShapeRef wire)
{
  // #1026: the wire's ShapeType() read below is an unguarded myTShape dereference.
  if (!occtShapeIsPresent(shape) || !occtShapeIsPresent(wire))
    return nullptr;
  try
  {
    LocOpe_SplitShape splitter(shape->shape);

    // #541: the shared face enumeration, so this names the face face(at:) names.
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return nullptr;

    // Extract wire
    TopoDS_Wire w;
    if (wire->shape.ShapeType() == TopAbs_WIRE)
    {
      w = TopoDS::Wire(wire->shape);
    }
    else
    {
      for (TopExp_Explorer exp(wire->shape, TopAbs_WIRE); exp.More(); exp.Next())
      {
        w = TopoDS::Wire(exp.Current());
        break;
      }
    }
    if (w.IsNull())
      return nullptr;

    bool added = splitter.Add(w, face);
    if (!added)
      return nullptr;

    // Rebuild the shape
    // SplitShape doesn't have a Shape() method - we collect descendants
    // Actually, we need to reconstruct. Let's use a different approach.
    // The SplitShape modifies in place - we can use DescendantShapes to see results.
    // For the bridge, let's return a compound of all shapes.
    BRep_Builder    builder;
    TopoDS_Compound compound;
    builder.MakeCompound(compound);

    // Add all descendant shapes
    const auto& descendants = splitter.DescendantShapes(face);
    for (auto it = descendants.begin(); it != descendants.end(); ++it)
    {
      builder.Add(compound, *it);
    }

    // Add other non-split faces
    for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next())
    {
      TopoDS_Face f = TopoDS::Face(exp.Current());
      if (f.IsSame(face))
        continue;
      builder.Add(compound, f);
    }

    return new OCCTShape(compound);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTLocOpeSplitShapeByVertex(OCCTShapeRef shape, int32_t edgeIndex, double parameter)
{
  if (!shape)
    return nullptr;
  try
  {
    LocOpe_SplitShape splitter(shape->shape);

    // #613: this counted TopExp_Explorer occurrences while OCCTLocOpeSplitShapeByWire directly
    // above already read the shared enumeration, so faceIndex and edgeIndex meant different
    // things in two adjacent functions driving the same LocOpe_SplitShape. Measured on a 10mm
    // box: splitEdge(at:) matches edges() up to index 8 and splits a DIFFERENT edge from 9 on
    // (index 9 split edges()[4], index 11 split edges()[0]), and indices 12 and 13 split
    // successfully although edge(at:) refuses both.
    //
    // Safe on the map: LocOpe_SplitShape keys the edge into its own myMap/myDblE, both
    // NCollection containers over TopTools_ShapeMapHasher (LocOpe_SplitShape.hxx:89-90) whose
    // equality is TopoDS_Shape::IsSame, so orientation cannot select a different entry.
    // Measured over all 12 box edges present in both orientations: BRep_Tool::Range and the
    // resulting DescendantShapes count were identical for both, 0 differing.
    TopoDS_Edge edge = occtEdgeAt(shape->shape, edgeIndex);
    if (edge.IsNull())
      return nullptr;

    // Get edge parameter range
    double first, last;
    BRep_Tool::Range(edge, first, last);
    double param = first + parameter * (last - first);

    // Create vertex
    gp_Pnt             pnt;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
    if (curve.IsNull())
      return nullptr;
    curve->D0(param, pnt);

    TopoDS_Vertex vertex = BRepBuilderAPI_MakeVertex(pnt);
    splitter.Add(vertex, param, edge);

    // Rebuild
    const auto& descendants = splitter.DescendantShapes(edge);
    if (descendants.Size() < 2)
      return nullptr;

    BRep_Builder    builder;
    TopoDS_Compound compound;
    builder.MakeCompound(compound);
    for (auto it = descendants.begin(); it != descendants.end(); ++it)
    {
      builder.Add(compound, *it);
    }
    return new OCCTShape(compound);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTLocOpeSplitDrafts(OCCTShapeRef shape,
                                   int32_t      faceIndex,
                                   OCCTShapeRef wire,
                                   double       dirX,
                                   double       dirY,
                                   double       dirZ,
                                   double       planeOriginX,
                                   double       planeOriginY,
                                   double       planeOriginZ,
                                   double       planeNormalX,
                                   double       planeNormalY,
                                   double       planeNormalZ,
                                   double       angle)
{
  // #1026: the wire's ShapeType() read below is an unguarded myTShape dereference.
  if (!occtShapeIsPresent(shape) || !occtShapeIsPresent(wire))
    return nullptr;
  try
  {
    LocOpe_SplitDrafts splitDrafts;
    splitDrafts.Init(shape->shape);

    // #541: the shared face enumeration, so this names the face face(at:) names.
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return nullptr;

    // Extract wire
    TopoDS_Wire w;
    if (wire->shape.ShapeType() == TopAbs_WIRE)
    {
      w = TopoDS::Wire(wire->shape);
    }
    else
    {
      for (TopExp_Explorer exp(wire->shape, TopAbs_WIRE); exp.More(); exp.Next())
      {
        w = TopoDS::Wire(exp.Current());
        break;
      }
    }
    if (w.IsNull())
      return nullptr;

    gp_Dir dir(dirX, dirY, dirZ);
    gp_Pln plane(gp_Pnt(planeOriginX, planeOriginY, planeOriginZ),
                 gp_Dir(planeNormalX, planeNormalY, planeNormalZ));

    splitDrafts.Perform(face, w, dir, plane, angle);

    TopoDS_Shape result = splitDrafts.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// #613: a finder returns a SELECTION, so the position of an entry in outEdges is a result slot, not
// an index into anything. Swift wrote that slot number into Edge.index all the same. Measured on a
// 10mm box (identically for the origin-centred and origin-at-zero spellings), edgesInFace(at: 3)
// handed back 0,1,2,3 for the four edges of face 3, whose real indices are 2, 6, 10 and 11, so
// ALL FOUR named a different edge, their arc-length midpoints 10.00, 12.25, 7.07 and 12.25 mm from
// the edges those slot numbers address. An Edge from either finder therefore could not be fed to
// filleted(edges:), chamfered(...) or any other index-taking entry point, which is the whole
// purpose of carrying an index.
//
// The map lookup is the fix and it is exact: the enumeration's equality is TopoDS_Shape::IsSame, so
// whichever orientation the finder hands back resolves to the one index that names that edge.
int32_t OCCTLocOpeFindEdges(OCCTShapeRef  shape1,
                            OCCTShapeRef  shape2,
                            OCCTShapeRef* outEdges,
                            int32_t*      outIndices,
                            int32_t       maxEdges)
{
  if (!shape1 || !shape2 || !outEdges || maxEdges <= 0)
    return 0;
  try
  {
    LocOpe_FindEdges finder;
    finder.Set(shape1->shape, shape2->shape);

    // One map for the whole batch rather than one per lookup.
    TopTools_IndexedMapOfShape edgeMap;
    occtMapSubShapes(shape1->shape, TopAbs_EDGE, edgeMap);

    int32_t count = 0;
    for (finder.InitIterator(); finder.More() && count < maxEdges; finder.Next())
    {
      const TopoDS_Edge& found = finder.EdgeFrom(); // an edge of shape1
      outEdges[count]          = new OCCTShape(found);
      if (outIndices)
        outIndices[count] = occtMappedIndexOf(edgeMap, found);
      count++;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTLocOpeFindEdgesInFace(OCCTShapeRef  shape,
                                  int32_t       faceIndex,
                                  OCCTShapeRef* outEdges,
                                  int32_t*      outIndices,
                                  int32_t       maxEdges)
{
  if (!shape || !outEdges || maxEdges <= 0)
    return 0;
  try
  {
    // #541: the shared face enumeration, so this names the face face(at:) names.
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return 0;

    LocOpe_FindEdgesInFace finder;
    finder.Set(shape->shape, face);

    TopTools_IndexedMapOfShape edgeMap;
    occtMapSubShapes(shape->shape, TopAbs_EDGE, edgeMap);

    int32_t count = 0;
    for (finder.Init(); finder.More() && count < maxEdges; finder.Next())
    {
      const TopoDS_Edge& found = finder.Edge();
      outEdges[count]          = new OCCTShape(found);
      if (outIndices)
        outIndices[count] = occtMappedIndexOf(edgeMap, found);
      count++;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTLocOpeCSIntersectLine(OCCTShapeRef             shape,
                                  double                   lineOriginX,
                                  double                   lineOriginY,
                                  double                   lineOriginZ,
                                  double                   lineDirX,
                                  double                   lineDirY,
                                  double                   lineDirZ,
                                  OCCTCSIntersectionPoint* outPoints,
                                  int32_t                  maxPoints)
{
  if (!shape || !outPoints || maxPoints <= 0)
    return 0;
  try
  {
    LocOpe_CSIntersector intersector(shape->shape);

    NCollection_Sequence<gp_Lin> lines;
    lines.Append(
      gp_Lin(gp_Pnt(lineOriginX, lineOriginY, lineOriginZ), gp_Dir(lineDirX, lineDirY, lineDirZ)));

    intersector.Perform(lines);

    int     nbPts = intersector.NbPoints(1); // 1-indexed
    int32_t count = 0;
    for (int i = 1; i <= nbPts && count < maxPoints; i++)
    {
      const LocOpe_PntFace& pf     = intersector.Point(1, i);
      outPoints[count].px          = pf.Pnt().X();
      outPoints[count].py          = pf.Pnt().Y();
      outPoints[count].pz          = pf.Pnt().Z();
      outPoints[count].parameter   = pf.Parameter();
      outPoints[count].uOnFace     = pf.UParameter();
      outPoints[count].vOnFace     = pf.VParameter();
      outPoints[count].orientation = (int32_t)pf.Orientation();
      count++;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef _Nullable OCCTLocOpeBuildShape(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    TopTools_ListOfShape faces;
    for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next())
    {
      faces.Append(exp.Current());
    }
    if (faces.Size() == 0)
      return nullptr;
    LocOpe_BuildShape bs(faces);
    TopoDS_Shape      result = bs.Shape();
    if (result.IsNull())
      return nullptr;
    auto* r  = new OCCTShape();
    r->shape = result;
    return r;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTLocOpeBuildWires(OCCTShapeRef shape,
                          int32_t      faceIndex,
                          OCCTShapeRef _Nullable* _Nullable* _Nonnull outWires,
                          int32_t* outCount)
{
  if (!shape)
    return false;
  try
  {
    // #541: the face index is 0-based, like Face.index. The "every edge of the shape"
    // sentinel used to be 0, which collided with the first face's own index and made that
    // face unaddressable; it is now any negative value.
    NCollection_List<TopoDS_Shape> edges;
    if (faceIndex >= 0)
    {
      TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
      if (face.IsNull())
        return false;
      TopExp_Explorer exp(face, TopAbs_EDGE);
      for (; exp.More(); exp.Next())
        edges.Append(exp.Current());
    }
    else
    {
      TopExp_Explorer exp(shape->shape, TopAbs_EDGE);
      for (; exp.More(); exp.Next())
        edges.Append(exp.Current());
    }

    Handle(LocOpe_WiresOnShape) wos = new LocOpe_WiresOnShape(shape->shape);
    LocOpe_BuildWires           bw(edges, wos);
    if (!bw.IsDone())
      return false;

    const NCollection_List<TopoDS_Shape>& result = bw.Result();
    int32_t                               n      = static_cast<int32_t>(result.Size());
    *outCount                                    = n;
    if (n == 0)
    {
      *outWires = nullptr;
      return true;
    }
    *outWires = (OCCTShapeRef*)malloc(n * sizeof(OCCTShapeRef));
    int32_t i = 0;
    for (auto it = result.cbegin(); it != result.cend(); ++it, ++i)
    {
      (*outWires)[i] = new OCCTShape(*it);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// #443 audit: first WIRE of the splitting shape only (the face is named by index, so that
// half is explicit). Singular by contract, since one wire splits one face. Documented on
// Shape.splitByWireOnFace rather than changed.
OCCTShapeRef _Nullable OCCTLocOpeSplitByWireOnFace(OCCTShapeRef shape,
                                                   OCCTShapeRef wire,
                                                   int32_t      faceIndex)
{
  // #1026: the wire's ShapeType() read below is an unguarded myTShape dereference.
  if (!occtShapeIsPresent(shape) || !occtShapeIsPresent(wire))
    return nullptr;
  try
  {
    // #541: 0-based, matching Face.index. It was 1-based, so face 0 was unaddressable.
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return nullptr;

    TopoDS_Wire w;
    if (wire->shape.ShapeType() == TopAbs_WIRE)
    {
      w = TopoDS::Wire(wire->shape);
    }
    else
    {
      TopExp_Explorer exp(wire->shape, TopAbs_WIRE);
      if (exp.More())
        w = TopoDS::Wire(exp.Current());
      else
        return nullptr;
    }

    Handle(LocOpe_WiresOnShape) wos = new LocOpe_WiresOnShape(shape->shape);
    wos->Bind(w, face);
    wos->BindAll();

    LocOpe_Spliter spliter(shape->shape);
    spliter.Perform(wos);
    if (!spliter.IsDone())
      return nullptr;

    return new OCCTShape(spliter.ResultingShape());
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTLocOpeCurveShapeIntersectLine(OCCTShapeRef shape,
                                       double       ox,
                                       double       oy,
                                       double       oz,
                                       double       dx,
                                       double       dy,
                                       double       dz,
                                       double* _Nullable* _Nonnull outParams,
                                       int32_t* outCount)
{
  if (!shape)
    return false;
  try
  {
    gp_Ax1                       axis(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz));
    LocOpe_CurveShapeIntersector csi(axis, shape->shape);
    if (!csi.IsDone())
      return false;
    int32_t n = csi.NbPoints();
    *outCount = n;
    if (n == 0)
    {
      *outParams = nullptr;
      return true;
    }
    *outParams = (double*)malloc(n * sizeof(double));
    for (int32_t i = 0; i < n; i++)
    {
      const LocOpe_PntFace& pf = csi.Point(i + 1);
      (*outParams)[i]          = pf.Parameter();
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef _Nullable OCCTBRepFeatBuilderFuse(OCCTShapeRef shape, OCCTShapeRef tool)
{
  if (!shape || !tool)
    return nullptr;
  try
  {
    BRepFeat_Builder builder;
    builder.Init(shape->shape, tool->shape);
    builder.SetOperation(1); // Fuse
    TopTools_ListOfShape parts;
    builder.PartsOfTool(parts);
    for (auto it = parts.begin(); it != parts.end(); ++it)
    {
      builder.KeepPart(*it);
    }
    builder.PerformResult();
    if (builder.HasErrors())
      return nullptr;
    TopoDS_Shape result = builder.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepFeatBuilderCut(OCCTShapeRef shape, OCCTShapeRef tool)
{
  if (!shape || !tool)
    return nullptr;
  try
  {
    BRepFeat_Builder builder;
    builder.Init(shape->shape, tool->shape);
    builder.SetOperation(0); // Cut
    TopTools_ListOfShape parts;
    builder.PartsOfTool(parts);
    // For cut, keep NO parts of tool (remove all)
    builder.PerformResult();
    if (builder.HasErrors())
      return nullptr;
    TopoDS_Shape result = builder.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeEdge(OCCTShapeRef _Nonnull shape,
                                                  OCCTShapeRef _Nonnull edge,
                                                  OCCTShapeRef _Nonnull face)
{
  try
  {
    BRepFeat_SplitShape splitter(shape->shape);
    splitter.Add(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
    splitter.Build();
    if (!splitter.IsDone())
      return nullptr;
    TopoDS_Shape result = splitter.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeWire(OCCTShapeRef _Nonnull shape,
                                                  OCCTShapeRef _Nonnull wire,
                                                  OCCTShapeRef _Nonnull face)
{
  try
  {
    BRepFeat_SplitShape splitter(shape->shape);
    splitter.Add(TopoDS::Wire(wire->shape), TopoDS::Face(face->shape));
    splitter.Build();
    if (!splitter.IsDone())
      return nullptr;
    TopoDS_Shape result = splitter.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeWithSides(
  OCCTShapeRef _Nonnull shape,
  const OCCTShapeRef _Nonnull* _Nonnull edgesOnFaces,
  int32_t pairCount,
  OCCTShapeRef _Nullable* _Nullable* _Nonnull outLeft,
  int32_t* _Nonnull outLeftCount,
  OCCTShapeRef _Nullable* _Nullable* _Nonnull outRight,
  int32_t* _Nonnull outRightCount)
{
  *outLeft       = nullptr;
  *outLeftCount  = 0;
  *outRight      = nullptr;
  *outRightCount = 0;
  try
  {
    BRepFeat_SplitShape splitter(shape->shape);
    for (int32_t i = 0; i < pairCount; i++)
    {
      // #1026: per element, since a guard on one array slot says nothing about the next. The
      // whole call is refused rather than the pair skipped, matching OCCTMakeWireFromEdges (#1008):
      // a silently dropped pair is a split the caller asked for and did not get.
      if (!occtShapeIsPresent(edgesOnFaces[i * 2]) || !occtShapeIsPresent(edgesOnFaces[i * 2 + 1]))
        return nullptr;
      TopoDS_Shape edgeOrWire = edgesOnFaces[i * 2]->shape;
      TopoDS_Face  face       = TopoDS::Face(edgesOnFaces[i * 2 + 1]->shape);
      if (edgeOrWire.ShapeType() == TopAbs_WIRE)
      {
        splitter.Add(TopoDS::Wire(edgeOrWire), face);
      }
      else
      {
        splitter.Add(TopoDS::Edge(edgeOrWire), face);
      }
    }
    splitter.Build();
    if (!splitter.IsDone())
      return nullptr;
    TopoDS_Shape result = splitter.Shape();
    if (result.IsNull())
      return nullptr;

    // Left faces
    const TopTools_ListOfShape& leftList = splitter.Left();
    int32_t                     nl       = static_cast<int32_t>(leftList.Size());
    *outLeftCount                        = nl;
    if (nl > 0)
    {
      *outLeft    = (OCCTShapeRef*)malloc(nl * sizeof(OCCTShapeRef));
      int32_t idx = 0;
      for (auto it = leftList.cbegin(); it != leftList.cend(); ++it, ++idx)
      {
        (*outLeft)[idx] = new OCCTShape(*it);
      }
    }

    // Right faces
    const TopTools_ListOfShape& rightList = splitter.Right();
    int32_t                     nr        = static_cast<int32_t>(rightList.Size());
    *outRightCount                        = nr;
    if (nr > 0)
    {
      *outRight   = (OCCTShapeRef*)malloc(nr * sizeof(OCCTShapeRef));
      int32_t idx = 0;
      for (auto it = rightList.cbegin(); it != rightList.cend(); ++it, ++idx)
      {
        (*outRight)[idx] = new OCCTShape(*it);
      }
    }

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepFeatCylindricalHole(OCCTShapeRef _Nonnull shape,
                                                   double  axisOriginX,
                                                   double  axisOriginY,
                                                   double  axisOriginZ,
                                                   double  axisDirX,
                                                   double  axisDirY,
                                                   double  axisDirZ,
                                                   double  radius,
                                                   int32_t extent,
                                                   double  extentP0,
                                                   double  extentP1)
{
  OCCTShapeRef result = nullptr;
  occtBRepFeatCylindricalHole(shape,
                              axisOriginX,
                              axisOriginY,
                              axisOriginZ,
                              axisDirX,
                              axisDirY,
                              axisDirZ,
                              radius,
                              extent,
                              extentP0,
                              extentP1,
                              &result);
  return result;
}

int32_t OCCTBRepFeatCylindricalHoleStatus(OCCTShapeRef _Nonnull shape,
                                          double  axisOriginX,
                                          double  axisOriginY,
                                          double  axisOriginZ,
                                          double  axisDirX,
                                          double  axisDirY,
                                          double  axisDirZ,
                                          double  radius,
                                          int32_t extent,
                                          double  extentP0,
                                          double  extentP1)
{
  return occtBRepFeatCylindricalHole(shape,
                                     axisOriginX,
                                     axisOriginY,
                                     axisOriginZ,
                                     axisDirX,
                                     axisDirY,
                                     axisDirZ,
                                     radius,
                                     extent,
                                     extentP0,
                                     extentP1,
                                     nullptr);
}

OCCTShapeRef _Nullable OCCTBRepFeatGluer(OCCTShapeRef _Nonnull baseShape,
                                         OCCTShapeRef _Nonnull gluedShape,
                                         const OCCTShapeRef _Nonnull* _Nonnull baseFaces,
                                         const OCCTShapeRef _Nonnull* _Nonnull gluedFaces,
                                         int32_t faceCount)
{
  try
  {
    BRepFeat_Gluer gluer(gluedShape->shape, baseShape->shape);
    for (int32_t i = 0; i < faceCount; i++)
    {
      gluer.Bind(TopoDS::Face(gluedFaces[i]->shape), TopoDS::Face(baseFaces[i]->shape));
    }
    gluer.Build();
    if (!gluer.IsDone())
      return nullptr;
    TopoDS_Shape result = gluer.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// #443 audit: each (wire, face) pair contributes only its first wire. The pair list is
// already the place to name several wires, so this is singular by contract; documented on
// Shape.locOpeSplit(wiresOnFaces:) rather than changed.
OCCTShapeRef _Nullable OCCTLocOpeSplitByWires(
  OCCTShapeRef _Nonnull shape,
  const OCCTShapeRef _Nonnull* _Nonnull wiresOnFaces,
  int32_t pairCount,
  OCCTShapeRef _Nullable* _Nullable* _Nonnull outDirectLeft,
  int32_t* _Nonnull outDirectLeftCount)
{
  *outDirectLeft      = nullptr;
  *outDirectLeftCount = 0;
  try
  {
    Handle(LocOpe_WiresOnShape) wos = new LocOpe_WiresOnShape(shape->shape);
    for (int32_t i = 0; i < pairCount; i++)
    {
      // #1026: per element, same reasoning as OCCTBRepFeatSplitShapeWithSides above.
      if (!occtShapeIsPresent(wiresOnFaces[i * 2]) || !occtShapeIsPresent(wiresOnFaces[i * 2 + 1]))
        return nullptr;
      TopoDS_Wire         w;
      const TopoDS_Shape& ws = wiresOnFaces[i * 2]->shape;
      if (ws.ShapeType() == TopAbs_WIRE)
      {
        w = TopoDS::Wire(ws);
      }
      else
      {
        TopExp_Explorer exp(ws, TopAbs_WIRE);
        if (exp.More())
          w = TopoDS::Wire(exp.Current());
        else
          continue;
      }
      TopoDS_Face f = TopoDS::Face(wiresOnFaces[i * 2 + 1]->shape);
      wos->Bind(w, f);
    }

    LocOpe_Spliter spliter(shape->shape);
    spliter.Perform(wos);
    if (!spliter.IsDone())
      return nullptr;

    const TopoDS_Shape& result = spliter.ResultingShape();
    if (result.IsNull())
      return nullptr;

    // Direct left faces
    const TopTools_ListOfShape& dl = spliter.DirectLeft();
    int32_t                     n  = static_cast<int32_t>(dl.Size());
    *outDirectLeftCount            = n;
    if (n > 0)
    {
      *outDirectLeft = (OCCTShapeRef*)malloc(n * sizeof(OCCTShapeRef));
      int32_t idx    = 0;
      for (auto it = dl.cbegin(); it != dl.cend(); ++it, ++idx)
      {
        (*outDirectLeft)[idx] = new OCCTShape(*it);
      }
    }

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTLocOpeSplitByWiresAuto(OCCTShapeRef _Nonnull shape,
                                                  const OCCTShapeRef _Nonnull* _Nonnull wires,
                                                  int32_t wireCount)
{
  try
  {
    Handle(LocOpe_WiresOnShape) wos = new LocOpe_WiresOnShape(shape->shape);
    for (int32_t i = 0; i < wireCount; i++)
    {
      const TopoDS_Shape& ws = wires[i]->shape;
      // Add edges from each wire as a sequence
      NCollection_Sequence<TopoDS_Shape> edgeSeq;
      TopExp_Explorer                    exp(ws, TopAbs_EDGE);
      for (; exp.More(); exp.Next())
      {
        edgeSeq.Append(exp.Current());
      }
      if (edgeSeq.Length() > 0)
      {
        wos->Add(edgeSeq);
      }
    }
    wos->BindAll();

    LocOpe_Spliter spliter(shape->shape);
    spliter.Perform(wos);
    if (!spliter.IsDone())
      return nullptr;

    const TopoDS_Shape& result = spliter.ResultingShape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTLocOpeGlue(OCCTShapeRef _Nonnull baseShape,
                                      OCCTShapeRef _Nonnull gluedShape,
                                      const OCCTShapeRef _Nonnull* _Nonnull baseFaces,
                                      const OCCTShapeRef _Nonnull* _Nonnull gluedFaces,
                                      int32_t faceCount,
                                      const OCCTShapeRef _Nullable* _Nullable baseEdges,
                                      const OCCTShapeRef _Nullable* _Nullable gluedEdges,
                                      int32_t edgeCount)
{
  try
  {
    LocOpe_Gluer gluer(baseShape->shape, gluedShape->shape);
    for (int32_t i = 0; i < faceCount; i++)
    {
      gluer.Bind(TopoDS::Face(gluedFaces[i]->shape), TopoDS::Face(baseFaces[i]->shape));
    }
    if (baseEdges && gluedEdges)
    {
      for (int32_t i = 0; i < edgeCount; i++)
      {
        if (baseEdges[i] && gluedEdges[i])
        {
          gluer.Bind(TopoDS::Edge(gluedEdges[i]->shape), TopoDS::Edge(baseEdges[i]->shape));
        }
      }
    }
    gluer.Perform();
    if (!gluer.IsDone())
      return nullptr;
    const TopoDS_Shape& result = gluer.ResultingShape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeDraftModification(OCCTShapeRef shape,
                                        int32_t      faceIndex,
                                        double       dirX,
                                        double       dirY,
                                        double       dirZ,
                                        double       angle,
                                        double       planeOX,
                                        double       planeOY,
                                        double       planeOZ,
                                        double       planeNX,
                                        double       planeNY,
                                        double       planeNZ)
{
  if (!shape)
    return nullptr;
  try
  {
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return nullptr;

    Handle(Draft_Modification) draft = new Draft_Modification(shape->shape);
    draft->Add(face,
               gp_Dir(dirX, dirY, dirZ),
               angle,
               gp_Pln(gp_Pnt(planeOX, planeOY, planeOZ), gp_Dir(planeNX, planeNY, planeNZ)));
    draft->Perform();
    if (!draft->IsDone())
      return nullptr;

    BRepTools_Modifier modifier(shape->shape, draft);
    if (!modifier.IsDone())
      return nullptr;
    TopoDS_Shape result = modifier.ModifiedShape(shape->shape);
    if (result.IsNull())
      return nullptr;
    OCCTShape* r = new OCCTShape();
    r->shape     = result;
    return r;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool occtDefeaturingFacesByIndex(const TopoDS_Shape&   shape,
                                 const int32_t*        faceIndices,
                                 int32_t               faceCount,
                                 TopTools_ListOfShape& outFaces)
{
  if (!faceIndices || faceCount <= 0)
    return false;

  try
  {
    // Build a map of faces in the shape (1-based index -> face)
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape, TopAbs_FACE, faceMap);

    if (faceMap.Extent() == 0)
      return false;

    for (int32_t i = 0; i < faceCount; i++)
    {
      // Swift passes 0-based indices (Face.index from wrapSubShapeEnumeration)
      // Convert to 1-based for TopTools_IndexedMapOfShape
      int32_t idx = faceIndices[i] + 1;
      if (idx < 1 || idx > faceMap.Extent())
        return false; // out of range - fail the whole request
      outFaces.Append(faceMap.FindKey(idx));
    }

    return outFaces.Extent() == faceCount;
  }
  catch (...)
  {
    return false;
  }
}

bool occtDefeaturingFacesFromShapes(const TopoDS_Shape&     shape,
                                    const OCCTShape* const* faces,
                                    int32_t                 faceCount,
                                    TopTools_ListOfShape&   outFaces)
{
  if (!faces || faceCount <= 0)
    return false;

  try
  {
    // Build a map of faces in the input shape for membership testing (IsSame)
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape, TopAbs_FACE, faceMap);

    if (faceMap.Extent() == 0)
      return false;

    for (int32_t i = 0; i < faceCount; i++)
    {
      const OCCTShape* carrier = faces[i];
      if (!carrier)
        return false; // null element - fail the whole request

      // Explode the carrier for faces
      TopExp_Explorer explorer(carrier->shape, TopAbs_FACE);
      bool            foundAny = false;
      while (explorer.More())
      {
        TopoDS_Face face = TopoDS::Face(explorer.Current());
        // Check if this face belongs to the input shape (IsSame via indexed map)
        if (!faceMap.Contains(face))
        {
          return false; // carrier contains a face not in the input shape - fail entire call
        }
        outFaces.Append(face);
        foundAny = true;
        explorer.Next();
      }
      if (!foundAny)
        return false; // carrier contributed no faces from the input shape
    }

    return outFaces.Extent() > 0;
  }
  catch (...)
  {
    return false;
  }
}
