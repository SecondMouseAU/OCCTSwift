//
//  OCCTBridge_Modeling_Sweep.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Modeling.mm (#396/#819): BRepOffsetAPI, BRepFill, Law, Filling,
//  ThruSections, PipeShell. Public C surface unchanged; imports the same OCCTBridge_Modeling.h
//  every sibling file does. No symbol changes, pure file move -- see
//  Scripts/repro/396-modeling-mm-split/ for how.
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

OCCTShapeRef OCCTShapeMiddlePath(OCCTShapeRef shape, OCCTShapeRef startShape, OCCTShapeRef endShape)
{
  if (!shape || !startShape || !endShape)
    return nullptr;
  try
  {
    BRepOffsetAPI_MiddlePath builder(shape->shape, startShape->shape, endShape->shape);
    builder.Build();
    if (!builder.IsDone())
      return nullptr;
    return new OCCTShape(builder.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeOffsetByJoin(OCCTShapeRef shape,
                                   double       distance,
                                   double       tolerance,
                                   int32_t      joinType,
                                   bool         removeInternalEdges)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepOffsetAPI_MakeOffsetShape offsetter;
    GeomAbs_JoinType              join = GeomAbs_Arc;
    if (joinType == 1)
      join = GeomAbs_Tangent;
    else if (joinType == 2)
      join = GeomAbs_Intersection;
    offsetter.PerformByJoin(shape->shape,
                            distance,
                            tolerance,
                            BRepOffset_Skin,
                            false,
                            false,
                            join,
                            removeInternalEdges);
    if (!offsetter.IsDone())
      return nullptr;
    return new OCCTShape(offsetter.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTWireMultiOffset(OCCTShapeRef  face,
                            const double* offsets,
                            int32_t       count,
                            int32_t       joinType,
                            OCCTWireRef*  outWires,
                            int32_t       maxWires)
{
  if (!face || !offsets || count < 1 || !outWires || maxWires < 1)
    return 0;
  try
  {
    // Extract the face from the shape
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(face->shape, TopAbs_FACE, faceMap);
    if (faceMap.Extent() < 1)
      return 0;
    TopoDS_Face topoFace = TopoDS::Face(faceMap(1));

    GeomAbs_JoinType join = GeomAbs_Arc;
    if (joinType == 1)
      join = GeomAbs_Tangent;
    else if (joinType == 2)
      join = GeomAbs_Intersection;

    BRepOffsetAPI_MakeOffset offsetMaker(topoFace, join);

    int32_t totalWires = 0;
    for (int32_t i = 0; i < count && totalWires < maxWires; ++i)
    {
      offsetMaker.Perform(offsets[i]);
      if (!offsetMaker.IsDone())
        continue;
      TopoDS_Shape result = offsetMaker.Shape();
      // Extract wires from the result
      TopExp_Explorer wireExp(result, TopAbs_WIRE);
      while (wireExp.More() && totalWires < maxWires)
      {
        outWires[totalWires] = new OCCTWire(TopoDS::Wire(wireExp.Current()));
        totalWires++;
        wireExp.Next();
      }
    }
    return totalWires;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTShapeCreateEvolvedAdvanced(OCCTShapeRef spine,
                                            OCCTWireRef  profile,
                                            int32_t      joinType,
                                            bool         axeProf,
                                            bool         solid,
                                            bool         volume,
                                            double       tolerance)
{
  if (!spine || !profile)
    return nullptr;
  try
  {
    GeomAbs_JoinType join = GeomAbs_Arc;
    if (joinType == 1)
      join = GeomAbs_Tangent;
    else if (joinType == 2)
      join = GeomAbs_Intersection;
    BRepOffsetAPI_MakeEvolved
      evolved(spine->shape, profile->wire, join, axeProf, solid, false, tolerance, volume, false);
    if (!evolved.IsDone())
      return nullptr;
    TopoDS_Shape result = evolved.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCreateEvolved(OCCTWireRef spine, OCCTWireRef profile)
{
  if (!spine || !profile)
    return nullptr;

  try
  {
    BRepOffsetAPI_MakeEvolved evolved(spine->wire, profile->wire);
    if (!evolved.IsDone())
      return nullptr;

    TopoDS_Shape result = evolved.Shape();
    if (result.IsNull())
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTLawFunctionRelease(OCCTLawFunctionRef l)
{
  delete l;
}

double OCCTLawFunctionValue(OCCTLawFunctionRef l, double param)
{
  if (!l || l->law.IsNull())
    return 0.0;
  try
  {
    return l->law->Value(param);
  }
  catch (...)
  {
    return 0.0;
  }
}

void OCCTLawFunctionBounds(OCCTLawFunctionRef l, double* first, double* last)
{
  if (!l || l->law.IsNull() || !first || !last)
    return;
  try
  {
    l->law->Bounds(*first, *last);
  }
  catch (...)
  {
    *first = 0;
    *last  = 0;
  }
}

OCCTLawFunctionRef OCCTLawCreateConstant(double value, double first, double last)
{
  try
  {
    Handle(Law_Constant) law = new Law_Constant();
    law->Set(value, first, last);
    return new OCCTLawFunction(law);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTLawFunctionRef OCCTLawCreateLinear(double first, double startVal, double last, double endVal)
{
  try
  {
    Handle(Law_Linear) law = new Law_Linear();
    law->Set(first, startVal, last, endVal);
    return new OCCTLawFunction(law);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTLawFunctionRef OCCTLawCreateS(double first, double startVal, double last, double endVal)
{
  try
  {
    Handle(Law_S) law = new Law_S();
    law->Set(first, startVal, last, endVal);
    return new OCCTLawFunction(law);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTLawFunctionRef OCCTLawCreateInterpolate(const double* paramValues, int32_t count, bool periodic)
{
  if (!paramValues || count < 2)
    return nullptr;
  try
  {
    TColgp_Array1OfPnt2d pts(1, count);
    for (int32_t i = 0; i < count; i++)
    {
      pts.SetValue(i + 1, gp_Pnt2d(paramValues[i * 2], paramValues[i * 2 + 1]));
    }
    Handle(Law_Interpol) law = new Law_Interpol();
    law->Set(pts, periodic ? Standard_True : Standard_False);
    return new OCCTLawFunction(law);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTLawFunctionRef OCCTLawCreateBSpline(const double*  poles,
                                        int32_t        poleCount,
                                        const double*  knots,
                                        int32_t        knotCount,
                                        const int32_t* multiplicities,
                                        int32_t        degree)
{
  if (!poles || !knots || !multiplicities || poleCount < 2 || knotCount < 2)
    return nullptr;
  try
  {
    TColStd_Array1OfReal poleArr(1, poleCount);
    for (int32_t i = 0; i < poleCount; i++)
      poleArr.SetValue(i + 1, poles[i]);

    TColStd_Array1OfReal knotArr(1, knotCount);
    for (int32_t i = 0; i < knotCount; i++)
      knotArr.SetValue(i + 1, knots[i]);

    TColStd_Array1OfInteger multArr(1, knotCount);
    for (int32_t i = 0; i < knotCount; i++)
      multArr.SetValue(i + 1, multiplicities[i]);

    Handle(Law_BSpline) bsp = new Law_BSpline(poleArr, knotArr, multArr, degree);
    Handle(Law_BSpFunc) law = new Law_BSpFunc(bsp, knots[0], knots[knotCount - 1]);
    return new OCCTLawFunction(law);
  }
  catch (...)
  {
    return nullptr;
  }
}

// The one pipe shell that is not an Add() sweep: SetLaw scales a single profile along the
// spine, and OCCT's own header warns against combining the two. It shares the build tail
// (and so the build-history workaround) with OCCTShapeCreatePipeShellMultiSection.
OCCTShapeRef OCCTShapeCreatePipeShellWithLaw(OCCTWireRef        spine,
                                             OCCTWireRef        profile,
                                             OCCTLawFunctionRef law,
                                             bool               solid)
{
  if (!spine || !profile || !law || law->law.IsNull())
    return nullptr;
  try
  {
    BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);
    // Standard_False -> corrected Frenet (#598 found this comment claiming plain Frenet,
    // which SetMode's own IsFrenet parameter does not: no public mode parameter reaches
    // this entry point, so the trihedron itself is unchanged, only the comment was wrong).
    pipeShell.SetMode(Standard_False); // corrected Frenet
    pipeShell.SetLaw(profile->wire, law->law, Standard_False, Standard_False);
    return occtPipeShellFinish(pipeShell, solid);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Record a refused constraint and report the refusal to the caller, in one expression.
// Refusing with a null handle is not recordable, so it is only reported.
static bool OCCTFillingRefuse(OCCTFillingRef filling)
{
  if (filling)
    filling->refusedCount++;
  return false;
}

OCCTFillingRef OCCTFillingCreate(int32_t degree,
                                 int32_t nbPtsOnCur,
                                 int32_t maxDegree,
                                 int32_t maxSegments,
                                 double  tolerance3d)
{
  try
  {
    // Aggregate-initializing filler directly from occtFillingMakeBuilder's returned prvalue
    // is covered by the same guaranteed-copy-elision guarantee that function's own comment
    // documents: no copy or move of the BRepOffsetAPI_MakeFilling is performed here either.
    return new OCCTFilling{
      occtFillingMakeBuilder(degree, nbPtsOnCur, maxDegree, maxSegments, tolerance3d)};
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTFillingRelease(OCCTFillingRef filling)
{
  delete filling;
}

// #432/#433: route through occtFillingAddConstraint rather than calling the face-less
// BRepOffsetAPI_MakeFilling::Add(edge, order) overload directly, which SIGSEGVs on any curved
// boundary edge for continuity above C0 (see OCCTBridge_Internal.h and issue #430 for the
// mechanism); and use occtGeomAbsFromSurfaceContinuity for the order mapping rather than a local
// copy, the local one that used to be here mapped order 1 to GeomAbs_C1 (curvature) instead of
// GeomAbs_G1 (tangency) and order 2 to GeomAbs_C2 (ordinal 4, rejected outright), failing the
// whole fill (#433). Note Add() only appends and never validates the order itself, so returning
// true here says nothing about the constraint's validity, a bad order still only surfaces as a
// nil Build() later.
bool OCCTFillingAddEdge(OCCTFillingRef filling, OCCTEdgeRef edge, int32_t continuity)
{
  if (!filling)
    return false;
  if (!edge)
    return OCCTFillingRefuse(filling);
  try
  {
    occtFillingAddConstraint(filling->filler,
                             edge->edge,
                             TopoDS_Face(),
                             OCCTFillingSupport::Inferred,
                             occtGeomAbsFromSurfaceContinuity(continuity),
                             /*isBound=*/true);
    return true;
  }
  catch (...)
  {
    return OCCTFillingRefuse(filling);
  }
}

bool OCCTFillingAddFreeEdge(OCCTFillingRef filling, OCCTEdgeRef edge, int32_t continuity)
{
  if (!filling)
    return false;
  if (!edge)
    return OCCTFillingRefuse(filling);
  try
  {
    occtFillingAddConstraint(filling->filler,
                             edge->edge,
                             TopoDS_Face(),
                             OCCTFillingSupport::Inferred,
                             occtGeomAbsFromSurfaceContinuity(continuity),
                             /*isBound=*/false);
    return true;
  }
  catch (...)
  {
    return OCCTFillingRefuse(filling);
  }
}

// #434: gives FillingSurface the same explicit-support-face capability
// Shape.fill(constraints:)/FillConstraint already has. A face named here is Nominated: if it
// cannot carry `edge`'s continuity, the constraint is not added and the whole fill fails,
// matching OCCTShapeFillConstraints, which returns NULL on that same refusal (#482).
bool OCCTFillingAddEdgeWithSupport(OCCTFillingRef filling,
                                   OCCTEdgeRef    edge,
                                   OCCTFaceRef    support,
                                   int32_t        continuity)
{
  if (!filling)
    return false;
  if (!edge)
    return OCCTFillingRefuse(filling);
  try
  {
    TopoDS_Face supportFace;
    if (support)
      supportFace = support->face;
    if (!occtFillingAddConstraint(filling->filler,
                                  edge->edge,
                                  supportFace,
                                  support ? OCCTFillingSupport::Nominated
                                          : OCCTFillingSupport::Inferred,
                                  occtGeomAbsFromSurfaceContinuity(continuity),
                                  /*isBound=*/true))
    {
      return OCCTFillingRefuse(filling);
    }
    return true;
  }
  catch (...)
  {
    return OCCTFillingRefuse(filling);
  }
}

bool OCCTFillingAddPoint(OCCTFillingRef filling, double x, double y, double z)
{
  if (!filling)
    return false;
  try
  {
    filling->filler.Add(gp_Pnt(x, y, z));
    return true;
  }
  catch (...)
  {
    return OCCTFillingRefuse(filling);
  }
}

int32_t OCCTFillingRefusedConstraintCount(OCCTFillingRef filling)
{
  return filling ? filling->refusedCount : 0;
}

// #482: a refused Add* fails the build outright rather than fitting a surface to whatever did
// make it in. The one-shot entry point has always behaved this way: OCCTShapeFillConstraints
// returns NULL the moment occtFillingAddConstraint refuses a nominated support face. The
// incremental one carried on, so the same geometry answered differently depending on which API
// the caller reached for, and the difference was a plausible-looking face that neither passed
// through nor was bounded by the constraint the caller cared most about.
//
// Build() is not attempted at all, so IsDone() stays false and the face/error accessors keep
// reporting "not built" rather than describing a surface no caller asked for.
bool OCCTFillingBuild(OCCTFillingRef filling)
{
  if (!filling || filling->refusedCount > 0)
    return false;
  try
  {
    filling->filler.Build();
    return filling->filler.IsDone();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFillingIsDone(OCCTFillingRef filling)
{
  if (!filling)
    return false;
  return filling->filler.IsDone();
}

OCCTShapeRef OCCTFillingGetFace(OCCTFillingRef filling)
{
  if (!filling || !filling->filler.IsDone())
    return nullptr;
  try
  {
    // BRepOffsetAPI_MakeFilling has no Face() of its own (BRepFill_Filling's accessor);
    // Shape() is BRepBuilderAPI_MakeShape's, and Build() sets it to the same face.
    TopoDS_Shape result = filling->filler.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTFillingG0Error(OCCTFillingRef filling)
{
  if (!filling || !filling->filler.IsDone())
    return -1.0;
  try
  {
    return filling->filler.G0Error();
  }
  catch (...)
  {
    return -1.0;
  }
}

double OCCTFillingG1Error(OCCTFillingRef filling)
{
  if (!filling || !filling->filler.IsDone())
    return -1.0;
  try
  {
    return filling->filler.G1Error();
  }
  catch (...)
  {
    return -1.0;
  }
}

double OCCTFillingG2Error(OCCTFillingRef filling)
{
  if (!filling || !filling->filler.IsDone())
    return -1.0;
  try
  {
    return filling->filler.G2Error();
  }
  catch (...)
  {
    return -1.0;
  }
}

// MARK: - BRepFill Generator/Evolved/Offset/Draft/Pipe/Compatible (v0.52)
OCCTShapeRef _Nullable OCCTBRepFillGenerator(const OCCTWireRef _Nonnull* _Nonnull wires,
                                             int32_t count)
{
  if (!wires || count < 2)
    return nullptr;
  try
  {
    BRepFill_Generator gen;
    for (int i = 0; i < count; i++)
    {
      if (!wires[i])
        return nullptr;
      gen.AddWire(wires[i]->wire);
    }
    gen.Perform();
    TopoDS_Shell shell = gen.Shell();
    if (shell.IsNull())
      return nullptr;
    auto* result  = new OCCTShape();
    result->shape = shell;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepFillAdvancedEvolved(OCCTWireRef spine,
                                                   OCCTWireRef profile,
                                                   double      tolerance,
                                                   bool        solidReq)
{
  if (!spine || !profile)
    return nullptr;
  try
  {
    BRepFill_AdvancedEvolved ae;
    ae.Perform(spine->wire, profile->wire, tolerance, solidReq);
    if (!ae.IsDone())
      return nullptr;
    TopoDS_Shape shape = ae.Shape();
    if (shape.IsNull())
      return nullptr;
    auto* result  = new OCCTShape();
    result->shape = shape;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepFillOffsetWire(OCCTFaceRef faceRef, double offset)
{
  if (!faceRef)
    return nullptr;
  try
  {
    BRepFill_OffsetWire ow(faceRef->face, GeomAbs_Arc, false);
    ow.Perform(offset);
    if (!ow.IsDone())
      return nullptr;
    TopoDS_Shape shape = ow.Shape();
    if (shape.IsNull())
      return nullptr;
    auto* result  = new OCCTShape();
    result->shape = shape;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepFillDraft(OCCTWireRef wire,
                                         double      dirX,
                                         double      dirY,
                                         double      dirZ,
                                         double      angle,
                                         double      length)
{
  if (!wire)
    return nullptr;
  try
  {
    gp_Dir         dir(dirX, dirY, dirZ);
    BRepFill_Draft draft(wire->wire, dir, angle);
    draft.Perform(length);
    if (!draft.IsDone())
      return nullptr;
    TopoDS_Shape shape = draft.Shape();
    if (shape.IsNull())
      return nullptr;
    auto* result  = new OCCTShape();
    result->shape = shape;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBRepFillPipeResult OCCTBRepFillPipe(OCCTWireRef spine, OCCTWireRef profile)
{
  OCCTBRepFillPipeResult result = {};
  if (!spine || !profile)
    return result;
  try
  {
    BRepFill_Pipe pipe(spine->wire, profile->wire, GeomFill_IsCorrectedFrenet, false, false);
    TopoDS_Shape  shape = pipe.Shape();
    if (shape.IsNull())
      return result;
    result.errorOnSurface = pipe.ErrorOnSurface();
    auto* s               = new OCCTShape();
    s->shape              = shape;
    result.shape          = s;
    return result;
  }
  catch (...)
  {
    return result;
  }
}

int32_t OCCTBRepFillCompatibleWires(const OCCTWireRef _Nonnull* _Nonnull wires,
                                    int32_t count,
                                    OCCTWireRef _Nullable* _Nonnull outWires)
{
  if (!wires || count < 2 || !outWires)
    return 0;
  try
  {
    NCollection_Sequence<TopoDS_Shape> sections;
    for (int i = 0; i < count; i++)
    {
      if (!wires[i])
        return 0;
      sections.Append(wires[i]->wire);
    }
    BRepFill_CompatibleWires cw(sections);
    cw.Perform();
    if (!cw.IsDone())
      return 0;
    auto&   result = cw.Shape();
    int32_t n      = (int32_t)result.Size();
    if (n > count)
      n = count;
    for (int i = 0; i < n; i++)
    {
      TopoDS_Wire w       = TopoDS::Wire(result.Value(i + 1)); // 1-indexed
      auto*       wireObj = new OCCTWire();
      wireObj->wire       = w;
      outWires[i]         = wireObj;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// #481: reports the true split count even when maxIndices truncated the write, and fails
// with -1, matching OCCTLawBSplineKnotSplitParams below in both respects. The two wrap the
// same analyzer over the same law, so a caller pairing them must be able to size a retry off
// either one. Returning the written count instead capped LawFunction.knotSplitting at its
// caller's first-pass buffer with nothing to signal that anything had been dropped.
int32_t OCCTLawBSplineKnotSplitting(OCCTLawFunctionRef law,
                                    int32_t            continuityOrder,
                                    int32_t*           outIndices,
                                    int32_t            maxIndices)
{
  if (!law || !outIndices || maxIndices <= 0)
    return -1;
  try
  {
    auto* wrapper = reinterpret_cast<OCCTLawFunction*>(law);
    // The law must be a BSpline-based law (Law_BSpFunc or similar)
    Handle(Law_BSpFunc) bspFunc = Handle(Law_BSpFunc)::DownCast(wrapper->law);
    if (bspFunc.IsNull())
      return -1;

    Handle(Law_BSpline) bspl = bspFunc->Curve();
    if (bspl.IsNull())
      return -1;

    Law_BSplineKnotSplitting splitter(bspl, continuityOrder);
    return occtWriteKnotSplits<int32_t>(
      splitter.NbSplits(),
      [&](int32_t i) { return (int32_t)splitter.SplitValue(i); },
      outIndices,
      maxIndices);
  }
  catch (...)
  {
    return -1;
  }
}

// #403: same analyzer as above, but converts each split's knot-table index to an actual
// parameter value via Law_BSpline::Knot(); raw indices are otherwise uninterpretable
// since the public API exposes no way to read the law's own knot vector.
int32_t OCCTLawBSplineKnotSplitParams(OCCTLawFunctionRef law,
                                      int32_t            continuityOrder,
                                      double*            outParams,
                                      int32_t            maxParams)
{
  if (!law || !outParams || maxParams <= 0)
    return -1;
  try
  {
    auto*               wrapper = reinterpret_cast<OCCTLawFunction*>(law);
    Handle(Law_BSpFunc) bspFunc = Handle(Law_BSpFunc)::DownCast(wrapper->law);
    if (bspFunc.IsNull())
      return -1;

    Handle(Law_BSpline) bspl = bspFunc->Curve();
    if (bspl.IsNull())
      return -1;

    Law_BSplineKnotSplitting splitter(bspl, continuityOrder);
    return occtWriteKnotSplitParams(
      splitter.NbSplits(),
      [&](int32_t i) { return splitter.SplitValue(i); },
      [&](int32_t idx) { return bspl->Knot(idx); },
      outParams,
      maxParams);
  }
  catch (...)
  {
    return -1;
  }
}

OCCTLawFunctionRef OCCTLawComposite(const OCCTLawFunctionRef* lawRefs,
                                    int32_t                   count,
                                    double                    first,
                                    double                    last)
{
  try
  {
    Handle(Law_Composite)                   composite = new Law_Composite(first, last, 1.0e-6);
    NCollection_List<Handle(Law_Function)>& laws      = composite->ChangeLaws();
    for (int32_t i = 0; i < count; i++)
    {
      auto* wrapper = reinterpret_cast<OCCTLawFunction*>(lawRefs[i]);
      laws.Append(wrapper->law);
    }

    auto* result = new OCCTLawFunction();
    result->law  = composite;
    return reinterpret_cast<OCCTLawFunctionRef>(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - BRepFill_Evolved (v0.79)
// --- BRepFill_Evolved ---
OCCTShapeRef _Nullable OCCTBRepFillEvolved(OCCTShapeRef _Nonnull spineFaceRef,
                                           OCCTShapeRef _Nonnull profileWireRef,
                                           double axOriginX,
                                           double axOriginY,
                                           double axOriginZ,
                                           double axNormalX,
                                           double axNormalY,
                                           double axNormalZ,
                                           double axXDirX,
                                           double axXDirY,
                                           double axXDirZ,
                                           int    joinType,
                                           bool   makeSolid)
{
  try
  {
    const TopoDS_Shape& spineShape   = *(const TopoDS_Shape*)spineFaceRef;
    const TopoDS_Shape& profileShape = *(const TopoDS_Shape*)profileWireRef;

    gp_Ax3 axe(gp_Pnt(axOriginX, axOriginY, axOriginZ),
               gp_Dir(axNormalX, axNormalY, axNormalZ),
               gp_Dir(axXDirX, axXDirY, axXDirZ));

    GeomAbs_JoinType jt = GeomAbs_Arc;
    if (joinType == 1)
      jt = GeomAbs_Tangent;
    else if (joinType == 2)
      jt = GeomAbs_Intersection;

    TopoDS_Wire profile = TopoDS::Wire(profileShape);

    BRepFill_Evolved evolved;
    if (spineShape.ShapeType() == TopAbs_FACE)
    {
      evolved.Perform(TopoDS::Face(spineShape), profile, axe, jt, makeSolid);
    }
    else if (spineShape.ShapeType() == TopAbs_WIRE)
    {
      evolved.Perform(TopoDS::Wire(spineShape), profile, axe, jt, makeSolid);
    }
    else
    {
      return nullptr;
    }

    if (!evolved.IsDone())
      return nullptr;
    return (OCCTShapeRef) new TopoDS_Shape(evolved.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTOffsetAncestorsRef OCCTBRepFillOffsetAncestorsCreate(OCCTShapeRef _Nonnull faceRef,
                                                         double offset,
                                                         int    joinType)
{
  try
  {
    const TopoDS_Shape& shape = *(const TopoDS_Shape*)faceRef;
    TopoDS_Face         face  = TopoDS::Face(shape);

    GeomAbs_JoinType jt = GeomAbs_Arc;
    if (joinType == 1)
      jt = GeomAbs_Tangent;
    else if (joinType == 2)
      jt = GeomAbs_Intersection;

    auto* opaque = new OffsetAncestorsOpaque();
    opaque->offsetWire.Init(face, jt);
    opaque->offsetWire.Perform(offset);
    if (opaque->offsetWire.IsDone())
    {
      opaque->ancestors.Perform(opaque->offsetWire);
      opaque->isDone = opaque->ancestors.IsDone();
    }
    else
    {
      opaque->isDone = false;
    }
    return opaque;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTBRepFillOffsetAncestorsIsDone(OCCTOffsetAncestorsRef _Nonnull ref)
{
  return ((OffsetAncestorsOpaque*)ref)->isDone;
}

bool OCCTBRepFillOffsetAncestorsHasAncestor(OCCTOffsetAncestorsRef _Nonnull ref,
                                            OCCTShapeRef _Nonnull edgeRef)
{
  try
  {
    auto*               opaque    = (OffsetAncestorsOpaque*)ref;
    const TopoDS_Shape& edgeShape = *(const TopoDS_Shape*)edgeRef;
    return opaque->ancestors.HasAncestor(TopoDS::Edge(edgeShape));
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef _Nullable OCCTBRepFillOffsetAncestorsGetAncestor(OCCTOffsetAncestorsRef _Nonnull ref,
                                                              OCCTShapeRef _Nonnull edgeRef)
{
  try
  {
    auto*               opaque    = (OffsetAncestorsOpaque*)ref;
    const TopoDS_Shape& edgeShape = *(const TopoDS_Shape*)edgeRef;
    TopoDS_Edge         edge      = TopoDS::Edge(edgeShape);
    if (!opaque->ancestors.HasAncestor(edge))
      return nullptr;
    return (OCCTShapeRef) new TopoDS_Shape(opaque->ancestors.Ancestor(edge));
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTBRepFillOffsetAncestorsRelease(OCCTOffsetAncestorsRef _Nonnull ref)
{
  delete (OffsetAncestorsOpaque*)ref;
}

OCCTNSectionsRef OCCTBRepFillNSectionsCreate(const OCCTShapeRef _Nonnull* _Nonnull wireRefs,
                                             int count)
{
  try
  {
    NCollection_Sequence<TopoDS_Shape> sections;
    for (int i = 0; i < count; i++)
    {
      const TopoDS_Shape& shape = *(const TopoDS_Shape*)wireRefs[i];
      sections.Append(shape);
    }
    auto* opaque = new NSectionsOpaque();
    opaque->nsec = new BRepFill_NSections(sections);
    return opaque;
  }
  catch (...)
  {
    return nullptr;
  }
}

int OCCTBRepFillNSectionsNbLaw(OCCTNSectionsRef _Nonnull ref)
{
  try
  {
    auto* opaque = (NSectionsOpaque*)ref;
    return opaque->nsec->NbLaw();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTBRepFillNSectionsIsConstant(OCCTNSectionsRef _Nonnull ref)
{
  try
  {
    auto* opaque = (NSectionsOpaque*)ref;
    return opaque->nsec->IsConstant();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepFillNSectionsIsVertex(OCCTNSectionsRef _Nonnull ref)
{
  try
  {
    auto* opaque = (NSectionsOpaque*)ref;
    return opaque->nsec->IsVertex();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTBRepFillNSectionsRelease(OCCTNSectionsRef _Nonnull ref)
{
  delete (NSectionsOpaque*)ref;
}

OCCTContigousEdgeResult OCCTShapeFindContigousEdges(OCCTShapeRef shape, double tolerance)
{
  OCCTContigousEdgeResult result = {0, 0};
  try
  {
    BRepOffsetAPI_FindContigousEdges finder(tolerance, true);
    finder.Add(shape->shape);
    finder.Perform();
    result.contigousEdgeCount    = finder.NbContigousEdges();
    result.degeneratedShapeCount = finder.NbDegeneratedShapes();
  }
  catch (...)
  {
  }
  return result;
}

OCCTLawFunctionRef OCCTLawInterpolate(const double* values,
                                      int32_t       count,
                                      const double* parameters,
                                      bool          periodic)
{
  try
  {
    Handle(NCollection_HArray1<double>) pts = new NCollection_HArray1<double>(1, count);
    for (int i = 0; i < count; i++)
      pts->SetValue(i + 1, values[i]);

    Law_Interpolate* interp;
    if (parameters)
    {
      Handle(NCollection_HArray1<double>) params = new NCollection_HArray1<double>(1, count);
      for (int i = 0; i < count; i++)
        params->SetValue(i + 1, parameters[i]);
      interp = new Law_Interpolate(pts, params, periodic, 1e-6);
    }
    else
    {
      interp = new Law_Interpolate(pts, periodic, 1e-6);
    }
    interp->Perform();
    if (!interp->IsDone())
    {
      delete interp;
      return nullptr;
    }
    Handle(Law_BSpline) curve = interp->Curve();
    delete interp;
    if (curve.IsNull())
      return nullptr;
    Handle(Law_Function) func =
      new Law_BSpFunc(curve, curve->FirstParameter(), curve->LastParameter());
    auto result = new OCCTLawFunction();
    result->law = func;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTPipeShellRef OCCTPipeShellCreate(OCCTShapeRef spineWire)
{
  if (!spineWire)
    return nullptr;
  try
  {
    TopoDS_Wire wire   = TopoDS::Wire(spineWire->shape);
    auto        result = new OCCTPipeShell();
    result->ps         = new BRepFill_PipeShell(wire);
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTPipeShellRelease(OCCTPipeShellRef ps)
{
  delete ps;
}

void OCCTPipeShellSetFrenet(OCCTPipeShellRef ps, bool frenet)
{
  if (!ps)
    return;
  try
  {
    ps->ps->Set(frenet);
  }
  catch (...)
  {
  }
}

void OCCTPipeShellSetDiscrete(OCCTPipeShellRef ps)
{
  if (!ps)
    return;
  try
  {
    ps->ps->SetDiscrete();
  }
  catch (...)
  {
  }
}

void OCCTPipeShellSetFixed(OCCTPipeShellRef ps, double bx, double by, double bz)
{
  if (!ps)
    return;
  try
  {
    ps->ps->Set(gp_Dir(bx, by, bz));
  }
  catch (...)
  {
  }
}

void OCCTPipeShellAdd(OCCTPipeShellRef ps, OCCTShapeRef profile)
{
  if (!ps || !profile)
    return;
  try
  {
    ps->ps->Add(profile->shape);
  }
  catch (...)
  {
  }
}

void OCCTPipeShellAddAtVertex(OCCTPipeShellRef ps, OCCTShapeRef profile, OCCTShapeRef vertex)
{
  if (!ps || !profile || !vertex)
    return;
  try
  {
    TopoDS_Vertex v = TopoDS::Vertex(vertex->shape);
    ps->ps->Add(profile->shape, v);
  }
  catch (...)
  {
  }
}

void OCCTPipeShellSetLaw(OCCTPipeShellRef ps, OCCTShapeRef profile, OCCTLawFunctionRef law)
{
  if (!ps || !profile || !law)
    return;
  try
  {
    ps->ps->SetLaw(profile->shape, law->law);
  }
  catch (...)
  {
  }
}

void OCCTPipeShellSetTolerance(OCCTPipeShellRef ps,
                               double           tol3d,
                               double           boundTol,
                               double           tolAngular)
{
  if (!ps)
    return;
  try
  {
    ps->ps->SetTolerance(tol3d, boundTol, tolAngular);
  }
  catch (...)
  {
  }
}

void OCCTPipeShellSetTransition(OCCTPipeShellRef ps, int32_t mode)
{
  if (!ps)
    return;
  try
  {
    BRepFill_TransitionStyle ts = BRepFill_Modified;
    switch (mode)
    {
      case 0:
        ts = BRepFill_Modified;
        break;
      case 1:
        ts = BRepFill_Right;
        break;
      case 2:
        ts = BRepFill_Round;
        break;
    }
    ps->ps->SetTransition(ts);
  }
  catch (...)
  {
  }
}

bool OCCTPipeShellBuild(OCCTPipeShellRef ps)
{
  if (!ps)
    return false;
  try
  {
    // Disable history tracking to avoid segfault on closed spine+profile
    // geometries (OCCT bug: BuildHistory crashes via null WireExplorer)
    ps->ps->SetIsBuildHistory(false);
    return ps->ps->Build();
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTPipeShellShape(OCCTPipeShellRef ps)
{
  if (!ps)
    return nullptr;
  try
  {
    const TopoDS_Shape& shape = ps->ps->Shape();
    if (shape.IsNull())
      return nullptr;
    return new OCCTShape(shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTPipeShellMakeSolid(OCCTPipeShellRef ps)
{
  if (!ps)
    return false;
  try
  {
    return ps->ps->MakeSolid();
  }
  catch (...)
  {
    return false;
  }
}

double OCCTPipeShellError(OCCTPipeShellRef ps)
{
  if (!ps)
    return 0;
  try
  {
    return ps->ps->ErrorOnSurface();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTPipeShellIsReady(OCCTPipeShellRef ps)
{
  if (!ps)
    return false;
  try
  {
    return ps->ps->IsReady();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTPipeShellSetMaxDegree(OCCTPipeShellRef ps, int32_t maxDeg)
{
  if (!ps || ps->ps.IsNull())
    return;
  try
  {
    ps->ps->SetMaxDegree(maxDeg);
  }
  catch (...)
  {
  }
}

void OCCTPipeShellSetMaxSegments(OCCTPipeShellRef ps, int32_t maxSeg)
{
  if (!ps || ps->ps.IsNull())
    return;
  try
  {
    ps->ps->SetMaxSegments(maxSeg);
  }
  catch (...)
  {
  }
}

void OCCTPipeShellSetForceApproxC1(OCCTPipeShellRef ps, bool force)
{
  if (!ps || ps->ps.IsNull())
    return;
  try
  {
    ps->ps->SetForceApproxC1(force);
  }
  catch (...)
  {
  }
}

void OCCTPipeShellSetBuildHistory(OCCTPipeShellRef ps, bool enabled)
{
  if (!ps || ps->ps.IsNull())
    return;
  try
  {
    ps->ps->SetIsBuildHistory(enabled);
  }
  catch (...)
  {
  }
}

double OCCTPipeShellErrorOnSurface(OCCTPipeShellRef ps)
{
  if (!ps || ps->ps.IsNull())
    return 0;
  try
  {
    return ps->ps->ErrorOnSurface();
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTPipeShellFirstShape(OCCTPipeShellRef ps)
{
  if (!ps || ps->ps.IsNull())
    return nullptr;
  try
  {
    TopoDS_Shape s = ps->ps->FirstShape();
    if (s.IsNull())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = s;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTPipeShellLastShape(OCCTPipeShellRef ps)
{
  if (!ps || ps->ps.IsNull())
    return nullptr;
  try
  {
    TopoDS_Shape s = ps->ps->LastShape();
    if (s.IsNull())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = s;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTPipeShellGetStatus(OCCTPipeShellRef ps)
{
  if (!ps)
    return 1; // NotOk
  try
  {
    GeomFill_PipeError status = ps->ps->GetStatus();
    return (int32_t)status;
  }
  catch (...)
  {
    return 1;
  }
}

OCCTShapeRef* OCCTPipeShellSimulate(OCCTPipeShellRef ps, int32_t numSections, int32_t* outCount)
{
  *outCount = 0;
  if (!ps || numSections <= 0)
    return nullptr;
  try
  {
    NCollection_List<TopoDS_Shape> sections;
    ps->ps->Simulate(numSections, sections);
    int32_t count = (int32_t)sections.Size();
    if (count == 0)
      return nullptr;
    auto result = (OCCTShapeRef*)malloc(sizeof(OCCTShapeRef) * count);
    int  i      = 0;
    for (auto it = sections.cbegin(); it != sections.cend(); ++it, ++i)
    {
      result[i] = new OCCTShape{*it};
    }
    *outCount = count;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTPipeShellSimulateFree(OCCTShapeRef* shapes, int32_t count)
{
  if (!shapes)
    return;
  for (int32_t i = 0; i < count; i++)
  {
    delete shapes[i];
  }
  free(shapes);
}

OCCTShapeRef OCCTOffsetWireOnPlane(OCCTShapeRef wire, double distance, int32_t joinType)
{
  if (!wire)
    return nullptr;
  try
  {
    GeomAbs_JoinType jt = GeomAbs_Arc;
    if (joinType == 1)
      jt = GeomAbs_Tangent;
    else if (joinType == 2)
      jt = GeomAbs_Intersection;
    BRepOffsetAPI_MakeOffset offset(TopoDS::Wire(wire->shape), jt);
    offset.Perform(distance);
    if (!offset.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = offset.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTOffsetFace(OCCTShapeRef face, double distance, int32_t joinType)
{
  if (!face)
    return nullptr;
  try
  {
    GeomAbs_JoinType jt = GeomAbs_Arc;
    if (joinType == 1)
      jt = GeomAbs_Tangent;
    else if (joinType == 2)
      jt = GeomAbs_Intersection;
    BRepOffsetAPI_MakeOffset offset(TopoDS::Face(face->shape), jt);
    offset.Perform(distance);
    if (!offset.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = offset.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTThickSolidWithOptions(OCCTShapeRef        shape,
                                       OCCTShapeRef const* facesToRemove,
                                       int32_t             faceCount,
                                       double              offset,
                                       double              tolerance,
                                       int32_t             joinType)
{
  if (!shape || !facesToRemove || faceCount <= 0)
    return nullptr;
  try
  {
    TopTools_ListOfShape facesToHollow;
    for (int32_t i = 0; i < faceCount; i++)
    {
      if (facesToRemove[i])
      {
        facesToHollow.Append(facesToRemove[i]->shape);
      }
    }
    GeomAbs_JoinType jt = GeomAbs_Arc;
    if (joinType == 1)
      jt = GeomAbs_Tangent;
    else if (joinType == 2)
      jt = GeomAbs_Intersection;
    BRepOffsetAPI_MakeThickSolid maker;
    maker.MakeThickSolidByJoin(shape->shape,
                               facesToHollow,
                               offset,
                               tolerance,
                               BRepOffset_Skin,
                               false,
                               false,
                               jt);
    if (!maker.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = maker.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTThruSectionsRef OCCTThruSectionsCreate(bool isSolid, bool isRuled, double pres3d)
{
  auto ts     = new OCCTThruSections();
  ts->builder = new BRepOffsetAPI_ThruSections(isSolid, isRuled, pres3d);
  return (OCCTThruSectionsRef)ts;
}

void OCCTThruSectionsRelease(OCCTThruSectionsRef ref)
{
  auto ts = (OCCTThruSections*)ref;
  if (ts)
  {
    delete ts->builder;
    delete ts;
  }
}

void OCCTThruSectionsAddWire(OCCTThruSectionsRef ref, OCCTShapeRef wire)
{
  auto ts = (OCCTThruSections*)ref;
  if (!ts || !wire)
    return;
  try
  {
    ts->builder->AddWire(TopoDS::Wire(wire->shape));
    ts->sectionCount++;
    // #910: a section added after a successful build belongs to a build that hasn't happened
    // yet, see the struct's `built` comment.
    ts->built = false;
  }
  catch (...)
  {
  }
}

void OCCTThruSectionsAddVertex(OCCTThruSectionsRef ref, OCCTShapeRef vertex)
{
  auto ts = (OCCTThruSections*)ref;
  if (!ts || !vertex)
    return;
  try
  {
    ts->builder->AddVertex(TopoDS::Vertex(vertex->shape));
    ts->sectionCount++;
    ts->built = false; // see OCCTThruSectionsAddWire's comment
  }
  catch (...)
  {
  }
}

void OCCTThruSectionsSetSmoothing(OCCTThruSectionsRef ref, bool smoothing)
{
  auto ts = (OCCTThruSections*)ref;
  if (!ts)
    return;
  ts->builder->SetSmoothing(smoothing);
  ts->built = false; // #910 review round 2 finding 2: see OCCTThruSectionsAddWire's comment,
  // every setter that changes what the NEXT Build() will produce needs the same invalidation
  // AddWire/AddVertex already got, or a caller reading .shape/.generatedFace after changing a
  // setting on a previously-built instance gets stale geometry that predates the change.
}

void OCCTThruSectionsSetMaxDegree(OCCTThruSectionsRef ref, int32_t maxDeg)
{
  auto ts = (OCCTThruSections*)ref;
  if (!ts)
    return;
  ts->builder->SetMaxDegree(maxDeg);
  ts->built = false; // see OCCTThruSectionsSetSmoothing's comment
}

void OCCTThruSectionsSetContinuity(OCCTThruSectionsRef ref, int32_t continuity)
{
  auto ts = (OCCTThruSections*)ref;
  if (!ts)
    return;
  ts->builder->SetCriteriumWeight(1.0, 1.0, 1.0); // ensure defaults
  ts->builder->SetContinuity(occtGeomAbsFromParametricContinuity(continuity));
  ts->built = false; // see OCCTThruSectionsSetSmoothing's comment
}

bool OCCTThruSectionsBuild(OCCTThruSectionsRef ref)
{
  auto ts = (OCCTThruSections*)ref;
  if (!ts)
    return false;
  // ThruSections requires at least 2 sections. OCCT segfaults otherwise
  if (ts->sectionCount < 2)
  {
    ts->built = false;
    return false;
  }
  try
  {
    ts->builder->Build();
    // IsDone() alone is not enough: see the struct's own comment. GetStatus() reports what
    // Build() actually decided, including the two WrongUsage returns that leave IsDone() in
    // whatever state a PRIOR successful build left it.
    ts->built =
      ts->builder->IsDone() && ts->builder->GetStatus() == BRepFill_ThruSectionErrorStatus_Done;
    return ts->built;
  }
  catch (...)
  {
    ts->built = false;
    return false;
  }
}

OCCTShapeRef OCCTThruSectionsShape(OCCTThruSectionsRef ref)
{
  auto ts = (OCCTThruSections*)ref;
  if (!ts)
    return nullptr;
  try
  {
    if (!ts->built)
      return nullptr;
    return new OCCTShape{ts->builder->Shape()};
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTThruSectionsCheckCompatibility(OCCTThruSectionsRef ref, bool check)
{
  auto ts = (OCCTThruSections*)ref;
  if (!ts)
    return;
  try
  {
    ts->builder->CheckCompatibility(check);
    ts->built = false;
  }
  catch (...)
  {
  }
  // see OCCTThruSectionsSetSmoothing's comment
}

void OCCTThruSectionsSetParType(OCCTThruSectionsRef ref, int32_t parType)
{
  auto ts = (OCCTThruSections*)ref;
  if (!ts)
    return;
  try
  {
    Approx_ParametrizationType pt = Approx_ChordLength;
    switch (parType)
    {
      case 0:
        pt = Approx_ChordLength;
        break;
      case 1:
        pt = Approx_Centripetal;
        break;
      case 2:
        pt = Approx_IsoParametric;
        break;
    }
    ts->builder->SetParType(pt);
    ts->built = false; // see OCCTThruSectionsSetSmoothing's comment
  }
  catch (...)
  {
  }
}

bool OCCTThruSectionsSetCriteriumWeight(OCCTThruSectionsRef ref, double w1, double w2, double w3)
{
  auto ts = (OCCTThruSections*)ref;
  if (!ts)
    return false;
  // Reject negative weights before calling OCCT: OCCT's SetCriteriumWeight silently
  // ignores them (sets myStatus = Failed but doesn't update myCritWeights), and
  // Build() then resets myStatus = Done, making the rejection unobservable.
  if (w1 < 0 || w2 < 0 || w3 < 0)
    return false;
  try
  {
    ts->builder->SetCriteriumWeight(w1, w2, w3);
    ts->built = false;
  }
  catch (...)
  {
    return false;
  }
  // see OCCTThruSectionsSetSmoothing's comment
  return true;
}

OCCTShapeRef OCCTThruSectionsGeneratedFace(OCCTThruSectionsRef ref, OCCTShapeRef edge)
{
  auto ts = (OCCTThruSections*)ref;
  if (!ts || !edge)
    return nullptr;
  try
  {
    // #910: GeneratedFace() is a bare lookup into myEdgeFace, which Build() never clears,
    // see the struct's `built` comment. `built` alone isn't sufficient here, though: a THIRD
    // build succeeding after an intervening failure (build ok -> add a mismatched section,
    // build fails -> CheckCompatibility(true) reconciles it, build ok again) can rebuild every
    // section's edges, not just the new one's, stranding `edge`'s ORIGINAL binding in the map
    // without ever overwriting it, measured empirically, `built` is true and GeneratedFace()
    // answers non-null with a face that provably isn't part of the new build's own Shape().
    // myEdgeFace is a private OCCT member with no public clear(), so confirm membership in the
    // current Shape() directly instead of trusting the map (#910 review round 2 finding 1).
    if (!ts->built)
      return nullptr;
    TopoDS_Shape face = ts->builder->GeneratedFace(edge->shape);
    if (face.IsNull())
      return nullptr;
    TopoDS_Shape current = ts->builder->Shape();
    for (TopExp_Explorer exp(current, TopAbs_FACE); exp.More(); exp.Next())
    {
      if (exp.Current().IsSame(face))
      {
        return new OCCTShape{face};
      }
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCreatePipeSweep(OCCTWireRef profile, OCCTWireRef path)
{
  if (!profile || !path)
    return nullptr;
  try
  {
    BRepOffsetAPI_MakePipe maker(path->wire, profile->wire);
    maker.Build();
    if (!maker.IsDone())
      return nullptr;
    return new OCCTShape(maker.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCreateLoft(const OCCTWireRef* profiles, int32_t count, bool solid)
{
  if (!profiles || count < 2)
    return nullptr;
  occtEnsureSignals();
  try
  {
    OCC_CATCH_SIGNALS
    BRepOffsetAPI_ThruSections maker(solid ? Standard_True : Standard_False);

    // Enable compatibility checking to:
    // - Compute origin and orientation on wires to avoid twisted results
    // - Update wires to have same number of edges
    maker.CheckCompatibility(Standard_True);

    for (int32_t i = 0; i < count; i++)
    {
      if (profiles[i])
      {
        maker.AddWire(profiles[i]->wire);
      }
    }

    maker.Build();
    if (!maker.IsDone())
      return nullptr;
    return new OCCTShape(maker.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeShell(OCCTShapeRef shape, double thickness)
{
  if (!shape)
    return nullptr;
  try
  {
    // Create list of faces to remove (none = hollow shell)
    TopTools_ListOfShape facesToRemove;

    BRepOffsetAPI_MakeThickSolid thickSolid;
    thickSolid.MakeThickSolidBySimple(shape->shape, thickness);
    if (!thickSolid.IsDone())
      return nullptr;
    return new OCCTShape(thickSolid.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeOffset(OCCTShapeRef shape, double distance)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepOffsetAPI_MakeOffsetShape offsetter;
    offsetter.PerformBySimple(shape->shape, distance);
    if (!offsetter.IsDone())
      return nullptr;
    return new OCCTShape(offsetter.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireOffset(OCCTWireRef wire, double distance, int32_t joinType)
{
  if (!wire)
    return nullptr;

  try
  {
    TopoDS_Wire theWire = wire->wire;

    // Create a planar face from the wire (required for BRepOffsetAPI_MakeOffset)
    BRepBuilderAPI_MakeFace faceMaker(theWire, Standard_True);
    if (!faceMaker.IsDone())
      return nullptr;
    TopoDS_Face face = faceMaker.Face();

    // Select join type
    GeomAbs_JoinType join = (joinType == 0) ? GeomAbs_Arc : GeomAbs_Intersection;

    // Create offset using the face
    BRepOffsetAPI_MakeOffset offsetMaker(face, join);
    offsetMaker.Perform(distance);

    if (!offsetMaker.IsDone())
      return nullptr;

    // Extract the offset wire from the result shape
    TopoDS_Shape result = offsetMaker.Shape();

    // The result may contain multiple wires - get the first one
    TopExp_Explorer explorer(result, TopAbs_WIRE);
    if (explorer.More())
    {
      TopoDS_Wire resultWire = TopoDS::Wire(explorer.Current());
      return new OCCTWire(resultWire);
    }

    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}
