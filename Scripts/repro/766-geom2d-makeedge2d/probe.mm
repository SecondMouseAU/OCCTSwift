// #1979 kernel parity for MakeEdge2dTests and MakeEdge2dExtensionsTests: the vertices
// BRepLib_MakeEdge2d / BRepBuilderAPI_MakeEdge2d give each fixture, as the OCCTMakeEdge2d* bridges
// build them, read the way Shape.vertices() reads them (TopExp::MapShapes over TopAbs_VERTEX).
#include <BRepBuilderAPI_MakeEdge2d.hxx>
#include <BRepLib_MakeEdge2d.hxx>
#include <BRep_Tool.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Lin2d.hxx>
#include <cmath>
#include <cstdio>

static void verts(const char* tag, const TopoDS_Shape& e)
{
  TopTools_IndexedMapOfShape m;
  TopExp::MapShapes(e, TopAbs_VERTEX, m);
  printf("%s: vertices=%d", tag, m.Extent());
  for (int i = 1; i <= m.Extent(); i++)
  {
    gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(m(i)));
    printf(" (%.12g, %.12g, %.12g)", p.X(), p.Y(), p.Z());
  }
  printf("\n");
}

int main()
{
  gp_Ax2d ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  verts("points (0,0)-(10,5)", BRepBuilderAPI_MakeEdge2d(gp_Pnt2d(0, 0), gp_Pnt2d(10, 5)).Edge());
  verts("circle r5 arc [0, pi]", BRepBuilderAPI_MakeEdge2d(gp_Circ2d(ax, 5), 0, M_PI).Edge());
  verts("line (0,0)+(1,1) [0, 10]", BRepBuilderAPI_MakeEdge2d(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 1)), 0, 10).Edge());
  verts("full circle r5", BRepLib_MakeEdge2d(gp_Circ2d(ax, 5)).Edge());
  verts("full ellipse 10x5", BRepLib_MakeEdge2d(gp_Elips2d(ax, 10, 5)).Edge());
  verts("ellipse 10x5 arc [0, pi]", BRepLib_MakeEdge2d(gp_Elips2d(ax, 10, 5), 0, M_PI).Edge());
  Handle(Geom2d_Line) l = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 1));
  verts("Geom2d_Line (1,1) [0, 10]", BRepLib_MakeEdge2d(l, 0, 10).Edge());
  Handle(Geom2d_Circle) c = new Geom2d_Circle(gp_Circ2d(ax, 5));
  verts("Geom2d_Circle r5 full range", BRepLib_MakeEdge2d(c).Edge());
  return 0;
}
