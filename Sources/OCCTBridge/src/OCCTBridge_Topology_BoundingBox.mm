//
//  OCCTBridge_Topology_BoundingBox.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Topology.mm (#1380): Bnd_OBB/Box/BoundSortBox, BRepClass3d,
//  BRepClass_FClassifier. Public C surface unchanged; every sibling file imports the same headers
//  this one does (the shared preamble below). No symbol changes, pure file move -- see
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

OCCTTopAbsState OCCTClassifyPointInSolid(OCCTShapeRef solid,
                                         double       px,
                                         double       py,
                                         double       pz,
                                         double       tolerance)
{
  if (!solid)
    return 3; // UNKNOWN

  try
  {
    BRepClass3d_SolidClassifier classifier(solid->shape, gp_Pnt(px, py, pz), tolerance);
    return mapTopAbsState(classifier.State());
  }
  catch (...)
  {
    return 3; // UNKNOWN
  }
}

OCCTTopAbsState OCCTClassifyPointOnFace(OCCTFaceRef face,
                                        double      px,
                                        double      py,
                                        double      pz,
                                        double      tolerance)
{
  if (!face)
    return 3; // UNKNOWN

  try
  {
    BRepClass_FaceClassifier classifier(face->face, gp_Pnt(px, py, pz), tolerance);
    return mapTopAbsState(classifier.State());
  }
  catch (...)
  {
    return 3; // UNKNOWN
  }
}

OCCTTopAbsState OCCTClassifyPointOnFaceUV(OCCTFaceRef face, double u, double v, double tolerance)
{
  if (!face)
    return 3; // UNKNOWN

  try
  {
    BRepClass_FaceClassifier classifier(face->face, gp_Pnt2d(u, v), tolerance);
    return mapTopAbsState(classifier.State());
  }
  catch (...)
  {
    return 3; // UNKNOWN
  }
}

