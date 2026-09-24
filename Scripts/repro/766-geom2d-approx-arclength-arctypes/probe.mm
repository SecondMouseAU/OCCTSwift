// #1979 kernel parity for Curve2DApproximatedOverloadParityTests, Curve2DArcLengthFailureTests and
// Curve2DArcTypesTests: the same OCCT calls, with the same inputs, that OCCTCurve2DApproximate,
// OCCTApproxCurve2d, OCCTCurve2DGetLengthBetween, OCCTCurve2DCreateArcOfHyperbola and
// OCCTCurve2DCreateArcOfParabola make.
#include <Geom2d_Circle.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Parabola.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dConvert_ApproxCurve.hxx>
#include <Approx_Curve2d.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <cstdio>
#include <cmath>

static void approx(const char* tag, const Handle(Geom2d_Curve)& c, double tol, GeomAbs_Shape cont)
{
  Geom2dConvert_ApproxCurve a(c, tol, cont, 100, 8);
  Handle(Geom2d_BSplineCurve) b = a.Curve();
  printf("%s Geom2dConvert_ApproxCurve tol=%g cont=%d: done=%d result=%d maxError=%.3g degree=%d "
         "poles=%d\n",
         tag, tol, (int)cont, a.IsDone(), a.HasResult(), a.MaxError(), b.IsNull() ? -1 : b->Degree(),
         b.IsNull() ? -1 : b->NbPoles());
}

int main()
{
  Handle(Geom2d_Circle) c10 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10);
  approx("circle r10", c10, 1e-3, GeomAbs_C2);
  approx("circle r10", c10, 1e-6, GeomAbs_C2);
  approx("circle r10", c10, 1e-3, GeomAbs_C0);
  {
    Handle(Adaptor2d_Curve2d) ad = new Geom2dAdaptor_Curve(c10, 0, 2 * M_PI);
    Approx_Curve2d            a(ad, 0, 2 * M_PI, 1e-6, 1e-6, GeomAbs_C2, 8, 100);
    printf("circle r10 Approx_Curve2d tol=1e-6: done=%d degree=%d poles=%d\n", a.IsDone(),
           a.Curve()->Degree(), a.Curve()->NbPoles());
  }
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 60);
    for (int i = 0; i < 60; i++)
      pts->SetValue(i + 1,
                    gp_Pnt2d(i * 0.5, sin(i * 0.6) * 3.0 + sin(i * 1.3) * 0.6));
    Geom2dAPI_Interpolate in(pts, false, 1e-6);
    in.Perform();
    approx("zigzag", in.Curve(), 1e-3, GeomAbs_C2);
  }
  {
    NCollection_Array1<gp_Pnt2d> p(1, 3);
    p(1) = gp_Pnt2d(0, 0);
    p(2) = gp_Pnt2d(5, 5);
    p(3) = gp_Pnt2d(10, 0);
    Handle(Geom2d_BezierCurve) b = new Geom2d_BezierCurve(p);
    Geom2dAdaptor_Curve        ad(b);
    printf("bezier length(0.2, 0.8)=%.12g length(0.3, 0.3)=%.12g\n",
           GCPnts_AbscissaPoint::Length(ad, 0.2, 0.8), GCPnts_AbscissaPoint::Length(ad, 0.3, 0.3));
  }
  {
    Handle(Geom2d_Hyperbola) h =
      new Geom2d_Hyperbola(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5, 3);
    Handle(Geom2d_TrimmedCurve) t = new Geom2d_TrimmedCurve(h, -0.5, 0.5);
    gp_Pnt2d                    a = t->StartPoint(), b = t->EndPoint();
    printf("arc of hyperbola closed=%d start=(%.12g, %.12g) end=(%.12g, %.12g)\n", t->IsClosed(),
           a.X(), a.Y(), b.X(), b.Y());
  }
  {
    Handle(Geom2d_Parabola)     p = new Geom2d_Parabola(gp_Ax2d(gp_Pnt2d(-2, 0), gp_Dir2d(1, 0)), 2);
    Handle(Geom2d_TrimmedCurve) t = new Geom2d_TrimmedCurve(p, -5, 5);
    gp_Pnt2d                    a = t->StartPoint(), b = t->EndPoint();
    printf("arc of parabola focus=(%.12g, %.12g) closed=%d start=(%.12g, %.12g) end=(%.12g, %.12g)\n",
           p->Focus().X(), p->Focus().Y(), t->IsClosed(), a.X(), a.Y(), b.X(), b.Y());
  }
  return 0;
}
