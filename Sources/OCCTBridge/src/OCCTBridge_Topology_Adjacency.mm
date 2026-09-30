//
//  OCCTBridge_Topology_Adjacency.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Topology.mm (#1380): BRepTools (WireExplorer, ReShape, Substitution,
//  Adjacency), TopLoc. Public C surface unchanged; every sibling file imports the same headers this
//  one does (the shared preamble below). No symbol changes, pure file move -- see
//  Scripts/repro/396-bridge-mm-split/ for how.
//

//
//  OCCTBridge_Topology.mm
//  OCCTSwift
//
//  Per-OCCT-module TU for topology traversal + classification:
//
//  - TopExp_*, TopTools_*, TopoDS_*, TopAbs_*
//  - BRepTools_WireExplorer (ordered wire-edge iteration)
//  - BRepTools_ReShape (sub-shape replacement / removal)
//  - BRepClass / BRepClass3d (point-in-shape classification)
//  - BRepBndLib + Bnd_OBB (oriented bounding box)
//  - ShapeAnalysis_ShapeContents (sub-shape census)
//  - BRepLib_FindSurface (planar surface from edge group)
//  - BRepGProp helpers when not delegated to Properties
//
//  Public C surface unchanged. No symbol changes, a pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

#include <limits>

#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepGProp.hxx>
#include <IntCurvesFace_Intersector.hxx>
#include <IntCurvesFace_ShapeIntersector.hxx>
#include <TopCnx_EdgeFaceTransition.hxx>
#include <TopTrans_SurfaceTransition.hxx>
#include <BRepIntCurveSurface_Inter.hxx>
#include <BRepTools.hxx>
#include <BRepLib.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeShell.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <BRepExtrema_DistanceSS.hxx>
#include <BRepExtrema_SolutionElem.hxx>
#include <BRepLib_FindSurface.hxx>
#include <BRepTools_ReShape.hxx>
#include <BRepTools_WireExplorer.hxx>

#include <Bnd_Box.hxx>
#include <Bnd_OBB.hxx>

#include <Geom_Plane.hxx>

#include <GCPnts_TangentialDeflection.hxx>
#include <GProp_GProps.hxx>

#include <ShapeAnalysis_ShapeContents.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeExtend_WireData.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <GProp_PrincipalProps.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepExtrema_ExtCC.hxx>
#include <BRepExtrema_ExtCF.hxx>
#include <BRepExtrema_ExtFF.hxx>
#include <BRepExtrema_ExtPC.hxx>
#include <BRepExtrema_ExtPF.hxx>
#include <BRepExtrema_Poly.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffset_Analyse.hxx>
#include <BRepOffset_Interval.hxx>
#include <ChFiDS_TypeOfConcavity.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <GeomConvert_BSplineCurveKnotSplitting.hxx>

#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_XYZ.hxx>

#include <TopAbs.hxx>
#include <TopAbs_State.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

#include <algorithm>

// MARK: - Wire Explorer (v0.29.0)

// Additional includes gathered from throughout the original file (#1380):
#include <ShapeAnalysis_Edge.hxx>
#include <BRepOffsetAPI_FindContigousEdges.hxx>
#include <BRepClass3d.hxx>
#include <TopoDS_Solid.hxx>
#include <TopoDS_Shell.hxx>
#include <BRepBuilderAPI_FindPlane.hxx>
#include <ShapeUpgrade_ShapeDivideClosedEdges.hxx>
#include <ShapeCustom.hxx>
#include <BRepAlgo_FaceRestrictor.hxx>
#include <BRepClass_FaceExplorer.hxx>
#include <BRepClass_FClassifier.hxx>
#include <Bnd_BoundSortBox.hxx>
#include <BRepTools_Substitution.hxx>
#include <BRepLib_MakeVertex.hxx>
#include <TopoDS_Builder.hxx>
#include <TopoDS_CompSolid.hxx>
#import <Geom2d_Curve.hxx>
#include <BRepLProp_SLProps.hxx>
#include <GeomAbs_SurfaceType.hxx>

// Shared private structs/helpers (#1380): every split file gets this identical block,
// compiled independently per TU -- see this split's own README for why.

