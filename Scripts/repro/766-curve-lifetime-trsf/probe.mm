// Epic #766 (#1978), kernel parity for Issue965Curve3DPropertyLifetimeTests and
// Issue995BuildTrsf3DTests. #995: the six gp_Trsf kinds applied to the probe point (3, 4, 5), which
// is what each test's `expected` computes by hand. #965: Geom_Circle radius read and SetRadius(8);
// the lifetime half is Swift-side and has no kernel counterpart.
#include <Geom_Circle.hxx>
#include <cmath>
#include <cstdio>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Trsf.hxx>

static void show(const char* name, const gp_Trsf& t)
{
  gp_Pnt p(3, 4, 5);
  p.Transform(t);
  printf("%s: (%.12g, %.12g, %.12g)\n", name, p.X(), p.Y(), p.Z());
}

int main()
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(10, 20, 30));
  show("0 translation (10,20,30)", t);
  t.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 2);
  show("1 rotation z pi/2", t);
  t.SetScale(gp_Pnt(1, 1, 1), 3);
  show("2 scale (1,1,1) x3", t);
  t.SetMirror(gp_Pnt(1, 2, 3));
  show("3 mirror point (1,2,3)", t);
  t.SetMirror(gp_Ax1(gp_Pnt(1, 2, 0), gp_Dir(0, 0, 1)));
  show("4 mirror axis (1,2,0) z", t);
  t.SetMirror(gp_Ax2(gp_Pnt(0, 0, 1), gp_Dir(0, 0, 1)));
  show("5 mirror plane z=1", t);
  Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(), 5);
  printf("circle radius %.12g", c->Radius());
  c->SetRadius(8);
  printf(", after SetRadius(8) %.12g\n", c->Radius());
  return 0;
}
