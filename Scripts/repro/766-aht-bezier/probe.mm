// Epic #766, AHTBezierCurve3DTests.swift and AHTBezierSurfaceTests.swift: kernel parity for the
// three tests. Same inputs as the Swift tests, straight to GeomEval_AHTBezierCurve (plain and
// weighted constructors, as OCCTGeomEvalAHTBezierCurveCreate / ...CreateRational build it) and
// GeomEval_AHTBezierSurface (row-major poles, pts(i + 1, j + 1) = poles[i * vCount + j], as
// OCCTGeomEvalAHTBezierSurfaceCreate reads them), then FirstParameter/LastParameter and D0.
#include <GeomEval_AHTBezierCurve.hxx>
#include <GeomEval_AHTBezierSurface.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  NCollection_Array1<gp_Pnt> poles(1, 5);
  poles(1) = gp_Pnt(0, 0, 0);
  poles(2) = gp_Pnt(1, 0, 0);
  poles(3) = gp_Pnt(2, 1, 0);
  poles(4) = gp_Pnt(3, 0, 0);
  poles(5) = gp_Pnt(4, 0, 0);
  NCollection_Array1<double> w(1, 5);
  w(1) = 1;
  w(2) = 1;
  w(3) = 2;
  w(4) = 1;
  w(5) = 1;

  Handle(GeomEval_AHTBezierCurve) c = new GeomEval_AHTBezierCurve(poles, 0, 1.0, 1.0);
  gp_Pnt                          p = c->Value(0.5);
  printf("createAndEval: domain=[%.17g, %.17g] point(0.5)=(%.17g, %.17g, %.17g)\n",
         c->FirstParameter(), c->LastParameter(), p.X(), p.Y(), p.Z());

  Handle(GeomEval_AHTBezierCurve) r = new GeomEval_AHTBezierCurve(poles, w, 0, 1.0, 1.0);
  double                          mid = (r->FirstParameter() + r->LastParameter()) / 2;
  gp_Pnt                          rp  = r->Value(mid);
  gp_Pnt                          cp  = c->Value(mid);
  printf("rationalAHTBezier: domain=[%.17g, %.17g] point(mid=%.17g)=(%.17g, %.17g, %.17g)"
         " unweighted point(mid)=(%.17g, %.17g, %.17g)\n",
         r->FirstParameter(), r->LastParameter(), mid, rp.X(), rp.Y(), rp.Z(), cp.X(), cp.Y(), cp.Z());

  NCollection_Array2<gp_Pnt> sp(1, 5, 1, 5);
  for (int i = 0; i < 5; i++)
    for (int j = 0; j < 5; j++)
      sp(i + 1, j + 1) = gp_Pnt(i, j, 0.3 * std::sin(double(i)) * std::cos(double(j)));
  Handle(GeomEval_AHTBezierSurface) s = new GeomEval_AHTBezierSurface(sp, 0, 0, 1.0, 1.0, 1.0, 1.0);
  double                            u1, u2, v1, v2;
  s->Bounds(u1, u2, v1, v2);
  double u = u1 + 0.3 * (u2 - u1), v = v1 + 0.7 * (v2 - v1);
  gp_Pnt q = s->Value(u, v);
  printf("createSurface: bounds=[%.17g, %.17g]x[%.17g, %.17g] point(%.17g, %.17g)=(%.17g, %.17g, %.17g)\n",
         u1, u2, v1, v2, u, v, q.X(), q.Y(), q.Z());
  return 0;
}
