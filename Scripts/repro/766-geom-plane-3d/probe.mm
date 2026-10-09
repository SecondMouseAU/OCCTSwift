// Kernel parity probe for Tests/OCCTAnalysisTests/GeomPlane3DTests.swift (#1863-#1866).
// Surface.plane(origin: (0,0,2), normal: +Z) is GC_MakePlane(gp_Pnt, gp_Dir) in
// OCCTSurfacePlaneFromPointNormal; the four getters are Geom_Plane::Coefficients, UIso, VIso, Pln.
#include <GC_MakePlane.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Plane.hxx>
#include <gp_Pln.hxx>
#include <cstdio>

int main()
{
  GC_MakePlane maker(gp_Pnt(0, 0, 2), gp_Dir(0, 0, 1));
  printf("IsDone=%d\n", (int)maker.IsDone());
  Handle(Geom_Plane) p = maker.Value();

  double a, b, c, d;
  p->Coefficients(a, b, c, d);
  printf("planeCoefficients: A=%.12g B=%.12g C=%.12g D=%.12g\n", a, b, c, d);

  Handle(Geom_Curve) u = p->UIso(3);
  gp_Pnt             u0 = u->Value(0), u1 = u->Value(1);
  printf("planeUIso(3): point(0)=(%.12g, %.12g, %.12g) point(1)=(%.12g, %.12g, %.12g)\n",
         u0.X(), u0.Y(), u0.Z(), u1.X(), u1.Y(), u1.Z());

  Handle(Geom_Curve) v = p->VIso(3);
  gp_Pnt             v0 = v->Value(0), v1 = v->Value(1);
  printf("planeVIso(3): point(0)=(%.12g, %.12g, %.12g) point(1)=(%.12g, %.12g, %.12g)\n",
         v0.X(), v0.Y(), v0.Z(), v1.X(), v1.Y(), v1.Z());

  gp_Pln pln = p->Pln();
  gp_Pnt o   = pln.Location();
  gp_Dir n   = pln.Axis().Direction();
  printf("planePln: origin=(%.12g, %.12g, %.12g) normal=(%.12g, %.12g, %.12g)\n",
         o.X(), o.Y(), o.Z(), n.X(), n.Y(), n.Z());
  return 0;
}
