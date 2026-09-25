// #1979 kernel parity for Issue1407EvaluatorGuardTests, Issue1474Curve2DApproxDetailsTests,
// Issue1477Geom2dCurvesTests and Issue1511Curve2DCurveTypeOtherCurveFallbackTests: the same OCCT
// calls, with the same inputs, that OCCTGeom2dEval*D0, occtApproxCurve2D,
// OCCTGeom2dConvertApproxArcsSegments, OCCTCurve2DJoinToBSpline and OCCTCurve2DCurveType make.
#include <Geom2dEval_SineWaveCurve.hxx>
#include <Geom2dEval_CircleInvoluteCurve.hxx>
#include <Geom2dEval_ArchimedeanSpiralCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2dConvert_ApproxCurve.hxx>
#include <Geom2dConvert_ApproxArcsSegments.hxx>
#include <Geom2dConvert_CompCurveToBSplineCurve.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <GCE2d_MakeArcOfCircle.hxx>
#include <gp_Circ2d.hxx>
#include <Standard_Failure.hxx>
#include <cmath>
#include <cstdio>

static Handle(Geom2d_BSplineCurve) seg(double x0, double y0, double x1, double y1)
{
  return Geom2dConvert::CurveToBSplineCurve(GCE2d_MakeSegment(gp_Pnt2d(x0, y0), gp_Pnt2d(x1, y1)).Value());
}

static Handle(Geom2d_BSplineCurve) arc(double cx, double cy, double r, double a0, double a1)
{
  gp_Circ2d c(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), r);
  return Geom2dConvert::CurveToBSplineCurve(GCE2d_MakeArcOfCircle(c, a0, a1, true).Value());
}

int main()
{
  gp_Ax2d ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  try
  {
    Geom2dEval_SineWaveCurve sw(ax, 0, 1, 0);
    printf("sine amplitude 0: constructed (no throw)\n");
  }
  catch (Standard_Failure& e)
  {
    printf("sine amplitude 0: throws %s\n", e.what());
  }
  try
  {
    Geom2dEval_CircleInvoluteCurve inv(ax, 0);
    printf("involute radius 0: constructed (no throw)\n");
  }
  catch (Standard_Failure& e)
  {
    printf("involute radius 0: throws %s\n", e.what());
  }
  try
  {
    Geom2dEval_ArchimedeanSpiralCurve sp(ax, 1, 0);
    printf("spiral growth 0: constructed (no throw)\n");
  }
  catch (Standard_Failure& e)
  {
    printf("spiral growth 0: throws %s\n", e.what());
  }

  {
    Handle(Geom2d_Circle)     c = new Geom2d_Circle(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10));
    Geom2dConvert_ApproxCurve a(c, 1e-9, GeomAbs_C0, 1, 3);
    printf("approx r10 tol 1e-9 C0 1 seg deg 3: done=%d hasResult=%d maxError=%.12g poles=%d\n", a.IsDone(),
           a.HasResult(), a.MaxError(), a.Curve()->NbPoles());
    Handle(Geom2d_Circle)     c5 = new Geom2d_Circle(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5));
    Geom2dConvert_ApproxCurve b(c5, 1e-3, GeomAbs_C2, 100, 8);
    printf("approx r5 tol 1e-3 C2 100 seg deg 8: done=%d hasResult=%d maxError=%.12g poles=%d degree=%d\n", b.IsDone(),
           b.HasResult(), b.MaxError(), b.Curve()->NbPoles(), b.Curve()->Degree());
  }

  {
    Geom2dConvert_CompCurveToBSplineCurve j;
    printf("join l1=%d", j.Add(seg(0, 0, 10, 0), 1e-6));
    printf(" arc1=%d", j.Add(arc(10, 5, 5, -M_PI / 2, M_PI / 2), 1e-6));
    printf(" l2=%d", j.Add(seg(10, 10, 0, 10), 1e-6));
    printf(" arc2=%d\n", j.Add(arc(0, 5, 5, M_PI / 2, 3 * M_PI / 2), 1e-6));
    Geom2dAdaptor_Curve              ad(j.BSplineCurve());
    Geom2dConvert_ApproxArcsSegments aas(ad, 0.1, 0.1);
    printf("ApproxArcsSegments tol 0.1 angTol 0.1: pieces=%d\n", aas.GetResult().Length());
  }
  {
    Geom2dConvert_CompCurveToBSplineCurve j;
    printf("gapped: add (0,0)-(1,0)=%d add (50,50)-(51,50)=%d\n", j.Add(seg(0, 0, 1, 0), 1e-6),
           j.Add(seg(50, 50, 51, 50), 1e-6));
    Geom2dConvert_CompCurveToBSplineCurve k;
    printf("out of order: a=%d c=%d b=%d\n", k.Add(seg(0, 0, 1, 0), 1e-6), k.Add(seg(1, 1, 0, 1), 1e-6),
           k.Add(seg(1, 0, 1, 1), 1e-6));
    Geom2dConvert_CompCurveToBSplineCurve m;
    printf("continuous: c1=%d c2=%d", m.Add(seg(0, 0, 5, 5), 1e-6), m.Add(seg(5, 5, 10, 0), 1e-6));
    Handle(Geom2d_BSplineCurve) r = m.BSplineCurve();
    printf(" start=(%.12g, %.12g) end=(%.12g, %.12g)\n", r->StartPoint().X(), r->StartPoint().Y(), r->EndPoint().X(),
           r->EndPoint().Y());
  }
  {
    Handle(Geom2d_Line) l = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    printf("line GetType=%d (GeomAbs_OffsetCurve=%d, GeomAbs_OtherCurve=%d)\n", (int)Geom2dAdaptor_Curve(l).GetType(),
           (int)GeomAbs_OffsetCurve, (int)GeomAbs_OtherCurve);
  }
  return 0;
}
