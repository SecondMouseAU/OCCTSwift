// #1979 kernel parity for Point2DCreationTests, Point2DDistanceTests, Point2DTransformTests,
// Polygon2DTests and Matrix2DTests: Geom2d_CartesianPoint, gp_Trsf2d, Poly_Polygon2D and gp_Mat2d
// on the tests' own inputs, as the OCCTPoint2D*, OCCTPolyPolygon2D* and OCCTMat2d* bridges call them.
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <Poly_Polygon2D.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <gp_Mat2d.hxx>
#include <gp_Trsf2d.hxx>
#include <cmath>
#include <cstdio>

static void mat(const char* tag, const gp_Mat2d& m)
{
  printf("%s: [%.15g, %.15g, %.15g, %.15g] det=%.15g\n", tag, m.Value(1, 1), m.Value(1, 2), m.Value(2, 1), m.Value(2, 2),
         m.Determinant());
}

static void pt(const char* tag, const gp_Trsf2d& t, double x, double y)
{
  Handle(Geom2d_CartesianPoint) p = new Geom2d_CartesianPoint(x, y);
  p->Transform(t);
  printf("%s (%g, %g) -> (%.15g, %.15g)\n", tag, x, y, p->X(), p->Y());
}

int main()
{
  gp_Mat2d m;
  m.SetIdentity();
  mat("identity", m);
  m.SetRotation(M_PI / 2);
  mat("rotation(pi/2)", m);
  m.SetScale(3);
  mat("scale(3)", m);
  gp_Mat2d a, b;
  a.SetRotation(M_PI / 4);
  b.SetRotation(-M_PI / 4);
  mat("rot(pi/4) * rot(-pi/4)", a.Multiplied(b));
  gp_Mat2d t;
  t.SetIdentity();
  t.SetValue(1, 2, 5);
  mat("transpose of [1,5,0,1]", t.Transposed());
  gp_Mat2d r;
  r.SetRotation(M_PI / 3);
  mat("inverse of rot(pi/3)", r.Inverted());
  mat("rot(pi/3) * inverse", r.Multiplied(r.Inverted()));

  Handle(Geom2d_CartesianPoint) p0 = new Geom2d_CartesianPoint(0, 0), p1 = new Geom2d_CartesianPoint(3, 4);
  printf("distance (0,0)-(3,4) = %.15g, square = %.15g\n", p0->Distance(p1), p0->SquareDistance(p1));
  Handle(Geom2d_Circle)        c = new Geom2d_Circle(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 3));
  Geom2dAPI_ProjectPointOnCurve pr(gp_Pnt2d(0, 5), c);
  printf("(0,5) to r3 circle: %.15g\n", pr.LowerDistance());

  gp_Trsf2d tr;
  tr.SetTranslation(gp_Vec2d(3, 4));
  pt("translate (3,4)", tr, 1, 2);
  tr.SetRotation(gp_Pnt2d(0, 0), M_PI / 2);
  pt("rotate pi/2 about origin", tr, 1, 0);
  tr.SetScale(gp_Pnt2d(0, 0), 2);
  pt("scale 2 about origin", tr, 2, 3);
  tr.SetMirror(gp_Pnt2d(0, 0));
  pt("mirror through origin", tr, 1, 0);
  tr.SetMirror(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)));
  pt("mirror across x-axis", tr, 1, 1);
  tr.SetTranslation(gp_Vec2d(5, 3));
  pt("translate (5,3)", tr, 1, 0);

  TColgp_Array1OfPnt2d n(1, 4);
  n.SetValue(1, gp_Pnt2d(0, 0));
  n.SetValue(2, gp_Pnt2d(10, 0));
  n.SetValue(3, gp_Pnt2d(10, 10));
  n.SetValue(4, gp_Pnt2d(0, 10));
  Handle(Poly_Polygon2D) poly = new Poly_Polygon2D(n);
  poly->Deflection(0.5);
  printf("Poly_Polygon2D square: NbNodes=%d node(2)=(%g, %g) deflection=%g\n", poly->NbNodes(), poly->Nodes()(2).X(),
         poly->Nodes()(2).Y(), poly->Deflection());
  return 0;
}
