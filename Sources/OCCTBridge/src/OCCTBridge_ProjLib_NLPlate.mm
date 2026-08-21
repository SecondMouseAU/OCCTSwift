//
//  OCCTBridge_ProjLib_NLPlate.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm, issue #99.
//
//  Two adjacent v0.22 / v0.23 areas that both project / fit curves onto
//  surfaces:
//
//  - ProjLib (v0.22): curve projection onto planes + general surfaces
//    (ProjLib_CompProjectedCurve / ProjectedCurve / ProjectOnPlane,
//    GeomProjLib helpers)
//  - NLPlate (v0.23): non-linear plate surfaces, point + curve
//    constraints fitted into a smooth surface (NLPlate_NLPlate +
//    GeomPlate_*)
//
//  Public C surface unchanged. No symbol changes, pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <ProjLib_ComputeApprox.hxx>
#include <ProjLib_ComputeApproxOnPolarSurface.hxx>
#include <NLPlate_HPG0G2Constraint.hxx>
#include <NLPlate_HPG0G3Constraint.hxx>
#include <Plate_D1.hxx>
#include <Plate_D2.hxx>
#include <Plate_D3.hxx>
#include <Plate_GtoCConstraint.hxx>
#include <Plate_PinpointConstraint.hxx>
#include <Plate_Plate.hxx>
#include <Geom_Line.hxx>
#include <ShapeConstruct_ProjectCurveOnSurface.hxx>
#include <ProjLib_ProjectOnSurface.hxx>
#include <ProjLib_Plane.hxx>
#include <ProjLib_Cylinder.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_TrimmedCurve.hxx>

#include <Geom_BSplineSurface.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_Surface.hxx>
#include <Geom2d_Curve.hxx>

#include <GeomAbs_Shape.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomPlate_BuildAveragePlane.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <GeomProjLib.hxx>

#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG1Constraint.hxx>
#include <NLPlate_NLPlate.hxx>
#include <Plate_D1.hxx>

#include <ProjLib_CompProjectedCurve.hxx>
#include <ProjLib_ProjectedCurve.hxx>
#include <ProjLib_ProjectOnPlane.hxx>

#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_XY.hxx>
#include <gp_XYZ.hxx>

#include <TColgp_Array2OfPnt.hxx>

#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

// MARK: - ProjLib: Curve Projection onto Surfaces (v0.22.0)

#include <GeomProjLib.hxx>
#include <ProjLib_CompProjectedCurve.hxx>
#include <ProjLib_ProjectedCurve.hxx>
#include <ProjLib_ProjectOnPlane.hxx>
#include <Geom_Plane.hxx>

