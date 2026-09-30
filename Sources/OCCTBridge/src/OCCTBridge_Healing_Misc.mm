//
//  OCCTBridge_Healing_Misc.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Healing.mm (#1380): ShapeBuild_*, ShapeExtend_Explorer, NURBS conversion,
//  BRepLib_ValidateEdge, BRepAlgo_FaceRestrictor. Public C surface unchanged; every sibling file
//  imports the same headers this one does (the shared preamble below). No symbol changes, pure file
//  move -- see Scripts/repro/396-bridge-mm-split/ for how.
//

//
//  OCCTBridge_Healing.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm, issue #99.
//
//  Shape healing & analysis (v0.13) + Advanced blends & surface filling
//  (v0.14):
//
//  - Shape healing: ShapeFix_Shape / Face / Wire, tolerance analysis,
//    shell + wire validators, BRepCheck_Analyzer
//  - Surface upgrade: ShapeUpgrade_UnifySameDomain
//  - Advanced blends: filling surfaces with point + curve constraints
//    (GeomPlate_*), filleting with sigil controls, surface filling
//
//  Public C surface unchanged. No symbol changes, pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Edge.hxx>
#include <BRepCheck_Face.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepCheck_Shell.hxx>
#include <BRepCheck_Solid.hxx>
#include <BRepCheck_Status.hxx>
#include <BRepCheck_Vertex.hxx>
#include <BRepCheck_Wire.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <ShapeAnalysis_ShapeContents.hxx>
#include <BRepAlgoAPI_Check.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <ChFi2d_Builder.hxx>
#include <ChFi2d_ConstructionError.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepTools.hxx>

#include <Geom_BSplineSurface.hxx>
#include <Geom_Curve.hxx>
#include <GeomAbs_Shape.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>

#include <gp_Pnt.hxx>
#include <GProp_GProps.hxx>

#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <ShapeAnalysis_Shell.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeAnalysis.hxx>
#include <ShapeFix_Face.hxx>
#include <ShapeExtend_Status.hxx>
#include <NCollection_Sequence.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeFix_Wire.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <ShapeUpgrade_ShapeDivideAngle.hxx>
#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_FaceDivideArea.hxx>
#include <ShapeUpgrade_ShapeDivideClosedEdges.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <BRepAlgo_FaceRestrictor.hxx>
#include <ShapeAnalysis_FreeBoundData.hxx>
#include <ShapeAnalysis_FreeBoundsProperties.hxx>
#include <ShapeAnalysis_Geom.hxx>
#include <ShapeAnalysis_WireVertex.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeFix_Edge.hxx>
#include <ShapeFix_EdgeConnect.hxx>
#include <ShapeFix_SplitTool.hxx>
#include <BRepTools_Substitution.hxx>
#include <ShapeAnalysis_TransferParametersProj.hxx>
#include <ShapeBuild_Edge.hxx>
#include <ShapeBuild_Vertex.hxx>
#include <ShapeCustom_DirectModification.hxx>
#include <ShapeCustom_SweptToElementary.hxx>
#include <ShapeCustom_TrsfModification.hxx>
#include <ShapeExtend_Explorer.hxx>
#include <ShapeUpgrade_ClosedEdgeDivide.hxx>
#include <ShapeUpgrade_ConvertCurve3dToBezier.hxx>
#include <ShapeUpgrade_ConvertSurfaceToBezierBasis.hxx>
#include <ShapeUpgrade_EdgeDivide.hxx>
#include <ShapeUpgrade_FaceDivide.hxx>
#include <ShapeUpgrade_FixSmallBezierCurves.hxx>
#include <ShapeUpgrade_FixSmallCurves.hxx>
#include <ShapeUpgrade_WireDivide.hxx>
#include <BRepLib_ValidateEdge.hxx>
#include <ShapeCustom_BSplineRestriction.hxx>
#include <ShapeCustom_ConvertToBSpline.hxx>
#include <ShapeCustom_ConvertToRevolution.hxx>
#include <ShapeUpgrade_SplitSurfaceAngle.hxx>
#include <ShapeUpgrade_SplitSurfaceArea.hxx>
#include <ShapeUpgrade_SplitSurfaceContinuity.hxx>
#include <ShapeExtend_CompositeSurface.hxx>
#include <ShapeFix_ComposeShell.hxx>
#include <ShapeUpgrade_ClosedFaceDivide.hxx>
#include <ShapeUpgrade_ShapeDivideArea.hxx>
#include <ShapeUpgrade_ShellSewing.hxx>
#include <ShapeFix_FaceConnect.hxx>
#include <ShapeFix_FixSmallSolid.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <ShapeFix_SplitCommonVertex.hxx>
#include <ShapeFix_WireVertex.hxx>
#include <ShapeUpgrade_ShapeDivideClosed.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <ShapeFix_Wireframe.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <ShapeAnalysis_WireOrder.hxx>
#include <ShapeFix_FreeBounds.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepLib.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shell.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

