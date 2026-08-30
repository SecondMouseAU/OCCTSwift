//
//  OCCTBridge_Modeling_WireEdgeFaceBuilders.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Modeling.mm (#396/#819):
//  BRepBuilderAPI_Make{Edge,Face,Wire,Vertex,Solid,Shell}, BRepLib_Make*. Public C surface
//  unchanged; imports the same OCCTBridge_Modeling.h every sibling file does. No symbol changes,
//  pure file move -- see Scripts/repro/396-modeling-mm-split/ for how.
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

OCCTShapeRef OCCTShapeCreateShellFromSurface(OCCTSurfaceRef surface)
{
  if (!surface || surface->surface.IsNull())
    return nullptr;
  try
  {
    BRepBuilderAPI_MakeShell builder(surface->surface);
    if (!builder.IsDone())
      return nullptr;
    return new OCCTShape(builder.Shell());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCreateVertex(double x, double y, double z)
{
  try
  {
    BRepBuilderAPI_MakeVertex builder(gp_Pnt(x, y, z));
    if (!builder.IsDone())
      return nullptr;
    return new OCCTShape(builder.Vertex());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFuseEdges(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepLib_FuseEdges fuser(shape->shape);
    fuser.Perform();
    return new OCCTShape(fuser.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeAddLinearRib(OCCTShapeRef shape,
                                   OCCTWireRef  profile,
                                   double       dirX,
                                   double       dirY,
                                   double       dirZ,
                                   double       dir1X,
                                   double       dir1Y,
                                   double       dir1Z,
                                   bool         fuse)
{
  if (!shape || !profile)
    return nullptr;
  try
  {
    BRepLib_FindSurface finder(profile->wire);
    if (!finder.Found())
      return nullptr;
    Handle(Geom_Plane) plane = Handle(Geom_Plane)::DownCast(finder.Surface());
    if (plane.IsNull())
      return nullptr;
    gp_Vec dir(dirX, dirY, dirZ);
    gp_Vec dir1(dir1X, dir1Y, dir1Z);
    BRepFeat_MakeLinearForm
      maker(shape->shape, profile->wire, plane, dir, dir1, fuse ? 1 : 0, false);
    maker.Perform();
    if (!maker.IsDone())
      return nullptr;
    return new OCCTShape(maker.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCreateLoftAdvanced(const OCCTWireRef* profiles,
                                         int32_t            profileCount,
                                         bool               solid,
                                         bool               ruled,
                                         double             firstVertexX,
                                         double             firstVertexY,
                                         double             firstVertexZ,
                                         double             lastVertexX,
                                         double             lastVertexY,
                                         double             lastVertexZ)
{
  if (!profiles || profileCount < 1)
    return nullptr;
  try
  {
    BRepOffsetAPI_ThruSections maker(solid, ruled);
    maker.CheckCompatibility(Standard_True);

    // Add first vertex if specified (NaN check)
    if (firstVertexX == firstVertexX)
    { // not NaN
      BRepBuilderAPI_MakeVertex mv(gp_Pnt(firstVertexX, firstVertexY, firstVertexZ));
      maker.AddVertex(TopoDS::Vertex(mv.Shape()));
    }

    for (int32_t i = 0; i < profileCount; i++)
    {
      if (profiles[i])
      {
        maker.AddWire(profiles[i]->wire);
      }
    }

    // Add last vertex if specified
    if (lastVertexX == lastVertexX)
    { // not NaN
      BRepBuilderAPI_MakeVertex mv(gp_Pnt(lastVertexX, lastVertexY, lastVertexZ));
      maker.AddVertex(TopoDS::Vertex(mv.Shape()));
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

OCCTShapeRef OCCTShapeAddRevolutionForm(OCCTShapeRef shape,
                                        OCCTWireRef  profile,
                                        double       axOX,
                                        double       axOY,
                                        double       axOZ,
                                        double       axDX,
                                        double       axDY,
                                        double       axDZ,
                                        double       height1,
                                        double       height2,
                                        bool         fuse)
{
  if (!shape || !profile)
    return nullptr;
  try
  {
    BRepLib_FindSurface finder(profile->wire);
    if (!finder.Found())
      return nullptr;
    Handle(Geom_Plane) plane = Handle(Geom_Plane)::DownCast(finder.Surface());
    if (plane.IsNull())
      return nullptr;
    gp_Ax1 axis(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));
    bool   sliding = true;
    BRepFeat_MakeRevolutionForm
      maker(shape->shape, profile->wire, plane, axis, height1, height2, fuse ? 1 : 0, sliding);
    maker.Perform();
    if (!maker.IsDone())
      return nullptr;
    return new OCCTShape(maker.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeDraftPrism(OCCTShapeRef shape,
                                 int32_t      profileFace,
                                 OCCTWireRef  profile,
                                 double       angleDeg,
                                 double       height,
                                 bool         fuse)
{
  if (!shape || !profile)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
    int32_t fi = profileFace + 1;
    if (fi < 1 || fi > faceMap.Extent())
      return nullptr;
    TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

    // Create profile face from wire
    BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face pbase = makeFace.Face();

    double              angleRad = angleDeg * M_PI / 180.0;
    BRepFeat_MakeDPrism maker(shape->shape,
                              pbase,
                              sketchFace,
                              angleRad,
                              fuse ? 1 : 0,
                              Standard_True);
    maker.Perform(height);
    if (!maker.IsDone())
      return nullptr;
    return new OCCTShape(maker.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeDraftPrismThruAll(OCCTShapeRef shape,
                                        int32_t      profileFace,
                                        OCCTWireRef  profile,
                                        double       angleDeg,
                                        bool         fuse)
{
  if (!shape || !profile)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
    int32_t fi = profileFace + 1;
    if (fi < 1 || fi > faceMap.Extent())
      return nullptr;
    TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

    BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face pbase = makeFace.Face();

    double              angleRad = angleDeg * M_PI / 180.0;
    BRepFeat_MakeDPrism maker(shape->shape,
                              pbase,
                              sketchFace,
                              angleRad,
                              fuse ? 1 : 0,
                              Standard_True);
    maker.PerformThruAll();
    if (!maker.IsDone())
      return nullptr;
    return new OCCTShape(maker.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeRevolFeature(OCCTShapeRef shape,
                                   int32_t      profileFace,
                                   OCCTWireRef  profile,
                                   double       axOX,
                                   double       axOY,
                                   double       axOZ,
                                   double       axDX,
                                   double       axDY,
                                   double       axDZ,
                                   double       angleDeg,
                                   bool         fuse)
{
  if (!shape || !profile)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
    int32_t fi = profileFace + 1;
    if (fi < 1 || fi > faceMap.Extent())
      return nullptr;
    TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

    BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face pbase = makeFace.Face();

    gp_Ax1 axis(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));
    double angleRad = angleDeg * M_PI / 180.0;

    BRepFeat_MakeRevol maker(shape->shape, pbase, sketchFace, axis, fuse ? 1 : 0, Standard_True);
    maker.Perform(angleRad);
    if (!maker.IsDone())
      return nullptr;
    return new OCCTShape(maker.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeRevolFeatureThruAll(OCCTShapeRef shape,
                                          int32_t      profileFace,
                                          OCCTWireRef  profile,
                                          double       axOX,
                                          double       axOY,
                                          double       axOZ,
                                          double       axDX,
                                          double       axDY,
                                          double       axDZ,
                                          bool         fuse)
{
  if (!shape || !profile)
    return nullptr;
  try
  {
    TopTools_IndexedMapOfShape faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
    int32_t fi = profileFace + 1;
    if (fi < 1 || fi > faceMap.Extent())
      return nullptr;
    TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

    BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face pbase = makeFace.Face();

    gp_Ax1 axis(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));

    BRepFeat_MakeRevol maker(shape->shape, pbase, sketchFace, axis, fuse ? 1 : 0, Standard_True);
    maker.PerformThruAll();
    if (!maker.IsDone())
      return nullptr;
    return new OCCTShape(maker.Shape());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCreateFaceFromSurface(OCCTSurfaceRef surface,
                                            double         uMin,
                                            double         uMax,
                                            double         vMin,
                                            double         vMax,
                                            double         tolerance)
{
  if (!surface || surface->surface.IsNull())
    return nullptr;
  try
  {
    BRepBuilderAPI_MakeFace maker(surface->surface, uMin, uMax, vMin, vMax, tolerance);
    if (!maker.IsDone())
      return nullptr;
    return new OCCTShape(maker.Face());
  }
  catch (...)
  {
    return nullptr;
  }
}

// Build a face on a surface trimmed to a non-rectangular region given by a closed UV-space
// polygon (uv = [u0,v0,u1,v1,...], count points). Each segment becomes a 2D edge with a pcurve
// on the surface, so the face footprint follows the polygon rather than a rectangular UV patch
// (OCCTSwift #233). Returns NULL on failure.
OCCTShapeRef OCCTShapeCreateFaceFromSurfaceUVPolygon(OCCTSurfaceRef surface,
                                                     const double*  uv,
                                                     int32_t        count)
{
  if (!surface || surface->surface.IsNull() || !uv || count < 3)
    return nullptr;
  try
  {
    Handle(Geom_Surface)    surf = surface->surface;
    BRepBuilderAPI_MakeWire wireMaker;
    for (int32_t i = 0; i < count; i++)
    {
      int32_t  j = (i + 1) % count;
      gp_Pnt2d a(uv[2 * i], uv[2 * i + 1]);
      gp_Pnt2d b(uv[2 * j], uv[2 * j + 1]);
      if (a.Distance(b) < Precision::Confusion())
        continue; // skip degenerate segment
      Handle(Geom2d_TrimmedCurve) seg = GCE2d_MakeSegment(a, b).Value();
      TopoDS_Edge                 e   = BRepBuilderAPI_MakeEdge(seg, surf).Edge();
      wireMaker.Add(e);
    }
    if (!wireMaker.IsDone())
      return nullptr;
    BRepBuilderAPI_MakeFace faceMaker(surf, wireMaker.Wire(), Standard_True);
    if (!faceMaker.IsDone())
      return nullptr;
    TopoDS_Face face = faceMaker.Face();
    BRepLib::BuildCurves3d(face); // add 3D curves from the pcurves
    return new OCCTShape(face);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeEdgesToFaces(OCCTShapeRef compound, bool isOnlyPlane)
{
  if (!compound)
    return nullptr;
  try
  {
    // Collect all edges from the input shape
    TopTools_ListOfShape edgeList;
    TopExp_Explorer      explorer(compound->shape, TopAbs_EDGE);
    while (explorer.More())
    {
      edgeList.Append(explorer.Current());
      explorer.Next();
    }
    if (edgeList.IsEmpty())
      return nullptr;

    // Build wires from edges, then faces from wires
    BRep_Builder    builder;
    TopoDS_Compound result;
    builder.MakeCompound(result);

    // Try to build wires and faces
    TopTools_ListOfShape remainingEdges;
    remainingEdges.Assign(edgeList);
    bool anyFace = false;

    while (!remainingEdges.IsEmpty())
    {
      BRepBuilderAPI_MakeWire wireBuilder;
      // Try adding edges to the wire
      bool added = true;
      while (added && !remainingEdges.IsEmpty())
      {
        added = false;
        TopTools_ListIteratorOfListOfShape it(remainingEdges);
        while (it.More())
        {
          wireBuilder.Add(TopoDS::Edge(it.Value()));
          if (wireBuilder.Error() == BRepBuilderAPI_WireDone)
          {
            added = true;
            remainingEdges.Remove(it);
          }
          else
          {
            wireBuilder = BRepBuilderAPI_MakeWire(wireBuilder.Wire());
            it.Next();
          }
        }
      }
      if (wireBuilder.IsDone())
      {
        TopoDS_Wire             wire = wireBuilder.Wire();
        BRepBuilderAPI_MakeFace faceBuilder(wire, isOnlyPlane);
        if (faceBuilder.IsDone())
        {
          builder.Add(result, faceBuilder.Face());
          anyFace = true;
        }
      }
      if (!added && !remainingEdges.IsEmpty())
      {
        // Can't connect more edges; start a new wire with first remaining
        TopTools_ListIteratorOfListOfShape it(remainingEdges);
        if (it.More())
        {
          remainingEdges.Remove(it);
        }
      }
    }

    if (!anyFace)
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCreateFaceFromWire(OCCTWireRef wire, bool planar)
{
  if (!wire)
    return nullptr;

  try
  {
    BRepBuilderAPI_MakeFace makeFace(wire->wire, planar);
    if (!makeFace.IsDone())
    {
      return nullptr;
    }

    TopoDS_Face face = makeFace.Face();
    if (face.IsNull())
      return nullptr;

    return new OCCTShape(face);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCreateFaceWithHoles(OCCTWireRef        outer,
                                          const OCCTWireRef* holes,
                                          int32_t            holeCount)
{
  if (!outer)
    return nullptr;

  try
  {
    // First create face from outer wire
    BRepBuilderAPI_MakeFace makeFace(outer->wire, true); // planar
    if (!makeFace.IsDone())
    {
      return nullptr;
    }

    // For a valid planar face with holes, each hole wire must wind OPPOSITE to
    // the outer boundary (measured in the face plane). Callers may hand in a hole
    // wound either way, so we CONDITIONALLY reverse: only flip a hole whose winding
    // currently MATCHES the outer's. A hole already wound opposite is left as-is.
    // (The previous implementation reversed every hole unconditionally, which broke
    // callers that already passed the geometrically-correct opposite winding, #274.)
    //
    // Winding is decided by the sign of each wire's signed area projected onto the
    // outer face plane. If the plane can't be determined we fall back to the old
    // unconditional-reverse behaviour, which is correct for same-sense inputs.
    BRepBuilderAPI_FindPlane finder(outer->wire);
    const bool               havePlane = finder.Found();
    gp_Pln                   plane;
    double                   outerSign = 0.0;
    if (havePlane)
    {
      plane     = finder.Plane()->Pln();
      outerSign = occtSignedWireAreaInPlane(outer->wire, plane);
    }

    // Add holes (inner wires)
    for (int32_t i = 0; i < holeCount; i++)
    {
      if (!holes[i])
        continue;
      const TopoDS_Wire& holeWire = holes[i]->wire;

      bool reverse;
      if (havePlane && outerSign != 0.0)
      {
        const double holeSign = occtSignedWireAreaInPlane(holeWire, plane);
        // Reverse only when the hole winds the SAME way as the outer.
        // If holeSign is ~0 (degenerate), fall back to reversing.
        reverse = (holeSign == 0.0) || (holeSign * outerSign > 0.0);
      }
      else
      {
        reverse = true; // no reliable plane: preserve legacy same-sense behaviour
      }

      TopoDS_Wire toAdd = reverse ? TopoDS::Wire(holeWire.Reversed()) : holeWire;
      makeFace.Add(toAdd);
    }

    if (!makeFace.IsDone())
    {
      return nullptr;
    }

    TopoDS_Face face = makeFace.Face();
    if (face.IsNull())
      return nullptr;

    return new OCCTShape(face);
  }
  catch (...)
  {
    return nullptr;
  }
}

// One solid per body-bounding shell, not just the first shell an explorer yields (#443).
// Sewing two disjoint bodies produces exactly the two-shell input this used to reduce to one
// solid, which is the input its own doc comment names, and after #442 the sibling entry point
// OCCTShapeSolidFromShell answered that same input with both bodies. Same helper, so the two
// now agree; cavity shells stay out of the result for the reason documented there.
//
// #443 review flagged the IsDone()/IsNull() checks below as a silent-drop path reopened one
// layer down: a MakeSolid failure used to fail the whole call, and per-shell it just skips that
// body. Checked against occt-src rather than assumed: BRepLib_MakeSolid's single-shell
// constructor (BRepLib_MakeSolid.cxx) unconditionally calls Done() after B.Add(myShape, S), with
// no closure or coherence check anywhere in the path, its own header says as much ("a solid
// under construction is always valid"). Confirmed with a probe (BRepBuilderAPI_MakeSolid on a
// 5-of-6-face open shell, and on a bare empty shell): IsDone() true and Solid() non-null in both
// cases, just a geometrically invalid solid (BRepCheck_Analyzer.IsValid() false) rather than a
// null one. So neither branch below can fire for a real shell today. They stay as push-not-drop
// rather than being deleted, matching OCCTShapeSolidFromShell's identical belt-and-braces
// comment ("keeps a body rather than dropping it if that changes"), same defensive contract,
// zero behaviour change either way.
OCCTShapeRef OCCTShapeCreateSolidFromShell(OCCTShapeRef shell)
{
  if (!shell)
    return nullptr;

  try
  {
    std::vector<TopoDS_Shape> made;
    for (const TopoDS_Shell& topoShell : occtBodyBoundingShells(shell->shape))
    {
      BRepBuilderAPI_MakeSolid makeSolid(topoShell);
      TopoDS_Solid             solid;
      if (makeSolid.IsDone())
        solid = makeSolid.Solid();
      if (solid.IsNull())
      {
        made.push_back(topoShell); // Kept, not dropped, see comment above.
        continue;
      }

      // Optionally fix the solid orientation
      ShapeFix_Solid fixer(solid);
      fixer.Perform();
      TopoDS_Shape fixedShape = fixer.Solid();
      // Keep the unfixed solid rather than dropping the body, as before.
      made.push_back((fixedShape.IsNull() || fixedShape.ShapeType() != TopAbs_SOLID)
                       ? TopoDS_Shape(solid)
                       : fixedShape);
    }

    TopoDS_Shape result = occtSolidBodiesToShape(made);
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireInterpolate(const double* points, int32_t count, bool closed, double tolerance)
{
  return occtWireInterpolateImpl(points, count, tolerance, closed, 0, 0, 0, 0, 0, 0, false);
}

OCCTWireRef OCCTWireInterpolateWithTangents(const double* points,
                                            int32_t       count,
                                            double        startTanX,
                                            double        startTanY,
                                            double        startTanZ,
                                            double        endTanX,
                                            double        endTanY,
                                            double        endTanZ,
                                            double        tolerance)
{
  return occtWireInterpolateImpl(points,
                                 count,
                                 tolerance,
                                 false, // not closed when tangents specified
                                 startTanX,
                                 startTanY,
                                 startTanZ,
                                 endTanX,
                                 endTanY,
                                 endTanZ,
                                 true);
}

OCCTWireRef OCCTWireCreateRectangle(double width, double height)
{
  try
  {
    // Sub-confusion dimensions make near-coincident corners and zero-length edges, which crash
    // OCCT 8.0.0p1 downstream (e.g. length on the degenerate wire). Reject as un-buildable.
    if (width < Precision::Confusion() || height < Precision::Confusion())
      return nullptr;
    double hw = width / 2;
    double hh = height / 2;

    gp_Pnt p1(-hw, -hh, 0);
    gp_Pnt p2(hw, -hh, 0);
    gp_Pnt p3(hw, hh, 0);
    gp_Pnt p4(-hw, hh, 0);

    TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2);
    TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3);
    TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(p3, p4);
    TopoDS_Edge e4 = BRepBuilderAPI_MakeEdge(p4, p1);

    BRepBuilderAPI_MakeWire wireMaker;
    wireMaker.Add(e1);
    wireMaker.Add(e2);
    wireMaker.Add(e3);
    wireMaker.Add(e4);

    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateCircle(double radius)
{
  try
  {
    gp_Circ                 circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), radius);
    TopoDS_Edge             edge = BRepBuilderAPI_MakeEdge(circle);
    BRepBuilderAPI_MakeWire wireMaker(edge);
    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateCircleEx(double radius,
                                   double ox,
                                   double oy,
                                   double oz,
                                   double nx,
                                   double ny,
                                   double nz)
{
  try
  {
    gp_Circ                 circle(gp_Ax2(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), radius);
    TopoDS_Edge             edge = BRepBuilderAPI_MakeEdge(circle);
    BRepBuilderAPI_MakeWire wireMaker(edge);
    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreatePolygon(const double* points, int32_t pointCount, bool closed)
{
  if (!points || pointCount < 2)
    return nullptr;

  try
  {
    BRepBuilderAPI_MakeWire wireMaker;

    for (int32_t i = 0; i < pointCount - 1; i++)
    {
      gp_Pnt      p1(points[i * 2], points[i * 2 + 1], 0);
      gp_Pnt      p2(points[(i + 1) * 2], points[(i + 1) * 2 + 1], 0);
      TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(p1, p2);
      wireMaker.Add(edge);
    }

    if (closed && pointCount > 2)
    {
      gp_Pnt      pLast(points[(pointCount - 1) * 2], points[(pointCount - 1) * 2 + 1], 0);
      gp_Pnt      pFirst(points[0], points[1], 0);
      TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(pLast, pFirst);
      wireMaker.Add(edge);
    }

    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateFromPoints3D(const double* points, int32_t pointCount, bool closed)
{
  if (!points || pointCount < 2)
    return nullptr;

  try
  {
    BRepBuilderAPI_MakeWire wireMaker;

    for (int32_t i = 0; i < pointCount - 1; i++)
    {
      gp_Pnt      p1(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
      gp_Pnt      p2(points[(i + 1) * 3], points[(i + 1) * 3 + 1], points[(i + 1) * 3 + 2]);
      TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(p1, p2);
      wireMaker.Add(edge);
    }

    if (closed && pointCount > 2)
    {
      gp_Pnt      pLast(points[(pointCount - 1) * 3],
                        points[(pointCount - 1) * 3 + 1],
                        points[(pointCount - 1) * 3 + 2]);
      gp_Pnt      pFirst(points[0], points[1], points[2]);
      TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(pLast, pFirst);
      wireMaker.Add(edge);
    }

    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateLine(double x1, double y1, double z1, double x2, double y2, double z2)
{
  try
  {
    gp_Pnt                  p1(x1, y1, z1);
    gp_Pnt                  p2(x2, y2, z2);
    TopoDS_Edge             edge = BRepBuilderAPI_MakeEdge(p1, p2);
    BRepBuilderAPI_MakeWire wireMaker(edge);
    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateArc(double centerX,
                              double centerY,
                              double centerZ,
                              double radius,
                              double startAngle,
                              double endAngle,
                              double normalX,
                              double normalY,
                              double normalZ)
{
  try
  {
    gp_Pnt center(centerX, centerY, centerZ);
    gp_Dir normal(normalX, normalY, normalZ);
    gp_Ax2 axis(center, normal);

    gp_Circ circle(axis, radius);

    // Create arc from angles
    Handle(Geom_Circle)       geomCircle = new Geom_Circle(circle);
    Handle(Geom_TrimmedCurve) arc        = new Geom_TrimmedCurve(geomCircle, startAngle, endAngle);

    TopoDS_Edge             edge = BRepBuilderAPI_MakeEdge(arc);
    BRepBuilderAPI_MakeWire wireMaker(edge);
    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateArcThroughPoints(double sx,
                                           double sy,
                                           double sz,
                                           double mx,
                                           double my,
                                           double mz,
                                           double ex,
                                           double ey,
                                           double ez)
{
  try
  {
    gp_Pnt             p1(sx, sy, sz);
    gp_Pnt             p2(mx, my, mz);
    gp_Pnt             p3(ex, ey, ez);
    GC_MakeArcOfCircle maker(p1, p2, p3);
    if (!maker.IsDone())
      return nullptr;
    Handle(Geom_TrimmedCurve) arc  = maker.Value();
    TopoDS_Edge               edge = BRepBuilderAPI_MakeEdge(arc);
    BRepBuilderAPI_MakeWire   wireMaker(edge);
    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateBSpline(const double* controlPoints, int32_t pointCount)
{
  if (!controlPoints || pointCount < 2)
    return nullptr;

  try
  {
    TColgp_Array1OfPnt points(1, pointCount);
    for (int32_t i = 0; i < pointCount; i++)
    {
      points.SetValue(
        i + 1,
        gp_Pnt(controlPoints[i * 3], controlPoints[i * 3 + 1], controlPoints[i * 3 + 2]));
    }

    GeomAPI_PointsToBSpline fitter(points);
    if (!fitter.IsDone())
      return nullptr;

    Handle(Geom_BSplineCurve) curve = fitter.Curve();
    TopoDS_Edge               edge  = BRepBuilderAPI_MakeEdge(curve);
    BRepBuilderAPI_MakeWire   wireMaker(edge);
    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateNURBS(const double*  poles,
                                int32_t        poleCount,
                                const double*  weights,
                                const double*  knots,
                                int32_t        knotCount,
                                const int32_t* multiplicities,
                                int32_t        degree)
{
  if (!poles || poleCount < 2 || !knots || knotCount < 2 || degree < 1)
    return nullptr;

  try
  {
    // Create control points array (1-indexed in OCCT)
    TColgp_Array1OfPnt polesArray(1, poleCount);
    for (int32_t i = 0; i < poleCount; i++)
    {
      polesArray.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
    }

    // Create weights array
    TColStd_Array1OfReal weightsArray(1, poleCount);
    for (int32_t i = 0; i < poleCount; i++)
    {
      weightsArray.SetValue(i + 1, weights ? weights[i] : 1.0);
    }

    // Create knots array
    TColStd_Array1OfReal knotsArray(1, knotCount);
    for (int32_t i = 0; i < knotCount; i++)
    {
      knotsArray.SetValue(i + 1, knots[i]);
    }

    // Create multiplicities array
    TColStd_Array1OfInteger multsArray(1, knotCount);
    for (int32_t i = 0; i < knotCount; i++)
    {
      multsArray.SetValue(i + 1, multiplicities ? multiplicities[i] : 1);
    }

    // Create the B-spline curve
    Handle(Geom_BSplineCurve) curve =
      new Geom_BSplineCurve(polesArray, weightsArray, knotsArray, multsArray, degree);

    TopoDS_Edge             edge = BRepBuilderAPI_MakeEdge(curve);
    BRepBuilderAPI_MakeWire wireMaker(edge);
    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateNURBSUniform(const double* poles,
                                       int32_t       poleCount,
                                       const double* weights,
                                       int32_t       degree)
{
  if (!poles || poleCount < 2 || degree < 1)
    return nullptr;
  if (poleCount < degree + 1)
    return nullptr; // Need at least degree+1 control points

  try
  {
    // Create control points array
    TColgp_Array1OfPnt polesArray(1, poleCount);
    for (int32_t i = 0; i < poleCount; i++)
    {
      polesArray.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
    }

    // Create weights array
    TColStd_Array1OfReal weightsArray(1, poleCount);
    for (int32_t i = 0; i < poleCount; i++)
    {
      weightsArray.SetValue(i + 1, weights ? weights[i] : 1.0);
    }

    // For clamped uniform B-spline:
    // - First and last knots have multiplicity = degree + 1
    // - Interior knots have multiplicity = 1
    // - Number of interior knots = poleCount - degree - 1
    // - Total distinct knots = interior + 2 (for start and end)
    int32_t interiorKnots = poleCount - degree - 1;
    int32_t knotCount     = interiorKnots + 2;

    TColStd_Array1OfReal    knotsArray(1, knotCount);
    TColStd_Array1OfInteger multsArray(1, knotCount);

    // Start knot at 0 with multiplicity degree+1
    knotsArray.SetValue(1, 0.0);
    multsArray.SetValue(1, degree + 1);

    // Interior knots uniformly distributed
    for (int32_t i = 0; i < interiorKnots; i++)
    {
      knotsArray.SetValue(i + 2, (double)(i + 1) / (double)(interiorKnots + 1));
      multsArray.SetValue(i + 2, 1);
    }

    // End knot at 1 with multiplicity degree+1
    knotsArray.SetValue(knotCount, 1.0);
    multsArray.SetValue(knotCount, degree + 1);

    // Create the B-spline curve
    Handle(Geom_BSplineCurve) curve =
      new Geom_BSplineCurve(polesArray, weightsArray, knotsArray, multsArray, degree);

    TopoDS_Edge             edge = BRepBuilderAPI_MakeEdge(curve);
    BRepBuilderAPI_MakeWire wireMaker(edge);
    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateCubicBSpline(const double* poles, int32_t poleCount)
{
  // Cubic B-spline with uniform weights (non-rational)
  return OCCTWireCreateNURBSUniform(poles, poleCount, nullptr, 3);
}

OCCTWireRef OCCTWireJoin(const OCCTWireRef* wires, int32_t count)
{
  if (!wires || count < 1)
    return nullptr;

  try
  {
    BRepBuilderAPI_MakeWire wireMaker;

    for (int32_t i = 0; i < count; i++)
    {
      // #1035: the array pointer above says nothing about the element, and
      // BRepBuilderAPI_MakeWire::Add dereferences a null TopoDS_Wire.
      //
      // This SKIPS a null element, where #1026 made OCCTShapeCreateCompound refuse the whole
      // call for one. The skip is this function's own pre-existing contract for a null pointer
      // and is left alone rather than changed under cover of a crash fix; no public Swift
      // producer of a null-carrying Wire exists today, so nothing observes the divergence. If
      // one ever does, the two need reconciling.
      if (occtShapeIsPresent(wires[i]))
      {
        wireMaker.Add(wires[i]->wire);
      }
    }

    if (!wireMaker.IsDone())
      return nullptr;
    return new OCCTWire(wireMaker.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

// #443 audit: each argument contributes only its FIRST shell. The outer-versus-cavity
// contract is the caller's to state (that is what the argument order means), but which shell
// of a multi-shell argument gets used is not. Documented on Shape.solidFromShells rather
// than changed, since widening it would make the argument order stop meaning anything.
OCCTShapeRef OCCTSolidFromShells(OCCTShapeRef* shells, int32_t count)
{
  if (!shells || count <= 0)
    return nullptr;
  try
  {
    // Get the first shell
    TopExp_Explorer exp(shells[0]->shape, TopAbs_SHELL);
    if (!exp.More())
      return nullptr;
    TopoDS_Shell firstShell = TopoDS::Shell(exp.Current());

    BRepBuilderAPI_MakeSolid maker(firstShell);

    // Add additional shells (cavities)
    for (int32_t i = 1; i < count; i++)
    {
      if (!shells[i])
        continue;
      TopExp_Explorer exp2(shells[i]->shape, TopAbs_SHELL);
      if (exp2.More())
      {
        maker.Add(TopoDS::Shell(exp2.Current()));
      }
    }

    if (!maker.IsDone())
      return nullptr;
    return new OCCTShape(maker.Solid());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireCreateFastPolygon(const double* coords, int32_t pointCount, bool closed)
{
  if (!coords || pointCount < 2)
    return nullptr;
  try
  {
    BRepBuilderAPI_MakePolygon poly;
    for (int32_t i = 0; i < pointCount; i++)
    {
      poly.Add(gp_Pnt(coords[i * 3], coords[i * 3 + 1], coords[i * 3 + 2]));
    }
    if (closed)
      poly.Close();
    if (!poly.IsDone())
      return nullptr;
    return new OCCTWire(poly.Wire());
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - BRepLib MakePolygon / MakeWire (v0.51)
OCCTWireRef _Nullable OCCTWireMakePolygonFromPoints(const double* coords,
                                                    int32_t       nPoints,
                                                    bool          close)
{
  if (!coords || nPoints < 2)
    return nullptr;
  try
  {
    BRepLib_MakePolygon poly;
    for (int32_t i = 0; i < nPoints; i++)
    {
      poly.Add(gp_Pnt(coords[i * 3], coords[i * 3 + 1], coords[i * 3 + 2]));
    }
    if (close)
      poly.Close();
    if (!poly.IsDone())
      return nullptr;
    auto* wire = new OCCTWire();
    wire->wire = poly.Wire();
    return wire;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef _Nullable OCCTWireMakeWireFromEdgeRefs(const OCCTEdgeRef _Nonnull* _Nonnull edges,
                                                   int32_t count)
{
  if (!edges || count < 1)
    return nullptr;
  try
  {
    BRepLib_MakeWire mw;
    for (int32_t i = 0; i < count; i++)
    {
      if (!edges[i])
        return nullptr;
      mw.Add(edges[i]->edge);
    }
    if (!mw.IsDone())
      return nullptr;
    auto* wire = new OCCTWire();
    wire->wire = mw.Wire();
    return wire;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFromMesh(const double*  points,
                               int32_t        nodeCount,
                               const int32_t* triangles,
                               int32_t        triCount)
{
  if (!points || nodeCount < 3 || !triangles || triCount < 1)
    return nullptr;
  try
  {
    TColgp_Array1OfPnt nodes(1, nodeCount);
    for (int32_t i = 0; i < nodeCount; i++)
    {
      nodes.SetValue(i + 1, gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]));
    }

    Poly_Array1OfTriangle tris(1, triCount);
    for (int32_t i = 0; i < triCount; i++)
    {
      tris.SetValue(i + 1,
                    Poly_Triangle(triangles[i * 3], triangles[i * 3 + 1], triangles[i * 3 + 2]));
    }

    Handle(Poly_Triangulation) mesh = new Poly_Triangulation(nodes, tris);
    if (mesh.IsNull())
      return nullptr;

    BRepBuilderAPI_MakeShapeOnMesh maker(mesh);
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

OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromLine(double ox,
                                                   double oy,
                                                   double oz,
                                                   double dx,
                                                   double dy,
                                                   double dz,
                                                   double p1,
                                                   double p2)
{
  try
  {
    gp_Lin           line(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz));
    BRepLib_MakeEdge me(line, p1, p2);
    if (!me.IsDone())
      return nullptr;
    return new OCCTShape(me.Edge());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromPoints(double x1,
                                                     double y1,
                                                     double z1,
                                                     double x2,
                                                     double y2,
                                                     double z2)
{
  try
  {
    BRepLib_MakeEdge me(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2));
    if (!me.IsDone())
      return nullptr;
    return new OCCTShape(me.Edge());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromCircle(double cx,
                                                     double cy,
                                                     double cz,
                                                     double dx,
                                                     double dy,
                                                     double dz,
                                                     double radius,
                                                     double p1,
                                                     double p2)
{
  try
  {
    gp_Circ          circ(gp_Ax2(gp_Pnt(cx, cy, cz), gp_Dir(dx, dy, dz)), radius);
    BRepLib_MakeEdge me(circ, p1, p2);
    if (!me.IsDone())
      return nullptr;
    return new OCCTShape(me.Edge());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepLibMakeFaceFromPlane(double ox,
                                                    double oy,
                                                    double oz,
                                                    double nx,
                                                    double ny,
                                                    double nz,
                                                    double uMin,
                                                    double uMax,
                                                    double vMin,
                                                    double vMax,
                                                    double tolerance)
{
  try
  {
    gp_Pln             pln(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz));
    Handle(Geom_Plane) plane = new Geom_Plane(pln);
    BRepLib_MakeFace   mf(plane, uMin, uMax, vMin, vMax, tolerance);
    if (!mf.IsDone())
      return nullptr;
    return new OCCTShape(mf.Face());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepLibMakeFaceFromCylinder(double ox,
                                                       double oy,
                                                       double oz,
                                                       double dx,
                                                       double dy,
                                                       double dz,
                                                       double radius,
                                                       double uMin,
                                                       double uMax,
                                                       double vMin,
                                                       double vMax,
                                                       double tolerance)
{
  try
  {
    Handle(Geom_CylindricalSurface) cyl =
      new Geom_CylindricalSurface(gp_Ax2(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz)), radius);
    BRepLib_MakeFace mf(cyl, uMin, uMax, vMin, vMax, tolerance);
    if (!mf.IsDone())
      return nullptr;
    return new OCCTShape(mf.Face());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef _Nullable OCCTBRepLibMakeShellFromPlane(double ox,
                                                     double oy,
                                                     double oz,
                                                     double nx,
                                                     double ny,
                                                     double nz,
                                                     double uMin,
                                                     double uMax,
                                                     double vMin,
                                                     double vMax)
{
  try
  {
    Handle(Geom_Plane) plane = new Geom_Plane(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz));
    BRepLib_MakeShell  ms(plane, uMin, uMax, vMin, vMax, false);
    if (!ms.IsDone())
      return nullptr;
    return new OCCTShape(ms.Shell());
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTMakeDir2d(double x, double y, double* outX, double* outY)
{
  try
  {
    gce_MakeDir2d md(x, y);
    if (!md.IsDone())
      return false;
    gp_Dir2d d = md.Value();
    *outX      = d.X();
    *outY      = d.Y();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTMakeDir2dFromPoints(double x1, double y1, double x2, double y2, double* outX, double* outY)
{
  try
  {
    gce_MakeDir2d md(gp_Pnt2d(x1, y1), gp_Pnt2d(x2, y2));
    if (!md.IsDone())
      return false;
    gp_Dir2d d = md.Value();
    *outX      = d.X();
    *outY      = d.Y();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTMakeFaceFromSphere(double cx,
                                    double cy,
                                    double cz,
                                    double radius,
                                    double umin,
                                    double umax,
                                    double vmin,
                                    double vmax)
{
  try
  {
    gp_Sphere               sphere(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
    BRepBuilderAPI_MakeFace mf(sphere, umin, umax, vmin, vmax);
    if (!mf.IsDone())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = mf.Shape();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeFaceFromTorus(double cx,
                                   double cy,
                                   double cz,
                                   double nx,
                                   double ny,
                                   double nz,
                                   double major,
                                   double minor,
                                   double umin,
                                   double umax,
                                   double vmin,
                                   double vmax)
{
  try
  {
    gp_Torus                torus(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), major, minor);
    BRepBuilderAPI_MakeFace mf(torus, umin, umax, vmin, vmax);
    if (!mf.IsDone())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = mf.Shape();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeFaceFromCone(double cx,
                                  double cy,
                                  double cz,
                                  double nx,
                                  double ny,
                                  double nz,
                                  double angle,
                                  double radius,
                                  double umin,
                                  double umax,
                                  double vmin,
                                  double vmax)
{
  try
  {
    gp_Cone                 cone(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz)), angle, radius);
    BRepBuilderAPI_MakeFace mf(cone, umin, umax, vmin, vmax);
    if (!mf.IsDone())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = mf.Shape();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeFaceFromSurfaceWire(OCCTSurfaceRef surface, OCCTShapeRef wire, bool inside)
{
  if (!surface || surface->surface.IsNull() || !wire)
    return nullptr;
  try
  {
    BRepBuilderAPI_MakeFace mf(surface->surface, TopoDS::Wire(wire->shape), inside);
    if (!mf.IsDone())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = mf.Shape();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeFaceCopy(OCCTShapeRef face)
{
  if (!face)
    return nullptr;
  try
  {
    BRepBuilderAPI_MakeFace mf(TopoDS::Face(face->shape));
    if (!mf.IsDone())
      return nullptr;
    auto result   = new OCCTShape();
    result->shape = mf.Shape();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdgeFromEllipse(double cx,
                                     double cy,
                                     double cz,
                                     double nx,
                                     double ny,
                                     double nz,
                                     double major,
                                     double minor)
{
  try
  {
    // BRepBuilderAPI_MakeEdge reports IsDone() for every degenerate conic, so without this
    // the caller gets a live edge carrying a curve that is really a point (#554).
    if (!occtValidEllipseRadii(major, minor))
      return nullptr;
    gp_Ax2                  ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    gp_Elips                elips(ax, major, minor);
    BRepBuilderAPI_MakeEdge me(elips);
    if (!me.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = me.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdgeFromEllipseArc(double cx,
                                        double cy,
                                        double cz,
                                        double nx,
                                        double ny,
                                        double nz,
                                        double major,
                                        double minor,
                                        double u1,
                                        double u2)
{
  try
  {
    if (!occtValidEllipseRadii(major, minor))
      return nullptr;
    gp_Ax2                  ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    gp_Elips                elips(ax, major, minor);
    BRepBuilderAPI_MakeEdge me(elips, u1, u2);
    if (!me.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = me.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdgeFromHyperbolaArc(double cx,
                                          double cy,
                                          double cz,
                                          double nx,
                                          double ny,
                                          double nz,
                                          double major,
                                          double minor,
                                          double u1,
                                          double u2)
{
  try
  {
    if (!occtValidHyperbolaRadii(major, minor))
      return nullptr;
    gp_Ax2                  ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    gp_Hypr                 hypr(ax, major, minor);
    BRepBuilderAPI_MakeEdge me(hypr, u1, u2);
    if (!me.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = me.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdgeFromParabolaArc(double cx,
                                         double cy,
                                         double cz,
                                         double nx,
                                         double ny,
                                         double nz,
                                         double focal,
                                         double u1,
                                         double u2)
{
  try
  {
    if (!occtValidParabolaFocal(focal))
      return nullptr;
    gp_Ax2                  ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
    gp_Parab                parab(ax, focal);
    BRepBuilderAPI_MakeEdge me(parab, u1, u2);
    if (!me.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = me.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdgeFromCurve(OCCTCurve3DRef curve)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    BRepBuilderAPI_MakeEdge me(curve->curve);
    if (!me.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = me.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdgeFromCurveParams(OCCTCurve3DRef curve, double u1, double u2)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    BRepBuilderAPI_MakeEdge me(curve->curve, u1, u2);
    if (!me.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = me.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdgeFromCurvePoints(OCCTCurve3DRef curve,
                                         double         x1,
                                         double         y1,
                                         double         z1,
                                         double         x2,
                                         double         y2,
                                         double         z2)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    BRepBuilderAPI_MakeEdge me(curve->curve, gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2));
    if (!me.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = me.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdgeOnSurface(OCCTCurve2DRef pcurve, OCCTSurfaceRef surface)
{
  if (!pcurve || pcurve->curve.IsNull() || !surface || surface->surface.IsNull())
    return nullptr;
  try
  {
    BRepBuilderAPI_MakeEdge me(pcurve->curve, surface->surface);
    if (!me.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = me.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeEdgeOnSurfaceParams(OCCTCurve2DRef pcurve,
                                         OCCTSurfaceRef surface,
                                         double         u1,
                                         double         u2)
{
  if (!pcurve || pcurve->curve.IsNull() || !surface || surface->surface.IsNull())
    return nullptr;
  try
  {
    BRepBuilderAPI_MakeEdge me(pcurve->curve, surface->surface, u1, u2);
    if (!me.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = me.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeFaceFromSurfaceUV(OCCTSurfaceRef surface,
                                       double         umin,
                                       double         umax,
                                       double         vmin,
                                       double         vmax,
                                       double         tol)
{
  if (!surface || surface->surface.IsNull())
    return nullptr;
  try
  {
    BRepBuilderAPI_MakeFace mf(surface->surface, umin, umax, vmin, vmax, tol);
    if (!mf.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = mf.Shape();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireBuilderRef OCCTWireBuilderCreate()
{
  try
  {
    return new OCCTWireBuilder();
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTWireBuilderRelease(OCCTWireBuilderRef wb)
{
  delete wb;
}

void OCCTWireBuilderAddEdge(OCCTWireBuilderRef wb, OCCTShapeRef edge)
{
  if (!wb || !edge)
    return;
  try
  {
    wb->maker.Add(TopoDS::Edge(edge->shape));
  }
  catch (...)
  {
  }
}

void OCCTWireBuilderAddWire(OCCTWireBuilderRef wb, OCCTShapeRef wire)
{
  if (!wb || !wire)
    return;
  try
  {
    wb->maker.Add(TopoDS::Wire(wire->shape));
  }
  catch (...)
  {
  }
}

OCCTShapeRef OCCTWireBuilderWire(OCCTWireBuilderRef wb)
{
  if (!wb)
    return nullptr;
  try
  {
    if (!wb->maker.IsDone())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = wb->maker.Wire();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTWireBuilderIsDone(OCCTWireBuilderRef wb)
{
  if (!wb)
    return false;
  try
  {
    return wb->maker.IsDone();
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTWireBuilderError(OCCTWireBuilderRef wb)
{
  if (!wb)
    return 1; // EmptyWire
  try
  {
    return (int32_t)wb->maker.Error();
  }
  catch (...)
  {
    return 1;
  }
}

OCCTWireRef OCCTWireFromCurve2DOnPlane(OCCTCurve2DRef curve,
                                       double         ox,
                                       double         oy,
                                       double         oz,
                                       double         nx,
                                       double         ny,
                                       double         nz,
                                       double         xx,
                                       double         xy,
                                       double         xz)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    gp_Pnt origin(ox, oy, oz);
    gp_Dir normal(nx, ny, nz);
    gp_Dir xDir(xx, xy, xz);
    gp_Ax2 ax2(origin, normal, xDir);
    gp_Pln plane(ax2);

    // BRepBuilderAPI_MakeEdge accepts a Geom2d_Curve + Handle(Geom_Surface)
    Handle(Geom_Plane)      surf = new Geom_Plane(plane);
    BRepBuilderAPI_MakeEdge maker(curve->curve, surf);
    if (!maker.IsDone())
      return nullptr;
    TopoDS_Edge edge = maker.Edge();

    // Build the 3D curve representation from the pcurve on the plane surface
    BRepLib::BuildCurves3d(edge);

    BRepBuilderAPI_MakeWire wireMaker(edge);
    if (!wireMaker.IsDone())
      return nullptr;

    auto* w = new OCCTWire();
    w->wire = wireMaker.Wire();
    return w;
  }
  catch (...)
  {
    return nullptr;
  }
}

// Note: This creates an approximation of the swept volume using
// two cylinders connected by a box. For CAM purposes, this provides
// a conservative (larger) estimate suitable for collision detection
// and material removal simulation. A true swept solid could use
// BRepOffsetAPI_MakePipeShell for more accurate results.
OCCTShapeRef OCCTShapeCreateToolSweep(double radius,
                                      double height,
                                      double x1,
                                      double y1,
                                      double z1,
                                      double x2,
                                      double y2,
                                      double z2)
{
  try
  {
    // For a cylindrical tool (flat end mill) moving from point 1 to point 2:
    // The swept volume consists of:
    // 1. Cylinder at start position
    // 2. Cylinder at end position
    // 3. A box connecting them (for horizontal component)

    double dx     = x2 - x1;
    double dy     = y2 - y1;
    double dz     = z2 - z1;
    double xyDist = std::sqrt(dx * dx + dy * dy);

    // Use the lower Z as the bottom of the swept volume
    double bottomZ = std::min(z1, z2);

    // Create cylinder at start position
    gp_Ax2                   axis1(gp_Pnt(x1, y1, bottomZ), gp_Dir(0, 0, 1));
    BRepPrimAPI_MakeCylinder cyl1Maker(axis1, radius, height + std::abs(dz));
    TopoDS_Shape             result = cyl1Maker.Shape();

    // If there's XY movement, we need the end cylinder and connecting box
    if (xyDist > 1e-6)
    {
      // Create cylinder at end position
      gp_Ax2                   axis2(gp_Pnt(x2, y2, bottomZ), gp_Dir(0, 0, 1));
      BRepPrimAPI_MakeCylinder cyl2Maker(axis2, radius, height + std::abs(dz));

      // Union end cylinder
      BRepAlgoAPI_Fuse fuse1(result, cyl2Maker.Shape());
      fuse1.Build();
      if (!fuse1.IsDone())
        return nullptr;
      result = fuse1.Shape();

      // Create connecting box
      // The box needs to be oriented along the movement direction
      // Width = 2*radius (tool diameter), Length = xyDist, Height = tool height + dz

      // Calculate perpendicular direction for box width
      double perpX = -dy / xyDist; // perpendicular to movement direction
      double perpY = dx / xyDist;

      // Box corner points (4 corners at bottom, extruded up)
      // The box connects the two cylinder centers
      gp_Pnt p1(x1 + perpX * radius, y1 + perpY * radius, bottomZ);
      gp_Pnt p2(x1 - perpX * radius, y1 - perpY * radius, bottomZ);
      gp_Pnt p3(x2 - perpX * radius, y2 - perpY * radius, bottomZ);
      gp_Pnt p4(x2 + perpX * radius, y2 + perpY * radius, bottomZ);

      // Create edges for the bottom face
      TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2);
      TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3);
      TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(p3, p4);
      TopoDS_Edge e4 = BRepBuilderAPI_MakeEdge(p4, p1);

      // Create wire from edges
      BRepBuilderAPI_MakeWire wireMaker;
      wireMaker.Add(e1);
      wireMaker.Add(e2);
      wireMaker.Add(e3);
      wireMaker.Add(e4);

      if (!wireMaker.IsDone())
        return nullptr;

      // Create face from wire
      BRepBuilderAPI_MakeFace faceMaker(wireMaker.Wire());
      if (!faceMaker.IsDone())
        return nullptr;

      // Extrude face upward to create box
      gp_Vec                extrudeVec(0, 0, height + std::abs(dz));
      BRepPrimAPI_MakePrism prismMaker(faceMaker.Face(), extrudeVec);
      prismMaker.Build();
      if (!prismMaker.IsDone())
        return nullptr;

      // Union connecting box
      BRepAlgoAPI_Fuse fuse2(result, prismMaker.Shape());
      fuse2.Build();
      if (!fuse2.IsDone())
        return nullptr;
      result = fuse2.Shape();
    }

    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeCreateExtrusion(OCCTWireRef profile,
                                      double      dx,
                                      double      dy,
                                      double      dz,
                                      double      length)
{
  if (!profile)
    return nullptr;
  occtEnsureSignals();
  try
  {
    OCC_CATCH_SIGNALS
    // Normalize direction and scale by length
    double mag = std::sqrt(dx * dx + dy * dy + dz * dz);
    if (mag < 1e-10)
      return nullptr;
    gp_Vec direction(dx / mag * length, dy / mag * length, dz / mag * length);

    // Create a face from the wire for solid extrusion
    BRepBuilderAPI_MakeFace faceMaker(profile->wire);
    if (!faceMaker.IsDone())
      return nullptr;

    // #263: a self-intersecting profile extrudes into a prism that heap-corrupts OCCT's
    // ShapeFix downstream (uncatchable OS signal). Refuse it here so the chain breaks with nil.
    if (occtHasSelfIntersectingWire(faceMaker.Face()))
      return nullptr;

    BRepPrimAPI_MakePrism maker(faceMaker.Face(), direction);
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

void OCCTFreeWireArray(OCCTWireRef* wires, int32_t count)
{
  if (!wires)
    return;
  for (int32_t i = 0; i < count; i++)
  {
    delete wires[i];
  }
  delete[] wires;
}

void OCCTFreeWireArrayOnly(OCCTWireRef* wires)
{
  if (!wires)
    return;
  delete[] wires;
}
