//
//  OCCTBridge_Healing_Blends.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Healing.mm (#1380): ChFi2d/ChFi3d/BRepFilletAPI edge blends (variable
//  fillet, 2D wire fillet/chamfer). Public C surface unchanged; every sibling file imports the same
//  headers this one does (the shared preamble below). No symbol changes, pure file move -- see
//  Scripts/repro/396-bridge-mm-split/ for how.
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
#include <BRepTools_WireExplorer.hxx>

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

// The single-edge member of the radius-law pair, sharing occtFilletAddEdges (the edge lookup and
// its bounds check) and occtFilletSetRadiusProfile (the law itself) with OCCTShapeFilletEvolving in
// OCCTBridge_Modeling.mm. See OCCTBridge_Internal.h for what OCCT does with a profile.
//
// This used to map each relative parameter onto the edge's own curve parameter range and pass the
// result to SetRadius(radii[i], param, 1). BRepFilletAPI_MakeFillet has no (Real, Real, Integer)
// overload: `param` was truncated to an int and taken as the *contour* index, so the profile was
// never applied. What the caller got was a constant radius, whichever profile point happened to
// truncate to a live contour index, and, for any edge whose parameter range does not start at 0,
// no radius at all, which SIGSEGVs in Build(). Both measured in
// Scripts/repro/520-fillet-edge-index-contracts/. #520
OCCTShapeRef OCCTShapeFilletVariable(OCCTShapeRef  shape,
                                     int32_t       edgeIndex,
                                     const double* radii,
                                     const double* params,
                                     int32_t       count)
{
  if (!shape || !radii || !params || count < 2)
    return nullptr;

  try
  {
    BRepFilletAPI_MakeFillet fillet(shape->shape);
    TopoDS_Edge              added;
    if (!occtFilletAddEdges(
          fillet,
          shape->shape,
          &edgeIndex,
          1,
          [&added](BRepFilletAPI_MakeFillet& f, const TopoDS_Edge& edge, int32_t) {
            f.Add(edge); // the radius-law overload: the profile below supplies the radius
            added = edge;
            return true;
          }))
      return nullptr;

    // #612: the profile goes to this edge's own slot in this edge's own contour. One edge is
    // added, so the contour index agreed with NbContours() whenever there was one at all, but
    // when OCCT *declines* the edge (a free-boundary edge of an open shell) NbContours() is 0,
    // and SetRadius(law, 0, 1) is the unchecked low side #505 measured: it used to SIGSEGV,
    // uncatchably, rather than fail. Resolving the slot returns no slot instead, and the empty
    // fillet then fails in Build().
    if (!occtFilletSetRadiusProfile(fillet, added, count, [radii, params](int32_t i) {
          return gp_Pnt2d(params[i], radii[i]);
        }))
      return nullptr;

    fillet.Build();
    if (!fillet.IsDone())
      return nullptr;

    TopoDS_Shape result = fillet.Shape();
    if (!occtBlendResultIsValid(result)) // #3200
      return nullptr;

    return new OCCTShape(result);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTWireRef OCCTWireFillet2D(OCCTWireRef wire, int32_t vertexIndex, double radius)
{
  if (!wire || radius <= 0 || vertexIndex < 0)
    return nullptr;

  try
  {
    // Create a face from the wire for 2D operations
    BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face face = makeFace.Face();

    // Get vertex at index
    TopTools_IndexedMapOfShape vertexMap;
    TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

    if (vertexIndex >= vertexMap.Extent())
      return nullptr;

    TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(vertexIndex + 1));

    // Use ChFi2d_Builder for 2D fillet on face
    ChFi2d_Builder fillet2d(face);
    TopoDS_Edge    filletEdge = fillet2d.AddFillet(vertex, radius);

    if (filletEdge.IsNull())
      return nullptr;
    if (fillet2d.Status() != ChFi2d_IsDone)
      return nullptr;

    // Get the modified face and extract its outer wire
    TopoDS_Face resultFace = TopoDS::Face(fillet2d.Result());
    if (resultFace.IsNull())
      return nullptr;

    TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
    if (outerWire.IsNull())
      return nullptr;

    return new OCCTWire(outerWire);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTWireRef OCCTWireFilletAll2D(OCCTWireRef wire, double radius)
{
  if (!wire || radius <= 0)
    return nullptr;

  try
  {
    // Create a face from the wire
    BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face face = makeFace.Face();

    // Get all vertices
    TopTools_IndexedMapOfShape vertexMap;
    TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

    if (vertexMap.Extent() < 2)
      return nullptr;

    // Use ChFi2d_Builder to fillet all vertices
    ChFi2d_Builder fillet2d(face);

    // Add fillet to each vertex. #1478: track failure across the whole loop rather than
    // reading Status() once after it -- ChFi2d_Builder::status is a single field overwritten
    // by every AddFillet call, so a single post-loop read only reflects the LAST call and can
    // miss a mid-loop failure masked by a later success.
    bool anyFailed = false;
    for (int v = 1; v <= vertexMap.Extent(); v++)
    {
      TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(v));
      fillet2d.AddFillet(vertex, radius);
      if (fillet2d.Status() != ChFi2d_IsDone)
        anyFailed = true;
    }

    if (anyFailed)
    {
      // Some vertices might not be fillettable; return original
      return new OCCTWire(wire->wire);
    }

    // Get the modified face and extract its outer wire
    TopoDS_Face resultFace = TopoDS::Face(fillet2d.Result());
    if (resultFace.IsNull())
      return nullptr;

    TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
    if (outerWire.IsNull())
      return nullptr;

    return new OCCTWire(outerWire);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTWireRef OCCTWireChamfer2D(OCCTWireRef wire, int32_t vertexIndex, double dist1, double dist2)
{
  if (!wire || dist1 <= 0 || dist2 <= 0 || vertexIndex < 0)
    return nullptr;

  try
  {
    // Create face from wire
    BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face face = makeFace.Face();

    // Get edges and vertices
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(wire->wire, TopAbs_EDGE, edgeMap);

    TopTools_IndexedMapOfShape vertexMap;
    TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

    if (vertexIndex >= vertexMap.Extent())
      return nullptr;

    TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(vertexIndex + 1));

    // Find edges sharing this vertex
    TopoDS_Edge edge1, edge2;
    for (int i = 1; i <= edgeMap.Extent(); i++)
    {
      TopoDS_Edge   edge = TopoDS::Edge(edgeMap(i));
      TopoDS_Vertex v1, v2;
      TopExp::Vertices(edge, v1, v2);
      if (v1.IsSame(vertex) || v2.IsSame(vertex))
      {
        if (edge1.IsNull())
        {
          edge1 = edge;
        }
        else
        {
          edge2 = edge;
          break;
        }
      }
    }

    if (edge1.IsNull() || edge2.IsNull())
      return nullptr;

    // Use ChFi2d_Builder for 2D chamfer
    ChFi2d_Builder chamfer2d(face);
    TopoDS_Edge    chamferEdge = chamfer2d.AddChamfer(edge1, edge2, dist1, dist2);

    if (chamferEdge.IsNull())
      return nullptr;
    if (chamfer2d.Status() != ChFi2d_IsDone)
      return nullptr;

    // Get the modified face and extract its outer wire
    TopoDS_Face resultFace = TopoDS::Face(chamfer2d.Result());
    if (resultFace.IsNull())
      return nullptr;

    TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
    if (outerWire.IsNull())
      return nullptr;

    return new OCCTWire(outerWire);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTWireRef OCCTWireChamferAll2D(OCCTWireRef wire, double distance)
{
  if (!wire || distance <= 0)
    return nullptr;

  try
  {
    // Create face from wire
    BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
    if (!makeFace.IsDone())
      return nullptr;
    TopoDS_Face face = makeFace.Face();

    // Walk the wire in true connection order (#1478): TopExp::MapShapes returns stored
    // sub-shape order, not connection order, so pairing consecutive map indices can pair
    // edges that are not actually adjacent. BRepTools_WireExplorer walks the wire the way
    // every other adjacency-pairing site in this bridge already does, so consecutive edges
    // from it are adjacent by construction and need no separate shared-vertex check.
    std::vector<TopoDS_Edge> edges;
    for (BRepTools_WireExplorer explorer(wire->wire); explorer.More(); explorer.Next())
    {
      edges.push_back(explorer.Current());
    }

    if (edges.size() < 2)
      return nullptr;

    // Use ChFi2d_Builder for 2D chamfers
    ChFi2d_Builder chamfer2d(face);

    // For each pair of adjacent edges, add chamfer. #1478: track failure across the whole
    // loop rather than reading Status() once after it -- ChFi2d_Builder::status is a single
    // field overwritten by every AddChamfer call, so a single post-loop read only reflects
    // the LAST call and can miss a mid-loop failure masked by a later success.
    bool anyFailed = false;
    for (size_t i = 0; i < edges.size(); i++)
    {
      const TopoDS_Edge& edge1 = edges[i];
      const TopoDS_Edge& edge2 = edges[(i + 1) % edges.size()];

      chamfer2d.AddChamfer(edge1, edge2, distance, distance);
      if (chamfer2d.Status() != ChFi2d_IsDone)
        anyFailed = true;
    }

    if (anyFailed)
    {
      // Some edges might not be chamferable; return original
      return new OCCTWire(wire->wire);
    }

    // Get the modified face and extract its outer wire
    TopoDS_Face resultFace = TopoDS::Face(chamfer2d.Result());
    if (resultFace.IsNull())
      return nullptr;

    TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
    if (outerWire.IsNull())
      return nullptr;

    return new OCCTWire(outerWire);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

// Shares occtShapeFilletEdgeList (OCCTBridge_Internal.h) with OCCTShapeFilletEdges and
// OCCTShapeFilletEdgesLinear in OCCTBridge_Modeling.mm, supplying only the per-edge radius.
// This is the entry point that had no radius precondition at all; see that helper. #489
//
// #633: `declinedEdgeIndices`/`outDeclinedCount` report which of `edgeIndices` OCCT declined
// (occtFilletWriteDeclined), the same contract #639 gave the other three edge-list entry points.
// Both are nullable and the existing skip behaviour is unchanged when they are null.
OCCTShapeRef OCCTShapeBlendEdges(OCCTShapeRef   shape,
                                 const int32_t* edgeIndices,
                                 const double*  radii,
                                 int32_t        count,
                                 int32_t*       declinedEdgeIndices,
                                 int32_t*       outDeclinedCount)
{
  if (outDeclinedCount)
    *outDeclinedCount = 0;
  if (!occtValidFilletRadii(radii, count))
    return nullptr;

  return occtShapeFilletEdgeList(
    shape,
    edgeIndices,
    count,
    [radii](BRepFilletAPI_MakeFillet& fillet, const TopoDS_Edge& edge, int32_t entry) {
      fillet.Add(radii[entry], edge);
      return true;
    },
    declinedEdgeIndices,
    outDeclinedCount);
}
