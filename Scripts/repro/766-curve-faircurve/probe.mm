// Epic #766 (#1978), kernel parity for FairCurveBattenTests.swift and
// FairCurveMinimalVariationTests.swift. Same inputs and the same calls as OCCTFairCurveBatten /
// OCCTFairCurveMinimalVariation: FairCurve_Batten / FairCurve_MinimalVariation with the Swift
// defaults (slope 0, angles 0, constraint orders 1, free sliding, physical ratio 0), Compute(code,
// 50, 1e-3).
#include <FairCurve_Batten.hxx>
#include <FairCurve_MinimalVariation.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <cstdio>

static void report(const char* name, bool ok, FairCurve_AnalysisCode code, const Handle(Geom2d_BSplineCurve)& c)
{
  printf("%s: ok=%d code=%d", name, ok, (int)code);
  if (ok && !c.IsNull())
  {
    gp_Pnt2d a = c->StartPoint(), b = c->EndPoint(), m = c->Value((c->FirstParameter() + c->LastParameter()) / 2);
    printf(" degree=%d poles=%d domain=[%.17g, %.17g] start=(%.17g, %.17g) mid=(%.17g, %.17g) end=(%.17g, %.17g)",
           c->Degree(), c->NbPoles(), c->FirstParameter(), c->LastParameter(), a.X(), a.Y(), m.X(),
           m.Y(), b.X(), b.Y());
  }
  printf("\n");
}

static void batten(const char* name, double h, double slope, double a1, double a2, int o1, int o2)
{
  FairCurve_Batten b(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0), h, slope);
  b.SetAngle1(a1);
  b.SetAngle2(a2);
  b.SetConstraintOrder1(o1);
  b.SetConstraintOrder2(o2);
  b.SetFreeSliding(true);
  FairCurve_AnalysisCode code;
  bool                   ok = b.Compute(code, 50, 1.0e-3);
  report(name, ok, code, ok ? b.Curve() : Handle(Geom2d_BSplineCurve)());
}

static void mv(const char* name, double ratio, int o1, int o2, double c1, double c2)
{
  FairCurve_MinimalVariation m(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0), 2.0, 0.0, ratio);
  m.SetAngle1(0);
  m.SetAngle2(0);
  m.SetConstraintOrder1(o1);
  m.SetConstraintOrder2(o2);
  m.SetFreeSliding(true);
  if (o1 >= 2)
    m.SetCurvature1(c1);
  if (o2 >= 2)
    m.SetCurvature2(c2);
  FairCurve_AnalysisCode code;
  bool                   ok = m.Compute(code, 50, 1.0e-3);
  report(name, ok, code, ok ? m.Curve() : Handle(Geom2d_BSplineCurve)());
}

int main()
{
  batten("basicBatten h=2", 2.0, 0, 0, 0, 1, 1);
  batten("battenWithSlope h=3 slope=0.5", 3.0, 0.5, 0, 0, 1, 1);
  batten("battenWithAngles h=2 a=+-0.3", 2.0, 0, 0.3, -0.3, 1, 1);
  batten("battenConstraintOrders 0,0", 2.0, 0, 0, 0, 0, 0);
  mv("basicMinimalVariation", 0.0, 1, 1, 0, 0);
  mv("withCurvatureConstraints 2,2 k=0.1", 0.0, 2, 2, 0.1, 0.1);
  mv("withPhysicalRatio 0.5", 0.5, 1, 1, 0, 0);
  return 0;
}
