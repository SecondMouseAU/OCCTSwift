// Epic #766 evidence fix, Tests/OCCTModelingTests/BOPAlgoSectionTests.swift.
// probe.mm printed the shape type as an integer. This probe repeats the same bridge call (OCCTBOPAlgoSection:
// BOPAlgo_Section with every object and tool as an argument, Perform, Shape()) and prints whether a shape came
// back (no errors), its type as Shape.shapeTypeString spells it, and its edge and vertex counts.
#include <BOPAlgo_Section.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cctype>
#include <cstdio>
#include <string>

static std::string lower(const char* s)
{
  std::string r(s);
  for (auto& c : r)
    c = (char)std::tolower((unsigned char)c);
  return r;
}

static void run(const char* label, const TopoDS_Shape& a, const TopoDS_Shape& b)
{
  BOPAlgo_Section s;
  s.AddArgument(a);
  s.AddArgument(b);
  s.Perform();
  TopTools_IndexedMapOfShape e, v;
  TopExp::MapShapes(s.Shape(), TopAbs_EDGE, e);
  TopExp::MapShapes(s.Shape(), TopAbs_VERTEX, v);
  printf("%s: produced=%d type=%s edges=%d vertices=%d\n", label, !s.HasErrors(),
         lower(TopAbs::ShapeTypeToString(s.Shape().ShapeType())).c_str(), e.Extent(), v.Extent());
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  run("sectionBoxSphere", box, BRepPrimAPI_MakeSphere(6).Shape());
  run("sectionTwoBoxes", box, BRepPrimAPI_MakeBox(gp_Pnt(5, 5, 0), 10, 10, 10).Shape());
  run("staticSection", box, BRepPrimAPI_MakeSphere(7).Shape());
  return 0;
}
