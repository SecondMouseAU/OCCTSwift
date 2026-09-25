// Epic #766, BSplineSurfaceExtrasTests.swift, BSplineSurfaceFillTests.swift,
// BSplineSurfaceIsoTests.swift and BSplineSurfaceKnotSplitTests.swift: kernel parity for the ten
// tests. Same inputs, straight to OCCT:
//  - makeModThreeGridBSplineSurface(): GeomAPI_PointsToBSplineSurface on the 4x4 grid
//    z = (u + v) % 3, degree 3..3 (fromPointGrid caps degMax at min(u, v) count - 1), C2, 1e-3,
//    then Resolution(0.01), Weight(1, 1), SetU/VNotPeriodic.
//  - GeomFill_BSplineCurves on GeomAPI_Interpolate curves (tolerance 1e-6) for the two-curve
//    fills and on GeomAPI_PointsToBSpline(3, 8, C2, 1e-3) curves for the Coons fill.
//  - GeomConvert::SurfaceToBSplineSurface(sphere r = 5): UIso/VIso at mid-parameters, and
//    GeomConvert_BSplineSurfaceKnotSplitting(bs, 0, 0).
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_BSplineSurfaceKnotSplitting.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Curve.hxx>
#include <Geom_SphericalSurface.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_HArray1.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <cstdio>
#include <vector>

static void pt(const char* tag, const gp_Pnt& p)
{
  printf("%s=(%.17g, %.17g, %.17g)", tag, p.X(), p.Y(), p.Z());
}

static Handle(Geom_BSplineCurve) interp(std::vector<gp_Pnt> v)
{
  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, (int)v.size());
  for (size_t i = 0; i < v.size(); i++)
    a->SetValue((int)i + 1, v[i]);
  GeomAPI_Interpolate g(a, false, 1e-6);
  g.Perform();
  return g.Curve();
}

static Handle(Geom_BSplineCurve) fit(std::vector<gp_Pnt> v)
{
  NCollection_Array1<gp_Pnt> a(1, (int)v.size());
  for (size_t i = 0; i < v.size(); i++)
    a((int)i + 1) = v[i];
  GeomAPI_PointsToBSpline f(a, 3, 8, GeomAbs_C2, 1e-3);
  return f.Curve();
}

static void fill(const char* name, Handle(Geom_BSplineSurface) s)
{
  printf("%s: ", name);
  if (s.IsNull())
  {
    printf("null\n");
    return;
  }
  double u1, u2, v1, v2;
  s->Bounds(u1, u2, v1, v2);
  printf("bounds=[%.17g, %.17g]x[%.17g, %.17g] ", u1, u2, v1, v2);
  pt("S(u1,v1)", s->Value(u1, v1));
  pt(" S(mid,v1)", s->Value((u1 + u2) / 2, v1));
  pt(" S(mid,v2)", s->Value((u1 + u2) / 2, v2));
  pt(" S(0.3,0.6 of domain)", s->Value(u1 + 0.3 * (u2 - u1), v1 + 0.6 * (v2 - v1)));
  printf("\n");
}

