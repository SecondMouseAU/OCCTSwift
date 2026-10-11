// Epic #766 (#1978), kernel parity for Issue506ArcLengthBridgeContractTests.swift: re-measures the
// suite's table on the pinned kernel. GCPnts_AbscissaPoint::Length over a pre-bounded
// GeomAdaptor_Curve(c, u1, u2) (the deleted bridge form) against the ranged
// GCPnts_AbscissaPoint::Length(adaptor, u1, u2) over the full adaptor, with the bridge's clamp
// applied by hand for the clamped column.
#include <GCPnts_AbscissaPoint.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <algorithm>
#include <cstdio>

int main()
{
  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, 5);
  gp_Pnt p[] = {gp_Pnt(0, 0, 0), gp_Pnt(10, 40, 0), gp_Pnt(20, 0, 0), gp_Pnt(200, 5, 0), gp_Pnt(210, 60, 30)};
  for (int i = 0; i < 5; i++)
    a->SetValue(i + 1, p[i]);
  GeomAPI_Interpolate ip(a, false, 1e-7);
  ip.Perform();
  Handle(Geom_BSplineCurve) c = ip.Curve();
  GeomAdaptor_Curve         full(c);
  double                    f = c->FirstParameter(), l = c->LastParameter(), s = l - f;
  printf("domain [%.17g, %.17g] whole %.17g\n", f, l, GCPnts_AbscissaPoint::Length(full));
  struct R
  {
    const char* name;
    double      u1, u2;
  } rs[] = {{"forward [0.1, 0.6]", f + 0.1 * s, f + 0.6 * s},
            {"reversed [0.6, 0.1]", f + 0.6 * s, f + 0.1 * s},
            {"overshoot both ends", f - s, l + s},
            {"wholly outside", l + 1, l + 2}};
  for (auto& r : rs)
  {
    printf("%s:", r.name);
    try
    {
      GeomAdaptor_Curve pre(c, r.u1, r.u2);
      printf(" pre-bounded %.17g", GCPnts_AbscissaPoint::Length(pre));
    }
    catch (Standard_Failure& e)
    {
      printf(" pre-bounded throws");
    }
    double lo = std::clamp(std::min(r.u1, r.u2), f, l), hi = std::clamp(std::max(r.u1, r.u2), f, l);
    printf(" | ranged unclamped %.17g | ranged clamped %.17g\n", GCPnts_AbscissaPoint::Length(full, r.u1, r.u2),
           hi > lo ? GCPnts_AbscissaPoint::Length(full, lo, hi) : 0.0);
  }
  return 0;
}
