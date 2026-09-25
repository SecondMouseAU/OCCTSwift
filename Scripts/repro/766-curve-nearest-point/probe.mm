// Epic #766 (#1978), kernel parity for Issue539NearestPointOnCurveTests.swift: the two raw OCCT
// calls the bridge takes candidates from (ShapeAnalysis_Curve::Project and
// GeomAPI_ProjectPointOnCurve's lowest in-range extremum), next to a dense brute-force minimum over
// the curve's own domain, which is the answer the tests pin.
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Line.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <cstdio>

static void probe(const char* name, const Handle(Geom_Curve)& c, gp_Pnt p)
{
  double f = c->FirstParameter(), l = c->LastParameter();
  gp_Pnt proj;
  double par = 0;
  double sa  = ShapeAnalysis_Curve().Project(c, p, 1e-6, proj, par);
  printf("%s p=(%g,%g,%g): ShapeAnalysis dist %.9g param %.9g", name, p.X(), p.Y(), p.Z(), sa, par);
  GeomAPI_ProjectPointOnCurve g(p, c, f, l);
  if (g.NbPoints() > 0)
    printf(" | GeomAPI lower %.9g at %.9g", g.LowerDistance(), g.LowerDistanceParameter());
  else
    printf(" | GeomAPI none");
  if (!Precision::IsInfinite(f) && !Precision::IsInfinite(l))
  {
    double best = 1e300, bu = f;
    for (int i = 0; i <= 200000; i++)
    {
      double u = f + (l - f) * i / 200000.0, d = c->Value(u).Distance(p);
      if (d < best)
      {
        best = d;
        bu   = u;
      }
    }
    printf(" | brute min %.9g at %.9g", best, bu);
  }
  printf("\n");
}

int main()
{
  Handle(Geom_Curve) seg  = new Geom_TrimmedCurve(new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 3, 8);
  Handle(Geom_Curve) half = new Geom_TrimmedCurve(new Geom_Circle(gp_Ax2(), 5), 0, M_PI);
  Handle(Geom_Curve) par  = new Geom_TrimmedCurve(new Geom_Parabola(gp_Ax2(), 2), 0, 2);
  Handle(Geom_Curve) hyp  = new Geom_TrimmedCurve(new Geom_Hyperbola(gp_Ax2(), 3, 2), 0, 1);
  for (gp_Pnt p : {gp_Pnt(100, 0, 0), gp_Pnt(0, 0, 0), gp_Pnt(-50, 3, 0), gp_Pnt(8.001, 0, 0), gp_Pnt(5, 2, 0)})
    probe("segment [3,8]", seg, p);
  for (gp_Pnt p : {gp_Pnt(3, -4, 0), gp_Pnt(0, -6, 0), gp_Pnt(0, -1, 0), gp_Pnt(0, 6, 0), gp_Pnt(6, 0, 0)})
    probe("half circle r5", half, p);
  probe("parabola F2 [0,2]", par, gp_Pnt(20, 0, 0));
  probe("hyperbola 3x2 [0,1]", hyp, gp_Pnt(30, 0, 0));
  probe("full circle r5", new Geom_Circle(gp_Ax2(), 5), gp_Pnt(6, 0, 0));
  probe("line", new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), gp_Pnt(100, 7, 0));
  return 0;
}
