// Epic #766 (#1978), kernel parity for Issue495AnalysisOrderTests and
// Issue500Curve3DNearestParameterTests. #495: LocalAnalysis_CurveContinuity on the sharp-corner and
// smooth-junction fixtures (GeomAPI_PointsToBSpline, degree 3..8, C2, tol 1e-3) at each order, all
// five predicates printed, so the transcript shows which ones answer off an uncomputed member.
// #500: GeomAPI_ProjectPointOnCurve on the line trimmed to [3, 8] and the radius-5 circle.
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomLProp_CLProps.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <LocalAnalysis_CurveContinuity.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <cstdio>

static Handle(Geom_Curve) fit(gp_Pnt a, gp_Pnt b, gp_Pnt c)
{
  TColgp_Array1OfPnt p(1, 3);
  p(1) = a; p(2) = b; p(3) = c;
  return GeomAPI_PointsToBSpline(p, 3, 8, GeomAbs_C2, 1e-3).Curve();
}

static void analyse(const char* name, const Handle(Geom_Curve)& c1, const Handle(Geom_Curve)& c2)
{
  printf("%s:\n", name);
  for (GeomAbs_Shape s : {GeomAbs_C0, GeomAbs_G1, GeomAbs_C1, GeomAbs_G2, GeomAbs_C2})
  {
    GeomLProp_CLProps p1(c1, c1->LastParameter(), 2, 1e-9), p2(c2, c2->FirstParameter(), 2, 1e-9);
    LocalAnalysis_CurveContinuity a(c1, c1->LastParameter(), c2, c2->FirstParameter(), s);
    printf("  order %d: done %d status %d | IsC0 %d IsG1 %d IsC1 %d IsG2 %d IsC2 %d | C0Value %.3g\n", (int)s,
           a.IsDone(), (int)a.ContinuityStatus(), a.IsC0(), a.IsG1(), a.IsC1(), a.IsG2(), a.IsC2(), a.C0Value());
  }
}

int main()
{
  analyse("sharp corner", fit(gp_Pnt(0, 0, 0), gp_Pnt(2.5, 0.5, 0), gp_Pnt(5, 0, 0)),
          fit(gp_Pnt(5, 0, 0), gp_Pnt(5.5, 2.5, 0), gp_Pnt(5, 5, 0)));
  analyse("smooth junction", fit(gp_Pnt(0, 0, 0), gp_Pnt(2.5, 1, 0), gp_Pnt(5, 0, 0)),
          fit(gp_Pnt(5, 0, 0), gp_Pnt(7.5, -1, 0), gp_Pnt(10, 0, 0)));

  Handle(Geom_Curve) seg = new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 3, 8);
  for (gp_Pnt p : {gp_Pnt(5, 2, 0), gp_Pnt(3, 4, 0), gp_Pnt(8, -1, 0), gp_Pnt(100, 0, 0), gp_Pnt(0, 0, 0)})
  {
    GeomAPI_ProjectPointOnCurve pr(p, seg);
    printf("segment [3,8] point (%g,%g,%g): NbPoints %d", p.X(), p.Y(), p.Z(), pr.NbPoints());
    if (pr.NbPoints() > 0)
      printf(" LowerDistanceParameter %.17g", pr.LowerDistanceParameter());
    printf("\n");
  }
  Handle(Geom_Circle)         circ = new Geom_Circle(gp_Ax2(), 5);
  GeomAPI_ProjectPointOnCurve pc(gp_Pnt(0, 0, 0), circ);
  printf("circle r 5 centre: NbPoints %d\n", pc.NbPoints());
  return 0;
}
