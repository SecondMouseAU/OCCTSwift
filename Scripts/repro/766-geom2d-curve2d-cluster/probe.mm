// #766 lift of the Geom2d Curve2D cluster: the kernel facts behind the pins this lift added to
// Curve2DBezierTests, Curve2DBezierCompletionsTests, Curve2DLocalPropertiesTests,
// Curve2DParameterAtLengthTests, Curve2DInteriorTangentTests, Point2DTransformTests,
// Curve2DApproximatedOverloadParityTests and Curve2DTransformTests beyond what the seven v5 probes
// it sits beside measured: the same OCCT calls, with the same inputs, that the bridge functions
// those tests reach make.
#include <Approx_Curve2d.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_CurAndInf2d.hxx>
#include <NCollection_HArray1.hxx>
#include <Precision.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <gp_Trsf2d.hxx>
#include <cmath>
#include <cstdio>
#include <map>
#include <vector>

// ---------------------------------------------------------------------------------------------
// Bezier: Curve2DBezierTests and Curve2DBezierCompletionsTests
// ---------------------------------------------------------------------------------------------

static Handle(Geom2d_BezierCurve) bez(std::initializer_list<gp_Pnt2d> pts,
                                      const std::vector<double>*      w = nullptr)
{
  NCollection_Array1<gp_Pnt2d> a(1, (int)pts.size());
  int                          i = 1;
  for (auto& p : pts)
    a(i++) = p;
  if (!w)
    return new Geom2d_BezierCurve(a);
  NCollection_Array1<double> wa(1, (int)w->size());
  for (size_t k = 0; k < w->size(); k++)
    wa((int)k + 1) = (*w)[k];
  return new Geom2d_BezierCurve(a, wa);
}

static void poles(const char* tag, const Handle(Geom2d_BezierCurve)& c)
{
  printf("%s degree=%d poles=[", tag, c->Degree());
  for (int i = 1; i <= c->NbPoles(); i++)
    printf("%s(%.12g, %.12g)", i > 1 ? ", " : "", c->Pole(i).X(), c->Pole(i).Y());
  printf("]\n");
}

