// Kernel-parity probe for Tests/OCCTAnalysisTests/ExtremaExtPSTests.swift (#1888, #1889).
// Same Geom_SphericalSurface OCCTSurfaceCreateSphere builds (gp_Ax3(center, gp::DZ()), r 5), and
// the same Extrema_ExtPS(point, GeomAdaptor_Surface, 1e-6, 1e-6) OCCTExtremaExtPS and
// OCCTExtremaExtPSPoint run, from the point (0, 0, 10).
#include <Extrema_ExtPS.hxx>
#include <Extrema_POnSurf.hxx>
#include <Geom_SphericalSurface.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <gp.hxx>
#include <gp_Ax3.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  Handle(Geom_SphericalSurface) s  = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
  Handle(GeomAdaptor_Surface)   as = new GeomAdaptor_Surface(s);
  Extrema_ExtPS                 ext(gp_Pnt(0, 0, 10), *as, 1e-6, 1e-6);
  printf("IsDone=%d NbExt=%d\n", ext.IsDone(), ext.IsDone() ? ext.NbExt() : -1);
  if (!ext.IsDone())
    return 1;
  double minD = 1e300;
  for (int i = 1; i <= ext.NbExt(); i++)
  {
    const Extrema_POnSurf& ps = ext.Point(i);
    double                 u, v;
    ps.Parameter(u, v);
    gp_Pnt p = ps.Value();
    double d = std::sqrt(ext.SquareDistance(i));
    if (d < minD)
      minD = d;
    printf("ext %d: SquareDistance=%.17g dist=%.17g point=(%.17g, %.17g, %.17g) |p|=%.17g u=%.17g v=%.17g\n",
           i, ext.SquareDistance(i), d, p.X(), p.Y(), p.Z(),
           std::sqrt(p.X() * p.X() + p.Y() * p.Y() + p.Z() * p.Z()), u, v);
  }
  printf("pointSurfaceDistance: min distance=%.17g\n", minD);
  return 0;
}
