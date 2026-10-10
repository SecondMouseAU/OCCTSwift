// Epic #766 (#1978), kernel parity for Curve3DConicFactoryParityTests.swift,
// Curve3DContinuityTests.swift and Curve3DContinuityQueriesTests.swift. Same inputs as the tests,
// straight to the OCCT calls the bridge makes: gce_Make{Circ,Elips,Hypr,Parab} vs direct Geom_*
// construction, Geom_Curve::Continuity / IsCN / ReversedParameter / ParametricTransformation,
// Geom_BezierCurve::Resolution and the two MaxDegree statics.
#include <GeomAPI_Interpolate.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Line.hxx>
#include <Geom_Parabola.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <gce_MakeCirc.hxx>
#include <gce_MakeElips.hxx>
#include <gce_MakeHypr.hxx>
#include <gce_MakeParab.hxx>
#include <cstdio>

int main()
{
  gp_Pnt c(1, 2, 3);
  gp_Dir n(0, 0, 1);
  gp_Ax2 ax(c, n);
  // gce_Make* reject only strictly negative sizes, which is why the bridge checks first (#399).
  for (double r : {0.0, -1.0})
    printf("gce_MakeCirc radius %g: done=%d\n", r, gce_MakeCirc(c, n, r).IsDone());
  printf("gce_MakeElips (10,0)=%d (0,0)=%d (5,10)=%d (10,-1)=%d\n",
         gce_MakeElips(ax, 10, 0).IsDone(), gce_MakeElips(ax, 0, 0).IsDone(),
         gce_MakeElips(ax, 5, 10).IsDone(), gce_MakeElips(ax, 10, -1).IsDone());
  printf("gce_MakeHypr (0,3)=%d (8,0)=%d (0,0)=%d (-8,3)=%d\n", gce_MakeHypr(ax, 0, 3).IsDone(),
         gce_MakeHypr(ax, 8, 0).IsDone(), gce_MakeHypr(ax, 0, 0).IsDone(),
         gce_MakeHypr(ax, -8, 3).IsDone());
  printf("gce_MakeParab focal 0=%d -1=%d\n", gce_MakeParab(ax, 0).IsDone(),
         gce_MakeParab(ax, -1).IsDone());
  Handle(Geom_Circle) c1 = new Geom_Circle(ax, 7), c2 = new Geom_Circle(gce_MakeCirc(c, n, 7).Value());
  Handle(Geom_Ellipse) e1 = new Geom_Ellipse(ax, 10, 5), e2 = new Geom_Ellipse(gce_MakeElips(ax, 10, 5).Value());
  Handle(Geom_Hyperbola) h1 = new Geom_Hyperbola(ax, 8, 3), h2 = new Geom_Hyperbola(gce_MakeHypr(ax, 8, 3).Value());
  Handle(Geom_Parabola) p1 = new Geom_Parabola(ax, 4), p2 = new Geom_Parabola(gce_MakeParab(ax, 4).Value());
  double dc = 0, de = 0, dh = 0, dp = 0;
  for (double t = 0; t < 2 * M_PI; t += M_PI / 4)
  {
    dc = std::max(dc, c1->Value(t).Distance(c2->Value(t)));
    de = std::max(de, e1->Value(t).Distance(e2->Value(t)));
  }
  for (double t = -1; t <= 1; t += 0.25)
    dh = std::max(dh, h1->Value(t).Distance(h2->Value(t)));
  for (double t = -2; t <= 2; t += 0.5)
    dp = std::max(dp, p1->Value(t).Distance(p2->Value(t)));
  printf("direct vs gce max distance: circle %g ellipse %g hyperbola %g parabola %g\n", dc, de, dh, dp);
  gp_Pnt e0 = e1->Value(0);
  printf("ellipse(0) = (%g, %g, %g)\n", e0.X(), e0.Y(), e0.Z());

  Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  printf("line: Continuity=%d IsCN(0)=%d IsCN(1)=%d IsCN(2)=%d ReversedParameter(2)=%g "
         "ParametricTransformation(identity)=%g\n",
         (int)line->Continuity(), line->IsCN(0), line->IsCN(1), line->IsCN(2),
         line->ReversedParameter(2.0), line->ParametricTransformation(gp_Trsf()));
  Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, 4);
  pts->SetValue(1, gp_Pnt(0, 0, 0));
  pts->SetValue(2, gp_Pnt(1, 1, 0));
  pts->SetValue(3, gp_Pnt(2, 0, 0));
  pts->SetValue(4, gp_Pnt(3, 1, 0));
  GeomAPI_Interpolate ip(pts, false, 1e-6);
  ip.Perform();
  printf("interpolated 4-point BSpline: Continuity=%d (GeomAbs_C2 = %d)\n", (int)ip.Curve()->Continuity(),
         (int)GeomAbs_C2);
  TColgp_Array1OfPnt bp(1, 3);
  bp(1) = gp_Pnt(0, 0, 0);
  bp(2) = gp_Pnt(1, 1, 0);
  bp(3) = gp_Pnt(2, 0, 0);
  Handle(Geom_BezierCurve) bz = new Geom_BezierCurve(bp);
  double                   res;
  bz->Resolution(0.01, res);
  printf("Bezier Resolution(0.01)=%.17g\n", res);
  printf("Geom_BezierCurve::MaxDegree()=%d Geom_BSplineCurve::MaxDegree()=%d\n",
         Geom_BezierCurve::MaxDegree(), Geom_BSplineCurve::MaxDegree());
  return 0;
}