static void bezier()
{
  Handle(Geom2d_BezierCurve) arch = bez({gp_Pnt2d(0, 0), gp_Pnt2d(5, 10), gp_Pnt2d(10, 0)});
  double                     r1 = 0, r2 = 0;
  arch->Resolution(0.1, r1);
  arch->Resolution(0.2, r2);
  printf("arch rational=%d Resolution(0.1)=%.15g Resolution(0.2)=%.15g\n", arch->IsRational(), r1,
         r2);
  arch->SetPole(2, gp_Pnt2d(3, 7));
  double r3 = 0;
  arch->Resolution(0.1, r3);
  printf("arch after SetPole(2, (3, 7)) Resolution(0.1)=%.15g (0.1 / 28 = %.15g)\n", r3, 0.1 / 28);

  std::vector<double> w121 = {1, 2, 1}, w111 = {1, 1, 1};
  Handle(Geom2d_BezierCurve) weighted =
    bez({gp_Pnt2d(0, 0), gp_Pnt2d(5, 10), gp_Pnt2d(10, 0)}, &w121);
  Handle(Geom2d_BezierCurve) unit = bez({gp_Pnt2d(0, 0), gp_Pnt2d(5, 10), gp_Pnt2d(10, 0)}, &w111);
  printf("weights [1, 2, 1] rational=%d; weights [1, 1, 1] rational=%d\n", weighted->IsRational(),
         unit->IsRational());

  std::vector<double> w132 = {1, 3, 2};
  Handle(Geom2d_BezierCurve) skew = bez({gp_Pnt2d(0, 0), gp_Pnt2d(5, 10), gp_Pnt2d(10, 0)}, &w132);
  printf("weights [1, 3, 2] rational=%d value(0.5)=(%.12g, %.12g)\n", skew->IsRational(),
         skew->Value(0.5).X(), skew->Value(0.5).Y());

  Handle(Geom2d_BezierCurve) cubic = bez({gp_Pnt2d(0, 0), gp_Pnt2d(1, 2), gp_Pnt2d(3, 2), gp_Pnt2d(4, 0)});
  printf("cubic degree=%d poles=%d\n", cubic->Degree(), cubic->NbPoles());

  for (int idx : {1, 0, 2})
  {
    Handle(Geom2d_BezierCurve) c = bez({gp_Pnt2d(0, 0), gp_Pnt2d(1, 1)});
    c->InsertPoleAfter(idx, gp_Pnt2d(0.25, 0.75));
    char tag[64];
    snprintf(tag, sizeof tag, "InsertPoleAfter(%d, (0.25, 0.75))", idx);
    poles(tag, c);
  }

  Handle(Geom2d_BezierCurve) quad = bez({gp_Pnt2d(0, 0), gp_Pnt2d(5, 10), gp_Pnt2d(10, 0)});
  const double               us[6] = {0, 0.1, 0.25, 0.5, 0.8, 1};
  gp_Pnt2d                   b4[6];
  for (int i = 0; i < 6; i++)
    b4[i] = quad->Value(us[i]);
  quad->Increase(3);
  poles("Increase(3) of the quadratic", quad);
  double drift = 0;
  for (int i = 0; i < 6; i++)
    drift = std::max(drift, quad->Value(us[i]).Distance(b4[i]));
  printf("  largest drift of the curve over 6 samples: %.3g\n", drift);

  Handle(Geom2d_BezierCurve) st = bez({gp_Pnt2d(1, 2), gp_Pnt2d(5, 10), gp_Pnt2d(9, 3)});
  printf("start/end of [(1, 2), (5, 10), (9, 3)]: start=(%.12g, %.12g) end=(%.12g, %.12g)\n",
         st->StartPoint().X(), st->StartPoint().Y(), st->EndPoint().X(), st->EndPoint().Y());

  Handle(Geom2d_BezierCurve) rv = bez({gp_Pnt2d(0, 0), gp_Pnt2d(10, 20), gp_Pnt2d(30, 5)});
  rv->Reverse();
  poles("Reverse of [(0, 0), (10, 20), (30, 5)]", rv);
}

// ---------------------------------------------------------------------------------------------
// Local properties: Curve2DLocalPropertiesTests
// ---------------------------------------------------------------------------------------------

static const char* typeName(LProp_CIType t)
{
  return t == LProp_Inflection ? "Inflection" : t == LProp_MinCur ? "MinCur" : "MaxCur";
}

static void extrema(const char* tag, const Handle(Geom2d_Curve)& c)
{
  GeomLProp_CurAndInf2d a;
  a.PerformCurExt(c);
  printf("%s PerformCurExt done=%d points=%d\n", tag, a.IsDone(), a.NbPoints());
  for (int i = 1; i <= a.NbPoints(); i++)
  {
    GeomLProp_CLProps2d p(c, a.Parameter(i), 2, Precision::Confusion());
    printf("  u=%.12g type=%s curvature=%.12g\n", a.Parameter(i), typeName(a.Type(i)), p.Curvature());
  }
}

