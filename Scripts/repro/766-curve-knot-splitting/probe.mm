// Epic #766 (#1978), kernel parity for Issue398KnotSplittingTests, Issue403LawKnotSplitParamsTests
// and Issue480LawKnotSplitContinuityTests: GeomAPI_Interpolate then GeomConvert_BSplineCurveKnotSplitting
// for the curves, Law_BSplineKnotSplitting for the laws, at every continuity order 0...3.
#include <GeomAPI_Interpolate.hxx>
#include <GeomConvert_BSplineCurveKnotSplitting.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Law_BSpline.hxx>
#include <Law_BSplineKnotSplitting.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static void curveSplits(const char* name, const std::vector<gp_Pnt>& pts)
{
  Handle(TColgp_HArray1OfPnt) a = new TColgp_HArray1OfPnt(1, (int)pts.size());
  for (int i = 0; i < (int)pts.size(); i++)
    a->SetValue(i + 1, pts[i]);
  GeomAPI_Interpolate ip(a, false, 1e-7);
  ip.Perform();
  Handle(Geom_BSplineCurve) c = ip.Curve();
  printf("%s: degree %d knots %d domain [%.17g, %.17g]\n", name, c->Degree(), c->NbKnots(),
         c->FirstParameter(), c->LastParameter());
  for (int o = 0; o <= 3; o++)
  {
    GeomConvert_BSplineCurveKnotSplitting ks(c, o);
    printf("  C%d splits %d", o, ks.NbSplits());
    if (ks.NbSplits() <= 10)
      for (int i = 1; i <= ks.NbSplits(); i++)
        printf(" %.17g", c->Knot(ks.SplitValue(i)));
    printf("\n");
  }
}

static void lawSplits(const char* name, const std::vector<double>& poles, const std::vector<double>& knots,
                      const std::vector<int>& mults, int degree)
{
  TColStd_Array1OfReal    p(1, (int)poles.size()), k(1, (int)knots.size());
  TColStd_Array1OfInteger m(1, (int)mults.size());
  for (int i = 0; i < (int)poles.size(); i++)
    p(i + 1) = poles[i];
  for (int i = 0; i < (int)knots.size(); i++)
  {
    k(i + 1) = knots[i];
    m(i + 1) = mults[i];
  }
  Handle(Law_BSpline) b = new Law_BSpline(p, k, m, degree);
  printf("%s:\n", name);
  for (int o = 0; o <= 3; o++)
  {
    Law_BSplineKnotSplitting ks(b, o);
    printf("  C%d splits %d:", o, ks.NbSplits());
    for (int i = 1; i <= ks.NbSplits(); i++)
      printf(" %g", b->Knot(ks.SplitValue(i)));
    printf("\n");
  }
}

int main()
{
  curveSplits("#398 8-point cubic", {gp_Pnt(0, 0, 0), gp_Pnt(10, 5, 0), gp_Pnt(20, -5, 0), gp_Pnt(30, 5, 0),
                                     gp_Pnt(40, -5, 0), gp_Pnt(50, 5, 0), gp_Pnt(60, -3, 0), gp_Pnt(70, 0, 0)});
  std::vector<gp_Pnt> big;
  for (int i = 0; i < 400; i++)
  {
    double t = i / 399.0 * 12.0 * M_PI;
    big.push_back(gp_Pnt(i * 0.25, sin(t) * 5.0, cos(t * 0.5) * 2.0));
  }
  curveSplits("#398 400-point", big);
  lawSplits("#403 mult-2 at 0.5", {1, 3, 2, 5, 4, 6}, {0, 0.5, 1}, {4, 2, 4}, 3);
  std::vector<double> poles;
  for (int i = 0; i < 8; i++)
    poles.push_back((i % 4) * 1.5);
  lawSplits("#480 cubic, 4 simple interior knots", poles, {0, 1, 2, 3, 4, 5}, {4, 1, 1, 1, 1, 4}, 3);
  poles.clear();
  for (int i = 0; i < 10; i++)
    poles.push_back((i % 4) * 1.5);
  lawSplits("#480 cubic, knot 2 at multiplicity 3", poles, {0, 1, 2, 3, 4, 5}, {4, 1, 3, 1, 1, 4}, 3);
  return 0;
}
