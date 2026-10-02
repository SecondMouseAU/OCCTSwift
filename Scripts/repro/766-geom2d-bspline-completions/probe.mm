// #1979 kernel parity for BSplineCurve2DCompletionsV121Tests and BSplineCurve2dKnotSplitTests:
// the same Geom2d_BSplineCurve edits, with the same inputs, that the bridge functions those tests
// reach make.
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dConvert_BSplineCurveKnotSplitting.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <Standard_Failure.hxx>
#include <cstdio>
#include <typeinfo>

static Handle(Geom2d_BSplineCurve) make()
{
  NCollection_Array1<gp_Pnt2d> p(1, 4);
  p(1) = gp_Pnt2d(0, 0);
  p(2) = gp_Pnt2d(3, 5);
  p(3) = gp_Pnt2d(7, 5);
  p(4) = gp_Pnt2d(10, 0);
  TColStd_Array1OfReal    k(1, 2);
  TColStd_Array1OfInteger m(1, 2);
  k(1) = 0;
  k(2) = 1;
  m(1) = 4;
  m(2) = 4;
  return new Geom2d_BSplineCurve(p, k, m, 3);
}

static void show(const char* tag, const Handle(Geom2d_BSplineCurve)& c)
{
  printf("%s periodic=%d domain=[%.12g, %.12g] poles=%d knots=[", tag, c->IsPeriodic(),
         c->FirstParameter(), c->LastParameter(), c->NbPoles());
  for (int i = 1; i <= c->NbKnots(); i++)
    printf("%s%.12g", i > 1 ? ", " : "", c->Knot(i));
  printf("] mults=[");
  for (int i = 1; i <= c->NbKnots(); i++)
    printf("%s%d", i > 1 ? ", " : "", c->Multiplicity(i));
  printf("]\n");
  double f = c->FirstParameter(), l = c->LastParameter();
  for (double t : {0.0, 0.25, 0.5, 1.0})
  {
    double   u = f + t * (l - f);
    gp_Pnt2d v = c->Value(u);
    printf("  value(%.12g)=(%.12g, %.12g)\n", u, v.X(), v.Y());
  }
}

static Handle(Geom2d_BSplineCurve) interp(bool closed)
{
  Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, 4);
  if (closed)
  {
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(10, 0));
    pts->SetValue(3, gp_Pnt2d(10, 10));
    pts->SetValue(4, gp_Pnt2d(0, 10));
  }
  else
  {
    pts->SetValue(1, gp_Pnt2d(0, 0));
    pts->SetValue(2, gp_Pnt2d(1, 1));
    pts->SetValue(3, gp_Pnt2d(2, 0));
    pts->SetValue(4, gp_Pnt2d(3, 1));
  }
  Geom2dAPI_Interpolate in(pts, closed, 1e-6);
  in.Perform();
  return in.Curve();
}

int main()
{
  show("original", make());
  {
    Handle(Geom2d_BSplineCurve) c = interp(true);
    show("periodic interpolant before SetNotPeriodic", c);
    c->SetNotPeriodic();
    show("periodic interpolant after SetNotPeriodic", c);
  }
  {
    Handle(Geom2d_BSplineCurve) c = make();
    c->InsertKnot(0.5, 1, 1e-10);
    c->IncreaseMultiplicity(2, 2);
    show("InsertKnot(0.5) + IncreaseMultiplicity(2, 2)", c);
  }
  {
    Handle(Geom2d_BSplineCurve) c = make();
    c->Reverse();
    show("Reverse", c);
  }
  {
    Handle(Geom2d_BSplineCurve) c = make();
    TColStd_Array1OfReal        k(1, 2);
    k(1) = 0;
    k(2) = 2;
    c->SetKnots(k);
    show("SetKnots [0, 2]", c);
  }
  for (int endCond : {1, -1})
  {
    Handle(Geom2d_BSplineCurve) c = make();
    int                         err = 0;
    c->MovePointAndTangent(0.5, gp_Pnt2d(5, 10), gp_Vec2d(1, 0), 1e-6, 1, endCond, err);
    printf("MovePointAndTangent(start 1, end %d) errorStatus=%d\n", endCond, err);
    show("  after", c);
    gp_Pnt2d p;
    gp_Vec2d v;
    c->D1(0.5, p, v);
    printf("  D1(0.5) point=(%.12g, %.12g) tangent=(%.12g, %.12g)\n", p.X(), p.Y(), v.X(), v.Y());
  }
  {
    Handle(Geom2d_BSplineCurve) c = make();
    c->InsertKnot(0.3, 1, 1e-10);
    c->InsertKnot(0.7, 1, 1e-10);
    c->IncrementMultiplicity(2, 3, 1);
    show("InsertKnot(0.3), InsertKnot(0.7), IncrementMultiplicity(2, 3, 1)", c);
  }
  {
    Handle(Geom2d_BSplineCurve) c = make();
    try
    {
      c->SetOrigin(1);
      printf("SetOrigin(1) on non-periodic: no exception\n");
    }
    catch (const Standard_Failure& e)
    {
      printf("SetOrigin(1) on non-periodic: %s\n", typeid(e).name());
    }
  }
  {
    Handle(Geom2d_BSplineCurve) c = interp(false);
    show("interpolant (0,0) (1,1) (2,0) (3,1)", c);
    for (int cont : {0, 1, 2, 3})
    {
      Geom2dConvert_BSplineCurveKnotSplitting sp(c, cont);
      printf("  KnotSplitting(continuity %d) NbSplits=%d values=[", cont, sp.NbSplits());
      for (int i = 1; i <= sp.NbSplits(); i++)
        printf("%s%d", i > 1 ? ", " : "", sp.SplitValue(i));
      printf("]\n");
    }
  }
  return 0;
}
