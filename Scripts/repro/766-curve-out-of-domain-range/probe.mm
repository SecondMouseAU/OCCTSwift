// Epic #766 (#1978), kernel parity for Issue600OutOfDomainRangeTests.swift: the raw
// GCPnts_AbscissaPoint::Length(adaptor, u1, u2) on each fixture over the out-of-domain ranges the
// suite uses, so the transcript shows what the bridge's confine-or-wind rule changes and what it
// keeps. Whole lengths are the in-domain reference.
#include <GC_MakeSegment.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cstdio>

static void row(const char* name, const Handle(Geom_Curve)& c)
{
  GeomAdaptor_Curve a(c);
  double            f = a.FirstParameter(), l = a.LastParameter(), s = l - f;
  printf("%s: periodic %d domain [%.6g, %.6g] whole %.9g | [f, l+s] %.9g | [l+s, l+2s] %.9g | [f, f+2s] %.9g\n", name,
         a.IsPeriodic(), f, l, GCPnts_AbscissaPoint::Length(a), GCPnts_AbscissaPoint::Length(a, f, l + s),
         GCPnts_AbscissaPoint::Length(a, l + s, l + 2 * s), GCPnts_AbscissaPoint::Length(a, f, f + 2 * s));
}

int main()
{
  row("segment", GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Value());
  TColgp_Array1OfPnt bp(1, 4);
  bp(1) = gp_Pnt(0, 0, 0); bp(2) = gp_Pnt(30, 60, 0); bp(3) = gp_Pnt(70, -40, 20); bp(4) = gp_Pnt(100, 0, 0);
  row("bezier", new Geom_BezierCurve(bp));
  row("arc [0, pi] r5", new Geom_TrimmedCurve(new Geom_Circle(gp_Ax2(), 5), 0, M_PI));
  row("circle r5", new Geom_Circle(gp_Ax2(), 5));
  row("ellipse 8x3", new Geom_Ellipse(gp_Ax2(), 8, 3));
  Handle(TColgp_HArray1OfPnt) pp = new TColgp_HArray1OfPnt(1, 5);
  pp->SetValue(1, gp_Pnt(0, 0, 0)); pp->SetValue(2, gp_Pnt(100, 40, 0)); pp->SetValue(3, gp_Pnt(160, -30, 20));
  pp->SetValue(4, gp_Pnt(60, -90, -10)); pp->SetValue(5, gp_Pnt(-40, -30, 30));
  GeomAPI_Interpolate ip(pp, true, 1e-6);
  ip.Perform();
  row("periodic bspline", ip.Curve());
  return 0;
}
