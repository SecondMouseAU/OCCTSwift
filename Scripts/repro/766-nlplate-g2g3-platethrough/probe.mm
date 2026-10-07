// Epic #766, NLPlateG2G3Tests.swift and ParametricPlateSurfaceTests.swift: kernel parity for the
// eight tests.
//  - NLPlate_NLPlate on the z = 0 Geom_Plane with the tests' constraints, solved as
//    OCCTSurfaceNLPlateG2/G3 (Solve2(2, 1)), OCCTSurfaceNLPlateIncrementalG0
//    (IncrementalSolve(2, 1, 4, false)) and OCCTSurfaceNLPlateEvaluateDerivative (Solve2(2, 1),
//    then EvaluateDerivative); printed as base point + displacement at each constraint's (u, v).
//  - GeomPlate_BuildPlateSurface(degree, 15, 2) + GeomPlate_MakeApprox(tol, 20, 8, tol * 0.1, 0,
//    C1) as OCCTSurfacePlateThrough / occtPlateApproxSurface build it, with the largest distance
//    from an input point to the approximated surface.
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Plane.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG0G2Constraint.hxx>
#include <NLPlate_HPG0G3Constraint.hxx>
#include <NLPlate_NLPlate.hxx>
#include <Plate_D1.hxx>
#include <Plate_D2.hxx>
#include <Plate_D3.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <vector>

static Handle(Geom_Plane) plane()
{
  return new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
}

static void at(const char* name, NLPlate_NLPlate& s, const Handle(Geom_Plane)& p, double u, double v)
{
  gp_XYZ q = p->Value(u, v).XYZ() + s.Evaluate(gp_XY(u, v));
  printf("%s: IsDone=%d S(%g,%g)=(%.9g, %.9g, %.9g)\n", name, s.IsDone(), u, v, q.X(), q.Y(), q.Z());
}

static void plate(const char* name, const std::vector<gp_Pnt>& pts, int degree, double tol)
{
  try
  {
    GeomPlate_BuildPlateSurface b(degree, 15, 2);
    for (const gp_Pnt& p : pts)
      b.Add(new GeomPlate_PointConstraint(p, 0));
    b.Perform();
    GeomPlate_MakeApprox        a(b.Surface(), tol, 20, 8, tol * 0.1, 0, GeomAbs_C1);
    Handle(Geom_BSplineSurface) s = a.Surface();
    double                      worst = 0;
    for (const gp_Pnt& p : pts)
    {
      GeomAPI_ProjectPointOnSurf pr(p, s);
      if (pr.NbPoints() > 0 && pr.LowerDistance() > worst)
        worst = pr.LowerDistance();
    }
    double u1, u2, v1, v2;
    s->Bounds(u1, u2, v1, v2);
    printf("%s: bounds=[%.9g, %.9g]x[%.9g, %.9g] maxPointDistance=%.3g\n", name, u1, u2, v1, v2, worst);
  }
  catch (Standard_Failure& e)
  {
    printf("%s: threw %s\n", name, e.GetMessageString());
  }
}

int main()
{
  {
    auto            p = plane();
    NLPlate_NLPlate s(p);
    s.Load(new NLPlate_HPG0G2Constraint(gp_XY(0.5, 0.5), gp_XYZ(0.5, 0.5, 1.0), Plate_D1(gp_XYZ(1, 0, 0), gp_XYZ(0, 1, 0)),
                                        Plate_D2(gp_XYZ(0, 0, 0.1), gp_XYZ(0, 0, 0), gp_XYZ(0, 0, 0.1))));
    s.Solve2(2, 1);
    at("nlPlateG2Deformation", s, p, 0.5, 0.5);
  }
  {
    auto            p = plane();
    NLPlate_NLPlate s(p);
    gp_XYZ          z(0, 0, 0);
    s.Load(new NLPlate_HPG0G3Constraint(gp_XY(0.3, 0.3), gp_XYZ(0.3, 0.3, 0.5), Plate_D1(gp_XYZ(1, 0, 0), gp_XYZ(0, 1, 0)),
                                        Plate_D2(z, z, z), Plate_D3(z, z, z, z)));
    s.Solve2(2, 1);
    at("nlPlateG3Deformation", s, p, 0.3, 0.3);
  }
  {
    auto            p = plane();
    NLPlate_NLPlate s(p);
    s.Load(new NLPlate_HPG0Constraint(gp_XY(0.5, 0.5), gp_XYZ(0.5, 0.5, 1.0)));
    s.IncrementalSolve(2, 1, 4, false);
    at("nlPlateIncrementalSolve", s, p, 0.5, 0.5);
  }
  {
    auto            p = plane();
    NLPlate_NLPlate s(p);
    s.Load(new NLPlate_HPG0Constraint(gp_XY(0.5, 0.5), gp_XYZ(0.5, 0.5, 1.0)));
    s.Solve2(2, 1);
    gp_XYZ d = s.EvaluateDerivative(gp_XY(0.5, 0.5), 1, 0);
    printf("nlPlateDerivative: IsDone=%d EvaluateDerivative((0.5,0.5), 1, 0)=(%.17g, %.17g, %.17g)\n", s.IsDone(), d.X(), d.Y(), d.Z());
  }
  plate("plateThroughPoints", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 1), gp_Pnt(10, 10, 2), gp_Pnt(0, 10, 1), gp_Pnt(5, 5, 3)}, 3, 0.01);
  plate("plateThroughEvaluable", {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)}, 3, 0.01);
  plate("plateThroughTooFew", {gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0)}, 3, 0.01);
  plate("plateThroughCustomDegree",
        {gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 2), gp_Pnt(10, 0, 0), gp_Pnt(0, 5, 2), gp_Pnt(5, 5, 4), gp_Pnt(10, 5, 2), gp_Pnt(0, 10, 0),
         gp_Pnt(5, 10, 2), gp_Pnt(10, 10, 0)},
        4, 0.001);
  return 0;
}
