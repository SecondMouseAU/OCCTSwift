// #1979 kernel parity for Curve2DLocalPropertiesTests and Curve2DOperationsTests: the same
// GeomLProp_CLProps2d / GeomLProp_CurAndInf2d queries, Geom2d_TrimmedCurve / Geom2d_OffsetCurve
// constructions, gp_Trsf2d transforms and arc lengths the bridge functions those tests reach make.
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_OffsetCurve.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GeomLProp_CLProps.hxx>
#include <Precision.hxx>
#include <GeomLProp_CurAndInf2d.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <gp_Trsf2d.hxx>
#include <gp_Ax2d.hxx>
#include <cstdio>

static void props(const char* tag, const Handle(Geom2d_Curve)& c, double u)
{
  GeomLProp_CLProps2d p(c, u, 2, Precision::Confusion());
  gp_Dir2d            t, n;
  gp_Pnt2d            cc;
  p.Tangent(t);
  printf("%s u=%.12g curvature=%.12g tangent=(%.12g, %.12g)", tag, u, p.Curvature(), t.X(), t.Y());
  if (p.Curvature() > 1e-12)
  {
    p.Normal(n);
    p.CentreOfCurvature(cc);
    printf(" normal=(%.12g, %.12g) centre=(%.12g, %.12g)", n.X(), n.Y(), cc.X(), cc.Y());
  }
  printf("\n");
}

static void curinf(const char* tag, const Handle(Geom2d_Curve)& c, int mode)
{
  GeomLProp_CurAndInf2d a;
  if (mode == 0)
    a.PerformInf(c);
  else if (mode == 1)
    a.PerformCurExt(c);
  else
    a.Perform(c);
  printf("%s done=%d points=%d\n", tag, a.IsDone(), a.NbPoints());
  for (int i = 1; i <= a.NbPoints(); i++)
    printf("  u=%.12g type=%s\n", a.Parameter(i),
           a.Type(i) == LProp_Inflection ? "Inflection" : a.Type(i) == LProp_MinCur ? "MinCur" : "MaxCur");
}

static void seg(const char* tag, const Handle(Geom2d_Curve)& c)
{
  gp_Pnt2d a = c->Value(c->FirstParameter()), b = c->Value(c->LastParameter());
  printf("%s start=(%.12g, %.12g) end=(%.12g, %.12g)\n", tag, a.X(), a.Y(), b.X(), b.Y());
}

int main()
{
  Handle(Geom2d_Circle) c5 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
  props("circle r5", c5, 0);
  props("circle r5 centre (3,4)", new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(3, 4), gp_Dir2d(1, 0)), 5), 0);
  Handle(Geom2d_TrimmedCurve) s10 = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)).Value();
  props("segment (0,0)-(10,0)", s10, 0.5);
  {
    Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 4);
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(2, 5));
    pts->SetValue(3, gp_Pnt2d(5, -5));
    pts->SetValue(4, gp_Pnt2d(8, 0));
    Geom2dAPI_Interpolate in(pts, false, 1e-6);
    in.Perform();
    curinf("S-curve inflections", in.Curve(), 0);
  }
  Handle(Geom2d_Ellipse) el = new Geom2d_Ellipse(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10, 5);
  curinf("ellipse 10x5 curvature extrema", el, 1);
  curinf("ellipse 10x5 all special points", el, 2);
  seg("trim circle [0, pi/2]", new Geom2d_TrimmedCurve(c5, 0, M_PI / 2));
  {
    Handle(Geom2d_OffsetCurve) oc = new Geom2d_OffsetCurve(s10, 2.0);
    seg("offset segment by 2", oc);
  }
  seg("reversed (0,0)-(10,5)", GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 5)).Value()->Reversed());
  {
    gp_Trsf2d t;
    t.SetTranslation(gp_Vec2d(5, 5));
    Handle(Geom2d_Curve) c = Handle(Geom2d_Curve)::DownCast(s10->Copy());
    c->Transform(t);
    seg("translated by (5,5)", c);
    gp_Trsf2d r;
    r.SetRotation(gp_Pnt2d(0, 0), M_PI / 2);
    Handle(Geom2d_Curve) s12 = GCE2d_MakeSegment(gp_Pnt2d(1, 0), gp_Pnt2d(2, 0)).Value();
    s12->Transform(r);
    seg("(1,0)-(2,0) rotated pi/2", s12);
    gp_Trsf2d sc;
    sc.SetScale(gp_Pnt2d(0, 0), 2);
    Handle(Geom2d_Curve) s13 = GCE2d_MakeSegment(gp_Pnt2d(1, 0), gp_Pnt2d(3, 0)).Value();
    s13->Transform(sc);
    seg("(1,0)-(3,0) scaled 2", s13);
    gp_Trsf2d m;
    m.SetMirror(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)));
    Handle(Geom2d_Curve) s14 = GCE2d_MakeSegment(gp_Pnt2d(0, 1), gp_Pnt2d(10, 1)).Value();
    s14->Transform(m);
    seg("(0,1)-(10,1) mirrored in x-axis", s14);
    gp_Trsf2d mp;
    mp.SetMirror(gp_Pnt2d(0, 0));
    Handle(Geom2d_Curve) s15 = GCE2d_MakeSegment(gp_Pnt2d(1, 1), gp_Pnt2d(2, 1)).Value();
    s15->Transform(mp);
    seg("(1,1)-(2,1) mirrored in origin", s15);
  }
  printf("circle r5 length=%.12g segment (0,0)-(3,4) length=%.12g\n",
         GCPnts_AbscissaPoint::Length(Geom2dAdaptor_Curve(c5)),
         GCPnts_AbscissaPoint::Length(Geom2dAdaptor_Curve(GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(3, 4)).Value())));
  return 0;
}
