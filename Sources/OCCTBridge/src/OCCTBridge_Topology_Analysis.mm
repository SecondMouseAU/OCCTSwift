//
//  OCCTBridge_Topology_Analysis.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Topology.mm (#1380): ShapeAnalysis, BRepOffset_Analyse, ChFiDS,
//  ShapeExtend, ShapeUpgrade. Public C surface unchanged; every sibling file imports the same
//  headers this one does (the shared preamble below). No symbol changes, pure file move -- see
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
#include <BRepBuilderAPI_MakeFace.hxx>
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

OCCTShapeContents OCCTShapeGetContents(OCCTShapeRef shape)
{
  OCCTShapeContents result = {};
  if (!shape)
    return result;
  try
  {
    ShapeAnalysis_ShapeContents contents;
    contents.Perform(shape->shape);
    result.nbSolids    = contents.NbSolids();
    result.nbShells    = contents.NbShells();
    result.nbFaces     = contents.NbFaces();
    result.nbWires     = contents.NbWires();
    result.nbEdges     = contents.NbEdges();
    result.nbVertices  = contents.NbVertices();
    result.nbFreeEdges = contents.NbFreeEdges();
    result.nbFreeWires = contents.NbFreeWires();
    result.nbFreeFaces = contents.NbFreeFaces();
    return result;
  }
  catch (...)
  {
    return result;
  }
}

