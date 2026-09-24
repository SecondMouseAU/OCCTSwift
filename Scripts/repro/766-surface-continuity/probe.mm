// Epic #766, SurfaceContinuityQueriesTests.swift and SurfaceContinuityTests.swift: kernel parity
// for the eleven tests, on the GC_MakePlane z = 0 plane and the radius-5 Geom_SphericalSurface
// the tests build: IsCNu/IsCNv, UReversed/VReversed and the reversed parameters, MaxDegree,
// Continuity, and Bounds (OCCTSurfaceGetNBounds reports 1 span per non-empty range).
#include <GC_MakePlane.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <cstdio>

int main()
{
  Handle(Geom_Surface) plane  = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
  Handle(Geom_Surface) sphere = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5);
  printf("isCNu: %d %d %d  isCNv: %d %d %d\n", plane->IsCNu(0), plane->IsCNu(1), plane->IsCNu(2), plane->IsCNv(0), plane->IsCNv(1),
         plane->IsCNv(2));
  Handle(Geom_Surface) ur = plane->UReversed(), vr = plane->VReversed();
  gp_Pnt               a = ur->Value(3, 4), b = vr->Value(3, 4);
  printf("uReversed: S'(3,4)=(%g,%g,%g)  vReversed: S'(3,4)=(%g,%g,%g)\n", a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
  printf("uReversedParameter(0.5)=%.17g vReversedParameter(0.5)=%.17g\n", plane->UReversedParameter(0.5), plane->VReversedParameter(0.5));
  printf("bezierMaxDegree=%d bsplineMaxDegree=%d\n", Geom_BezierSurface::MaxDegree(), Geom_BSplineSurface::MaxDegree());
  printf("continuity: plane=%d sphere=%d (GeomAbs_CN=%d)\n", (int)plane->Continuity(), (int)sphere->Continuity(), (int)GeomAbs_CN);
  double u1, u2, v1, v2;
  plane->Bounds(u1, u2, v1, v2);
  printf("surfaceNBounds: plane bounds=[%g, %g]x[%g, %g]\n", u1, u2, v1, v2);
  return 0;
}