bool OCCTShapeOrientedBoundingBox(OCCTShapeRef shape, bool optimal, OCCTOrientedBoundingBox* result)
{
  if (!shape || !result)
    return false;
  try
  {
    Bnd_OBB obb;
    BRepBndLib::AddOBB(shape->shape, obb, true, optimal, true);
    if (obb.IsVoid())
      return false;

    gp_XYZ center   = obb.Center();
    result->centerX = center.X();
    result->centerY = center.Y();
    result->centerZ = center.Z();

    gp_XYZ xDir   = obb.XDirection();
    result->xDirX = xDir.X();
    result->xDirY = xDir.Y();
    result->xDirZ = xDir.Z();
    gp_XYZ yDir   = obb.YDirection();
    result->yDirX = yDir.X();
    result->yDirY = yDir.Y();
    result->yDirZ = yDir.Z();
    gp_XYZ zDir   = obb.ZDirection();
    result->zDirX = zDir.X();
    result->zDirY = zDir.Y();
    result->zDirZ = zDir.Z();

    result->halfX = obb.XHSize();
    result->halfY = obb.YHSize();
    result->halfZ = obb.ZHSize();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTOrientedBoundingBoxVolume(const OCCTOrientedBoundingBox* result)
{
  if (!result)
    return 0.0;
  return 8.0 * result->halfX * result->halfY * result->halfZ;
}

void OCCTOrientedBoundingBoxCorners(const OCCTOrientedBoundingBox* result, double* outCorners)
{
  if (!result || !outCorners)
    return;
  gp_XYZ center(result->centerX, result->centerY, result->centerZ);
  gp_XYZ xDir(result->xDirX, result->xDirY, result->xDirZ);
  gp_XYZ yDir(result->yDirX, result->yDirY, result->yDirZ);
  gp_XYZ zDir(result->zDirX, result->zDirY, result->zDirZ);
  gp_XYZ hx = xDir * result->halfX;
  gp_XYZ hy = yDir * result->halfY;
  gp_XYZ hz = zDir * result->halfZ;

  // 8 corners: all combinations of +/- half-sizes
  int idx = 0;
  for (int sx = -1; sx <= 1; sx += 2)
  {
    for (int sy = -1; sy <= 1; sy += 2)
    {
      for (int sz = -1; sz <= 1; sz += 2)
      {
        gp_XYZ corner = center;
        corner += hx * sx;
        corner += hy * sy;
        corner += hz * sz;
        outCorners[idx++] = corner.X();
        outCorners[idx++] = corner.Y();
        outCorners[idx++] = corner.Z();
      }
    }
  }
}

OCCTOBBRef OCCTOBBCreate(double cx,
                         double cy,
                         double cz,
                         double xDirX,
                         double xDirY,
                         double xDirZ,
                         double yDirX,
                         double yDirY,
                         double yDirZ,
                         double zDirX,
                         double zDirY,
                         double zDirZ,
                         double hx,
                         double hy,
                         double hz)
{
  auto* ref = new OCCTOBB();
  try
  {
    ref->obb = Bnd_OBB(gp_Pnt(cx, cy, cz),
                       gp_Dir(xDirX, xDirY, xDirZ),
                       gp_Dir(yDirX, yDirY, yDirZ),
                       gp_Dir(zDirX, zDirY, zDirZ),
                       hx,
                       hy,
                       hz);
  }
  catch (...)
  {
    ref->obb =
      Bnd_OBB(gp_Pnt(cx, cy, cz), gp_Dir(1, 0, 0), gp_Dir(0, 1, 0), gp_Dir(0, 0, 1), hx, hy, hz);
  }
  return ref;
}

OCCTOBBRef OCCTOBBCreateFromShape(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    auto*   ref = new OCCTOBB();
    Bnd_Box bbox;
    BRepBndLib::Add(shape->shape, bbox);
    ref->obb = Bnd_OBB(bbox);
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTOBBRelease(OCCTOBBRef obb)
{
  delete obb;
}

bool OCCTOBBIsVoid(OCCTOBBRef obb)
{
  return obb->obb.IsVoid();
}

void OCCTOBBGetCenter(OCCTOBBRef obb, double* x, double* y, double* z)
{
  gp_XYZ c = obb->obb.Center();
  *x       = c.X();
  *y       = c.Y();
  *z       = c.Z();
}

void OCCTOBBGetHalfSizes(OCCTOBBRef obb, double* hx, double* hy, double* hz)
{
  *hx = obb->obb.XHSize();
  *hy = obb->obb.YHSize();
  *hz = obb->obb.ZHSize();
}

bool OCCTOBBIsOutPoint(OCCTOBBRef obb, double px, double py, double pz)
{
  return obb->obb.IsOut(gp_Pnt(px, py, pz));
}

bool OCCTOBBIsOutOBB(OCCTOBBRef obb1, OCCTOBBRef obb2)
{
  return obb1->obb.IsOut(obb2->obb);
}

void OCCTOBBEnlarge(OCCTOBBRef obb, double gap)
{
  obb->obb.Enlarge(gap);
}

double OCCTOBBSquareExtent(OCCTOBBRef obb)
{
  return obb->obb.SquareExtent();
}

// #851: this used to hand-build BRepClass3d_SolidExplorer + BRepClass3d_SClassifier, the exact
// pair BRepClass3d_SolidClassifier's own convenience constructor wraps internally (confirmed by
// reading BRepClass3d_SolidClassifier.hxx), duplicating OCCTClassifyPointInSolid's mechanism
// under a different, more verbose spelling. Routed through the same classifier + the shared
// mapTopAbsState() helper (declared above, ~line 387) so the two bridge functions can no longer
// silently diverge on tolerance handling or IN/OUT/ON/UNKNOWN mapping. Zero behavior change:
// TopAbs_State's ordinals already matched the raw (int32_t) cast this replaces.
int32_t OCCTShapeClassifyPoint(OCCTShapeRef shape,
                               double       px,
                               double       py,
                               double       pz,
                               double       tolerance)
{
  if (!shape)
    return 3; // UNKNOWN
  try
  {
    BRepClass3d_SolidClassifier classifier(shape->shape, gp_Pnt(px, py, pz), tolerance);
    return mapTopAbsState(classifier.State());
  }
  catch (...)
  {
    return 3;
  }
}

int32_t OCCTShapeClassifyPoint2D(OCCTShapeRef shape,
                                 int32_t      faceIndex,
                                 double       u,
                                 double       v,
                                 double       tolerance)
{
  if (!shape)
    return 3;
  try
  {
    TopoDS_Face face = occtFaceAt(shape->shape, faceIndex);
    if (face.IsNull())
      return 3;

    BRepClass_FaceExplorer explorer(face);
    BRepClass_FClassifier  classifier(explorer, gp_Pnt2d(u, v), tolerance);
    return (int32_t)classifier.State();
  }
  catch (...)
  {
    return 3;
  }
}

OCCTBoundSortBoxRef OCCTBoundSortBoxCreate(const double* boxData, int32_t count)
{
  try
  {
    auto* ref  = new OCCTBoundSortBox();
    ref->boxes = new NCollection_HArray1<Bnd_Box>(1, count);
    Bnd_Box enclosing;
    for (int i = 0; i < count; i++)
    {
      Bnd_Box b;
      b.Update(boxData[i * 6],
               boxData[i * 6 + 1],
               boxData[i * 6 + 2],
               boxData[i * 6 + 3],
               boxData[i * 6 + 4],
               boxData[i * 6 + 5]);
      ref->boxes->SetValue(i + 1, b);
      enclosing.Add(b);
    }
    ref->sorter.Initialize(enclosing, ref->boxes);
    return ref;
  }
  catch (...)
  {
    return new OCCTBoundSortBox();
  }
}

void OCCTBoundSortBoxRelease(OCCTBoundSortBoxRef bsb)
{
  delete bsb;
}

int32_t OCCTBoundSortBoxCompare(OCCTBoundSortBoxRef bsb,
                                double              xmin,
                                double              ymin,
                                double              zmin,
                                double              xmax,
                                double              ymax,
                                double              zmax,
                                int32_t*            outIndices,
                                int32_t             maxIndices)
{
  if (!bsb)
    return 0;
  try
  {
    Bnd_Box query;
    query.Update(xmin, ymin, zmin, xmax, ymax, zmax);
    auto&   result = bsb->sorter.Compare(query);
    int32_t total  = 0;
    for (auto it = result.cbegin(); it != result.cend(); ++it)
    {
      // Bnd_BoundSortBox returns OCCT's native 1-based indices (Bnd_BoundSortBox.hxx's own
      // doc on Add(): "The index is 1-based"); OCCTBoundSortBoxCreate stores caller box i
      // (0-based) at OCCT array position i+1, so translate back here to keep this bridge's
      // 0-based convention (#1462, finding 1).
      if (outIndices && total < maxIndices)
        outIndices[total] = (*it) - 1;
      total++;
    }
    // Count-then-fill: return the TOTAL count always, not the number written, so a caller can
    // detect truncation (return > maxIndices) and outIndices=NULL can be used as a sizing query
    // (#1462, finding 2).
    return total;
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTShapeOBBVolume(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  try
  {
    Bnd_OBB obb;
    BRepBndLib::AddOBB(shape->shape, obb);
    if (obb.IsVoid())
      return 0;
    // Volume = 8 * halfX * halfY * halfZ
    double hx = obb.XHSize(), hy = obb.YHSize(), hz = obb.ZHSize();
    return 8.0 * hx * hy * hz;
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTShapeBoundingDiagonal(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  try
  {
    Bnd_Box box;
    BRepBndLib::Add(shape->shape, box);
    if (box.IsVoid())
      return 0;
    double xMin, yMin, zMin, xMax, yMax, zMax;
    box.Get(xMin, yMin, zMin, xMax, yMax, zMax);
    double dx = xMax - xMin, dy = yMax - yMin, dz = zMax - zMin;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTShapeBoundingBox(OCCTShapeRef shape,
                          double*      xmin,
                          double*      ymin,
                          double*      zmin,
                          double*      xmax,
                          double*      ymax,
                          double*      zmax)
{
  if (!xmin || !ymin || !zmin || !xmax || !ymax || !zmax)
    return false;
  // A null shape needs the same zero-sentinel contract as every other failure path (#901 review
  // followup) -- the combined guard used to return before occtComputeBoundingBox's own zeroing
  // ever ran, leaving these untouched. Zero now that every pointer is known-writable, then guard
  // shape on its own.
  *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0.0;
  if (!shape)
    return false;
  auto* s = static_cast<OCCTShape*>(shape);
  return occtComputeBoundingBox(s->shape,
                                /*optimal=*/false,
                                /*useTriangulation=*/true,
                                /*useShapeTolerance=*/false,
                                *xmin,
                                *ymin,
                                *zmin,
                                *xmax,
                                *ymax,
                                *zmax);
}

bool OCCTShapeBoundingBoxOptimal(OCCTShapeRef shape,
                                 bool         useShapeTolerance,
                                 double*      xmin,
                                 double*      ymin,
                                 double*      zmin,
                                 double*      xmax,
                                 double*      ymax,
                                 double*      zmax)
{
  if (!xmin || !ymin || !zmin || !xmax || !ymax || !zmax)
    return false;
  // Same null-shape zero-sentinel gap as OCCTShapeBoundingBox above (#901 review followup).
  *xmin = *ymin = *zmin = *xmax = *ymax = *zmax = 0.0;
  if (!shape)
    return false;
  auto* s = static_cast<OCCTShape*>(shape);
  return occtComputeBoundingBox(s->shape,
                                /*optimal=*/true,
                                /*useTriangulation=*/true,
                                useShapeTolerance,
                                *xmin,
                                *ymin,
                                *zmin,
                                *xmax,
                                *ymax,
                                *zmax);
}

void OCCTShapeOrientedBoundingBoxDetailed(OCCTShapeRef shape,
                                          bool         isOptimal,
                                          double*      cx,
                                          double*      cy,
                                          double*      cz,
                                          double*      xDirX,
                                          double*      xDirY,
                                          double*      xDirZ,
                                          double*      yDirX,
                                          double*      yDirY,
                                          double*      yDirZ,
                                          double*      zDirX,
                                          double*      zDirY,
                                          double*      zDirZ,
                                          double*      xHSize,
                                          double*      yHSize,
                                          double*      zHSize,
                                          bool*        isVoid)
{
  // Delegates to OCCTShapeOrientedBoundingBox rather than building a second Bnd_OBB from a
  // second BRepBndLib::AddOBB call: both wrap the identical computation (#847), and delegating
  // also picks up that function's null-shape guard, which this site previously lacked.
  OCCTOrientedBoundingBox obb{};
  bool                    ok = OCCTShapeOrientedBoundingBox(shape, isOptimal, &obb);
  *isVoid                    = !ok;
  if (ok)
  {
    *cx     = obb.centerX;
    *cy     = obb.centerY;
    *cz     = obb.centerZ;
    *xDirX  = obb.xDirX;
    *xDirY  = obb.xDirY;
    *xDirZ  = obb.xDirZ;
    *yDirX  = obb.yDirX;
    *yDirY  = obb.yDirY;
    *yDirZ  = obb.yDirZ;
    *zDirX  = obb.zDirX;
    *zDirY  = obb.zDirY;
    *zDirZ  = obb.zDirZ;
    *xHSize = obb.halfX;
    *yHSize = obb.halfY;
    *zHSize = obb.halfZ;
  }
  else
  {
    *cx = *cy = *cz = 0.0;
    *xDirX          = 1;
    *xDirY          = 0;
    *xDirZ          = 0;
    *yDirX          = 0;
    *yDirY          = 1;
    *yDirZ          = 0;
    *zDirX          = 0;
    *zDirY          = 0;
    *zDirZ          = 1;
    *xHSize = *yHSize = *zHSize = 0.0;
  }
}
