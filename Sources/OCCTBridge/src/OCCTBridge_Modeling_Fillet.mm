//
//  OCCTBridge_Modeling_Fillet.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Modeling.mm (#396/#819): BRepFilletAPI, FilletSurf, BiTgte, FilletBuilder.
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

OCCTShapeRef OCCTShapeChamferTwoDistances(OCCTShapeRef   shape,
                                          const int32_t* edgeIndices,
                                          const int32_t* faceIndices,
                                          const double*  dist1,
                                          const double*  dist2,
                                          int32_t        count)
{
  if (!shape || !edgeIndices || !faceIndices || !dist1 || !dist2 || count <= 0)
    return nullptr;
  try
  {
    BRepFilletAPI_MakeChamfer  chamfer(shape->shape);
    TopTools_IndexedMapOfShape edgeMap, faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

    for (int32_t i = 0; i < count; i++)
    {
      int32_t ei = edgeIndices[i] + 1; // 0-based to 1-based
      int32_t fi = faceIndices[i] + 1;
      if (ei < 1 || ei > edgeMap.Extent())
        return nullptr;
      if (fi < 1 || fi > faceMap.Extent())
        return nullptr;
      chamfer.Add(dist1[i], dist2[i], TopoDS::Edge(edgeMap(ei)), TopoDS::Face(faceMap(fi)));
    }
    chamfer.Build();
    if (!chamfer.IsDone())
      return nullptr;
    return new OCCTShape(chamfer.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeChamferDistAngle(OCCTShapeRef   shape,
                                       const int32_t* edgeIndices,
                                       const int32_t* faceIndices,
                                       const double*  distances,
                                       const double*  anglesDeg,
                                       int32_t        count)
{
  if (!shape || !edgeIndices || !faceIndices || !distances || !anglesDeg || count <= 0)
    return nullptr;
  try
  {
    BRepFilletAPI_MakeChamfer  chamfer(shape->shape);
    TopTools_IndexedMapOfShape edgeMap, faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

    for (int32_t i = 0; i < count; i++)
    {
      int32_t ei = edgeIndices[i] + 1;
      int32_t fi = faceIndices[i] + 1;
      if (ei < 1 || ei > edgeMap.Extent())
        return nullptr;
      if (fi < 1 || fi > faceMap.Extent())
        return nullptr;
      double angleRad = anglesDeg[i] * M_PI / 180.0;
      chamfer.AddDA(distances[i], angleRad, TopoDS::Edge(edgeMap(ei)), TopoDS::Face(faceMap(fi)));
    }
    chamfer.Build();
    if (!chamfer.IsDone())
      return nullptr;
    return new OCCTShape(chamfer.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

// The multi-edge member of the radius-law pair. It shares occtFilletAddEdges with the other four
// entry points and occtFilletSetRadiusProfile with OCCTShapeFilletVariable (OCCTBridge_Healing.mm).
//
// Two contract changes, #520. `edgeIndices` is 0-based, as it is for every sibling; it was the one
// 1-based edge index in the family. And a per-edge point count below 1 is now rejected: it used to
// take neither branch, leaving a contour with no radius at all, which SIGSEGVs in Build() rather
// than failing IsDone(). Reachable from Swift as EvolvingFilletEdge(edge:radiusPoints: []).
//
// #639: `declinedEdgeIndices`/`outDeclinedCount` report which of `edgeIndices` OCCT declined, same
// contract as OCCTShapeFilletEdges. This is the entry point the census named directly: filleting an
// open shell's whole edge list SKIPs the edges OCCT declines with no way to learn which or how
// many. `filletEvolving(_:)` passes null for both; `filletEvolvingWithReport(_:)` does not.
OCCTShapeRef OCCTShapeFilletEvolving(OCCTShapeRef                 shape,
                                     const int32_t*               edgeIndices,
                                     int32_t                      edgeCount,
                                     const OCCTFilletRadiusPoint* radiusPoints,
                                     const int32_t*               pointCounts,
                                     int32_t*                     declinedEdgeIndices,
                                     int32_t*                     outDeclinedCount)
{
  if (outDeclinedCount)
    *outDeclinedCount = 0;
  if (!shape || !edgeIndices || edgeCount <= 0 || !radiusPoints || !pointCounts)
    return nullptr;
  try
  {
    BRepFilletAPI_MakeFillet fillet(shape->shape);

    // The profile of edge i starts where the profiles of edges 0..i-1 end, so the offset walks
    // forward with the loop inside occtFilletAddEdges rather than being indexable from `entry`.
    int32_t offset = 0;
    bool    ok     = occtFilletAddEdges(
      fillet,
      shape->shape,
      edgeIndices,
      edgeCount,
      [&](BRepFilletAPI_MakeFillet& f, const TopoDS_Edge& edge, int32_t entry) {
        f.Add(edge);
        const OCCTFilletRadiusPoint* points = radiusPoints + offset;
        // Both the contour and the edge's slot within it are resolved from `edge` inside the
        // helper, not from (NbContours(), 1). Two tangent-continuous edges share a contour but
        // not a slot, so both laws are honoured, measured 10139.793468, byte-identical to the
        // blendedEdges request that always could. #612
        bool profileOk =
          occtFilletSetRadiusProfile(f, edge, pointCounts[entry], [points](int32_t j) {
            return gp_Pnt2d(points[j].parameter, points[j].radius);
          });
        offset += pointCounts[entry];
        return profileOk;
      });
    if (!ok)
      return nullptr;

    occtFilletWriteDeclined(fillet,
                            shape->shape,
                            edgeIndices,
                            edgeCount,
                            declinedEdgeIndices,
                            outDeclinedCount);

    fillet.Build();
    if (!fillet.IsDone())
      return nullptr;

    TopoDS_Shape result = fillet.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

// #443 audit: first face only, and the result is that face alone. Left as-is because the
// vertex indices are numbered within it, so filleting every face would need per-face index
// lists, a different signature. Documented on Shape.fillet2D.
OCCTShapeRef OCCTFace2DFillet(OCCTShapeRef   shape,
                              const int32_t* vertexIndices,
                              const double*  radii,
                              int32_t        count)
{
  if (!shape || !vertexIndices || !radii || count <= 0)
    return nullptr;
  try
  {
    // Get face from shape
    TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
    if (!faceExp.More())
      return nullptr;
    TopoDS_Face face = TopoDS::Face(faceExp.Current());

    BRepFilletAPI_MakeFillet2d fillet(face);

    // #568: a vertex index naming no vertex of that first face rejects the whole call. It used
    // to be skipped, so a list mixing real corners with unresolvable ones rounded the corners
    // that resolved and reported success. See OCCTBridge_Internal.h.
    if (!occtUseSubShapesByIndex(face,
                                 TopAbs_VERTEX,
                                 vertexIndices,
                                 count,
                                 [&](const TopoDS_Shape& vertex, int32_t i) {
                                   fillet.AddFillet(TopoDS::Vertex(vertex), radii[i]);
                                 }))
      return nullptr;

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

// #443 audit: first face only, same reasoning as OCCTFace2DFillet above.
OCCTShapeRef OCCTFace2DChamfer(OCCTShapeRef   shape,
                               const int32_t* edge1Indices,
                               const int32_t* edge2Indices,
                               const double*  distances,
                               int32_t        count)
{
  if (!shape || !edge1Indices || !edge2Indices || !distances || count <= 0)
    return nullptr;
  try
  {
    TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
    if (!faceExp.More())
      return nullptr;
    TopoDS_Face face = TopoDS::Face(faceExp.Current());

    BRepFilletAPI_MakeFillet2d chamfer(face);

    // #568: either half of a pair naming no edge of that first face rejects the whole call. It
    // used to drop just that pair, so a list mixing real pairs with unresolvable ones chamfered
    // the corners that resolved and reported success. This is the one site whose entries name
    // two sub-shapes each, so it reads the map directly rather than through
    // occtUseSubShapesByIndex; the map and the lookup are the same ones. See
    // OCCTBridge_Internal.h.
    TopTools_IndexedMapOfShape edgeMap;
    occtMapSubShapes(face, TopAbs_EDGE, edgeMap);

    for (int32_t i = 0; i < count; i++)
    {
      TopoDS_Shape e1 = occtMappedSubShapeAt(edgeMap, edge1Indices[i]);
      TopoDS_Shape e2 = occtMappedSubShapeAt(edgeMap, edge2Indices[i]);
      if (e1.IsNull() || e2.IsNull())
        return nullptr;

      // #705: the exact same edge pair named twice SIGSEGVs, uncatchably, inside the repeat
      // call's own BRepFilletAPI_MakeFillet2d::AddChamfer. Measured order-independent: (0,1)
      // then (1,0) crashes the same way as (0,1) twice. Root cause is an upstream OCCT
      // defect, not this bridge's: AddChamfer(edge1, edge2, ...) calls
      // ChFi2d::FindConnectedEdges to look up the pair's shared vertex and dereferences the
      // two edges it returns without checking the returned status first; that lookup leaves
      // both edges null on every failure path, and the pair's second call fails it, because
      // the shared vertex was already consumed chamfering the pair the first time. The
      // sibling overload (AddChamfer(edge, vertex, distance, angle)) checks the identical
      // status correctly. Filed upstream as OCCT#1431 (repro) / OCCT#1432 (fix). The kernel
      // patch carrying that fix lands in its own PR and is inert until the pinned
      // xcframework is rebuilt, so this guard is what protects callers meanwhile. Reusing ONE edge
      // across two DIFFERENT pairs is ordinary and measured safe, e.g. chamfering adjacent corners
      // of a rectangle with (0,1) then (1,2); only the identical pair repeated crashes, so this
      // checks the pair, not the individual indices. Rejected rather than skipped, matching
      // fillet2D's own contract for a duplicated vertex (#568): this site already rejects the whole
      // batch on one bad index instead of dropping just that entry, and a repeated pair has
      // the same "which distance wins" ambiguity a bad index does, so the whole call fails
      // instead of guessing.
      for (int32_t j = 0; j < i; j++)
      {
        bool sameOrder = edge1Indices[i] == edge1Indices[j] && edge2Indices[i] == edge2Indices[j];
        bool swappedOrder =
          edge1Indices[i] == edge2Indices[j] && edge2Indices[i] == edge1Indices[j];
        if (sameOrder || swappedOrder)
          return nullptr;
      }

      chamfer.AddChamfer(TopoDS::Edge(e1), TopoDS::Edge(e2), distances[i], distances[i]);
    }

    chamfer.Build();
    if (!chamfer.IsDone())
      return nullptr;
    return new OCCTShape(chamfer.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTFilletSurfBuild(OCCTShapeRef _Nonnull shape,
                            const OCCTShapeRef _Nonnull* _Nonnull edges,
                            int32_t edgeCount,
                            double  radius,
                            OCCTFilletSurfInfo* _Nullable* _Nonnull outSurfaces,
                            int32_t* _Nonnull outCount)
{
  *outSurfaces = nullptr;
  *outCount    = 0;
  try
  {
    NCollection_List<TopoDS_Shape> edgeList;
    for (int32_t i = 0; i < edgeCount; i++)
    {
      edgeList.Append(edges[i]->shape);
    }
    FilletSurf_Builder fb(shape->shape, edgeList, radius);
    fb.Perform();
    FilletSurf_StatusDone status = fb.IsDone();
    if (status == FilletSurf_IsNotOk)
      return 1;

    int32_t n = fb.NbSurface();
    *outCount = n;
    if (n > 0)
    {
      *outSurfaces = (OCCTFilletSurfInfo*)calloc(n, sizeof(OCCTFilletSurfInfo));
      for (int32_t i = 0; i < n; i++)
      {
        const Handle(Geom_Surface)& surf = fb.SurfaceFillet(i + 1);
        if (!surf.IsNull())
        {
          (*outSurfaces)[i].surface = new OCCTSurface(surf);
        }
        (*outSurfaces)[i].supportFace1 = new OCCTShape(fb.SupportFace1(i + 1));
        (*outSurfaces)[i].supportFace2 = new OCCTShape(fb.SupportFace2(i + 1));
        (*outSurfaces)[i].tolerance    = fb.TolApp3d(i + 1);
        (*outSurfaces)[i].firstParam   = fb.FirstParameter();
        (*outSurfaces)[i].lastParam    = fb.LastParameter();
        (*outSurfaces)[i].startStatus  = (int32_t)fb.StartSectionStatus();
        (*outSurfaces)[i].endStatus    = (int32_t)fb.EndSectionStatus();
      }
    }
    return (status == FilletSurf_IsOk) ? 0 : 2;
  }
  catch (...)
  {
    return 1;
  }
}

int32_t OCCTFilletSurfError(OCCTShapeRef _Nonnull shape,
                            const OCCTShapeRef _Nonnull* _Nonnull edges,
                            int32_t edgeCount,
                            double  radius)
{
  try
  {
    NCollection_List<TopoDS_Shape> edgeList;
    for (int32_t i = 0; i < edgeCount; i++)
    {
      edgeList.Append(edges[i]->shape);
    }
    FilletSurf_Builder fb(shape->shape, edgeList, radius);
    fb.Perform();
    return (int32_t)fb.StatusError();
  }
  catch (...)
  {
    // FilletSurf_ErrorTypeStatus is EmptyList=0, EdgeNotG1=1, FacesNotG1=2, EdgeNotOnShape=3,
    // NotSharpEdge=4, PbFilletCompute=5 (#1439); an exception here has no verdict of its own, so
    // this reports PbFilletCompute, the closest real category, and deliberately not 4, which
    // FilletSurf_Builder also returns for a genuine (non-exceptional) NotSharpEdge verdict.
    return 5;
  }
}

OCCTShapeRef _Nullable OCCTBiTgteBlend(OCCTShapeRef _Nonnull shape,
                                       const int32_t* _Nonnull edgeIndices,
                                       int32_t edgeCount,
                                       double  radius,
                                       double  tolerance,
                                       bool    nubs)
{
  if (!shape || edgeCount <= 0)
    return nullptr;
  try
  {
    BiTgte_Blend blend(shape->shape, radius, tolerance, nubs);

    // #613: this filled a std::vector from a bare TopExp_Explorer, one entry per OCCURRENCE,
    // and subscripted it with the caller's edgeIndices, which come from edges() / Edge.index and
    // so are positions in the deduplicated enumeration. A 10mm box has 24 edge occurrences over
    // 12 edges, so from index 9 on this blended a different edge than the caller selected, and
    // indices 12..23 were accepted although edge(at:) refuses every one of them. Not named by
    // the issue or its audit; found by sweeping for the same idiom.
    //
    // occtUseSubShapesByIndex also settles the #568 question this site got wrong in the same
    // breath: an index naming no edge used to be SILENTLY SKIPPED, so a blend of 3 edges naming
    // one that does not exist blended 2 and reported an ordinary success. The batch is refused
    // now, as it is for every other index-taking builder.
    //
    // Safe on the map: BiTgte_Blend keys the edge into its own myEdges, an
    // NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> (BiTgte_Blend.hxx:202),
    // whose equality is TopoDS_Shape::IsSame, so orientation cannot select a different entry.
    if (!occtUseSubShapesByIndex(
          shape->shape,
          TopAbs_EDGE,
          edgeIndices,
          edgeCount,
          [&](const TopoDS_Shape& sub, int32_t) { blend.SetEdge(TopoDS::Edge(sub)); }))
    {
      return nullptr;
    }

    blend.Perform(true);
    if (!blend.IsDone())
      return nullptr;

    TopoDS_Shape result = blend.Shape();
    if (result.IsNull())
      return nullptr;
    auto* ref  = new OCCTShape();
    ref->shape = result;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTBiTgteBlendInfo OCCTBiTgteBlendInfo_(OCCTShapeRef _Nonnull shape,
                                         const int32_t* _Nonnull edgeIndices,
                                         int32_t edgeCount,
                                         double  radius,
                                         double  tolerance)
{
  OCCTBiTgteBlendInfo info = {};
  if (!shape || edgeCount <= 0)
    return info;
  try
  {
    BiTgte_Blend blend(shape->shape, radius, tolerance, false);

    // #613: the same explorer-indexed walk as OCCTBiTgteBlend above, written out a second time.
    // Both are converted together, since fixing one alone would have left the two entry points
    // disagreeing about what edgeIndices means for the identical operation.
    if (!occtUseSubShapesByIndex(
          shape->shape,
          TopAbs_EDGE,
          edgeIndices,
          edgeCount,
          [&](const TopoDS_Shape& sub, int32_t) { blend.SetEdge(TopoDS::Edge(sub)); }))
    {
      return info;
    }

    blend.Perform(true);
    info.isDone = blend.IsDone();
    if (info.isDone)
    {
      info.nbSurfaces = blend.NbSurfaces();
    }
  }
  catch (...)
  {
  }
  return info;
}

OCCTFilletBuilderRef OCCTFilletBuilderCreate(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    return new OCCTFilletBuilder(shape->shape);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTFilletBuilderRelease(OCCTFilletBuilderRef builder)
{
  delete builder;
}

bool OCCTFilletBuilderAddEdge(OCCTFilletBuilderRef builder, OCCTEdgeRef edge, double radius)
{
  if (!builder || !edge)
    return false;
  try
  {
    builder->fillet.Add(radius, edge->edge);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFilletBuilderAddEdgeEvolving(OCCTFilletBuilderRef builder,
                                      OCCTEdgeRef          edge,
                                      double               r1,
                                      double               r2)
{
  if (!builder || !edge)
    return false;
  try
  {
    builder->fillet.Add(r1, r2, edge->edge);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTFilletBuilderBuild(OCCTFilletBuilderRef builder)
{
  if (!builder)
    return nullptr;
  try
  {
    builder->fillet.Build();
    if (!builder->fillet.IsDone())
      return nullptr;
    return new OCCTShape(builder->fillet.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTFilletBuilderNbContours(OCCTFilletBuilderRef builder)
{
  if (!builder)
    return 0;
  try
  {
    return builder->fillet.NbContours();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTFilletBuilderNbEdges(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return 0;
  try
  {
    return builder->fillet.NbEdges(contourIndex);
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTFilletBuilderHasResult(OCCTFilletBuilderRef builder)
{
  if (!builder)
    return false;
  try
  {
    return builder->fillet.HasResult();
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTFilletBuilderBadShape(OCCTFilletBuilderRef builder)
{
  if (!builder)
    return nullptr;
  try
  {
    const TopoDS_Shape& bad = builder->fillet.BadShape();
    if (bad.IsNull())
      return nullptr;
    return new OCCTShape(bad);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTFilletBuilderNbFaultyContours(OCCTFilletBuilderRef builder)
{
  if (!builder)
    return 0;
  try
  {
    return builder->fillet.NbFaultyContours();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTFilletBuilderNbFaultyVertices(OCCTFilletBuilderRef builder)
{
  if (!builder)
    return 0;
  try
  {
    return builder->fillet.NbFaultyVertices();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTFilletBuilderGetRadius(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return 0;
  try
  {
    return builder->fillet.Radius(contourIndex);
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTFilletBuilderGetLength(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return 0;
  try
  {
    return builder->fillet.Length(contourIndex);
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTFilletBuilderIsConstant(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return false;
  try
  {
    return builder->fillet.IsConstant(contourIndex);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFilletBuilderRemoveEdge(OCCTFilletBuilderRef builder, OCCTEdgeRef edge)
{
  if (!builder || !edge)
    return false;
  try
  {
    builder->fillet.Remove(edge->edge);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTFilletBuilderReset(OCCTFilletBuilderRef builder)
{
  if (!builder)
    return;
  try
  {
    builder->fillet.Reset();
  }
  catch (...)
  {
  }
}

bool OCCTFilletBuilderSetRadiusOnEdge(OCCTFilletBuilderRef builder,
                                      double               radius,
                                      int32_t              contourIndex,
                                      OCCTEdgeRef          edge)
{
  if (!builder || !edge)
    return false;
  try
  {
    builder->fillet.SetRadius(radius, contourIndex, edge->edge);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFilletBuilderSetRadiusAtVertex(OCCTFilletBuilderRef builder,
                                        double               radius,
                                        int32_t              contourIndex,
                                        OCCTShapeRef         vertex)
{
  if (!builder || !vertex)
    return false;
  try
  {
    builder->fillet.SetRadius(radius, contourIndex, TopoDS::Vertex(vertex->shape));
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFilletBuilderSetTwoRadii(OCCTFilletBuilderRef builder,
                                  double               r1,
                                  double               r2,
                                  int32_t              contourIndex,
                                  int32_t              edgeInContour)
{
  if (!builder)
    return false;
  try
  {
    builder->fillet.SetRadius(r1, r2, contourIndex, edgeInContour);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTFilletBuilderContour(OCCTFilletBuilderRef builder, OCCTEdgeRef edge)
{
  if (!builder || !edge)
    return 0;
  try
  {
    return builder->fillet.Contour(edge->edge);
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTFilletBuilderEdge(OCCTFilletBuilderRef builder,
                                   int32_t              contourIndex,
                                   int32_t              edgeIndex)
{
  if (!builder)
    return nullptr;
  try
  {
    const TopoDS_Edge& e = builder->fillet.Edge(contourIndex, edgeIndex);
    if (e.IsNull())
      return nullptr;
    return new OCCTShape(e);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTFilletBuilderFirstVertex(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return nullptr;
  try
  {
    TopoDS_Vertex v = builder->fillet.FirstVertex(contourIndex);
    if (v.IsNull())
      return nullptr;
    return new OCCTShape(v);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTFilletBuilderLastVertex(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return nullptr;
  try
  {
    TopoDS_Vertex v = builder->fillet.LastVertex(contourIndex);
    if (v.IsNull())
      return nullptr;
    return new OCCTShape(v);
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTFilletBuilderAbscissa(OCCTFilletBuilderRef builder,
                                 int32_t              contourIndex,
                                 OCCTShapeRef         vertex)
{
  if (!builder || !vertex)
    return -1.0;
  try
  {
    return builder->fillet.Abscissa(contourIndex, TopoDS::Vertex(vertex->shape));
  }
  catch (...)
  {
    return -1.0;
  }
}

double OCCTFilletBuilderRelativeAbscissa(OCCTFilletBuilderRef builder,
                                         int32_t              contourIndex,
                                         OCCTShapeRef         vertex)
{
  if (!builder || !vertex)
    return -1.0;
  try
  {
    return builder->fillet.RelativeAbscissa(contourIndex, TopoDS::Vertex(vertex->shape));
  }
  catch (...)
  {
    return -1.0;
  }
}

bool OCCTFilletBuilderClosedAndTangent(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return false;
  try
  {
    return builder->fillet.ClosedAndTangent(contourIndex);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFilletBuilderClosed(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return false;
  try
  {
    return builder->fillet.Closed(contourIndex);
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTFilletBuilderNbSurfaces(OCCTFilletBuilderRef builder)
{
  if (!builder)
    return 0;
  try
  {
    return builder->fillet.NbSurfaces();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTFilletBuilderNbComputedSurfaces(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return 0;
  try
  {
    return builder->fillet.NbComputedSurfaces(contourIndex);
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTFilletBuilderStripeStatus(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return -1;
  try
  {
    return static_cast<int32_t>(builder->fillet.StripeStatus(contourIndex));
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTFilletBuilderFaultyContour(OCCTFilletBuilderRef builder, int32_t faultIndex)
{
  if (!builder)
    return 0;
  try
  {
    return builder->fillet.FaultyContour(faultIndex);
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTFilletBuilderFaultyVertex(OCCTFilletBuilderRef builder, int32_t faultIndex)
{
  if (!builder)
    return nullptr;
  try
  {
    TopoDS_Vertex v = builder->fillet.FaultyVertex(faultIndex);
    if (v.IsNull())
      return nullptr;
    return new OCCTShape(v);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - FilletBuilder/ChamferBuilder extensions (hoisted with structs)
void OCCTFilletBuilderSetParams(OCCTFilletBuilderRef builder,
                                double               tang,
                                double               tesp,
                                double               t2d,
                                double               tApp3d,
                                double               tApp2d,
                                double               fleche)
{
  if (!builder)
    return;
  try
  {
    builder->fillet.SetParams(tang, tesp, t2d, tApp3d, tApp2d, fleche);
  }
  catch (...)
  {
  }
}

// #490: this was the one request-side site that decoded nothing at all, a raw cast, which made the
// argument a GeomAbs_Shape ordinal (1 = G1, 2 = C1) while the Swift entry point documented the
// parametric ladder (0=C0, 1=C1, 2=C2), so every value from 1 up asked for one class less than the
// caller read. BRepFilletAPI_MakeFillet.hxx agrees the domain is "an continuity Ci (i=0,1 or 2)".
// Flagged in #513's census; fixed here because it is the same defect this issue is about.
void OCCTFilletBuilderSetContinuity(OCCTFilletBuilderRef builder,
                                    int32_t              internalContinuity,
                                    double               angularTolerance)
{
  if (!builder)
    return;
  try
  {
    builder->fillet.SetContinuity(occtGeomAbsFromParametricContinuity(internalContinuity),
                                  angularTolerance);
  }
  catch (...)
  {
  }
}

void OCCTFilletBuilderSetFilletShape(OCCTFilletBuilderRef builder, int32_t filletShape)
{
  if (!builder)
    return;
  try
  {
    builder->fillet.SetFilletShape((ChFi3d_FilletShape)filletShape);
  }
  catch (...)
  {
  }
}

int32_t OCCTFilletBuilderGetFilletShape(OCCTFilletBuilderRef builder)
{
  if (!builder)
    return 0;
  try
  {
    return (int32_t)builder->fillet.GetFilletShape();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTFilletBuilderResetContour(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return;
  try
  {
    builder->fillet.ResetContour(contourIndex);
  }
  catch (...)
  {
  }
}

void OCCTFilletBuilderSimulate(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return;
  try
  {
    builder->fillet.Simulate(contourIndex);
  }
  catch (...)
  {
  }
}

int32_t OCCTFilletBuilderNbSimulatedSurf(OCCTFilletBuilderRef builder, int32_t contourIndex)
{
  if (!builder)
    return 0;
  try
  {
    return (int32_t)builder->fillet.NbSurf(contourIndex);
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTFilletBuilderGetBounds(OCCTFilletBuilderRef builder,
                                int32_t              contourIndex,
                                OCCTEdgeRef          edge,
                                double*              outFirst,
                                double*              outLast)
{
  if (!builder || !edge || !outFirst || !outLast)
    return false;
  try
  {
    if (!occtFilletContourHoldsEdge(builder->fillet, contourIndex, edge->edge))
      return false;
    return builder->fillet.GetBounds(contourIndex, edge->edge, *outFirst, *outLast);
  }
  catch (...)
  {
    return false;
  }
}

OCCTLawFunctionRef OCCTFilletBuilderGetLaw(OCCTFilletBuilderRef builder,
                                           int32_t              contourIndex,
                                           OCCTEdgeRef          edge)
{
  if (!builder || !edge)
    return nullptr;
  try
  {
    if (!occtFilletContourHoldsEdge(builder->fillet, contourIndex, edge->edge))
      return nullptr;
    Handle(Law_Function) law = builder->fillet.GetLaw(contourIndex, edge->edge);
    if (law.IsNull())
      return nullptr;
    return new OCCTLawFunction(law);
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTFilletBuilderSetLaw(OCCTFilletBuilderRef builder,
                             int32_t              contourIndex,
                             OCCTEdgeRef          edge,
                             OCCTLawFunctionRef   law)
{
  if (!builder || !edge || !law)
    return false;
  try
  {
    if (!occtFilletContourHoldsEdge(builder->fillet, contourIndex, edge->edge))
      return false;
    builder->fillet.SetLaw(contourIndex, edge->edge, law->law);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTFilletBuilderGenerated(OCCTFilletBuilderRef builder,
                                   OCCTShapeRef         shape,
                                   OCCTShapeRef**       outShapes)
{
  return occtFilletBuilderHistoryQuery(builder,
                                       shape,
                                       outShapes,
                                       &BRepFilletAPI_MakeFillet::Generated);
}

int32_t OCCTFilletBuilderModified(OCCTFilletBuilderRef builder,
                                  OCCTShapeRef         shape,
                                  OCCTShapeRef**       outShapes)
{
  return occtFilletBuilderHistoryQuery(builder,
                                       shape,
                                       outShapes,
                                       &BRepFilletAPI_MakeFillet::Modified);
}

bool OCCTFilletBuilderIsDeleted(OCCTFilletBuilderRef builder, OCCTShapeRef shape)
{
  if (!builder || !shape)
    return false;
  try
  {
    return builder->fillet.IsDeleted(shape->shape);
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTShapeFillet(OCCTShapeRef shape, double radius)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepFilletAPI_MakeFillet fillet(shape->shape);

    // Add fillet to all edges
    TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
    while (explorer.More())
    {
      fillet.Add(radius, TopoDS::Edge(explorer.Current()));
      explorer.Next();
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

OCCTShapeRef OCCTShapeChamfer(OCCTShapeRef shape, double distance)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepFilletAPI_MakeChamfer chamfer(shape->shape);

    // Add chamfer to all edges
    TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
    while (explorer.More())
    {
      chamfer.Add(distance, TopoDS::Edge(explorer.Current()));
      explorer.Next();
    }

    chamfer.Build();
    if (!chamfer.IsDone())
      return nullptr;
    return new OCCTShape(chamfer.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}
