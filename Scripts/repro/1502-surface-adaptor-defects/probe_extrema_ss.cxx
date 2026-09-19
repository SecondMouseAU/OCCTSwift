// Scratch probe (not part of the #1502 fix set) to pick a two-sphere fixture whose
// surface-surface extremum lands away from either sphere's equator, so V is genuinely
// non-trivial on both sides -- see Issue1502ExtremaSSPointTests.swift.
#include <Geom_SphericalSurface.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Extrema_ExtSS.hxx>
#include <Extrema_POnSurf.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pnt.hxx>
#include <gp_Sphere.hxx>
#include <cstdio>

static Handle(Geom_SphericalSurface) makeSphere(double cx, double cy, double cz, double r)
{
  gp_Ax3 ax(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1));
  return new Geom_SphericalSurface(ax, r);
}

int main()
{
  Handle(Geom_SphericalSurface) s1 = makeSphere(0, 0, 0, 3);
  Handle(Geom_SphericalSurface) s2 = makeSphere(10, 0, 5, 2);

  GeomAdaptor_Surface as1(s1);
  GeomAdaptor_Surface as2(s2);
  Extrema_ExtSS       ext(as1, as2, 1e-6, 1e-6);
  printf("isDone=%d isParallel=%d\n", ext.IsDone(), ext.IsDone() ? ext.IsParallel() : -1);
  if (!ext.IsDone() || ext.IsParallel())
    return 1;
  printf("nbExt=%d\n", ext.NbExt());
  for (int i = 1; i <= ext.NbExt(); i++)
  {
    Extrema_POnSurf p1, p2;
    ext.Points(i, p1, p2);
    double u1, v1, u2, v2;
    p1.Parameter(u1, v1);
    p2.Parameter(u2, v2);
    printf("[%d] d2=%g p1=(%g,%g,%g) u1=%g v1=%g p2=(%g,%g,%g) u2=%g v2=%g\n",
          i,
          ext.SquareDistance(i),
          p1.Value().X(),
          p1.Value().Y(),
          p1.Value().Z(),
          u1,
          v1,
          p2.Value().X(),
          p2.Value().Y(),
          p2.Value().Z(),
          u2,
          v2);
  }
  return 0;
}
