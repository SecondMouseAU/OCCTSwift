//
//  OCCTBridge_Topology_Extrema.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Topology.mm (#1380): BRepExtrema, IntCurvesFace, BRepIntCurveSurface,
//  TopCnx, TopTrans. Public C surface unchanged; every sibling file imports the same headers this
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

#include <BRepTools_WireExplorer.hxx>

// Additional includes gathered from throughout the original file (#1380):
#include <ShapeAnalysis_Edge.hxx>
#include <BRepOffsetAPI_FindContigousEdges.hxx>
#include <BRepClass3d.hxx>
#include <TopoDS_Solid.hxx>
#include <TopoDS_Shell.hxx>
#include <TopExp_Explorer.hxx> // still used by the shell-classification and traversal helpers below
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
#import <BRep_Tool.hxx>
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

static OCCTFindSurfaceResult occtRunFindSurface(OCCTShapeRef        shape,
                                                double              tolerance,
                                                bool                onlyPlane,
                                                OCCTFindSurfaceWant want)
{
  OCCTFindSurfaceResult result;
  if (!shape)
    return result;
  try
  {
    BRepLib_FindSurface finder(shape->shape, tolerance, onlyPlane);
    result.found = finder.Found();
    if (!result.found)
      return result;
    switch (want)
    {
      case OCCTFindSurfaceWant::Surface:
        try
        {
          result.surface = finder.Surface();
        }
        catch (...)
        {
          // Matches the pre-consolidation behavior of every surface-returning caller: a
          // throwing Surface() was caught by that caller's own single try/catch and
          // treated as "not found" (OCCTShapeFindSurfaceEx set *outFound = false in
          // exactly this case), not as "found, but no surface available".
          result.found   = false;
          result.surface = Handle(Geom_Surface)();
        }
        break;
      case OCCTFindSurfaceWant::Tolerance:
        try
        {
          result.toleranceReached = finder.ToleranceReached();
        }
        catch (...)
        {
          result.toleranceReached = -1.0;
        }
        break;
      case OCCTFindSurfaceWant::Existed:
        try
        {
          result.existed = finder.Existed();
        }
        catch (...)
        {
          result.existed = false;
        }
        break;
    }
  }
  catch (...)
  {
    result = OCCTFindSurfaceResult();
  }
  return result;
}

// Unwraps an OCCTFindSurfaceResult into the OCCTSurfaceRef each of the three surface-returning
// callers (OCCTShapeFindSurface, OCCTShapeFindSurfaceEx, OCCTFindSurface) returns, or nullptr on
// any failure, including allocation failure for the `new OCCTSurface(...)` wrapper itself, which
// must be try/catch-guarded here rather than left to each caller: an exception escaping this
// extern "C" bridge boundary into Swift-generated call frames is uncatchable and undefined
// behavior, not the graceful nullptr every caller here otherwise guarantees (PR #866 review).
static OCCTSurfaceRef occtSurfaceRefOrNull(const OCCTFindSurfaceResult& result)
{
  if (!result.found || result.surface.IsNull())
    return nullptr;
  try
  {
    return new OCCTSurface(result.surface);
  }
  catch (...)
  {
    return nullptr;
  }
}

// The single solid a shape denotes: itself if it IS a solid, else the sole solid a
// compound/compsolid wraps. False when the container holds two or more: a set of bodies has no
// one outer shell, and answering with the first silently measures against the wrong solid. #439
static bool occtSoleSolid(const TopoDS_Shape& shape, TopoDS_Solid& outSolid)
{
  if (shape.IsNull())
    return false;
  if (shape.ShapeType() == TopAbs_SOLID)
  {
    outSolid = TopoDS::Solid(shape);
    return true;
  }
  TopExp_Explorer ex(shape, TopAbs_SOLID);
  if (!ex.More())
    return false;
  const TopoDS_Shape first = ex.Current();
  ex.Next();
  if (ex.More())
    return false; // two or more solids, no single body to answer for
  outSolid = TopoDS::Solid(first);
  return true;
}

static int32_t mapTopAbsState(TopAbs_State state)
{
  switch (state)
  {
    case TopAbs_IN:
      return 0;
    case TopAbs_OUT:
      return 1;
    case TopAbs_ON:
      return 2;
    case TopAbs_UNKNOWN:
      return 3;
    default:
      return 3;
  }
}