static void localprops()
{
  Handle(Geom2d_Ellipse) el = new Geom2d_Ellipse(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10, 5);
  for (double u : {0.0, M_PI / 2, M_PI, 3 * M_PI / 2})
  {
    GeomLProp_CLProps2d p(el, u, 2, Precision::Confusion());
    printf("ellipse 10x5 u=%.12g curvature=%.12g\n", u, p.Curvature());
  }
  for (double u : {0.0, M_PI / 2})
  {
    GeomLProp_CLProps2d p(el, u, 2, Precision::Confusion());
    gp_Dir2d            nn, tt;
    gp_Pnt2d            centre;
    p.Normal(nn);
    p.Tangent(tt);
    p.CentreOfCurvature(centre);
    printf("ellipse 10x5 u=%.12g: normal=(%.12g, %.12g) tangent=(%.12g, %.12g) centre=(%.12g, %.12g)\n",
           u, nn.X(), nn.Y(), tt.X(), tt.Y(), centre.X(), centre.Y());
  }
  extrema("ellipse 10x5", el);
  Handle(Geom2d_Curve) rev = el->Reversed();
  extrema("ellipse 10x5 reversed", rev);

  Handle(Geom2d_Circle) off = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(3, 4), gp_Dir2d(1, 0)), 5);
  GeomLProp_CLProps2d   top(off, M_PI / 2, 2, Precision::Confusion());
  gp_Dir2d              n, t;
  gp_Pnt2d              cc;
  top.Normal(n);
  top.Tangent(t);
  printf("circle (3,4) r5 u=pi/2: point=(%.12g, %.12g) normal=(%.12g, %.12g) tangent=(%.12g, %.12g)\n",
         off->Value(M_PI / 2).X(), off->Value(M_PI / 2).Y(), n.X(), n.Y(), t.X(), t.Y());
  GeomLProp_CLProps2d other(off, 2.1, 2, Precision::Confusion());
  other.CentreOfCurvature(cc);
  printf("circle (3,4) r5 u=2.1: curvature=%.12g centre=(%.12g, %.12g)\n", other.Curvature(), cc.X(),
         cc.Y());
  Handle(Geom2d_Circle) c1 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
  GeomLProp_CLProps2d   at13(c1, 1.3, 2, Precision::Confusion());
  Handle(Geom2d_Circle) c2 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(3, 4), gp_Dir2d(1, 0)), 2);
  GeomLProp_CLProps2d   small(c2, 0, 2, Precision::Confusion());
  printf("circle r5 u=1.3 curvature=%.12g; circle r2 u=0 curvature=%.12g\n", at13.Curvature(),
         small.Curvature());

  Handle(Geom2d_TrimmedCurve) diag = GCE2d_MakeSegment(gp_Pnt2d(1, 1), gp_Pnt2d(4, 5)).Value();
  GeomLProp_CLProps2d         dp(diag, 2, 1, Precision::Confusion());
  dp.Tangent(t);
  printf("segment (1,1)-(4,5) u=2 tangent=(%.12g, %.12g)\n", t.X(), t.Y());

  // The S-curve's inflection, and the cross product of its first and second derivatives about it.
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 4);
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(2, 5));
    pts->SetValue(3, gp_Pnt2d(5, -5));
    pts->SetValue(4, gp_Pnt2d(8, 0));
    Geom2dAPI_Interpolate in(pts, false, 1e-6);
    in.Perform();
    Handle(Geom2d_BSplineCurve) s = in.Curve();
    GeomLProp_CurAndInf2d       a;
    a.PerformInf(s);
    printf("S-curve PerformInf points=%d\n", a.NbPoints());
    for (int i = 1; i <= a.NbPoints(); i++)
    {
      double u = a.Parameter(i);
      for (double du : {-0.01, 0.0, 0.01})
      {
        gp_Pnt2d p;
        gp_Vec2d d1, d2;
        s->D2(u + du, p, d1, d2);
        printf("  u=%.12g du=%g cross(D1, D2)=%.3g\n", u, du, d1.Crossed(d2));
      }
    }
  }
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 3);
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(5, 3));
    pts->SetValue(3, gp_Pnt2d(10, 0));
    Geom2dAPI_Interpolate in(pts, false, 1e-6);
    in.Perform();
    GeomLProp_CurAndInf2d a;
    a.PerformInf(in.Curve());
    printf("arch (0,0), (5,3), (10,0) PerformInf points=%d\n", a.NbPoints());
    GeomLProp_CurAndInf2d b;
    b.PerformInf(off);
    printf("circle (3,4) r5 PerformInf points=%d\n", b.NbPoints());
  }
}

// ---------------------------------------------------------------------------------------------
// Parameter at length: Curve2DParameterAtLengthTests
// ---------------------------------------------------------------------------------------------

