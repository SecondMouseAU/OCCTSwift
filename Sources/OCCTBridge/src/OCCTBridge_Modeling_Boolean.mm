//
//  OCCTBridge_Modeling_Boolean.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Modeling.mm (#396/#819): BRepAlgoAPI, BOPAlgo, IntTools, BOPTools,
//  boolean/pattern history. Public C surface unchanged; imports the same OCCTBridge_Modeling.h
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

OCCTShapeRef OCCTShapeSection(OCCTShapeRef shape1, OCCTShapeRef shape2)
{
  if (!shape1 || !shape2)
    return nullptr;
  try
  {
    BRepAlgoAPI_Section section(shape1->shape, shape2->shape, Standard_False);
    section.ComputePCurveOn1(Standard_True);
    section.Approximation(Standard_True);
    section.Build();
    if (!section.IsDone())
      return nullptr;
    TopoDS_Shape result = section.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFuseMulti(const OCCTShapeRef* shapes, int32_t count)
{
  if (!shapes || count < 2)
    return nullptr;
  try
  {
    TopTools_ListOfShape arguments;
    for (int32_t i = 0; i < count; ++i)
    {
      if (!shapes[i])
        return nullptr;
      arguments.Append(shapes[i]->shape);
    }
    BRepAlgoAPI_BuilderAlgo builder;
    builder.SetArguments(arguments);
    // #367/#369: SetRunParallel(true) was removed here after appearing to cause silent data
    // corruption under concurrent top-level callers. #369's root-cause investigation found the
    // "corruption" was a test-harness bug
    // (Scripts/repro/342-boolean-ops/occt_342_boolean_stress.cpp compared this General Fuse
    // operation's output against a BRepAlgoAPI_Fuse baseline -- a different OCCT operation with
    // legitimately different topology for the same input), not a real defect in
    // OSD_ThreadPool/BOPTools_Parallel: both direct isolation testing and the corrected harness
    // show zero TSan races and zero wrong results, solo or under concurrent load.
    // SetRunParallel(true) is very likely safe to re-enable here; left at the serial default
    // pending that follow-up decision. See CLAUDE.md's Known OCCT Bugs #367/#369 entry.
    builder.Build();
    if (!builder.IsDone())
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

int32_t OCCTShapeFuseWithHistory(OCCTShapeRef  shape1,
                                 OCCTShapeRef  shape2,
                                 OCCTShapeRef* outModified,
                                 int32_t       maxModified)
{
  if (!shape1 || !shape2 || !outModified || maxModified < 1)
    return -1;
  try
  {
    BRepAlgoAPI_Fuse fuse(shape1->shape, shape2->shape);
    if (!fuse.IsDone())
      return -1;
    // Collect modified shapes from shape1's faces
    int32_t         count = 0;
    TopExp_Explorer explorer(shape1->shape, TopAbs_FACE);
    while (explorer.More() && count < maxModified)
    {
      const TopTools_ListOfShape&        modified = fuse.Modified(explorer.Current());
      TopTools_ListIteratorOfListOfShape it(modified);
      while (it.More() && count < maxModified)
      {
        outModified[count] = new OCCTShape(it.Value());
        count++;
        it.Next();
      }
      explorer.Next();
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

OCCTBooleanHistoryRef OCCTBooleanUnionWithHistory(OCCTShapeRef  shape1,
                                                  OCCTShapeRef  shape2,
                                                  OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape1 || !shape2)
    return nullptr;
  try
  {
    std::unique_ptr<BRepAlgoAPI_Fuse> op(new BRepAlgoAPI_Fuse(shape1->shape, shape2->shape));
    if (!op->IsDone())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(op->Shape());
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape1->shape, shape2->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTBooleanSubtractWithHistory(OCCTShapeRef  shape1,
                                                     OCCTShapeRef  shape2,
                                                     OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape1 || !shape2)
    return nullptr;
  try
  {
    std::unique_ptr<BRepAlgoAPI_Cut> op(new BRepAlgoAPI_Cut(shape1->shape, shape2->shape));
    if (!op->IsDone())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(op->Shape());
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape1->shape, shape2->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTBooleanIntersectWithHistory(OCCTShapeRef  shape1,
                                                      OCCTShapeRef  shape2,
                                                      OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape1 || !shape2)
    return nullptr;
  try
  {
    std::unique_ptr<BRepAlgoAPI_Common> op(new BRepAlgoAPI_Common(shape1->shape, shape2->shape));
    if (!op->IsDone())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(op->Shape());
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape1->shape, shape2->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTBooleanSplitWithHistory(OCCTShapeRef  shape1,
                                                  OCCTShapeRef  shape2,
                                                  OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape1 || !shape2)
    return nullptr;
  try
  {
    std::unique_ptr<BRepAlgoAPI_Splitter> op(new BRepAlgoAPI_Splitter());
    TopTools_ListOfShape                  args;
    args.Append(shape1->shape);
    TopTools_ListOfShape tools;
    tools.Append(shape2->shape);
    op->SetArguments(args);
    op->SetTools(tools);
    op->Build();
    if (!op->IsDone())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(op->Shape());
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape1->shape, shape2->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

// Always returns the full Modified count. If outRefs is non-null, also writes
// up to maxCount entries (caller takes ownership of each). Pass outRefs=null
// (or maxCount=0) to probe the count without allocating.
int32_t OCCTBooleanHistoryModified(OCCTBooleanHistoryRef h,
                                   OCCTShapeRef          inputSubShape,
                                   OCCTShapeRef*         outRefs,
                                   int32_t               maxCount)
{
  if (!h || !inputSubShape)
    return -1;
  try
  {
    const TopTools_ListOfShape& list =
      h->op ? h->op->Modified(inputSubShape->shape) : h->prebuilt->Modified(inputSubShape->shape);
    int32_t count = 0;
    for (TopTools_ListIteratorOfListOfShape it(list); it.More(); it.Next())
    {
      if (outRefs && count < maxCount)
      {
        outRefs[count] = new OCCTShape(it.Value());
      }
      count++;
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

// Same probe-and-fill semantics as OCCTBooleanHistoryModified.
int32_t OCCTBooleanHistoryGenerated(OCCTBooleanHistoryRef h,
                                    OCCTShapeRef          inputSubShape,
                                    OCCTShapeRef*         outRefs,
                                    int32_t               maxCount)
{
  if (!h || !inputSubShape)
    return -1;
  try
  {
    // Sewing/quilting/healing (prebuilt) never populate Generated, they
    // only replace or remove, never create lower/higher-dimension topology
    //, but BRepTools_History:Generated still returns a valid empty list.
    const TopTools_ListOfShape& list =
      h->op ? h->op->Generated(inputSubShape->shape) : h->prebuilt->Generated(inputSubShape->shape);
    int32_t count = 0;
    for (TopTools_ListIteratorOfListOfShape it(list); it.More(); it.Next())
    {
      if (outRefs && count < maxCount)
      {
        outRefs[count] = new OCCTShape(it.Value());
      }
      count++;
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTBooleanHistoryIsDeleted(OCCTBooleanHistoryRef h, OCCTShapeRef inputSubShape)
{
  if (!h || !inputSubShape)
    return false;
  try
  {
    return h->op ? h->op->IsDeleted(inputSubShape->shape)
                 : h->prebuilt->IsRemoved(inputSubShape->shape);
  }
  catch (...)
  {
    return false;
  }
}

// Synthesize a standalone BRepTools_History from the retained builder, or hand
// back the already-complete one for sewing/quilting/healing (issue #327).
//
// BRepTools_History's template constructor walks the argument list and copies
// Modified / Generated / IsDeleted for each supported subshape, so it works off
// the virtual base and does not need the concrete builder type. That matters:
// only the BRepAlgoAPI_* builders expose a native History(); fillet, chamfer and
// thick-solid do not, and this path covers all of them uniformly.
//
// Note BRepTools_History only tracks VERTEX / EDGE / FACE / SOLID
// (BRepTools_History:IsSupportedType), wires, shells and compounds are not
// carried, so absorbing this into a graph records nothing for those kinds.
OCCTHistoryRef OCCTBooleanHistoryAsBRepToolsHistory(OCCTBooleanHistoryRef h)
{
  if (!h)
    return nullptr;
  try
  {
    auto* ref = new OCCTHistoryStorage();
    if (h->op)
    {
      ref->history = new BRepTools_History(h->args, *h->op);
    }
    else if (!h->prebuilt.IsNull())
    {
      // Shared Handle (ref-counted), cheap, and keeps `h` independently
      // queryable via OCCTBooleanHistoryModified/Generated/IsDeleted after
      // this call, same as the synthesized-from-op case.
      ref->history = h->prebuilt;
    }
    else
    {
      delete ref;
      return nullptr;
    }
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTBooleanHistoryRelease(OCCTBooleanHistoryRef h)
{
  delete h;
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromFilletEdges(OCCTShapeRef   shape,
                                                      const int32_t* edgeIndices,
                                                      int32_t        count,
                                                      double         radius,
                                                      OCCTShapeRef*  outResult)
{
  if (outResult)
    *outResult = nullptr;
  // Same family as OCCTShapeFilletEdges, so the same precondition and the same edge loop; it
  // cannot use occtShapeFilletEdgeList itself because the builder outlives the call. #489
  if (!occtValidFilletRadius(radius))
    return nullptr;
  if (!shape || !edgeIndices || count < 1)
    return nullptr;
  try
  {
    std::unique_ptr<BRepFilletAPI_MakeFillet> op(new BRepFilletAPI_MakeFillet(shape->shape));
    if (!occtFilletAddEdges(
          *op,
          shape->shape,
          edgeIndices,
          count,
          [radius](BRepFilletAPI_MakeFillet& fillet, const TopoDS_Edge& edge, int32_t) {
            fillet.Add(radius, edge);
            return true;
          }))
      return nullptr;
    op->Build();
    if (!op->IsDone())
      return nullptr;
    TopoDS_Shape result = op->Shape();
    if (result.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromFilletEdgeVariable(OCCTShapeRef  shape,
                                                             int32_t       edgeIndex,
                                                             double        startRadius,
                                                             double        endRadius,
                                                             OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  // The single-edge sibling of OCCTShapeFilletEdgesLinear, and the same precondition. #489
  if (!occtValidFilletRadius(startRadius) || !occtValidFilletRadius(endRadius))
    return nullptr;
  if (!shape)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
    int32_t idx = edgeIndex + 1;
    if (idx < 1 || idx > edgeMap.Extent())
      return nullptr;
    TopoDS_Edge                               edge = TopoDS::Edge(edgeMap(idx));
    std::unique_ptr<BRepFilletAPI_MakeFillet> op(new BRepFilletAPI_MakeFillet(shape->shape));
    // #612: the same one-call overload OCCTShapeFilletEdgesLinear uses, replacing Add(edge)
    // plus a two-point array written to SetRadius(radii, 1, 1). That literal 1 was in fact
    // safe here, a single added edge always lands at index 1 of its contour's spine, measured
    // on all four edges of a tangent rim, and a *literal* 1 is bounds-checked upstream even
    // when the edge was declined and there are no contours (unlike the 0 that NbContours()
    // yields there, which is the unchecked low side that used to SIGSEGV). Converted anyway so
    // the idiom is gone: Add(R1, R2, E) measures identical to the array law (492.500243 on an
    // accepted edge) and declines an unfilletable edge by construction.
    op->Add(startRadius, endRadius, edge);
    op->Build();
    if (!op->IsDone())
      return nullptr;
    TopoDS_Shape result = op->Shape();
    if (result.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromChamferEdges(OCCTShapeRef   shape,
                                                       const int32_t* edgeIndices,
                                                       int32_t        count,
                                                       double         distance,
                                                       OCCTShapeRef*  outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape || !edgeIndices || count < 1)
    return nullptr;
  try
  {
    std::unique_ptr<BRepFilletAPI_MakeChamfer> op(new BRepFilletAPI_MakeChamfer(shape->shape));
    // #568: the chamfer counterpart of occtFilletAddEdges, which the fillet sibling two
    // functions up already shares. Same builder shape, same contract: an edge index naming no
    // edge of this shape rejects the call rather than chamfering the rest. It cannot use that
    // helper itself, which is BRepFilletAPI_MakeFillet-typed, but both now resolve their
    // indices through the same occtUseSubShapesByIndex. See OCCTBridge_Internal.h.
    if (!occtUseSubShapesByIndex(
          shape->shape,
          TopAbs_EDGE,
          edgeIndices,
          count,
          [&](const TopoDS_Shape& edge, int32_t) { op->Add(distance, TopoDS::Edge(edge)); }))
      return nullptr;
    op->Build();
    if (!op->IsDone())
      return nullptr;
    TopoDS_Shape result = op->Shape();
    if (result.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromShell(OCCTShapeRef   shape,
                                                const int32_t* faceIndices,
                                                int32_t        faceCount,
                                                double         thickness,
                                                double         tolerance,
                                                OCCTShapeRef*  outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape || !faceIndices || faceCount < 1)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
    TopTools_ListOfShape closingFaces;
    for (int32_t i = 0; i < faceCount; ++i)
    {
      int32_t idx = faceIndices[i] + 1;
      if (idx < 1 || idx > faceMap.Extent())
        return nullptr;
      closingFaces.Append(faceMap(idx));
    }
    std::unique_ptr<BRepOffsetAPI_MakeThickSolid> op(new BRepOffsetAPI_MakeThickSolid());
    op->MakeThickSolidByJoin(shape->shape,
                             closingFaces,
                             thickness,
                             tolerance,
                             BRepOffset_Skin,
                             false,
                             false,
                             GeomAbs_Arc);
    op->Build();
    if (!op->IsDone())
      return nullptr;
    TopoDS_Shape result = op->Shape();
    if (result.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromDefeature(OCCTShapeRef   shape,
                                                    const int32_t* faceIndices,
                                                    int32_t        faceCount,
                                                    OCCTShapeRef*  outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape)
    return nullptr;
  try
  {
    TopTools_ListOfShape facesToRemove;
    if (!occtDefeaturingFacesByIndex(shape->shape, faceIndices, faceCount, facesToRemove))
    {
      return nullptr;
    }
    // The builder outlives this call, OCCTBooleanHistory reads its history, so it is held by
    // pointer here rather than on the stack, but it is the same skeleton. #497
    std::unique_ptr<BRepAlgoAPI_Defeaturing> op(new BRepAlgoAPI_Defeaturing());
    TopoDS_Shape                             result;
    if (!occtDefeaturePerform(*op, shape->shape, facesToRemove, result))
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCommonMulti(const OCCTShapeRef* shapes, int32_t count)
{
  if (!shapes || count < 2)
    return nullptr;
  try
  {
    // Start with the common of first two shapes, then iteratively intersect with rest
    for (int32_t i = 0; i < count; ++i)
    {
      if (!shapes[i])
        return nullptr;
    }
    TopoDS_Shape result = shapes[0]->shape;
    for (int32_t i = 1; i < count; ++i)
    {
      BRepAlgoAPI_Common common(result, shapes[i]->shape);
      if (!common.IsDone())
        return nullptr;
      result = common.Shape();
      if (result.IsNull())
        return nullptr;
    }
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFuseAndBlend(OCCTShapeRef shape1, OCCTShapeRef shape2, double radius)
{
  if (!shape1 || !shape2 || radius <= 0)
    return nullptr;
  try
  {
    // Step 1: Fuse
    BRepAlgoAPI_Fuse fuse(shape1->shape, shape2->shape);
    if (!fuse.IsDone())
      return nullptr;

    // Step 2: Find intersection edges (edges generated/modified by the boolean)
    TopTools_ListOfShape generatedEdges;
    // Collect edges from the fuse that were generated from faces of either input
    for (TopExp_Explorer exp(shape1->shape, TopAbs_FACE); exp.More(); exp.Next())
    {
      const TopTools_ListOfShape& gen = fuse.Generated(exp.Current());
      for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next())
      {
        if (it.Value().ShapeType() == TopAbs_EDGE)
        {
          generatedEdges.Append(it.Value());
        }
      }
    }
    for (TopExp_Explorer exp(shape2->shape, TopAbs_FACE); exp.More(); exp.Next())
    {
      const TopTools_ListOfShape& gen = fuse.Generated(exp.Current());
      for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next())
      {
        if (it.Value().ShapeType() == TopAbs_EDGE)
        {
          generatedEdges.Append(it.Value());
        }
      }
    }

    // Also collect section edges (edges at the intersection of the two shapes)
    const TopoDS_Shape& fuseResult = fuse.Shape();

    // Use SectionEdges() to get the intersection edges
    const TopTools_ListOfShape& sectionEdges = fuse.SectionEdges();

    // Step 3: Fillet those edges
    BRepFilletAPI_MakeFillet fillet(fuseResult);
    // Add section edges
    for (TopTools_ListIteratorOfListOfShape it(sectionEdges); it.More(); it.Next())
    {
      if (it.Value().ShapeType() == TopAbs_EDGE)
      {
        fillet.Add(radius, TopoDS::Edge(it.Value()));
      }
    }
    // Add generated edges
    for (TopTools_ListIteratorOfListOfShape it(generatedEdges); it.More(); it.Next())
    {
      fillet.Add(radius, TopoDS::Edge(it.Value()));
    }

    if (fillet.NbContours() == 0)
    {
      // No edges to fillet, just return the fuse result
      return new OCCTShape(fuseResult);
    }

    fillet.Build();
    if (!fillet.IsDone())
      return nullptr;
    return new OCCTShape(fillet.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCutAndBlend(OCCTShapeRef shape1, OCCTShapeRef shape2, double radius)
{
  if (!shape1 || !shape2 || radius <= 0)
    return nullptr;
  try
  {
    // Step 1: Cut
    BRepAlgoAPI_Cut cut(shape1->shape, shape2->shape);
    if (!cut.IsDone())
      return nullptr;

    const TopoDS_Shape&         cutResult    = cut.Shape();
    const TopTools_ListOfShape& sectionEdges = cut.SectionEdges();

    // Collect generated edges from faces
    TopTools_ListOfShape generatedEdges;
    for (TopExp_Explorer exp(shape1->shape, TopAbs_FACE); exp.More(); exp.Next())
    {
      const TopTools_ListOfShape& gen = cut.Generated(exp.Current());
      for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next())
      {
        if (it.Value().ShapeType() == TopAbs_EDGE)
        {
          generatedEdges.Append(it.Value());
        }
      }
    }
    for (TopExp_Explorer exp(shape2->shape, TopAbs_FACE); exp.More(); exp.Next())
    {
      const TopTools_ListOfShape& gen = cut.Generated(exp.Current());
      for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next())
      {
        if (it.Value().ShapeType() == TopAbs_EDGE)
        {
          generatedEdges.Append(it.Value());
        }
      }
    }

    // Step 2: Fillet
    BRepFilletAPI_MakeFillet fillet(cutResult);
    for (TopTools_ListIteratorOfListOfShape it(sectionEdges); it.More(); it.Next())
    {
      if (it.Value().ShapeType() == TopAbs_EDGE)
      {
        fillet.Add(radius, TopoDS::Edge(it.Value()));
      }
    }
    for (TopTools_ListIteratorOfListOfShape it(generatedEdges); it.More(); it.Next())
    {
      fillet.Add(radius, TopoDS::Edge(it.Value()));
    }

    if (fillet.NbContours() == 0)
    {
      return new OCCTShape(cutResult);
    }

    fillet.Build();
    if (!fillet.IsDone())
      return nullptr;
    return new OCCTShape(fillet.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeSewWithHistory(const OCCTShapeRef* shapes,
                                              int32_t             count,
                                              double              tolerance,
                                              OCCTShapeRef*       outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shapes || count < 1)
    return nullptr;
  try
  {
    BRepBuilderAPI_Sewing sewing(tolerance);
    for (int32_t i = 0; i < count; i++)
    {
      if (shapes[i])
        sewing.Add(shapes[i]->shape);
    }
    sewing.Perform();
    TopoDS_Shape sewn = sewing.SewedShape();
    if (sewn.IsNull())
      return nullptr;

    if (sewn.ShapeType() == TopAbs_SHELL)
    {
      TopoDS_Shell shell = TopoDS::Shell(sewn);
      if (shell.Closed())
      {
        BRepBuilderAPI_MakeSolid makeSolid(shell);
        if (makeSolid.IsDone())
          sewn = makeSolid.Solid();
      }
    }

    Handle(BRepTools_History) hist = sewing.GetContext()->History();
    if (hist.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(sewn);
    return new OCCTBooleanHistory(hist);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Self-sew (mirrors OCCTShapeSewSingle in OCCTBridge_Healing.mm) with full
// history. Lives here, not next to its plain counterpart, because
// OCCTBooleanHistory is private to this translation unit, every function that
// constructs one has to live in this file (same constraint the Tier 2
// fillet/chamfer/shell/defeature *WithHistory functions above are already under).
OCCTBooleanHistoryRef OCCTShapeSewSingleWithHistory(OCCTShapeRef  shape,
                                                    double        tolerance,
                                                    OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape)
    return nullptr;
  try
  {
    BRepBuilderAPI_Sewing sewing(tolerance);
    sewing.Add(shape->shape);
    sewing.Perform();
    TopoDS_Shape sewn = sewing.SewedShape();
    if (sewn.IsNull())
      return nullptr;

    if (sewn.ShapeType() == TopAbs_SHELL)
    {
      TopoDS_Shell shell = TopoDS::Shell(sewn);
      if (shell.Closed())
      {
        BRepBuilderAPI_MakeSolid makeSolid(shell);
        if (makeSolid.IsDone())
          sewn = makeSolid.Solid();
      }
    }

    Handle(BRepTools_History) hist = sewing.GetContext()->History();
    if (hist.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(sewn);
    return new OCCTBooleanHistory(hist);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Quilt multiple shapes (faces/shells) into a single shell, with full
// per-input-subshape history. Uses BRepTools_Quilt (not BRepBuilderAPI_Sewing)
// because it preserves the exact input face->output face mapping that
// BRepTools_Quilt provides (IsCopied/Copy). The plain OCCTShapeQuilt shares
// this same BRepTools_Quilt path through occtQuiltShells, defined next to it
// near the top of this file (#974).
OCCTBooleanHistoryRef OCCTShapeQuiltWithHistory(OCCTShapeRef* shapes,
                                                int32_t       count,
                                                OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shapes || count <= 0)
    return nullptr;
  try
  {
    BRepTools_Quilt quilt;
    TopoDS_Shape    result = occtQuiltShells(quilt, shapes, count);
    if (result.IsNull())
      return nullptr;

    Handle(BRepTools_History)  hist = new BRepTools_History();
    TopTools_IndexedMapOfShape subMap;
    for (int32_t i = 0; i < count; i++)
    {
      subMap.Clear();
      TopExp::MapShapes(shapes[i]->shape, subMap);
      for (int32_t j = 1; j <= subMap.Extent(); j++)
      {
        const TopoDS_Shape& sub = subMap(j);
        if (!BRepTools_History::IsSupportedType(sub))
          continue;
        if (quilt.IsCopied(sub))
        {
          hist->AddModified(sub, quilt.Copy(sub));
        }
      }
    }

    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(hist);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeHealWithHistory(OCCTShapeRef shape, OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape)
    return nullptr;
  try
  {
    if (occtHasSelfIntersectingWire(shape->shape))
      return nullptr;
    Handle(ShapeFix_Shape) fixer = new ShapeFix_Shape(shape->shape);
    fixer->Perform();
    TopoDS_Shape result = fixer->Shape();
    if (result.IsNull())
      return nullptr;

    Handle(BRepTools_History) hist = fixer->Context()->History();
    if (hist.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(hist);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - Solid from shell with full history (issue #327)
//
// Unlike sewing/healing, BRepBuilderAPI_MakeSolid genuinely derives from
// BRepBuilderAPI_MakeShape (fits the existing template-synthesis path), but a
// solid built from an already-closed shell doesn't modify/generate any of the
// shell's sub-shapes, it only wraps it, so the templated ctor would report
// nothing. The one stage that can actually touch sub-shape identity is the
// ShapeFix_Solid orientation-fix pass, so that's the history source here.
// ShapeFix_Solid::Init does NOT auto-create a context (verified in occt-src,
// unlike ShapeFix_Shape above): SetContext() must be called explicitly before
// Perform(), or Context()->History() below would dereference a null Handle.
//
// Multi-body input goes one body per body-bounding shell, matching the plain
// OCCTShapeCreateSolidFromShell (#443). All the per-body fixers share ONE
// ShapeBuild_ReShape, so the single history covers every body: History() builds a
// fresh BRepTools_History from the context's whole replacement map on each call
// (BRepTools_ReShape::History), so replacements from earlier bodies are still in it.
// The flip side of sharing: each body's Perform() calls Context()->Apply() against a map
// that already holds the earlier bodies' replacements. Harmless for the disjoint bodies
// sewing produces, since Apply returns an unmapped shape unchanged, but two bodies that
// genuinely share a sub-shape would see the first body's replacement of it.
OCCTBooleanHistoryRef OCCTShapeCreateSolidFromShellWithHistory(OCCTShapeRef  shell,
                                                               OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shell)
    return nullptr;
  try
  {
    Handle(ShapeBuild_ReShape) context = new ShapeBuild_ReShape;
    std::vector<TopoDS_Shape>  made;
    for (const TopoDS_Shell& topoShell : occtBodyBoundingShells(shell->shape))
    {
      // Same MakeSolid IsDone()/IsNull() checks as OCCTShapeCreateSolidFromShell above,
      // and the same finding applies: verified dead code (BRepLib_MakeSolid's single-shell
      // constructor always Done()s, never a null Solid()), kept push-not-drop for the same
      // belt-and-braces reason. A body that took this branch never reaches ShapeFix_Solid,
      // so it contributes nothing to `context`, same as any body the loop never visits.
      BRepBuilderAPI_MakeSolid makeSolid(topoShell);
      TopoDS_Solid             solid;
      if (makeSolid.IsDone())
        solid = makeSolid.Solid();
      if (solid.IsNull())
      {
        made.push_back(topoShell); // Kept, not dropped, see comment above.
        continue;
      }

      ShapeFix_Solid fixer(solid);
      fixer.SetContext(context);
      fixer.Perform();
      TopoDS_Shape result = fixer.Solid();
      if (result.IsNull() || result.ShapeType() != TopAbs_SOLID)
      {
        result = solid; // Fall back to the unfixed solid, same as OCCTShapeCreateSolidFromShell.
      }
      made.push_back(result);
    }

    TopoDS_Shape result = occtSolidBodiesToShape(made);
    if (result.IsNull())
      return nullptr;

    Handle(BRepTools_History) hist = context->History();
    if (hist.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(hist);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromTranslate(OCCTShapeRef  shape,
                                                    double        dx,
                                                    double        dy,
                                                    double        dz,
                                                    OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape)
    return nullptr;
  try
  {
    gp_Trsf transform;
    transform.SetTranslation(gp_Vec(dx, dy, dz));
    std::unique_ptr<BRepBuilderAPI_Transform> op(
      new BRepBuilderAPI_Transform(shape->shape, transform, Standard_True));
    if (!op->IsDone())
      return nullptr;
    TopoDS_Shape result = op->Shape();
    if (result.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromRotate(OCCTShapeRef  shape,
                                                 double        axisX,
                                                 double        axisY,
                                                 double        axisZ,
                                                 double        angle,
                                                 OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape)
    return nullptr;
  try
  {
    gp_Ax1  axis(gp_Pnt(0, 0, 0), gp_Dir(axisX, axisY, axisZ));
    gp_Trsf transform;
    transform.SetRotation(axis, angle);
    std::unique_ptr<BRepBuilderAPI_Transform> op(
      new BRepBuilderAPI_Transform(shape->shape, transform, Standard_True));
    if (!op->IsDone())
      return nullptr;
    TopoDS_Shape result = op->Shape();
    if (result.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromScale(OCCTShapeRef  shape,
                                                double        factor,
                                                OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape)
    return nullptr;
  try
  {
    gp_Trsf transform;
    transform.SetScale(gp_Pnt(0, 0, 0), factor);
    std::unique_ptr<BRepBuilderAPI_Transform> op(
      new BRepBuilderAPI_Transform(shape->shape, transform, Standard_True));
    if (!op->IsDone())
      return nullptr;
    TopoDS_Shape result = op->Shape();
    if (result.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromMirror(OCCTShapeRef  shape,
                                                 double        originX,
                                                 double        originY,
                                                 double        originZ,
                                                 double        normalX,
                                                 double        normalY,
                                                 double        normalZ,
                                                 OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  if (!shape)
    return nullptr;
  try
  {
    gp_Ax2  mirrorPlane(gp_Pnt(originX, originY, originZ), gp_Dir(normalX, normalY, normalZ));
    gp_Trsf transform;
    transform.SetMirror(mirrorPlane);
    std::unique_ptr<BRepBuilderAPI_Transform> op(
      new BRepBuilderAPI_Transform(shape->shape, transform, Standard_True));
    if (!op->IsDone())
      return nullptr;
    TopoDS_Shape result = op->Shape();
    if (result.IsNull())
      return nullptr;
    if (outResult)
      *outResult = new OCCTShape(result);
    return new OCCTBooleanHistory(std::move(op), occtArgList(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromLinearPattern(OCCTShapeRef  shape,
                                                        double        dirX,
                                                        double        dirY,
                                                        double        dirZ,
                                                        double        spacing,
                                                        int32_t       count,
                                                        OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  try
  {
    // gp_Vec:Normalize throws on a zero-length vector, guard it here (the
    // plain OCCTShapeLinearPattern does the same inside its own try/catch);
    // occtPatternHistory's try/catch only covers what happens after this call.
    gp_Vec direction(dirX, dirY, dirZ);
    direction.Normalize();
    return occtPatternHistory(
      shape,
      count,
      [&](int32_t i) {
        gp_Trsf transform;
        transform.SetTranslation(direction * (spacing * i));
        return transform;
      },
      outResult);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBooleanHistoryRef OCCTShapeHistoryFromCircularPattern(OCCTShapeRef  shape,
                                                          double        axisX,
                                                          double        axisY,
                                                          double        axisZ,
                                                          double        axisDirX,
                                                          double        axisDirY,
                                                          double        axisDirZ,
                                                          int32_t       count,
                                                          double        angle,
                                                          OCCTShapeRef* outResult)
{
  if (outResult)
    *outResult = nullptr;
  try
  {
    // gp_Dir's constructor throws on a zero-length vector, same guarding
    // rationale as OCCTShapeHistoryFromLinearPattern above.
    gp_Ax1 axis(gp_Pnt(axisX, axisY, axisZ), gp_Dir(axisDirX, axisDirY, axisDirZ));
    double totalAngle = (angle == 0) ? (2.0 * M_PI) : angle;
    double stepAngle  = (count > 0) ? (totalAngle / count) : 0.0;
    return occtPatternHistory(
      shape,
      count,
      [&](int32_t i) {
        gp_Trsf transform;
        transform.SetRotation(axis, stepAngle * i);
        return transform;
      },
      outResult);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapePrism(OCCTShapeRef shape,
                            OCCTWireRef  profile,
                            double       dirX,
                            double       dirY,
                            double       dirZ,
                            double       height,
                            bool         fuse)
{
  if (!shape || !profile)
    return nullptr;

  try
  {
    // Create face from profile wire
    BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face profileFace = makeFace.Face();

    // Create the prism direction
    gp_Vec dir(dirX, dirY, dirZ);
    dir.Normalize();
    dir.Scale(height);

    // Create the prism shape (extrusion of the profile)
    BRepPrimAPI_MakePrism makePrism(profileFace, dir);
    if (!makePrism.IsDone())
      return nullptr;
    TopoDS_Shape prismShape = makePrism.Shape();

    // Fuse or cut with base shape
    TopoDS_Shape result;
    if (fuse)
    {
      BRepAlgoAPI_Fuse fuseOp(shape->shape, prismShape);
      if (!fuseOp.IsDone())
        return nullptr;
      result = fuseOp.Shape();
    }
    else
    {
      BRepAlgoAPI_Cut cutOp(shape->shape, prismShape);
      if (!cutOp.IsDone())
        return nullptr;
      result = cutOp.Shape();
    }

    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef* OCCTShapeSplit(OCCTShapeRef shape, OCCTShapeRef tool, int32_t* outCount)
{
  if (!shape || !tool || !outCount)
    return nullptr;
  *outCount = 0;

  try
  {
    // Use BRepAlgoAPI_Splitter for general splitting
    BRepAlgoAPI_Splitter splitter;

    // Set arguments (shapes to be split)
    TopTools_ListOfShape arguments;
    arguments.Append(shape->shape);
    splitter.SetArguments(arguments);

    // Set tools (cutting shapes)
    TopTools_ListOfShape tools;
    tools.Append(tool->shape);
    splitter.SetTools(tools);

    // Perform split
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

    // If no solids, try shells
    if (solids.empty())
    {
      for (TopExp_Explorer exp(result, TopAbs_SHELL); exp.More(); exp.Next())
      {
        solids.push_back(exp.Current());
      }
    }

    // If still nothing, return the whole result as one shape
    if (solids.empty())
    {
      solids.push_back(result);
    }

    // Allocate array
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
    *outCount = 0;
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeGlue(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance)
{
  if (!shape1 || !shape2)
    return nullptr;

  try
  {
    // Use BRepAlgoAPI_Fuse with glue option for coincident faces
    BRepAlgoAPI_Fuse fuse;
    fuse.SetGlue(BOPAlgo_GlueShift); // Enable gluing mode
    fuse.SetFuzzyValue(tolerance);

    TopTools_ListOfShape args;
    args.Append(shape1->shape);
    args.Append(shape2->shape);
    fuse.SetArguments(args);

    fuse.Build();
    if (!fuse.IsDone())
    {
      // Fallback to regular fuse
      BRepAlgoAPI_Fuse regularFuse(shape1->shape, shape2->shape);
      if (!regularFuse.IsDone())
        return nullptr;
      return new OCCTShape(regularFuse.Shape());
    }

    TopoDS_Shape result = fuse.Shape();
    if (result.IsNull())
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTFaceIntersect(OCCTFaceRef face1, OCCTFaceRef face2, double tolerance)
{
  if (!face1 || !face2)
    return nullptr;

  try
  {
    BRepAlgoAPI_Section section(face1->face, face2->face, Standard_False);
    section.Approximation(Standard_True);
    section.ComputePCurveOn1(Standard_True);
    section.ComputePCurveOn2(Standard_True);
    section.SetFuzzyValue(tolerance);
    section.Build();

    if (!section.IsDone())
      return nullptr;

    TopoDS_Shape result = section.Shape();
    if (result.IsNull())
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTHistoryRef OCCTHistoryCreate(void)
{
  try
  {
    auto* ref    = new OCCTHistoryStorage();
    ref->history = new BRepTools_History();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTHistoryAddModified(OCCTHistoryRef history, OCCTShapeRef initial, OCCTShapeRef modified)
{
  if (!history || !initial || !modified)
    return;
  try
  {
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    h->history->AddModified(initial->shape, modified->shape);
  }
  catch (...)
  {
  }
}

void OCCTHistoryAddGenerated(OCCTHistoryRef history, OCCTShapeRef initial, OCCTShapeRef generated)
{
  if (!history || !initial || !generated)
    return;
  try
  {
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    h->history->AddGenerated(initial->shape, generated->shape);
  }
  catch (...)
  {
  }
}

void OCCTHistoryRemove(OCCTHistoryRef history, OCCTShapeRef shape)
{
  if (!history || !shape)
    return;
  try
  {
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    h->history->Remove(shape->shape);
  }
  catch (...)
  {
  }
}

bool OCCTHistoryIsRemoved(OCCTHistoryRef history, OCCTShapeRef shape)
{
  if (!history || !shape)
    return false;
  try
  {
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    return h->history->IsRemoved(shape->shape);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTHistoryHasModified(OCCTHistoryRef history)
{
  if (!history)
    return false;
  auto* h = static_cast<OCCTHistoryStorage*>(history);
  return h->history->HasModified();
}

bool OCCTHistoryHasGenerated(OCCTHistoryRef history)
{
  if (!history)
    return false;
  auto* h = static_cast<OCCTHistoryStorage*>(history);
  return h->history->HasGenerated();
}

bool OCCTHistoryHasRemoved(OCCTHistoryRef history)
{
  if (!history)
    return false;
  auto* h = static_cast<OCCTHistoryStorage*>(history);
  return h->history->HasRemoved();
}

int32_t OCCTHistoryModifiedCount(OCCTHistoryRef history, OCCTShapeRef initial)
{
  if (!history || !initial)
    return 0;
  try
  {
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    return (int32_t)h->history->Modified(initial->shape).Size();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTHistoryGeneratedCount(OCCTHistoryRef history, OCCTShapeRef initial)
{
  if (!history || !initial)
    return 0;
  try
  {
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    return (int32_t)h->history->Generated(initial->shape).Size();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTHistoryDestroy(OCCTHistoryRef history)
{
  if (!history)
    return;
  delete static_cast<OCCTHistoryStorage*>(history);
}

OCCTShapeRef OCCTBOPAlgoSplit(const OCCTShapeRef* objects,
                              int32_t             objCount,
                              const OCCTShapeRef* tools,
                              int32_t             toolCount)
{
  if (!objects || objCount <= 0)
    return nullptr;
  try
  {
    BOPAlgo_Splitter splitter;
    for (int32_t i = 0; i < objCount; i++)
    {
      if (objects[i])
        splitter.AddArgument(objects[i]->shape);
    }
    if (tools)
    {
      for (int32_t i = 0; i < toolCount; i++)
      {
        if (tools[i])
          splitter.AddTool(tools[i]->shape);
      }
    }
    splitter.Perform();
    if (splitter.HasErrors())
      return nullptr;
    return new OCCTShape(splitter.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTBOPAlgoAnalyzeArguments(OCCTShapeRef shape1, OCCTShapeRef shape2, int32_t operation)
{
  if (!shape1 || !shape2)
    return false;
  try
  {
    BOPAlgo_ArgumentAnalyzer analyzer;
    analyzer.SetShape1(shape1->shape);
    analyzer.SetShape2(shape2->shape);
    analyzer.OperationType()    = static_cast<BOPAlgo_Operation>(operation);
    analyzer.ArgumentTypeMode() = true;
    analyzer.SelfInterMode()    = true;
    analyzer.SmallEdgeMode()    = true;
    analyzer.Perform();
    return !analyzer.HasFaulty();
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef _Nullable OCCTBOPAlgoSection(const OCCTShapeRef _Nonnull* _Nonnull objects,
                                          int32_t objCount,
                                          const OCCTShapeRef _Nonnull* _Nonnull tools,
                                          int32_t toolCount)
{
  if (objCount <= 0)
    return nullptr;
  try
  {
    BOPAlgo_Section section;
    for (int32_t i = 0; i < objCount; i++)
    {
      if (objects[i])
        section.AddArgument(objects[i]->shape);
    }
    for (int32_t i = 0; i < toolCount; i++)
    {
      if (tools[i])
        section.AddArgument(tools[i]->shape);
    }
    section.Perform();
    if (section.HasErrors())
      return nullptr;
    TopoDS_Shape result = section.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTIntToolsEdgeEdge(OCCTShapeRef _Nonnull edge1,
                          OCCTShapeRef _Nonnull edge2,
                          OCCTCommonPart* _Nullable* _Nonnull outParts,
                          int32_t* _Nonnull outCount)
{
  try
  {
    const TopoDS_Edge& e1 = TopoDS::Edge(edge1->shape);
    const TopoDS_Edge& e2 = TopoDS::Edge(edge2->shape);

    IntTools_EdgeEdge ee(e1, e2);
    ee.Perform();
    if (!ee.IsDone())
    {
      *outParts = nullptr;
      *outCount = 0;
      return false;
    }

    const IntTools_SequenceOfCommonPrts& cps = ee.CommonParts();
    int32_t                              n   = cps.Length();
    *outCount                                = n;
    if (n == 0)
    {
      *outParts = nullptr;
      return true;
    }

    *outParts = (OCCTCommonPart*)malloc(sizeof(OCCTCommonPart) * n);
    for (int32_t i = 0; i < n; i++)
    {
      fillCommonPart(cps(i + 1), (*outParts)[i]);
    }
    return true;
  }
  catch (...)
  {
    *outParts = nullptr;
    *outCount = 0;
    return false;
  }
}

bool OCCTIntToolsEdgeFace(OCCTShapeRef _Nonnull edge,
                          OCCTShapeRef _Nonnull face,
                          OCCTCommonPart* _Nullable* _Nonnull outParts,
                          int32_t* _Nonnull outCount)
{
  try
  {
    const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
    const TopoDS_Face& f = TopoDS::Face(face->shape);

    IntTools_EdgeFace ef;
    ef.SetEdge(e);
    ef.SetFace(f);
    ef.Perform();
    if (!ef.IsDone())
    {
      *outParts = nullptr;
      *outCount = 0;
      return false;
    }

    const IntTools_SequenceOfCommonPrts& cps = ef.CommonParts();
    int32_t                              n   = cps.Length();
    *outCount                                = n;
    if (n == 0)
    {
      *outParts = nullptr;
      return true;
    }

    *outParts = (OCCTCommonPart*)malloc(sizeof(OCCTCommonPart) * n);
    for (int32_t i = 0; i < n; i++)
    {
      fillCommonPart(cps(i + 1), (*outParts)[i]);
    }
    return true;
  }
  catch (...)
  {
    *outParts = nullptr;
    *outCount = 0;
    return false;
  }
}

bool OCCTIntToolsFaceFace(OCCTShapeRef _Nonnull face1,
                          OCCTShapeRef _Nonnull face2,
                          double tolerance,
                          OCCTFaceFaceCurve* _Nullable* _Nonnull outCurves,
                          int32_t* _Nonnull outCurveCount,
                          OCCTFaceFacePoint* _Nullable* _Nonnull outPoints,
                          int32_t* _Nonnull outPointCount,
                          bool* _Nonnull outTangent)
{
  try
  {
    const TopoDS_Face& f1 = TopoDS::Face(face1->shape);
    const TopoDS_Face& f2 = TopoDS::Face(face2->shape);

    IntTools_FaceFace ff;
    ff.SetParameters(true, true, true, tolerance);
    ff.Perform(f1, f2);
    if (!ff.IsDone())
    {
      *outCurves     = nullptr;
      *outCurveCount = 0;
      *outPoints     = nullptr;
      *outPointCount = 0;
      *outTangent    = false;
      return false;
    }

    *outTangent = ff.TangentFaces();

    // Curves
    const IntTools_SequenceOfCurves& lines = ff.Lines();
    int32_t                          nc    = lines.Length();
    *outCurveCount                         = nc;
    if (nc > 0)
    {
      *outCurves = (OCCTFaceFaceCurve*)malloc(sizeof(OCCTFaceFaceCurve) * nc);
      for (int32_t i = 0; i < nc; i++)
      {
        const IntTools_Curve& c  = lines(i + 1);
        (*outCurves)[i].hasStart = c.HasBounds();
        (*outCurves)[i].hasEnd   = c.HasBounds();
        if (c.HasBounds())
        {
          gp_Pnt p1, p2;
          c.Bounds((*outCurves)[i].startX, (*outCurves)[i].endX, p1, p2);
          // startX/endX are actually parameter values; use points
          (*outCurves)[i].startX = p1.X();
          (*outCurves)[i].startY = p1.Y();
          (*outCurves)[i].startZ = p1.Z();
          (*outCurves)[i].endX   = p2.X();
          (*outCurves)[i].endY   = p2.Y();
          (*outCurves)[i].endZ   = p2.Z();
        }
        else
        {
          (*outCurves)[i].startX = (*outCurves)[i].startY = (*outCurves)[i].startZ = 0;
          (*outCurves)[i].endX = (*outCurves)[i].endY = (*outCurves)[i].endZ = 0;
        }
      }
    }
    else
    {
      *outCurves = nullptr;
    }

    // Points
    const IntTools_SequenceOfPntOn2Faces& pts = ff.Points();
    int32_t                               np  = pts.Length();
    *outPointCount                            = np;
    if (np > 0)
    {
      *outPoints = (OCCTFaceFacePoint*)malloc(sizeof(OCCTFaceFacePoint) * np);
      for (int32_t i = 0; i < np; i++)
      {
        const IntTools_PntOn2Faces& pp = pts(i + 1);
        gp_Pnt                      p1 = pp.P1().Pnt();
        gp_Pnt                      p2 = pp.P2().Pnt();
        (*outPoints)[i].x1             = p1.X();
        (*outPoints)[i].y1             = p1.Y();
        (*outPoints)[i].z1             = p1.Z();
        (*outPoints)[i].x2             = p2.X();
        (*outPoints)[i].y2             = p2.Y();
        (*outPoints)[i].z2             = p2.Z();
      }
    }
    else
    {
      *outPoints = nullptr;
    }

    return true;
  }
  catch (...)
  {
    *outCurves     = nullptr;
    *outCurveCount = 0;
    *outPoints     = nullptr;
    *outPointCount = 0;
    *outTangent    = false;
    return false;
  }
}

int32_t OCCTIntToolsFClass2dPerform(OCCTShapeRef _Nonnull face,
                                    double u,
                                    double v,
                                    double tolerance)
{
  try
  {
    const TopoDS_Face& f = TopoDS::Face(face->shape);
    IntTools_FClass2d  fc(f, tolerance);
    TopAbs_State       state = fc.Perform(gp_Pnt2d(u, v));
    switch (state)
    {
      case TopAbs_IN:
        return 0;
      case TopAbs_ON:
        return 1;
      case TopAbs_OUT:
        return 2;
      default:
        return 3;
    }
  }
  catch (...)
  {
    return 3; // UNKNOWN
  }
}

bool OCCTIntToolsFClass2dIsHole(OCCTShapeRef _Nonnull face, double tolerance)
{
  try
  {
    const TopoDS_Face& f = TopoDS::Face(face->shape);
    IntTools_FClass2d  fc(f, tolerance);
    return fc.IsHole();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBOPAlgoBuilderFace(OCCTShapeRef _Nonnull baseFace,
                            const OCCTShapeRef _Nonnull* _Nonnull edges,
                            int32_t edgeCount,
                            OCCTShapeRef _Nullable* _Nullable* _Nonnull outFaces,
                            int32_t* _Nonnull outFaceCount)
{
  try
  {
    const TopoDS_Face& face = TopoDS::Face(baseFace->shape);

    BOPAlgo_BuilderFace bf;
    bf.SetFace(face);
    TopTools_ListOfShape shapes;
    for (int32_t i = 0; i < edgeCount; i++)
    {
      shapes.Append(edges[i]->shape);
    }
    bf.SetShapes(shapes);
    bf.Perform();

    if (bf.HasErrors())
    {
      *outFaces     = nullptr;
      *outFaceCount = 0;
      return false;
    }

    const TopTools_ListOfShape& areas = bf.Areas();
    int32_t                     n     = static_cast<int32_t>(areas.Size());
    *outFaceCount                     = n;
    if (n == 0)
    {
      *outFaces = nullptr;
      return true;
    }

    *outFaces   = (OCCTShapeRef*)malloc(sizeof(OCCTShapeRef) * n);
    int32_t idx = 0;
    for (TopTools_ListOfShape::Iterator it(areas); it.More(); it.Next(), idx++)
    {
      (*outFaces)[idx] = new OCCTShape(it.Value());
    }
    return true;
  }
  catch (...)
  {
    *outFaces     = nullptr;
    *outFaceCount = 0;
    return false;
  }
}

bool OCCTBOPAlgoBuilderSolid(const OCCTShapeRef _Nonnull* _Nonnull faces,
                             int32_t faceCount,
                             OCCTShapeRef _Nullable* _Nullable* _Nonnull outSolids,
                             int32_t* _Nonnull outSolidCount)
{
  try
  {
    BOPAlgo_BuilderSolid bs;
    TopTools_ListOfShape shapes;
    for (int32_t i = 0; i < faceCount; i++)
    {
      shapes.Append(faces[i]->shape);
    }
    bs.SetShapes(shapes);
    bs.Perform();

    if (bs.HasErrors())
    {
      *outSolids     = nullptr;
      *outSolidCount = 0;
      return false;
    }

    const TopTools_ListOfShape& areas = bs.Areas();
    int32_t                     n     = static_cast<int32_t>(areas.Size());
    *outSolidCount                    = n;
    if (n == 0)
    {
      *outSolids = nullptr;
      return true;
    }

    *outSolids  = (OCCTShapeRef*)malloc(sizeof(OCCTShapeRef) * n);
    int32_t idx = 0;
    for (TopTools_ListOfShape::Iterator it(areas); it.More(); it.Next(), idx++)
    {
      (*outSolids)[idx] = new OCCTShape(it.Value());
    }
    return true;
  }
  catch (...)
  {
    *outSolids     = nullptr;
    *outSolidCount = 0;
    return false;
  }
}

bool OCCTBOPAlgoShellSplitter(OCCTShapeRef _Nonnull shell,
                              OCCTShapeRef _Nullable* _Nullable* _Nonnull outShells,
                              int32_t* _Nonnull outShellCount)
{
  try
  {
    const TopoDS_Shell& sh = TopoDS::Shell(shell->shape);

    BOPAlgo_ShellSplitter ss;
    ss.AddStartElement(sh);
    ss.Perform();

    if (ss.HasErrors())
    {
      *outShells     = nullptr;
      *outShellCount = 0;
      return false;
    }

    const TopTools_ListOfShape& shells = ss.Shells();
    int32_t                     n      = static_cast<int32_t>(shells.Size());
    *outShellCount                     = n;
    if (n == 0)
    {
      *outShells = nullptr;
      return true;
    }

    *outShells  = (OCCTShapeRef*)malloc(sizeof(OCCTShapeRef) * n);
    int32_t idx = 0;
    for (TopTools_ListOfShape::Iterator it(shells); it.More(); it.Next(), idx++)
    {
      (*outShells)[idx] = new OCCTShape(it.Value());
    }
    return true;
  }
  catch (...)
  {
    *outShells     = nullptr;
    *outShellCount = 0;
    return false;
  }
}

OCCTShapeRef _Nullable OCCTBOPAlgoEdgesToWires(OCCTShapeRef _Nonnull edges, double tolerance)
{
  try
  {
    TopoDS_Shape result;
    bool         shared = false;
    int          status = BOPAlgo_Tools::EdgesToWires(edges->shape, result, shared, tolerance);
    if (status != 0)
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBOPAlgoWiresToFaces(OCCTShapeRef _Nonnull wires, double tolerance)
{
  try
  {
    TopoDS_Shape result;
    bool         ok = BOPAlgo_Tools::WiresToFaces(wires->shape, result, tolerance);
    if (!ok)
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTBOPToolsNormalOnEdge(OCCTShapeRef _Nonnull edge,
                              OCCTShapeRef _Nonnull face,
                              double* _Nonnull outNX,
                              double* _Nonnull outNY,
                              double* _Nonnull outNZ)
{
  try
  {
    const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
    const TopoDS_Face& f = TopoDS::Face(face->shape);

    gp_Dir normal;
    BOPTools_AlgoTools3D::GetNormalToFaceOnEdge(e, f, normal);
    *outNX = normal.X();
    *outNY = normal.Y();
    *outNZ = normal.Z();
    return true;
  }
  catch (...)
  {
    *outNX = *outNY = *outNZ = 0;
    return false;
  }
}

bool OCCTBOPToolsPointInFace(OCCTShapeRef _Nonnull face,
                             double* _Nonnull outX,
                             double* _Nonnull outY,
                             double* _Nonnull outZ)
{
  try
  {
    const TopoDS_Face& f = TopoDS::Face(face->shape);

    gp_Pnt                   pnt;
    gp_Pnt2d                 pnt2d;
    Handle(IntTools_Context) ctx    = new IntTools_Context();
    int                      status = BOPTools_AlgoTools3D::PointInFace(f, pnt, pnt2d, ctx);
    if (status != 0)
      return false;

    *outX = pnt.X();
    *outY = pnt.Y();
    *outZ = pnt.Z();
    return true;
  }
  catch (...)
  {
    *outX = *outY = *outZ = 0;
    return false;
  }
}

bool OCCTBOPToolsIsEmptyShape(OCCTShapeRef _Nonnull shape)
{
  try
  {
    return BOPTools_AlgoTools3D::IsEmptyShape(shape->shape);
  }
  catch (...)
  {
    return true;
  }
}

bool OCCTBOPToolsIsOpenShell(OCCTShapeRef _Nonnull shell)
{
  try
  {
    const TopoDS_Shell& sh = TopoDS::Shell(shell->shape);
    return BOPTools_AlgoTools::IsOpenShell(sh);
  }
  catch (...)
  {
    return true;
  }
}

bool OCCTIntToolsBeanFaceIntersect(OCCTShapeRef _Nonnull edge,
                                   OCCTShapeRef _Nonnull face,
                                   OCCTParameterRange* _Nullable* _Nonnull outRanges,
                                   int32_t* _Nonnull outCount,
                                   double* _Nonnull outMinSquareDist)
{
  *outRanges        = nullptr;
  *outCount         = 0;
  *outMinSquareDist = 0.0;
  try
  {
    const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
    const TopoDS_Face& f = TopoDS::Face(face->shape);

    IntTools_BeanFaceIntersector bfi(e, f);
    bfi.Perform();
    if (!bfi.IsDone())
      return false;

    *outMinSquareDist = bfi.MinimalSquareDistance();

    const NCollection_Sequence<IntTools_Range>& ranges = bfi.Result();
    int32_t                                     n      = ranges.Length();
    *outCount                                          = n;
    if (n > 0)
    {
      *outRanges = (OCCTParameterRange*)malloc(n * sizeof(OCCTParameterRange));
      for (int32_t i = 0; i < n; i++)
      {
        (*outRanges)[i].first = ranges(i + 1).First();
        (*outRanges)[i].last  = ranges(i + 1).Last();
      }
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef _Nullable OCCTBOPAlgoMakeWire(const OCCTShapeRef _Nonnull* _Nonnull edges,
                                           int32_t edgeCount)
{
  try
  {
    NCollection_List<TopoDS_Shape> edgeList;
    for (int32_t i = 0; i < edgeCount; i++)
    {
      edgeList.Append(edges[i]->shape);
    }
    TopoDS_Wire wire;
    BOPAlgo_WireSplitter::MakeWire(edgeList, wire);
    if (wire.IsNull())
      return nullptr;
    return new OCCTShape(wire);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTIntToolsComputeVV(OCCTShapeRef vertex1, OCCTShapeRef vertex2)
{
  if (!vertex1 || !vertex2)
    return -1;
  try
  {
    return IntTools_Tools::ComputeVV(TopoDS::Vertex(vertex1->shape),
                                     TopoDS::Vertex(vertex2->shape));
  }
  catch (...)
  {
    return -1;
  }
}

double OCCTIntToolsIntermediatePoint(double first, double last)
{
  try
  {
    return IntTools_Tools::IntermediatePoint(first, last);
  }
  catch (...)
  {
    return 0.5 * (first + last);
  }
}

bool OCCTIntToolsIsDirsCoinside(double dx1,
                                double dy1,
                                double dz1,
                                double dx2,
                                double dy2,
                                double dz2)
{
  try
  {
    return IntTools_Tools::IsDirsCoinside(gp_Dir(dx1, dy1, dz1), gp_Dir(dx2, dy2, dz2));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTIntToolsIsDirsCoinisdeWithTol(double dx1,
                                       double dy1,
                                       double dz1,
                                       double dx2,
                                       double dy2,
                                       double dz2,
                                       double tol)
{
  try
  {
    return IntTools_Tools::IsDirsCoinside(gp_Dir(dx1, dy1, dz1), gp_Dir(dx2, dy2, dz2), tol);
  }
  catch (...)
  {
    return false;
  }
}

double OCCTIntToolsComputeIntRange(double tol1, double tol2, double angle)
{
  try
  {
    return IntTools_Tools::ComputeIntRange(tol1, tol2, angle);
  }
  catch (...)
  {
    return 0.0;
  }
}

OCCTBRepAlgoImageRef OCCTBRepAlgoImageCreate()
{
  return new OCCTBRepAlgoImage();
}

void OCCTBRepAlgoImageRelease(OCCTBRepAlgoImageRef img)
{
  delete img;
}

void OCCTBRepAlgoImageSetRoot(OCCTBRepAlgoImageRef img, OCCTShapeRef shape)
{
  if (img && shape)
    img->image.SetRoot(shape->shape);
}

void OCCTBRepAlgoImageBind(OCCTBRepAlgoImageRef img, OCCTShapeRef oldShape, OCCTShapeRef newShape)
{
  if (img && oldShape && newShape)
    img->image.Bind(oldShape->shape, newShape->shape);
}

bool OCCTBRepAlgoImageHasImage(OCCTBRepAlgoImageRef img, OCCTShapeRef shape)
{
  if (!img || !shape)
    return false;
  return img->image.HasImage(shape->shape);
}

bool OCCTBRepAlgoImageIsImage(OCCTBRepAlgoImageRef img, OCCTShapeRef shape)
{
  if (!img || !shape)
    return false;
  return img->image.IsImage(shape->shape);
}

void OCCTBRepAlgoImageClear(OCCTBRepAlgoImageRef img)
{
  if (img)
    img->image.Clear();
}

int32_t OCCTShapeBuildLoops(OCCTShapeRef shape, int32_t faceIndex)
{
  if (!shape)
    return -1;
  try
  {
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return -1;

    BRepAlgo_Loop loop;
    loop.Init(face);
    TopExp_Explorer edgeExp(face, TopAbs_EDGE);
    while (edgeExp.More())
    {
      loop.AddConstEdge(TopoDS::Edge(edgeExp.Current()));
      edgeExp.Next();
    }
    loop.Perform();
    return static_cast<int32_t>(loop.NewWires().Size());
  }
  catch (...)
  {
    return -1;
  }
}

OCCTAsDesRef OCCTAsDesCreate(void)
{
  return new OCCTAsDes();
}

void OCCTAsDesRelease(OCCTAsDesRef ad)
{
  delete ad;
}

void OCCTAsDesAdd(OCCTAsDesRef ad, OCCTShapeRef parent, OCCTShapeRef child)
{
  if (!ad || !parent || !child)
    return;
  try
  {
    ad->ad->Add(parent->shape, child->shape);
  }
  catch (...)
  {
  }
}

bool OCCTAsDesHasDescendant(OCCTAsDesRef ad, OCCTShapeRef shape)
{
  if (!ad || !shape)
    return false;
  try
  {
    return ad->ad->HasDescendant(shape->shape);
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTAsDesDescendantCount(OCCTAsDesRef ad, OCCTShapeRef shape)
{
  if (!ad || !shape)
    return 0;
  try
  {
    if (!ad->ad->HasDescendant(shape->shape))
      return 0;
    const TopTools_ListOfShape& desc = ad->ad->Descendant(shape->shape);
    return (int32_t)desc.Extent();
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTBooleanFuseWithTolerance(OCCTShapeRef s1, OCCTShapeRef s2, double fuzzyTol)
{
  if (!s1 || !s2)
    return nullptr;
  try
  {
    BRepAlgoAPI_Fuse fuse(s1->shape, s2->shape);
    fuse.SetFuzzyValue(fuzzyTol);
    fuse.Build();
    if (!fuse.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = fuse.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBooleanCutWithTolerance(OCCTShapeRef s1, OCCTShapeRef s2, double fuzzyTol)
{
  if (!s1 || !s2)
    return nullptr;
  try
  {
    BRepAlgoAPI_Cut cut(s1->shape, s2->shape);
    cut.SetFuzzyValue(fuzzyTol);
    cut.Build();
    if (!cut.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = cut.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBooleanCommonWithTolerance(OCCTShapeRef s1, OCCTShapeRef s2, double fuzzyTol)
{
  if (!s1 || !s2)
    return nullptr;
  try
  {
    BRepAlgoAPI_Common common(s1->shape, s2->shape);
    common.SetFuzzyValue(fuzzyTol);
    common.Build();
    if (!common.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = common.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBooleanFuseGlue(OCCTShapeRef s1, OCCTShapeRef s2, int32_t glueMode)
{
  if (!s1 || !s2)
    return nullptr;
  try
  {
    BRepAlgoAPI_Fuse fuse(s1->shape, s2->shape);
    fuse.SetGlue(toGlueEnum(glueMode));
    fuse.Build();
    if (!fuse.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = fuse.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBooleanCutGlue(OCCTShapeRef s1, OCCTShapeRef s2, int32_t glueMode)
{
  if (!s1 || !s2)
    return nullptr;
  try
  {
    BRepAlgoAPI_Cut cut(s1->shape, s2->shape);
    cut.SetGlue(toGlueEnum(glueMode));
    cut.Build();
    if (!cut.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = cut.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBooleanCommonGlue(OCCTShapeRef s1, OCCTShapeRef s2, int32_t glueMode)
{
  if (!s1 || !s2)
    return nullptr;
  try
  {
    BRepAlgoAPI_Common common(s1->shape, s2->shape);
    common.SetGlue(toGlueEnum(glueMode));
    common.Build();
    if (!common.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = common.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBooleanSectionWithTolerance(OCCTShapeRef s1, OCCTShapeRef s2, double fuzzyTol)
{
  if (!s1 || !s2)
    return nullptr;
  try
  {
    BRepAlgoAPI_Section sec(s1->shape, s2->shape, Standard_False);
    sec.SetFuzzyValue(fuzzyTol);
    sec.Build();
    if (sec.IsDone())
    {
      return new OCCTShape{sec.Shape()};
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBooleanSplitMulti(OCCTShapeRef        shape,
                                   const OCCTShapeRef* tools,
                                   int32_t             toolCount,
                                   double              fuzzyTol)
{
  if (!shape || !tools || toolCount < 1)
    return nullptr;
  try
  {
    BRepAlgoAPI_Splitter splitter;
    TopTools_ListOfShape args, toolShapes;
    args.Append(shape->shape);
    for (int i = 0; i < toolCount; i++)
    {
      if (tools[i])
        toolShapes.Append(tools[i]->shape);
    }
    splitter.SetArguments(args);
    splitter.SetTools(toolShapes);
    if (fuzzyTol > 0)
      splitter.SetFuzzyValue(fuzzyTol);
    splitter.Build();
    if (splitter.IsDone())
    {
      return new OCCTShape{splitter.Shape()};
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBooleanCutWithHistory(OCCTShapeRef s1,
                                       OCCTShapeRef s2,
                                       double       fuzzyTol,
                                       bool*        hasDeleted,
                                       bool*        hasModified,
                                       bool*        hasGenerated)
{
  if (!s1 || !s2)
    return nullptr;
  *hasDeleted   = false;
  *hasModified  = false;
  *hasGenerated = false;
  try
  {
    BRepAlgoAPI_Cut      cut;
    TopTools_ListOfShape args, tools;
    args.Append(s1->shape);
    tools.Append(s2->shape);
    cut.SetArguments(args);
    cut.SetTools(tools);
    if (fuzzyTol > 0)
      cut.SetFuzzyValue(fuzzyTol);
    cut.Build();
    if (cut.IsDone())
    {
      *hasDeleted   = cut.HasDeleted();
      *hasModified  = cut.HasModified();
      *hasGenerated = cut.HasGenerated();
      return new OCCTShape{cut.Shape()};
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - v0.118: Defeature + Sewing nbMultipleEdges
// The shape-addressed defeaturing entry point, and since #497 the only one: it absorbed
// OCCTDefeatureWithTolerance, whose fuzzy tolerance BRepAlgoAPI_Defeaturing discards.
OCCTShapeRef OCCTShapeDefeature(OCCTShapeRef shape, const OCCTShapeRef* faces, int32_t faceCount)
{
  if (!shape)
    return nullptr;
  try
  {
    TopTools_ListOfShape facesToRemove;
    if (!occtDefeaturingFacesFromShapes(shape->shape, faces, faceCount, facesToRemove))
      return nullptr;

    BRepAlgoAPI_Defeaturing defeaturing;
    TopoDS_Shape            result;
    if (!occtDefeaturePerform(defeaturing, shape->shape, facesToRemove, result))
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTHistoryMerge(OCCTHistoryRef history, OCCTHistoryRef other)
{
  if (!history || !other)
    return;
  try
  {
    auto* h1 = static_cast<OCCTHistoryStorage*>(history);
    auto* h2 = static_cast<OCCTHistoryStorage*>(other);
    if (!h1->history.IsNull() && !h2->history.IsNull())
    {
      h1->history->Merge(h2->history);
    }
  }
  catch (...)
  {
  }
}

void OCCTHistoryReplaceGenerated(OCCTHistoryRef history,
                                 OCCTShapeRef   initial,
                                 OCCTShapeRef   generated)
{
  if (!history || !initial || !generated)
    return;
  try
  {
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    if (!h->history.IsNull())
    {
      h->history->ReplaceGenerated(initial->shape, generated->shape);
    }
  }
  catch (...)
  {
  }
}

void OCCTHistoryReplaceModified(OCCTHistoryRef history, OCCTShapeRef initial, OCCTShapeRef modified)
{
  if (!history || !initial || !modified)
    return;
  try
  {
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    if (!h->history.IsNull())
    {
      h->history->ReplaceModified(initial->shape, modified->shape);
    }
  }
  catch (...)
  {
  }
}

int32_t OCCTHistoryGetModifiedShapes(OCCTHistoryRef history,
                                     OCCTShapeRef   initial,
                                     OCCTShapeRef*  outShapes,
                                     int32_t        maxCount)
{
  if (!history || !initial || !outShapes || maxCount <= 0)
    return 0;
  try
  {
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    if (h->history.IsNull())
      return 0;
    const auto& modified = h->history->Modified(initial->shape);
    int32_t     count    = 0;
    for (auto it = modified.cbegin(); it != modified.cend() && count < maxCount; ++it, ++count)
    {
      auto* ref        = new OCCTShape;
      ref->shape       = *it;
      outShapes[count] = ref;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTHistoryGetGeneratedShapes(OCCTHistoryRef history,
                                      OCCTShapeRef   initial,
                                      OCCTShapeRef*  outShapes,
                                      int32_t        maxCount)
{
  if (!history || !initial || !outShapes || maxCount <= 0)
    return 0;
  try
  {
    auto* h = static_cast<OCCTHistoryStorage*>(history);
    if (h->history.IsNull())
      return 0;
    const auto& generated = h->history->Generated(initial->shape);
    int32_t     count     = 0;
    for (auto it = generated.cbegin(); it != generated.cend() && count < maxCount; ++it, ++count)
    {
      auto* ref        = new OCCTShape;
      ref->shape       = *it;
      outShapes[count] = ref;
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTShapeSectionWithOptions(OCCTShapeRef shape1,
                                         OCCTShapeRef shape2,
                                         bool         approximation,
                                         bool         computePCurve1,
                                         bool         computePCurve2)
{
  if (!shape1 || !shape2)
    return nullptr;
  try
  {
    BRepAlgoAPI_Section section(shape1->shape, shape2->shape, false);
    section.Approximation(approximation);
    section.ComputePCurveOn1(computePCurve1);
    section.ComputePCurveOn2(computePCurve2);
    section.Build();
    if (!section.IsDone())
      return nullptr;
    TopoDS_Shape result = section.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape{result};
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTSectionAncestorFaceOn1(OCCTShapeRef shape1,
                                        OCCTShapeRef shape2,
                                        OCCTShapeRef edge,
                                        bool         approximation,
                                        bool         computePCurve1,
                                        bool         computePCurve2)
{
  if (!shape1 || !shape2 || !edge)
    return nullptr;
  try
  {
    BRepAlgoAPI_Section section(shape1->shape, shape2->shape, false);
    section.Approximation(approximation);
    section.ComputePCurveOn1(computePCurve1);
    section.ComputePCurveOn2(computePCurve2);
    section.Build();
    if (!section.IsDone())
      return nullptr;
    TopoDS_Shape face;
    if (section.HasAncestorFaceOn1(edge->shape, face))
    {
      return new OCCTShape{face};
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTSectionAncestorFaceOn2(OCCTShapeRef shape1,
                                        OCCTShapeRef shape2,
                                        OCCTShapeRef edge,
                                        bool         approximation,
                                        bool         computePCurve1,
                                        bool         computePCurve2)
{
  if (!shape1 || !shape2 || !edge)
    return nullptr;
  try
  {
    BRepAlgoAPI_Section section(shape1->shape, shape2->shape, false);
    section.Approximation(approximation);
    section.ComputePCurveOn1(computePCurve1);
    section.ComputePCurveOn2(computePCurve2);
    section.Build();
    if (!section.IsDone())
      return nullptr;
    TopoDS_Shape face;
    if (section.HasAncestorFaceOn2(edge->shape, face))
    {
      return new OCCTShape{face};
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeSectionWithPlane(OCCTShapeRef shape,
                                       double       normalX,
                                       double       normalY,
                                       double       normalZ,
                                       double       originX,
                                       double       originY,
                                       double       originZ)
{
  if (!shape)
    return nullptr;
  try
  {
    gp_Pln              plane(gp_Pnt(originX, originY, originZ), gp_Dir(normalX, normalY, normalZ));
    BRepAlgoAPI_Section section(shape->shape, plane);
    section.Build();
    if (!section.IsDone() || section.Shape().IsNull())
      return nullptr;
    return new OCCTShape(section.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeSectionWithSurface(OCCTShapeRef shape, OCCTSurfaceRef surface)
{
  if (!shape || !surface || surface->surface.IsNull())
    return nullptr;
  try
  {
    BRepAlgoAPI_Section section(shape->shape, surface->surface);
    section.Build();
    if (!section.IsDone() || section.Shape().IsNull())
      return nullptr;
    return new OCCTShape(section.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeUnion(OCCTShapeRef shape1, OCCTShapeRef shape2)
{
  if (!shape1 || !shape2)
    return nullptr;
  occtEnsureSignals();
  try
  {
    OCC_CATCH_SIGNALS
    BRepAlgoAPI_Fuse fuser(shape1->shape, shape2->shape);
    fuser.Build();
    if (!fuser.IsDone())
      return nullptr;
    return new OCCTShape(fuser.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeSubtract(OCCTShapeRef shape1, OCCTShapeRef shape2)
{
  if (!shape1 || !shape2)
    return nullptr;
  try
  {
    BRepAlgoAPI_Cut cutter(shape1->shape, shape2->shape);
    cutter.Build();
    if (!cutter.IsDone())
      return nullptr;
    return new OCCTShape(cutter.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeIntersect(OCCTShapeRef shape1, OCCTShapeRef shape2)
{
  if (!shape1 || !shape2)
    return nullptr;
  try
  {
    BRepAlgoAPI_Common intersector(shape1->shape, shape2->shape);
    intersector.Build();
    if (!intersector.IsDone())
      return nullptr;
    return new OCCTShape(intersector.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

DEFINE_STANDARD_HANDLE(OCCTBoolTimeoutBreaker, Message_ProgressIndicator)

// Shared driver: BRepAlgoAPI_Fuse/Cut/Common all derive from
// BRepAlgoAPI_BooleanOperation, so the option setters are identical across ops.
// timeoutSeconds <= 0 means no time bound (run to completion).
//
// outTimedOut, when not NULL, separates the two reasons a caller gets NULL: 1 for the
// watchdog interrupting the build, 0 for every other failure (#1067). The breaker is
// declared outside the try so the catch can read it too, since an abort that unwinds as
// an exception is still an abort.
//
// tripped() is read here only to EXPLAIN a NULL that IsDone() already decided on, never to
// decide one. OCCTShapeSelfIntersectsBounded below reads the same flag before its results
// instead, because BOPAlgo_ArgumentAnalyzer has no IsDone() to decide with; see the comment
// there for why that difference is the same rule and not two (#1054).
template <typename BoolOpT>
static OCCTShapeRef runBooleanEx(OCCTShapeRef shape1,
                                 OCCTShapeRef shape2,
                                 double       fuzzyValue,
                                 int32_t      glue,
                                 double       timeoutSeconds,
                                 int32_t* _Nullable outTimedOut)
{
  if (outTimedOut)
    *outTimedOut = 0;
  if (!shape1 || !shape2)
    return nullptr;
  occtEnsureSignals();
  Handle(OCCTBoolTimeoutBreaker) breaker;
  try
  {
    OCC_CATCH_SIGNALS
    BoolOpT              op;
    TopTools_ListOfShape args;
    args.Append(shape1->shape);
    TopTools_ListOfShape tools;
    tools.Append(shape2->shape);
    op.SetArguments(args);
    op.SetTools(tools);
    if (fuzzyValue > 0.0)
      op.SetFuzzyValue(fuzzyValue);
    switch (glue)
    {
      case 1:
        op.SetGlue(BOPAlgo_GlueShift);
        break;
      case 2:
        op.SetGlue(BOPAlgo_GlueFull);
        break;
      default:
        op.SetGlue(BOPAlgo_GlueOff);
        break;
    }
    if (timeoutSeconds > 0.0)
    {
      breaker                     = new OCCTBoolTimeoutBreaker(timeoutSeconds);
      Message_ProgressRange range = breaker->Start();
      op.Build(range);
    }
    else
    {
      op.Build();
    }
    // IsDone() is false both on genuine failure and when the watchdog interrupted the
    // build, either way there is no usable result. The breaker is what tells the two
    // apart, and it is only asked once the op has already declined: a completed build
    // is a completed build even if a late poll happened to trip.
    if (!op.IsDone())
    {
      if (outTimedOut && !breaker.IsNull() && breaker->tripped())
        *outTimedOut = 1;
      return nullptr;
    }
    return new OCCTShape(op.Shape());
  }
  catch (...)
  {
    if (outTimedOut && !breaker.IsNull() && breaker->tripped())
      *outTimedOut = 1;
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeUnionEx(OCCTShapeRef shape1,
                              OCCTShapeRef shape2,
                              double       fuzzyValue,
                              int32_t      glue,
                              double       timeoutSeconds,
                              int32_t* _Nullable outTimedOut)
{
  return runBooleanEx<BRepAlgoAPI_Fuse>(shape1,
                                        shape2,
                                        fuzzyValue,
                                        glue,
                                        timeoutSeconds,
                                        outTimedOut);
}

OCCTShapeRef OCCTShapeSubtractEx(OCCTShapeRef shape1,
                                 OCCTShapeRef shape2,
                                 double       fuzzyValue,
                                 int32_t      glue,
                                 double       timeoutSeconds,
                                 int32_t* _Nullable outTimedOut)
{
  return runBooleanEx<BRepAlgoAPI_Cut>(shape1,
                                       shape2,
                                       fuzzyValue,
                                       glue,
                                       timeoutSeconds,
                                       outTimedOut);
}

OCCTShapeRef OCCTShapeIntersectEx(OCCTShapeRef shape1,
                                  OCCTShapeRef shape2,
                                  double       fuzzyValue,
                                  int32_t      glue,
                                  double       timeoutSeconds,
                                  int32_t* _Nullable outTimedOut)
{
  return runBooleanEx<BRepAlgoAPI_Common>(shape1,
                                          shape2,
                                          fuzzyValue,
                                          glue,
                                          timeoutSeconds,
                                          outTimedOut);
}

// Reports whether a shape self-intersects (overlapping/interfering sub-faces), the
// defect that BRepCheck_Analyzer misses but that poisons downstream booleans (#206).
// BOPAlgo_ArgumentAnalyzer's self-interference test is authoritative but can be slow
// (>10s on the #206 B-spline operands) or unbounded, so it runs with StopOnFirstFaulty
// and the same wall-clock watchdog as the booleans.
//   returns:  1 = self-intersects,  0 = clean,
//            -1 = indeterminate (timed out, argument refused, or errored)
// The watchdog is read before the results and the results are read by status rather
// than through HasFaulty(), both because HasFaulty() answers a wider question than the
// one asked here; the measurements are in Scripts/repro/1054-selfintersect-fault-kinds/
// and summarised in docs/reference/Shape-Features.md (#1054).
//
// runBooleanEx above reads the same OCCTBoolTimeoutBreaker::tripped() flag in the
// opposite order, deliberately (#1067/#1079). The rule both follow is about which signal
// decides whether the work COMPLETED, not about whether the watchdog is consulted at all:
// each asks the operation first if the operation can answer, and the watchdog only to
// explain an answer already given. A BRepAlgoAPI_BooleanOperation can answer, through
// IsDone(), so runBooleanEx consults tripped() inside the !IsDone() branch and its catch,
// to say WHY the build produced nothing, and a completed build is kept even if a late poll
// happened to trip. BOPAlgo_ArgumentAnalyzer exposes no equivalent: no done
// flag, a result list populated the same way whether it ran to the end or not, and a
// progress position that is no substitute, since every scope advances to its own end when
// it is destroyed (measured: an aborted run still closes "Analyze shapes" at pos=1.000).
// It does inherit BOPAlgo_Options::HasErrors(), which its own UserBreak calls set, and
// that agrees with tripped() at every break point measured, but it says nothing on the
// unbounded path this function also serves, which is the path isSelfIntersecting
// (hardTimeout:) takes. So tripped() is read first and a late trip costs a real answer.
// That cost is the smaller one: a clean box interrupted anywhere in the last fifth of its
// analysis reports up to three self-interferences of its own.
int32_t OCCTShapeSelfIntersectsBounded(OCCTShapeRef shape, double timeoutSeconds)
{
  if (!shape)
    return -1;
  occtEnsureSignals();
  try
  {
    OCC_CATCH_SIGNALS
    BOPAlgo_ArgumentAnalyzer aa;
    aa.SetShape1(shape->shape);
    aa.ArgumentTypeMode()  = Standard_True; // basic argument sanity
    aa.SelfInterMode()     = Standard_True; // the self-interference test we care about
    aa.StopOnFirstFaulty() = Standard_True; // bail as soon as one fault is found
    aa.SetRunParallel(Standard_False);
    Handle(OCCTBoolTimeoutBreaker) breaker;
    if (timeoutSeconds > 0.0)
    {
      breaker                     = new OCCTBoolTimeoutBreaker(timeoutSeconds);
      Message_ProgressRange range = breaker->Start();
      aa.Perform(range);
    }
    else
    {
      aa.Perform();
    }
    // An aborted analysis answers nothing, whatever it recorded on the way out.
    // BOPAlgo_CheckerSI::CheckFaceSelfIntersection clears BOPDS_DS::Interferences() on
    // entry, and the PostTreat that follows re-adds only pairs passing its own per-type
    // gates, which for a valid solid's face adjacency is none. Interrupt the analysis
    // before that Clear() and TestSelfInterferences reads the pave filler's own raw map
    // instead, so a clean box reports up to three BOPAlgo_SelfIntersect results of its
    // own. Measured in Scripts/repro/1054-selfintersect-fault-kinds/, which localises the
    // transition to one poll with every other observable identical either side.
    if (!breaker.IsNull() && breaker->tripped())
      return -1;
    // HasFaulty() is "did any enabled mode record something", and ArgumentTypeMode is
    // enabled too, so read the statuses instead. BOPAlgo_BadType (an argument BOP cannot
    // use, e.g. an emptied solid) and BOPAlgo_OperationAborted (the self-interference pass
    // gave up) are recorded the same way a real interference is, and neither is an answer
    // to "does this shape self-intersect".
    bool selfIntersects = false;
    bool otherFault     = false;
    for (NCollection_List<BOPAlgo_CheckResult>::Iterator it(aa.GetCheckResult()); it.More();
         it.Next())
    {
      if (it.Value().GetCheckStatus() == BOPAlgo_SelfIntersect)
        selfIntersects = true;
      else
        otherFault = true;
    }
    // otherFault wins over selfIntersects, deliberately. BOPAlgo_OperationAborted is
    // appended after whatever the aborted pass had already recorded, and it is appended
    // for any BOPAlgo_CheckerSI error, not only a watchdog break, so the tripped() test
    // above does not cover it: the unbounded entry point never has a breaker at all.
    // BOPAlgo_CheckUnknown is the other status that can share the list with a genuine
    // interference, since Perform's own catch appends it after TestSelfInterferences has
    // run. Both mean the analysis did not finish, so both outrank what it managed to
    // record. BOPAlgo_BadType cannot share the list either, on both of the branches that
    // record it: a shape with no geometry (BOPTools_AlgoTools3D::IsEmptyShape) and a null
    // shape, which TestTypes catches first. TestSelfInterferences skips both.
    if (otherFault)
      return -1; // analysed something, but not the question asked
    if (selfIntersects)
      return 1; // conclusive
    return 0;   // completed clean
  }
  catch (...)
  {
    return -1; // interrupted by the watchdog, or analyzer error, either way indeterminate
  }
}

// --- Detailed self-intersection check with progress info (#1068) ---
//
// Reports self-intersection status with granular progress information.
// Status codes:
//   1  = self-intersects (conclusive)
//   0  = clean (conclusive)
//  -1  = indeterminate (timed out, breaker tripped - analysis was running)
//  -2  = indeterminate (timed out, breaker NOT tripped - analysis made no progress)
//  -3  = error (exception occurred, or the analyzer recorded a fault other than
//        BOPAlgo_SelfIntersect, e.g. BOPAlgo_BadType for a refused/empty argument - #1436)
//
// Output parameters (optional, can pass nullptr):
//   - outTotalFacePairs: estimated total face pairs to check
//   - outTimeSpent: actual time spent in seconds
int32_t OCCTShapeSelfIntersectsDetailed(OCCTShapeRef shape,
                                        double       timeoutSeconds,
                                        int32_t* _Nullable outTotalFacePairs,
                                        double* _Nullable outTimeSpent)
{
  if (!shape)
    return -3;
  if (outTotalFacePairs)
    *outTotalFacePairs = 0;
  if (outTimeSpent)
    *outTimeSpent = 0.0;

  auto startTime = std::chrono::steady_clock::now();
  occtEnsureSignals();
  try
  {
    OCC_CATCH_SIGNALS
    BOPAlgo_ArgumentAnalyzer aa;
    aa.SetShape1(shape->shape);
    aa.ArgumentTypeMode()  = Standard_True;
    aa.SelfInterMode()     = Standard_True;
    aa.StopOnFirstFaulty() = Standard_True;
    aa.SetRunParallel(Standard_False);

    // Estimate total face pairs for progress reporting
    int32_t estimatedTotalPairs = 0;
    if (outTotalFacePairs)
    {
      TopExp_Explorer exp(shape->shape, TopAbs_FACE);
      int32_t         numFaces = 0;
      while (exp.More())
      {
        numFaces++;
        exp.Next();
      }
      // Upper bound: n*(n-1)/2 pairs, but self-intersection checks adjacent faces too
      // A more realistic estimate for self-intersection is ~n^2 / 4
      estimatedTotalPairs = (numFaces * numFaces) / 4;
      *outTotalFacePairs  = estimatedTotalPairs;
    }

    Handle(OCCTBoolTimeoutBreaker) breaker;
    if (timeoutSeconds > 0.0)
    {
      breaker                     = new OCCTBoolTimeoutBreaker(timeoutSeconds);
      Message_ProgressRange range = breaker->Start();
      aa.Perform(range);
    }
    else
    {
      aa.Perform();
    }

    auto endTime = std::chrono::steady_clock::now();
    if (outTimeSpent)
    {
      *outTimeSpent = std::chrono::duration<double>(endTime - startTime).count();
    }

    // The watchdog is read before the results, same order and same reason as
    // OCCTShapeSelfIntersectsBounded above (#1054): an aborted analysis answers nothing,
    // whatever it recorded on the way out, and a breaker-interrupted run can report up to
    // three spurious BOPAlgo_SelfIntersect entries of its own (Scripts/repro/
    // 1054-selfintersect-fault-kinds/). Trusting HasFaulty()/the fault loop ahead of this
    // check would reintroduce that exact bug here.
    bool breakerTripped = (!breaker.IsNull() && breaker->tripped());
    bool deadlinePassed = (!breaker.IsNull() && breaker->deadlinePassed());

    if (breakerTripped)
      return -1; // timed out, breaker was tripped (analysis was running)

    // Read the results by status rather than through HasFaulty(): HasFaulty() is "did any
    // enabled mode record something", true for BOPAlgo_BadType/OperationAborted/CheckUnknown
    // just as much as for a genuine BOPAlgo_SelfIntersect, so it is not an answer to "does
    // this shape self-intersect" (#1436, the same mistake fixed in this function's sibling
    // above, #1054). An empty compound, for example, records BOPAlgo_BadType and returns
    // early with no self-intersection test ever run; HasFaulty() was true regardless.
    bool selfIntersects = false;
    bool otherFault     = false;
    for (NCollection_List<BOPAlgo_CheckResult>::Iterator it(aa.GetCheckResult()); it.More();
         it.Next())
    {
      if (it.Value().GetCheckStatus() == BOPAlgo_SelfIntersect)
        selfIntersects = true;
      else
        otherFault = true;
    }

    // otherFault wins over selfIntersects, deliberately (same rule as the sibling function):
    // a fault outside BOPAlgo_SelfIntersect means the analysis did not finish answering the
    // question asked, so neither "intersects" nor "clean" is defensible. Report it as an
    // error rather than folding it into either conclusive result.
    if (otherFault)
      return -3; // analysed something, but not the question asked

    // Check for a genuine fault next - a completed analysis that found a real
    // self-intersection is conclusive regardless of whether the deadline passed during
    // execution, as long as the breaker (checked above) was not the reason it stopped.
    if (selfIntersects)
      return 1; // self-intersects (conclusive)

    // Timeout set, deadline passed, but breaker not tripped AND no fault found:
    // analysis made no progress (completed but took longer than timeout without breaker being
    // polled)
    if (timeoutSeconds > 0.0 && deadlinePassed && !breakerTripped)
      return -2; // timed out, breaker NOT tripped (analysis made no progress)

    // No timeout, or completed before timeout with no faults.
    return 0;
  }
  catch (...)
  {
    auto endTime = std::chrono::steady_clock::now();
    if (outTimeSpent)
    {
      *outTimeSpent = std::chrono::duration<double>(endTime - startTime).count();
    }
    return -3; // exception occurred
  }
}

OCCTShapeRef OCCTShapeSliceAtZ(OCCTShapeRef shape, double z)
{
  if (!shape)
    return nullptr;

  try
  {
    // Create a horizontal plane at height z
    gp_Pln plane(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1));

    // Compute section (intersection of shape with plane)
    BRepAlgoAPI_Section section(shape->shape, plane);
    section.Build();

    if (!section.IsDone())
      return nullptr;

    TopoDS_Shape result = section.Shape();
    if (result.IsNull())
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

bool occtDefeaturePerform(BRepAlgoAPI_Defeaturing&    defeaturing,
                          const TopoDS_Shape&         shape,
                          const TopTools_ListOfShape& facesToRemove,
                          TopoDS_Shape&               outResult)
{
  if (facesToRemove.Extent() == 0)
    return false;

  try
  {
    defeaturing.SetShape(shape);
    defeaturing.AddFacesToRemove(facesToRemove);
    defeaturing.Build();
    if (!defeaturing.IsDone())
      return false;

    outResult = defeaturing.Shape();
    return !outResult.IsNull();
  }
  catch (...)
  {
    return false;
  }
}
