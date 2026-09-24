// Epic #766, Issue1017NLPlateResolutionOrderTests.swift and Issue1049NLPlateBaseSurfaceTests.swift:
// kernel parity. NLPlate_NLPlate on the same planes and constraints the tests use, solved with
// Solve2(order, 1) as OCCTSurfaceNLPlateG0/G1 do, and read back with NLPlate_NLPlate::Evaluate,
// the value occtNLPlateFitSolved samples and refits (so the Swift surface agrees with these to the
// fit tolerance, not exactly).
#include <GC_MakePlane.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG0G1Constraint.hxx>
#include <NLPlate_NLPlate.hxx>
#include <Plate_D1.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <cmath>
#include <cstdio>

static void g0(const char* tag, const Handle(Geom_Surface)& s, int order, const double (*c)[5], int n, double u, double v)
{
  NLPlate_NLPlate solver(s);
  for (int i = 0; i < n; i++)
    solver.Load(new NLPlate_HPG0Constraint(gp_XY(c[i][0], c[i][1]), gp_XYZ(c[i][2], c[i][3], c[i][4])));
  solver.Solve2(order, 1);
  gp_XYZ p = solver.Evaluate(gp_XY(u, v));
  printf("%s: order=%d IsDone=%d Evaluate(%g,%g)=(%.12g, %.12g, %.12g)\n", tag, order, solver.IsDone(), u, v, p.X(), p.Y(), p.Z());
}


// The bridge's own tail (occtNLPlateFitSolved): sample Evaluate on a 20x20 grid over the working
// domain, GeomAPI_PointsToBSplineSurface(poles, 3, 8, C2, tol), then map the knots onto the
// domain. Printed at the constraint's uv (0, 0), with the largest |z| among the samples.
static void fitted(const char* tag, const Handle(Geom_Surface)& s, int order, const double (*c)[5], int n,
                   double d1, double d2, double tol)
{
  NLPlate_NLPlate solver(s);
  for (int i = 0; i < n; i++)
    solver.Load(new NLPlate_HPG0Constraint(gp_XY(c[i][0], c[i][1]), gp_XYZ(c[i][2], c[i][3], c[i][4])));
  solver.Solve2(order, 1);
  TColgp_Array2OfPnt poles(1, 20, 1, 20);
  double             maxZ = 0;
  for (int iu = 1; iu <= 20; iu++)
    for (int iv = 1; iv <= 20; iv++)
    {
      gp_XYZ v      = solver.Evaluate(gp_XY(d1 + (d2 - d1) * (iu - 1) / 19.0, d1 + (d2 - d1) * (iv - 1) / 19.0));
      poles(iu, iv) = gp_Pnt(v);
      maxZ          = std::max(maxZ, std::abs(v.Z()));
    }
  GeomAPI_PointsToBSplineSurface approx;
  approx.Init(poles, 3, 8, GeomAbs_C2, tol);
  Handle(Geom_BSplineSurface) b = approx.Surface();
  double                      fu1, fu2, fv1, fv2;
  b->Bounds(fu1, fu2, fv1, fv2);
  double u = fu1 + (0 - d1) / (d2 - d1) * (fu2 - fu1), v = fv1 + (0 - d1) / (d2 - d1) * (fv2 - fv1);
  gp_Pnt p = b->Value(u, v);
  printf("%s: order=%d fitted surface at uv (0,0) = (%.12g, %.12g, %.12g), max |z| over the 20x20 samples = %.12g\n", tag,
         order, p.X(), p.Y(), p.Z(), maxZ);
}

int main()
{
  Handle(Geom_Surface) plane0 = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
  const double c1017[3][5] = {{-5, -5, -5, -5, 1}, {5, 5, 5, 5, 2}, {0, 0, 0, 0, 5}};
  for (int order : {0, 1, 10, 12, 100, -1, 2, 3, 4, 5, 8, 9})
    g0("1017 G0 three constraints", plane0, order, c1017, 3, 0, 0);
  fitted("1017 refit (working domain [-15, 15]^2, tol 0.1)", plane0, 2, c1017, 3, -15, 15, 0.1);
  fitted("1017 refit (working domain [-15, 15]^2, tol 0.1)", plane0, 8, c1017, 3, -15, 15, 0.1);
  {
    // G1 at an out-of-range order: IsDone reports true and the plate stays undeformed.
    for (int order : {1, 4})
    {
      NLPlate_NLPlate solver(plane0);
      solver.Load(new NLPlate_HPG0G1Constraint(gp_XY(0, 0), gp_XYZ(0, 0, 5), Plate_D1(gp_XYZ(1, 0, 0.5), gp_XYZ(0, 1, 0.5))));
      solver.Solve2(order, 1);
      gp_XYZ p = solver.Evaluate(gp_XY(0, 0));
      printf("1017 G1: order=%d IsDone=%d Evaluate(0,0)=(%.12g, %.12g, %.12g)\n", order, solver.IsDone(), p.X(), p.Y(), p.Z());
    }
  }

  Handle(Geom_Surface) plane100 = GC_MakePlane(gp_Pnt(100, 0, 0), gp_Dir(0, 0, 1)).Value();
  gp_Pnt o = plane100->Value(0, 0), q = plane100->Value(3, 4);
  printf("1049 fixture: S(0,0)=(%g, %g, %g) S(3,4)=(%g, %g, %g)\n", o.X(), o.Y(), o.Z(), q.X(), q.Y(), q.Z());
  const double ident[1][5] = {{0, 0, 100, 0, 0}};
  g0("1049 identity G0", plane100, 4, ident, 1, 10, 10);
  const double pureZ[1][5] = {{0, 0, 100, 0, 5}};
  g0("1049 pure-Z G0 at the constraint", plane100, 4, pureZ, 1, 0, 0);
  g0("1049 pure-Z G0 at a corner", plane100, 4, pureZ, 1, 10, -10);
  Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
  double u1, u2, v1, v2;
  cyl->Bounds(u1, u2, v1, v2);
  printf("1049 cylinder bounds: u=[%.17g, %.17g] v=[%g, %g] (v unbounded: the bridge pads it, u is kept)\n", u1, u2, v1, v2);
  return 0;
}
