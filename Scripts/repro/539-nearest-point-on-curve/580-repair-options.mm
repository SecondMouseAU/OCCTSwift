// #580: the two routes compared on the same 189 combinations -- repair inside BRepExtrema_ExtPC
// (extrema + TrimmedSquareDistances) vs reuse of #539's occtNearestPointOnCurveRange.
#include <cstdio>
#include <cmath>
#include <vector>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Line.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_ExtPC.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRep_Tool.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Vertex.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <Precision.hxx>
#include <gp_Ax2.hxx>

// Verbatim shape of the shipped #539 helper.
static bool nearestOnRange(const Handle(Geom_Curve)& curve, const gp_Pnt& point,
                           double first, double last, double precision, double* outDistance) {
  if (curve.IsNull()) return false;
  const bool ff = !Precision::IsInfinite(first), lf = !Precision::IsInfinite(last);
  double bestD = RealLast(); bool found = false;
  auto consider = [&](double t) {
    if (ff && t < first) return;
    if (lf && t > last) return;
    gp_Pnt c; try { c = curve->Value(t); } catch (...) { return; }
    double d = point.Distance(c);
    if (d < bestD) { bestD = d; found = true; }
  };
  double sp = 0, sd = RealLast(); bool haveS = false;
  try { ShapeAnalysis_Curve a; gp_Pnt pr; sd = a.Project(curve, point, precision, pr, sp); haveS = true; consider(sp); } catch (...) {}
  try { GeomAPI_ProjectPointOnCurve pc(point, curve, first, last);
        for (int i = 1; i <= pc.NbPoints(); i++) consider(pc.Parameter(i)); } catch (...) {}
  if (ff) consider(first);
  if (lf) consider(last);
  if (!found) { if (!haveS) return false; bestD = sd; }
  *outDistance = bestD;
  return true;
}

static double truthOf(const TopoDS_Edge& e, const gp_Pnt& p) {
  BRepAdaptor_Curve ad(e);
  double f = ad.FirstParameter(), l = ad.LastParameter(), best = 1e300;
  for (int i = 0; i <= 400000; i++)
    best = fmin(best, p.Distance(ad.Value(f + (l - f) * i / 400000.0)));
  return best;
}

static int okExt = 0, okHelper = 0, total = 0;

static void run(const TopoDS_Edge& e, const gp_Pnt& p, int ei) {
  TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(p);
  BRepExtrema_ExtPC ext(v, e);
  double minAll = 1e300;
  if (ext.IsDone() && ext.NbExt() >= 1)
    for (int i = 1; i <= ext.NbExt(); i++) minAll = fmin(minAll, sqrt(ext.SquareDistance(i)));
  double d1 = -1, d2 = -1; gp_Pnt p1, p2;
  ext.TrimmedSquareDistances(d1, d2, p1, p2);
  double viaExt = fmin(minAll, fmin(sqrt(fmax(d1, 0.0)), sqrt(fmax(d2, 0.0))));

  double first, last;
  Handle(Geom_Curve) c = BRep_Tool::Curve(e, first, last);
  double viaHelper = -1;
  bool got = nearestOnRange(c, p, first, last, Precision::Confusion(), &viaHelper);

  double t = truthOf(e, p);
  auto near = [&](double a) { return fabs(a - t) <= 1e-5 * (1 + t); };
  total++;
  if (near(viaExt)) okExt++; else printf("  ExtPC route MISS  edge#%d pt(%.4g,%.4g,%.4g): %.8g vs truth %.8g\n", ei, p.X(), p.Y(), p.Z(), viaExt, t);
  if (got && near(viaHelper)) okHelper++; else printf("  #539 helper MISS  edge#%d pt(%.4g,%.4g,%.4g): %.8g vs truth %.8g\n", ei, p.X(), p.Y(), p.Z(), viaHelper, t);
}

int main() {
  gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
  Handle(Geom_Circle) circ = new Geom_Circle(ax, 5);
  Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0,0,0), gp_Dir(1,0,0));
  TColgp_Array1OfPnt pts(1, 5);
  pts.SetValue(1, gp_Pnt(0,0,0)); pts.SetValue(2, gp_Pnt(1,2,0));
  pts.SetValue(3, gp_Pnt(3,3,0)); pts.SetValue(4, gp_Pnt(5,1,0));
  pts.SetValue(5, gp_Pnt(7,0,0));
  std::vector<TopoDS_Edge> edges = {
    BRepBuilderAPI_MakeEdge(line, 3.0, 8.0),
    BRepBuilderAPI_MakeEdge(circ, 0.0, M_PI),
    BRepBuilderAPI_MakeEdge(circ, 0.0, M_PI / 2),
    BRepBuilderAPI_MakeEdge(circ, 5.5, 7.0),
    BRepBuilderAPI_MakeEdge(circ),
    BRepBuilderAPI_MakeEdge(new Geom_Ellipse(ax, 8, 4), 0.0, M_PI),
    BRepBuilderAPI_MakeEdge(GeomAPI_PointsToBSpline(pts).Curve()),
  };
  std::vector<gp_Pnt> queries;
  for (int i = 0; i < 12; i++) {
    double a = 2 * M_PI * i / 12.0;
    queries.push_back(gp_Pnt(6 * cos(a), 6 * sin(a), 0));
    queries.push_back(gp_Pnt(2 * cos(a), 2 * sin(a), 0));
  }
  queries.push_back(gp_Pnt(0, 0, 0));
  queries.push_back(gp_Pnt(100, 0, 0));
  queries.push_back(gp_Pnt(0, 0, 4));

  for (size_t ei = 0; ei < edges.size(); ei++) for (auto& q : queries) run(edges[ei], q, (int)ei);

  printf("\n%d combinations\n", total);
  printf("  repair inside BRepExtrema_ExtPC (extrema + TrimmedSquareDistances) : %d\n", okExt);
  printf("  reuse #539's occtNearestPointOnCurveRange                          : %d\n", okHelper);
  return 0;
}
