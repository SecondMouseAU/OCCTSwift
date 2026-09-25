// #1979 kernel parity for Issue549Curve2DArcLengthRangeTests and Issue553GccZeroRadiusTests: the
// lengths GCPnts_AbscissaPoint gives on the multi-span interpolation, clamped and unclamped, and
// what the GccAna / IntAna2d / Extrema / GC_MakeCircle2d producers return for a zero radius next
// to a valid one (what the bridge guards refuse and what they let through).
#include <Extrema_ExtPElC2d.hxx>
#include <GC_MakeCircle2d.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <GccAna_Circ2d3Tan.hxx>
#include <GccAna_Circ2dBisec.hxx>
#include <GccAna_CircPnt2dBisec.hxx>
#include <GccEnt.hxx>
#include <GccEnt_QualifiedCirc.hxx>
#include <IntAna2d_Conic.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <IntAna2d_AnaIntersection.hxx>
#include <IntAna2d_IntPoint.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Lin2d.hxx>
#include <cmath>
#include <cstdio>

static gp_Circ2d circ(double x, double y, double r)
{
  return gp_Circ2d(gp_Ax2d(gp_Pnt2d(x, y), gp_Dir2d(1, 0)), r);
}

int main()
{
  Handle(TColgp_HArray1OfPnt2d) p = new TColgp_HArray1OfPnt2d(1, 5);
  gp_Pnt2d                      pts[] = {{0, 0}, {10, 40}, {20, 0}, {200, 5}, {210, 60}};
  for (int i = 0; i < 5; i++)
    p->SetValue(i + 1, pts[i]);
  Geom2dAPI_Interpolate in(p, false, 1e-6);
  in.Perform();
  Handle(Geom2d_BSplineCurve) c = in.Curve();
  double                      f = c->FirstParameter(), l = c->LastParameter(), s = l - f;
  Geom2dAdaptor_Curve         whole(c);
  printf("multi-span interpolation: domain=[%.12g, %.12g] length=%.12g\n", f, l, GCPnts_AbscissaPoint::Length(whole));
  printf("  [0.1, 0.6] of the span: %.12g\n", GCPnts_AbscissaPoint::Length(whole, f + 0.1 * s, f + 0.6 * s));
  printf("  full-curve adaptor over [-span, 2 span] (clamped): %.12g\n", GCPnts_AbscissaPoint::Length(whole, f - s, l + s));
  Geom2dAdaptor_Curve over(c, f - s, l + s), outside(c, l + 1, l + 2);
  printf("  pre-bounded adaptor over [-span, 2 span] (the pre-#549 extrapolation): %.12g\n",
         GCPnts_AbscissaPoint::Length(over));
  printf("  pre-bounded adaptor over [last + 1, last + 2]: %.12g\n", GCPnts_AbscissaPoint::Length(outside));

  GccAna_Circ2dBisec b0(circ(0, 0, 0), circ(10, 0, 2));
  GccAna_Circ2dBisec b1(circ(0, 0, 3), circ(10, 0, 2));
  printf("GccAna_Circ2dBisec r0/r2: n=%d; r3/r2: n=%d\n", b0.IsDone() ? b0.NbSolutions() : -1,
         b1.IsDone() ? b1.NbSolutions() : -1);
  GccAna_CircPnt2dBisec cp0(circ(0, 0, 0), gp_Pnt2d(6, 0));
  GccAna_CircPnt2dBisec cp2(circ(0, 0, 2), gp_Pnt2d(6, 0));
  printf("GccAna_CircPnt2dBisec r0: n=%d; r2: n=%d\n", cp0.IsDone() ? cp0.NbSolutions() : -1,
         cp2.IsDone() ? cp2.NbSolutions() : -1);
  GccAna_Circ2d3Tan t0(GccEnt::Unqualified(circ(0, 0, 0)), GccEnt::Unqualified(circ(10, 0, 2)),
                       GccEnt::Unqualified(circ(5, 8, 2)), 1e-6);
  GccAna_Circ2d3Tan t2(GccEnt::Unqualified(circ(0, 0, 2)), GccEnt::Unqualified(circ(10, 0, 2)),
                       GccEnt::Unqualified(circ(5, 8, 2)), 1e-6);
  printf("GccAna_Circ2d3Tan r0: n=%d; r2: n=%d\n", t0.IsDone() ? t0.NbSolutions() : -1,
         t2.IsDone() ? t2.NbSolutions() : -1);

  IntAna2d_AnaIntersection li(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), IntAna2d_Conic(circ(0, 0, 0)));
  printf("IntAna2d x-axis vs r0 circle: n=%d", li.NbPoints());
  for (int i = 1; i <= li.NbPoints(); i++)
  {
    printf(" (%.12g, %.12g)", li.Point(i).Value().X(), li.Point(i).Value().Y());
    try
    {
      printf(" param2=%g", li.Point(i).ParamOnSecond());
    }
    catch (Standard_Failure& e)
    {
      printf(" ParamOnSecond throws Standard_DomainError");
    }
  }
  printf("\n");
  IntAna2d_AnaIntersection cc(circ(0, 0, 3), circ(4, 0, 3));
  printf("IntAna2d r3 at 0 vs r3 at 4: n=%d\n", cc.NbPoints());

  Extrema_ExtPElC2d e0(gp_Pnt2d(0, 10), circ(0, 0, 0), 1e-9, 0, 2 * M_PI);
  Extrema_ExtPElC2d e3(gp_Pnt2d(0, 10), circ(0, 0, 3), 1e-9, 0, 2 * M_PI);
  printf("Extrema_ExtPElC2d (0,10) to r0: done=%d n=%d; to r3: n=%d\n", e0.IsDone(), e0.IsDone() ? e0.NbExt() : -1,
         e3.NbExt());

  GC_MakeCircle2d g0(gp_Pnt2d(0, 0), 0.0);
  printf("GC_MakeCircle2d r0: IsDone=%d\n", g0.IsDone());
  for (double d : {-5.0, -6.0, -2.0})
  {
    GC_MakeCircle2d g(circ(0, 0, 5), d);
    printf("GC_MakeCircle2d parallel to r5 at %g: IsDone=%d radius=%g\n", d, g.IsDone(),
           g.IsDone() ? g.Value()->Radius() : -1.0);
  }
  try
  {
    gp_Circ2d n = circ(0, 0, -1);
    printf("gp_Circ2d r-1 constructed\n");
  }
  catch (Standard_Failure& e)
  {
    printf("gp_Circ2d r-1: throws %s\n", e.what());
  }
  return 0;
}
