// Epic #766 (#1978), kernel parity for LawCompositeTests and LawFunctionTests: Law_Constant,
// Law_Linear, Law_S, Law_Interpol, Law_BSpline and Law_Composite built the way the tests build them,
// evaluated at the tests' parameters.
#include <Law_BSpFunc.hxx>
#include <Law_BSpline.hxx>
#include <Law_BSplineKnotSplitting.hxx>
#include <Law_Composite.hxx>
#include <Law_Constant.hxx>
#include <Law_Interpol.hxx>
#include <Law_Laws.hxx>
#include <Law_Linear.hxx>
#include <Law_S.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <cstdio>

int main()
{
  Handle(Law_Constant) c = new Law_Constant();
  c->Set(3.5, 0, 10);
  printf("constant 3.5 on [0,10]: %.12g %.12g %.12g\n", c->Value(0), c->Value(5), c->Value(10));
  Handle(Law_Linear) l = new Law_Linear();
  l->Set(0, 1, 10, 3);
  printf("linear 1->3 on [0,10]: %.12g %.12g %.12g\n", l->Value(0), l->Value(5), l->Value(10));
  Handle(Law_S) s = new Law_S();
  s->Set(0, 0, 1, 1);
  printf("S 0->1 on [0,1]: %.12g %.12g %.12g\n", s->Value(0), s->Value(0.5), s->Value(1));
  TColgp_Array1OfPnt2d pts(1, 5);
  double               ps[][2] = {{0, 0}, {0.25, 1}, {0.5, 0}, {0.75, -1}, {1, 0}};
  for (int i = 0; i < 5; i++)
    pts(i + 1) = gp_Pnt2d(ps[i][0], ps[i][1]);
  Handle(Law_Interpol) ip = new Law_Interpol();
  ip->Set(pts, false);
  printf("interpol: %.12g %.12g %.12g %.12g\n", ip->Value(0), ip->Value(0.25), ip->Value(0.5), ip->Value(1));
  Handle(Law_Linear) a = new Law_Linear();
  a->Set(0, 1, 0.5, 3);
  Handle(Law_Linear) b = new Law_Linear();
  b->Set(0.5, 3, 1, 1);
  Handle(Law_Composite) comp = new Law_Composite(0, 1, 1e-9);
  comp->ChangeLaws().Append(a);
  comp->ChangeLaws().Append(b);
  printf("composite: %.12g %.12g %.12g %.12g\n", comp->Value(0), comp->Value(0.25), comp->Value(0.5), comp->Value(1));
  TColStd_Array1OfReal    p(1, 6), k(1, 3);
  TColStd_Array1OfInteger m(1, 3);
  double                  pv[] = {1, 3, 2, 5, 4, 6};
  for (int i = 0; i < 6; i++)
    p(i + 1) = pv[i];
  k(1) = 0; k(2) = 0.5; k(3) = 1;
  m(1) = 4; m(2) = 2; m(3) = 4;
  printf("bspline mult-2 knot C2 splits %d\n", Law_BSplineKnotSplitting(new Law_BSpline(p, k, m, 3), 2).NbSplits());
  return 0;
}