static void paramAtLength()
{
  Handle(Geom2d_Circle)       c = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(1, 1), gp_Dir2d(1, 0)), 10);
  Handle(Geom2d_TrimmedCurve) arc = new Geom2d_TrimmedCurve(c, M_PI / 6, M_PI / 6 + M_PI / 2);
  Geom2dAdaptor_Curve         aa(arc);
  double                      L = GCPnts_AbscissaPoint::Length(aa);
  GCPnts_AbscissaPoint        half(aa, L / 2, aa.FirstParameter());
  GCPnts_AbscissaPoint        full(aa, L, aa.FirstParameter());
  printf("arc about (1,1) r10 from pi/6: first=%.12g last=%.12g length=%.12g param(L/2)=%.12g "
         "param(L)=%.12g\n",
         aa.FirstParameter(), aa.LastParameter(), L, half.Parameter(), full.Parameter());

  Handle(Geom2d_TrimmedCurve) d = GCE2d_MakeSegment(gp_Pnt2d(1, 2), gp_Pnt2d(4, 6)).Value();
  Geom2dAdaptor_Curve         ad(d);
  double                      dl = GCPnts_AbscissaPoint::Length(ad);
  GCPnts_AbscissaPoint        dh(ad, 2.5, ad.FirstParameter());
  GCPnts_AbscissaPoint        df(ad, dl, ad.FirstParameter());
  printf("segment (1,2)-(4,6): first=%.12g last=%.12g length=%.12g param(2.5)=%.12g param(L)=%.12g "
         "point(2.5)=(%.12g, %.12g)\n",
         ad.FirstParameter(), ad.LastParameter(), dl, dh.Parameter(), df.Parameter(),
         d->Value(dh.Parameter()).X(), d->Value(dh.Parameter()).Y());

  Handle(Geom2d_TrimmedCurve) s10 = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)).Value();
  Geom2dAdaptor_Curve         a10(s10);
  GCPnts_AbscissaPoint        back(a10, -5, a10.FirstParameter());
  GCPnts_AbscissaPoint        still(a10, 0, 4);
  GCPnts_AbscissaPoint        earlier(a10, -3, 7);
  printf("segment (0,0)-(10,0): -5 from u=0 -> %.12g; 0 from u=4 -> %.12g; -3 from u=7 -> %.12g\n",
         back.Parameter(), still.Parameter(), earlier.Parameter());
  GCPnts_AbscissaPoint nan(a10, std::nan(""), 0);
  printf("segment (0,0)-(10,0): a NaN distance, done=%d\n", nan.IsDone());

  Handle(Geom2d_TrimmedCurve) s20 = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(20, 0)).Value();
  Geom2dAdaptor_Curve         a20(s20);
  GCPnts_AbscissaPoint        to5(a20, 5, 0);
  GCPnts_AbscissaPoint        to12(a20, 7, to5.Parameter());
  GCPnts_AbscissaPoint        mid(a20, -5, 10);
  printf("segment (0,0)-(20,0): 5 from u=0 -> %.12g; 7 from there -> %.12g; length between = %.12g; "
         "-5 from u=10 -> %.12g\n",
         to5.Parameter(), to12.Parameter(),
         GCPnts_AbscissaPoint::Length(a20, to5.Parameter(), to12.Parameter()), mid.Parameter());
}

// ---------------------------------------------------------------------------------------------
// Interior tangents: Curve2DInteriorTangentTests
// ---------------------------------------------------------------------------------------------

static void interp(const char* tag, const std::vector<gp_Pnt2d>& v,
                   const std::map<int, gp_Vec2d>& tans, bool closed)
{
  Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, (int)v.size());
  for (int i = 0; i < (int)v.size(); i++)
    pts->SetValue(i + 1, v[i]);
  Geom2dAPI_Interpolate in(pts, closed, 1e-6);
  if (!tans.empty())
  {
    NCollection_Array1<gp_Vec2d>      tv(1, (int)v.size());
    Handle(NCollection_HArray1<bool>) fl = new NCollection_HArray1<bool>(1, (int)v.size());
    for (int i = 0; i < (int)v.size(); i++)
    {
      auto it = tans.find(i);
      tv.SetValue(i + 1, it == tans.end() ? gp_Vec2d(0, 0) : it->second);
      fl->SetValue(i + 1, it != tans.end());
    }
    in.Load(tv, fl);
  }
  in.Perform();
  Handle(Geom2d_BSplineCurve) c = in.Curve();
  printf("%s: done=%d closed=%d periodic=%d poles=%d domain=[%.12g, %.12g]\n", tag, in.IsDone(),
         c->IsClosed(), c->IsPeriodic(), c->NbPoles(), c->FirstParameter(), c->LastParameter());
  double u = 0;
  for (int i = 0; i < (int)v.size(); i++)
  {
    if (i > 0)
      u += v[i].Distance(v[i - 1]);
    gp_Pnt2d p;
    gp_Vec2d d1;
    c->D1(u, p, d1);
    gp_Dir2d dir(d1);
    printf("  knot %d u=%.12g miss=%.3g direction=(%.12g, %.12g)\n", i, u, p.Distance(v[i]), dir.X(),
           dir.Y());
  }
}

