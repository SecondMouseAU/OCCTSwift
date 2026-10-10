// Epic #766 (#1978), kernel parity for BezierCurve3DCompletionTests.swift and
// BezierCurveManipulationTests.swift. Same Geom_BezierCurve inputs as the Swift tests, and the
// same Geom_BezierCurve methods the OCCTCurve3DBezier* bridge functions call.
#include <GeomAbs_Shape.hxx>
#include <Geom_BezierCurve.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <cstdio>
#include <vector>

static Handle(Geom_BezierCurve) make(const std::vector<gp_Pnt>& p, const std::vector<double>& w = {})
{
  TColgp_Array1OfPnt a(1, (int)p.size());
  for (size_t i = 0; i < p.size(); i++)
    a((int)i + 1) = p[i];
  if (w.empty())
    return new Geom_BezierCurve(a);
  TColStd_Array1OfReal b(1, (int)w.size());
  for (size_t i = 0; i < w.size(); i++)
    b((int)i + 1) = w[i];
  return new Geom_BezierCurve(a, b);
}

static void poles(const char* tag, const Handle(Geom_BezierCurve)& c)
{
  printf("  %s: degree=%d nbPoles=%d rational=%d poles:", tag, c->Degree(), c->NbPoles(),
         c->IsRational());
  for (int i = 1; i <= c->NbPoles(); i++)
    printf(" (%.17g, %.17g, %.17g)", c->Pole(i).X(), c->Pole(i).Y(), c->Pole(i).Z());
  printf("\n");
  const TColStd_Array1OfReal* w = c->Weights();
  if (w)
  {
    printf("    weights:");
    for (int i = w->Lower(); i <= w->Upper(); i++)
      printf(" %.17g", (*w)(i));
    printf("\n");
  }
  else
    printf("    weights: nullptr\n");
}

int main()
{
  std::vector<gp_Pnt> p3 = {gp_Pnt(0, 0, 0), gp_Pnt(1, 2, 0), gp_Pnt(2, 0, 0)};
  auto                c  = make(p3);
  gp_Pnt              s = c->StartPoint(), e = c->EndPoint();
  printf("Completions, poles (0,0,0) (1,2,0) (2,0,0):\n");
  printf("  StartPoint=(%.17g, %.17g, %.17g) EndPoint=(%.17g, %.17g, %.17g)\n", s.X(), s.Y(), s.Z(),
         e.X(), e.Y(), e.Z());
  poles("non-rational", c);
  printf("  IsClosed=%d IsPeriodic=%d Continuity=%d IsCN(0)=%d IsCN(1)=%d IsCN(10)=%d\n",
         c->IsClosed(), c->IsPeriodic(), (int)c->Continuity(), c->IsCN(0), c->IsCN(1), c->IsCN(10));
  poles("rational weights 1,2,1", make(p3, {1, 2, 1}));
  auto cl = make({gp_Pnt(0, 0, 0), gp_Pnt(1, 2, 0), gp_Pnt(2, 0, 0), gp_Pnt(0, 0, 0)});
  printf("  closed poles: IsClosed=%d\n", cl->IsClosed());

  std::vector<gp_Pnt> p4 = {gp_Pnt(0, 0, 0), gp_Pnt(3, 5, 0), gp_Pnt(7, 5, 0), gp_Pnt(10, 0, 0)};
  printf("Manipulation, poles (0,0,0) (3,5,0) (7,5,0) (10,0,0):\n");
  poles("as built", make(p4));
  {
    auto b = make(p4);
    b->SetPole(2, gp_Pnt(3, 8, 0));
    poles("SetPole(2, (3,8,0))", b);
  }
  {
    auto   b  = make(p4);
    gp_Pnt a0 = b->Value(0.25), a1 = b->Value(0.75), am = b->Value(0.5);
    b->Segment(0.25, 0.75);
    poles("Segment(0.25, 0.75)", b);
    gp_Pnt b0 = b->Value(0), b1 = b->Value(1), bm = b->Value(0.5);
    printf("    original C(0.25)=(%.17g, %.17g) C(0.5)=(%.17g, %.17g) C(0.75)=(%.17g, %.17g)\n",
           a0.X(), a0.Y(), am.X(), am.Y(), a1.X(), a1.Y());
    printf("    segment  S(0)=(%.17g, %.17g) S(0.5)=(%.17g, %.17g) S(1)=(%.17g, %.17g)\n", b0.X(),
           b0.Y(), bm.X(), bm.Y(), b1.X(), b1.Y());
  }
  {
    auto   b  = make(p4);
    gp_Pnt a0 = b->Value(0.3);
    b->Increase(5);
    gp_Pnt b0 = b->Value(0.3);
    poles("Increase(5)", b);
    printf("    C(0.3) before=(%.17g, %.17g) after=(%.17g, %.17g)\n", a0.X(), a0.Y(), b0.X(),
           b0.Y());
  }
  {
    auto b = make(p4);
    b->InsertPoleAfter(2, gp_Pnt(5, 6, 0));
    poles("InsertPoleAfter(2, (5,6,0))", b);
  }
  {
    auto b = make({gp_Pnt(0, 0, 0), gp_Pnt(3, 5, 0), gp_Pnt(5, 6, 0), gp_Pnt(7, 5, 0),
                   gp_Pnt(10, 0, 0)});
    b->RemovePole(3);
    poles("5 poles, RemovePole(3)", b);
  }
  {
    auto b = make(p4);
    b->SetWeight(2, 2.0);
    poles("SetWeight(2, 2.0)", b);
  }
  return 0;
}
