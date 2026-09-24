// #1979 kernel parity for BatchCurve2DTests, BisectorBisecAnaTests and BisectorIntersectionTests:
// the same OCCT calls, with the same inputs, that the bridge functions those tests reach make.
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2dGridEval_Curve.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Bisector_BisecAna.hxx>
#include <Bisector_Bisec.hxx>
#include <Bisector_Inter.hxx>
#include <IntRes2d_Domain.hxx>
#include <IntRes2d_IntersectionPoint.hxx>
#include <Precision.hxx>
#include <cstdio>
#include <cmath>

static void inter(double ax, double ay, double bx, double by, double cx, double cy, double dx,
                  double dy)
{
  // Mirrors OCCTBisectorInterPointPoint.
  Bisector_Bisec                b1;
  Handle(Geom2d_CartesianPoint) pA = new Geom2d_CartesianPoint(gp_Pnt2d(ax, ay));
  Handle(Geom2d_CartesianPoint) pB = new Geom2d_CartesianPoint(gp_Pnt2d(bx, by));
  gp_Vec2d                      vAB(bx - ax, by - ay);
  gp_Vec2d                      perpAB(-vAB.Y(), vAB.X());
  gp_Vec2d                      v1 = perpAB.Normalized(), v2 = perpAB.Reversed().Normalized();
  b1.Perform(pA, pB, gp_Pnt2d((ax + bx) / 2, (ay + by) / 2), v1, v2, 1.0, 1e-6);
  Bisector_Bisec                b2;
  Handle(Geom2d_CartesianPoint) pC = new Geom2d_CartesianPoint(gp_Pnt2d(cx, cy));
  Handle(Geom2d_CartesianPoint) pD = new Geom2d_CartesianPoint(gp_Pnt2d(dx, dy));
  gp_Vec2d                      vCD(dx - cx, dy - cy);
  gp_Vec2d                      perpCD(-vCD.Y(), vCD.X());
  gp_Vec2d                      v3 = perpCD.Normalized(), v4 = perpCD.Reversed().Normalized();
  b2.Perform(pC, pD, gp_Pnt2d((cx + dx) / 2, (cy + dy) / 2), v3, v4, 1.0, 1e-6);
  const Handle(Geom2d_TrimmedCurve)& c1 = b1.Value();
  const Handle(Geom2d_TrimmedCurve)& c2 = b2.Value();
  double f1 = c1->FirstParameter(), l1 = c1->LastParameter();
  double f2 = c2->FirstParameter(), l2 = c2->LastParameter();
  IntRes2d_Domain d1(c1->Value(f1), f1, 1e-6, c1->Value(l1), l1, 1e-6);
  IntRes2d_Domain d2(c2->Value(f2), f2, 1e-6, c2->Value(l2), l2, 1e-6);
  Bisector_Inter  in;
  in.Perform(b1, d1, b2, d2, 1e-6, 1e-6, false);
  printf("BisectorInter (%g,%g)-(%g,%g) x (%g,%g)-(%g,%g): done=%d points=%d segments=%d\n", ax, ay,
         bx, by, cx, cy, dx, dy, in.IsDone(), in.NbPoints(), in.NbSegments());
  for (int i = 1; i <= in.NbPoints(); i++)
    printf("  point (%.12g, %.12g) paramOnFirst=%.12g paramOnSecond=%.12g\n",
           in.Point(i).Value().X(), in.Point(i).Value().Y(), in.Point(i).ParamOnFirst(),
           in.Point(i).ParamOnSecond());
}

static void curveInfo(const char* tag, const Handle(Geom2d_Curve)& c)
{
  printf("%s type=%s domain=[%.12g, %.12g]\n", tag, c->DynamicType()->Name(), c->FirstParameter(),
         c->LastParameter());
  for (double u : {0.0, 1.0, 5.0})
  {
    gp_Pnt2d p = c->Value(u);
    printf("  value(%g)=(%.12g, %.12g)\n", u, p.X(), p.Y());
  }
}

int main()
{
  // BatchCurve2DTests (OCCTCurve2DEvaluateGrid / OCCTCurve2DEvaluateGridD1)
  {
    Handle(Geom2d_Circle) c5 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Geom2dGridEval_Curve  ev(c5);
    NCollection_Array1<double> p(1, 3);
    p(1) = 0;
    p(2) = M_PI / 2;
    p(3) = M_PI;
    auto r = ev.EvaluateGrid(p);
    auto d = ev.EvaluateGridD1(p);
    for (int i = 1; i <= 3; i++)
      printf("Batch circle r=5 u=%.12g point=(%.12g, %.12g) d1=(%.12g, %.12g)\n", p(i), r(i).X(),
             r(i).Y(), d(i).D1.X(), d(i).D1.Y());
    Handle(Geom2d_TrimmedCurve) s = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 5)).Value();
    Geom2dGridEval_Curve        es(s);
    NCollection_Array1<double>  q(1, 1);
    q(1) = 0.5 * (s->FirstParameter() + s->LastParameter());
    auto m = es.EvaluateGrid(q);
    printf("Batch segment (0,0)-(10,5) domain=[%.12g, %.12g] mid=(%.12g, %.12g)\n",
           s->FirstParameter(), s->LastParameter(), m(1).X(), m(1).Y());
  }
  // BisectorBisecAnaTests.curveCurveBisector (OCCTBisectorBisecAnaCurveCurve)
  {
    Handle(Geom2d_Line)       l1 = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom2d_Line)       l2 = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(0, 1));
    Handle(Bisector_BisecAna) b  = new Bisector_BisecAna();
    b->Perform(l1, l2, gp_Pnt2d(1, 1), gp_Vec2d(1, 0), gp_Vec2d(0, 1), 1.0, GeomAbs_Arc, 1e-6);
    curveInfo("BisecAna line-line", b->Geom2dCurve());
    // The same lines with the reference point at their common point (0, 0).
    Handle(Bisector_BisecAna) b0 = new Bisector_BisecAna();
    b0->Perform(l1, l2, gp_Pnt2d(0, 0), gp_Vec2d(1, 0), gp_Vec2d(0, 1), 1.0, GeomAbs_Arc, 1e-6);
    curveInfo("BisecAna line-line ref (0,0)", b0->Geom2dCurve());
  }
  // BisectorBisecAnaTests.pointPointBisector (OCCTBisectorBisecAnaPointPoint)
  {
    Handle(Geom2d_Point)      p1 = new Geom2d_CartesianPoint(gp_Pnt2d(0, 0));
    Handle(Geom2d_Point)      p2 = new Geom2d_CartesianPoint(gp_Pnt2d(10, 0));
    Handle(Bisector_BisecAna) b  = new Bisector_BisecAna();
    b->Perform(p1, p2, gp_Pnt2d(5, 0), gp_Vec2d(1, 0), gp_Vec2d(-1, 0), 1.0, 1e-6);
    curveInfo("BisecAna point-point", b->Geom2dCurve());
  }
  // BisectorIntersectionTests (OCCTBisectorInterPointPoint)
  inter(0, 0, 10, 0, 0, 0, 0, 10);
  inter(0, 0, 4, 0, 0, 0, 0, 4);
  // The same pairs with the second pair's points swapped, which turns its half-line to +x.
  inter(0, 0, 10, 0, 0, 10, 0, 0);
  inter(0, 0, 4, 0, 0, 4, 0, 0);
  return 0;
}
