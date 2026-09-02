//
//  OCCTBridge_Topology_ShapeQueries.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Topology.mm (#1380): BRep_Tool, BRepLib, BRepBuilderAPI, BRepAdaptor,
//  GCPnts, GProp, BRepLProp (the file's dominant, catch-all concern; default_bucket for everything
//  else). Public C surface unchanged; every sibling file imports the same headers this one does
//  (the shared preamble below). No symbol changes, pure file move -- see
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

// Outer shell of a solid (BRepClass3d::OuterShell), which distinguishes the outer body from
// internal void shells of a multi-shell solid. #211
OCCTShapeRef OCCTShapeOuterShell(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    TopoDS_Solid solid;
    if (!occtSoleSolid(shape->shape, solid))
      return nullptr;
    TopoDS_Shell shell = BRepClass3d::OuterShell(solid);
    if (shell.IsNull())
      return nullptr;
    return new OCCTShape(shell);
  }
  catch (...)
  {
    return nullptr;
  }
}

// Outer shell of every solid in a shape: the multi-solid counterpart of OCCTShapeOuterShell. #439
int32_t OCCTShapeOuterShells(OCCTShapeRef shape, OCCTShapeRef* outShells, int32_t maxCount)
{
  if (!shape)
    return 0;
  try
  {
    int32_t n = 0;
    for (TopExp_Explorer ex(shape->shape, TopAbs_SOLID); ex.More(); ex.Next())
    {
      // Sizing query: the solid count is an upper bound on the shells, and reaching it
      // costs one traversal. Classifying here instead would make a caller's count-then-fill
      // pay BRepClass3d::OuterShell twice per solid, real work on a multi-shell body,
      // where it runs a solid classification per candidate shell.
      if (!outShells)
      {
        n++;
        continue;
      }
      // Per-solid catch, so one unusable body is skipped rather than discarding every
      // other shell.
      TopoDS_Shell shell;
      try
      {
        shell = BRepClass3d::OuterShell(TopoDS::Solid(ex.Current()));
      }
      catch (...)
      {
        continue;
      }
      if (shell.IsNull())
        continue;
      if (n < maxCount)
        outShells[n] = new OCCTShape(shell);
      n++;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

// Inner (void/cavity) shells = every shell of the solid except the outer one. #212
int32_t OCCTShapeInnerShells(OCCTShapeRef shape, OCCTShapeRef* outShells, int32_t maxCount)
{
  if (!shape)
    return 0;
  try
  {
    TopoDS_Solid solid;
    if (!occtSoleSolid(shape->shape, solid))
      return 0;
    TopoDS_Shell outer = BRepClass3d::OuterShell(solid);
    int32_t      n     = 0;
    for (TopExp_Explorer ex(solid, TopAbs_SHELL); ex.More(); ex.Next())
    {
      const TopoDS_Shape& sh = ex.Current();
      if (!outer.IsNull() && sh.IsSame(outer))
        continue; // skip the outer shell
      if (outShells && n < maxCount)
        outShells[n] = new OCCTShape(sh);
      n++;
    }
    return n;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTShapeRef OCCTShapeCopy(OCCTShapeRef shape, bool copyGeom, bool copyMesh)
{
  if (!shape)
    return nullptr;
  try
  {
    BRepBuilderAPI_Copy copier(shape->shape, copyGeom, copyMesh);
    if (!copier.IsDone())
      return nullptr;
    TopoDS_Shape result = copier.Shape();
    if (result.IsNull())
      return nullptr;
    return new OCCTShape(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFromWire(OCCTWireRef wireRef)
{
  if (!wireRef)
    return nullptr;
  return new OCCTShape(wireRef->wire);
}

OCCTShapeRef OCCTShapeFromFace(OCCTFaceRef faceRef)
{
  if (!faceRef)
    return nullptr;
  return new OCCTShape(faceRef->face);
}

OCCTFaceRef OCCTFaceFromShape(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    if (shape->shape.IsNull())
      return nullptr;
    if (shape->shape.ShapeType() != TopAbs_FACE)
      return nullptr;
    return new OCCTFace(TopoDS::Face(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTWireRef OCCTWireFromShape(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    if (shape->shape.IsNull())
      return nullptr;
    if (shape->shape.ShapeType() != TopAbs_WIRE)
      return nullptr;
    return new OCCTWire(TopoDS::Wire(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTShapeRelease(OCCTShapeRef shape)
{
  delete shape;
}

void OCCTWireRelease(OCCTWireRef wire)
{
  delete wire;
}

void OCCTMeshRelease(OCCTMeshRef mesh)
{
  delete mesh;
}

int32_t OCCTShapeRevolutionAxes(OCCTShapeRef   shape,
                                double         tolerance,
                                OCCTShapeAxis* outAxes,
                                int32_t        maxAxes)
{
  if (!shape || !outAxes || maxAxes <= 0)
    return -1;
  try
  {
    std::vector<OCCTShapeAxis> collected;
    for (TopExp_Explorer ex(shape->shape, TopAbs_FACE); ex.More(); ex.Next())
    {
      TopoDS_Face         face = TopoDS::Face(ex.Current());
      BRepAdaptor_Surface adaptor(face);
      gp_Ax1              axis;
      int                 kind = 0;
      try
      {
        switch (adaptor.GetType())
        {
          case GeomAbs_Cylinder:
            axis = adaptor.Cylinder().Axis();
            kind = 1;
            break;
          case GeomAbs_Cone:
            axis = adaptor.Cone().Axis();
            kind = 2;
            break;
          case GeomAbs_Sphere: {
            gp_Sphere s = adaptor.Sphere();
            axis        = gp_Ax1(s.Location(), s.Position().Direction());
            kind        = 3;
            break;
          }
          case GeomAbs_Torus:
            axis = adaptor.Torus().Axis();
            kind = 4;
            break;
          case GeomAbs_SurfaceOfRevolution: {
            Handle(Geom_Surface)             surf = BRep_Tool::Surface(face);
            Handle(Geom_SurfaceOfRevolution) rev = Handle(Geom_SurfaceOfRevolution)::DownCast(surf);
            if (rev.IsNull())
              continue;
            axis = rev->Axis();
            kind = 5;
            break;
          }
          default:
            continue;
        }
      }
      catch (...)
      {
        continue;
      }
      const gp_Pnt& p   = axis.Location();
      const gp_Dir& d   = axis.Direction();
      bool          dup = false;
      for (const auto& existing : collected)
      {
        if (axesCoincide(existing, p.X(), p.Y(), p.Z(), d.X(), d.Y(), d.Z(), tolerance))
        {
          dup = true;
          break;
        }
      }
      if (dup)
        continue;
      OCCTShapeAxis a;
      a.originX    = p.X();
      a.originY    = p.Y();
      a.originZ    = p.Z();
      a.directionX = d.X();
      a.directionY = d.Y();
      a.directionZ = d.Z();
      occtComputeAxisExtent(face, p, d, a.extentMin, a.extentMax, a.hasExtent);
      a.kind = kind;
      collected.push_back(a);
    }
    int32_t count = std::min((int32_t)collected.size(), maxAxes);
    for (int32_t i = 0; i < count; i++)
      outAxes[i] = collected[i];
    return (int32_t)collected.size();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTShapeSymmetryAxes(OCCTShapeRef   shape,
                              double         fractionalTolerance,
                              OCCTShapeAxis* outAxes,
                              int32_t        maxAxes)
{
  if (!shape || !outAxes || maxAxes <= 0)
    return -1;
  try
  {
    GProp_GProps props;
    // A zero-mass framework has three equal (zero) moments, so GProp_PrincipalProps reports
    // BOTH HasSymmetryPoint() and HasSymmetryAxis() as true and the branch below hands back
    // three orthonormal axes through the location origin. Measured on a face, edge, wire and
    // vertex alike: spherical symmetry, from math_Jacobi's identity basis on a zero matrix.
    // Inertial symmetry detection is a volume question, so outside the volume domain the
    // answer is "no axes found", not "found three". See #609.
    if (!occtVolumeMassProperties(shape->shape, props))
      return 0;
    gp_Pnt               cm = props.CentreOfMass();
    GProp_PrincipalProps pp = props.PrincipalProperties();
    double               Ix, Iy, Iz;
    pp.Moments(Ix, Iy, Iz);
    gp_Vec                     v1         = pp.FirstAxisOfInertia();
    gp_Vec                     v2         = pp.SecondAxisOfInertia();
    gp_Vec                     v3         = pp.ThirdAxisOfInertia();
    double                     moments[3] = {Ix, Iy, Iz};
    gp_Vec                     axes[3]    = {v1, v2, v3};
    double                     maxM       = std::max({Ix, Iy, Iz});
    std::vector<OCCTShapeAxis> collected;
    if (pp.HasSymmetryPoint())
    {
      // Spherical: add all three principal axes (all equal).
      for (int i = 0; i < 3; i++)
      {
        OCCTShapeAxis a;
        a.originX    = cm.X();
        a.originY    = cm.Y();
        a.originZ    = cm.Z();
        a.directionX = axes[i].X();
        a.directionY = axes[i].Y();
        a.directionZ = axes[i].Z();
        occtComputeAxisExtent(shape->shape,
                              cm,
                              gp_Dir(axes[i].X(), axes[i].Y(), axes[i].Z()),
                              a.extentMin,
                              a.extentMax,
                              a.hasExtent);
        a.kind = 7;
        collected.push_back(a);
      }
    }
    else if (pp.HasSymmetryAxis())
    {
      // Rotational: the unique (different) moment's axis IS the symmetry axis.
      int uniqueIdx = 0;
      for (int i = 0; i < 3; i++)
      {
        int j = (i + 1) % 3, k = (i + 2) % 3;
        if (fabs(moments[j] - moments[k]) < fractionalTolerance * maxM
            && fabs(moments[i] - moments[j]) > fractionalTolerance * maxM)
        {
          uniqueIdx = i;
          break;
        }
      }
      OCCTShapeAxis a;
      a.originX    = cm.X();
      a.originY    = cm.Y();
      a.originZ    = cm.Z();
      a.directionX = axes[uniqueIdx].X();
      a.directionY = axes[uniqueIdx].Y();
      a.directionZ = axes[uniqueIdx].Z();
      occtComputeAxisExtent(shape->shape,
                            cm,
                            gp_Dir(axes[uniqueIdx].X(), axes[uniqueIdx].Y(), axes[uniqueIdx].Z()),
                            a.extentMin,
                            a.extentMax,
                            a.hasExtent);
      a.kind = 7;
      collected.push_back(a);
    }
    int32_t count = std::min((int32_t)collected.size(), maxAxes);
    for (int32_t i = 0; i < count; i++)
      outAxes[i] = collected[i];
    return (int32_t)collected.size();
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTSurfaceBSplineToBezierPatches(OCCTSurfaceRef  surface,
                                          OCCTSurfaceRef* outPatches,
                                          int32_t         maxPatches,
                                          int32_t*        outNbUPatches,
                                          int32_t*        outNbVPatches)
{
  if (!surface || !outPatches || !outNbUPatches || !outNbVPatches || maxPatches <= 0)
    return -1;
  try
  {
    Handle(Geom_BSplineSurface) bspline = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bspline.IsNull())
      return -1;

    GeomConvert_BSplineSurfaceToBezierSurface conv(bspline);
    int32_t                                   nbU = conv.NbUPatches();
    int32_t                                   nbV = conv.NbVPatches();
    *outNbUPatches                                = nbU;
    *outNbVPatches                                = nbV;

    int32_t total = nbU * nbV;
    int32_t count = std::min(total, maxPatches);

    int32_t idx = 0;
    for (int32_t u = 1; u <= nbU && idx < count; u++)
    {
      for (int32_t v = 1; v <= nbV && idx < count; v++)
      {
        Handle(Geom_BezierSurface) patch = conv.Patch(u, v);
        if (!patch.IsNull())
        {
          outPatches[idx] = new OCCTSurface(patch);
        }
        else
        {
          outPatches[idx] = nullptr;
        }
        idx++;
      }
    }
    return total;
  }
  catch (...)
  {
    return -1;
  }
}

int32_t OCCTCurve3DBSplineKnotSplits(OCCTCurve3DRef curve3D,
                                     int32_t        continuityOrder,
                                     double*        outParams,
                                     int32_t        maxParams)
{
  if (!curve3D || !outParams || maxParams <= 0)
    return -1;
  try
  {
    Handle(Geom_BSplineCurve) bspline = Handle(Geom_BSplineCurve)::DownCast(curve3D->curve);
    if (bspline.IsNull())
      return -1;

    GeomConvert_BSplineCurveKnotSplitting splitter(bspline, continuityOrder);
    return occtWriteKnotSplitParams(
      splitter.NbSplits(),
      [&](int32_t i) { return splitter.SplitValue(i); },
      [&](int32_t idx) { return bspline->Knot(idx); },
      outParams,
      maxParams);
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTShapeFindPlane(OCCTShapeRef shape,
                        double       tolerance,
                        double*      outNormalX,
                        double*      outNormalY,
                        double*      outNormalZ,
                        double*      outOriginX,
                        double*      outOriginY,
                        double*      outOriginZ)
{
  if (!shape || !outNormalX || !outNormalY || !outNormalZ || !outOriginX || !outOriginY
      || !outOriginZ)
    return false;
  try
  {
    BRepBuilderAPI_FindPlane finder(shape->shape, tolerance);
    if (!finder.Found())
      return false;

    Handle(Geom_Plane) plane = finder.Plane();
    if (plane.IsNull())
      return false;

    gp_Pln pln  = plane->Pln();
    gp_Dir norm = pln.Axis().Direction();
    gp_Pnt loc  = pln.Location();

    *outNormalX = norm.X();
    *outNormalY = norm.Y();
    *outNormalZ = norm.Z();
    *outOriginX = loc.X();
    *outOriginY = loc.Y();
    *outOriginZ = loc.Z();

    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeFirstVertex(OCCTShapeRef shape, double* x, double* y, double* z)
{
  try
  {
    TopoDS_Edge   edge = TopoDS::Edge(shape->shape);
    TopoDS_Vertex v    = TopExp::FirstVertex(edge);
    if (v.IsNull())
      return false;
    gp_Pnt p = BRep_Tool::Pnt(v);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeLastVertex(OCCTShapeRef shape, double* x, double* y, double* z)
{
  try
  {
    TopoDS_Edge   edge = TopoDS::Edge(shape->shape);
    TopoDS_Vertex v    = TopExp::LastVertex(edge);
    if (v.IsNull())
      return false;
    gp_Pnt p = BRep_Tool::Pnt(v);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeVertices(OCCTShapeRef shape,
                      double*      x1,
                      double*      y1,
                      double*      z1,
                      double*      x2,
                      double*      y2,
                      double*      z2)
{
  try
  {
    TopoDS_Edge   edge = TopoDS::Edge(shape->shape);
    TopoDS_Vertex v1, v2;
    TopExp::Vertices(edge, v1, v2);
    if (v1.IsNull() || v2.IsNull())
      return false;
    gp_Pnt p1 = BRep_Tool::Pnt(v1), p2 = BRep_Tool::Pnt(v2);
    *x1 = p1.X();
    *y1 = p1.Y();
    *z1 = p1.Z();
    *x2 = p2.X();
    *y2 = p2.Y();
    *z2 = p2.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTWireVertices(OCCTShapeRef shape,
                      double*      x1,
                      double*      y1,
                      double*      z1,
                      double*      x2,
                      double*      y2,
                      double*      z2)
{
  try
  {
    TopoDS_Wire   wire = TopoDS::Wire(shape->shape);
    TopoDS_Vertex v1, v2;
    TopExp::Vertices(wire, v1, v2);
    if (v1.IsNull())
      return false;
    gp_Pnt p1 = BRep_Tool::Pnt(v1);
    *x1       = p1.X();
    *y1       = p1.Y();
    *z1       = p1.Z();
    if (v2.IsNull())
    {
      *x2 = p1.X();
      *y2 = p1.Y();
      *z2 = p1.Z();
    }
    else
    {
      gp_Pnt p2 = BRep_Tool::Pnt(v2);
      *x2       = p2.X();
      *y2       = p2.Y();
      *z2       = p2.Z();
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeCommonVertex(OCCTShapeRef edge1, OCCTShapeRef edge2, double* x, double* y, double* z)
{
  try
  {
    TopoDS_Edge   e1 = TopoDS::Edge(edge1->shape);
    TopoDS_Edge   e2 = TopoDS::Edge(edge2->shape);
    TopoDS_Vertex v;
    if (!TopExp::CommonVertex(e1, e2, v))
      return false;
    gp_Pnt p = BRep_Tool::Pnt(v);
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTMakeVertex(double x, double y, double z)
{
  try
  {
    BRepLib_MakeVertex mv(gp_Pnt(x, y, z));
    TopoDS_Vertex      v = mv.Vertex();
    return new OCCTShape(v);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTShapeGetOrientation(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  return static_cast<int32_t>(shape->shape.Orientation());
}

void OCCTShapeSetOrientation(OCCTShapeRef shape, int32_t orientation)
{
  if (!shape)
    return;
  shape->shape.Orientation(occtOrientationFromInt(orientation));
}

OCCTShapeRef OCCTShapeReversed(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    auto result   = new OCCTShape();
    result->shape = shape->shape.Reversed();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeComplemented(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    auto result   = new OCCTShape();
    result->shape = shape->shape.Complemented();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeComposed(OCCTShapeRef shape, int32_t orientation)
{
  if (!shape)
    return nullptr;
  try
  {
    auto result   = new OCCTShape();
    result->shape = shape->shape.Composed(occtOrientationFromInt(orientation));
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #1026: ShapeType() is not the only unguarded myTShape dereference on TopoDS_Shape. Its eight flag
// accessors (Free, Locked, Modified, Checked, Orientable, Closed, Infinite, Convex), each with a
// getter and a setter, read and write the same packed state word with no null test either
// (TopoDS_Shape.hxx:143-188). Ten bridge sites reach them: the six here, OCCTShapeIsLocked and
// OCCTShapeSetLocked, OCCTShapeIsClosed, and OCCTWireAnalyze. All ten were measured crashing on a
// nullified shape, one test process each, in the repro directory.
//
// false is a refusal here, not the value a real shape would have answered anyway: measured on the
// pinned kernel, a box answers Free and Modified true, its shell Orientable and Closed true, and
// one of its faces Checked true. Infinite and Convex are false on every sub-shape of a box, so
// those two have no positive control, and the test suite says so rather than implying one.
bool OCCTShapeIsFree(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return false;
  return shape->shape.Free();
}

bool OCCTShapeIsModified(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return false;
  return shape->shape.Modified();
}

bool OCCTShapeIsChecked(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return false;
  return shape->shape.Checked();
}

bool OCCTShapeIsOrientable(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return false;
  return shape->shape.Orientable();
}

bool OCCTShapeIsInfinite(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return false;
  return shape->shape.Infinite();
}

bool OCCTShapeIsConvex(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return false;
  return shape->shape.Convex();
}

bool OCCTShapeIsEmpty(OCCTShapeRef shape)
{
  if (!shape)
    return true;
  return shape->shape.IsNull();
}

bool OCCTShapeIsPartner(OCCTShapeRef shape1, OCCTShapeRef shape2)
{
  if (!shape1 || !shape2)
    return false;
  return shape1->shape.IsPartner(shape2->shape);
}

bool OCCTShapeIsEqual(OCCTShapeRef shape1, OCCTShapeRef shape2)
{
  if (!shape1 || !shape2)
    return false;
  return shape1->shape.IsEqual(shape2->shape);
}

int32_t OCCTShapeNbChildren(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  return shape->shape.NbChildren();
}

int32_t OCCTShapeHashCode(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  return static_cast<int32_t>(std::hash<TopoDS_Shape>{}(shape->shape) & 0x7FFFFFFF);
}

void OCCTShapeClean(OCCTShapeRef shape)
{
  OCCTBRepToolsCleanTriangulation(shape);
}

void OCCTShapeCleanGeometry(OCCTShapeRef shape)
{
  if (!shape)
    return;
  try
  {
    BRepTools::CleanGeometry(shape->shape);
  }
  catch (...)
  {
  }
}

void OCCTShapeRemoveUnusedPCurves(OCCTShapeRef shape)
{
  if (!shape)
    return;
  try
  {
    BRepTools::RemoveUnusedPCurves(shape->shape);
  }
  catch (...)
  {
  }
}

void OCCTShapeUpdate(OCCTShapeRef shape)
{
  OCCTBRepToolsUpdate(shape);
}

bool OCCTBRepLibCheckSameRange(OCCTShapeRef edge)
{
  if (!edge)
    return false;
  try
  {
    return BRepLib::CheckSameRange(TopoDS::Edge(edge->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepLibSameRange(OCCTShapeRef edge, double tol)
{
  if (!edge)
    return false;
  try
  {
    BRepLib::SameRange(TopoDS::Edge(edge->shape), tol);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepLibBuildCurve3d(OCCTShapeRef edge, double tol)
{
  if (!edge)
    return false;
  try
  {
    return BRepLib::BuildCurve3d(TopoDS::Edge(edge->shape), tol);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTBRepLibUpdateTolerances(OCCTShapeRef shape)
{
  if (!shape)
    return;
  try
  {
    BRepLib::UpdateTolerances(shape->shape);
  }
  catch (...)
  {
  }
}

void OCCTBRepLibUpdateInnerTolerances(OCCTShapeRef shape)
{
  if (!shape)
    return;
  try
  {
    BRepLib::UpdateInnerTolerances(shape->shape);
  }
  catch (...)
  {
  }
}

bool OCCTBRepLibUpdateEdgeTolerance(OCCTShapeRef edge, double tol)
{
  if (!edge)
    return false;
  try
  {
    return BRepLib::UpdateEdgeTol(TopoDS::Edge(edge->shape), tol, tol * 100.0);
  }
  catch (...)
  {
    return false;
  }
}

OCCTCurve3DRef OCCTEdgeExtractCurve3D(OCCTShapeRef edge, double* first, double* last)
{
  *first = 0;
  *last  = 0;
  if (!occtShapeIsPresent(edge))
    return nullptr;
  try
  {
    double             f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(TopoDS::Edge(edge->shape), f, l);
    if (curve.IsNull())
      return nullptr;
    *first      = f;
    *last       = l;
    auto result = new OCCTCurve3D(curve);
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve2DRef OCCTEdgeExtractPCurve(OCCTShapeRef edge,
                                     OCCTShapeRef face,
                                     double*      first,
                                     double*      last)
{
  *first = 0;
  *last  = 0;
  if (!occtShapeIsPresent(edge) || !occtShapeIsPresent(face))
    return nullptr;
  try
  {
    double               f, l;
    Handle(Geom2d_Curve) pcurve =
      BRep_Tool::CurveOnSurface(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape), f, l);
    if (pcurve.IsNull())
      return nullptr;
    *first      = f;
    *last       = l;
    auto result = new OCCTCurve2D(pcurve);
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTEdgeGetTolerance(OCCTShapeRef edge)
{
  if (!occtShapeIsPresent(edge))
    return 0;
  try
  {
    return BRep_Tool::Tolerance(TopoDS::Edge(edge->shape));
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTEdgeIsDegenerated(OCCTShapeRef edge)
{
  if (!occtShapeIsPresent(edge))
    return false;
  try
  {
    return BRep_Tool::Degenerated(TopoDS::Edge(edge->shape));
  }
  catch (...)
  {
    return false;
  }
}

OCCTSurfaceRef OCCTFaceExtractSurface(OCCTShapeRef face)
{
  if (!occtShapeIsPresent(face))
    return nullptr;
  try
  {
    Handle(Geom_Surface) surf = BRep_Tool::Surface(TopoDS::Face(face->shape));
    if (surf.IsNull())
      return nullptr;
    return new OCCTSurface(surf);
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTFaceGetTolerance(OCCTShapeRef face)
{
  if (!occtShapeIsPresent(face))
    return 0;
  try
  {
    return BRep_Tool::Tolerance(TopoDS::Face(face->shape));
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTFaceWireCount(OCCTShapeRef face)
{
  if (!face)
    return 0;
  try
  {
    int count = 0;
    for (TopExp_Explorer ex(face->shape, TopAbs_WIRE); ex.More(); ex.Next())
      count++;
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTVertexGetTolerance(OCCTShapeRef vertex)
{
  if (!occtShapeIsPresent(vertex))
    return 0;
  try
  {
    return BRep_Tool::Tolerance(TopoDS::Vertex(vertex->shape));
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTVertexGetPoint(OCCTShapeRef vertex, double* x, double* y, double* z)
{
  *x = 0;
  *y = 0;
  *z = 0;
  if (!vertex)
    return;
  try
  {
    gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(vertex->shape));
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
  }
}

int32_t OCCTShapeCountFaces(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  try
  {
    int count = 0;
    for (TopExp_Explorer ex(shape->shape, TopAbs_FACE); ex.More(); ex.Next())
      count++;
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

int32_t OCCTShapeCountEdges(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  try
  {
    int count = 0;
    for (TopExp_Explorer ex(shape->shape, TopAbs_EDGE); ex.More(); ex.Next())
      count++;
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// #1026: "null" was already this function's word for an absent shape, so a wrapper carrying a null
// TopoDS_Shape gets the same word rather than a type name it does not have. It is distinct from the
// catch's "unknown" and from the default branch's "shape", so a caller can still tell the three
// apart.
char* OCCTShapeTypeString(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return strdup("null");
  try
  {
    switch (shape->shape.ShapeType())
    {
      case TopAbs_COMPOUND:
        return strdup("compound");
      case TopAbs_COMPSOLID:
        return strdup("compsolid");
      case TopAbs_SOLID:
        return strdup("solid");
      case TopAbs_SHELL:
        return strdup("shell");
      case TopAbs_FACE:
        return strdup("face");
      case TopAbs_WIRE:
        return strdup("wire");
      case TopAbs_EDGE:
        return strdup("edge");
      case TopAbs_VERTEX:
        return strdup("vertex");
      default:
        return strdup("shape");
    }
  }
  catch (...)
  {
    return strdup("unknown");
  }
}

OCCTShapeRef OCCTShapeChild(OCCTShapeRef shape, int32_t index)
{
  if (!shape)
    return nullptr;
  try
  {
    TopoDS_Iterator it(shape->shape);
    for (int32_t i = 0; i < index && it.More(); i++, it.Next())
    {
    }
    if (!it.More())
      return nullptr;
    OCCTShape* result = new OCCTShape();
    result->shape     = it.Value();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #1026: the same unguarded myTShape dereference as the six flag getters above, plus the one setter
// this bridge exposes. Writing a flag to a null shape has nothing to write it to, so the setter
// returns without writing, which is what it already did for a null pointer.
bool OCCTShapeIsLocked(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return false;
  return shape->shape.Locked();
}

void OCCTShapeSetLocked(OCCTShapeRef shape, bool locked)
{
  if (!occtShapeIsPresent(shape))
    return;
  shape->shape.Locked(locked);
}

void OCCTShapeGetLocation(OCCTShapeRef shape, double* matrix12)
{
  if (!shape)
    return;
  try
  {
    gp_Trsf t =
      shape->shape.Location().IsIdentity() ? gp_Trsf() : shape->shape.Location().Transformation();
    occtMatrix12InterleavedFromTrsf(t, matrix12);
  }
  catch (...)
  {
  }
}

void OCCTShapeSetLocation(OCCTShapeRef shape, const double* matrix12)
{
  if (!shape)
    return;
  try
  {
    shape->shape.Location(occtLocationFromMatrix12Interleaved(matrix12));
  }
  catch (...)
  {
  }
}

OCCTShapeRef OCCTShapeOriented(OCCTShapeRef shape, int32_t orientation)
{
  if (!shape)
    return nullptr;
  try
  {
    OCCTShape* result = new OCCTShape();
    result->shape     = shape->shape.Oriented(occtOrientationFromInt(orientation));
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #1026, a THIRD spelling of the same defect, and the reason the guard belongs at the unwrap
// rather than at each consumer. This function reaches no hazardous TopoDS_Shape member and casts
// nothing, so neither #1008's TopoDS:: sweep nor #1026's ShapeType() census covers it; it hands the
// shape to BRep_Builder::Add, and TopoDS_Builder::Add dereferences it in its FIRST statement,
// `aComponent.TShape()->Free(false)` (TopoDS_Builder.cxx). Measured: Shape.compound with a
// nullified shape is SIGSEGV, alone or alongside a real one.
//
// A null element refuses the whole call rather than being skipped, matching OCCTMakeWireFromEdges
// and OCCTMakeShell (#1008/#1027): a silently dropped element is a member the caller asked for and
// did not get. Swift cannot reach the null-POINTER case either way, since [Shape] maps through a
// non-optional handle.
OCCTShapeRef OCCTShapeCompounded(const OCCTShapeRef* shapes, int32_t count)
{
  if (count > 0 && !shapes)
    return nullptr;
  try
  {
    BRep_Builder    builder;
    TopoDS_Compound compound;
    builder.MakeCompound(compound);
    for (int32_t i = 0; i < count; i++)
    {
      if (!occtShapeIsPresent(shapes[i]))
        return nullptr;
      builder.Add(compound, shapes[i]->shape);
    }
    OCCTShape* result = new OCCTShape();
    result->shape     = compound;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeEmpty(int32_t type)
{
  try
  {
    BRep_Builder builder;
    OCCTShape*   result = new OCCTShape();
    switch (type)
    {
      case 0: { // COMPOUND
        TopoDS_Compound c;
        builder.MakeCompound(c);
        result->shape = c;
        break;
      }
      case 1: { // COMPSOLID
        TopoDS_CompSolid cs;
        builder.MakeCompSolid(cs);
        result->shape = cs;
        break;
      }
      case 2: { // SOLID
        TopoDS_Solid s;
        builder.MakeSolid(s);
        result->shape = s;
        break;
      }
      case 3: { // SHELL
        TopoDS_Shell sh;
        builder.MakeShell(sh);
        result->shape = sh;
        break;
      }
      case 5: { // WIRE
        TopoDS_Wire w;
        builder.MakeWire(w);
        result->shape = w;
        break;
      }
      default:
        delete result;
        return nullptr;
    }
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeWireFromEdges(const OCCTShapeRef* edges, int32_t count)
{
  try
  {
    BRepBuilderAPI_MakeWire mw;
    for (int32_t i = 0; i < count; i++)
    {
      if (!edges[i] || edges[i]->shape.IsNull() || edges[i]->shape.ShapeType() != TopAbs_EDGE)
        return nullptr;
      mw.Add(TopoDS::Edge(edges[i]->shape));
    }
    if (!mw.IsDone())
      return nullptr;
    OCCTShape* result = new OCCTShape();
    result->shape     = mw.Wire();
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTMakeCompound(const OCCTShapeRef* shapes, int32_t count)
{
  return OCCTShapeCompounded(shapes, count);
}

OCCTShapeRef OCCTMakeShell(const OCCTShapeRef* faces, int32_t count)
{
  try
  {
    BRep_Builder builder;
    TopoDS_Shell shell;
    builder.MakeShell(shell);
    for (int32_t i = 0; i < count; i++)
    {
      // #1008, the same guard as OCCTMakeWireFromEdges above: see the comment there.
      if (!faces[i] || faces[i]->shape.IsNull() || faces[i]->shape.ShapeType() != TopAbs_FACE)
        return nullptr;
      builder.Add(shell, TopoDS::Face(faces[i]->shape));
    }
    OCCTShape* result = new OCCTShape();
    result->shape     = shell;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #1026: each of these five asks "is this shape a T", and a null shape is not a T, so false is the
// answer rather than a stand-in for one. occtShapeIsType (OCCTBridge_Internal.h) is that question
// with the null shape rejected alongside the null pointer.
bool OCCTShapeIsCompound(OCCTShapeRef shape)
{
  return occtShapeIsType(shape, TopAbs_COMPOUND);
}

bool OCCTShapeIsSolid(OCCTShapeRef shape)
{
  return occtShapeIsType(shape, TopAbs_SOLID);
}

bool OCCTShapeIsShell(OCCTShapeRef shape)
{
  return occtShapeIsType(shape, TopAbs_SHELL);
}

bool OCCTShapeIsFace(OCCTShapeRef shape)
{
  return occtShapeIsType(shape, TopAbs_FACE);
}

bool OCCTShapeIsEdge(OCCTShapeRef shape)
{
  return occtShapeIsType(shape, TopAbs_EDGE);
}

OCCTShapeRef OCCTBuilderMakeWire()
{
  try
  {
    TopoDS_Builder builder;
    TopoDS_Wire    wire;
    builder.MakeWire(wire);
    auto ref   = new OCCTShape();
    ref->shape = wire;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBuilderMakeShell()
{
  try
  {
    TopoDS_Builder builder;
    TopoDS_Shell   shell;
    builder.MakeShell(shell);
    auto ref   = new OCCTShape();
    ref->shape = shell;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBuilderMakeSolid()
{
  try
  {
    TopoDS_Builder builder;
    TopoDS_Solid   solid;
    builder.MakeSolid(solid);
    auto ref   = new OCCTShape();
    ref->shape = solid;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBuilderMakeCompound()
{
  try
  {
    TopoDS_Builder  builder;
    TopoDS_Compound compound;
    builder.MakeCompound(compound);
    auto ref   = new OCCTShape();
    ref->shape = compound;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBuilderMakeCompSolid()
{
  try
  {
    TopoDS_Builder   builder;
    TopoDS_CompSolid cs;
    builder.MakeCompSolid(cs);
    auto ref   = new OCCTShape();
    ref->shape = cs;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #1026: the same TopoDS_Builder::Add dereference the two compound builders reach. Measured, both
// arguments crash on a nullified shape, so both are guarded.
bool OCCTBuilderAdd(OCCTShapeRef parent, OCCTShapeRef child)
{
  if (!occtShapeIsPresent(parent) || !occtShapeIsPresent(child))
    return false;
  try
  {
    TopoDS_Builder builder;
    builder.Add(parent->shape, child->shape);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// #1026: the PARENT crashes here, measured. The child does not: TopoDS_Builder::Remove walks the
// parent's children looking for it and never dereferences the one it is given, confirmed against
// both an empty and a populated parent. It is guarded anyway, in the same expression, because
// resting one argument of a two-argument builder call on an emptiness of OCCT's current internals
// is not worth the one comparison it saves.
bool OCCTBuilderRemove(OCCTShapeRef parent, OCCTShapeRef child)
{
  if (!occtShapeIsPresent(parent) || !occtShapeIsPresent(child))
    return false;
  try
  {
    TopoDS_Builder builder;
    builder.Remove(parent->shape, child->shape);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepLibOrientClosedSolid(OCCTShapeRef shape)
{
  if (!shape)
    return false;
  try
  {
    TopoDS_Solid solid = TopoDS::Solid(shape->shape);
    return BRepLib::OrientClosedSolid(solid);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepLibBuildCurves3dForShape(OCCTShapeRef shape, double tolerance)
{
  if (!shape)
    return false;
  try
  {
    // The catch is load-bearing: an edge with no 3D curve and no pcurve at all reaches
    // BuildCurve3d's approximation branch, which dereferences the pcurve handle it never
    // found and throws Standard_NullObject. Report that as failure, not as a crash. #498.
    return BRepLib::BuildCurves3d(shape->shape, tolerance);
  }
  catch (...)
  {
    return false;
  }
}

OCCTShapeRef OCCTBRepLibSortFaces(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    NCollection_List<TopoDS_Shape> faceList;
    BRepLib::SortFaces(shape->shape, faceList);
    BRep_Builder    builder;
    TopoDS_Compound compound;
    builder.MakeCompound(compound);
    for (auto it = faceList.cbegin(); it != faceList.cend(); ++it)
    {
      builder.Add(compound, *it);
    }
    auto ref   = new OCCTShape();
    ref->shape = compound;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTBRepLibReverseSortFaces(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    NCollection_List<TopoDS_Shape> faceList;
    BRepLib::ReverseSortFaces(shape->shape, faceList);
    BRep_Builder    builder;
    TopoDS_Compound compound;
    builder.MakeCompound(compound);
    for (auto it = faceList.cbegin(); it != faceList.cend(); ++it)
    {
      builder.Add(compound, *it);
    }
    auto ref   = new OCCTShape();
    ref->shape = compound;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

double OCCTShapeEdgeTolerance(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return 0;
  try
  {
    return BRep_Tool::Tolerance(TopoDS::Edge(shape->shape));
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTShapeFaceTolerance(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return 0;
  try
  {
    return BRep_Tool::Tolerance(TopoDS::Face(shape->shape));
  }
  catch (...)
  {
    return 0;
  }
}

double OCCTShapeVertexTolerance(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return 0;
  try
  {
    return BRep_Tool::Tolerance(TopoDS::Vertex(shape->shape));
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTShapeVertexPoint(OCCTShapeRef shape, double* x, double* y, double* z)
{
  if (!shape)
  {
    *x = *y = *z = 0;
    return;
  }
  try
  {
    gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(shape->shape));
    *x       = p.X();
    *y       = p.Y();
    *z       = p.Z();
  }
  catch (...)
  {
    *x = *y = *z = 0;
  }
}

OCCTCurve3DRef OCCTShapeEdgeCurve(OCCTShapeRef shape, double* first, double* last)
{
  if (!occtShapeIsPresent(shape))
  {
    *first = *last = 0;
    return nullptr;
  }
  try
  {
    double             f, l;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(TopoDS::Edge(shape->shape), f, l);
    if (curve.IsNull())
    {
      *first = *last = 0;
      return nullptr;
    }
    *first     = f;
    *last      = l;
    auto ref   = new OCCTCurve3D();
    ref->curve = curve;
    return ref;
  }
  catch (...)
  {
    *first = *last = 0;
    return nullptr;
  }
}

OCCTSurfaceRef OCCTShapeFaceSurface(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return nullptr;
  try
  {
    Handle(Geom_Surface) surf = BRep_Tool::Surface(TopoDS::Face(shape->shape));
    if (surf.IsNull())
      return nullptr;
    auto ref     = new OCCTSurface();
    ref->surface = surf;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #1026: the ninth flag site, same unguarded myTShape dereference.
bool OCCTShapeIsClosed(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return false;
  return shape->shape.Closed();
}

int32_t OCCTShapeUniqueEdgeCount(OCCTShapeRef shape)
{
  return OCCTShapeUniqueSubShapeCount(shape, 6); // TopAbs_EDGE
}

int32_t OCCTShapeUniqueFaceCount(OCCTShapeRef shape)
{
  return OCCTShapeUniqueSubShapeCount(shape, 4); // TopAbs_FACE
}

int32_t OCCTShapeUniqueVertexCount(OCCTShapeRef shape)
{
  return OCCTShapeUniqueSubShapeCount(shape, 7); // TopAbs_VERTEX
}

OCCTShapeRef OCCTShapeEmptyCopied(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    auto ref   = new OCCTShape();
    ref->shape = shape->shape.EmptyCopied();
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// occtAdaptorParameterAtLength (OCCTBridge_Internal.h), so the parameter this returns and the
// length OCCTEdgeArcLength reports are built from the same subdivided quadratures. #603.
double OCCTEdgeParameterAtArcLength(OCCTShapeRef edge, double arcLength, double startParam)
{
  if (!occtShapeIsPresent(edge))
    return 0;
  try
  {
    BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
    double            parameter = 0;
    if (occtAdaptorParameterAtLength(adaptor, arcLength, startParam, parameter))
      return parameter;
    return 0;
  }
  catch (...)
  {
    return 0;
  }
}

// Both edge arc-length entry points report failure as -1.0, matching every other arc-length
// function in the bridge (OCCTCurve3DGetLength/GetLengthBetween, OCCTCurve2D*): arc length is
// never negative, so -1.0 cannot be confused with a measurement, while the 0 these two used to
// return is exactly what a genuine zero-width interval measures. #548.
double OCCTEdgeArcLength(OCCTShapeRef edge)
{
  if (!occtShapeIsPresent(edge))
    return -1.0;
  try
  {
    BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
    // Subdivided per GeomAbs_CN interval: an elliptical edge measured 1.485% long on the
    // single quadrature GCPnts hands a one-interval curve. #603.
    return occtAdaptorArcLength(adaptor, adaptor.FirstParameter(), adaptor.LastParameter());
  }
  catch (...)
  {
    return -1.0;
  }
}

// A non-finite bound was the worst case of the three ranged entry points: with no sentinel at all
// here, `Length(adaptor, u1, .nan)` on a straight edge returned NaN straight through to Swift, and
// on a multi-span edge the plausible 0 / whole-length answers of #548. See
// occtValidParameterRange (OCCTBridge_Internal.h).
double OCCTEdgeArcLengthBetween(OCCTShapeRef edge, double u1, double u2)
{
  if (!occtShapeIsPresent(edge))
    return -1.0;
  if (!occtValidParameterRange(u1, u2))
    return -1.0;
  try
  {
    BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
    // Shared with the Curve3D/Curve2D spellings, so an edge and the curve it was built from
    // answer an out-of-domain range identically. #600.
    return occtAdaptorLengthBetween(adaptor, u1, u2);
  }
  catch (...)
  {
    return -1.0;
  }
}

// A single, un-subdivided quadrature -- occtArcQuadrature's own single-span branch, i.e. exactly
// the GCPnts_AbscissaPoint::Length call GCPnts_UniformAbscissa's constructor makes internally to
// learn a curve's length before placing points. Unlike OCCTEdgeArcLengthBetween this does not
// subdivide per GeomAbs_CN interval or double until two levels converge to 1e-9 relative, so a
// caller bounding an implied sample count before running that constructor gets the estimate for
// about what one of its own internal calls costs, not the ~2x an accurate OCCTEdgeArcLengthBetween
// costs on top of it (#603's own bridge subdivision is already redundant at the pinned kernel,
// whose CPnts_AbscissaPoint::Length is itself adaptive -- this reaches that directly rather than
// paying for the extra convergence loop too). #862.
double OCCTEdgeArcLengthQuickEstimate(OCCTShapeRef edge, double u1, double u2)
{
  if (!occtShapeIsPresent(edge))
    return -1.0;
  if (!occtValidParameterRange(u1, u2))
    return -1.0;
  try
  {
    BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
    return occtArcQuadrature(adaptor, std::min(u1, u2), std::max(u1, u2), /*singleSpan=*/true);
  }
  catch (...)
  {
    return -1.0;
  }
}

// Both halves subdivided (#603): the fraction is taken of the accurate total and then walked with
// the same quadratures, so fraction 1.0 lands on the edge's last parameter again. On the biased
// pair those two errors cancelled; on a mixed pair they would not.
double OCCTEdgeParameterAtFraction(OCCTShapeRef edge, double fraction)
{
  if (!occtShapeIsPresent(edge))
    return 0;
  try
  {
    BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
    const double      first     = adaptor.FirstParameter();
    double            totalLen  = occtAdaptorArcLength(adaptor, first, adaptor.LastParameter());
    double            targetLen = totalLen * fraction;
    double            parameter = 0;
    if (occtAdaptorParameterAtLength(adaptor, targetLen, first, parameter))
      return parameter;
    return 0;
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTEdgeAdaptorDomain(OCCTShapeRef edge, double* first, double* last)
{
  *first = *last = 0;
  if (!occtShapeIsPresent(edge))
    return;
  try
  {
    BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
    *first = adaptor.FirstParameter();
    *last  = adaptor.LastParameter();
  }
  catch (...)
  {
  }
}

void OCCTEdgeAdaptorValue(OCCTShapeRef edge, double param, double* x, double* y, double* z)
{
  *x = *y = *z = 0;
  if (!occtShapeIsPresent(edge))
    return;
  try
  {
    BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
    gp_Pnt            p = adaptor.Value(param);
    *x                  = p.X();
    *y                  = p.Y();
    *z                  = p.Z();
  }
  catch (...)
  {
  }
}

int32_t OCCTEdgeAdaptorCurveType(OCCTShapeRef edge)
{
  if (!occtShapeIsPresent(edge))
    return -1;
  try
  {
    BRepAdaptor_Curve adaptor(TopoDS::Edge(edge->shape));
    return (int32_t)adaptor.GetType();
  }
  catch (...)
  {
    return -1;
  }
}

void OCCTFaceAdaptorBounds(OCCTShapeRef face,
                           double*      uMin,
                           double*      uMax,
                           double*      vMin,
                           double*      vMax)
{
  *uMin = *uMax = *vMin = *vMax = 0;
  if (!face)
    return;
  try
  {
    BRepAdaptor_Surface adaptor(TopoDS::Face(face->shape));
    *uMin = adaptor.FirstUParameter();
    *uMax = adaptor.LastUParameter();
    *vMin = adaptor.FirstVParameter();
    *vMax = adaptor.LastVParameter();
  }
  catch (...)
  {
  }
}

void OCCTFaceAdaptorValue(OCCTShapeRef face, double u, double v, double* x, double* y, double* z)
{
  *x = *y = *z = 0;
  if (!face)
    return;
  try
  {
    BRepAdaptor_Surface adaptor(TopoDS::Face(face->shape));
    gp_Pnt              p = adaptor.Value(u, v);
    *x                    = p.X();
    *y                    = p.Y();
    *z                    = p.Z();
  }
  catch (...)
  {
  }
}

int32_t OCCTFaceAdaptorSurfaceType(OCCTShapeRef face)
{
  if (!face)
    return -1;
  try
  {
    BRepAdaptor_Surface adaptor(TopoDS::Face(face->shape));
    return (int32_t)adaptor.GetType();
  }
  catch (...)
  {
    return -1;
  }
}

bool OCCTShapeHasFreeEdges(OCCTShapeRef shape)
{
  if (!shape)
    return false;
  try
  {
    // Count edges that appear in only one face
    TopTools_IndexedDataMapOfShapeListOfShape edgeFaceMap;
    TopExp::MapShapesAndAncestors(shape->shape, TopAbs_EDGE, TopAbs_FACE, edgeFaceMap);
    for (int i = 1; i <= edgeFaceMap.Extent(); i++)
    {
      if (edgeFaceMap(i).Extent() < 2)
        return true;
    }
    return false;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeHasFreeWires(OCCTShapeRef shape)
{
  if (!shape)
    return false;
  try
  {
    TopTools_IndexedDataMapOfShapeListOfShape wireFaceMap;
    TopExp::MapShapesAndAncestors(shape->shape, TopAbs_WIRE, TopAbs_FACE, wireFaceMap);
    for (int i = 1; i <= wireFaceMap.Extent(); i++)
    {
      if (wireFaceMap(i).Extent() < 1)
        return true;
    }
    return false;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeHasFreeFaces(OCCTShapeRef shape)
{
  if (!shape)
    return false;
  try
  {
    TopTools_IndexedDataMapOfShapeListOfShape faceShellMap;
    TopExp::MapShapesAndAncestors(shape->shape, TopAbs_FACE, TopAbs_SHELL, faceShellMap);
    for (int i = 1; i <= faceShellMap.Extent(); i++)
    {
      if (faceShellMap(i).Extent() < 1)
        return true;
    }
    return false;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTShapeCentroid(OCCTShapeRef shape, double* x, double* y, double* z)
{
  if (!shape || !x || !y || !z)
    return false;
  try
  {
    GProp_GProps props;
    if (!occtVolumeMassProperties(shape->shape, props))
      return false;
    gp_Pnt cg = props.CentreOfMass();
    *x        = cg.X();
    *y        = cg.Y();
    *z        = cg.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTShapeTotalEdgeLength(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  try
  {
    GProp_GProps props;
    BRepGProp::LinearProperties(shape->shape, props);
    return props.Mass();
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTShapeTransformFromMatrix(OCCTShapeRef  shape,
                                  double        a11,
                                  double        a12,
                                  double        a13,
                                  double        a14,
                                  double        a21,
                                  double        a22,
                                  double        a23,
                                  double        a24,
                                  double        a31,
                                  double        a32,
                                  double        a33,
                                  double        a34,
                                  OCCTShapeRef* result)
{
  try
  {
    auto*   s = static_cast<OCCTShape*>(shape);
    gp_Trsf trsf;
    trsf.SetValues(a11, a12, a13, a14, a21, a22, a23, a24, a31, a32, a33, a34);
    BRepBuilderAPI_Transform xform(s->shape, trsf, true);
    if (xform.IsDone())
    {
      auto* r  = new OCCTShape();
      r->shape = xform.Shape();
      *result  = r;
    }
    else
    {
      *result = nullptr;
    }
  }
  catch (...)
  {
    *result = nullptr;
  }
}

bool OCCTEdgesCommonVertex(OCCTShapeRef edge1, OCCTShapeRef edge2, double* x, double* y, double* z)
{
  try
  {
    auto*         s1 = static_cast<OCCTShape*>(edge1);
    auto*         s2 = static_cast<OCCTShape*>(edge2);
    TopoDS_Edge   e1 = TopoDS::Edge(s1->shape);
    TopoDS_Edge   e2 = TopoDS::Edge(s2->shape);
    TopoDS_Vertex cv;
    if (TopExp::CommonVertex(e1, e2, cv))
    {
      gp_Pnt p = BRep_Tool::Pnt(cv);
      *x       = p.X();
      *y       = p.Y();
      *z       = p.Z();
      return true;
    }
    return false;
  }
  catch (...)
  {
    return false;
  }
}

// === BRep_Tool extras ===
bool OCCTEdgeSameParameter(OCCTShapeRef edge)
{
  try
  {
    auto* s = static_cast<OCCTShape*>(edge);
    return BRep_Tool::SameParameter(TopoDS::Edge(s->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeSameRange(OCCTShapeRef edge)
{
  try
  {
    auto* s = static_cast<OCCTShape*>(edge);
    return BRep_Tool::SameRange(TopoDS::Edge(s->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceNaturalRestriction(OCCTShapeRef face)
{
  try
  {
    auto* s = static_cast<OCCTShape*>(face);
    return BRep_Tool::NaturalRestriction(TopoDS::Face(s->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeIsGeometric(OCCTShapeRef edge)
{
  try
  {
    auto* s = static_cast<OCCTShape*>(edge);
    return BRep_Tool::IsGeometric(TopoDS::Edge(s->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceIsGeometric(OCCTShapeRef face)
{
  try
  {
    auto* s = static_cast<OCCTShape*>(face);
    return BRep_Tool::IsGeometric(TopoDS::Face(s->shape));
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepLibEnsureNormalConsistency(OCCTShapeRef shape, double maxAngleRad)
{
  if (!shape)
    return false;
  try
  {
    return BRepLib::EnsureNormalConsistency(shape->shape, maxAngleRad);
  }
  catch (...)
  {
    return false;
  }
}

void OCCTBRepLibUpdateDeflection(OCCTShapeRef shape)
{
  if (!shape)
    return;
  try
  {
    BRepLib::UpdateDeflection(shape->shape);
  }
  catch (...)
  {
  }
}

int32_t OCCTBRepLibContinuityOfFaces(OCCTShapeRef edge,
                                     OCCTShapeRef face1,
                                     OCCTShapeRef face2,
                                     double       tolerance)
{
  if (!edge || !face1 || !face2)
    return -1;
  try
  {
    GeomAbs_Shape cont = BRepLib::ContinuityOfFaces(TopoDS::Edge(edge->shape),
                                                    TopoDS::Face(face1->shape),
                                                    TopoDS::Face(face2->shape),
                                                    tolerance);
    return (int32_t)cont;
  }
  catch (...)
  {
    return -1;
  }
}

void OCCTBRepLibSameParameterAll(OCCTShapeRef shape, double tolerance, bool forced)
{
  if (!shape)
    return;
  try
  {
    BRepLib::SameParameter(shape->shape, tolerance, forced);
  }
  catch (...)
  {
  }
}

OCCTShapeRef OCCTShapeNullified(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    TopoDS_Shape s = shape->shape;
    s.Nullify();
    return new OCCTShape{s};
  }
  catch (...)
  {
    return nullptr;
  }
}

// #1026: nullptr, which Swift reads as nil, is already this function's answer for a shape it has no
// name for, and its Swift doc comment already promised "nil if the shape is null". Before this
// guard that promise held only for a null POINTER, which Swift cannot produce; a wrapper carrying a
// null TopoDS_Shape, which Shape.nullified hands out, crashed instead of keeping it.
const char* OCCTShapeTypeName(OCCTShapeRef shape)
{
  if (!occtShapeIsPresent(shape))
    return nullptr;
  switch (shape->shape.ShapeType())
  {
    case TopAbs_COMPOUND:
      return "COMPOUND";
    case TopAbs_COMPSOLID:
      return "COMPSOLID";
    case TopAbs_SOLID:
      return "SOLID";
    case TopAbs_SHELL:
      return "SHELL";
    case TopAbs_FACE:
      return "FACE";
    case TopAbs_WIRE:
      return "WIRE";
    case TopAbs_EDGE:
      return "EDGE";
    case TopAbs_VERTEX:
      return "VERTEX";
    case TopAbs_SHAPE:
      return "SHAPE";
    default:
      return "UNKNOWN";
  }
}

bool OCCTShapeIsNotEqual(OCCTShapeRef shape1, OCCTShapeRef shape2)
{
  if (!shape1 || !shape2)
    return true;
  return !shape1->shape.IsEqual(shape2->shape);
}

OCCTShapeRef OCCTShapeEmptied(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    TopoDS_Shape s = shape->shape.EmptyCopied();
    if (s.IsNull())
      return nullptr;
    return new OCCTShape{s};
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTShapeOrientationValue(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  return (int32_t)shape->shape.Orientation();
}

OCCTCurve2DRef OCCTBRepToolCurveOnSurface(OCCTShapeRef edge,
                                          OCCTShapeRef face,
                                          double*      outFirst,
                                          double*      outLast)
{
  if (!edge || !face)
    return nullptr;
  try
  {
    const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
    const TopoDS_Face& f = TopoDS::Face(face->shape);
    double             first, last;
    auto               c2d = BRep_Tool::CurveOnSurface(e, f, first, last);
    if (c2d.IsNull())
      return nullptr;
    *outFirst     = first;
    *outLast      = last;
    auto* result  = new OCCTCurve2D();
    result->curve = c2d;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTBRepToolHasContinuity(OCCTShapeRef edge, OCCTShapeRef face1, OCCTShapeRef face2)
{
  if (!edge || !face1 || !face2)
    return false;
  try
  {
    const TopoDS_Edge& e  = TopoDS::Edge(edge->shape);
    const TopoDS_Face& f1 = TopoDS::Face(face1->shape);
    const TopoDS_Face& f2 = TopoDS::Face(face2->shape);
    return BRep_Tool::HasContinuity(e, f1, f2);
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTBRepToolContinuity(OCCTShapeRef edge, OCCTShapeRef face1, OCCTShapeRef face2)
{
  if (!edge || !face1 || !face2)
    return 0;
  try
  {
    const TopoDS_Edge& e  = TopoDS::Edge(edge->shape);
    const TopoDS_Face& f1 = TopoDS::Face(face1->shape);
    const TopoDS_Face& f2 = TopoDS::Face(face2->shape);
    return (int32_t)BRep_Tool::Continuity(e, f1, f2);
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTBRepToolHasAnyContinuity(OCCTShapeRef edge)
{
  if (!edge)
    return false;
  try
  {
    const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
    return BRep_Tool::HasContinuity(e);
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTBRepToolMaxContinuity(OCCTShapeRef edge)
{
  if (!edge)
    return 0;
  try
  {
    const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
    return (int32_t)BRep_Tool::MaxContinuity(e);
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTBRepToolDegenerated(OCCTShapeRef edge)
{
  if (!edge)
    return false;
  try
  {
    const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
    return BRep_Tool::Degenerated(e);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepToolNaturalRestriction(OCCTShapeRef face)
{
  if (!face)
    return false;
  try
  {
    const TopoDS_Face& f = TopoDS::Face(face->shape);
    return BRep_Tool::NaturalRestriction(f);
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepToolRangeOnFace(OCCTShapeRef edge,
                             OCCTShapeRef face,
                             double*      outFirst,
                             double*      outLast)
{
  if (!edge || !face)
    return false;
  try
  {
    const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
    const TopoDS_Face& f = TopoDS::Face(face->shape);
    double             first, last;
    BRep_Tool::Range(e, f, first, last);
    *outFirst = first;
    *outLast  = last;
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepToolParameterOnFace(OCCTShapeRef vertex,
                                 OCCTShapeRef edge,
                                 OCCTShapeRef face,
                                 double*      outParam)
{
  if (!vertex || !edge || !face)
    return false;
  try
  {
    const TopoDS_Vertex& v = TopoDS::Vertex(vertex->shape);
    const TopoDS_Edge&   e = TopoDS::Edge(edge->shape);
    const TopoDS_Face&   f = TopoDS::Face(face->shape);
    *outParam              = BRep_Tool::Parameter(v, e, f);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepToolParametersOnFace(OCCTShapeRef vertex,
                                  OCCTShapeRef face,
                                  double*      outU,
                                  double*      outV)
{
  if (!vertex || !face)
    return false;
  try
  {
    const TopoDS_Vertex& v  = TopoDS::Vertex(vertex->shape);
    const TopoDS_Face&   f  = TopoDS::Face(face->shape);
    gp_Pnt2d             uv = BRep_Tool::Parameters(v, f);
    *outU                   = uv.X();
    *outV                   = uv.Y();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTBRepToolUVPoints(OCCTShapeRef edge,
                          OCCTShapeRef face,
                          double*      firstU,
                          double*      firstV,
                          double*      lastU,
                          double*      lastV)
{
  if (!edge || !face)
    return false;
  try
  {
    const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
    const TopoDS_Face& f = TopoDS::Face(face->shape);
    gp_Pnt2d           pFirst, pLast;
    BRep_Tool::UVPoints(e, f, pFirst, pLast);
    *firstU = pFirst.X();
    *firstV = pFirst.Y();
    *lastU  = pLast.X();
    *lastV  = pLast.Y();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

double OCCTBRepToolMaxTolerance(OCCTShapeRef shape, int32_t subShapeType)
{
  if (!shape)
    return 0.0;
  try
  {
    return BRep_Tool::MaxTolerance(shape->shape, (TopAbs_ShapeEnum)subShapeType);
  }
  catch (...)
  {
    return 0.0;
  }
}

bool OCCTBRepToolIsClosedOnFace(OCCTShapeRef edge, OCCTShapeRef face)
{
  if (!occtShapeIsPresent(edge) || !occtShapeIsPresent(face))
    return false;
  try
  {
    TopoDS_Edge e = TopoDS::Edge(edge->shape);
    TopoDS_Face f = TopoDS::Face(face->shape);
    return BRep_Tool::IsClosed(e, f);
  }
  catch (...)
  {
    return false;
  }
}

int32_t OCCTBRepToolPolygonOnSurface(OCCTShapeRef edge, OCCTShapeRef face, double** outPoints)
{
  if (!edge || !face || !outPoints)
    return 0;
  *outPoints = nullptr;
  try
  {
    TopoDS_Edge            e    = TopoDS::Edge(edge->shape);
    TopoDS_Face            f    = TopoDS::Face(face->shape);
    Handle(Poly_Polygon2D) poly = BRep_Tool::PolygonOnSurface(e, f);
    if (poly.IsNull())
      return 0;
    int32_t count = poly->NbNodes();
    if (count == 0)
      return 0;
    *outPoints                        = (double*)malloc(count * 2 * sizeof(double));
    const TColgp_Array1OfPnt2d& nodes = poly->Nodes();
    for (int i = 1; i <= count; i++)
    {
      (*outPoints)[(i - 1) * 2]     = nodes.Value(i).X();
      (*outPoints)[(i - 1) * 2 + 1] = nodes.Value(i).Y();
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTBRepToolSetUVPoints(OCCTShapeRef edge,
                             OCCTShapeRef face,
                             double       fU,
                             double       fV,
                             double       lU,
                             double       lV)
{
  if (!edge || !face)
    return false;
  try
  {
    TopoDS_Edge e = TopoDS::Edge(edge->shape);
    TopoDS_Face f = TopoDS::Face(face->shape);
    gp_Pnt2d    p1(fU, fV), p2(lU, lV);
    BRep_Tool::SetUVPoints(e, f, p1, p2);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// #541: this drove its own TopExp_Explorer, one entry per occurrence, while
// OCCTShapeGetFaceCount/GetFaceAtIndex read the deduplicated map. Since Swift writes the array
// position here into Face.index and hands it back to ~30 index-taking entry points, the two
// enumerations had to be one. Reads occtMapSubShapes now, like every other face accessor.
//
// #614: that convergence is right for the index and lossy for the normal. TopExp::MapShapes keys
// on TopoDS_Shape::IsSame, which ignores orientation (TopoDS_Shape.hxx:265-271), so a face
// occurring both FORWARD and REVERSED keeps only the orientation it was first seen with -- and
// OCCTFaceGetNormalAtUV derives the normal's SIDE from exactly that flag.
//
// Keeping this on the IsSame map is what OCCT does for an index: TopExp::MapShapes publishes no
// oriented overload (TopExp.hxx:57-60) and BREP persistence indexes sub-shapes through the same
// IsSame map (TopTools_ShapeSet.hxx:192). Orientation-sensitive work reads the traversal instead --
// see OCCTShapeGetOrientedFaces below, and BRepGProp.cxx:318-338 for upstream doing exactly that.
OCCTFaceRef* OCCTShapeGetFaces(OCCTShapeRef shape, int32_t* outCount)
{
  if (!shape || !outCount)
    return nullptr;
  *outCount = 0;

  try
  {
    TopTools_IndexedMapOfShape faceMap;
    int32_t                    count = occtMapSubShapes(shape->shape, TopAbs_FACE, faceMap);
    if (count == 0)
      return nullptr;

    OCCTFaceRef* result = new OCCTFaceRef[count];
    for (int32_t i = 0; i < count; i++)
    {
      result[i] = new OCCTFace(TopoDS::Face(faceMap(i + 1)));
    }

    *outCount = count;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #614: the occurrence count -- what OCCTShapeGetFaces returned before #541, and what
// OCCTShapeGetOrientedFaces returns now. Deliberately a bare explorer walk: the whole point is the
// repeats the map drops.
int32_t OCCTShapeGetFaceOccurrenceCount(OCCTShapeRef shape)
{
  if (!shape)
    return 0;
  try
  {
    int32_t count = 0;
    for (TopExp_Explorer ex(shape->shape, TopAbs_FACE); ex.More(); ex.Next())
      count++;
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

// #614: the geometry enumeration. One entry per occurrence, carrying the orientation the explorer
// composed through the traversal -- which is the orientation that makes OCCTFaceGetNormalAtUV
// point out of the body that owns this occurrence.
//
// This is upstream's own idiom for orientation-sensitive face work, not a local invention:
// BRepGProp::VolumeProperties reads TopoDS::Face(ex.Current()).Orientation() straight off the
// explorer (BRepGProp.cxx:322-325), and when it dedupes it keeps one IsSame map PER orientation
// (aFwdFMap/aRvsFMap, BRepGProp.cxx:318-338) precisely so a shared wall's two orientations both
// survive. Collapsing them is the bug; the explorer is the fix.
//
// Each entry also reports its position in OCCTShapeGetFaces' deduplicated enumeration, looked up
// through the same map that enumeration is built from (FindIndex is the IsSame lookup, 1-based).
// TopExp::MapShapes is literally this explorer walk piped into the map, so every occurrence is in
// it and FindIndex never misses; a 0 would mean the two walks had diverged, and is reported as -1
// rather than silently written as a valid-looking index.
OCCTFaceRef* OCCTShapeGetOrientedFaces(OCCTShapeRef shape,
                                       int32_t*     outIndices,
                                       int32_t      indexCapacity,
                                       int32_t*     outCount)
{
  if (!shape || !outCount)
    return nullptr;
  *outCount = 0;

  try
  {
    // One traversal serves both: TopExp::MapShapes IS this explorer walk piped into the map
    // (TopExp.cxx:35-45), so adding as we go builds exactly the enumeration OCCTShapeGetFaces
    // reads, without walking the shape a second time to rebuild it.
    std::vector<TopoDS_Face>   occurrences;
    TopTools_IndexedMapOfShape faceMap;
    for (TopExp_Explorer ex(shape->shape, TopAbs_FACE); ex.More(); ex.Next())
    {
      occurrences.push_back(TopoDS::Face(ex.Current()));
      faceMap.Add(ex.Current());
    }
    if (occurrences.empty())
      return nullptr;

    int32_t      count  = static_cast<int32_t>(occurrences.size());
    OCCTFaceRef* result = new OCCTFaceRef[count];
    for (int32_t i = 0; i < count; i++)
    {
      result[i] = new OCCTFace(occurrences[i]);
      if (outIndices && i < indexCapacity)
      {
        int32_t found = faceMap.FindIndex(occurrences[i]);
        outIndices[i] = (found > 0) ? found - 1 : -1;
      }
    }

    *outCount = count;
    return result;
  }
  catch (...)
  {
    return nullptr;
  }
}

// #614: the flag OCCTFaceGetNormalAtUV reverses on, exposed so a caller can tell a shared wall's
// two occurrences apart.
int32_t OCCTFaceGetOrientation(OCCTFaceRef face)
{
  if (!face)
    return 0;
  try
  {
    return static_cast<int32_t>(face->face.Orientation());
  }
  catch (...)
  {
    return 0;
  }
}

void OCCTFreeFaceArray(OCCTFaceRef* faces, int32_t count)
{
  if (!faces)
    return;
  for (int32_t i = 0; i < count; i++)
  {
    delete faces[i];
  }
  delete[] faces;
}

void OCCTFreeFaceArrayOnly(OCCTFaceRef* faces)
{
  if (!faces)
    return;
  delete[] faces;
}

void OCCTFaceRelease(OCCTFaceRef face)
{
  delete face;
}

bool OCCTFaceGetNormal(OCCTFaceRef face, double* outNx, double* outNy, double* outNz)
{
  if (!face || !outNx || !outNy || !outNz)
    return false;

  try
  {
    // Get surface from face
    BRepAdaptor_Surface adaptor(face->face);

    // Get parameter range
    double uMin, uMax, vMin, vMax;
    uMin = adaptor.FirstUParameter();
    uMax = adaptor.LastUParameter();
    vMin = adaptor.FirstVParameter();
    vMax = adaptor.LastVParameter();

    // Evaluate at center of parameter space
    double uMid = (uMin + uMax) / 2.0;
    double vMid = (vMin + vMax) / 2.0;

    // Get surface properties at center. Shares its resolution with OCCTFaceGetNormalAtUV, which
    // answers the same question about the same face at a caller-chosen (u, v) rather than the
    // parametric midpoint (#529).
    BRepLProp_SLProps props = occtFaceLocalProps(adaptor, uMid, vMid, 1);
    if (!props.IsNormalDefined())
      return false;

    gp_Dir normal = props.Normal();

    // Account for face orientation
    if (face->face.Orientation() == TopAbs_REVERSED)
    {
      normal.Reverse();
    }

    *outNx = normal.X();
    *outNy = normal.Y();
    *outNz = normal.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTWireRef OCCTFaceGetOuterWire(OCCTFaceRef face)
{
  if (!face)
    return nullptr;

  try
  {
    TopoDS_Wire outerWire = BRepTools::OuterWire(face->face);
    if (outerWire.IsNull())
      return nullptr;
    return new OCCTWire(outerWire);
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTFaceGetBounds(OCCTFaceRef face,
                       double*     minX,
                       double*     minY,
                       double*     minZ,
                       double*     maxX,
                       double*     maxY,
                       double*     maxZ)
{
  if (!minX || !minY || !minZ || !maxX || !maxY || !maxZ)
    return false;
  *minX = *minY = *minZ = *maxX = *maxY = *maxZ = 0.0;
  if (!face)
    return false;
  return occtComputeBoundingBox(face->face,
                                /*optimal=*/false,
                                /*useTriangulation=*/true,
                                /*useShapeTolerance=*/false,
                                *minX,
                                *minY,
                                *minZ,
                                *maxX,
                                *maxY,
                                *maxZ);
}

bool OCCTFaceGetBoundsExact(OCCTFaceRef face,
                            double*     minX,
                            double*     minY,
                            double*     minZ,
                            double*     maxX,
                            double*     maxY,
                            double*     maxZ)
{
  if (!minX || !minY || !minZ || !maxX || !maxY || !maxZ)
    return false;
  *minX = *minY = *minZ = *maxX = *maxY = *maxZ = 0.0;
  if (!face)
    return false;
  return occtComputeBoundingBox(face->face,
                                /*optimal=*/false,
                                /*useTriangulation=*/false,
                                /*useShapeTolerance=*/false,
                                *minX,
                                *minY,
                                *minZ,
                                *maxX,
                                *maxY,
                                *maxZ);
}

bool OCCTFaceIsPlanar(OCCTFaceRef face)
{
  if (!face)
    return false;

  try
  {
    BRepAdaptor_Surface adaptor(face->face);
    return adaptor.GetType() == GeomAbs_Plane;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTFaceGetZLevel(OCCTFaceRef face, double* outZ)
{
  if (!face || !outZ)
    return false;

  try
  {
    BRepAdaptor_Surface adaptor(face->face);

    // Check if planar
    if (adaptor.GetType() != GeomAbs_Plane)
      return false;

    gp_Pln plane  = adaptor.Plane();
    gp_Dir normal = plane.Axis().Direction();

    // Account for face orientation
    if (face->face.Orientation() == TopAbs_REVERSED)
    {
      normal.Reverse();
    }

    // Check if horizontal (normal is parallel to Z axis)
    double dotZ = std::abs(normal.Z());
    if (dotZ < 0.99)
      return false; // Not horizontal enough

    // Get Z from plane location
    gp_Pnt location = plane.Location();
    *outZ           = location.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

OCCTEdgeRef OCCTEdgeFromShape(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    if (shape->shape.IsNull())
      return nullptr;
    if (shape->shape.ShapeType() != TopAbs_EDGE)
      return nullptr;
    return new OCCTEdge(TopoDS::Edge(shape->shape));
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapeFromEdge(OCCTEdgeRef edgeRef)
{
  if (!edgeRef)
    return nullptr;
  return new OCCTShape(edgeRef->edge);
}

int32_t OCCTShapeGetFaceCount(OCCTShapeRef shape)
{
  return OCCTShapeGetSubShapeCount(shape, TopAbs_FACE);
}

OCCTFaceRef OCCTShapeGetFaceAtIndex(OCCTShapeRef shape, int32_t index)
{
  if (!shape)
    return nullptr;

  try
  {
    TopoDS_Shape face = occtSubShapeAt(shape->shape, TopAbs_FACE, index);
    if (face.IsNull())
      return nullptr;
    return new OCCTFace(TopoDS::Face(face));
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTShapeGetTotalEdgeCount(OCCTShapeRef shape)
{
  return OCCTShapeGetSubShapeCount(shape, TopAbs_EDGE);
}

OCCTEdgeRef OCCTShapeGetEdgeAtIndex(OCCTShapeRef shape, int32_t index)
{
  if (!shape)
    return nullptr;

  try
  {
    TopoDS_Shape edge = occtSubShapeAt(shape->shape, TopAbs_EDGE, index);
    if (edge.IsNull())
      return nullptr;
    return new OCCTEdge(TopoDS::Edge(edge));
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTEdgeRelease(OCCTEdgeRef edge)
{
  delete edge;
}

double OCCTEdgeGetLength(OCCTEdgeRef edge)
{
  if (!edge)
    return 0;

  try
  {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge->edge, props);
    return props.Mass(); // For curves, Mass() returns length
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTEdgeGetBounds(OCCTEdgeRef edge,
                       double*     minX,
                       double*     minY,
                       double*     minZ,
                       double*     maxX,
                       double*     maxY,
                       double*     maxZ)
{
  if (!minX || !minY || !minZ || !maxX || !maxY || !maxZ)
    return false;
  *minX = *minY = *minZ = *maxX = *maxY = *maxZ = 0.0;
  if (!edge)
    return false;
  return occtComputeBoundingBox(edge->edge,
                                /*optimal=*/false,
                                /*useTriangulation=*/true,
                                /*useShapeTolerance=*/false,
                                *minX,
                                *minY,
                                *minZ,
                                *maxX,
                                *maxY,
                                *maxZ);
}

int32_t OCCTEdgeGetPoints(OCCTEdgeRef edge, int32_t count, double* outPoints)
{
  if (!occtShapeIsPresent(edge) || count <= 0 || !outPoints)
    return 0;

  try
  {
    BRepAdaptor_Curve curve(edge->edge);
    double            first = curve.FirstParameter();
    double            last  = curve.LastParameter();

    for (int32_t i = 0; i < count; i++)
    {
      double t             = (count == 1) ? first : first + (last - first) * i / (count - 1);
      gp_Pnt pt            = curve.Value(t);
      outPoints[i * 3]     = pt.X();
      outPoints[i * 3 + 1] = pt.Y();
      outPoints[i * 3 + 2] = pt.Z();
    }

    return count;
  }
  catch (...)
  {
    return 0;
  }
}

bool OCCTEdgeIsLine(OCCTEdgeRef edge)
{
  if (!occtShapeIsPresent(edge))
    return false;

  try
  {
    BRepAdaptor_Curve curve(edge->edge);
    return curve.GetType() == GeomAbs_Line;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTEdgeIsCircle(OCCTEdgeRef edge)
{
  if (!occtShapeIsPresent(edge))
    return false;

  try
  {
    BRepAdaptor_Curve curve(edge->edge);
    return curve.GetType() == GeomAbs_Circle;
  }
  catch (...)
  {
    return false;
  }
}

void OCCTEdgeGetEndpoints(OCCTEdgeRef edge,
                          double*     startX,
                          double*     startY,
                          double*     startZ,
                          double*     endX,
                          double*     endY,
                          double*     endZ)
{
  if (!edge || !startX || !startY || !startZ || !endX || !endY || !endZ)
    return;

  try
  {
    TopoDS_Vertex v1, v2;
    TopExp::Vertices(edge->edge, v1, v2);

    gp_Pnt p1 = BRep_Tool::Pnt(v1);
    gp_Pnt p2 = BRep_Tool::Pnt(v2);

    *startX = p1.X();
    *startY = p1.Y();
    *startZ = p1.Z();
    *endX   = p2.X();
    *endY   = p2.Y();
    *endZ   = p2.Z();
  }
  catch (...)
  {
    *startX = *startY = *startZ = *endX = *endY = *endZ = 0;
  }
}