// #726/#763: OCCTShapeAxis.extentMin/extentMax/hasExtent were hardcoded 0/0/false on every call
// (three sites: OCCTShapeRevolutionAxes below and both OCCTShapeAxis constructions inside
// OCCTShapeSymmetryAxes) since the feature's introduction in v0.137 -- never wired up, though the
// struct's own field comments already documented the intended contract ("extentMin: along
// direction from origin (-inf as -DBL_MAX)", "extentMax: +inf as DBL_MAX"). Because
// ShapeAxis.swift's `self.extent = a.hasExtent ? (...) : nil` already gates that into an Optional,
// this reads exactly like the #583/#595/#609 "absence made representable" fix on a first look --
// which is how an earlier census pass (Scripts/repro/726-unmeasured-values/README.md) classified
// it. It is not: `hasExtent` is `false` on literally every reached path, so `extent` was `nil` for
// every caller unconditionally, the same defect class as `selfIntersectionCount`, just one layer
// removed. Fixed here by actually computing it, per the contract the header already promised.
//
// Method: BRepBndLib::Add's geometric (not triangulation) bounding box of the shape the axis
// belongs to (a face for a revolution axis, the whole shape for a symmetry axis), then the 8
// corners of that box projected onto the axis direction from the axis origin -- min and max of
// those 8 dot products. This is exact for the cases a bounding box IS tight along the query
// direction (a bounded cylindrical/conical face along its own axis, a box along a principal axis,
// both verified directly in OCCTTopologyTests), and a safe enclosing interval otherwise (curved
// geometry whose true extent is less than its box's). `IsOpen()` (an untrimmed natural-bounds
// face, or a genuinely infinite shape) reports the axis as extending to +-DBL_MAX rather than
// treating the box's own infinity sentinel (Precision::Infinite() = 1e100) as if it were a real
// measured bound; `IsVoid()` (no boundable geometry at all) reports no extent, `hasExtent = false`.
static void occtComputeAxisExtent(const TopoDS_Shape& forShape,
                                  const gp_Pnt&       origin,
                                  const gp_Dir&       direction,
                                  double&             outMin,
                                  double&             outMax,
                                  bool&               outHasExtent)
{
  outMin       = 0.0;
  outMax       = 0.0;
  outHasExtent = false;
  if (forShape.IsNull())
    return;
  try
  {
    Bnd_Box box;
    BRepBndLib::Add(forShape, box);
    if (box.IsVoid())
      return;
    if (box.IsOpen())
    {
      outMin       = -std::numeric_limits<double>::max();
      outMax       = std::numeric_limits<double>::max();
      outHasExtent = true;
      return;
    }
    double xmin, ymin, zmin, xmax, ymax, zmax;
    box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
    const double ox = origin.X(), oy = origin.Y(), oz = origin.Z();
    const double dx = direction.X(), dy = direction.Y(), dz = direction.Z();
    double       tMin = std::numeric_limits<double>::infinity();
    double       tMax = -std::numeric_limits<double>::infinity();
    for (int ix = 0; ix < 2; ix++)
    {
      double px = (ix == 0) ? xmin : xmax;
      for (int iy = 0; iy < 2; iy++)
      {
        double py = (iy == 0) ? ymin : ymax;
        for (int iz = 0; iz < 2; iz++)
        {
          double pz = (iz == 0) ? zmin : zmax;
          double t  = (px - ox) * dx + (py - oy) * dy + (pz - oz) * dz;
          if (t < tMin)
            tMin = t;
          if (t > tMax)
            tMax = t;
        }
      }
    }
    outMin       = tMin;
    outMax       = tMax;
    outHasExtent = true;
  }
  catch (...)
  {
    outMin       = 0.0;
    outMax       = 0.0;
    outHasExtent = false;
  }
}

static bool axesCoincide(const OCCTShapeAxis& a,
                         double               ox,
                         double               oy,
                         double               oz,
                         double               dx,
                         double               dy,
                         double               dz,
                         double               tol)
{
  gp_Dir d1(a.directionX, a.directionY, a.directionZ);
  gp_Dir d2(dx, dy, dz);
  // Direction parallel (either same or opposite)
  if (fabs(fabs(d1.Dot(d2)) - 1.0) > tol)
    return false;
  // Origin-to-origin vector parallel to direction (i.e. same line)
  gp_Vec sep(ox - a.originX, oy - a.originY, oz - a.originZ);
  if (sep.Magnitude() < tol)
    return true;
  gp_Vec axisVec(d1.X(), d1.Y(), d1.Z());
  gp_Vec cross = sep.Crossed(axisVec);
  return cross.Magnitude() < tol;
}

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

// Map our convention (0=Convex,1=Concave,2=Tangent) to ChFiDS (0=Concave,1=Convex,2=Tangential)
static ChFiDS_TypeOfConcavity _mapConcavity(int32_t ourType)
{
  switch (ourType)
  {
    case 0:
      return ChFiDS_Convex;
    case 1:
      return ChFiDS_Concave;
    case 2:
      return ChFiDS_Tangential;
    default:
      return ChFiDS_Convex;
  }
}

static int32_t _mapConcavityBack(ChFiDS_TypeOfConcavity chiType)
{
  switch (chiType)
  {
    case ChFiDS_Convex:
      return 0;
    case ChFiDS_Concave:
      return 1;
    case ChFiDS_Tangential:
      return 2;
    case ChFiDS_FreeBound:
      return 3;
    default:
      return 4;
  }
}

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

