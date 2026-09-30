// #766 kernel parity for Issue580PointEdgeExtremaTests. OCCTBRepExtremaExtPC answers the nearest
// point with the bridge's own occtNearestPointOnCurveRange; this probe asks the kernel the same
// question independently, with BRepExtrema_DistShapeShape between a vertex and the edge (which
// considers the edge's ends), and reads BRepExtrema_ExtPC::NbExt() for solutionCount, as the
// bridge does.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepExtrema_ExtPC.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GC_MakeSegment.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static void measure(const char* label, const TopoDS_Edge& e, gp_Pnt p)
{
  TopoDS_Vertex              v = BRepBuilderAPI_MakeVertex(p);
  BRepExtrema_DistShapeShape dss(v, e);
  gp_Pnt                     q = dss.PointOnShape2(1);
  BRepExtrema_ExtPC          ext(v, e);
  printf("%s point (%g, %g, %g): distance=%.17g nearest=(%.17g, %.17g, %.17g) ExtPC IsDone=%d NbExt=%d\n", label,
         p.X(), p.Y(), p.Z(), dss.Value(), q.X(), q.Y(), q.Z(), ext.IsDone(), ext.IsDone() ? ext.NbExt() : 0);
}

int main()
{
  // Wire.line(from: (3,0,0), to: (8,0,0)) and Wire.arc(center: .zero, radius: 5, 0, pi)
  TopoDS_Edge segment = BRepBuilderAPI_MakeEdge(gp_Pnt(3, 0, 0), gp_Pnt(8, 0, 0)).Edge();
  Handle(Geom_Circle) circle = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  TopoDS_Edge         arc    = BRepBuilderAPI_MakeEdge(new Geom_TrimmedCurve(circle, 0, M_PI)).Edge();

  measure("halfArc belowTheArc", arc, gp_Pnt(0, -6, 0));
  measure("halfArc onTheCircleButOffTheArc", arc, gp_Pnt(3, -4, 0));
  measure("segment pastTheEnd", segment, gp_Pnt(100, 0, 0));
  measure("segment before", segment, gp_Pnt(0, 0, 0));
  measure("segment perpendicularFoot", segment, gp_Pnt(5, 2, 0));
  measure("halfArc above", arc, gp_Pnt(0, 6, 0));
  gp_Pnt agree[6] = {gp_Pnt(0, -6, 0), gp_Pnt(3, -4, 0), gp_Pnt(0, 6, 0), gp_Pnt(0, -1, 0), gp_Pnt(6, 0, 0), gp_Pnt(0, 0, 0)};
  for (auto& p : agree)
    measure("halfArc agreesWithEdgeProject", arc, p);

  // Shape.box(10,10,10), centred; edges in TopExp::MapShapes order (Shape.edges()' enumeration).
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  printf("box edges=%d\n", edges.Extent());
  double nearest = 1e300;
  for (int i = 1; i <= edges.Extent(); i++)
  {
    char label[64];
    snprintf(label, sizeof(label), "box edge %d", i - 1);
    measure(label, TopoDS::Edge(edges(i)), gp_Pnt(1, 2, 3));
    TopoDS_Vertex              v = BRepBuilderAPI_MakeVertex(gp_Pnt(20, 0, 0));
    BRepExtrema_DistShapeShape d(v, edges(i));
    nearest = std::min(nearest, d.Value());
  }
  printf("box proximity scan from (20,0,0): nearest=%.17g (sqrt(250)=%.17g)\n", nearest, std::sqrt(250.0));
  return 0;
}