int main()
{
  {
    TColgp_Array2OfPnt pts(1, 4, 1, 4);
    for (int v = 0; v < 4; v++)
      for (int u = 0; u < 4; u++)
        pts.SetValue(u + 1, v + 1, gp_Pnt(u * 3.0, v * 3.0, (u + v) % 3));
    GeomAPI_PointsToBSplineSurface a(pts, 3, 3, GeomAbs_C2, 1e-3);
    Handle(Geom_BSplineSurface)    s = a.Surface();
    double                         ur, vr;
    s->Resolution(0.01, ur, vr);
    printf("resolution: Resolution(0.01) u=%.17g v=%.17g (degree %d x %d, %dx%d poles)\n", ur, vr, s->UDegree(), s->VDegree(),
           s->NbUPoles(), s->NbVPoles());
    printf("getWeight: Weight(1,1)=%.17g rational=%d/%d\n", s->Weight(1, 1), s->IsURational(), s->IsVRational());
    gp_Pnt p0 = s->Value(0.3, 0.6);
    s->SetUNotPeriodic();
    s->SetVNotPeriodic();
    gp_Pnt p1 = s->Value(0.3, 0.6);
    double u1, u2, v1, v2;
    s->Bounds(u1, u2, v1, v2);
    printf("setU/VPeriodic(false): SetU/VNotPeriodic moved S(0.3,0.6) by %.3g, IsUPeriodic=%d IsVPeriodic=%d bounds=[%g,%g]x[%g,%g]\n",
           p0.Distance(p1), s->IsUPeriodic(), s->IsVPeriodic(), u1, u2, v1, v2);
    pt("  S(0.3,0.6)", p0);
    printf("\n");
    try
    {
      s->SetUPeriodic();
      printf("  SetUPeriodic() on it: returned\n");
    }
    catch (Standard_Failure& e)
    {
      printf("  SetUPeriodic() on it: threw %s\n", e.GetMessageString());
    }
  }
  {
    auto c1 = interp({gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 2), gp_Pnt(10, 0, 0)});
    auto c2 = interp({gp_Pnt(0, 10, 0), gp_Pnt(5, 10, 2), gp_Pnt(10, 10, 0)});
    fill("twoCurveFill stretch", GeomFill_BSplineCurves(c1, c2, GeomFill_StretchStyle).Surface());
    try
    {
      fill("twoCurveFill curved", GeomFill_BSplineCurves(c1, c2, GeomFill_CurvedStyle).Surface());
    }
    catch (Standard_Failure& e)
    {
      printf("twoCurveFill curved: threw %s\n", e.GetMessageString());
    }
    auto d1 = interp({gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 3), gp_Pnt(10, 0, 0)});
    auto d2 = interp({gp_Pnt(0, 10, 0), gp_Pnt(5, 10, 3), gp_Pnt(10, 10, 0)});
    fill("stretchFill stretch", GeomFill_BSplineCurves(d1, d2, GeomFill_StretchStyle).Surface());
    auto f1 = fit({gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 1), gp_Pnt(10, 0, 0)});
    auto f2 = fit({gp_Pnt(10, 0, 0), gp_Pnt(10, 5, 1), gp_Pnt(10, 10, 0)});
    auto f3 = fit({gp_Pnt(10, 10, 0), gp_Pnt(5, 10, 1), gp_Pnt(0, 10, 0)});
    auto f4 = fit({gp_Pnt(0, 10, 0), gp_Pnt(0, 5, 1), gp_Pnt(0, 0, 0)});
    fill("fourCurveCoonsFill coons", GeomFill_BSplineCurves(f1, f2, f3, f4, GeomFill_CoonsStyle).Surface());
    fill("fourCurveCoonsFill stretch", GeomFill_BSplineCurves(f1, f2, f3, f4, GeomFill_StretchStyle).Surface());
  }
  {
    Handle(Geom_BSplineSurface) bs =
      GeomConvert::SurfaceToBSplineSurface(new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5));
    double u1, u2, v1, v2;
    bs->Bounds(u1, u2, v1, v2);
    double             um = (u1 + u2) / 2, vm = (v1 + v2) / 2;
    Handle(Geom_Curve) ui = bs->UIso(um), vi = bs->VIso(vm);
    printf("uIso: u=%.17g ", um);
    pt("UIso(u)(0.3)", ui->Value(0.3));
    pt(" S(u,0.3)", bs->Value(um, 0.3));
    printf("\nvIso: v=%.17g ", vm);
    pt("VIso(v)(1.0)", vi->Value(1.0));
    pt(" S(1.0,v)", bs->Value(1.0, vm));
    printf("\n");
    for (int c = 0; c <= 2; c++)
    {
      GeomConvert_BSplineSurfaceKnotSplitting ks(bs, c, c);
      printf("knotSplitsU: continuity %d: NbUSplits=%d NbVSplits=%d\n", c, ks.NbUSplits(), ks.NbVSplits());
    }
  }
  {
    // Last, because it does not return: the Coons fill with the fourth curve replaced by the
    // first, so the boundary does not close. In the pinned kernel GeomFill_BSplineCurves does not
    // throw here, it faults (SIGSEGV), which no catch can intercept.
    auto g1 = fit({gp_Pnt(0, 0, 0), gp_Pnt(5, 0, 1), gp_Pnt(10, 0, 0)});
    auto g2 = fit({gp_Pnt(10, 0, 0), gp_Pnt(10, 5, 1), gp_Pnt(10, 10, 0)});
    auto g3 = fit({gp_Pnt(10, 10, 0), gp_Pnt(5, 10, 1), gp_Pnt(0, 10, 0)});
    // The same fill with the fourth curve replaced by the first, so the boundary does not close.
    // Printed before the call: in the pinned kernel this does not throw, it faults.
    printf("fourCurveCoonsFill with c4 := c1: calling GeomFill_BSplineCurves...\n");
    fflush(stdout);
    try
    {
      fill("fourCurveCoonsFill c4 := c1", GeomFill_BSplineCurves(g1, g2, g3, g1, GeomFill_CoonsStyle).Surface());
    }
    catch (Standard_Failure& e)
    {
      printf("fourCurveCoonsFill c4 := c1: threw %s\n", e.GetMessageString());
    }
  }
  return 0;
}
