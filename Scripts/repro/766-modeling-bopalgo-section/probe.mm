// Epic #766, Tests/OCCTModelingTests/BOPAlgoSectionTests.swift: kernel parity for all three tests.
// OCCTBOPAlgoSection: BOPAlgo_Section with every object and tool as an argument, Perform, Shape().
#include <BOPAlgo_Section.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

static void run(const char* label, const TopoDS_Shape& a, const TopoDS_Shape& b)
{
  BOPAlgo_Section s;
  s.AddArgument(a);
  s.AddArgument(b);
  s.Perform();
  TopTools_IndexedMapOfShape e, v;
  TopExp::MapShapes(s.Shape(), TopAbs_EDGE, e);
  TopExp::MapShapes(s.Shape(), TopAbs_VERTEX, v);
  printf("%s: hasErrors=%d type=%d edges=%d vertices=%d\n", label, s.HasErrors(), (int)s.Shape().ShapeType(),
         e.Extent(), v.Extent());
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  run("sectionBoxSphere", box, BRepPrimAPI_MakeSphere(6).Shape());
  run("sectionTwoBoxes", box, BRepPrimAPI_MakeBox(gp_Pnt(5, 5, 0), 10, 10, 10).Shape());
  run("staticSection", box, BRepPrimAPI_MakeSphere(7).Shape());
  return 0;
}
