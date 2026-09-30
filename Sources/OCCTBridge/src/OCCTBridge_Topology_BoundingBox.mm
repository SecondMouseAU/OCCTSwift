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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
    occtRecordCaughtException(__func__);
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
