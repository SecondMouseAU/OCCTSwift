// Epic #766 (#1978), kernel parity for Issue477ArcLengthAccuracyTests.swift: the zigzag and helix
// interpolations through GeomAPI_Interpolate, measured with GCPnts_AbscissaPoint::Length (the
// composite integrator the bridge uses) and CPnts_AbscissaPoint::Length (the whole-domain one it
// replaced), plus the segment and circle.
#include <CPnts_AbscissaPoint.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static Handle(Geom_BSplineCurve) interp(const std::vector<gp_Pnt>& p)
{
  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, (int)p.size());
  for (int i = 0; i < (int)p.size(); i++)
    a->SetValue(i + 1, p[i]);
  GeomAPI_Interpolate ip(a, false, 1e-7);
  ip.Perform();
  return ip.Curve();
}

static void report(const char* name, const Handle(Geom_Curve)& c)
{
  GeomAdaptor_Curve a(c);
  double            f = a.FirstParameter(), l = a.LastParameter(), s = l - f;
  printf("%s: domain [%.17g, %.17g]\n", name, f, l);
  printf("  GCPnts whole %.17g | CPnts whole %.17g\n", GCPnts_AbscissaPoint::Length(a),
         CPnts_AbscissaPoint::Length(a, f, l));
  printf("  GCPnts [1/3, 2/3] %.17g | CPnts %.17g\n", GCPnts_AbscissaPoint::Length(a, f + s / 3, f + 2 * s / 3),
         CPnts_AbscissaPoint::Length(a, f + s / 3, f + 2 * s / 3));
  printf("  GCPnts [1/4, 3/4] %.17g reversed %.17g\n", GCPnts_AbscissaPoint::Length(a, f + s / 4, f + 3 * s / 4),
         GCPnts_AbscissaPoint::Length(a, f + 3 * s / 4, f + s / 4));
  printf("  CPnts over [f - s, l + s] (unclamped extension) %.17g\n", CPnts_AbscissaPoint::Length(a, f - s, l + s));
}

int main()
{
  std::vector<gp_Pnt> z, h;
  for (int i = 0; i < 40; i++)
  {
    double s = i / 39.0;
    z.push_back(gp_Pnt(100 * s * s * s, i % 2 == 0 ? 0.0 : 8.0, 5 * sin(6 * M_PI * s)));
  }
  for (int i = 0; i < 60; i++)
  {
    double t = 2 * M_PI * 3 * i / 59.0;
    h.push_back(gp_Pnt(10 * cos(t), 10 * sin(t), 2 * t));
  }
  report("zigzag 40 points", interp(z));
  report("helix 60 points", interp(h));
  report("segment (0,0,0)-(3,4,0)", GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(3, 4, 0)).Value());
  report("circle r 7", new Geom_Circle(gp_Ax2(), 7));
  return 0;
}
