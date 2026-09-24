// Kernel parity probe for Tests/OCCTAnalysisTests/ExtremaExtSSTests.swift (#766), covering the
// two tests #766 filed (parallelPlanes, sphereDistance).
//
// The same Extrema_ExtSS(GeomAdaptor_Surface, GeomAdaptor_Surface, 1e-6, 1e-6) that
// OCCTExtremaExtSS and OCCTExtremaExtSSPoint build, over the surfaces the tests build:
// GC_MakePlane(point, normal) for Surface.plane, and Geom_SphericalSurface(gp_Ax3(centre, DZ), r)
// for Surface.sphere.
#include <Extrema_ExtSS.hxx>
#include <Extrema_POnSurf.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <GC_MakePlane.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <gp_Ax3.hxx>
#include <gp.hxx>
#include <cmath>
#include <cstdio>

static void run(const char* name, const Handle(Geom_Surface)& a, const Handle(Geom_Surface)& b)
{
  GeomAdaptor_Surface as1(a), as2(b);
  Extrema_ExtSS       ext(as1, as2, 1e-6, 1e-6);
  printf("%s: IsDone=%d", name, ext.IsDone());
  if (!ext.IsDone())
  {
    printf("\n");
    return;
  }
  printf(" IsParallel=%d", ext.IsParallel());
  if (ext.IsParallel())
  {
    printf(" SquareDistance(1)=%.17g\n", ext.SquareDistance(1));
    return;
  }
  printf(" NbExt=%d\n", ext.NbExt());
  for (int i = 1; i <= ext.NbExt(); i++)
  {
    Extrema_POnSurf p1, p2;
    ext.Points(i, p1, p2);
    printf("  [%d] sqDist=%.17g dist=%.17g p1=(%.17g, %.17g, %.17g) p2=(%.17g, %.17g, %.17g)\n",
           i, ext.SquareDistance(i), std::sqrt(ext.SquareDistance(i)), p1.Value().X(),
           p1.Value().Y(), p1.Value().Z(), p2.Value().X(), p2.Value().Y(), p2.Value().Z());
  }
}

int main()
{
  Handle(Geom_Plane) p1 = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
  Handle(Geom_Plane) p2 = GC_MakePlane(gp_Pnt(0, 0, 7), gp_Dir(0, 0, 1)).Value();
  run("parallelPlanes", p1, p2);

  Handle(Geom_SphericalSurface) s1 = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 3);
  Handle(Geom_SphericalSurface) s2 = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(10, 0, 0), gp::DZ()), 2);
  run("sphereDistance", s1, s2);
  return 0;
}
