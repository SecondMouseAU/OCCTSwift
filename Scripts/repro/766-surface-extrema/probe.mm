// Kernel parity probe for Tests/OCCTAnalysisTests/SurfaceExtremaTests.swift (#766).
//
// Same calls as OCCTSurfaceExtrema (OCCTBridge_Surface_Conversion.mm): GeomAPI_ExtremaSurfaceSurface
// over the caller's UV boxes, then NbExtrema, LowerDistance, NearestPoints and
// LowerDistanceParameters. Surfaces built as OCCTSurfaceCreateSphere (gp_Ax3(center, gp::DZ()))
// and OCCTSurfaceCreateCylinder (gp_Ax3(origin, dir)) build them.
#include <GeomAPI_ExtremaSurfaceSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <gp.hxx>
#include <gp_Ax3.hxx>
#include <cstdio>

static void run(const char*                 label,
                const Handle(Geom_Surface)& s1,
                const Handle(Geom_Surface)& s2,
                double                      u1a,
                double                      u1b,
                double                      v1a,
                double                      v1b,
                double                      u2a,
                double                      u2b,
                double                      v2a,
                double                      v2b)
{
  GeomAPI_ExtremaSurfaceSurface ex(s1, s2, u1a, u1b, v1a, v1b, u2a, u2b, v2a, v2b);
  int                           nb = ex.NbExtrema();
  printf("%s nbExtrema=%d\n", label, nb);
  if (nb <= 0)
    return;
  gp_Pnt p1, p2;
  ex.NearestPoints(p1, p2);
  double u1, v1, u2, v2;
  ex.LowerDistanceParameters(u1, v1, u2, v2);
  printf("%s distance=%.17g\n", label, ex.LowerDistance());
  printf("%s p1=(%.17g, %.17g, %.17g) p2=(%.17g, %.17g, %.17g)\n", label, p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
  printf("%s uv1=(%.17g, %.17g) uv2=(%.17g, %.17g)\n", label, u1, v1, u2, v2);
}

static Handle(Geom_Surface) sphere(double x, double y, double z, double r)
{
  return new Geom_SphericalSurface(gp_Ax3(gp_Pnt(x, y, z), gp::DZ()), r);
}

int main()
{
  const double pi = M_PI;
  run("sphereDistance", sphere(0, 0, 0, 3), sphere(20, 0, 0, 5), 0, 2 * pi, -pi / 2, pi / 2, 0, 2 * pi, -pi / 2, pi / 2);
  run("nearestPointsAndUV", sphere(0, 0, 0, 4), sphere(30, 0, 0, 6), 0, 2 * pi, -pi / 2, pi / 2, 0, 2 * pi, -pi / 2, pi / 2);
  Handle(Geom_Surface) cyl = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  run("cylinderSphereDistance", cyl, sphere(20, 0, 0, 3), 0, 2 * pi, 0, 10, 0, 2 * pi, -pi / 2, pi / 2);
  return 0;
}
