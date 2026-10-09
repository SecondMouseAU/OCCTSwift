// #1979 kernel parity for Curve2DContinuityQueriesTests, Curve2DContinuityTests and
// Curve2DConvertExtrasTests: the same OCCT calls, with the same inputs, that
// OCCTCurve2DGetContinuity, OCCTCurve2DIsCN, OCCTCurve2DReversedParameter, the MaxDegree queries,
// OCCTCurve2DApproximate, OCCTCurve2DJoinToBSpline + OCCTCurve2DSplitAtDiscontinuities and
// OCCTCurve2DToArcsAndSegments make.
#include <Geom2d_Line.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2dConvert_ApproxCurve.hxx>
#include <Geom2dConvert_CompCurveToBSplineCurve.hxx>
#include <Geom2dConvert_BSplineCurveKnotSplitting.hxx>
#include <Geom2dConvert_ApproxArcsSegments.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <cstdio>

int main()
{
  Handle(Geom2d_TrimmedCurve) s = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(1, 0)).Value();
  printf("segment continuity=%d IsCN(0,1,2)=%d%d%d ReversedParameter(0.2)=%.17g\n",
         (int)s->Continuity(), s->IsCN(0), s->IsCN(1), s->IsCN(2), s->ReversedParameter(0.2));
  printf("Geom2d_BezierCurve::MaxDegree=%d Geom2d_BSplineCurve::MaxDegree=%d\n",
         Geom2d_BezierCurve::MaxDegree(), Geom2d_BSplineCurve::MaxDegree());
  Handle(Geom2d_Line) l = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  printf("line continuity=%d\n", (int)l->Continuity());
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 4);
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(1, 1));
    pts->SetValue(3, gp_Pnt2d(2, 0));
    pts->SetValue(4, gp_Pnt2d(3, 1));
    Geom2dAPI_Interpolate in(pts, false, 1e-6);
    in.Perform();
    printf("interpolant continuity=%d\n", (int)in.Curve()->Continuity());
  }
  Handle(Geom2d_Circle) c5 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
  {
    Geom2dConvert_ApproxCurve a(c5, 1e-3, GeomAbs_C2, 100, 8);
    printf("approx circle r5 tol 1e-3: done=%d degree=%d poles=%d maxError=%.3g\n", a.IsDone(),
           a.Curve()->Degree(), a.Curve()->NbPoles(), a.MaxError());
  }
  {
    Geom2dConvert_CompCurveToBSplineCurve j;
    j.Add(Geom2dConvert::CurveToBSplineCurve(GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(5, 5)).Value()), 1e-6);
    j.Add(Geom2dConvert::CurveToBSplineCurve(GCE2d_MakeSegment(gp_Pnt2d(5, 5), gp_Pnt2d(10, 0)).Value()), 1e-6);
    Handle(Geom2d_BSplineCurve) b = j.BSplineCurve();
    printf("joined: degree=%d knots=%d mults=[", b->Degree(), b->NbKnots());
    for (int i = 1; i <= b->NbKnots(); i++)
      printf("%s%d", i > 1 ? ", " : "", b->Multiplicity(i));
    printf("]\n");
    for (int cont : {0, 1, 2})
    {
      Geom2dConvert_BSplineCurveKnotSplitting sp(b, cont);
      printf("  split continuity %d: NbSplits=%d values=[", cont, sp.NbSplits());
      for (int i = 1; i <= sp.NbSplits(); i++)
        printf("%s%d", i > 1 ? ", " : "", sp.SplitValue(i));
      printf("]\n");
    }
  }
  {
    Geom2dAdaptor_Curve              ad(c5);
    Geom2dConvert_ApproxArcsSegments a(ad, 0.1, 0.1);
    printf("ApproxArcsSegments full circle r5 (0.1, 0.1): count=%d\n", a.GetResult().Length());
    for (int i = 1; i <= a.GetResult().Length(); i++)
      printf("  [%d] %s\n", i, a.GetResult()(i)->DynamicType()->Name());
  }
  return 0;
}
