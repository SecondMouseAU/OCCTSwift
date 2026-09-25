// Kernel parity probe for Tests/OCCTAnalysisTests/ExtremaLocateExtCCTests.swift (#766).
//
// Same calls as OCCTExtremaLocateExtCC (OCCTBridge_Curve3D_Adaptor.mm): GeomAdaptor_Curve over
// each curve's caller range, Extrema_LocateExtCC(ac1, ac2, seedU, seedV), IsDone, SquareDistance,
// Point(p1, p2). Curves built as OCCTCurve3DCreateCircle (Geom_Circle(gp_Ax2(center, normal), r))
// and OCCTCurve3DCreateLine (Geom_Line(point, dir)) build them.
#include <Extrema_LocateExtCC.hxx>
#include <Extrema_POnCurv.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <gp_Ax2.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
  Handle(Geom_Line)   line = new Geom_Line(gp_Pnt(10, 0, 3), gp_Dir(0, 1, 0));
  GeomAdaptor_Curve   ac1(circ, 0, 2 * M_PI);
  GeomAdaptor_Curve   ac2(line, -10, 10);
  Extrema_LocateExtCC ext(ac1, ac2, 0, 0);
  printf("localExtremum isDone=%d\n", (int)ext.IsDone());
  if (ext.IsDone())
  {
    Extrema_POnCurv p1, p2;
    ext.Point(p1, p2);
    printf("localExtremum squareDistance=%.17g distance=%.17g\n", ext.SquareDistance(), std::sqrt(ext.SquareDistance()));
    printf("localExtremum p1=(%.17g, %.17g, %.17g) param1=%.17g\n", p1.Value().X(), p1.Value().Y(), p1.Value().Z(), p1.Parameter());
    printf("localExtremum p2=(%.17g, %.17g, %.17g) param2=%.17g\n", p2.Value().X(), p2.Value().Y(), p2.Value().Z(), p2.Parameter());
  }
  return 0;
}
