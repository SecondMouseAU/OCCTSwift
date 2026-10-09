// #1979 kernel parity for Curve2DGccTests and Curve2DHatchingTests: the Geom2dGcc solvers and the
// Geom2dHatch_Hatcher run, with the same inputs, that OCCTGccCircle2d3Pt, OCCTGccCircle2d2PtRad,
// OCCTGccCircle2dTanCen, OCCTGccLine2dTanPt, OCCTGccCircle2dTanPtRad and OCCTCurve2DHatch make.
#include <Geom2d_Line.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2dGcc_QualifiedCurve.hxx>
#include <Geom2dGcc_Circ2d3Tan.hxx>
#include <Geom2dGcc_Circ2d2TanRad.hxx>
#include <Geom2dGcc_Circ2dTanCen.hxx>
#include <Geom2dGcc_Lin2d2Tan.hxx>
#include <Geom2dHatch_Hatcher.hxx>
#include <Geom2dHatch_Intersector.hxx>
#include <HatchGen_Domain.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Lin2d.hxx>
#include <cstdio>
#include <functional>
#include <algorithm>
#include <vector>

static void circs(const char* tag, int n, const std::function<gp_Circ2d(int)>& f)
{
  printf("%s solutions=%d\n", tag, n);
  for (int i = 1; i <= n; i++)
  {
    gp_Circ2d c = f(i);
    printf("  centre=(%.12g, %.12g) radius=%.12g\n", c.Location().X(), c.Location().Y(), c.Radius());
  }
}

static int hatch(const std::vector<Handle(Geom2d_Curve)>& b, double spacing, TopAbs_Orientation o)
{
  // Mirrors OCCTCurve2DHatch for a box boundary hatched along +x from the origin.
  Geom2dHatch_Intersector ix(1e-6, 1e-6);
  Geom2dHatch_Hatcher     h(ix, 1e-6, 1e-6);
  for (auto& c : b)
    h.AddElement(Geom2dAdaptor_Curve(c), o);
  double yMin = 0, yMax = 0;
  for (auto& c : b)
  {
    yMin = std::min(yMin, std::min(c->Value(c->FirstParameter()).Y(), c->Value(c->LastParameter()).Y()));
    yMax = std::max(yMax, std::max(c->Value(c->FirstParameter()).Y(), c->Value(c->LastParameter()).Y()));
  }
  int              nLines = (int)((yMax - yMin) / spacing) + 2;
  std::vector<int> idx;
  for (int i = 0; i < nLines; i++)
    idx.push_back(h.AddHatching(Geom2dAdaptor_Curve(
      new Geom2d_Line(gp_Lin2d(gp_Pnt2d(0, yMin + i * spacing), gp_Dir2d(1, 0))))));
  h.Trim();
  h.ComputeDomains();
  int segs = 0;
  for (int k : idx)
  {
    if (!h.IsDone(k))
      continue;
    for (int d = 1; d <= h.NbDomains(k); d++)
    {
      HatchGen_Domain dom = h.Domain(k, d);
      if (!dom.HasFirstPoint() || !dom.HasSecondPoint())
        continue;
      if (b.size() == 4 && yMax < 20)
      {
        gp_Pnt2d p1 = h.HatchingCurve(k).Value(dom.FirstPoint().Parameter());
        gp_Pnt2d p2 = h.HatchingCurve(k).Value(dom.SecondPoint().Parameter());
        printf("  segment (%.12g, %.12g)-(%.12g, %.12g)\n", p1.X(), p1.Y(), p2.X(), p2.Y());
      }
      segs++;
    }
  }
  return segs;
}

int main()
{
  {
    Geom2dGcc_Circ2d3Tan s(new Geom2d_CartesianPoint(0, 0), new Geom2d_CartesianPoint(10, 0),
                           new Geom2d_CartesianPoint(5, 5), 1e-6);
    circs("Circ2d3Tan (0,0) (10,0) (5,5)", s.NbSolutions(), [&](int i) { return s.ThisSolution(i); });
  }
  {
    Geom2dGcc_Circ2d2TanRad s(new Geom2d_CartesianPoint(0, 0), new Geom2d_CartesianPoint(6, 0), 5, 1e-6);
    circs("Circ2d2TanRad (0,0) (6,0) r5", s.NbSolutions(), [&](int i) { return s.ThisSolution(i); });
  }
  Handle(Geom2d_Line) xAxis = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  {
    Geom2dGcc_Circ2dTanCen s(Geom2dGcc_QualifiedCurve(Geom2dAdaptor_Curve(xAxis), GccEnt_unqualified),
                             new Geom2d_CartesianPoint(5, 3), 1e-6);
    circs("Circ2dTanCen x-axis centre (5,3)", s.NbSolutions(), [&](int i) { return s.ThisSolution(i); });
  }
  {
    Handle(Geom2d_Circle) c5 = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Geom2dGcc_Lin2d2Tan   s(Geom2dGcc_QualifiedCurve(Geom2dAdaptor_Curve(c5), GccEnt_outside),
                          gp_Pnt2d(10, 0), 1e-6);
    printf("Lin2d2Tan circle r5 outside, point (10,0): solutions=%d\n", s.NbSolutions());
    for (int i = 1; i <= s.NbSolutions(); i++)
    {
      gp_Lin2d l = s.ThisSolution(i);
      gp_Pnt2d t;
      double   u1, u2;
      s.Tangency1(i, u1, u2, t);
      printf("  location=(%.12g, %.12g) direction=(%.12g, %.12g) tangency=(%.12g, %.12g)\n",
             l.Location().X(), l.Location().Y(), l.Direction().X(), l.Direction().Y(), t.X(), t.Y());
    }
  }
  {
    Geom2dGcc_Circ2d2TanRad s(Geom2dGcc_QualifiedCurve(Geom2dAdaptor_Curve(xAxis), GccEnt_unqualified),
                              new Geom2d_CartesianPoint(5, 5), 5, 1e-6);
    circs("Circ2d2TanRad x-axis + point (5,5) r5", s.NbSolutions(), [&](int i) { return s.ThisSolution(i); });
  }
  {
    std::vector<Handle(Geom2d_Curve)> ccw = {
      GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)).Value(),
      GCE2d_MakeSegment(gp_Pnt2d(10, 0), gp_Pnt2d(10, 10)).Value(),
      GCE2d_MakeSegment(gp_Pnt2d(10, 10), gp_Pnt2d(0, 10)).Value(),
      GCE2d_MakeSegment(gp_Pnt2d(0, 10), gp_Pnt2d(0, 0)).Value()};
    printf("Hatch 10x10 CCW spacing 2:\n");
    printf("  total=%d\n", hatch(ccw, 2.0, TopAbs_FORWARD));
    std::vector<Handle(Geom2d_Curve)> tall = {
      GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(10, 0)).Value(),
      GCE2d_MakeSegment(gp_Pnt2d(10, 0), gp_Pnt2d(10, 3000)).Value(),
      GCE2d_MakeSegment(gp_Pnt2d(10, 3000), gp_Pnt2d(0, 3000)).Value(),
      GCE2d_MakeSegment(gp_Pnt2d(0, 3000), gp_Pnt2d(0, 0)).Value()};
    printf("Hatch 10x3000 spacing 1: total=%d\n", hatch(tall, 1.0, TopAbs_FORWARD));
  }
  return 0;
}