// #1026: occtShapeIsType (OCCTBridge_Internal.h) folds the pointer test together with the
// null-shape test the type read needs, so these three answer false for a null shape the way
// they already answered false for a shape of the wrong type, instead of dereferencing a null
// TShape.
bool OCCTEdgeHasCurve3D(OCCTShapeRef edge)
{
  if (!occtShapeIsType(edge, TopAbs_EDGE))
    return false;
  try
  {
    ShapeAnalysis_Edge analyzer;
    return analyzer.HasCurve3d(TopoDS::Edge(edge->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeIsClosed3D(OCCTShapeRef edge)
{
  if (!occtShapeIsType(edge, TopAbs_EDGE))
    return false;
  try
  {
    ShapeAnalysis_Edge analyzer;
    return analyzer.IsClosed3d(TopoDS::Edge(edge->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeIsSeam(OCCTShapeRef edge, OCCTShapeRef face)
{
  if (!occtShapeIsType(edge, TopAbs_EDGE) || !occtShapeIsType(face, TopAbs_FACE))
    return false;
  try
  {
    ShapeAnalysis_Edge analyzer;
    return analyzer.IsSeam(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
  }
  catch (...)
  {
    return false;
  }
}

OCCTSurfaceRef OCCTShapeFindSurface(OCCTShapeRef shape, double tolerance)
{
  OCCTFindSurfaceResult result =
    occtRunFindSurface(shape, tolerance, /*onlyPlane=*/false, OCCTFindSurfaceWant::Surface);
  return occtSurfaceRefOrNull(result);
}

// #1026: TopoDS_Wire::Closed() is TopoDS_Shape::Closed(), one of the eight flag accessors that
// dereference myTShape with no null test, so the wrapper's wire needs testing as well as the
// pointer. No public Swift producer hands back a null Wire today (Wire(_:) refuses one, since
// OCCTWireFromShape tests IsNull first), so this is a contract pin rather than a reachable crash.
//
// #1415: the analyzer's face was declared and never assigned (the comment claimed one was "created"
// but no SetFace/Init call existed), so ShapeAnalysis_Wire::Load(const TopoDS_Wire&) only ever set
// myWire, myFace stayed default-null, and IsReady() (== IsLoaded() && !myFace.IsNull()) was false
// on every call. CheckClosed/CheckSelfIntersection both early-return false on !IsReady() --
// confirmed directly against ShapeAnalysis_Wire.cxx/.lxx and reproduced live
// (Scripts/repro/1415-wire-analyze-face/) on the exact single-edge open-line case this issue was
// filed with: unfixed, CheckClosed() -> false unconditionally -> the bridge's `wire.Closed() ||
// !CheckClosed()` forced isClosed true for an OPEN wire, and CheckSelfIntersection() -> false
// unconditionally, silently reporting a genuinely self-intersecting wire as clean.
//
// Fixed in two parts, not one, because "just set a face" turns out not to fix isClosed:
//
// 1. hasSelfIntersection needs a real face. ShapeAnalysis_Wire's self-intersection check is
//    inherently 2D/pcurve-based (CheckSelfIntersectingEdge/CheckIntersectingEdges both fetch each
//    edge's pcurve via ShapeAnalysis_Edge::PCurve(edge, myFace, ...) and intersect those, not the
//    3D curves), so there is no face-free way to get a real answer out of this class. Build one via
//    BRepBuilderAPI_MakeFace(wire, /*OnlyPlane=*/true), the same pattern already used for a
//    face-less wire at OCCTWireFillet2D/OCCTWireFilletAll2D (OCCTBridge_Healing_Blends.mm): it fits
//    a plane through the wire and gives each edge a pcurve on it, which is what the intersection
//    check actually needs. This only succeeds for an (approximately) planar wire; a genuinely
//    non-planar 3D wire leaves the analyzer without a face and hasSelfIntersection reports false,
//    same as before this fix -- a real, acknowledged limitation of this OCCT class, not something a
//    face substitute can work around, and not new: it was never checkable for such wires either.
//
// 2. isClosed is NOT fixed by setting a face, even for a planar wire: CheckClosed()'s own contract
//    (ShapeAnalysis_Wire.hxx) is "true if at least one sub-check flagged a FIXABLE problem", so a
//    false return is ambiguous between "genuinely closed" and "endpoints are simply too far apart
//    to fix" (a FAIL, not a DONE) -- confirmed empirically: an open two-edge polyline with
//    endpoints 11 units apart at tolerance 1e-7, given a real face, still returns CheckClosed() ==
//    false, so
//    `!CheckClosed()` reads it as closed. `!analyzer.CheckClosed(tolerance)` was never a sound way
//    to compute isClosed, face or no face. Computed directly instead: TopoDS_Shape::Closed() (the
//    cheap flag BRepBuilderAPI_MakeWire sets when the wire's first and last vertices are literally
//    the same TopoDS_Vertex) first, then a genuine 3D coincidence check on the wire's endpoints
//    (TopExp::Vertices, matching OCCTWireVertices's own idiom two functions below) for wires built
//    by hand where the flag was never set. No face needed for this half at all.
bool OCCTWireAnalyze(OCCTWireRef wire, double tolerance, OCCTWireAnalysisResult* result)
{
  if (!wire || wire->wire.IsNull() || !result)
    return false;
  try
  {
    ShapeAnalysis_Wire analyzer;
    analyzer.Load(wire->wire);
    analyzer.SetPrecision(tolerance);

    // See part 1 above: only a planar wire can get a face this way, and only then can
    // CheckSelfIntersection do anything but silently report "clean".
    BRepBuilderAPI_MakeFace planarFace(wire->wire, /*OnlyPlane=*/true);
    if (planarFace.IsDone())
      analyzer.SetFace(planarFace.Face());

    // See part 2 above: independent of the face, a direct 3D endpoint check.
    bool isClosed = wire->wire.Closed();
    if (!isClosed)
    {
      TopoDS_Vertex vFirst, vLast;
      TopExp::Vertices(wire->wire, vFirst, vLast);
      if (!vFirst.IsNull() && !vLast.IsNull())
      {
        isClosed = vFirst.IsSame(vLast)
                   || BRep_Tool::Pnt(vFirst).Distance(BRep_Tool::Pnt(vLast)) <= tolerance;
      }
    }

    result->edgeCount           = analyzer.NbEdges();
    result->isClosed            = isClosed;
    result->hasSmallEdges       = analyzer.CheckSmall(tolerance);
    result->hasGaps3d           = analyzer.CheckGaps3d();
    result->hasSelfIntersection = analyzer.CheckSelfIntersection();
    result->isOrdered           = !analyzer.CheckOrder();
    result->minDistance3d       = analyzer.MinDistance3d();
    result->maxDistance3d       = analyzer.MaxDistance3d();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTSurfaceRef OCCTShapeFindSurfaceEx(OCCTShapeRef shape,
                                      double       tolerance,
                                      bool         onlyPlane,
                                      bool*        outFound)
{
  if (!shape || !outFound)
  {
    if (outFound)
      *outFound = false;
    return nullptr;
  }
  OCCTFindSurfaceResult result =
    occtRunFindSurface(shape, tolerance, onlyPlane, OCCTFindSurfaceWant::Surface);
  *outFound = result.found;
  return occtSurfaceRefOrNull(result);
}

// #613: both of these walked a bare TopExp_Explorer, one entry per OCCURRENCE, while Swift zips the
// result against edges() -- the deduplicated map. A 10mm box has 24 edge occurrences over 12 edges,
// so the two desynchronised from the first repeat and every classification after it landed on the
// wrong edge. Measured on an L-bracket (two fused boxes, inner corner at x=10, z=10): the one
// genuinely concave edge is map index 27, the analyser finds it (2 occurrences), and
// concaveEdges() returned an EMPTY array -- the issue's own failure scenario, where
// `bracket.filleted(edges: bracket.concaveEdges(), radius: 3)` rounds nothing and reports success.
// The count function was wrong on its own terms too: a 12-edge box reported 24 convex edges.
//
// Safe to read the map rather than the traversal, unlike the mesh entry points (#614): the edge is
// used only as a key into BRepOffset_Analyse's own myMapEdgeType, an
// NCollection_DataMap<..., TopTools_ShapeMapHasher> (BRepOffset_Analyse.hxx:173) whose equality IS
// TopoDS_Shape::IsSame (TopTools_ShapeMapHasher.hxx:35-38), so orientation cannot select a
// different entry. Confirmed by measurement rather than by reading the header: over all 12 edges of
// a box present in both orientations, Type() returned the same interval list for both, 0 differing.
//
// #1423: this classifier's `break` after the first interval and OCCTShapeCountEdgeConcavity's
// scan-every-interval below look like a real first-vs-any divergence -- BRepOffset_Interval's own
// header documents Type() as splitting an edge into "the parts... connecting the convex, concave or
// tangent faces", implying more than one interval per edge is a real possibility. It structurally
// is not, for this call path: BRepOffset_Analyse.cxx's own EdgeAnalyse() always appends exactly ONE
// interval per edge (spanning the edge's whole range, whatever ChFiDS_TypeOfConcavity it computes,
// including the ChFiDS_Mixed case for a spline-spline edge with a convex/concave transition -- that
// still collapses to one interval of type Mixed, not two of different types), and Type()'s only
// other writer, the artificial-tangent-face splitting in TreatTangentFaces(), is gated on
// myFaceOffsetMap, populated only by the explicit SetFaceOffsetMap() setter neither this function
// nor its sibling ever calls. So myMapEdgeType(edge).Extent() is provably always 0 or 1 through
// this analyser's (theShape, theAngle)-constructor-then-Type() path, confirmed both by reading
// BRepOffset_Analyse.cxx's every myMapEdgeType writer and empirically: probed a box, a box+sphere
// fuse, a fully-filleted box, a triangle-to-square ThruSections loft (BSpline side faces) and a
// cylinder+box fuse (122 edges total) and found maxIntervalsOnAnyEdge == 1 on every one
// (Scripts/repro/1423-edge-concavity-interval-count/). The `break`/scan-all difference is therefore
// dead code today, not a live bug: reachable divergence would need a caller that opts into
// SetFaceOffsetMap(), which neither entry point below does.
int32_t OCCTShapeAnalyzeEdgeConcavity(OCCTShapeRef       shape,
                                      double             angle,
                                      OCCTEdgeConcavity* outEdgeTypes,
                                      int32_t            maxEntries)
{
  if (!shape || !outEdgeTypes || maxEntries <= 0)
    return -1;
  try
  {
    BRepOffset_Analyse analyser(shape->shape, angle);
    if (!analyser.IsDone())
      return -1;

    TopTools_IndexedMapOfShape edgeMap;
    int32_t                    edgeCount = occtMapSubShapes(shape->shape, TopAbs_EDGE, edgeMap);

    int32_t count = 0;
    // No ShapeType re-check: occtMapSubShapes filters by TopAbs_EDGE, so every entry IS an edge.
    // A `continue` here would be worse than useless -- it would advance `i` without advancing
    // `count`, desynchronising the result array from edges(), which is the exact defect #613 fixes.
    for (int32_t i = 0; i < edgeCount && count < maxEntries; i++)
    {
      const auto& intervals = analyser.Type(TopoDS::Edge(edgeMap(i + 1))); // maps are 1-based
      // Use the first interval's type for the overall edge classification
      for (auto it = intervals.begin(); it != intervals.end(); ++it)
      {
        OCCTConcavityType type;
        if (it->Type() == ChFiDS_Convex)
          type = OCCTConcavityConvex;
        else if (it->Type() == ChFiDS_Concave)
          type = OCCTConcavityConcave;
        else
          type = OCCTConcavityTangent;
        outEdgeTypes[count].type = type;
        count++;
        break; // One classification per edge
      }
    }
    return count;
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTShapeCountEdgeConcavity(OCCTShapeRef shape, double angle, int32_t type)
{
  if (!shape)
    return -1;
  try
  {
    BRepOffset_Analyse analyser(shape->shape, angle);
    if (!analyser.IsDone())
      return -1;

    ChFiDS_TypeOfConcavity targetType;
    if (type == 0)
      targetType = ChFiDS_Convex;
    else if (type == 1)
      targetType = ChFiDS_Concave;
    else
      targetType = ChFiDS_Tangential;

    // #613: counted occurrences, so a 12-edge box reported 24 convex edges. Distinct edges now,
    // which is the number edgeCount reports and the number of entries the classifier above
    // fills.
    TopTools_IndexedMapOfShape edgeMap;
    int32_t                    edgeCount = occtMapSubShapes(shape->shape, TopAbs_EDGE, edgeMap);

    int32_t count = 0;
    for (int32_t i = 0; i < edgeCount; i++)
    {
      const auto& intervals = analyser.Type(TopoDS::Edge(edgeMap(i + 1)));
      for (auto it = intervals.begin(); it != intervals.end(); ++it)
      {
        if (it->Type() == targetType)
        {
          count++;
          break;
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

OCCTSurfaceRef OCCTFindSurface(OCCTShapeRef shape, double tolerance, bool onlyPlane)
{
  OCCTFindSurfaceResult result =
    occtRunFindSurface(shape, tolerance, onlyPlane, OCCTFindSurfaceWant::Surface);
  return occtSurfaceRefOrNull(result);
}

double OCCTFindSurfaceTolerance(OCCTShapeRef shape, double tolerance, bool onlyPlane)
{
  OCCTFindSurfaceResult result =
    occtRunFindSurface(shape, tolerance, onlyPlane, OCCTFindSurfaceWant::Tolerance);
  if (!result.found)
    return -1.0;
  return result.toleranceReached;
}

bool OCCTFindSurfaceExisted(OCCTShapeRef shape, double tolerance, bool onlyPlane)
{
  OCCTFindSurfaceResult result =
    occtRunFindSurface(shape, tolerance, onlyPlane, OCCTFindSurfaceWant::Existed);
  if (!result.found)
    return false;
  return result.existed;
}

int32_t OCCTAnalyseEdgeConcavity(OCCTShapeRef shape, double angle, int32_t* edgeTypes)
{
  try
  {
    BRepOffset_Analyse analyse(shape->shape, angle);
    if (!analyse.IsDone())
      return 0;
    NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> edges;
    TopExp::MapShapes(shape->shape, TopAbs_EDGE, edges);
    int32_t count = (int32_t)edges.Extent();
    if (edgeTypes)
    {
      for (int i = 1; i <= count; i++)
      {
        TopoDS_Edge                                  e         = TopoDS::Edge(edges(i));
        const NCollection_List<BRepOffset_Interval>& intervals = analyse.Type(e);
        if (intervals.IsEmpty())
        {
          edgeTypes[i - 1] = 4; // Other
        }
        else
        {
          edgeTypes[i - 1] = _mapConcavityBack(intervals.First().Type());
        }
      }
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTAnalyseExplode(OCCTShapeRef shape, double angle, int32_t concavityType)
{
  try
  {
    BRepOffset_Analyse analyse(shape->shape, angle);
    if (!analyse.IsDone())
      return nullptr;
    ChFiDS_TypeOfConcavity type = _mapConcavity(concavityType);
    TopTools_ListOfShape   groups;
    analyse.Explode(groups, type);
    if (groups.IsEmpty())
      return nullptr;
    // Build compound from all groups
    BRep_Builder    bb;
    TopoDS_Compound compound;
    bb.MakeCompound(compound);
    for (auto it = groups.cbegin(); it != groups.cend(); ++it)
    {
      bb.Add(compound, *it);
    }
    auto result   = new OCCTShape();
    result->shape = compound;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTAnalyseEdgesOnFace(OCCTShapeRef shape,
                               double       angle,
                               OCCTShapeRef face,
                               int32_t      concavityType)
{
  try
  {
    BRepOffset_Analyse analyse(shape->shape, angle);
    if (!analyse.IsDone())
      return 0;
    ChFiDS_TypeOfConcavity type = _mapConcavity(concavityType);
    TopoDS_Face            f    = TopoDS::Face(face->shape);
    TopTools_ListOfShape   edges;
    analyse.Edges(f, type, edges);
    return (int32_t)edges.Extent();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTAnalyseAncestorCount(OCCTShapeRef shape, double angle, OCCTShapeRef edge)
{
  try
  {
    BRepOffset_Analyse analyse(shape->shape, angle);
    if (!analyse.IsDone())
      return 0;
    if (!analyse.HasAncestor(edge->shape))
      return 0;
    const NCollection_List<TopoDS_Shape>& ancestors = analyse.Ancestors(edge->shape);
    return (int32_t)ancestors.Extent();
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTAnalyseTangentEdgeCount(OCCTShapeRef shape,
                                    double       angle,
                                    OCCTShapeRef edge,
                                    OCCTShapeRef vertex)
{
  try
  {
    BRepOffset_Analyse analyse(shape->shape, angle);
    if (!analyse.IsDone())
      return 0;
    TopoDS_Edge          e = TopoDS::Edge(edge->shape);
    TopoDS_Vertex        v = TopoDS::Vertex(vertex->shape);
    TopTools_ListOfShape tangents;
    analyse.TangentEdges(e, v, tangents);
    return (int32_t)tangents.Extent();
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTShapeMaxEdgeTolerance(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  try
  {
    ShapeAnalysis_ShapeTolerance sat;
    return sat.Tolerance(shape->shape, 1, TopAbs_EDGE); // 1 = max
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTShapeMaxFaceTolerance(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  try
  {
    ShapeAnalysis_ShapeTolerance sat;
    return sat.Tolerance(shape->shape, 1, TopAbs_FACE); // 1 = max
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTShapeMaxVertexTolerance(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  try
  {
    ShapeAnalysis_ShapeTolerance sat;
    return sat.Tolerance(shape->shape, 1, TopAbs_VERTEX); // 1 = max
  }
  catch (...)
  {
    return 0;
  }
}