// Shared by every OCCTShapeFindSurface*/OCCTFindSurface* entry point below (#838): each used to
// independently construct its own BRepLib_FindSurface, guard, try/catch and accessor reads for
// what is logically one query. This runs the finder once; `want` selects which single accessor
// this caller needs: Surface() for the three surface-returning entry points
// (OCCTShapeFindSurface/Ex, OCCTFindSurface), ToleranceReached() for OCCTFindSurfaceTolerance, or
// Existed() for OCCTFindSurfaceExisted, so a caller never invokes an accessor its own contract
// doesn't promise, matching the pre-consolidation code (each hand-written body called only the
// one accessor it needed). PR #870 aggregate review: an earlier version of this consolidation
// grouped ToleranceReached()+Existed() under one `wantSurface=false` branch and always computed
// both, even though OCCTFindSurfaceTolerance/OCCTFindSurfaceExisted each only ever consume one:
// real, if cheap today, extra OCCT-object introspection neither pre-consolidation function
// performed. Splitting `wantSurface` into this 3-way selector removes that: each of the three
// `want` values computes exactly the one accessor its caller reads. (PR #866 review, still
// honored: each requested accessor gets its own try/catch, so one accessor throwing can't discard
// a sibling result the same call also asked for.) Also fixes a real asymmetry the consolidation
// surfaced: OCCTFindSurface/OCCTFindSurfaceTolerance/OCCTFindSurfaceExisted previously had no
// null-shape guard at all (relying solely on the header's `_Nonnull`), unlike
// OCCTShapeFindSurface/Ex; not reachable from Swift today (`Shape.handle` is non-optional), so
// this is a hardening, not an observable behavior change.
enum class OCCTFindSurfaceWant
{
  Surface,
  Tolerance,
  Existed
};

struct OCCTFindSurfaceResult
{
  bool                 found = false;
  Handle(Geom_Surface) surface;
  double               toleranceReached = -1.0;
  bool                 existed          = false;
};

// MARK: - BRepIntCurveSurface_Inter (v0.74)
struct OCCTCurveSurfaceInter
{
  BRepIntCurveSurface_Inter inter;
};

struct OCCTOBB
{
  Bnd_OBB obb;
};

struct OCCTBoundSortBox
{
  Bnd_BoundSortBox                     sorter;
  Handle(NCollection_HArray1<Bnd_Box>) boxes;
};

struct OCCTReShape
{
  Handle(BRepTools_ReShape) rs;

  OCCTReShape()
      : rs(new BRepTools_ReShape())
  {
  }
};

struct OCCTDistSS
{
  BRepExtrema_DistShapeShape dist;
};