OCCTCurve2DRef OCCTSurfaceProjectCurve2D(OCCTSurfaceRef surface,
                                         OCCTCurve3DRef curve,
                                         double         tolerance)
{
  if (!surface || surface->surface.IsNull())
    return nullptr;
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    Standard_Real        first = curve->curve->FirstParameter();
    Standard_Real        last  = curve->curve->LastParameter();
    Standard_Real        tol   = tolerance;
    Handle(Geom2d_Curve) result =
      GeomProjLib::Curve2d(curve->curve, first, last, surface->surface, tol);
    if (result.IsNull())
      return nullptr;
    return new OCCTCurve2D(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

int32_t OCCTSurfaceProjectCurveSegments(OCCTSurfaceRef  surface,
                                        OCCTCurve3DRef  curve,
                                        double          tolerance,
                                        OCCTCurve2DRef* outCurves,
                                        int32_t         maxCurves)
{
  if (!surface || surface->surface.IsNull())
    return 0;
  if (!curve || curve->curve.IsNull())
    return 0;
  if (!outCurves || maxCurves <= 0)
    return 0;
  try
  {
    Handle(GeomAdaptor_Surface) surfAdaptor  = new GeomAdaptor_Surface(surface->surface);
    Handle(GeomAdaptor_Curve)   curveAdaptor = new GeomAdaptor_Curve(curve->curve);

    ProjLib_CompProjectedCurve comp(tolerance, surfAdaptor, curveAdaptor);
    comp.Perform();

    int32_t nbCurves = comp.NbCurves();
    int32_t count    = 0;
    for (int32_t i = 1; i <= nbCurves && count < maxCurves; i++)
    {
      Handle(Geom2d_Curve) c2d = comp.GetResult2dC(i);
      if (!c2d.IsNull())
      {
        outCurves[count] = new OCCTCurve2D(c2d);
        count++;
      }
    }
    return count;
  }
  catch (...)
  {
    return 0;
  }
}

OCCTCurve3DRef OCCTSurfaceProjectCurve3D(OCCTSurfaceRef surface, OCCTCurve3DRef curve)
{
  if (!surface || surface->surface.IsNull())
    return nullptr;
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    Handle(Geom_Curve) result = GeomProjLib::Project(curve->curve, surface->surface);
    if (result.IsNull())
      return nullptr;
    return new OCCTCurve3D(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTCurve3DRef OCCTCurve3DProjectOnPlane(OCCTCurve3DRef curve,
                                         double         oX,
                                         double         oY,
                                         double         oZ,
                                         double         nX,
                                         double         nY,
                                         double         nZ,
                                         double         dX,
                                         double         dY,
                                         double         dZ)
{
  if (!curve || curve->curve.IsNull())
    return nullptr;
  try
  {
    gp_Pnt             origin(oX, oY, oZ);
    gp_Dir             normal(nX, nY, nZ);
    gp_Dir             direction(dX, dY, dZ);
    Handle(Geom_Plane) plane = new Geom_Plane(origin, normal);

    Handle(Geom_Curve) result =
      GeomProjLib::ProjectOnPlane(curve->curve, plane, direction, Standard_True);
    if (result.IsNull())
      return nullptr;
    return new OCCTCurve3D(result);
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTSurfaceProjectPoint(OCCTSurfaceRef surface,
                             double         px,
                             double         py,
                             double         pz,
                             double*        u,
                             double*        v,
                             double*        distance)
{
  if (!surface || surface->surface.IsNull())
    return false;
  if (!u || !v || !distance)
    return false;
  try
  {
    GeomAPI_ProjectPointOnSurf proj(gp_Pnt(px, py, pz), surface->surface);
    if (!proj.IsDone() || proj.NbPoints() == 0)
      return false;
    proj.LowerDistanceParameters(*u, *v);
    *distance = proj.LowerDistance();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - NLPlate: Advanced Plate Surfaces (v0.23.0)

#include <NLPlate_NLPlate.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG1Constraint.hxx>
#include <NLPlate_HPG0G1Constraint.hxx>
#include <Plate_D1.hxx>
#include <GeomPlate_BuildAveragePlane.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>

// === #571: the one GeomPlate_MakeApprox call ===
//
// See OCCTBridge_Internal.h for why Nbmax, dmax and continuity are what they are, and for the
// measurements behind each. In short: Nbmax = 1 makes the criterion unable to act and the
// tolerance unreachable, and dmax = tolerance * 10 sets the criterion threshold to 100x the
// tolerance the caller asked for. Five of the six sites had both.
occ::handle<Geom_BSplineSurface> occtPlateApproxSurface(const occ::handle<GeomPlate_Surface>& plate,
                                                        double        tolerance,
                                                        int32_t       maxDegree,
                                                        int32_t       maxSegments,
                                                        GeomAbs_Shape continuity)
{
  if (plate.IsNull() || !(tolerance > 0))
    return occ::handle<Geom_BSplineSurface>();

  // A single patch cannot be cut, so the criterion's verdict is discarded and `tolerance` stops
  // being enforceable at all. Two is the smallest cap that lets the approximator honour it.
  int32_t nbMax = maxSegments < 2 ? 2 : maxSegments;
  int32_t dgMax = maxDegree < 1 ? occtPlateApproxDefaultMaxDegree() : maxDegree;

  // AdvApp2Var accepts C0, C1 and C2 only; G1/G2/C3/CN each throw. Clamp into that ladder
  // rather than let a caller's continuity turn the whole call into a nullptr.
  GeomAbs_Shape cont = continuity;
  if (cont == GeomAbs_G1)
    cont = GeomAbs_C1;
  else if (cont == GeomAbs_G2)
    cont = GeomAbs_C2;
  else if (cont == GeomAbs_C3 || cont == GeomAbs_CN)
    cont = GeomAbs_C2;

  // seuil = max(Tol3d, 10 * dmax), so this makes the criterion threshold the caller's tolerance.
  const double dmax = tolerance * 0.1;

  try
  {
    GeomPlate_MakeApprox approx(plate, tolerance, nbMax, dgMax, dmax, 0, cont);
    return approx.Surface();
  }
  catch (...)
  {
    return occ::handle<Geom_BSplineSurface>();
  }
}

OCCTShapeRef OCCTShapePlatePointsAdvanced(const double*  points,
                                          int32_t        pointCount,
                                          const int32_t* orders,
                                          int32_t        degree,
                                          int32_t        nbPtsOnCur,
                                          int32_t        nbIter,
                                          double         tolerance)
{
  if (!points || pointCount < 3 || !orders)
    return nullptr;
  try
  {
    GeomPlate_BuildPlateSurface plateBuilder(degree, nbPtsOnCur, nbIter);

    for (int32_t i = 0; i < pointCount; i++)
    {
      gp_Pnt  pt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
      int32_t order = orders[i];
      if (order < 0)
        order = 0;
      if (order > 2)
        order = 2;
      Handle(GeomPlate_PointConstraint) constraint = new GeomPlate_PointConstraint(pt, order);
      plateBuilder.Add(constraint);
    }

    plateBuilder.Perform();
    if (!plateBuilder.IsDone())
      return nullptr;

    Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
    if (plateSurface.IsNull())
      return nullptr;

    Handle(Geom_BSplineSurface) bsplineSurf =
      occtPlateApproxSurface(plateSurface,
                             tolerance,
                             occtPlateApproxDefaultMaxDegree(),
                             occtPlateApproxDefaultMaxSegments(),
                             occtPlateApproxDefaultContinuity());
    if (bsplineSurf.IsNull())
      return nullptr;

    BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
    if (!makeFace.IsDone())
      return nullptr;

    return new OCCTShape(makeFace.Face());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTShapeRef OCCTShapePlateMixed(const double*      points,
                                 const int32_t*     pointOrders,
                                 int32_t            pointCount,
                                 const OCCTWireRef* curves,
                                 const int32_t*     curveOrders,
                                 int32_t            curveCount,
                                 int32_t            degree,
                                 double             tolerance)
{
  if (pointCount < 1 && curveCount < 1)
    return nullptr;
  try
  {
    GeomPlate_BuildPlateSurface plateBuilder(degree, 15, 2);

    // Add point constraints
    if (points && pointOrders)
    {
      for (int32_t i = 0; i < pointCount; i++)
      {
        gp_Pnt  pt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
        int32_t order = pointOrders[i];
        if (order < 0)
          order = 0;
        if (order > 2)
          order = 2;
        Handle(GeomPlate_PointConstraint) constraint = new GeomPlate_PointConstraint(pt, order);
        plateBuilder.Add(constraint);
      }
    }

    // Add curve constraints
    if (curves && curveOrders)
    {
      for (int32_t i = 0; i < curveCount; i++)
      {
        if (!curves[i])
          continue;
        int32_t order = curveOrders[i];
        if (order < 0)
          order = 0;
        if (order > 2)
          order = 2;

        for (TopExp_Explorer exp(curves[i]->wire, TopAbs_EDGE); exp.More(); exp.Next())
        {
          TopoDS_Edge                       edge = TopoDS::Edge(exp.Current());
          BRepAdaptor_Curve                 adaptor(edge);
          Handle(Adaptor3d_Curve)           curve = new BRepAdaptor_Curve(adaptor);
          Handle(GeomPlate_CurveConstraint) constraint =
            new GeomPlate_CurveConstraint(curve, order);
          plateBuilder.Add(constraint);
        }
      }
    }

    plateBuilder.Perform();
    if (!plateBuilder.IsDone())
      return nullptr;

    Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
    if (plateSurface.IsNull())
      return nullptr;

    Handle(Geom_BSplineSurface) bsplineSurf =
      occtPlateApproxSurface(plateSurface,
                             tolerance,
                             occtPlateApproxDefaultMaxDegree(),
                             occtPlateApproxDefaultMaxSegments(),
                             occtPlateApproxDefaultContinuity());
    if (bsplineSurf.IsNull())
      return nullptr;

    BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
    if (!makeFace.IsDone())
      return nullptr;

    return new OCCTShape(makeFace.Face());
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfacePlateThrough(const double* points,
                                       int32_t       pointCount,
                                       int32_t       degree,
                                       double        tolerance)
{
  if (!points || pointCount < 3)
    return nullptr;
  try
  {
    GeomPlate_BuildPlateSurface plateBuilder(degree, 15, 2);

    for (int32_t i = 0; i < pointCount; i++)
    {
      gp_Pnt                            pt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
      Handle(GeomPlate_PointConstraint) constraint = new GeomPlate_PointConstraint(pt, 0);
      plateBuilder.Add(constraint);
    }

    plateBuilder.Perform();
    if (!plateBuilder.IsDone())
      return nullptr;

    Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
    if (plateSurface.IsNull())
      return nullptr;

    Handle(Geom_BSplineSurface) bsplineSurf =
      occtPlateApproxSurface(plateSurface,
                             tolerance,
                             occtPlateApproxDefaultMaxDegree(),
                             occtPlateApproxDefaultMaxSegments(),
                             occtPlateApproxDefaultContinuity());
    if (bsplineSurf.IsNull())
      return nullptr;

    return new OCCTSurface(bsplineSurf);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - NLPlate shared tail (#1049, #1046)

// The parameter rectangle every OCCTSurfaceNLPlate* entry point samples its solved plate over,
// with the surface the solver is built on.
//
// A direction the input already bounds is kept, so a cylinder comes back spanning its own
// [0, 2pi] rather than an interval derived from wherever its constraints happen to sit. A
// direction the input leaves unbounded has no range to sample, so it is replaced by the span of
// the constraint parameters padded outward. Only the unbounded directions are replaced, and the
// whole surface is trimmed to the result before it is refit, per CLAUDE.md's rule that an
// infinite surface is trimmed before converting to BSpline (#1046).
struct OCCTNLPlateWorkingDomain
{
  Handle(Geom_Surface) surface;
  double               u1 = 0.0;
  double               u2 = 0.0;
  double               v1 = 0.0;
  double               v2 = 0.0;
};

static bool occtNLPlateWorkingDomain(const Handle(Geom_Surface)& initialSurface,
                                     const double*               constraints,
                                     int32_t                     constraintCount,
                                     int32_t                     stride,
                                     OCCTNLPlateWorkingDomain&   domain)
{
  Standard_Real u1, u2, v1, v2;
  initialSurface->Bounds(u1, u2, v1, v2);

  const bool uInfinite = Precision::IsNegativeInfinite(u1) || Precision::IsPositiveInfinite(u2);
  const bool vInfinite = Precision::IsNegativeInfinite(v1) || Precision::IsPositiveInfinite(v2);

  if (uInfinite || vInfinite)
  {
    double minU = 1e30, maxU = -1e30, minV = 1e30, maxV = -1e30;
    for (int32_t i = 0; i < constraintCount; i++)
    {
      const double cu = constraints[i * stride + 0];
      const double cv = constraints[i * stride + 1];
      minU            = std::min(minU, cu);
      maxU            = std::max(maxU, cu);
      minV            = std::min(minV, cv);
      maxV            = std::max(maxV, cv);
    }
    if (uInfinite)
    {
      const double padU = std::max(10.0, (maxU - minU) * 0.5);
      u1                = minU - padU;
      u2                = maxU + padU;
    }
    if (vInfinite)
    {
      const double padV = std::max(10.0, (maxV - minV) * 0.5);
      v1                = minV - padV;
      v2                = maxV + padV;
    }
  }

  // Checked before the trim is built, because Geom_RectangularTrimmedSurface throws on a
  // degenerate range and a refusal is the answer either way.
  if (!(u2 > u1) || !(v2 > v1))
    return false;

  domain.surface =
    (uInfinite || vInfinite)
      ? Handle(Geom_Surface)(new Geom_RectangularTrimmedSurface(initialSurface, u1, u2, v1, v2))
      : initialSurface;
  domain.u1 = u1;
  domain.u2 = u2;
  domain.v1 = v1;
  domain.v2 = v2;
  return true;
}

// Map a fitted surface's knots linearly onto the working domain. The poles are untouched, so the
// geometry is unchanged and only the parametrisation moves: the caller's own (u, v), the one the
// constraints were written in, addresses the same place on the output as it did on the input.
// The fit itself always lands on [0, 1] x [0, 1] (#1046).
//
// Periodicity is not restored by this. A periodic input still comes back as a plain BSpline that
// does not close on itself; see docs/occtswift-wrapping-gaps.md.
static void occtNLPlateReparametrise(const Handle(Geom_BSplineSurface)& surface,
                                     const OCCTNLPlateWorkingDomain&    domain)
{
  Standard_Real fu1, fu2, fv1, fv2;
  surface->Bounds(fu1, fu2, fv1, fv2);

  if (fu2 > fu1)
  {
    const double                      scale = (domain.u2 - domain.u1) / (fu2 - fu1);
    const NCollection_Array1<double>& src   = surface->UKnots();
    NCollection_Array1<double>        knots(src.Lower(), src.Upper());
    for (int i = src.Lower(); i <= src.Upper(); i++)
      knots(i) = domain.u1 + (src(i) - fu1) * scale;
    surface->SetUKnots(knots);
  }

  if (fv2 > fv1)
  {
    const double                      scale = (domain.v2 - domain.v1) / (fv2 - fv1);
    const NCollection_Array1<double>& src   = surface->VKnots();
    NCollection_Array1<double>        knots(src.Lower(), src.Upper());
    for (int i = src.Lower(); i <= src.Upper(); i++)
      knots(i) = domain.v1 + (src(i) - fv1) * scale;
    surface->SetVKnots(knots);
  }
}

// Sample the solved plate over the working domain and refit it as a BSpline.
//
// NLPlate_NLPlate::Evaluate returns the absolute deformed point, not a displacement.
// EvaluateDerivative seeds its accumulator with myInitialSurface->Value(uv) before summing the
// plates, and Iterate corroborates it by loading G0Target() - Evaluate(UV) as the pinpoint
// constraint, a subtraction that only makes sense if Evaluate is a point in the same space as the
// target. Adding the base surface to it a second time put every result at twice its distance from
// the origin, invisible only because every shipped fixture was a plane through the origin (#1049).
// See Scripts/repro/1049-nlplate-double-base.
static OCCTSurfaceRef occtNLPlateFitSolved(const NLPlate_NLPlate&          solver,
                                           const OCCTNLPlateWorkingDomain& domain,
                                           double                          tolerance)
{
  const int          nuPts = 20, nvPts = 20;
  TColgp_Array2OfPnt poles(1, nuPts, 1, nvPts);
  for (int iu = 1; iu <= nuPts; iu++)
  {
    const double pu = domain.u1 + (domain.u2 - domain.u1) * (iu - 1) / (nuPts - 1);
    for (int iv = 1; iv <= nvPts; iv++)
    {
      const double pv  = domain.v1 + (domain.v2 - domain.v1) * (iv - 1) / (nvPts - 1);
      const gp_XYZ val = solver.Evaluate(gp_XY(pu, pv));
      poles(iu, iv)    = gp_Pnt(val.X(), val.Y(), val.Z());
    }
  }

  GeomAPI_PointsToBSplineSurface approx;
  approx.Init(poles, 3, 8, GeomAbs_C2, tolerance);
  if (!approx.IsDone())
    return nullptr;

  Handle(Geom_BSplineSurface) result = approx.Surface();
  if (result.IsNull())
    return nullptr;

  occtNLPlateReparametrise(result, domain);
  return new OCCTSurface(result);
}

// #1017: OCCTSurfaceNLPlateG0/G1 used to call this argument maxIter and hand it to
// NLPlate_NLPlate::Solve2, whose first parameter is `ord`, the plate's resolution order. It is
// forwarded to Plate_Plate::SolveTI, which accepts only [2, 9] and otherwise returns with its own
// OK false. NLPlate_NLPlate::Solve2 then sets OK true unconditionally after its loop, so an
// out-of-range order came back IsDone() with an empty plate list and Evaluate() returning the
// undeformed surface. Measured on the shipped fixtures: a G0 constraint 5 units off the plane was
// missed by the full 5 at orders 0, 1, 10, 12 and 100, and met to 6.3e-6 at order 4. The refusal
// below is what makes the parameter mean something; see
// Scripts/repro/1017-nlplate-solve2-order.
//
// Reach: the two Solve2 call sites that take the order from the caller. The three that hardcode
// it (G2, G3, EvaluateDerivative) pass 2 or 3 and cannot go out of range.
static bool occtNLPlateResolutionOrderInRange(int32_t resolutionOrder)
{
  return resolutionOrder >= 2 && resolutionOrder <= 9;
}

OCCTSurfaceRef OCCTSurfaceNLPlateG0(OCCTSurfaceRef initialSurface,
                                    const double*  constraints,
                                    int32_t        constraintCount,
                                    int32_t        resolutionOrder,
                                    double         tolerance)
{
  if (!occtNLPlateResolutionOrderInRange(resolutionOrder))
    return nullptr;
  if (!initialSurface || initialSurface->surface.IsNull())
    return nullptr;
  if (!constraints || constraintCount < 1)
    return nullptr;
  try
  {
    OCCTNLPlateWorkingDomain domain;
    if (!occtNLPlateWorkingDomain(initialSurface->surface, constraints, constraintCount, 5, domain))
      return nullptr;

    NLPlate_NLPlate solver(domain.surface);

    for (int32_t i = 0; i < constraintCount; i++)
    {
      const double* c = constraints + i * 5;
      gp_XY         uv(c[0], c[1]);
      gp_XYZ        target(c[2], c[3], c[4]);

      Handle(NLPlate_HPG0Constraint) g0 = new NLPlate_HPG0Constraint(uv, target);
      solver.Load(g0);
    }

    solver.Solve2(resolutionOrder, 1);
    if (!solver.IsDone())
      return nullptr;

    return occtNLPlateFitSolved(solver, domain, tolerance);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceNLPlateG1(OCCTSurfaceRef initialSurface,
                                    const double*  constraints,
                                    int32_t        constraintCount,
                                    int32_t        resolutionOrder,
                                    double         tolerance)
{
  if (!occtNLPlateResolutionOrderInRange(resolutionOrder))
    return nullptr;
  if (!initialSurface || initialSurface->surface.IsNull())
    return nullptr;
  if (!constraints || constraintCount < 1)
    return nullptr;
  try
  {
    OCCTNLPlateWorkingDomain domain;
    if (!occtNLPlateWorkingDomain(initialSurface->surface,
                                  constraints,
                                  constraintCount,
                                  11,
                                  domain))
      return nullptr;

    NLPlate_NLPlate solver(domain.surface);

    // constraints: flat (u, v, targetX, targetY, targetZ, d1uX, d1uY, d1uZ, d1vX, d1vY, d1vZ)
    for (int32_t i = 0; i < constraintCount; i++)
    {
      const double* c = constraints + i * 11;
      gp_XY         uv(c[0], c[1]);
      gp_XYZ        target(c[2], c[3], c[4]);
      Plate_D1      d1(gp_XYZ(c[5], c[6], c[7]), gp_XYZ(c[8], c[9], c[10]));

      Handle(NLPlate_HPG0G1Constraint) g0g1 = new NLPlate_HPG0G1Constraint(uv, target, d1);
      solver.Load(g0g1);
    }

    solver.Solve2(resolutionOrder, 1);
    if (!solver.IsDone())
      return nullptr;

    return occtNLPlateFitSolved(solver, domain, tolerance);
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - GeomPlate_Surface (v0.61)
// MARK: - GeomPlate_Surface (v0.61.0)

OCCTShapeRef OCCTGeomPlateSurface(const double* points,
                                  int32_t       ptCount,
                                  double        tolerance,
                                  int32_t       maxDegree,
                                  int32_t       maxSegments)
{
  if (!points || ptCount < 3)
    return nullptr;
  try
  {
    // #1019: this used to pass `tolerance` as the fourth argument, which is Tol2d, the 2D
    // parametric tolerance, not Tol3d. Moving it to Tol3d is measurably a no-op rather than a
    // fix, so the argument is dropped instead of relocated: this entry point loads only
    // GeomPlate_PointConstraints, and GeomPlate_BuildPlateSurface reads myTol2d only inside its
    // `for (i = 1; i <= NTLinCont; ...)` curve-intersection loop, while myTol3d's point-only
    // readers are the average-plane planarity test and the projection resolutions, all exact on
    // the planar initial surface that branch builds. Swept 1e-12 to 1e2 in both slots on two
    // fixtures: the fitted surface is bit-identical in all 24 rows. `tolerance` keeps the two
    // places it does govern, the approximation below and the face tolerance.
    //
    // #1020 asked whether maxDegree/maxSegments should also reach the builder. They should not.
    // The builder's first argument is its own Degree, which it hands to Plate_Plate::SolveTI as
    // a resolution order capped at 9, and the caller's maxDegree is the approximation's maximum
    // BSpline degree, where 10 and above are ordinary requests. Forwarding it turns those into
    // outright failures, and moves the shipped default's plate off OCCT's own documented optimum
    // of 3. Surface.plateThrough already exposes the builder's Degree separately, as `degree`.
    // See Scripts/repro/1019-1020-plate-builder-arguments.
    GeomPlate_BuildPlateSurface builder(3, 10, 5);

    for (int32_t i = 0; i < ptCount; i++)
    {
      Handle(GeomPlate_PointConstraint) pc =
        new GeomPlate_PointConstraint(gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]),
                                      0);
      builder.Add(pc);
    }

    builder.Perform();
    if (!builder.IsDone())
      return nullptr;

    Handle(GeomPlate_Surface) plateSurf = builder.Surface();
    if (plateSurf.IsNull())
      return nullptr;

    // Convert to BSpline for use as a face
    Handle(Geom_BSplineSurface) bspline =
      occtPlateApproxSurface(plateSurf,
                             tolerance,
                             maxDegree,
                             maxSegments,
                             occtPlateApproxDefaultContinuity());
    if (bspline.IsNull())
      return nullptr;

    BRepBuilderAPI_MakeFace faceMaker(bspline, tolerance);
    if (!faceMaker.IsDone())
      return nullptr;
    return new OCCTShape(faceMaker.Face());
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ProjLib Compute Approx (v0.64)
// --- ProjLib_ComputeApprox ---

OCCTShapeRef _Nullable OCCTProjLibComputeApprox(OCCTShapeRef edgeShape,
                                                OCCTShapeRef faceShape,
                                                double       tolerance)
{
  if (!edgeShape || !faceShape)
    return nullptr;
  try
  {
    TopoDS_Edge        edge = TopoDS::Edge(edgeShape->shape);
    TopoDS_Face        face = TopoDS::Face(faceShape->shape);
    double             f, l;
    Handle(Geom_Curve) curve3d = BRep_Tool::Curve(edge, f, l);
    if (curve3d.IsNull())
      return nullptr;
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
    if (surface.IsNull())
      return nullptr;

    Handle(GeomAdaptor_Curve)   curveAdaptor = new GeomAdaptor_Curve(curve3d, f, l);
    Handle(GeomAdaptor_Surface) surfAdaptor  = new GeomAdaptor_Surface(surface);

    ProjLib_ComputeApprox       proj(curveAdaptor, surfAdaptor, tolerance);
    Handle(Geom2d_BSplineCurve) bsp = proj.BSpline();
    if (!bsp.IsNull())
    {
      // Convert 2D curve to a 3D edge on the surface
      BRepBuilderAPI_MakeEdge me(bsp, surface);
      if (me.IsDone())
        return new OCCTShape(me.Edge());
    }
    Handle(Geom2d_BezierCurve) bez = proj.Bezier();
    if (!bez.IsNull())
    {
      BRepBuilderAPI_MakeEdge me(bez, surface);
      if (me.IsDone())
        return new OCCTShape(me.Edge());
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

// --- ProjLib_ComputeApproxOnPolarSurface ---

OCCTShapeRef _Nullable OCCTProjLibComputeApproxOnPolarSurface(OCCTShapeRef edgeShape,
                                                              OCCTShapeRef faceShape,
                                                              double       tolerance)
{
  if (!edgeShape || !faceShape)
    return nullptr;
  try
  {
    TopoDS_Edge        edge = TopoDS::Edge(edgeShape->shape);
    TopoDS_Face        face = TopoDS::Face(faceShape->shape);
    double             f, l;
    Handle(Geom_Curve) curve3d = BRep_Tool::Curve(edge, f, l);
    if (curve3d.IsNull())
      return nullptr;
    Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
    if (surface.IsNull())
      return nullptr;

    Handle(GeomAdaptor_Curve)   curveAdaptor = new GeomAdaptor_Curve(curve3d, f, l);
    Handle(GeomAdaptor_Surface) surfAdaptor  = new GeomAdaptor_Surface(surface);

    ProjLib_ComputeApproxOnPolarSurface proj(curveAdaptor, surfAdaptor, tolerance);
    if (!proj.IsDone())
      return nullptr;

    Handle(Geom2d_BSplineCurve) bsp = proj.BSpline();
    if (!bsp.IsNull())
    {
      BRepBuilderAPI_MakeEdge me(bsp, surface);
      if (me.IsDone())
        return new OCCTShape(me.Edge());
    }
    Handle(Geom2d_Curve) curve2d = proj.Curve2d();
    if (!curve2d.IsNull())
    {
      BRepBuilderAPI_MakeEdge me(curve2d, surface);
      if (me.IsDone())
        return new OCCTShape(me.Edge());
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - NLPlate G2/G3 / Incremental G0 (v0.69)
// --- NLPlate G0+G2 ---

// #999: this took a maxIter it never read, and there is no place to wire one that means it.
// NLPlate_NLPlate::Solve2(ord, InitialConsraintOrder) has no iteration count, and neither has
// Solve(). IncrementalSolve(ord, InitialConsraintOrder, NbIncrements, UVSliding) does, but it is a
// different solver rather than a bound on this one: measured on a 5-constraint G0G2 saddle with
// +-40 out-of-plane displacement, Solve2 reports Continuity() 1 and IncrementalSolve 3, and their
// evaluated grids differ by 2% of the checksum, while NbIncrements itself moves the answer only
// between 1 and 2 and is inert from 2 upward. Wiring maxIter to it would silently change every
// existing caller's surface and still not mean "maximum iterations". IncrementalSolve is already
// wrapped separately, as OCCTSurfaceNLPlateIncrementalG0, with its own nbIncrements.
// See Scripts/repro/999-dead-parameters/nlplate_solver.mm.
OCCTSurfaceRef OCCTSurfaceNLPlateG2(OCCTSurfaceRef initialSurface,
                                    const double*  constraints,
                                    int32_t        constraintCount,
                                    double         tolerance)
{
  if (!initialSurface || initialSurface->surface.IsNull())
    return nullptr;
  if (!constraints || constraintCount < 1)
    return nullptr;
  try
  {
    OCCTNLPlateWorkingDomain domain;
    if (!occtNLPlateWorkingDomain(initialSurface->surface,
                                  constraints,
                                  constraintCount,
                                  20,
                                  domain))
      return nullptr;

    NLPlate_NLPlate solver(domain.surface);

    // Each constraint: 20 doubles (u, v, x,y,z, d1u(3), d1v(3), d2uu(3), d2uv(3), d2vv(3))
    for (int i = 0; i < constraintCount; i++)
    {
      const double* c = constraints + i * 20;
      gp_XY         uv(c[0], c[1]);
      gp_XYZ        target(c[2], c[3], c[4]);
      Plate_D1      d1(gp_XYZ(c[5], c[6], c[7]), gp_XYZ(c[8], c[9], c[10]));
      Plate_D2      d2(gp_XYZ(c[11], c[12], c[13]),
                       gp_XYZ(c[14], c[15], c[16]),
                       gp_XYZ(c[17], c[18], c[19]));

      Handle(NLPlate_HPG0G2Constraint) g0g2 = new NLPlate_HPG0G2Constraint(uv, target, d1, d2);
      solver.Load(g0g2);
    }

    solver.Solve2(2, 1);
    if (!solver.IsDone())
      return nullptr;

    return occtNLPlateFitSolved(solver, domain, tolerance > 0 ? tolerance : 1e-3);
  }
  catch (...)
  {
    return nullptr;
  }
}

// No iteration count, for the reason spelled out on OCCTSurfaceNLPlateG2 above (#999).
OCCTSurfaceRef OCCTSurfaceNLPlateG3(OCCTSurfaceRef initialSurface,
                                    const double*  constraints,
                                    int32_t        constraintCount,
                                    double         tolerance)
{
  if (!initialSurface || initialSurface->surface.IsNull())
    return nullptr;
  if (!constraints || constraintCount < 1)
    return nullptr;
  try
  {
    OCCTNLPlateWorkingDomain domain;
    if (!occtNLPlateWorkingDomain(initialSurface->surface,
                                  constraints,
                                  constraintCount,
                                  32,
                                  domain))
      return nullptr;

    NLPlate_NLPlate solver(domain.surface);

    // Each constraint: 32 doubles
    for (int i = 0; i < constraintCount; i++)
    {
      const double* c = constraints + i * 32;
      gp_XY         uv(c[0], c[1]);
      gp_XYZ        target(c[2], c[3], c[4]);
      Plate_D1      d1(gp_XYZ(c[5], c[6], c[7]), gp_XYZ(c[8], c[9], c[10]));
      Plate_D2      d2(gp_XYZ(c[11], c[12], c[13]),
                       gp_XYZ(c[14], c[15], c[16]),
                       gp_XYZ(c[17], c[18], c[19]));
      Plate_D3      d3(gp_XYZ(c[20], c[21], c[22]),
                       gp_XYZ(c[23], c[24], c[25]),
                       gp_XYZ(c[26], c[27], c[28]),
                       gp_XYZ(c[29], c[30], c[31]));

      Handle(NLPlate_HPG0G3Constraint) g0g3 = new NLPlate_HPG0G3Constraint(uv, target, d1, d2, d3);
      solver.Load(g0g3);
    }

    solver.Solve2(3, 1);
    if (!solver.IsDone())
      return nullptr;

    return occtNLPlateFitSolved(solver, domain, tolerance > 0 ? tolerance : 1e-3);
  }
  catch (...)
  {
    return nullptr;
  }
}

OCCTSurfaceRef OCCTSurfaceNLPlateIncrementalG0(OCCTSurfaceRef initialSurface,
                                               const double*  constraints,
                                               int32_t        constraintCount,
                                               int32_t        maxOrder,
                                               int32_t        initConstraintOrder,
                                               int32_t        nbIncrements)
{
  if (!initialSurface || initialSurface->surface.IsNull())
    return nullptr;
  if (!constraints || constraintCount < 1)
    return nullptr;
  try
  {
    OCCTNLPlateWorkingDomain domain;
    if (!occtNLPlateWorkingDomain(initialSurface->surface, constraints, constraintCount, 5, domain))
      return nullptr;

    NLPlate_NLPlate solver(domain.surface);

    for (int i = 0; i < constraintCount; i++)
    {
      const double*                  c = constraints + i * 5;
      gp_XY                          uv(c[0], c[1]);
      gp_XYZ                         target(c[2], c[3], c[4]);
      Handle(NLPlate_HPG0Constraint) g0 = new NLPlate_HPG0Constraint(uv, target);
      solver.Load(g0);
    }

    solver.IncrementalSolve(maxOrder, initConstraintOrder, nbIncrements, false);
    if (!solver.IsDone())
      return nullptr;

    return occtNLPlateFitSolved(solver, domain, 1e-3);
  }
  catch (...)
  {
    return nullptr;
  }
}

bool OCCTSurfaceNLPlateEvaluateDerivative(OCCTSurfaceRef initialSurface,
                                          const double*  constraints,
                                          int32_t        constraintCount,
                                          double         u,
                                          double         v,
                                          int32_t        iu,
                                          int32_t        iv,
                                          double*        outX,
                                          double*        outY,
                                          double*        outZ)
{
  if (!initialSurface || initialSurface->surface.IsNull())
    return false;
  if (!constraints || constraintCount < 1)
    return false;
  try
  {
    NLPlate_NLPlate solver(initialSurface->surface);

    for (int i = 0; i < constraintCount; i++)
    {
      const double*                  c = constraints + i * 5;
      gp_XY                          uv(c[0], c[1]);
      gp_XYZ                         target(c[2], c[3], c[4]);
      Handle(NLPlate_HPG0Constraint) g0 = new NLPlate_HPG0Constraint(uv, target);
      solver.Load(g0);
    }

    solver.Solve2(2, 1);
    if (!solver.IsDone())
      return false;

    gp_XYZ result = solver.EvaluateDerivative(gp_XY(u, v), iu, iv);
    *outX         = result.X();
    *outY         = result.Y();
    *outZ         = result.Z();
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - Plate_Plate Solver (v0.69)
// --- Plate_Plate solver ---

OCCTPlateRef OCCTPlateCreate(void)
{
  try
  {
    return (OCCTPlateRef)(new Plate_Plate());
  }
  catch (...)
  {
    return nullptr;
  }
}

void OCCTPlateRelease(OCCTPlateRef plate)
{
  if (plate)
  {
    delete (Plate_Plate*)plate;
  }
}

void OCCTPlateLoadPinpoint(OCCTPlateRef plate,
                           double       u,
                           double       v,
                           double       x,
                           double       y,
                           double       z,
                           int32_t      iu,
                           int32_t      iv)
{
  try
  {
    auto* p = (Plate_Plate*)plate;
    p->Load(Plate_PinpointConstraint(gp_XY(u, v), gp_XYZ(x, y, z), iu, iv));
  }
  catch (...)
  {
  }
}

void OCCTPlateLoadGtoC(OCCTPlateRef plate, double u, double v, const double* d1s, const double* d1t)
{
  try
  {
    auto*    p = (Plate_Plate*)plate;
    Plate_D1 src(gp_XYZ(d1s[0], d1s[1], d1s[2]), gp_XYZ(d1s[3], d1s[4], d1s[5]));
    Plate_D1 tgt(gp_XYZ(d1t[0], d1t[1], d1t[2]), gp_XYZ(d1t[3], d1t[4], d1t[5]));
    p->Load(Plate_GtoCConstraint(gp_XY(u, v), src, tgt));
  }
  catch (...)
  {
  }
}

bool OCCTPlateSolve(OCCTPlateRef plate, int32_t order, double anisotropy)
{
  try
  {
    auto* p = (Plate_Plate*)plate;
    p->SolveTI(order, anisotropy, Message_ProgressRange());
    return p->IsDone();
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTPlateIsDone(OCCTPlateRef plate)
{
  try
  {
    return ((Plate_Plate*)plate)->IsDone();
  }
  catch (...)
  {
    return false;
  }
}

void OCCTPlateEvaluate(OCCTPlateRef plate,
                       double       u,
                       double       v,
                       double*      outX,
                       double*      outY,
                       double*      outZ)
{
  try
  {
    auto*  p      = (Plate_Plate*)plate;
    gp_XYZ result = p->Evaluate(gp_XY(u, v));
    *outX         = result.X();
    *outY         = result.Y();
    *outZ         = result.Z();
  }
  catch (...)
  {
    *outX = *outY = *outZ = 0;
  }
}

void OCCTPlateEvaluateDerivative(OCCTPlateRef plate,
                                 double       u,
                                 double       v,
                                 int32_t      iu,
                                 int32_t      iv,
                                 double*      outX,
                                 double*      outY,
                                 double*      outZ)
{
  try
  {
    auto*  p      = (Plate_Plate*)plate;
    gp_XYZ result = p->EvaluateDerivative(gp_XY(u, v), iu, iv);
    *outX         = result.X();
    *outY         = result.Y();
    *outZ         = result.Z();
  }
  catch (...)
  {
    *outX = *outY = *outZ = 0;
  }
}

void OCCTPlateUVBox(OCCTPlateRef plate, double* umin, double* umax, double* vmin, double* vmax)
{
  try
  {
    auto* p = (Plate_Plate*)plate;
    p->UVBox(*umin, *umax, *vmin, *vmax);
  }
  catch (...)
  {
    *umin = *umax = *vmin = *vmax = 0;
  }
}

int32_t OCCTPlateContinuity(OCCTPlateRef plate)
{
  try
  {
    return (int32_t)((Plate_Plate*)plate)->Continuity();
  }
  catch (...)
  {
    return -1;
  }
}

// MARK: - GeomPlate_BuildAveragePlane (v0.69)
// --- GeomPlate_BuildAveragePlane ---

OCCTAveragePlaneResult OCCTGeomPlateBuildAveragePlane(const double* points,
                                                      int32_t       pointCount,
                                                      int32_t       nbBoundPoints,
                                                      double        tolerance)
{
  OCCTAveragePlaneResult result = {};
  try
  {
    Handle(NCollection_HArray1<gp_Pnt>) pts = new NCollection_HArray1<gp_Pnt>(1, pointCount);
    for (int i = 0; i < pointCount; i++)
    {
      pts->SetValue(i + 1, gp_Pnt(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]));
    }

    GeomPlate_BuildAveragePlane avgPlane(pts, nbBoundPoints, tolerance, 1, 1);

    result.isPlane = avgPlane.IsPlane();
    result.isLine  = avgPlane.IsLine();

    if (result.isPlane)
    {
      Handle(Geom_Plane) plane = avgPlane.Plane();
      if (!plane.IsNull())
      {
        gp_Pnt origin  = plane->Location();
        gp_Dir normal  = plane->Axis().Direction();
        result.normalX = normal.X();
        result.normalY = normal.Y();
        result.normalZ = normal.Z();
        result.originX = origin.X();
        result.originY = origin.Y();
        result.originZ = origin.Z();
      }
      avgPlane.MinMaxBox(result.umin, result.umax, result.vmin, result.vmax);
    }

    if (result.isLine)
    {
      Handle(Geom_Line) line = avgPlane.Line();
      if (!line.IsNull())
      {
        gp_Pnt origin      = line->Lin().Location();
        gp_Dir dir         = line->Lin().Direction();
        result.lineOriginX = origin.X();
        result.lineOriginY = origin.Y();
        result.lineOriginZ = origin.Z();
        result.lineDirX    = dir.X();
        result.lineDirY    = dir.Y();
        result.lineDirZ    = dir.Z();
      }
    }
  }
  catch (...)
  {
  }
  return result;
}

// OCCTGeomPlateErrors was here (#999). It is deleted rather than repaired: see the note where it
// was declared, in OCCTBridge_ProjLib_NLPlate.h, for the kernel measurement.

// MARK: - ShapeConstruct_ProjectCurveOnSurface (v0.75)
// --- ShapeConstruct_ProjectCurveOnSurface ---

OCCTCurve2DRef _Nullable OCCTProjectCurveOnSurface(OCCTCurve3DRef _Nonnull curve,
                                                   OCCTSurfaceRef _Nonnull surface,
                                                   double firstParam,
                                                   double lastParam,
                                                   double precision)
{
  if (!curve || !surface || curve->curve.IsNull() || surface->surface.IsNull())
    return nullptr;
  try
  {
    Handle(ShapeConstruct_ProjectCurveOnSurface) projector =
      new ShapeConstruct_ProjectCurveOnSurface();
    projector->Init(surface->surface, precision);

    Handle(Geom2d_Curve) curve2d;
    bool                 ok = projector->Perform(curve->curve, firstParam, lastParam, curve2d);
    if (!ok || curve2d.IsNull())
      return nullptr;

    auto* ref  = new OCCTCurve2D();
    ref->curve = curve2d;
    return ref;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - ProjLib_ProjectOnSurface (v0.80)
// --- ProjLib_ProjectOnSurface ---

OCCTCurve3DRef _Nullable OCCTProjLibProjectOnSurface(OCCTCurve3DRef curve,
                                                     double         uFirst,
                                                     double         uLast,
                                                     OCCTSurfaceRef surface,
                                                     double         tolerance)
{
  try
  {
    auto* c = (OCCTCurve3D*)curve;
    auto* s = (OCCTSurface*)surface;
    if (!c || c->curve.IsNull() || !s || s->surface.IsNull())
      return nullptr;
    Handle(GeomAdaptor_Surface) as      = new GeomAdaptor_Surface(s->surface);
    Handle(Geom_TrimmedCurve)   trimmed = new Geom_TrimmedCurve(c->curve, uFirst, uLast);
    Handle(GeomAdaptor_Curve)   ac      = new GeomAdaptor_Curve(trimmed);

    ProjLib_ProjectOnSurface proj;
    proj.Load(as);
    proj.Load(ac, tolerance);

    if (proj.IsDone())
    {
      Handle(Geom_BSplineCurve) bsp = proj.BSpline();
      if (!bsp.IsNull())
        return (OCCTCurve3DRef) new OCCTCurve3D{bsp};
    }
    return nullptr;
  }
  catch (...)
  {
    return nullptr;
  }
}

// MARK: - v0.103: Plate Constraint Extensions
// MARK: - Plate Constraint Extensions (v0.103.0)

#include <Plate_PlaneConstraint.hxx>
#include <Plate_LineConstraint.hxx>
#include <Plate_FreeGtoCConstraint.hxx>
#include <Plate_LinearScalarConstraint.hxx>

bool OCCTPlateLoadPlaneConstraint(OCCTPlateRef plate,
                                  double       u,
                                  double       v,
                                  double       px,
                                  double       py,
                                  double       pz,
                                  double       nx,
                                  double       ny,
                                  double       nz)
{
  try
  {
    auto*                 p = (Plate_Plate*)plate;
    gp_XY                 uv(u, v);
    gp_Pln                pln(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz));
    Plate_PlaneConstraint pc(uv, pln);
    p->Load(pc.LSC());
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTPlateLoadLineConstraint(OCCTPlateRef plate,
                                 double       u,
                                 double       v,
                                 double       px,
                                 double       py,
                                 double       pz,
                                 double       dx,
                                 double       dy,
                                 double       dz)
{
  try
  {
    auto*                p = (Plate_Plate*)plate;
    gp_XY                uv(u, v);
    gp_Lin               lin(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
    Plate_LineConstraint lc(uv, lin);
    p->Load(lc.LSC());
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTPlateLoadFreeG1Constraint(OCCTPlateRef plate,
                                   double       u,
                                   double       v,
                                   double       duX,
                                   double       duY,
                                   double       duZ,
                                   double       dvX,
                                   double       dvY,
                                   double       dvZ)
{
  try
  {
    auto*                    p = (Plate_Plate*)plate;
    gp_XY                    uv(u, v);
    Plate_D1                 d1s(gp_XYZ(duX, duY, duZ), gp_XYZ(dvX, dvY, dvZ));
    Plate_D1                 d1t(gp_XYZ(duX, duY, duZ), gp_XYZ(dvX, dvY, dvZ));
    Plate_FreeGtoCConstraint fgtoc(uv, d1s, d1t);
    for (int i = 1; i <= fgtoc.nb_LSC(); i++)
    {
      p->Load(fgtoc.LSC(i));
    }
    for (int i = 1; i <= fgtoc.nb_PPC(); i++)
    {
      p->Load(fgtoc.GetPPC(i));
    }
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - v0.109: Plate Constraints Extensions
// MARK: - Plate Constraints Extensions (v0.109.0)

#include <Plate_GlobalTranslationConstraint.hxx>
#include <Plate_LinearXYZConstraint.hxx>

bool OCCTPlateLoadGlobalTranslation(OCCTPlateRef plate, const double* uvs, int32_t count)
{
  if (!plate || !uvs || count <= 0)
    return false;
  try
  {
    Plate_Plate*                pp = (Plate_Plate*)plate;
    NCollection_Sequence<gp_XY> pts;
    for (int i = 0; i < count; i++)
    {
      pts.Append(gp_XY(uvs[i * 2], uvs[i * 2 + 1]));
    }
    Plate_GlobalTranslationConstraint constraint(pts);
    pp->Load(constraint.LXYZC());
    return true;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTPlateLoadLinearXYZ(OCCTPlateRef  plate,
                            const double* uvs,
                            const double* targets,
                            const double* coeffs,
                            int32_t       count)
{
  if (!plate || !uvs || !targets || !coeffs || count <= 0)
    return false;
  try
  {
    Plate_Plate* pp = (Plate_Plate*)plate;
    // Build PinpointConstraints from UV+target pairs
    NCollection_Array1<Plate_PinpointConstraint> ppc(1, count);
    NCollection_Array2<double>                   coefs(1, 1, 1, count);
    for (int i = 0; i < count; i++)
    {
      gp_XY  uv(uvs[i * 2], uvs[i * 2 + 1]);
      gp_XYZ target(targets[i * 3], targets[i * 3 + 1], targets[i * 3 + 2]);
      ppc.SetValue(i + 1, Plate_PinpointConstraint(uv, target));
      coefs.SetValue(1, i + 1, coeffs[i]);
    }
    Plate_LinearXYZConstraint lc(ppc, coefs);
    pp->Load(lc);
    return true;
  }
  catch (...)
  {
    return false;
  }
}

// MARK: - v0.116: ProjLib Plane/Cylinder Project Line + Plane Project Circle
bool OCCTProjLibPlaneProjectLine(double plnPx,
                                 double plnPy,
                                 double plnPz,
                                 double plnNx,
                                 double plnNy,
                                 double plnNz,
                                 double linPx,
                                 double linPy,
                                 double linPz,
                                 double linDx,
                                 double linDy,
                                 double linDz,
                                 double* _Nonnull resPx,
                                 double* _Nonnull resPy,
                                 double* _Nonnull resDx,
                                 double* _Nonnull resDy)
{
  try
  {
    gp_Pln        pln(gp_Pnt(plnPx, plnPy, plnPz), gp_Dir(plnNx, plnNy, plnNz));
    gp_Lin        lin(gp_Pnt(linPx, linPy, linPz), gp_Dir(linDx, linDy, linDz));
    ProjLib_Plane proj(pln, lin);
    if (proj.IsDone())
    {
      gp_Lin2d l2d = proj.Line();
      *resPx       = l2d.Location().X();
      *resPy       = l2d.Location().Y();
      *resDx       = l2d.Direction().X();
      *resDy       = l2d.Direction().Y();
      return true;
    }
    return false;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTProjLibCylinderProjectLine(double cylPx,
                                    double cylPy,
                                    double cylPz,
                                    double cylDx,
                                    double cylDy,
                                    double cylDz,
                                    double cylRadius,
                                    double linPx,
                                    double linPy,
                                    double linPz,
                                    double linDx,
                                    double linDy,
                                    double linDz,
                                    double* _Nonnull resPx,
                                    double* _Nonnull resPy,
                                    double* _Nonnull resDx,
                                    double* _Nonnull resDy)
{
  try
  {
    gp_Ax3           ax(gp_Pnt(cylPx, cylPy, cylPz), gp_Dir(cylDx, cylDy, cylDz));
    gp_Cylinder      cyl(ax, cylRadius);
    gp_Lin           lin(gp_Pnt(linPx, linPy, linPz), gp_Dir(linDx, linDy, linDz));
    ProjLib_Cylinder proj(cyl, lin);
    if (proj.IsDone())
    {
      gp_Lin2d l2d = proj.Line();
      *resPx       = l2d.Location().X();
      *resPy       = l2d.Location().Y();
      *resDx       = l2d.Direction().X();
      *resDy       = l2d.Direction().Y();
      return true;
    }
    return false;
  }
  catch (...)
  {
    return false;
  }
}

bool OCCTProjLibPlaneProjectCircle(double plnPx,
                                   double plnPy,
                                   double plnPz,
                                   double plnNx,
                                   double plnNy,
                                   double plnNz,
                                   double cirCx,
                                   double cirCy,
                                   double cirCz,
                                   double cirNx,
                                   double cirNy,
                                   double cirNz,
                                   double cirRadius,
                                   double* _Nonnull resCx,
                                   double* _Nonnull resCy,
                                   double* _Nonnull resRadius)
{
  try
  {
    gp_Pln        pln(gp_Pnt(plnPx, plnPy, plnPz), gp_Dir(plnNx, plnNy, plnNz));
    gp_Ax2        ax(gp_Pnt(cirCx, cirCy, cirCz), gp_Dir(cirNx, cirNy, cirNz));
    gp_Circ       circ(ax, cirRadius);
    ProjLib_Plane proj(pln, circ);
    if (proj.IsDone())
    {
      gp_Circ2d c2d = proj.Circle();
      *resCx        = c2d.Location().X();
      *resCy        = c2d.Location().Y();
      *resRadius    = c2d.Radius();
      return true;
    }
    return false;
  }
  catch (...)
  {
    return false;
  }
}

// end of v0.117.0 implementations
