// #1979 kernel parity for Curve2DBSplineLocalTests and Curve2DBSplineTests: the same OCCT calls,
// with the same inputs, that the OCCTCurve2DBSplineLocal* bridge functions and the Curve2D
// factories (OCCTCurve2DCreateBezier, OCCTCurve2DCreateBSpline, OCCTCurve2DInterpolate,
// OCCTCurve2DInterpolateWithTangents, OCCTCurve2DFitPoints, OCCTCurve2DDrawAdaptive) make.
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAPI_PointsToBSpline.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <cstdio>
#include <cmath>
#include <vector>

static Handle(Geom2d_BSplineCurve) interp(const std::vector<gp_Pnt2d>& v)
{
  Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, (int)v.size());
  for (int i = 0; i < (int)v.size(); i++)
    pts->SetValue(i + 1, v[i]);
  Geom2dAPI_Interpolate in(pts, false, 1e-6);
  in.Perform();
  return in.Curve();
}

static void local(const char* tag, const std::vector<gp_Pnt2d>& v)
{
  auto   c  = interp(v);
  int    fk = c->FirstUKnotIndex(), lk = c->LastUKnotIndex();
  double u  = 0.5 * (c->Knot(fk) + c->Knot(lk));
  int    i1 = 0, i2 = 0;
  c->LocateU(u, 1e-10, i1, i2);
  gp_Pnt2d P;
  gp_Vec2d V1, V2, V3;
  c->LocalD3(u, i1, i2, P, V1, V2, V3);
  gp_Vec2d dn = c->LocalDN(u, i1, i2, 1);
  gp_Pnt2d g  = c->Value(u);
  printf("%s fk=%d lk=%d u=%.17g span=(%d, %d)\n", tag, fk, lk, u, i1, i2);
  printf("  P=(%.12g, %.12g) global=(%.12g, %.12g)\n  V1=(%.12g, %.12g) V2=(%.12g, %.12g) "
         "V3=(%.12g, %.12g) DN1=(%.12g, %.12g)\n",
         P.X(), P.Y(), g.X(), g.Y(), V1.X(), V1.Y(), V2.X(), V2.Y(), V3.X(), V3.Y(), dn.X(), dn.Y());
}

int main()
{
  local("local 4pt (0,0)(1,1)(2,0)(3,1)", {gp_Pnt2d(0, 0), gp_Pnt2d(1, 1), gp_Pnt2d(2, 0), gp_Pnt2d(3, 1)});
  local("local 3pt (0,0)(1,1)(2,0)", {gp_Pnt2d(0, 0), gp_Pnt2d(1, 1), gp_Pnt2d(2, 0)});
  local("local 4pt (0,0)(1,2)(2,0)(3,2)", {gp_Pnt2d(0, 0), gp_Pnt2d(1, 2), gp_Pnt2d(2, 0), gp_Pnt2d(3, 2)});
  local("local 5pt (0,0)(1,2)(2,0)(3,2)(4,0)",
        {gp_Pnt2d(0, 0), gp_Pnt2d(1, 2), gp_Pnt2d(2, 0), gp_Pnt2d(3, 2), gp_Pnt2d(4, 0)});
  {
    NCollection_Array1<gp_Pnt2d> p(1, 5);
    p(1) = gp_Pnt2d(0, 0);
    p(2) = gp_Pnt2d(2, 5);
    p(3) = gp_Pnt2d(5, 5);
    p(4) = gp_Pnt2d(8, 2);
    p(5) = gp_Pnt2d(10, 0);
    TColStd_Array1OfReal    k(1, 4);
    TColStd_Array1OfInteger m(1, 4);
    for (int i = 1; i <= 4; i++)
      k(i) = i - 1;
    m(1) = 3;
    m(2) = 1;
    m(3) = 1;
    m(4) = 3;
    Handle(Geom2d_BSplineCurve) b = new Geom2d_BSplineCurve(p, k, m, 2);
    gp_Pnt2d                    v = b->Value(1.5);
    printf("bspline deg2 domain=[%.12g, %.12g] value(1.5)=(%.12g, %.12g)\n", b->FirstParameter(),
           b->LastParameter(), v.X(), v.Y());
  }
  {
    auto     c = interp({gp_Pnt2d(0, 0), gp_Pnt2d(3, 4), gp_Pnt2d(6, 1), gp_Pnt2d(10, 5)});
    gp_Pnt2d e = c->EndPoint();
    printf("interpolate 4pt domain=[%.12g, %.12g] end=(%.12g, %.12g) knot2=%.12g value(knot2)=(%.12g, "
           "%.12g)\n",
           c->FirstParameter(), c->LastParameter(), e.X(), e.Y(), c->Knot(2), c->Value(c->Knot(2)).X(),
           c->Value(c->Knot(2)).Y());
  }
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 3);
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(5, 5));
    pts->SetValue(3, gp_Pnt2d(10, 0));
    Geom2dAPI_Interpolate in(pts, false, 1e-6);
    in.Load(gp_Vec2d(1, 1), gp_Vec2d(1, -1));
    in.Perform();
    auto     c = in.Curve();
    gp_Pnt2d p;
    gp_Vec2d d0, d1;
    c->D1(c->FirstParameter(), p, d0);
    c->D1(c->LastParameter(), p, d1);
    printf("interpolate with tangents: start D1=(%.12g, %.12g) end D1=(%.12g, %.12g) mid=(%.12g, %.12g)\n",
           d0.X(), d0.Y(), d1.X(), d1.Y(), c->Value(0.5 * (c->FirstParameter() + c->LastParameter())).X(),
           c->Value(0.5 * (c->FirstParameter() + c->LastParameter())).Y());
  }
  {
    TColgp_Array1OfPnt2d pts(1, 20);
    for (int i = 0; i < 20; i++)
    {
      double t = i / 19.0 * 10.0;
      pts(i + 1) = gp_Pnt2d(t, sin(t));
    }
    Geom2dAPI_PointsToBSpline f(pts, 3, 8, GeomAbs_C2, 1e-3);
    auto                      c = f.Curve();
    printf("fit sin: done=%d degree=%d poles=%d start=(%.12g, %.12g) end=(%.12g, %.12g)\n",
           f.IsDone(), c->Degree(), c->NbPoles(), c->StartPoint().X(), c->StartPoint().Y(),
           c->EndPoint().X(), c->EndPoint().Y());
  }
  {
    auto                        c = interp({gp_Pnt2d(0, 0), gp_Pnt2d(5, 5), gp_Pnt2d(10, 0)});
    Geom2dAdaptor_Curve         ad(c);
    GCPnts_TangentialDeflection s(ad, 0.1, 0.01);
    printf("drawAdaptive (0.1, 0.01) on interpolant (0,0)(5,5)(10,0): points=%d first=(%.12g, %.12g) "
           "last=(%.12g, %.12g)\n",
           s.NbPoints(), s.Value(1).X(), s.Value(1).Y(), s.Value(s.NbPoints()).X(),
           s.Value(s.NbPoints()).Y());
  }
  return 0;
}
