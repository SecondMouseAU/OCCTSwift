// Epic #766, Tests/OCCTModelingTests/OffsetByJoinTests.swift: kernel parity for all four tests.
// OCCTShapeOffsetByJoin is BRepOffsetAPI_MakeOffsetShape::PerformByJoin(shape, distance, 1e-7,
// BRepOffset_Skin, false, false, join, false), join Arc (0) or Intersection (2).
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <GProp_GProps.hxx>
#include <cstdio>

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

static void off(const char* label, const TopoDS_Shape& s, double d, GeomAbs_JoinType j)
{
  BRepOffsetAPI_MakeOffsetShape m;
  m.PerformByJoin(s, d, 1e-7, BRepOffset_Skin, false, false, j, false);
  printf("%s: done=%d", label, m.IsDone());
  if (m.IsDone())
    printf(" valid=%d volume=%.10g input=%.10g", BRepCheck_Analyzer(m.Shape()).IsValid(), volume(m.Shape()),
           volume(s));
  printf("\n");
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  off("offsetArc (+1)", box, 1, GeomAbs_Arc);
  off("offsetInward (-1)", box, -1, GeomAbs_Arc);
  off("offsetIntersection (+1)", box, 1, GeomAbs_Intersection);
  off("offsetCylinder (+1)", BRepPrimAPI_MakeCylinder(5, 10).Shape(), 1, GeomAbs_Arc);
  return 0;
}
