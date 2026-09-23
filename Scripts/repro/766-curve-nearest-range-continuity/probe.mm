// Epic #766 (#1978), kernel parity for Issue615NearestParameterRangeTests and
// Issue619ContinuityEncodingTests. #615: Extrema_LocateExtPC from the suite's guesses on the half
// circle and the [3, 8] segment (the primary search the bridge's fallback wraps). #619:
// Geom_BezierCurve::Continuity() on the three-pole Bezier.
#include <Extrema_LocateExtPC.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <cmath>
#include <cstdio>

static void locate(const char* name, const Handle(Geom_Curve)& c, gp_Pnt p, double guess)
{
  GeomAdaptor_Curve   a(c);
  Extrema_LocateExtPC l(p, a, guess, 1e-9);
  printf("%s guess %.6g: done %d", name, guess, (int)l.IsDone());
  if (l.IsDone())
    printf(" param %.12g dist %.12g IsMin %d", l.Point().Parameter(), sqrt(l.SquareDistance()), l.IsMin());
  printf("\n");
}

int main()
{
  Handle(Geom_Curve) half = new Geom_TrimmedCurve(new Geom_Circle(gp_Ax2(), 5), 0, M_PI);
  Handle(Geom_Curve) seg  = new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 3, 8);
  locate("half circle (0,-6,0)", half, gp_Pnt(0, -6, 0), 0);
  locate("half circle (0,-6,0)", half, gp_Pnt(0, -6, 0), M_PI / 2);
  for (double g : {3.0, 5.5, 8.0})
    locate("segment [3,8] (100,0,0)", seg, gp_Pnt(100, 0, 0), g);
  TColgp_Array1OfPnt p(1, 3);
  p(1) = gp_Pnt(0, 0, 0); p(2) = gp_Pnt(1, 1, 0); p(3) = gp_Pnt(2, 0, 0);
  printf("Bezier 3 poles Continuity() %d (GeomAbs_CN = %d)\n", (new Geom_BezierCurve(p))->Continuity(), GeomAbs_CN);
  return 0;
}
