// #1979 kernel parity for Curve2DBisectorTests, Curve2DBoundingBoxTests and
// Curve2DBSplineExtrasTests: the same OCCT calls, with the same inputs, that OCCTCurve2DBisectorCC,
// OCCTCurve2DBisectorPC, OCCTCurve2DGetBoundingBox, OCCTCurve2DBSplineGetWeight(s) and
// OCCTCurve2DBSplineSetPeriodic make.
#include <Geom2d_Circle.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GC_MakeSegment2d.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Bisector_BisecCC.hxx>
#include <Bisector_BisecPC.hxx>
#include <BndLib_Add2dCurve.hxx>
#include <Bnd_Box2d.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <vector>

static Handle(Geom2d_TrimmedCurve) seg(double x1, double y1, double x2, double y2)
{
  return GC_MakeSegment2d(gp_Pnt2d(x1, y1), gp_Pnt2d(x2, y2)).Value();
}

static void info(const char* tag, const Handle(Geom2d_Curve)& c)
{
  double f = c->FirstParameter(), l = c->LastParameter();
  printf("%s domain=[%.12g, %.12g]\n", tag, f, l);
  for (double t : {0.0, 0.25, 0.5, 0.75, 1.0})
  {
    double   u = f + t * (l - f);
    gp_Pnt2d p = c->Value(u);
    printf("  value(%.12g)=(%.12g, %.12g)\n", u, p.X(), p.Y());
  }
}

static Handle(Geom2d_BSplineCurve) interp(const std::vector<gp_Pnt2d>& v)
{
  Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, (int)v.size());
  for (int i = 0; i < (int)v.size(); i++)
    pts->SetValue(i + 1, v[i]);
  Geom2dAPI_Interpolate in(pts, false, 1e-6);
  in.Perform();
  return in.Curve();
}

int main()
{
  {
    Handle(Bisector_BisecCC) b = new Bisector_BisecCC();
    b->Perform(seg(0, 0, 10, 0), seg(0, 0, 0, 10), 1.0, 1.0, gp_Pnt2d(0, 0));
    printf("BisecCC segments from origin: empty=%d\n", b->IsEmpty());
    if (!b->IsEmpty())
      info("  bisector", b);
  }
  {
    Handle(Bisector_BisecPC) b = new Bisector_BisecPC();
    b->Perform(seg(-10, 0, 10, 0), gp_Pnt2d(0, 5), 1.0, 100);
    printf("BisecPC point (0,5) / segment y=0: empty=%d\n", b->IsEmpty());
    if (!b->IsEmpty())
      info("  bisector", b);
  }
  {
    Bnd_Box2d box;
    BndLib_Add2dCurve::Add(seg(1, 2, 5, 8), 0.0, box);
    double a, b, c, d;
    box.Get(a, b, c, d);
    printf("BndLib segment (1,2)-(5,8): [%.17g, %.17g] - [%.17g, %.17g]\n", a, b, c, d);
    Bnd_Box2d box2;
    BndLib_Add2dCurve::Add(new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(10, 10), gp_Dir2d(1, 0)), 5), 0.0,
                           box2);
    box2.Get(a, b, c, d);
    printf("BndLib circle c(10,10) r5: [%.17g, %.17g] - [%.17g, %.17g]\n", a, b, c, d);
  }
  {
    auto c = interp({gp_Pnt2d(0, 0), gp_Pnt2d(3, 5), gp_Pnt2d(6, 2), gp_Pnt2d(10, 10)});
    printf("interpolant weights: poles=%d rational=%d w(1)=%.17g\n", c->NbPoles(), c->IsRational(),
           c->Weight(1));
  }
  {
    auto c = interp(
      {gp_Pnt2d(0, 0), gp_Pnt2d(5, 5), gp_Pnt2d(10, 0), gp_Pnt2d(5, -5), gp_Pnt2d(0, 0)});
    printf("closed-point interpolant: closed=%d periodic=%d poles=%d\n", c->IsClosed(),
           c->IsPeriodic(), c->NbPoles());
    try
    {
      c->SetPeriodic();
      printf("  SetPeriodic: ok periodic=%d poles=%d domain=[%.12g, %.12g]\n", c->IsPeriodic(),
             c->NbPoles(), c->FirstParameter(), c->LastParameter());
    }
    catch (const Standard_Failure&)
    {
      printf("  SetPeriodic: raised\n");
    }
  }
  return 0;
}