#include <BRep_Builder.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom_Surface.hxx>

#include <vector>

// Additional includes gathered from throughout the original file (#1380):
#include <BRepBuilderAPI_NurbsConvert.hxx>
#include <BRepBuilderAPI_FastSewing.hxx>
#include <ShapeUpgrade_RemoveInternalWires.hxx>
#include <ShapeFix_FixSmallFace.hxx>
#include <ShapeUpgrade_RemoveLocations.hxx>
#include <ShapeAnalysis_CheckSmallFace.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <GeomFill_FillingStyle.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomConvert.hxx>
#include <BRepTools_PurgeLocations.hxx>
#include <BOPAlgo_Section.hxx>
#include <BOPAlgo_BuilderFace.hxx>
#include <BOPAlgo_BuilderSolid.hxx>
#include <BOPAlgo_ShellSplitter.hxx>
#include <BOPAlgo_Tools.hxx>
#include <BOPTools_AlgoTools.hxx>
#include <BOPTools_AlgoTools3D.hxx>
#include <IntTools_EdgeEdge.hxx>
#include <IntTools_EdgeFace.hxx>
#include <IntTools_FaceFace.hxx>
#include <IntTools_FClass2d.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_SequenceOfCommonPrts.hxx>
#include <IntTools_Curve.hxx>
#include <IntTools_PntOn2Faces.hxx>
#include <IntTools_SequenceOfCurves.hxx>
#include <IntTools_SequenceOfPntOn2Faces.hxx>
#include <IntTools_Context.hxx>
#include <IntTools_Range.hxx>
#include <BRepTools_Modifier.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_Point.hxx>
#include <Geom2d_Transformation.hxx>
#include <Geom2d_AxisPlacement.hxx>
#include <Geom2d_VectorWithMagnitude.hxx>
#include <Geom2d_Direction.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <LProp_CurAndInf.hxx>
#include <ShapeFix_Solid.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepBndLib.hxx>
#include <Bnd_Box.hxx>
#include <Precision.hxx>
#include <TopoDS_Iterator.hxx>
#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <gp_Pln.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>
#include <gp_Lin.hxx>
#include <gp_Circ.hxx>
#include <gp_Elips.hxx>
#include <ShapeFix_EdgeProjAux.hxx>
#include <ShapeFix_IntersectionTool.hxx>
#include <ShapeExtend_WireData.hxx>
#include <ShapeAnalysis_Edge.hxx>

// Shared private structs/helpers (#1380): every split file gets this identical block,
// compiled independently per TU -- see this split's own README for why.

struct OCCTShellOrientationScan
{
  bool checkResult       = false; // ShapeAnalysis_Shell::CheckOrientedShells' own return value
  bool hasFreeEdges      = false;
  bool hasBadEdges       = false;
  bool hasConnectedEdges = false;
  int  freeEdgeCount     = 0;
};

struct OCCTWireFixer
{
  Handle(ShapeFix_Wire) fixer;
};

struct OCCTFaceFixer
{
  Handle(ShapeFix_Face) fixer;
};

struct OCCTFreeBoundsProps
{
  ShapeAnalysis_FreeBoundsProperties fbp;
  bool                               performed;
};

struct OCCTShapeFixer
{
  Handle(ShapeFix_Shape) fixer;
};

struct OCCTWireAnalyzer
{
  Handle(ShapeAnalysis_Wire) analyzer;

  OCCTWireAnalyzer(const TopoDS_Wire& w, const TopoDS_Face& f, double prec)
  {
    analyzer = new ShapeAnalysis_Wire(w, f, prec);
  }
};

