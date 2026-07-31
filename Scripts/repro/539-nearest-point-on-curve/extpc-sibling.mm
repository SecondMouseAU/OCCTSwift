// Does BRepExtrema_ExtPC (Shape.pointEdgeExtrema) share the "extremum is not the nearest" defect?
#include <cstdio>
#include <cmath>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_ExtPC.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Ax2.hxx>
int main() {
  Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(0,0,0), gp_Dir(0,0,1)), 5);
  TopoDS_Edge arc = BRepBuilderAPI_MakeEdge(circ, 0.0, M_PI);
  Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0,0,0), gp_Dir(1,0,0));
  TopoDS_Edge seg = BRepBuilderAPI_MakeEdge(line, 3.0, 8.0);
  struct C { const char* n; TopoDS_Edge e; gp_Pnt p; double truth; };
  C cs[] = {
    {"half arc [0,pi] r=5", arc, gp_Pnt(0,-6,0), 7.81025},
    {"half arc [0,pi] r=5", arc, gp_Pnt(3,-4,0), 4.47214},
    {"seg [3,8]",           seg, gp_Pnt(100,0,0), 92.0},
    {"seg [3,8]",           seg, gp_Pnt(0,0,0),   3.0},
  };
  for (auto& c : cs) {
    TopoDS_Vertex v = BRepBuilderAPI_MakeVertex(c.p);
    BRepExtrema_ExtPC ext(v, c.e);
    double best = -1;
    if (ext.IsDone() && ext.NbExt() >= 1) {
      best = sqrt(ext.SquareDistance(1));
      for (int i = 2; i <= ext.NbExt(); i++) best = fmin(best, sqrt(ext.SquareDistance(i)));
    }
    BRepExtrema_DistShapeShape dss(v, c.e);
    printf("%-22s pt(%.3g,%.3g,%.3g)  ExtPC: NbExt=%d dist=%-10.6g %s | DistShapeShape=%-10.6g | truth=%.6g\n",
           c.n, c.p.X(), c.p.Y(), c.p.Z(), ext.IsDone() ? ext.NbExt() : -1, best,
           (ext.IsDone() && ext.NbExt() >= 1 && fabs(best - c.truth) < 1e-4) ? "ok " : "BAD/none",
           dss.IsDone() ? dss.Value() : -1.0, c.truth);
  }
  return 0;
}
