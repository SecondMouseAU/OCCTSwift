// Epic #766 (#1978), kernel parity for EdgePolylineConsistencyTests.swift: the edge counts the
// polylines are compared against, from TopExp::MapShapes on the same shapes, and which of them
// carry a 3D curve (a degenerated edge has none and is skipped). EditorViewV162Tests.swift is not
// probed here: its observables are BRepGraph editor state, and the regularity setter is a bridge
// stub on 8.0.1 by design (#490/#513).
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void count(const char* name, const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(s, TopAbs_EDGE, m);
  int withCurve = 0, degenerated = 0;
  for (int i = 1; i <= m.Extent(); i++)
  {
    const TopoDS_Edge& e = TopoDS::Edge(m(i));
    if (BRep_Tool::Degenerated(e))
      degenerated++;
    double f, l;
    if (!BRep_Tool::Curve(e, f, l).IsNull())
      withCurve++;
  }
  printf("%s: edges=%d with 3D curve=%d degenerated=%d\n", name, m.Extent(), withCurve, degenerated);
}

int main()
{
  count("box 5", BRepPrimAPI_MakeBox(5, 5, 5).Shape());
  count("cylinder r=3 h=6", BRepPrimAPI_MakeCylinder(3, 6).Shape());
  count("sphere r=4", BRepPrimAPI_MakeSphere(4).Shape());
  BRepBuilderAPI_MakePolygon poly(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 5, 0), gp_Pnt(0, 5, 0), true);
  TopoDS_Face f = BRepBuilderAPI_MakeFace(poly.Wire());
  count("rectangle 10x5 extruded 8", BRepPrimAPI_MakePrism(f, gp_Vec(0, 0, 8)).Shape());
  return 0;
}
