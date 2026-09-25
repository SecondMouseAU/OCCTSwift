// #1979 kernel parity for Curve2DBezierCompletionsTests and Curve2DBezierTests: the same
// Geom2d_BezierCurve edits and queries, with the same inputs, that the OCCTCurve2DBezier* bridge
// functions make.
#include <Geom2d_BezierCurve.hxx>
#include <cstdio>
#include <initializer_list>

static Handle(Geom2d_BezierCurve) make(std::initializer_list<gp_Pnt2d> pts)
{
  NCollection_Array1<gp_Pnt2d> a(1, (int)pts.size());
  int                          i = 1;
  for (auto& p : pts)
    a(i++) = p;
  return new Geom2d_BezierCurve(a);
}

static void show(const char* tag, const Handle(Geom2d_BezierCurve)& c)
{
  printf("%s degree=%d poles=[", tag, c->Degree());
  for (int i = 1; i <= c->NbPoles(); i++)
    printf("%s(%.12g, %.12g)", i > 1 ? ", " : "", c->Pole(i).X(), c->Pole(i).Y());
  printf("] start=(%.12g, %.12g) end=(%.12g, %.12g)\n", c->StartPoint().X(), c->StartPoint().Y(),
         c->EndPoint().X(), c->EndPoint().Y());
}

int main()
{
  {
    auto c = make({gp_Pnt2d(0, 0), gp_Pnt2d(1, 1)});
    c->InsertPoleAfter(1, gp_Pnt2d(0.5, 0.5));
    show("InsertPoleAfter(1, (0.5, 0.5))", c);
  }
  {
    auto c = make({gp_Pnt2d(0, 0), gp_Pnt2d(0.5, 0.5), gp_Pnt2d(1, 1)});
    c->RemovePole(2);
    show("RemovePole(2)", c);
  }
  {
    auto c = make({gp_Pnt2d(0, 0), gp_Pnt2d(0.5, 1), gp_Pnt2d(1, 0)});
    c->Segment(0.2, 0.8);
    show("Segment(0.2, 0.8)", c);
  }
  {
    auto c = make({gp_Pnt2d(0, 0), gp_Pnt2d(1, 1)});
    c->Increase(2);
    show("Increase(2)", c);
  }
  show("start/end", make({gp_Pnt2d(0, 0), gp_Pnt2d(5, 10)}));
  show("poles", make({gp_Pnt2d(0, 0), gp_Pnt2d(3, 4), gp_Pnt2d(6, 0)}));
  {
    auto c = make({gp_Pnt2d(0, 0), gp_Pnt2d(10, 20)});
    c->Reverse();
    show("Reverse", c);
  }
  {
    auto c = make({gp_Pnt2d(0, 0), gp_Pnt2d(5, 10), gp_Pnt2d(10, 0)});
    show("properties", c);
    printf("  rational=%d\n", c->IsRational());
    double r = 0;
    c->Resolution(0.1, r);
    printf("  Resolution(0.1)=%.12g\n", r);
    c->SetPole(2, gp_Pnt2d(3, 7));
    show("SetPole(2, (3, 7))", c);
  }
  return 0;
}
