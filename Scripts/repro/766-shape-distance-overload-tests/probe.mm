// Kernel-parity probe for Tests/OCCTAnalysisTests/ShapeDistanceOverloadTests.swift (#766
// execution, issues #1891-#1894). Every overload lifts its Wire/Edge/Face to a Shape and calls
// OCCTShapeDistance / OCCTShapeIntersects, i.e. BRepExtrema_DistShapeShape. See transcript.txt.

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <gp_Circ.hxx>
#include <cstdio>

// OCCTWireCreateCircleEx
static TopoDS_Shape circleWire(double ox, double oy, double oz, double r)
{
  gp_Circ     c(gp_Ax2(gp_Pnt(ox, oy, oz), gp_Dir(0, 0, 1)), r);
  TopoDS_Edge e = BRepBuilderAPI_MakeEdge(c);
  return BRepBuilderAPI_MakeWire(e).Wire();
}

static void report(const char* name, const TopoDS_Shape& a, const TopoDS_Shape& b, double defl)
{
  BRepExtrema_DistShapeShape d(a, b, defl);
  printf("%s: done=%d n=%d value=%.12f", name, (int)d.IsDone(), d.NbSolution(), d.Value());
  if (d.IsDone() && d.NbSolution() > 0)
  {
    gp_Pnt p1 = d.PointOnShape1(1), p2 = d.PointOnShape2(1);
    printf(" p1=(%.9g, %.9g, %.9g) p2=(%.9g, %.9g, %.9g)",
           p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
  }
  printf(" intersects(1e-6)=%d\n",
         (int)(d.IsDone() && d.NbSolution() > 0 && d.Value() <= defl));
}

int main()
{
  TopoDS_Shape box  = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape box2 = BRepPrimAPI_MakeBox(gp_Pnt(-2.5, -2.5, -2.5), 5, 5, 5).Shape();

  report("distanceToWire (circle r=1 at (20,0,0))", box, circleWire(20, 0, 0, 1), 1e-6);
  report("intersectsWire (circle r=1 at (20,0,0))", box, circleWire(20, 0, 0, 1), 1e-6);
  report("intersectsWire (circle r=1 at origin, inside box)", box, circleWire(0, 0, 0, 1), 1e-6);
  report("intersectsWire (circle r=10 at origin, crossing the box)",
         box,
         circleWire(0, 0, 0, 10),
         1e-6);

  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  report("distanceToEdge (box edges()[0])", box, edges(1), 1e-6);

  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box2, TopAbs_FACE, faces);
  report("distanceToFace (box2 faces()[0])", box, faces(1), 1e-6);
  return 0;
}
