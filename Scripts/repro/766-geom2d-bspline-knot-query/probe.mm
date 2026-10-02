// #1979 kernel parity for Curve2DBSplineKnotQueryTests: the Geom2d_BSplineCurve queries the
// OCCTCurve2DBSpline* query bridge functions make, on the same Geom2dAPI_Interpolate curve.
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <cstdio>

int main()
{
  Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 3);
  pts->SetValue(1, gp_Pnt2d(0, 0));
  pts->SetValue(2, gp_Pnt2d(1, 1));
  pts->SetValue(3, gp_Pnt2d(2, 0));
  Geom2dAPI_Interpolate in(pts, false, 1e-6);
  in.Perform();
  Handle(Geom2d_BSplineCurve) c = in.Curve();
  printf("degree=%d FirstUKnotIndex=%d LastUKnotIndex=%d NbKnots=%d KnotDistribution=%d\n",
         c->Degree(), c->FirstUKnotIndex(), c->LastUKnotIndex(), c->NbKnots(),
         (int)c->KnotDistribution());
  for (int i = 1; i <= c->NbKnots(); i++)
    printf("  knot %d = %.17g mult %d\n", i, c->Knot(i), c->Multiplicity(i));
  printf("poles=%d\n", c->NbPoles());
  for (int i = 1; i <= c->NbPoles(); i++)
    printf("  pole %d = (%.12g, %.12g)\n", i, c->Pole(i).X(), c->Pole(i).Y());
  printf("start=(%.12g, %.12g) end=(%.12g, %.12g)\n", c->StartPoint().X(), c->StartPoint().Y(),
         c->EndPoint().X(), c->EndPoint().Y());
  printf("closed=%d periodic=%d continuity=%d IsCN(0..4)=%d%d%d%d%d\n", c->IsClosed(),
         c->IsPeriodic(), (int)c->Continuity(), c->IsCN(0), c->IsCN(1), c->IsCN(2), c->IsCN(3),
         c->IsCN(4));
  return 0;
}
