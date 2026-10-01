// #1979 kernel parity for Curve2DAnalysisTests: the same OCCT calls, with the same inputs, that
// OCCTCurve2DIntersect, OCCTCurve2DProjectPoint, OCCTCurve2DMinDistance, OCCTCurve2DToBSpline,
// OCCTCurve2DBSplineToBeziers, OCCTCurve2DJoinToBSpline and OCCTCurve2DProjectPointAll make.
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2dAPI_InterCurveCurve.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <Geom2dAPI_ExtremaCurveCurve.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2dConvert_BSplineCurveToBezierCurve.hxx>
#include <Geom2dConvert_CompCurveToBSplineCurve.hxx>
#include <IntRes2d_IntersectionPoint.hxx>
#include <cstdio>

static Handle(Geom2d_TrimmedCurve) seg(double x1, double y1, double x2, double y2)
{
  return GCE2d_MakeSegment(gp_Pnt2d(x1, y1), gp_Pnt2d(x2, y2)).Value();
}

int main()
{
  Handle(Geom2d_Circle) c5 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
  {
    Geom2dAPI_InterCurveCurve in(seg(-10, 0, 10, 0), c5, 1e-6);
    printf("Intersect segment(-10,0)-(10,0) x circle r5: n=%d\n", in.NbPoints());
    for (int i = 1; i <= in.NbPoints(); i++)
      printf("  (%.12g, %.12g) u1=%.12g u2=%.12g\n", in.Point(i).X(), in.Point(i).Y(),
             in.Intersector().Point(i).ParamOnFirst(), in.Intersector().Point(i).ParamOnSecond());
    Geom2dAPI_InterCurveCurve in2(seg(0, 0, 10, 0), seg(0, 5, 10, 5), 1e-6);
    printf("Intersect parallel segments: n=%d segments=%d\n", in2.NbPoints(), in2.NbSegments());
  }
  {
    Geom2dAPI_ProjectPointOnCurve p(gp_Pnt2d(5, 3), seg(0, 0, 10, 0));
    printf("Project (5,3) on segment: n=%d nearest=(%.12g, %.12g) dist=%.12g\n", p.NbPoints(),
           p.NearestPoint().X(), p.NearestPoint().Y(), p.LowerDistance());
    Geom2dAPI_ProjectPointOnCurve q(gp_Pnt2d(10, 0), c5);
    printf("Project (10,0) on circle r5: n=%d nearest=(%.12g, %.12g) dist=%.12g\n", q.NbPoints(),
           q.NearestPoint().X(), q.NearestPoint().Y(), q.LowerDistance());
  }
  {
    Handle(Geom2d_TrimmedCurve) s = seg(10, -1, 10, 1);
    Geom2dAPI_ExtremaCurveCurve e(c5, s, c5->FirstParameter(), c5->LastParameter(),
                                  s->FirstParameter(), s->LastParameter());
    gp_Pnt2d a, b;
    e.NearestPoints(a, b);
    printf("MinDistance circle r5 to segment x=10: n=%d dist=%.12g p1=(%.12g, %.12g) p2=(%.12g, "
           "%.12g)\n",
           e.NbExtrema(), e.LowerDistance(), a.X(), a.Y(), b.X(), b.Y());
  }
  {
    Handle(Geom2d_BSplineCurve) b = Geom2dConvert::CurveToBSplineCurve(c5, Convert_TgtThetaOver2);
    printf("Circle r5 to BSpline (TgtThetaOver2): degree=%d poles=%d knots=%d rational=%d\n",
           b->Degree(), b->NbPoles(), b->NbKnots(), b->IsRational());
    Geom2dConvert_BSplineCurveToBezierCurve cv(b);
    printf("  to Beziers: arcs=%d\n", cv.NbArcs());
  }
  {
    Geom2dConvert_CompCurveToBSplineCurve j;
    j.Add(Geom2dConvert::CurveToBSplineCurve(seg(0, 0, 5, 5)), 1e-6);
    j.Add(Geom2dConvert::CurveToBSplineCurve(seg(5, 5, 10, 0)), 1e-6);
    Handle(Geom2d_BSplineCurve) r = j.BSplineCurve();
    gp_Pnt2d s = r->StartPoint(), e = r->EndPoint();
    gp_Pnt2d m = r->Value(0.5 * (r->FirstParameter() + r->LastParameter()));
    printf("Join (0,0)-(5,5)-(10,0): domain=[%.12g, %.12g] start=(%.12g, %.12g) end=(%.12g, "
           "%.12g) mid=(%.12g, %.12g) poles=%d\n",
           r->FirstParameter(), r->LastParameter(), s.X(), s.Y(), e.X(), e.Y(), m.X(), m.Y(),
           r->NbPoles());
  }
  {
    Handle(Geom2d_Ellipse) el =
      new Geom2d_Ellipse(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10, 5);
    Geom2dAPI_ProjectPointOnCurve p(gp_Pnt2d(0, 0), el);
    printf("All projections of (0,0) on ellipse 10x5: n=%d\n", p.NbPoints());
    for (int i = 1; i <= p.NbPoints(); i++)
      printf("  (%.12g, %.12g) u=%.12g dist=%.12g\n", p.Point(i).X(), p.Point(i).Y(),
             p.Parameter(i), p.Distance(i));
  }
  return 0;
}