bool occtFillingSupportFaceFromPCurve(const TopoDS_Edge& edge, TopoDS_Face& outFace)
{
  Handle(Geom2d_Curve) pcurve;
  Handle(Geom_Surface) surface;
  TopLoc_Location      location;
  double               first = 0.0, last = 0.0;

  BRep_Tool::CurveOnSurface(edge, pcurve, surface, location, first, last);
  if (pcurve.IsNull() || surface.IsNull())
    return false;

  BRep_Builder builder;
  builder.MakeFace(outFace, surface, location, BRep_Tool::Tolerance(edge));
  // Only useful if the edge really does resolve a pcurve against the face we just built.
  // BRep_Tool matches representations by surface handle and location, so this confirms the
  // synthesized face is the same support the edge already referenced rather than a lookalike.
  double checkFirst = 0.0, checkLast = 0.0;
  return !BRep_Tool::CurveOnSurface(edge, outFace, checkFirst, checkLast).IsNull();
}

int32_t OCCTShapeFaceRestrict(OCCTShapeRef  faceShape,
                              OCCTWireRef*  wires,
                              int32_t       wireCount,
                              OCCTShapeRef* outFaces,
                              int32_t       maxFaces)
{
  if (!faceShape || !wires || wireCount <= 0 || !outFaces || maxFaces <= 0)
    return -1;
  try
  {
    // Get the face from the shape
    TopoDS_Face     face;
    TopExp_Explorer exp(faceShape->shape, TopAbs_FACE);
    if (exp.More())
    {
      face = TopoDS::Face(exp.Current());
    }
    else
    {
      return -1;
    }

    BRepAlgo_FaceRestrictor restrictor;
    restrictor.Init(face, false, true);

    for (int32_t i = 0; i < wireCount; i++)
    {
      if (wires[i])
      {
        TopoDS_Wire w = wires[i]->wire;
        restrictor.Add(w);
      }
    }
    restrictor.Perform();
    if (!restrictor.IsDone())
      return -1;

    int32_t count = 0;
    for (; restrictor.More() && count < maxFaces; restrictor.Next())
    {
      TopoDS_Face resultFace = restrictor.Current();
      outFaces[count]        = new OCCTShape(resultFace);
      count++;
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

OCCTShapeRef _Nullable OCCTShapeBuildEdgeCopy(OCCTShapeRef edgeShape, bool sharePCurves)
{
  if (!edgeShape)
    return nullptr;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge   = TopoDS::Edge(edgeShape->shape);
    TopoDS_Edge     result = sbe.Copy(edge, sharePCurves ? Standard_True : Standard_False);
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

OCCTShapeRef _Nullable OCCTShapeBuildEdgeCopyReplaceVertices(OCCTShapeRef edgeShape,
                                                             OCCTShapeRef vertex1Shape,
                                                             OCCTShapeRef vertex2Shape)
{
  if (!edgeShape)
    return nullptr;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge = TopoDS::Edge(edgeShape->shape);
    TopoDS_Vertex   v1, v2;
    if (vertex1Shape)
      v1 = TopoDS::Vertex(vertex1Shape->shape);
    if (vertex2Shape)
      v2 = TopoDS::Vertex(vertex2Shape->shape);
    TopoDS_Edge result = sbe.CopyReplaceVertices(edge, v1, v2);
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

void OCCTShapeBuildEdgeSetRange3d(OCCTShapeRef edgeShape, double first, double last)
{
  if (!edgeShape)
    return;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge = TopoDS::Edge(edgeShape->shape);
    sbe.SetRange3d(edge, first, last);
    edgeShape->shape = edge;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

bool OCCTShapeBuildEdgeBuildCurve3d(OCCTShapeRef edgeShape)
{
  if (!edgeShape)
    return false;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge = TopoDS::Edge(edgeShape->shape);
    return sbe.BuildCurve3d(edge) ? true : false;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

void OCCTShapeBuildEdgeRemoveCurve3d(OCCTShapeRef edgeShape)
{
  if (!edgeShape)
    return;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge = TopoDS::Edge(edgeShape->shape);
    sbe.RemoveCurve3d(edge);
    edgeShape->shape = edge;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTShapeBuildEdgeCopyRanges(OCCTShapeRef toEdge, OCCTShapeRef fromEdge)
{
  if (!toEdge || !fromEdge)
    return;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     to   = TopoDS::Edge(toEdge->shape);
    TopoDS_Edge     from = TopoDS::Edge(fromEdge->shape);
    sbe.CopyRanges(to, from);
    toEdge->shape = to;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTShapeBuildEdgeCopyPCurves(OCCTShapeRef toEdge, OCCTShapeRef fromEdge)
{
  if (!toEdge || !fromEdge)
    return;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     to   = TopoDS::Edge(toEdge->shape);
    TopoDS_Edge     from = TopoDS::Edge(fromEdge->shape);
    sbe.CopyPCurves(to, from);
    toEdge->shape = to;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTShapeBuildEdgeRemovePCurve(OCCTShapeRef edgeShape, OCCTShapeRef faceShape)
{
  if (!edgeShape || !faceShape)
    return;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge = TopoDS::Edge(edgeShape->shape);
    TopoDS_Face     face = TopoDS::Face(faceShape->shape);
    sbe.RemovePCurve(edge, face);
    edgeShape->shape = edge;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

bool OCCTShapeBuildEdgeReassignPCurve(OCCTShapeRef edgeShape,
                                      OCCTShapeRef oldFaceShape,
                                      OCCTShapeRef newFaceShape)
{
  if (!edgeShape || !oldFaceShape || !newFaceShape)
    return false;
  try
  {
    ShapeBuild_Edge sbe;
    TopoDS_Edge     edge    = TopoDS::Edge(edgeShape->shape);
    TopoDS_Face     oldFace = TopoDS::Face(oldFaceShape->shape);
    TopoDS_Face     newFace = TopoDS::Face(newFaceShape->shape);
    return sbe.ReassignPCurve(edge, oldFace, newFace) ? true : false;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

void OCCTEdgeSetSameParameter(OCCTEdgeRef edge, bool sameParameter)
{
  if (!occtShapeIsPresent(edge))
    return;
  try
  {
    BRep_Builder().SameParameter(edge->edge, sameParameter);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

OCCTShapeRef _Nullable OCCTShapeBuildVertexCombine(OCCTShapeRef v1Shape,
                                                   OCCTShapeRef v2Shape,
                                                   double       tolFactor)
{
  if (!v1Shape || !v2Shape)
    return nullptr;
  try
  {
    ShapeBuild_Vertex sbv;
    TopoDS_Vertex     v1     = TopoDS::Vertex(v1Shape->shape);
    TopoDS_Vertex     v2     = TopoDS::Vertex(v2Shape->shape);
    TopoDS_Vertex     result = sbv.CombineVertex(v1, v2, tolFactor);
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

OCCTShapeRef _Nullable OCCTShapeBuildVertexCombineFromPoints(double x1,
                                                             double y1,
                                                             double z1,
                                                             double tol1,
                                                             double x2,
                                                             double y2,
                                                             double z2,
                                                             double tol2,
                                                             double tolFactor)
{
  try
  {
    ShapeBuild_Vertex sbv;
    TopoDS_Vertex     result =
      sbv.CombineVertex(gp_Pnt(x1, y1, z1), gp_Pnt(x2, y2, z2), tol1, tol2, tolFactor);
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

OCCTShapeRef _Nullable OCCTShapeExtendSortedCompound(OCCTShapeRef shape,
                                                     int32_t      shapeType,
                                                     bool         explore)
{
  if (!shape)
    return nullptr;
  try
  {
    ShapeExtend_Explorer explorer;
    TopoDS_Shape         result = explorer.SortedCompound(shape->shape,
                                                          (TopAbs_ShapeEnum)shapeType,
                                                          explore ? Standard_True : Standard_False,
                                                          Standard_True);
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

int32_t OCCTShapeExtendShapeType(OCCTShapeRef shape, bool compound)
{
  // #844 left this fallback as `7` (TopAbs_VERTEX, a real, legitimate case) though the comment
  // on this line at the time said TopAbs_SHAPE (8) -- so a null shape or a caught exception
  // silently decoded as ".vertex" in predominantShapeType() (Shape+ShapeHealing.swift) rather
  // than signaling failure. Fixed (PR #870 aggregate review): -1, matching ShapeType's own
  // `.unknown = -1` decode-failure sentinel -- predominantShapeType()'s
  // `ShapeFilterType(rawValue: Int(raw)) ?? .compound` decodes -1 to `.unknown` directly (a
  // defined case, so the `?? .compound` fallback never fires for this), rather than falling
  // through to a plausible-looking real answer. See Issue870ShapeExtendShapeTypeFailureTests.
  if (!shape)
    return -1; // ShapeType.unknown
  try
  {
    ShapeExtend_Explorer explorer;
    return (int32_t)explorer.ShapeType(shape->shape, compound ? Standard_True : Standard_False);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  } // ShapeType.unknown
}

OCCTValidateEdgeResult OCCTValidateEdge(OCCTEdgeRef _Nonnull edge,
                                        OCCTFaceRef _Nonnull face,
                                        double tolerance)
{
  OCCTValidateEdgeResult result = {};
  if (!occtShapeIsPresent(edge) || !occtShapeIsPresent(face))
    return result;
  try
  {
    TopoDS_Edge e = TopoDS::Edge(edge->edge);
    TopoDS_Face f = TopoDS::Face(face->face);

    Handle(BRepAdaptor_Curve) curve3d = new BRepAdaptor_Curve(e);

    double               first, last;
    Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(e, f, first, last);
    if (pcurve.IsNull())
      return result;

    Handle(BRepAdaptor_Surface)      brepSurf    = new BRepAdaptor_Surface(f);
    Handle(Geom2dAdaptor_Curve)      gac2d       = new Geom2dAdaptor_Curve(pcurve, first, last);
    Handle(Adaptor3d_CurveOnSurface) curveOnSurf = new Adaptor3d_CurveOnSurface(gac2d, brepSurf);

    // theSameParameter is the edge's own OCCT-tracked SameParameter state, not a mode flag the
    // caller picks: BRepLib_ValidateEdge::processApprox() uses it to decide whether the naive
    // same-t point comparison is valid, and every real OCCT caller (BRepCheck_Edge,
    // ShapeAnalysis_Edge::CheckSameParameter) passes the edge's real flag (#1461).
    BRepLib_ValidateEdge validator(curve3d, curveOnSurf, BRep_Tool::SameParameter(e));
    validator.Process();

    result.isDone = validator.IsDone();
    if (result.isDone)
    {
      result.maxDistance       = validator.GetMaxDistance();
      result.tolerance         = tolerance;
      result.isWithinTolerance = validator.CheckTolerance(tolerance);
    }
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
  return result;
}

int32_t OCCTShapeFaceRestrictAlgo(OCCTShapeRef  shape,
                                  int32_t       faceIndex,
                                  OCCTShapeRef* outFaces,
                                  int32_t       maxFaces)
{
  if (!shape)
    return -1;
  try
  {
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return -1;

    BRepAlgo_FaceRestrictor restrictor;
    restrictor.Init(face, false, true);

    TopExp_Explorer wireExp(face, TopAbs_WIRE);
    for (; wireExp.More(); wireExp.Next())
    {
      TopoDS_Wire w = TopoDS::Wire(wireExp.Current());
      restrictor.Add(w);
    }

    restrictor.Perform();
    if (!restrictor.IsDone())
      return -1;

    int count = 0;
    for (; restrictor.More() && count < maxFaces; restrictor.Next())
    {
      if (outFaces)
      {
        OCCTShape* result = new OCCTShape();
        result->shape     = restrictor.Current();
        outFaces[count]   = result;
      }
      count++;
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return -1;
  }
}

bool OCCTShapeFixIntersectingWires(OCCTShapeRef shape, int32_t faceIndex, double precision)
{
  if (!shape)
    return false;
  try
  {
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return false;

    Handle(ShapeBuild_ReShape) ctx = new ShapeBuild_ReShape();
    ShapeFix_IntersectionTool  tool(ctx, precision, 1.0);
    bool                       done = tool.FixIntersectingWires(face);
    // FixIntersectingWires records its substitutions on ctx (and, on success, reassigns its
    // by-reference `face` parameter to a brand-new TopoDS_Face) but never mutates shape->shape
    // itself -- ctx->Apply() is what actually rebuilds the shape from the accumulated
    // Replace() map. Without this, the function always reported `true` with no observable
    // change (#1461).
    if (done)
      shape->shape = ctx->Apply(shape->shape);
    return done;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}