int32_t OCCTWireExplorerEdgeCount(OCCTWireRef wire)
{
  if (!wire)
    return 0;
  try
  {
    int32_t count = 0;
    for (BRepTools_WireExplorer exp(wire->wire); exp.More(); exp.Next())
    {
      count++;
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

bool OCCTWireExplorerGetEdge(OCCTWireRef wire,
                             int32_t     index,
                             double*     outPoints,
                             int32_t     maxPoints,
                             int32_t*    outPointCount)
{
  if (!wire || !outPoints || !outPointCount || maxPoints <= 0 || index < 0)
    return false;
  try
  {
    int32_t current = 0;
    for (BRepTools_WireExplorer exp(wire->wire); exp.More(); exp.Next())
    {
      if (current == index)
      {
        TopoDS_Edge                 edge = exp.Current();
        BRepAdaptor_Curve           curve(edge);
        GCPnts_TangentialDeflection discretizer(curve, 0.01, 0.1);
        int32_t                     numPoints = std::min(discretizer.NbPoints(), maxPoints);
        for (int32_t i = 0; i < numPoints; i++)
        {
          gp_Pnt pt            = discretizer.Value(i + 1);
          outPoints[i * 3]     = pt.X();
          outPoints[i * 3 + 1] = pt.Y();
          outPoints[i * 3 + 2] = pt.Z();
        }
        *outPointCount = numPoints;
        return true;
      }
      current++;
    }
    return false;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

int32_t OCCTWireExplorerGetEdgePointCount(OCCTWireRef wire, int32_t index)
{
  if (!wire || index < 0)
    return 0;
  try
  {
    int32_t current = 0;
    for (BRepTools_WireExplorer exp(wire->wire); exp.More(); exp.Next())
    {
      if (current == index)
      {
        TopoDS_Edge                 edge = exp.Current();
        BRepAdaptor_Curve           curve(edge);
        GCPnts_TangentialDeflection discretizer(curve, 0.01, 0.1);
        return discretizer.NbPoints();
      }
      current++;
    }
    return 0;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

OCCTShapeRef OCCTShapeReplaceSubShape(OCCTShapeRef shape, OCCTShapeRef oldSub, OCCTShapeRef newSub)
{
  if (!shape || !oldSub || !newSub)
    return nullptr;
  try
  {
    Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
    reshaper->Replace(oldSub->shape, newSub->shape);
    TopoDS_Shape result = reshaper->Apply(shape->shape);
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

OCCTShapeRef OCCTShapeRemoveSubShape(OCCTShapeRef shape, OCCTShapeRef subToRemove)
{
  if (!shape || !subToRemove)
    return nullptr;
  try
  {
    Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
    reshaper->Remove(subToRemove->shape);
    TopoDS_Shape result = reshaper->Apply(shape->shape);
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

int32_t OCCTShapeFindContiguousEdges(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return 0;
  try
  {
    BRepOffsetAPI_FindContigousEdges finder(tolerance);
    finder.Add(shape->shape);
    finder.Perform();
    return finder.NbContigousEdges();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

OCCTShapeRef OCCTShapeRemoveSubShapes(OCCTShapeRef shape, OCCTShapeRef* subShapes, int32_t count)
{
  if (!shape || !subShapes || count <= 0)
    return nullptr;
  try
  {
    Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
    for (int32_t i = 0; i < count; i++)
    {
      if (subShapes[i])
      {
        reshaper->Remove(subShapes[i]->shape);
      }
    }
    TopoDS_Shape result = reshaper->Apply(shape->shape);
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

OCCTShapeRef OCCTShapeReplaceSubShapes(OCCTShapeRef  shape,
                                       OCCTShapeRef* oldShapes,
                                       OCCTShapeRef* newShapes,
                                       int32_t       count)
{
  if (!shape || !oldShapes || !newShapes || count <= 0)
    return nullptr;
  try
  {
    Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
    for (int32_t i = 0; i < count; i++)
    {
      if (oldShapes[i] && newShapes[i])
      {
        reshaper->Replace(oldShapes[i]->shape, newShapes[i]->shape);
      }
    }
    TopoDS_Shape result = reshaper->Apply(shape->shape);
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

int32_t OCCTShapeGetSubShapeCount(OCCTShapeRef shape, int32_t type)
{
  if (!shape)
    return 0;
  try
  {
    TopTools_IndexedMapOfShape map;
    return occtMapSubShapes(shape->shape, type, map);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTShapeGetSubShapes(OCCTShapeRef  shape,
                              int32_t       type,
                              OCCTShapeRef* outSubShapes,
                              int32_t       maxCount)
{
  if (!shape || !outSubShapes || maxCount <= 0)
    return 0;
  try
  {
    TopTools_IndexedMapOfShape map;
    int32_t                    total = occtMapSubShapes(shape->shape, type, map);
    int32_t                    count = total < maxCount ? total : maxCount;
    for (int32_t i = 0; i < count; i++)
    {
      outSubShapes[i] = new OCCTShape(map(i + 1)); // OCCT's indexed maps are 1-based
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

OCCTShapeRef OCCTShapeGetSubShapeByTypeIndex(OCCTShapeRef shape, int32_t type, int32_t index)
{
  if (!shape)
    return nullptr;
  try
  {
    TopoDS_Shape sub = occtSubShapeAt(shape->shape, type, index);
    if (sub.IsNull())
      return nullptr;
    return new OCCTShape(sub);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

int32_t OCCTEdgeFaceAdjacency(OCCTShapeRef shape, int32_t* adjacentFaceCounts)
{
  if (!shape)
    return 0;
  try
  {
    NCollection_IndexedDataMap<TopoDS_Shape, TopTools_ListOfShape, TopTools_ShapeMapHasher> map;
    TopExp::MapShapesAndUniqueAncestors(shape->shape, TopAbs_EDGE, TopAbs_FACE, map);
    int32_t count = (int32_t)map.Extent();
    if (adjacentFaceCounts)
    {
      for (int i = 1; i <= count; i++)
      {
        adjacentFaceCounts[i - 1] = (int32_t)map(i).Extent();
      }
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTVertexEdgeAdjacency(OCCTShapeRef shape, int32_t* adjacentEdgeCounts)
{
  if (!shape)
    return 0;
  try
  {
    NCollection_IndexedDataMap<TopoDS_Shape, TopTools_ListOfShape, TopTools_ShapeMapHasher> map;
    TopExp::MapShapesAndUniqueAncestors(shape->shape, TopAbs_VERTEX, TopAbs_EDGE, map);
    int32_t count = (int32_t)map.Extent();
    if (adjacentEdgeCounts)
    {
      for (int i = 1; i <= count; i++)
      {
        adjacentEdgeCounts[i - 1] = (int32_t)map(i).Extent();
      }
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTEdgeAdjacentFaces(OCCTShapeRef shape,
                              OCCTShapeRef edge,
                              int32_t*     faceIndices,
                              int32_t      maxFaces)
{
  if (!shape || !edge || !faceIndices || maxFaces <= 0)
    return 0;
  try
  {
    NCollection_IndexedDataMap<TopoDS_Shape, TopTools_ListOfShape, TopTools_ShapeMapHasher> map;
    TopExp::MapShapesAndUniqueAncestors(shape->shape, TopAbs_EDGE, TopAbs_FACE, map);
    // Find the edge in the map
    TopoDS_Edge e       = TopoDS::Edge(edge->shape);
    int         edgeIdx = map.FindIndex(e);
    if (edgeIdx == 0)
      return 0;
    // Build face index map for lookup
    NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> faceMap;
    TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
    const TopTools_ListOfShape& faces = map(edgeIdx);
    int32_t                     count = 0;
    for (auto it = faces.cbegin(); it != faces.cend() && count < maxFaces; ++it)
    {
      int fi = faceMap.FindIndex(*it);
      // #541: FindIndex is 1-based; these indices address the same enumeration
      // OCCTShapeGetFaceAtIndex reads 0-based, so they are reported 0-based too.
      if (fi > 0)
        faceIndices[count++] = (int32_t)(fi - 1);
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTVertexAdjacentEdges(OCCTShapeRef shape,
                                OCCTShapeRef vertex,
                                int32_t*     edgeIndices,
                                int32_t      maxEdges)
{
  if (!shape || !vertex || !edgeIndices || maxEdges <= 0)
    return 0;
  try
  {
    NCollection_IndexedDataMap<TopoDS_Shape, TopTools_ListOfShape, TopTools_ShapeMapHasher> map;
    TopExp::MapShapesAndUniqueAncestors(shape->shape, TopAbs_VERTEX, TopAbs_EDGE, map);
    TopoDS_Vertex v       = TopoDS::Vertex(vertex->shape);
    int           vertIdx = map.FindIndex(v);
    if (vertIdx == 0)
      return 0;
    NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> edgeMap;
    TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
    const TopTools_ListOfShape& edges = map(vertIdx);
    int32_t                     count = 0;
    for (auto it = edges.cbegin(); it != edges.cend() && count < maxEdges; ++it)
    {
      int ei = edgeMap.FindIndex(*it);
      // #541: 0-based, matching OCCTShapeGetEdgeAtIndex. See OCCTEdgeAdjacentFaces.
      if (ei > 0)
        edgeIndices[count++] = (int32_t)(ei - 1);
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTWireExplorerOrientations(OCCTShapeRef wire, OCCTShapeRef face, int32_t* orientations)
{
  if (!wire)
    return 0;
  try
  {
    TopoDS_Wire            w = TopoDS::Wire(wire->shape);
    BRepTools_WireExplorer we;
    if (face)
    {
      TopoDS_Face f = TopoDS::Face(face->shape);
      we.Init(w, f);
    }
    else
    {
      we.Init(w);
    }
    int32_t count = 0;
    while (we.More())
    {
      if (orientations)
      {
        orientations[count] = (int32_t)we.Orientation();
      }
      count++;
      we.Next();
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTWireExplorerVertices(OCCTShapeRef wire,
                                 OCCTShapeRef face,
                                 double*      xs,
                                 double*      ys,
                                 double*      zs)
{
  if (!wire)
    return 0;
  try
  {
    TopoDS_Wire            w = TopoDS::Wire(wire->shape);
    BRepTools_WireExplorer we;
    if (face)
    {
      TopoDS_Face f = TopoDS::Face(face->shape);
      we.Init(w, f);
    }
    else
    {
      we.Init(w);
    }
    int32_t count = 0;
    while (we.More())
    {
      if (xs)
      {
        TopoDS_Vertex v = we.CurrentVertex();
        if (!v.IsNull())
        {
          gp_Pnt p  = BRep_Tool::Pnt(v);
          xs[count] = p.X();
          ys[count] = p.Y();
          zs[count] = p.Z();
        }
      }
      count++;
      we.Next();
    }
    return count;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

OCCTReShapeRef OCCTReShapeCreate(void)
{
  return new OCCTReShape();
}

void OCCTReShapeRelease(OCCTReShapeRef rs)
{
  delete rs;
}

void OCCTReShapeClear(OCCTReShapeRef rs)
{
  if (!rs)
    return;
  try
  {
    rs->rs->Clear();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTReShapeRemove(OCCTReShapeRef rs, OCCTShapeRef shape)
{
  if (!rs || !shape)
    return;
  try
  {
    rs->rs->Remove(shape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTReShapeReplace(OCCTReShapeRef rs, OCCTShapeRef oldShape, OCCTShapeRef newShape)
{
  if (!rs || !oldShape || !newShape)
    return;
  try
  {
    rs->rs->Replace(oldShape->shape, newShape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

bool OCCTReShapeIsRecorded(OCCTReShapeRef rs, OCCTShapeRef shape)
{
  if (!rs || !shape)
    return false;
  try
  {
    return rs->rs->IsRecorded(shape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

OCCTShapeRef OCCTReShapeApply(OCCTReShapeRef rs, OCCTShapeRef shape)
{
  if (!rs || !shape)
    return nullptr;
  try
  {
    TopoDS_Shape result = rs->rs->Apply(shape->shape);
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

OCCTShapeRef OCCTReShapeValue(OCCTReShapeRef rs, OCCTShapeRef shape)
{
  if (!rs || !shape)
    return nullptr;
  try
  {
    TopoDS_Shape result = rs->rs->Value(shape->shape);
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

OCCTShapeRef OCCTShapeSubstitute(OCCTShapeRef  shape,
                                 OCCTShapeRef  oldSub,
                                 OCCTShapeRef* newSubs,
                                 int32_t       newCount)
{
  if (!shape || !oldSub)
    return nullptr;
  try
  {
    BRepTools_Substitution         sub;
    NCollection_List<TopoDS_Shape> newList;
    if (newSubs && newCount > 0)
    {
      for (int32_t i = 0; i < newCount; i++)
      {
        if (newSubs[i])
          newList.Append(newSubs[i]->shape);
      }
    }
    sub.Substitute(oldSub->shape, newList);
    sub.Build(shape->shape);
    if (!sub.IsCopied(shape->shape))
      return nullptr;
    const NCollection_List<TopoDS_Shape>& copies = sub.Copy(shape->shape);
    if (copies.IsEmpty())
      return nullptr;
    return new OCCTShape(copies.First());
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

bool OCCTSubstitutionIsCopied(OCCTShapeRef shape, OCCTShapeRef subshape)
{
  if (!shape || !subshape)
    return false;
  try
  {
    BRepTools_Substitution         sub;
    NCollection_List<TopoDS_Shape> empty;
    sub.Substitute(subshape->shape, empty);
    sub.Build(shape->shape);
    return sub.IsCopied(shape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

OCCTShapeRef OCCTShapeLocated(OCCTShapeRef shape, const double* matrix12)
{
  if (!shape)
    return nullptr;
  try
  {
    TopLoc_Location loc    = occtLocationFromMatrix12Interleaved(matrix12);
    OCCTShape*      result = new OCCTShape();
    result->shape          = shape->shape.Located(loc);
    return result;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

// A second spelling of OCCTShapeGetSubShapeCount, kept for its Swift callers; the count itself is
// computed in exactly one place (#502).
int32_t OCCTShapeUniqueSubShapeCount(OCCTShapeRef shape, int32_t type)
{
  return OCCTShapeGetSubShapeCount(shape, type);
}

bool OCCTShapeTransformIsNegative(OCCTShapeRef shape)
{
  if (!shape)
    return false;
  try
  {
    auto* s = static_cast<OCCTShape*>(shape);
    if (s->shape.IsNull())
      return false;
    const TopLoc_Location& loc = s->shape.Location();
    return loc.IsIdentity() ? false : loc.Transformation().IsNegative();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

void OCCTBRepToolsCleanTriangulation(OCCTShapeRef shape)
{
  if (!shape)
    return;
  try
  {
    BRepTools::Clean(shape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTBRepToolsRemoveInternals(OCCTShapeRef shape)
{
  if (!shape)
    return;
  try
  {
    BRepTools::RemoveInternals(shape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

void OCCTBRepToolsDetectClosedness(OCCTShapeRef face, bool* isClosedU, bool* isClosedV)
{
  if (!face || !isClosedU || !isClosedV)
    return;
  try
  {
    bool u = false, v = false;
    BRepTools::DetectClosedness(TopoDS::Face(face->shape), u, v);
    *isClosedU = u;
    *isClosedV = v;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    *isClosedU = false;
    *isClosedV = false;
  }
}

double OCCTBRepToolsEvalAndUpdateTol(OCCTShapeRef edge, OCCTShapeRef face)
{
  // #2812: the type test the two TopoDS:: casts below already perform, hoisted so that it also
  // rejects a null TopoDS_Shape, which those casts pass straight through. Everything downstream
  // dereferences it: BRep_Tool::Curve, CurveOnSurface, Surface and even the Tolerance fallback all
  // SIGSEGV on a null shape, and the catch below cannot absorb a signal. 0.0 is the refusal this
  // function already gave for a null pointer and for a caught exception.
  if (!occtShapeIsType(edge, TopAbs_EDGE) || !occtShapeIsType(face, TopAbs_FACE))
    return 0.0;
  try
  {
    const TopoDS_Edge&   e = TopoDS::Edge(edge->shape);
    const TopoDS_Face&   f = TopoDS::Face(face->shape);
    double               first, last;
    Handle(Geom_Curve)   c3d  = BRep_Tool::Curve(e, first, last);
    Handle(Geom2d_Curve) c2d  = BRep_Tool::CurveOnSurface(e, f, first, last);
    Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
    // c2d has to be guarded like the other two: BRepTools::EvalAndUpdateTol dereferences it
    // unconditionally at `if (!C2d->IsPeriodic())`, so a null pcurve is an OS signal the
    // catch(...) below cannot absorb. CurveOnSurface returns null whenever the edge has no
    // pcurve on a NON-planar face (routine for mesh-sewn topology; a plane always projects
    // one, which is why this hid), and as of OCCT 8.0.1 also when the edge's range is out of
    // the basis curve's domain, where p1 threw a catchable Standard_Failure instead.
    if (c3d.IsNull() || c2d.IsNull() || surf.IsNull())
      return BRep_Tool::Tolerance(e);
    return BRepTools::EvalAndUpdateTol(e, c3d, c2d, surf, first, last);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0.0;
  }
}

int32_t OCCTBRepToolsMap3DEdgeCount(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  try
  {
    TopTools_IndexedMapOfShape edgeMap;
    BRepTools::Map3DEdges(shape->shape, edgeMap);
    return (int32_t)edgeMap.Extent();
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

void OCCTBRepToolsUpdateFaceUVPoints(OCCTShapeRef face)
{
  if (!face)
    return;
  try
  {
    BRepTools::UpdateFaceUVPoints(TopoDS::Face(face->shape));
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

bool OCCTBRepToolsCompareVertices(OCCTShapeRef v1, OCCTShapeRef v2)
{
  if (!v1 || !v2)
    return false;
  try
  {
    return BRepTools::Compare(TopoDS::Vertex(v1->shape), TopoDS::Vertex(v2->shape));
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTBRepToolsCompareEdges(OCCTShapeRef e1, OCCTShapeRef e2)
{
  if (!e1 || !e2)
    return false;
  try
  {
    return BRepTools::Compare(TopoDS::Edge(e1->shape), TopoDS::Edge(e2->shape));
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

bool OCCTBRepToolsIsReallyClosed(OCCTShapeRef edge, OCCTShapeRef face)
{
  if (!edge || !face)
    return false;
  try
  {
    return BRepTools::IsReallyClosed(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return false;
  }
}

void OCCTBRepToolsUpdate(OCCTShapeRef shape)
{
  if (!shape)
    return;
  try
  {
    BRepTools::Update(shape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
  }
}

OCCTShapeRef OCCTShapeMoved(OCCTShapeRef shape, double dx, double dy, double dz)
{
  if (!shape)
    return nullptr;
  try
  {
    gp_Trsf trsf;
    trsf.SetTranslation(gp_Vec(dx, dy, dz));
    TopoDS_Shape moved = shape->shape.Moved(TopLoc_Location(trsf));
    if (moved.IsNull())
      return nullptr;
    return new OCCTShape{moved};
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

OCCTCurve2DRef OCCTBRepToolCurveOnPlane(OCCTShapeRef   edge,
                                        OCCTSurfaceRef surface,
                                        double*        outFirst,
                                        double*        outLast)
{
  if (!edge || !surface || surface->surface.IsNull() || !outFirst || !outLast)
    return nullptr;
  try
  {
    TopoDS_Edge          e = TopoDS::Edge(edge->shape);
    TopLoc_Location      loc;
    double               first = 0, last = 0;
    Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnPlane(e, surface->surface, loc, first, last);
    if (pcurve.IsNull())
      return nullptr;
    *outFirst = first;
    *outLast  = last;
    return new OCCTCurve2D(pcurve);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}

int32_t OCCTBRepToolPolygon3D(OCCTShapeRef edge, double** outPoints)
{
  if (!occtShapeIsPresent(edge) || !outPoints)
    return 0;
  *outPoints = nullptr;
  try
  {
    TopoDS_Edge            e = TopoDS::Edge(edge->shape);
    TopLoc_Location        loc;
    Handle(Poly_Polygon3D) poly = BRep_Tool::Polygon3D(e, loc);
    if (poly.IsNull())
      return 0;
    int nb = poly->NbNodes();
    if (nb == 0)
      return 0;
    double* pts = (double*)malloc(nb * 3 * sizeof(double));
    if (!pts)
      return 0;
    gp_Trsf                           trsf  = loc.IsIdentity() ? gp_Trsf() : loc.Transformation();
    const NCollection_Array1<gp_Pnt>& nodes = poly->Nodes();
    for (int i = 1; i <= nb; i++)
    {
      gp_Pnt p             = nodes.Value(i).Transformed(trsf);
      pts[(i - 1) * 3 + 0] = p.X();
      pts[(i - 1) * 3 + 1] = p.Y();
      pts[(i - 1) * 3 + 2] = p.Z();
    }
    *outPoints = pts;
    return nb;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}

int32_t OCCTBRepToolPolygonOnTriangulation(OCCTShapeRef edge, int32_t** outIndices)
{
  if (!edge || !outIndices)
    return 0;
  *outIndices = nullptr;
  try
  {
    TopoDS_Edge                         e = TopoDS::Edge(edge->shape);
    TopLoc_Location                     loc;
    Handle(Poly_PolygonOnTriangulation) pot;
    Handle(Poly_Triangulation)          tri;
    BRep_Tool::PolygonOnTriangulation(e, pot, tri, loc);
    if (pot.IsNull())
      return 0;
    int nb = pot->NbNodes();
    if (nb == 0)
      return 0;
    int32_t* indices = (int32_t*)malloc(nb * sizeof(int32_t));
    if (!indices)
      return 0;
    for (int i = 1; i <= nb; i++)
    {
      indices[i - 1] = pot->Node(i);
    }
    *outIndices = indices;
    return nb;
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return 0;
  }
}
