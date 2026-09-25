// Epic #766 (#1978), kernel parity for BSplineApproxInterpContractTests.swift (#507).
// BSplineApproxInterp is GeomAPI_PointsToBSpline(points, 3, 8, C2, tol3D) (OCCTBridge_Curve3D_Curves.mm,
// struct OCCTBSplineApproxInterp), so every contract the tests pin reduces to: which tol3D reaches
// the fit, and what that fit is. Same 24-point helix as the tests.
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <cmath>
#include <cstdio>

static TColgp_Array1OfPnt helix()
{
  TColgp_Array1OfPnt a(1, 24);
  for (int i = 0; i < 24; i++)
  {
    double t = i / 23.0 * 2.0 * M_PI;
    a(i + 1) = gp_Pnt(std::cos(t), std::sin(t), 0.1 * t);
  }
  return a;
}

static Handle(Geom_BSplineCurve) fit(double tol, int degMax = 8)
{
  TColgp_Array1OfPnt pts = helix();
  GeomAPI_PointsToBSpline f(pts, 3, degMax, GeomAbs_C2, tol);
  return f.Curve();
}

static double maxDev(const Handle(Geom_BSplineCurve)& a, const Handle(Geom_BSplineCurve)& b)
{
  double m = 0;
  for (int i = 0; i <= 32; i++)
  {
    double ua = a->FirstParameter() + (a->LastParameter() - a->FirstParameter()) * i / 32.0;
    double ub = b->FirstParameter() + (b->LastParameter() - b->FirstParameter()) * i / 32.0;
    m = std::max(m, a->Value(ua).Distance(b->Value(ub)));
  }
  return m;
}

int main()
{
  auto def   = fit(1e-3);
  auto loose = fit(1e-1);
  auto tight = fit(1e-8);
  printf("default tol3D 1e-3: degree=%d poles=%d\n", def->Degree(), def->NbPoles());
  printf("tol3D 1e-1: degree=%d poles=%d; tol3D 1e-8: degree=%d poles=%d\n", loose->Degree(),
         loose->NbPoles(), tight->Degree(), tight->NbPoles());
  printf("fitToleranceIsObservable: maxDeviation(1e-1 fit, 1e-8 fit) over 33 samples = %.17g\n",
         maxDev(loose, tight));
  printf("tuning setters, interpolatePoint, performOptimal, nbControlPoints are not passed to the "
         "fit, so each pair of fits is the same call: maxDeviation(default, default) = %.17g\n",
         maxDev(def, fit(1e-3)));
  printf("toleranceSettersShareOneValue: convergence 1e-8 then projection 1e-1 -> min = 1e-8; "
         "convergence 1e-1 then projection 1e-8 -> 1e-8: maxDeviation = %.17g\n",
         maxDev(fit(1e-8), fit(std::min(1e-1, 1e-8))));
  auto   c  = fit(1e-6);
  double mx = 0;
  TColgp_Array1OfPnt pts = helix();
  for (int i = 1; i <= 24; i++)
  {
    GeomAPI_ProjectPointOnCurve pr(pts(i), c);
    if (pr.NbPoints() > 0)
      mx = std::max(mx, pr.LowerDistance());
  }
  printf("maxErrorIsBackProjectionDistance: tol3D 1e-6, degree=%d poles=%d, max projection "
         "distance = %.17g\n",
         c->Degree(), c->NbPoles(), mx);
  return 0;
}