int32_t OCCTShapeAllDistanceSolutions(OCCTShapeRef          shape1,
                                      OCCTShapeRef          shape2,
                                      OCCTDistanceSolution* outSolutions,
                                      int32_t               maxSolutions)
{
  if (!shape1 || !shape2 || !outSolutions || maxSolutions <= 0)
    return -1;
  try
  {
    BRepExtrema_DistShapeShape dist(shape1->shape, shape2->shape);
    if (!dist.IsDone())
      return -1;

    int32_t nbSol = dist.NbSolution();
    int32_t count = std::min(nbSol, maxSolutions);

    for (int32_t i = 0; i < count; i++)
    {
      gp_Pnt p1                = dist.PointOnShape1(i + 1);
      gp_Pnt p2                = dist.PointOnShape2(i + 1);
      outSolutions[i].point1X  = p1.X();
      outSolutions[i].point1Y  = p1.Y();
      outSolutions[i].point1Z  = p1.Z();
      outSolutions[i].point2X  = p2.X();
      outSolutions[i].point2Y  = p2.Y();
      outSolutions[i].point2Z  = p2.Z();
      outSolutions[i].distance = dist.Value();
    }
    return nbSol;
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTShapeIsInnerDistance(OCCTShapeRef shape1, OCCTShapeRef shape2)
{
  if (!shape1 || !shape2)
    return -1;
  try
  {
    BRepExtrema_DistShapeShape dist(shape1->shape, shape2->shape);
    if (!dist.IsDone())
      return -1;
    return dist.InnerSolution() ? 1 : 0;
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTShapeDistanceSolutionDetail(OCCTShapeRef                shape1,
                                     OCCTShapeRef                shape2,
                                     int32_t                     solutionIndex,
                                     OCCTDistanceSolutionDetail* outDetail)
{
  if (!shape1 || !shape2 || !outDetail)
    return false;
  try
  {
    BRepExtrema_DistShapeShape dist(shape1->shape, shape2->shape);
    if (!dist.IsDone())
      return false;
    int idx = solutionIndex + 1; // OCCT is 1-based
    if (idx < 1 || idx > dist.NbSolution())
      return false;

    memset(outDetail, 0, sizeof(OCCTDistanceSolutionDetail));

    // Support types: BRepExtrema_IsVertex=0, BRepExtrema_IsOnEdge=1, BRepExtrema_IsInFace=2
    outDetail->supportType1 = (int32_t)dist.SupportTypeShape1(idx);
    outDetail->supportType2 = (int32_t)dist.SupportTypeShape2(idx);

    // Edge parameters
    if (outDetail->supportType1 == 1)
    { // IsOnEdge
      double t = 0;
      dist.ParOnEdgeS1(idx, t);
      outDetail->paramEdge1 = t;
    }
    if (outDetail->supportType2 == 1)
    {
      double t = 0;
      dist.ParOnEdgeS2(idx, t);
      outDetail->paramEdge2 = t;
    }

    // Face parameters
    if (outDetail->supportType1 == 2)
    { // IsInFace
      double u = 0, v = 0;
      dist.ParOnFaceS1(idx, u, v);
      outDetail->paramFaceU1 = u;
      outDetail->paramFaceV1 = v;
    }
    if (outDetail->supportType2 == 2)
    {
      double u = 0, v = 0;
      dist.ParOnFaceS2(idx, u, v);
      outDetail->paramFaceU2 = u;
      outDetail->paramFaceV2 = v;
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - BRepExtrema_SelfIntersection (v0.45)
OCCTSelfIntersectionResult OCCTShapeSelfIntersection(OCCTShapeRef shape,
                                                     double       tolerance,
                                                     double       meshDeflection)
{
  OCCTSelfIntersectionResult result = {0, false};
  if (!shape)
    return result;
  try
  {
    // Ensure the shape is meshed
    BRepMesh_IncrementalMesh mesh(shape->shape, meshDeflection);

    BRepExtrema_SelfIntersection selfInt(shape->shape, tolerance);
    selfInt.Perform();

    result.isDone = selfInt.IsDone();
    if (result.isDone)
    {
      result.overlapCount = (int32_t)selfInt.OverlapElements().Size();
    }
    return result;
  }
  catch (...)
  {
    return result;
  }
}

// MARK: - BRepExtrema Ext CC/PF/FF (v0.48)
OCCTEdgeEdgeExtremaResult OCCTBRepExtremaExtCC(OCCTShapeRef shape1,
                                               int32_t      edgeIndex1,
                                               OCCTShapeRef shape2,
                                               int32_t      edgeIndex2)
{
  OCCTEdgeEdgeExtremaResult result = {};
  if (!shape1 || !shape2)
    return result;
  try
  {
    // #613: this counted TopExp_Explorer occurrences while its neighbours in this same file
    // (OCCTBRepExtremaExtPC, ExtCF, OCCTShapeClassifyPoint2D) were converted to the shared
    // enumeration by #541 -- so edgeIndex meant one thing here and another thing one function
    // away. On a 10mm box the two agree up to index 8 and name DIFFERENT edges from 9 on, and
    // indices 12..23 answered at all despite edge(at:) refusing every one of them.
    //
    // BRepExtrema_ExtCC reads the edge as pure geometry (BRepAdaptor_Curve over the 3D curve
    // and its BRep_Tool::Range), so the map's stored orientation is as good as any occurrence's:
    // measured over all 12 box edges present in both orientations, IsParallel, NbExt,
    // SquareDistance, ParameterOnE1 and PointOnE1 were identical for both, 0 differing.
    TopoDS_Edge e1 = occtEdgeAt(shape1->shape, edgeIndex1);
    TopoDS_Edge e2 = occtEdgeAt(shape2->shape, edgeIndex2);
    if (e1.IsNull() || e2.IsNull())
      return result;

    BRepExtrema_ExtCC extCC(e1, e2);
    if (!extCC.IsDone())
      return result;

    result.isParallel = extCC.IsParallel();
    if (result.isParallel)
    {
      result.solutionCount = 0;
      return result;
    }
    result.solutionCount = extCC.NbExt();

    if (result.solutionCount >= 1 && !result.isParallel)
    {
      result.distance  = sqrt(extCC.SquareDistance(1));
      result.paramOnE1 = extCC.ParameterOnE1(1);
      result.paramOnE2 = extCC.ParameterOnE2(1);
      gp_Pnt p1        = extCC.PointOnE1(1);
      gp_Pnt p2        = extCC.PointOnE2(1);
      result.pt1x      = p1.X();
      result.pt1y      = p1.Y();
      result.pt1z      = p1.Z();
      result.pt2x      = p2.X();
      result.pt2y      = p2.Y();
      result.pt2z      = p2.Z();
    }
    return result;
  }
  catch (...)
  {
    return result;
  }
}

OCCTEdgeEdgeExtremaResult OCCTBRepExtremaExtCCEdges(OCCTShapeRef edge1, OCCTShapeRef edge2)
{
  OCCTEdgeEdgeExtremaResult result = {};
  if (!edge1 || !edge2)
    return result;
  try
  {
    // #975: occtEdgeAt(shape, 0) is this bridge's one spelling of "the first edge of this shape".
    // OCCTBRepExtremaExtCC forty lines above, which takes an edge INDEX rather than a shape that
    // holds one, was converted to the same enumeration by #613; the two ChFi2d entry points in
    // OCCTBridge_Modeling.mm carried a byte-identical copy of the block this replaces. See
    // OCCTBridge_Internal.h.
    TopoDS_Edge e1 = occtEdgeAt(edge1->shape, 0);
    TopoDS_Edge e2 = occtEdgeAt(edge2->shape, 0);
    if (e1.IsNull() || e2.IsNull())
      return result;

    BRepExtrema_ExtCC extCC(e1, e2);
    if (!extCC.IsDone())
      return result;

    result.isParallel = extCC.IsParallel();
    if (result.isParallel)
    {
      result.solutionCount = 0;
      return result;
    }
    result.solutionCount = extCC.NbExt();

    if (result.solutionCount >= 1 && !result.isParallel)
    {
      result.distance  = sqrt(extCC.SquareDistance(1));
      result.paramOnE1 = extCC.ParameterOnE1(1);
      result.paramOnE2 = extCC.ParameterOnE2(1);
      gp_Pnt p1        = extCC.PointOnE1(1);
      gp_Pnt p2        = extCC.PointOnE2(1);
      result.pt1x      = p1.X();
      result.pt1y      = p1.Y();
      result.pt1z      = p1.Z();
      result.pt2x      = p2.X();
      result.pt2y      = p2.Y();
      result.pt2z      = p2.Z();
    }
    return result;
  }
  catch (...)
  {
    return result;
  }
}

OCCTPointFaceExtremaResult OCCTBRepExtremaExtPF(double       px,
                                                double       py,
                                                double       pz,
                                                OCCTShapeRef shape,
                                                int32_t      faceIndex)
{
  OCCTPointFaceExtremaResult result = {};
  if (!shape)
    return result;
  try
  {
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return result;

    TopoDS_Vertex     vertex = BRepBuilderAPI_MakeVertex(gp_Pnt(px, py, pz));
    BRepExtrema_ExtPF extPF(vertex, face);
    if (!extPF.IsDone())
      return result;

    result.solutionCount = extPF.NbExt();
    if (result.solutionCount >= 1)
    {
      result.distance = sqrt(extPF.SquareDistance(1));
      gp_Pnt pt       = extPF.Point(1);
      result.ptx      = pt.X();
      result.pty      = pt.Y();
      result.ptz      = pt.Z();
      extPF.Parameter(1, result.u, result.v);
    }
    return result;
  }
  catch (...)
  {
    return result;
  }
}

OCCTFaceFaceExtremaResult OCCTBRepExtremaExtFF(OCCTShapeRef shape1,
                                               int32_t      faceIndex1,
                                               OCCTShapeRef shape2,
                                               int32_t      faceIndex2)
{
  OCCTFaceFaceExtremaResult result = {};
  if (!shape1 || !shape2)
    return result;
  try
  {
    TopoDS_Face f1 = occtFaceAt(shape1->shape, faceIndex1);
    TopoDS_Face f2 = occtFaceAt(shape2->shape, faceIndex2);
    if (f1.IsNull() || f2.IsNull())
      return result;

    BRepExtrema_ExtFF extFF(f1, f2);
    if (!extFF.IsDone())
      return result;

    result.solutionCount = extFF.NbExt();
    if (result.solutionCount >= 1)
    {
      result.distance = sqrt(extFF.SquareDistance(1));
      extFF.ParameterOnFace1(1, result.u1, result.v1);
      extFF.ParameterOnFace2(1, result.u2, result.v2);
      gp_Pnt p1   = extFF.PointOnFace1(1);
      gp_Pnt p2   = extFF.PointOnFace2(1);
      result.pt1x = p1.X();
      result.pt1y = p1.Y();
      result.pt1z = p1.Z();
      result.pt2x = p2.X();
      result.pt2y = p2.Y();
      result.pt2z = p2.Z();
    }
    return result;
  }
  catch (...)
  {
    return result;
  }
}

// #580: the nearest point on the edge, not the nearest of BRepExtrema_ExtPC's extrema.
//
// BRepExtrema_ExtPC searches for perpendicular feet, so it excludes the edge's own two ends and
// makes no distinction between a minimum and a maximum. Reporting the smallest of what it found is
// therefore not the smallest distance to the edge, and measurably so: over 189 edge/point
// combinations (Scripts/repro/539-nearest-point-on-curve/580-repair-options.mm) it answered 101
// correctly, 34 with a distance that was too large -- a point below a half circle of radius 5 read
// as 11 rather than 7.81, because the sole extremum in range is the far side of the arc -- and
// refused 54 outright, IsDone() being false whenever no foot exists at all.
//
// The measured trap: filtering the extrema to the IsMin ones scores 101, exactly what it scored
// before. The cases that filter drops are precisely the ones it leaves with no candidate.
//
// occtNearestPointOnCurveRange (#539) is what answers this, so both this entry point and
// OCCTEdgeProjectPoint reach one implementation and cannot disagree about the same edge and the
// same point. Adding BRepExtrema_ExtPC's own ends via TrimmedSquareDistances would be the smaller
// diff but tops out at 188/189: on a BSpline queried from (2, 0, 0) Extrema_ExtPC does not
// converge, leaving the nearer end to answer 2 against a truth of 1.996434, where the helper's
// GeomAPI_ProjectPointOnCurve finds the interior minimum.
OCCTPointEdgeExtremaResult OCCTBRepExtremaExtPC(double       px,
                                                double       py,
                                                double       pz,
                                                OCCTShapeRef shape,
                                                int32_t      edgeIndex)
{
  OCCTPointEdgeExtremaResult result = {};
  if (!shape)
    return result;
  try
  {
    // #541's enumeration, which is the one Shape.edges() and Shape.edge(at:) read. This used to
    // walk its own bare explorer, which counts one entry per *occurrence*: a box's 12 edges are
    // 24 occurrences, since each belongs to two faces, and measured on the pinned kernel the two
    // orders diverge from index 9 onwards -- edgeIndex 9 was the edge through (10, 0, 5) here
    // and the edge through (5, 0, 10) to every other entry point. A caller holding an index from
    // edges() measured to an edge it had not selected, on the most ordinary shape there is.
    TopoDS_Edge edge = occtEdgeAt(shape->shape, edgeIndex);
    if (edge.IsNull())
      return result;

    Standard_Real      first, last;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
    if (curve.IsNull())
      return result;

    gp_Pnt nearest;
    if (!occtNearestPointOnCurveRange(curve,
                                      gp_Pnt(px, py, pz),
                                      first,
                                      last,
                                      Precision::Confusion(),
                                      &nearest,
                                      &result.parameter,
                                      &result.distance))
    {
      return result;
    }
    result.ptx = nearest.X();
    result.pty = nearest.Y();
    result.ptz = nearest.Z();

    // Still BRepExtrema_ExtPC's own count, reported for its own sake: how many perpendicular
    // feet the point has on this edge. Zero now travels to the caller instead of erasing the
    // answer, and a search that cannot finish leaves it zero rather than failing the call.
    try
    {
      TopoDS_Vertex     vertex = BRepBuilderAPI_MakeVertex(gp_Pnt(px, py, pz));
      BRepExtrema_ExtPC ext(vertex, edge);
      if (ext.IsDone())
        result.solutionCount = ext.NbExt();
    }
    catch (...)
    {
      // A count we could not take is zero feet reported, not a failed distance.
    }

    result.isValid = true;
    return result;
  }
  catch (...)
  {
    return result;
  }
}

OCCTEdgeFaceExtremaResult OCCTBRepExtremaExtCF(OCCTShapeRef shape1,
                                               int32_t      edgeIndex,
                                               OCCTShapeRef shape2,
                                               int32_t      faceIndex)
{
  OCCTEdgeFaceExtremaResult result = {};
  if (!shape1 || !shape2)
    return result;
  try
  {
    TopoDS_Edge edge = occtEdgeAt(shape1->shape, edgeIndex);
    if (edge.IsNull())
      return result;

    TopoDS_Face face = occtFaceAt(shape2->shape, faceIndex);
    if (face.IsNull())
      return result;

    BRepExtrema_ExtCF ext(edge, face);
    if (!ext.IsDone())
      return result;

    result.isParallel = ext.IsParallel();
    if (result.isParallel)
    {
      result.solutionCount = 0;
      return result;
    }

    result.solutionCount = ext.NbExt();
    if (result.solutionCount >= 1)
    {
      // Find minimum distance
      double minDist2 = ext.SquareDistance(1);
      int    minIdx   = 1;
      for (int i = 2; i <= ext.NbExt(); i++)
      {
        if (ext.SquareDistance(i) < minDist2)
        {
          minDist2 = ext.SquareDistance(i);
          minIdx   = i;
        }
      }
      result.distance    = sqrt(minDist2);
      result.paramOnEdge = ext.ParameterOnEdge(minIdx);
      ext.ParameterOnFace(minIdx, result.uOnFace, result.vOnFace);
      gp_Pnt pe      = ext.PointOnEdge(minIdx);
      result.edgePtx = pe.X();
      result.edgePty = pe.Y();
      result.edgePtz = pe.Z();
      gp_Pnt pf      = ext.PointOnFace(minIdx);
      result.facePtx = pf.X();
      result.facePty = pf.Y();
      result.facePtz = pf.Z();
    }
    return result;
  }
  catch (...)
  {
    return result;
  }
}

// MARK: - BRepExtrema_Poly Distance (v0.50)
OCCTPolyDistanceResult OCCTShapePolyhedralDistance(OCCTShapeRef shape1, OCCTShapeRef shape2)
{
  OCCTPolyDistanceResult result = {};
  if (!shape1 || !shape2)
    return result;
  try
  {
    gp_Pnt           p1, p2;
    Standard_Real    dist;
    Standard_Boolean ok = BRepExtrema_Poly::Distance(shape1->shape, shape2->shape, p1, p2, dist);
    if (ok)
    {
      result.success  = true;
      result.distance = dist;
      result.p1x      = p1.X();
      result.p1y      = p1.Y();
      result.p1z      = p1.Z();
      result.p2x      = p2.X();
      result.p2y      = p2.Y();
      result.p2z      = p2.Z();
    }
  }
  catch (...)
  {
  }
  return result;
}

int32_t OCCTIntersectLineFace(OCCTShapeRef face,
                              double       origX,
                              double       origY,
                              double       origZ,
                              double       dirX,
                              double       dirY,
                              double       dirZ,
                              double       pInf,
                              double       pSup,
                              double*      outPoints,
                              double*      outParams,
                              int32_t      maxPts)
{
  // #1026: a null shape is not a face, so it meets no line at all and the count is 0, which is
  // already what this returns for every other input it cannot intersect.
  if (!occtShapeIsType(face, TopAbs_FACE) || !outPoints || !outParams || maxPts <= 0)
    return 0;
  try
  {
    TopoDS_Face               f = TopoDS::Face(face->shape);
    IntCurvesFace_Intersector intersector(f, 1e-6);
    gp_Lin                    line(gp_Pnt(origX, origY, origZ), gp_Dir(dirX, dirY, dirZ));
    intersector.Perform(line, pInf, pSup);
    if (!intersector.IsDone())
      return 0;
    int32_t nb = std::min((int32_t)intersector.NbPnt(), maxPts);
    for (int32_t i = 0; i < nb; i++)
    {
      gp_Pnt pt            = intersector.Pnt(i + 1);
      outPoints[i * 3]     = pt.X();
      outPoints[i * 3 + 1] = pt.Y();
      outPoints[i * 3 + 2] = pt.Z();
      outParams[i]         = intersector.WParameter(i + 1);
    }
    return nb;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTIntCurvesFaceShapeIntersect(OCCTShapeRef shape,
                                     double       ox,
                                     double       oy,
                                     double       oz,
                                     double       dx,
                                     double       dy,
                                     double       dz,
                                     double* _Nullable* _Nonnull outPoints,
                                     double* _Nullable* _Nonnull outParams,
                                     int32_t* outCount)
{
  if (!shape)
    return false;
  try
  {
    IntCurvesFace_ShapeIntersector si;
    si.Load(shape->shape, 1e-6);
    gp_Lin ray(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz));
    si.Perform(ray, -1e10, 1e10);
    int32_t n = si.NbPnt();
    *outCount = n;
    if (n == 0)
    {
      *outPoints = nullptr;
      *outParams = nullptr;
      return false;
    }
    si.SortResult();
    *outPoints = (double*)malloc(n * 3 * sizeof(double));
    *outParams = (double*)malloc(n * sizeof(double));
    for (int32_t i = 0; i < n; i++)
    {
      gp_Pnt pt               = si.Pnt(i + 1);
      (*outPoints)[i * 3]     = pt.X();
      (*outPoints)[i * 3 + 1] = pt.Y();
      (*outPoints)[i * 3 + 2] = pt.Z();
      (*outParams)[i]         = si.WParameter(i + 1);
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTIntCurvesFaceShapeIntersectNearest(OCCTShapeRef shape,
                                            double       ox,
                                            double       oy,
                                            double       oz,
                                            double       dx,
                                            double       dy,
                                            double       dz,
                                            double*      outX,
                                            double*      outY,
                                            double*      outZ,
                                            double*      outParam)
{
  if (!shape)
    return false;
  try
  {
    IntCurvesFace_ShapeIntersector si;
    si.Load(shape->shape, 1e-6);
    gp_Lin ray(gp_Pnt(ox, oy, oz), gp_Dir(dx, dy, dz));
    si.PerformNearest(ray, -1e10, 1e10);
    if (si.NbPnt() < 1)
      return false;
    gp_Pnt pt = si.Pnt(1);
    *outX     = pt.X();
    *outY     = pt.Y();
    *outZ     = pt.Z();
    *outParam = si.WParameter(1);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTTopTransSurfaceTransition(double  tgtX,
                                   double  tgtY,
                                   double  tgtZ,
                                   double  normX,
                                   double  normY,
                                   double  normZ,
                                   double  surfNormX,
                                   double  surfNormY,
                                   double  surfNormZ,
                                   double  tolerance,
                                   int32_t surfOrientation,
                                   int32_t boundOrientation,
                                   int32_t* _Nonnull outStateBefore,
                                   int32_t* _Nonnull outStateAfter)
{
  try
  {
    TopTrans_SurfaceTransition st;
    st.Reset(gp_Dir(tgtX, tgtY, tgtZ), gp_Dir(normX, normY, normZ));
    st.Compare(tolerance,
               gp_Dir(surfNormX, surfNormY, surfNormZ),
               occtOrientationFromInt(surfOrientation),
               occtOrientationFromInt(boundOrientation));
    *outStateBefore = (int32_t)st.StateBefore();
    *outStateAfter  = (int32_t)st.StateAfter();
  }
  catch (...)
  {
    *outStateBefore = 3; // UNKNOWN
    *outStateAfter  = 3;
  }
}

void OCCTTopTransSurfaceTransitionCurvature(double  tgtX,
                                            double  tgtY,
                                            double  tgtZ,
                                            double  normX,
                                            double  normY,
                                            double  normZ,
                                            double  maxDX,
                                            double  maxDY,
                                            double  maxDZ,
                                            double  minDX,
                                            double  minDY,
                                            double  minDZ,
                                            double  maxCurv,
                                            double  minCurv,
                                            double  surfNormX,
                                            double  surfNormY,
                                            double  surfNormZ,
                                            double  surfMaxDX,
                                            double  surfMaxDY,
                                            double  surfMaxDZ,
                                            double  surfMinDX,
                                            double  surfMinDY,
                                            double  surfMinDZ,
                                            double  surfMaxCurv,
                                            double  surfMinCurv,
                                            double  tolerance,
                                            int32_t surfOrientation,
                                            int32_t boundOrientation,
                                            int32_t* _Nonnull outStateBefore,
                                            int32_t* _Nonnull outStateAfter)
{
  try
  {
    TopTrans_SurfaceTransition st;
    st.Reset(gp_Dir(tgtX, tgtY, tgtZ),
             gp_Dir(normX, normY, normZ),
             gp_Dir(maxDX, maxDY, maxDZ),
             gp_Dir(minDX, minDY, minDZ),
             maxCurv,
             minCurv);
    st.Compare(tolerance,
               gp_Dir(surfNormX, surfNormY, surfNormZ),
               gp_Dir(surfMaxDX, surfMaxDY, surfMaxDZ),
               gp_Dir(surfMinDX, surfMinDY, surfMinDZ),
               surfMaxCurv,
               surfMinCurv,
               occtOrientationFromInt(surfOrientation),
               occtOrientationFromInt(boundOrientation));
    *outStateBefore = (int32_t)st.StateBefore();
    *outStateAfter  = (int32_t)st.StateAfter();
  }
  catch (...)
  {
    *outStateBefore = 3;
    *outStateAfter  = 3;
  }
}

void OCCTTopTransCurveTransition(double   tgtX,
                                 double   tgtY,
                                 double   tgtZ,
                                 double   tangX,
                                 double   tangY,
                                 double   tangZ,
                                 double   normX,
                                 double   normY,
                                 double   normZ,
                                 double   curvature,
                                 double   tolerance,
                                 int32_t  surfOrientation,
                                 int32_t  boundOrientation,
                                 int32_t* outStateBefore,
                                 int32_t* outStateAfter)
{
  try
  {
    TopTrans_CurveTransition ct;
    ct.Reset(gp_Dir(tgtX, tgtY, tgtZ));
    ct.Compare(tolerance,
               gp_Dir(tangX, tangY, tangZ),
               gp_Dir(normX, normY, normZ),
               curvature,
               occtOrientationFromInt(surfOrientation),
               occtOrientationFromInt(boundOrientation));
    *outStateBefore = (int32_t)ct.StateBefore();
    *outStateAfter  = (int32_t)ct.StateAfter();
  }
  catch (...)
  {
    *outStateBefore = 3;
    *outStateAfter  = 3;
  }
}

void OCCTTopTransCurveTransitionWithCurvature(double   tgtX,
                                              double   tgtY,
                                              double   tgtZ,
                                              double   curveNormX,
                                              double   curveNormY,
                                              double   curveNormZ,
                                              double   curveCurv,
                                              double   tangX,
                                              double   tangY,
                                              double   tangZ,
                                              double   normX,
                                              double   normY,
                                              double   normZ,
                                              double   surfCurv,
                                              double   tolerance,
                                              int32_t  surfOrientation,
                                              int32_t  boundOrientation,
                                              int32_t* outStateBefore,
                                              int32_t* outStateAfter)
{
  try
  {
    TopTrans_CurveTransition ct;
    ct.Reset(gp_Dir(tgtX, tgtY, tgtZ), gp_Dir(curveNormX, curveNormY, curveNormZ), curveCurv);
    ct.Compare(tolerance,
               gp_Dir(tangX, tangY, tangZ),
               gp_Dir(normX, normY, normZ),
               surfCurv,
               occtOrientationFromInt(surfOrientation),
               occtOrientationFromInt(boundOrientation));
    *outStateBefore = (int32_t)ct.StateBefore();
    *outStateAfter  = (int32_t)ct.StateAfter();
  }
  catch (...)
  {
    *outStateBefore = 3;
    *outStateAfter  = 3;
  }
}

OCCTEdgeFaceTransitionResult OCCTTopCnxEdgeFaceTransition(
  double edgeTangentX,
  double edgeTangentY,
  double edgeTangentZ,
  double edgeNormalX,
  double edgeNormalY,
  double edgeNormalZ,
  double edgeCurvature,
  const double* _Nonnull faceTangents,
  const double* _Nonnull faceNormals,
  const double* _Nonnull faceCurvatures,
  const int32_t* _Nonnull faceOrientations,
  const int32_t* _Nonnull faceTransitions,
  const int32_t* _Nonnull faceBoundaryTransitions,
  const double* _Nonnull tolerances,
  int32_t faceCount)
{
  OCCTEdgeFaceTransitionResult result = {0, 0};
  try
  {
    TopCnx_EdgeFaceTransition eft;
    gp_Dir                    tgt(edgeTangentX, edgeTangentY, edgeTangentZ);

    // Check if edge is linear (zero normal)
    double normMag =
      sqrt(edgeNormalX * edgeNormalX + edgeNormalY * edgeNormalY + edgeNormalZ * edgeNormalZ);
    if (normMag < 1e-10)
    {
      eft.Reset(tgt);
    }
    else
    {
      gp_Dir norm(edgeNormalX, edgeNormalY, edgeNormalZ);
      eft.Reset(tgt, norm, edgeCurvature);
    }

    for (int32_t i = 0; i < faceCount; i++)
    {
      gp_Dir faceTang(faceTangents[i * 3], faceTangents[i * 3 + 1], faceTangents[i * 3 + 2]);
      gp_Dir faceNorm(faceNormals[i * 3], faceNormals[i * 3 + 1], faceNormals[i * 3 + 2]);
      eft.AddInterference(tolerances[i],
                          faceTang,
                          faceNorm,
                          faceCurvatures[i],
                          (TopAbs_Orientation)faceOrientations[i],
                          (TopAbs_Orientation)faceTransitions[i],
                          (TopAbs_Orientation)faceBoundaryTransitions[i]);
    }

    result.transition         = (int32_t)eft.Transition();
    result.boundaryTransition = (int32_t)eft.BoundaryTransition();
  }
  catch (...)
  {
  }
  return result;
}

OCCTCurveSurfaceInterRef _Nullable OCCTCurveSurfaceInterCreateLine(OCCTShapeRef _Nonnull shape,
                                                                   double originX,
                                                                   double originY,
                                                                   double originZ,
                                                                   double dirX,
                                                                   double dirY,
                                                                   double dirZ,
                                                                   double tolerance)
{
  if (!shape)
    return nullptr;
  try
  {
    auto*  ref = new OCCTCurveSurfaceInter();
    gp_Lin line(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
    ref->inter.Init(shape->shape, line, tolerance);
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurveSurfaceInterRef _Nullable OCCTCurveSurfaceInterCreateCurve(OCCTShapeRef _Nonnull shape,
                                                                    OCCTCurve3DRef _Nonnull curve,
                                                                    double tolerance)
{
  if (!shape || !curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    auto*             ref = new OCCTCurveSurfaceInter();
    GeomAdaptor_Curve gac(curve->curve);
    ref->inter.Init(shape->shape, gac, tolerance);
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTCurveSurfaceInterRelease(OCCTCurveSurfaceInterRef _Nonnull inter)
{
  delete inter;
}

bool OCCTCurveSurfaceInterMore(OCCTCurveSurfaceInterRef _Nonnull inter)
{
  try
  {
    return inter->inter.More();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTCurveSurfaceInterNext(OCCTCurveSurfaceInterRef _Nonnull inter)
{
  try
  {
    inter->inter.Next();
  }
  catch (...)
  {
  }
}

OCCTCurveSurfaceHit OCCTCurveSurfaceInterHit(OCCTCurveSurfaceInterRef _Nonnull inter)
{
  OCCTCurveSurfaceHit hit = {};
  try
  {
    gp_Pnt pt = inter->inter.Pnt();
    hit.x     = pt.X();
    hit.y     = pt.Y();
    hit.z     = pt.Z();
    hit.u     = inter->inter.U();
    hit.v     = inter->inter.V();
    hit.w     = inter->inter.W();
  }
  catch (...)
  {
  }
  return hit;
}

OCCTFaceRef _Nullable OCCTCurveSurfaceInterFace(OCCTCurveSurfaceInterRef _Nonnull inter)
{
  try
  {
    TopoDS_Face face = inter->inter.Face();
    if (face.IsNull())
      return nullptr;
    auto* ref = new OCCTFace();
    ref->face = face;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTCurveSurfaceInterAllHits(OCCTCurveSurfaceInterRef _Nonnull inter,
                                     OCCTCurveSurfaceHit* _Nonnull hits,
                                     int32_t maxHits)
{
  int32_t count = 0;
  try
  {
    while (inter->inter.More() && count < maxHits)
    {
      gp_Pnt pt     = inter->inter.Pnt();
      hits[count].x = pt.X();
      hits[count].y = pt.Y();
      hits[count].z = pt.Z();
      hits[count].u = inter->inter.U();
      hits[count].v = inter->inter.V();
      hits[count].w = inter->inter.W();
      count++;
      inter->inter.Next();
    }
  }
  catch (...)
  {
  }
  return count;
}

// MARK: - BRepExtrema_DistanceSS (v0.79)
// --- BRepExtrema_DistanceSS ---
OCCTDistanceSSResult OCCTBRepExtremaDistanceSS(OCCTShapeRef _Nonnull shape1Ref,
                                               OCCTShapeRef _Nonnull shape2Ref,
                                               double deflection)
{
  OCCTDistanceSSResult result = {};
  try
  {
    const TopoDS_Shape& s1 = *(const TopoDS_Shape*)shape1Ref;
    const TopoDS_Shape& s2 = *(const TopoDS_Shape*)shape2Ref;

    Bnd_Box b1, b2;
    BRepBndLib::Add(s1, b1);
    BRepBndLib::Add(s2, b2);

    BRepExtrema_DistanceSS dss(s1, s2, b1, b2, 1e10, deflection);
    result.isDone        = dss.IsDone();
    result.distance      = dss.DistValue();
    result.solutionCount = (int)dss.Seq1Value().Size();

    if (result.solutionCount > 0)
    {
      gp_Pnt p1      = dss.Seq1Value().First().Point();
      gp_Pnt p2      = dss.Seq2Value().First().Point();
      result.point1X = p1.X();
      result.point1Y = p1.Y();
      result.point1Z = p1.Z();
      result.point2X = p2.X();
      result.point2Y = p2.Y();
      result.point2Z = p2.Z();
    }
  }
  catch (...)
  {
  }
  return result;
}

int32_t OCCTShapeSelfIntersectionPairs(OCCTShapeRef shape,
                                       double       tolerance,
                                       int32_t*     outFaceIdx1,
                                       int32_t*     outFaceIdx2,
                                       int32_t      maxPairs,
                                       double       deflection)
{
  if (!shape || !outFaceIdx1 || !outFaceIdx2 || maxPairs <= 0)
    return -1;
  try
  {
    BRepMesh_IncrementalMesh mesher(shape->shape, deflection);

    BRepExtrema_SelfIntersection selfInt(shape->shape, tolerance);
    selfInt.Perform();

    if (!selfInt.IsDone())
      return -1;

    const auto& overlaps = selfInt.OverlapElements();
    int32_t     count    = 0;

    for (NCollection_DataMap<int, TColStd_PackedMapOfInteger>::Iterator it(overlaps);
         it.More() && count < maxPairs;
         it.Next())
    {
      int                               faceIdx1 = it.Key();
      const TColStd_PackedMapOfInteger& partners = it.Value();
      for (TColStd_PackedMapOfInteger::Iterator mit(partners); mit.More() && count < maxPairs;
           mit.Next())
      {
        int faceIdx2 = mit.Key();
        if (faceIdx2 > faceIdx1)
        { // avoid duplicates
          outFaceIdx1[count] = (int32_t)faceIdx1;
          outFaceIdx2[count] = (int32_t)faceIdx2;
          count++;
        }
      }
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

OCCTDistSSRef OCCTDistSSCreate(OCCTShapeRef s1, OCCTShapeRef s2)
{
  if (!s1 || !s2)
    return nullptr;
  try
  {
    auto ref = new OCCTDistSS();
    ref->dist.LoadS1(s1->shape);
    ref->dist.LoadS2(s2->shape);
    ref->dist.Perform();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTDistSSRelease(OCCTDistSSRef dist)
{
  delete dist;
}

bool OCCTDistSSIsDone(OCCTDistSSRef dist)
{
  if (!dist)
    return false;
  return dist->dist.IsDone();
}

double OCCTDistSSValue(OCCTDistSSRef dist)
{
  if (!dist)
    return -1;
  try
  {
    return dist->dist.Value();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDistSSNbSolution(OCCTDistSSRef dist)
{
  if (!dist)
    return 0;
  try
  {
    return (int32_t)dist->dist.NbSolution();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTDistSSPointOnShape1(OCCTDistSSRef dist, int32_t index, double* x, double* y, double* z)
{
  if (!dist)
  {
    *x = *y = *z = 0;
    return;
  }
  try
  {
    gp_Pnt p = dist->dist.PointOnShape1(index);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
    *x = *y = *z = 0;
  }
}

void OCCTDistSSPointOnShape2(OCCTDistSSRef dist, int32_t index, double* x, double* y, double* z)
{
  if (!dist)
  {
    *x = *y = *z = 0;
    return;
  }
  try
  {
    gp_Pnt p = dist->dist.PointOnShape2(index);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
    *x = *y = *z = 0;
  }
}

int32_t OCCTDistSSSupportType1(OCCTDistSSRef dist, int32_t index)
{
  if (!dist)
    return -1;
  try
  {
    BRepExtrema_SupportType t = dist->dist.SupportTypeShape1(index);
    switch (t)
    {
      case BRepExtrema_IsVertex:
        return 0;
      case BRepExtrema_IsOnEdge:
        return 1;
      case BRepExtrema_IsInFace:
        return 2;
      default:
        return -1;
    }
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTDistSSSupportType2(OCCTDistSSRef dist, int32_t index)
{
  if (!dist)
    return -1;
  try
  {
    BRepExtrema_SupportType t = dist->dist.SupportTypeShape2(index);
    switch (t)
    {
      case BRepExtrema_IsVertex:
        return 0;
      case BRepExtrema_IsOnEdge:
        return 1;
      case BRepExtrema_IsInFace:
        return 2;
      default:
        return -1;
    }
  }
  catch (...)
  {
    return -1;
  }
}

OCCTShapeRef OCCTDistSSSupportShape1(OCCTDistSSRef dist, int32_t index)
{
  if (!dist)
    return nullptr;
  try
  {
    TopoDS_Shape s = dist->dist.SupportOnShape1(index);
    if (s.IsNull())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = s;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTDistSSSupportShape2(OCCTDistSSRef dist, int32_t index)
{
  if (!dist)
    return nullptr;
  try
  {
    TopoDS_Shape s = dist->dist.SupportOnShape2(index);
    if (s.IsNull())
      return nullptr;
    auto ref   = new OCCTShape();
    ref->shape = s;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}
