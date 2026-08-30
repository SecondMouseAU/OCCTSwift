//
//  OCCTBridge_Modeling_HealingSewing.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Modeling.mm (#396/#819): ShapeFix, ShapeAnalysis, ShapeBuild,
//  ShapeUpgrade, BRepCheck, Sewing. Public C surface unchanged; imports the same
//  OCCTBridge_Modeling.h every sibling file does. No symbol changes, pure file move -- see
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

OCCTShapeRef OCCTShapeSimpleOffset(OCCTShapeRef shape, double offsetValue)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepOffset_MakeSimpleOffset builder(shape->shape, offsetValue);
    builder.SetBuildSolidFlag(true);
    builder.Perform();
    if (!builder.IsDone())
      return nullptr;
    return new OCCTShape(builder.GetResultShape());
  }
  catch (...)
  {
    return nullptr;
  }
}

// Build a face from a surface bounded by a 3D wire that (approximately) lies on the surface.
// The wire's edges may lack pcurves, so ShapeFix_Face projects them onto the surface. Returns
// NULL on failure (OCCTSwift #233).
OCCTShapeRef OCCTShapeCreateFaceFromSurfaceWire(OCCTSurfaceRef surface, OCCTWireRef wire)
{
  if (!surface || surface->surface.IsNull() || !wire || wire->wire.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Surface)    surf = surface->surface;
    BRepBuilderAPI_MakeFace faceMaker(surf, wire->wire, Standard_True);
    if (!faceMaker.IsDone())
      return nullptr;
    TopoDS_Face face = faceMaker.Face();
    // The 3D wire's edges likely have no pcurves on this surface, project to add them.
    // #317: ShapeFix_Face::FixPeriodicDegenerated() (hit when the wire is a full periodic
    // loop on a conical surface) unconditionally dereferences Context() at its last line
    // with no IsNull() guard (every other Context()->Replace call site in that OCCT source
    // file guards it). SIGSEGVs unless a context is set first. Give it one.
    ShapeFix_Face fixer(face);
    fixer.SetContext(new ShapeBuild_ReShape);
    fixer.Perform();
    TopoDS_Face fixed = fixer.Face();
    BRepLib::BuildCurves3d(fixed);
    BRepCheck_Analyzer chk(fixed);
    if (!chk.IsValid())
      return nullptr;
    return new OCCTShape(fixed);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCreateFaceFromSurfaceWireWithHoles(OCCTSurfaceRef     surface,
                                                         OCCTWireRef        outer,
                                                         const OCCTWireRef* innerWires,
                                                         int32_t            innerCount)
{
  if (!surface || surface->surface.IsNull() || !outer || outer->wire.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Surface) surf = surface->surface;

    // A hole subtracts area only when its winding is opposite the outer boundary. The caller's
    // wire winding is unknown, so try the holes reversed (the usual convention) and, if that
    // doesn't yield a valid face, fall back to the wires as given. Returns the first valid build.
    for (int attempt = 0; attempt < 2; attempt++)
    {
      const bool              reverseHoles = (attempt == 0);
      BRepBuilderAPI_MakeFace faceMaker(surf, outer->wire, Standard_True);
      if (!faceMaker.IsDone())
        return nullptr; // outer alone failed, no point retrying
      bool ok = true;
      for (int32_t i = 0; i < innerCount; i++)
      {
        OCCTWireRef w = innerWires ? innerWires[i] : nullptr;
        if (!w || w->wire.IsNull())
          continue;
        TopoDS_Wire hole = reverseHoles ? TopoDS::Wire(w->wire.Reversed()) : w->wire;
        faceMaker.Add(hole);
        if (!faceMaker.IsDone())
        {
          ok = false;
          break;
        }
      }
      if (!ok)
        continue;
      TopoDS_Face face = faceMaker.Face();
      // The 3D wires likely have no pcurves on this surface, project them.
      // #317: see OCCTShapeCreateFaceFromSurfaceWire. ShapeFix_Face needs a context or
      // FixPeriodicDegenerated() SIGSEGVs on a periodic conical single-wire boundary.
      ShapeFix_Face fixer(face);
      fixer.SetContext(new ShapeBuild_ReShape);
      fixer.Perform();
      TopoDS_Face fixed = fixer.Face();
      BRepLib::BuildCurves3d(fixed);
      if (BRepCheck_Analyzer(fixed).IsValid())
        return new OCCTShape(fixed);
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeOffsetPerFace(OCCTShapeRef   shape,
                                    double         defaultOffset,
                                    const int32_t* faceIndices,
                                    const double*  faceOffsets,
                                    int32_t        faceCount,
                                    double         tolerance,
                                    int32_t        joinType)
{
  if (!shape)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

    GeomAbs_JoinType jt = GeomAbs_Arc;
    if (joinType == 1)
      jt = GeomAbs_Tangent;
    else if (joinType == 2)
      jt = GeomAbs_Intersection;

    BRepOffset_MakeOffset offset;
    offset.Initialize(shape->shape, defaultOffset, tolerance, BRepOffset_Skin, false, false, jt);

    // #541: 0-based, matching Face.index and every sibling here. It was 1-based, so a
    // Face.index offset the face before the one it named and index 0 was silently dropped.
    // Out of range is a caller error rather than something to skip: skipping returned a
    // shape offset by the default everywhere, indistinguishable from a successful run
    // (the same failure #497 fixed for defeaturing).
    for (int32_t i = 0; i < faceCount; i++)
    {
      int32_t idx = faceIndices[i] + 1;
      if (idx < 1 || idx > faceMap.Extent())
        return nullptr;
      const TopoDS_Face& face = TopoDS::Face(faceMap(idx));
      offset.SetOffsetOnFace(face, faceOffsets[i]);
    }

    offset.MakeOffsetShape();
    if (!offset.IsDone())
      return nullptr;
    TopoDS_Shape result = offset.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeSew(const OCCTShapeRef* shapes, int32_t count, double tolerance)
{
  if (!shapes || count < 1)
    return nullptr;

  try
  {
    BRepBuilderAPI_Sewing sewing(tolerance);

    for (int32_t i = 0; i < count; i++)
    {
      if (shapes[i])
      {
        sewing.Add(shapes[i]->shape);
      }
    }

    sewing.Perform();
    TopoDS_Shape sewn = sewing.SewedShape();

    if (sewn.IsNull())
      return nullptr;

    // Try to make a solid if we got a closed shell
    if (sewn.ShapeType() == TopAbs_SHELL)
    {
      TopoDS_Shell shell = TopoDS::Shell(sewn);
      if (shell.Closed())
      {
        BRepBuilderAPI_MakeSolid makeSolid(shell);
        if (makeSolid.IsDone())
        {
          return new OCCTShape(makeSolid.Solid());
        }
      }
    }

    return new OCCTShape(sewn);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeSewTwo(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance)
{
  if (!shape1 || !shape2)
    return nullptr;

  OCCTShapeRef shapes[2] = {shape1, shape2};
  return OCCTShapeSew(shapes, 2, tolerance);
}

OCCTShapeRef _Nullable OCCTBRepOffsetSimpleOffset(OCCTShapeRef shape,
                                                  double       offset,
                                                  double       tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    Handle(BRepOffset_SimpleOffset) mod =
      new BRepOffset_SimpleOffset(shape->shape, offset, tolerance);
    BRepTools_Modifier modifier(shape->shape, mod);
    if (!modifier.IsDone())
      return nullptr;
    TopoDS_Shape result = modifier.ModifiedShape(shape->shape);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepOffsetOffsetFace(OCCTShapeRef faceShape, double offset)
{
  if (!faceShape)
    return nullptr;
  try
  {
    TopoDS_Face       face = TopoDS::Face(faceShape->shape);
    BRepOffset_Offset off(face, offset, false, GeomAbs_Arc);
    TopoDS_Face       result = off.Face();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeFaceAddHole(OCCTShapeRef face, OCCTShapeRef wire)
{
  if (!face || !wire)
    return nullptr;
  try
  {
    TopoDS_Wire w = TopoDS::Wire(wire->shape);

    // #234: reject a DEGENERATE hole wire (one enclosing no area). Adding such a wire yields a
    // non-nil-but-invalid face; extruding it gives an invalid prism that SIGSEGVs OCCT's
    // ShapeFix (`healed()`) downstream, an OS signal the bridge's catch(...) cannot recover.
    // Failing here (return nil) breaks the chain.
    //
    // #397: the wire is sampled ALONG ITS CURVES, not at its vertices. A circular hole wire has
    // one vertex (`Wire.circle`) or two (two joined arcs), so a vertex-count test rejected every
    // curved hole ever passed in; only the sampled points describe what the wire encloses.
    std::vector<gp_Pnt> pts     = occtSampleWirePoints(w, 8);
    const bool          ordered = !pts.empty();
    if (!ordered)
    {
      // Nothing samplable (no 3D curves): fall back to the wire's vertices, unordered.
      TopTools_IndexedMapOfShape vmap;
      TopExp::MapShapes(w, TopAbs_VERTEX, vmap);
      for (int i = 1; i <= vmap.Extent(); i++)
        pts.push_back(BRep_Tool::Pnt(TopoDS::Vertex(vmap(i))));
    }
    std::vector<gp_Pnt> distinct;
    for (const gp_Pnt& p : pts)
    {
      bool dup = false;
      for (const gp_Pnt& q : distinct)
      {
        if (q.Distance(p) < Precision::Confusion())
        {
          dup = true;
          break;
        }
      }
      if (!dup)
        distinct.push_back(p);
    }
    if (distinct.size() < 3)
      return nullptr; // sub-3-distinct-point → degenerate
    // Collinearity (zero area): farthest pair defines a line; if every point lies on it, reject.
    gp_Pnt a = distinct[0], b = distinct[0];
    double maxd = 0;
    for (const gp_Pnt& p : distinct)
    {
      double d = a.Distance(p);
      if (d > maxd)
      {
        maxd = d;
        b    = p;
      }
    }
    if (maxd < Precision::Confusion())
      return nullptr; // all coincident
    gp_Vec dir(a, b);
    dir.Normalize();
    double maxPerp = 0;
    for (const gp_Pnt& p : distinct)
    {
      double perp = gp_Vec(a, p).Crossed(dir).Magnitude(); // perpendicular distance to the line
      if (perp > maxPerp)
        maxPerp = perp;
    }
    if (maxPerp < Precision::Confusion())
      return nullptr; // collinear → zero-area → degenerate
    if (ordered)
    {
      // A curved wire can spread out and still enclose nothing (an arc traversed out and back
      // clears the collinearity test above), so measure the loop's own vector area too.
      gp_Vec twiceArea(0, 0, 0);
      for (size_t i = 1; i + 1 < pts.size(); i++)
      {
        twiceArea += gp_Vec(pts[0], pts[i]).Crossed(gp_Vec(pts[0], pts[i + 1]));
      }
      // area/chord is the loop's mean width: below tolerance it encloses nothing measurable.
      if (0.5 * twiceArea.Magnitude() < Precision::Confusion() * maxd)
        return nullptr;
    }

    const TopoDS_Face host = TopoDS::Face(face->shape);
    // A hole subtracts area only when it winds OPPOSITE the face's outer boundary. `MakeFace::Add`
    // does no reorienting, so a same-sense wire was added as a second outer loop: the face's area
    // GREW by the hole's, and the prism built from it was not a valid solid. Decide by comparing
    // windings in the face's plane, the same rule OCCTShapeCreateFaceWithHoles uses (#274).
    bool   reverse = false;
    gp_Pln plane;
    if (occtFacePlane(host, plane))
    {
      const double outerSign = occtSignedWireAreaInPlane(BRepTools::OuterWire(host), plane);
      const double holeSign  = occtSignedWireAreaInPlane(w, plane);
      reverse                = (outerSign != 0.0) && (holeSign * outerSign > 0.0);
    }
    auto build = [&](bool rev) -> TopoDS_Face {
      BRepBuilderAPI_MakeFace mf(host);
      mf.Add(rev ? TopoDS::Wire(w.Reversed()) : w);
      return mf.IsDone() ? mf.Face() : TopoDS_Face();
    };
    TopoDS_Face holed = build(reverse);
    if (holed.IsNull() || !BRepCheck_Analyzer(holed).IsValid())
    {
      // Non-planar host, or a winding test that couldn't decide: take the other orientation
      // when it is the one that yields a valid face. If NEITHER does, the wire is not a usable
      // hole for this face at all (it crosses the boundary, say) and no winding will make it
      // one, decline it, rather than hand back a face that is invalid for a reason this
      // function cannot fix. That is the same call the degenerate guard above makes, and what
      // #234 established: a non-nil invalid face is exactly what breaks the caller later.
      TopoDS_Face alt = build(!reverse);
      if (alt.IsNull() || !BRepCheck_Analyzer(alt).IsValid())
        return nullptr;
      holed = alt;
    }
    auto result   = new OCCTShape();
    result->shape = holed;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSewingRef OCCTSewingCreate(double tolerance)
{
  try
  {
    return new OCCTSewing(tolerance);
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTSewingRelease(OCCTSewingRef sewing)
{
  delete sewing;
}

void OCCTSewingAdd(OCCTSewingRef sewing, OCCTShapeRef shape)
{
  if (!sewing || !shape)
    return;
  try
  {
    sewing->sewing.Add(shape->shape);
  }
  catch (...)
  {
  }
}

void OCCTSewingPerform(OCCTSewingRef sewing)
{
  if (!sewing)
    return;
  try
  {
    sewing->sewing.Perform();
  }
  catch (...)
  {
  }
}

OCCTShapeRef OCCTSewingResult(OCCTSewingRef sewing)
{
  if (!sewing)
    return nullptr;
  try
  {
    TopoDS_Shape result = sewing->sewing.SewedShape();
    if (result.IsNull())
      return nullptr;
    auto r   = new OCCTShape();
    r->shape = result;
    return r;
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTSewingNbFreeEdges(OCCTSewingRef sewing)
{
  if (!sewing)
    return 0;
  try
  {
    return sewing->sewing.NbFreeEdges();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSewingNbContigousEdges(OCCTSewingRef sewing)
{
  if (!sewing)
    return 0;
  try
  {
    return sewing->sewing.NbContigousEdges();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTSewingNbDegeneratedShapes(OCCTSewingRef sewing)
{
  if (!sewing)
    return 0;
  try
  {
    return sewing->sewing.NbDegeneratedShapes();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTMakeEdgeError(OCCTShapeRef edge)
{
  // This returns a generic check - we use BRepCheck_Analyzer as a proxy
  // 0 = valid, nonzero = error
  if (!edge)
    return -1;
  try
  {
    BRepCheck_Analyzer analyzer(edge->shape);
    return analyzer.IsValid() ? 0 : 1;
  }
  catch (...)
  {
    return -1;
  }
}

OCCTUnifySameDomainRef OCCTUnifySameDomainCreate(OCCTShapeRef shape,
                                                 bool         unifyEdges,
                                                 bool         unifyFaces,
                                                 bool         concatBSplines)
{
  if (!shape)
    return nullptr;
  try
  {
    // unique_ptr, not a raw new: the wrapper now owns a whole shape copy, so leaking it when
    // the algorithm's constructor throws is no longer one stray pointer.
    std::unique_ptr<OCCTUnifySameDomain> result(new OCCTUnifySameDomain());
    TopoDS_Shape work = occtUnifySameDomainInput(shape->shape, result->copier);
    if (work.IsNull())
      return nullptr;
    result->usd = new ShapeUpgrade_UnifySameDomain(work, unifyEdges, unifyFaces, concatBSplines);
    return (OCCTUnifySameDomainRef)result.release();
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTUnifySameDomainRelease(OCCTUnifySameDomainRef ref)
{
  auto usd = (OCCTUnifySameDomain*)ref;
  if (usd)
  {
    delete usd->usd;
    delete usd;
  }
}

void OCCTUnifySameDomainAllowInternalEdges(OCCTUnifySameDomainRef ref, bool allow)
{
  auto usd = (OCCTUnifySameDomain*)ref;
  if (!usd)
    return;
  try
  {
    usd->usd->AllowInternalEdges(allow);
  }
  catch (...)
  {
  }
}

void OCCTUnifySameDomainKeepShape(OCCTUnifySameDomainRef ref, OCCTShapeRef shape)
{
  auto usd = (OCCTUnifySameDomain*)ref;
  if (!usd || !shape)
    return;
  // #446: the algorithm holds a copy, so the caller's sub-shape has to be mapped onto its
  // counterpart there, handing over the caller's own would keep nothing at all.
  try
  {
    usd->usd->KeepShape(occtUnifySameDomainMapped(shape->shape, usd->copier));
  }
  catch (...)
  {
  }
}

void OCCTUnifySameDomainSetSafeInputMode(OCCTUnifySameDomainRef ref, bool safe)
{
  auto usd = (OCCTUnifySameDomain*)ref;
  if (!usd)
    return;
  try
  {
    usd->usd->SetSafeInputMode(safe);
  }
  catch (...)
  {
  }
}

void OCCTUnifySameDomainSetLinearTolerance(OCCTUnifySameDomainRef ref, double tol)
{
  auto usd = (OCCTUnifySameDomain*)ref;
  if (!usd)
    return;
  try
  {
    usd->usd->SetLinearTolerance(tol);
  }
  catch (...)
  {
  }
}

void OCCTUnifySameDomainSetAngularTolerance(OCCTUnifySameDomainRef ref, double tol)
{
  auto usd = (OCCTUnifySameDomain*)ref;
  if (!usd)
    return;
  try
  {
    usd->usd->SetAngularTolerance(tol);
  }
  catch (...)
  {
  }
}

void OCCTUnifySameDomainBuild(OCCTUnifySameDomainRef ref)
{
  auto usd = (OCCTUnifySameDomain*)ref;
  if (!usd)
    return;
  try
  {
    usd->usd->Build();
  }
  catch (...)
  {
  }
}

OCCTShapeRef OCCTUnifySameDomainShape(OCCTUnifySameDomainRef ref)
{
  auto usd = (OCCTUnifySameDomain*)ref;
  if (!usd)
    return nullptr;
  try
  {
    TopoDS_Shape result = usd->usd->Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape{result};
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTSewingNbMultipleEdges(OCCTSewingRef sewing)
{
  try
  {
    return (int32_t)sewing->sewing.NbMultipleEdges();
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTSewingIsMultipleEdge(OCCTSewingRef sewing, int32_t index, OCCTShapeRef* outEdge)
{
  try
  {
    if (index < 1 || index > sewing->sewing.NbMultipleEdges())
    {
      *outEdge = nullptr;
      return false;
    }
    const TopoDS_Edge& edge = sewing->sewing.MultipleEdge(index);
    auto*              r    = new OCCTShape();
    r->shape                = edge;
    *outEdge                = r;
    return true;
  }
  catch (...)
  {
    *outEdge = nullptr;
    return false;
  }
}

int32_t OCCTSewingNbDeletedFaces(OCCTSewingRef sewing)
{
  if (!sewing)
    return 0;
  try
  {
    return (int32_t)sewing->sewing.NbDeletedFaces();
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTSewingDeletedFace(OCCTSewingRef sewing, int32_t index)
{
  if (!sewing)
    return nullptr;
  try
  {
    const TopoDS_Face& f = sewing->sewing.DeletedFace(index);
    if (f.IsNull())
      return nullptr;
    auto* ref  = new OCCTShape;
    ref->shape = f;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTSewingIsModified(OCCTSewingRef sewing, OCCTShapeRef shape)
{
  if (!sewing || !shape)
    return false;
  try
  {
    return sewing->sewing.IsModified(shape->shape);
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTSewingModified(OCCTSewingRef sewing, OCCTShapeRef shape)
{
  if (!sewing || !shape)
    return nullptr;
  try
  {
    const TopoDS_Shape& mod = sewing->sewing.Modified(shape->shape);
    if (mod.IsNull())
      return nullptr;
    auto* ref  = new OCCTShape;
    ref->shape = mod;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTSewingIsDegenerated(OCCTSewingRef sewing, OCCTShapeRef shape)
{
  if (!sewing || !shape)
    return false;
  try
  {
    return sewing->sewing.IsDegenerated(shape->shape);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTSewingIsSectionBound(OCCTSewingRef sewing, OCCTShapeRef edge)
{
  if (!sewing || !edge)
    return false;
  try
  {
    return sewing->sewing.IsSectionBound(TopoDS::Edge(edge->shape));
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTSewingWhichFace(OCCTSewingRef sewing, OCCTShapeRef edge)
{
  if (!sewing || !edge)
    return nullptr;
  try
  {
    TopoDS_Face f = sewing->sewing.WhichFace(TopoDS::Edge(edge->shape));
    if (f.IsNull())
      return nullptr;
    auto* ref  = new OCCTShape;
    ref->shape = f;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTSewingLoad(OCCTSewingRef sewing, OCCTShapeRef shape)
{
  if (!sewing || !shape)
    return;
  try
  {
    sewing->sewing.Load(shape->shape);
  }
  catch (...)
  {
  }
}

void OCCTSewingSetNonManifoldMode(OCCTSewingRef sewing, bool nonManifold)
{
  if (!sewing)
    return;
  try
  {
    sewing->sewing.SetNonManifoldMode(nonManifold);
  }
  catch (...)
  {
  }
}

void OCCTSewingSetFaceMode(OCCTSewingRef sewing, bool faceMode)
{
  if (!sewing)
    return;
  try
  {
    sewing->sewing.SetFaceMode(faceMode);
  }
  catch (...)
  {
  }
}

void OCCTSewingSetFloatingEdgesMode(OCCTSewingRef sewing, bool floatingEdges)
{
  if (!sewing)
    return;
  try
  {
    sewing->sewing.SetFloatingEdgesMode(floatingEdges);
  }
  catch (...)
  {
  }
}

void OCCTSewingSetMinTolerance(OCCTSewingRef sewing, double minTol)
{
  if (!sewing)
    return;
  try
  {
    sewing->sewing.SetMinTolerance(minTol);
  }
  catch (...)
  {
  }
}

void OCCTSewingSetMaxTolerance(OCCTSewingRef sewing, double maxTol)
{
  if (!sewing)
    return;
  try
  {
    sewing->sewing.SetMaxTolerance(maxTol);
  }
  catch (...)
  {
  }
}

OCCTWireRef* OCCTShapeSectionWiresAtZ(OCCTShapeRef shape,
                                      double       z,
                                      double       tolerance,
                                      int32_t*     outCount)
{
  if (!shape || !outCount)
    return nullptr;
  *outCount = 0;

  try
  {
    // Create horizontal cutting plane at Z level
    gp_Pln plane(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1));

    // Compute section
    BRepAlgoAPI_Section section(shape->shape, plane);
    section.Build();
    if (!section.IsDone())
      return nullptr;

    TopoDS_Shape sectionShape = section.Shape();
    if (sectionShape.IsNull())
      return nullptr;

    // Collect edges from section result
    Handle(TopTools_HSequenceOfShape) edges = new TopTools_HSequenceOfShape;
    TopExp_Explorer                   explorer(sectionShape, TopAbs_EDGE);
    while (explorer.More())
    {
      edges->Append(explorer.Current());
      explorer.Next();
    }

    if (edges->Length() == 0)
      return nullptr;

    // Connect edges into wires using ShapeAnalysis_FreeBounds
    Handle(TopTools_HSequenceOfShape) wires = new TopTools_HSequenceOfShape;
    ShapeAnalysis_FreeBounds::ConnectEdgesToWires(edges,
                                                  tolerance,      // tolerance for connecting edges
                                                  Standard_False, // shared edges
                                                  wires);

    int wireCount = wires->Length();
    if (wireCount == 0)
      return nullptr;

    // Allocate array for result
    OCCTWireRef* result = new OCCTWireRef[wireCount];
    for (int i = 1; i <= wireCount; i++)
    {
      TopoDS_Wire theWire = TopoDS::Wire(wires->Value(i));
      result[i - 1]       = new OCCTWire(theWire);
    }

    *outCount = wireCount;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}
