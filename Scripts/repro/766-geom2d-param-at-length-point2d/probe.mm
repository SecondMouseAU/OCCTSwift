// #1979 kernel parity for Curve2DParameterAtLengthTests and Curve2DPoint2DIntegrationTests: the
// GCPnts_AbscissaPoint lengths and parameters, GCPnts_UniformAbscissa samples and
// Geom2dAPI_ProjectPointOnCurve projection the bridge functions those tests reach compute.
#include <Geom2d_Circle.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <cstdio>

int main()
{
  Handle(Geom2d_Circle)       c10 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10);
  Handle(Geom2d_TrimmedCurve) arc = new Geom2d_TrimmedCurve(c10, 0, M_PI / 2);
  Geom2dAdaptor_Curve         aa(arc);
  double                      L = GCPnts_AbscissaPoint::Length(aa);
  GCPnts_AbscissaPoint        half(aa, L / 2, aa.FirstParameter());
  gp_Pnt2d                    hp = arc->Value(half.Parameter());
  printf("quarter arc r10: length=%.12g param(L/2)=%.12g point=(%.12g, %.12g)\n", L, half.Parameter(), hp.X(),
         hp.Y());
  Handle(Geom2d_TrimmedCurve) s10 = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)).Value();
  Geom2dAdaptor_Curve         a10(s10);
  for (double d : {0.0, 10.0, 1000.0})
  {
    GCPnts_AbscissaPoint p(a10, d, a10.FirstParameter());
    printf("segment (0,0)-(10,0) param at %g: done=%d param=%.12g\n", d, p.IsDone(), p.IsDone() ? p.Parameter() : -1);
  }
  Handle(Geom2d_TrimmedCurve) s20 = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(20, 0)).Value();
  Geom2dAdaptor_Curve         a20(s20);
  GCPnts_AbscissaPoint        p5(a20, 5, 10);
  GCPnts_AbscissaPoint        p7(a20, 7, 0);
  printf("segment (0,0)-(20,0): 5 from u=10 -> %.12g; 7 from u=0 -> %.12g; length [0, that]=%.12g\n",
         p5.Parameter(), p7.Parameter(), GCPnts_AbscissaPoint::Length(a20, 0, p7.Parameter()));
  printf("segment (0,0)-(10,0) point at mid u=%.12g: (%.12g, %.12g)\n",
         0.5 * (s10->FirstParameter() + s10->LastParameter()), s10->Value(5).X(), s10->Value(5).Y());
  Handle(Geom2d_TrimmedCurve) s55 = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(5, 5)).Value();
  Geom2dAdaptor_Curve         a55(s55);
  GCPnts_UniformAbscissa      ua(a55, 2);
  printf("uniform 2 points on (0,0)-(5,5): n=%d first=(%.12g, %.12g) last=(%.12g, %.12g)\n", ua.NbPoints(),
         s55->Value(ua.Parameter(1)).X(), s55->Value(ua.Parameter(1)).Y(), s55->Value(ua.Parameter(2)).X(),
         s55->Value(ua.Parameter(2)).Y());
  Handle(Geom2d_Circle)         c5 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
  Geom2dAPI_ProjectPointOnCurve pr(gp_Pnt2d(10, 0), c5);
  printf("project (10,0) on circle r5: nearest=(%.12g, %.12g) distance=%.12g param=%.12g\n", pr.NearestPoint().X(),
         pr.NearestPoint().Y(), pr.LowerDistance(), pr.LowerDistanceParameter());
  return 0;
}
