// Epic #766 (#1978), kernel parity for Issue548NonFiniteLengthBoundTests.swift: what the unguarded
// kernel answers for a non-finite bound, re-measured on the pinned kernel. GCPnts_AbscissaPoint::
// Length(adaptor, u1, u2) on a segment, a circle and the 5-point multi-span interpolation (3D and
// 2D), and BRepAdaptor_Curve on a straight edge. Complements Scripts/repro/548-nonfinite-length-bounds.
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <GC_MakeSegment.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <cmath>
#include <cstdio>
#include <limits>

template <class A> static void row(const char* name, A& a)
{
  double f = a.FirstParameter(), l = a.LastParameter(), nan = std::numeric_limits<double>::quiet_NaN(),
         inf = std::numeric_limits<double>::infinity();
  printf("%s: whole %.9g | (f, nan) %g | (nan, l) %g | (nan, nan) %g | (f, +inf) %g | (-inf, l) %g\n", name,
         GCPnts_AbscissaPoint::Length(a), GCPnts_AbscissaPoint::Length(a, f, nan),
         GCPnts_AbscissaPoint::Length(a, nan, l), GCPnts_AbscissaPoint::Length(a, nan, nan),
         GCPnts_AbscissaPoint::Length(a, f, inf), GCPnts_AbscissaPoint::Length(a, -inf, l));
}

int main()
{
  GeomAdaptor_Curve seg(GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value());
  GeomAdaptor_Curve circ(new Geom_Circle(gp_Ax2(), 5));
  row("3D segment", seg);
  row("3D circle", circ);
  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, 5);
  gp_Pnt p[] = {gp_Pnt(0, 0, 0), gp_Pnt(100, 50, 0), gp_Pnt(150, -60, 40), gp_Pnt(250, 30, -20), gp_Pnt(300, 0, 60)};
  for (int i = 0; i < 5; i++)
    a->SetValue(i + 1, p[i]);
  GeomAPI_Interpolate ip(a, false, 1e-7);
  ip.Perform();
  GeomAdaptor_Curve ms(ip.Curve());
  printf("3D multi-span NbIntervals(CN) %d\n", ms.NbIntervals(GeomAbs_CN));
  row("3D multi-span", ms);

  Handle(TColgp_HArray1OfPnt2d) b = new TColgp_HArray1OfPnt2d(1, 5);
  gp_Pnt2d q[] = {gp_Pnt2d(0, 0), gp_Pnt2d(100, 50), gp_Pnt2d(150, -60), gp_Pnt2d(250, 30), gp_Pnt2d(300, 0)};
  for (int i = 0; i < 5; i++)
    b->SetValue(i + 1, q[i]);
  Geom2dAPI_Interpolate ip2(b, false, 1e-7);
  ip2.Perform();
  Geom2dAdaptor_Curve ms2(ip2.Curve());
  row("2D multi-span", ms2);

  BRepAdaptor_Curve e(BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge());
  row("straight edge", e);
  return 0;
}
