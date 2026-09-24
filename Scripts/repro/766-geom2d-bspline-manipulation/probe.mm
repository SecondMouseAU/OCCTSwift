// #1979 kernel parity for BSplineCurve2DManipulationTests: the Geom2d_BSplineCurve queries and
// edits the OCCTCurve2DBSpline* bridge functions make, on the same Geom2dAPI_Interpolate curve.
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <cstdio>

static Handle(Geom2d_BSplineCurve) make()
{
  Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 4);
  pts->SetValue(1, gp_Pnt2d(0, 0));
  pts->SetValue(2, gp_Pnt2d(3, 4));
  pts->SetValue(3, gp_Pnt2d(7, 2));
  pts->SetValue(4, gp_Pnt2d(10, 0));
  Geom2dAPI_Interpolate in(pts, false, 1e-6);
  in.Perform();
  return in.Curve();
}

static void show(const char* tag, const Handle(Geom2d_BSplineCurve)& c)
{
  printf("%s degree=%d rational=%d domain=[%.12g, %.12g] knots=[", tag, c->Degree(),
         c->IsRational(), c->FirstParameter(), c->LastParameter());
  for (int i = 1; i <= c->NbKnots(); i++)
    printf("%s%.12g", i > 1 ? ", " : "", c->Knot(i));
  printf("] mults=[");
  for (int i = 1; i <= c->NbKnots(); i++)
    printf("%s%d", i > 1 ? ", " : "", c->Multiplicity(i));
  printf("] poles=[");
  for (int i = 1; i <= c->NbPoles(); i++)
    printf("%s(%.12g, %.12g)", i > 1 ? ", " : "", c->Pole(i).X(), c->Pole(i).Y());
  printf("]\n");
  double f = c->FirstParameter(), l = c->LastParameter();
  for (double t : {0.0, 0.5, 1.0})
  {
    gp_Pnt2d v = c->Value(f + t * (l - f));
    printf("  value(%.12g)=(%.12g, %.12g)\n", f + t * (l - f), v.X(), v.Y());
  }
}

int main()
{
  Handle(Geom2d_BSplineCurve) c0 = make();
  show("interpolant", c0);
  double r = 0;
  c0->Resolution(0.001, r);
  printf("Resolution(0.001)=%.12g\n", r);
  {
    Handle(Geom2d_BSplineCurve) c = make();
    c->SetPole(2, gp_Pnt2d(3, 6));
    show("SetPole(2, (3, 6))", c);
  }
  {
    Handle(Geom2d_BSplineCurve) c   = make();
    double                      mid = 0.5 * (c->FirstParameter() + c->LastParameter());
    c->InsertKnot(mid, 1, 1e-6);
    show("InsertKnot(mid)", c);
  }
  {
    Handle(Geom2d_BSplineCurve) c = make();
    double f = c->FirstParameter(), l = c->LastParameter();
    c->Segment(f + 0.25 * (l - f), f + 0.75 * (l - f));
    show("Segment(25%, 75%)", c);
  }
  {
    Handle(Geom2d_BSplineCurve) c = make();
    c->IncreaseDegree(c->Degree() + 1);
    show("IncreaseDegree(+1)", c);
  }
  {
    Handle(Geom2d_BSplineCurve) c = make();
    c->SetWeight(1, 2.0);
    show("SetWeight(1, 2.0)", c);
    printf("  weight(1)=%.12g weight(2)=%.12g\n", c->Weight(1), c->Weight(2));
  }
  {
    Handle(Geom2d_BSplineCurve) c  = make();
    bool                        ok = c->RemoveKnot(2, 0, 1.0);
    printf("RemoveKnot(2, 0, 1.0) returned %d\n", ok);
    show("  after", c);
  }
  return 0;
}
