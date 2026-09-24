// #766 kernel parity for six Tests/OCCTAnalysisTests files:
//   ExtremaExtCCTests.swift          Extrema_ExtCC on two GeomAdaptor_Curve over Geom_Line, as
//                                    OCCTExtremaExtCC / OCCTExtremaExtCCPoint
//   ExtremaExtPElCLinTests.swift     Extrema_ExtPElC(p, gp_Lin, 1e-6, RealFirst, RealLast)
//   ExtremaExtPElCParabTests.swift   Extrema_ExtPElC(p, gp_Parab, 1e-6, RealFirst, RealLast)
//   ExtremaExtPElSCylTests.swift     Extrema_ExtPElS(p, gp_Cylinder, 1e-6)
//   ExtremaExtPElSSphereTests.swift  Extrema_ExtPElS(p, gp_Sphere, 1e-6)
//   ExtremaExtPElSTorusTests.swift   Extrema_ExtPElS(p, gp_Torus, 1e-6)
// Arguments mirror the bridge functions (OCCTBridge_Curve3D_Adaptor.mm, _Curve3D_Extrema.mm,
// _Surface_Extrema.mm); 1e-6 is the Swift wrappers' default tolerance.
#include <Extrema_ExtCC.hxx>
#include <Extrema_ExtPElC.hxx>
#include <Extrema_ExtPElS.hxx>
#include <Extrema_POnCurv.hxx>
#include <Extrema_POnSurf.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_Line.hxx>
#include <Precision.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Lin.hxx>
#include <gp_Parab.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <cstdio>

template <class E> static void pel(const char* name, E& e)
{
  printf("%s: IsDone=%d NbExt=%d\n", name, e.IsDone() ? 1 : 0, e.IsDone() ? e.NbExt() : -1);
  for (int i = 1; e.IsDone() && i <= e.NbExt(); ++i)
  {
    gp_Pnt p = e.Point(i).Value();
    printf("  [%d] sq=%.17g point=(%.17g, %.17g, %.17g)\n", i, e.SquareDistance(i), p.X(), p.Y(),
           p.Z());
  }
}

static void extcc(const char* name, gp_Pnt p1, gp_Dir d1, gp_Pnt p2, gp_Dir d2)
{
  Handle(GeomAdaptor_Curve) a = new GeomAdaptor_Curve(new Geom_Line(p1, d1), -10, 10);
  Handle(GeomAdaptor_Curve) b = new GeomAdaptor_Curve(new Geom_Line(p2, d2), -10, 10);
  Extrema_ExtCC             e(*a, *b);
  printf("%s: IsDone=%d IsParallel=%d", name, e.IsDone() ? 1 : 0, e.IsParallel() ? 1 : 0);
  if (e.IsParallel())
  {
    printf(" SquareDistance(1)=%.17g\n", e.SquareDistance(1));
    return;
  }
  printf(" NbExt=%d\n", e.NbExt());
  for (int i = 1; i <= e.NbExt(); ++i)
  {
    Extrema_POnCurv x, y;
    e.Points(i, x, y);
    printf("  [%d] sq=%.17g p1=(%.17g, %.17g, %.17g) p2=(%.17g, %.17g, %.17g)\n", i,
           e.SquareDistance(i), x.Value().X(), x.Value().Y(), x.Value().Z(), y.Value().X(),
           y.Value().Y(), y.Value().Z());
  }
}

int main()
{
  extcc("curveCurveDistance", gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0), gp_Pnt(0, 5, 0), gp_Dir(0, 0, 1));
  extcc("parallelCurves", gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0), gp_Pnt(0, 3, 0), gp_Dir(1, 0, 0));

  {
    Extrema_ExtPElC e(gp_Pnt(0, 5, 0), gp_Lin(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 1e-6, RealFirst(),
                      RealLast());
    pel("pointToLine", e);
  }
  {
    gp_Parab        par(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)), 2);
    Extrema_ExtPElC e(gp_Pnt(0, 10, 0), par, 1e-6, RealFirst(), RealLast());
    pel("pointToParabola", e);
  }
  {
    gp_Cylinder     cyl(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    Extrema_ExtPElS e(gp_Pnt(20, 0, 0), cyl, 1e-6);
    pel("pointToCylinder", e);
  }
  {
    gp_Sphere       sp(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    Extrema_ExtPElS e(gp_Pnt(20, 0, 0), sp, 1e-6);
    pel("pointToSphere", e);
  }
  {
    gp_Torus        tor(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10, 3);
    Extrema_ExtPElS e(gp_Pnt(20, 0, 0), tor, 1e-6);
    pel("pointToTorus", e);
  }
  return 0;
}