static void interior()
{
  std::vector<gp_Pnt2d> arch = {gp_Pnt2d(0, 0), gp_Pnt2d(5, 5), gp_Pnt2d(10, 0)};
  interp("arch plain", arch, {}, false);
  interp("arch tangents (1,0) at 0 and 2", arch, {{0, gp_Vec2d(1, 0)}, {2, gp_Vec2d(1, 0)}}, false);
  std::vector<gp_Pnt2d> sym5 = {gp_Pnt2d(0, 0), gp_Pnt2d(2, 3), gp_Pnt2d(5, 2), gp_Pnt2d(8, 3),
                                gp_Pnt2d(10, 0)};
  interp("sym5 plain", sym5, {}, false);
  interp("sym5 tangent (1,2) at 2", sym5, {{2, gp_Vec2d(1, 2)}}, false);
  std::vector<gp_Pnt2d> quad = {gp_Pnt2d(0, 0), gp_Pnt2d(6, 2), gp_Pnt2d(10, 8), gp_Pnt2d(3, 6)};
  interp("quad closed plain", quad, {}, true);
  interp("quad closed tangent (1,0) at 1", quad, {{1, gp_Vec2d(1, 0)}}, true);
  std::vector<gp_Pnt2d> two = {gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)};
  interp("two plain", two, {}, false);
  interp("two tangents (1,0) both", two, {{0, gp_Vec2d(1, 0)}, {1, gp_Vec2d(1, 0)}}, false);
  interp("two tangents (0,1) both", two, {{0, gp_Vec2d(0, 1)}, {1, gp_Vec2d(0, 1)}}, false);
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 2);
    pts->SetValue(1, two[0]);
    pts->SetValue(2, two[1]);
    Geom2dAPI_Interpolate in(pts, false, 1e-6);
    NCollection_Array1<gp_Vec2d>      tv(1, 2);
    Handle(NCollection_HArray1<bool>) fl = new NCollection_HArray1<bool>(1, 2);
    tv.SetValue(1, gp_Vec2d(0, 1));
    tv.SetValue(2, gp_Vec2d(0, 1));
    fl->SetValue(1, true);
    fl->SetValue(2, true);
    in.Load(tv, fl);
    in.Perform();
    Handle(Geom2d_BSplineCurve) c = in.Curve();
    printf("two tangents (0,1) both: value(2.5)=(%.12g, %.12g) value(5)=(%.12g, %.12g)\n",
           c->Value(2.5).X(), c->Value(2.5).Y(), c->Value(5).X(), c->Value(5).Y());
  }
}

// ---------------------------------------------------------------------------------------------
// Approximation: Curve2DApproximatedOverloadParityTests
// ---------------------------------------------------------------------------------------------

static void approx()
{
  Handle(Geom2d_Circle)    c10 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10);
  Handle(Adaptor2d_Curve2d) ad = new Geom2dAdaptor_Curve(c10, 0, 2 * M_PI);
  Approx_Curve2d            a(ad, 0, 2 * M_PI, 1e-6, 1e-6, GeomAbs_C2, 8, 100);
  printf("circle r10 Approx_Curve2d tol=1e-6: done=%d degree=%d poles=%d MaxError2dU=%.3g "
         "MaxError2dV=%.3g\n",
         a.IsDone(), a.Curve()->Degree(), a.Curve()->NbPoles(), a.MaxError2dU(), a.MaxError2dV());
}

