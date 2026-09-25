// Epic #766 (#1978), kernel parity for Issue479SampleCountBoundTests and
// Issue481LawKnotSplittingTruncationTests. The #479 ceiling is Swift-side (Sampling), so the kernel
// side is only the ordinary counts: GCPnts_UniformAbscissa on the 200-unit L wire. #481 is
// Law_BSplineKnotSplitting on the 150- and 12-knot multiplicity-3 laws.
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <Law_BSpline.hxx>
#include <Law_BSplineKnotSplitting.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <cstdio>

static void law(int knotCount)
{
  int                     degree = 3;
  TColStd_Array1OfReal    k(1, knotCount);
  TColStd_Array1OfInteger m(1, knotCount);
  int                     sum = 0;
  for (int i = 1; i <= knotCount; i++)
  {
    k(i) = i - 1;
    m(i) = (i == 1 || i == knotCount) ? degree + 1 : 3;
    sum += m(i);
  }
  int                  np = sum - degree - 1;
  TColStd_Array1OfReal p(1, np);
  for (int i = 1; i <= np; i++)
    p(i) = (i - 1) % 7;
  Handle(Law_BSpline)      b = new Law_BSpline(p, k, m, degree);
  Law_BSplineKnotSplitting ks(b, 2);
  printf("law %d knots, C2 splits %d, first index %d last index %d\n", knotCount, ks.NbSplits(),
         ks.SplitValue(1), ks.SplitValue(ks.NbSplits()));
}

int main()
{
  BRepBuilderAPI_MakePolygon poly(gp_Pnt(0, 0, 0), gp_Pnt(100, 0, 0), gp_Pnt(100, 100, 0));
  BRepAdaptor_CompCurve      cc(poly.Wire());
  printf("L wire length %.17g\n", GCPnts_AbscissaPoint::Length(cc));
  for (int n : {2, 5, 21, 100000, 200001})
  {
    GCPnts_UniformAbscissa u(cc, n);
    printf("  uniform abscissa %d -> %d points\n", n, u.NbPoints());
  }
  law(150);
  law(12);
  return 0;
}