// ---------------------------------------------------------------------------------------------
// Transforms: Point2DTransformTests and Curve2DTransformTests
// ---------------------------------------------------------------------------------------------

static void pt(const char* tag, const gp_Trsf2d& t, double x, double y)
{
  Handle(Geom2d_CartesianPoint) p = new Geom2d_CartesianPoint(x, y);
  p->Transform(t);
  printf("%s (%g, %g) -> (%.12g, %.12g)\n", tag, x, y, p->X(), p->Y());
}

static void ln(const char* tag, const gp_Trsf2d& t, gp_Pnt2d lp, gp_Dir2d ld)
{
  Handle(Geom2d_Line) l = new Geom2d_Line(lp, ld);
  l->Transform(t);
  printf("%s: value(0)=(%.12g, %.12g) value(1)=(%.12g, %.12g)\n", tag, l->Value(0).X(),
         l->Value(0).Y(), l->Value(1).X(), l->Value(1).Y());
}

static void transforms()
{
  gp_Trsf2d t;
  t.SetTranslation(gp_Vec2d(-1.5, 0.5));
  pt("point translate (-1.5, 0.5)", t, 1, 2);
  t.SetRotation(gp_Pnt2d(1, 1), M_PI / 2);
  pt("point rotate pi/2 about (1,1)", t, 3, 1);
  t.SetRotation(gp_Pnt2d(1, 1), M_PI);
  pt("point rotate pi about (1,1)", t, 3, 1);
  t.SetScale(gp_Pnt2d(1, 1), 3);
  pt("point scale 3 about (1,1)", t, 3, 5);
  t.SetScale(gp_Pnt2d(1, 1), -1);
  pt("point scale -1 about (1,1)", t, 3, 5);
  t.SetMirror(gp_Pnt2d(1, 1));
  pt("point mirror through (1,1)", t, 3, 1);
  t.SetMirror(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(0, 1)));
  pt("point mirror across the y axis", t, 1, 1);
  t.SetMirror(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 1)));
  pt("point mirror across y = x", t, 2, 0);
  t.SetMirror(gp_Ax2d(gp_Pnt2d(0, 2), gp_Dir2d(1, 0)));
  pt("point mirror across y = 2", t, 1, 5);
  t.SetMirror(gp_Ax2d(gp_Pnt2d(1, 0), gp_Dir2d(1, 1)));
  pt("point mirror across y = x - 1", t, 3, 0);

  gp_Dir2d diag(1, 1);
  t.SetTranslation(gp_Vec2d(5, 3));
  ln("line (1,2)+(1,1) translate (5,3)", t, gp_Pnt2d(1, 2), diag);
  t.SetRotation(gp_Pnt2d(1, 1), M_PI / 2);
  ln("line (3,1)+x rotate pi/2 about (1,1)", t, gp_Pnt2d(3, 1), gp_Dir2d(1, 0));
  ln("line (1,2)+(1,1) rotate pi/2 about (1,1)", t, gp_Pnt2d(1, 2), diag);
  t.SetScale(gp_Pnt2d(1, 1), 3);
  ln("line (3,1)+x scale 3 about (1,1)", t, gp_Pnt2d(3, 1), gp_Dir2d(1, 0));
  t.SetMirror(gp_Pnt2d(1, 1));
  ln("line (3,1)+x mirror through (1,1)", t, gp_Pnt2d(3, 1), gp_Dir2d(1, 0));
  t.SetMirror(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(0, 1)));
  ln("line (1,1)+x mirror across the y axis", t, gp_Pnt2d(1, 1), gp_Dir2d(1, 0));
  t.SetMirror(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 1)));
  ln("line (3,0)+x mirror across y = x", t, gp_Pnt2d(3, 0), gp_Dir2d(1, 0));
  t.SetMirror(gp_Ax2d(gp_Pnt2d(0, 2), gp_Dir2d(1, 0)));
  ln("line (1,5)+x mirror across y = 2", t, gp_Pnt2d(1, 5), gp_Dir2d(1, 0));
}

int main()
{
  bezier();
  localprops();
  paramAtLength();
  interior();
  approx();
  transforms();
  return 0;
}
