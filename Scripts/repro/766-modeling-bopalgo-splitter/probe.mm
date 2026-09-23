// Epic #766, Tests/OCCTModelingTests/BOPAlgoSplitterTests.swift: kernel parity for both tests.
// OCCTBOPAlgoSplit: BOPAlgo_Splitter, AddArgument(objects), AddTool(tools), Perform, Shape().
#include <BOPAlgo_Splitter.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

static void run(const char* label, const TopoDS_Shape& obj, const TopoDS_Shape& tool)
{
  BOPAlgo_Splitter s;
  s.AddArgument(obj);
  s.AddTool(tool);
  s.Perform();
  TopTools_IndexedMapOfShape solids;
  TopExp::MapShapes(s.Shape(), TopAbs_SOLID, solids);
  GProp_GProps p;
  BRepGProp::VolumeProperties(s.Shape(), p);
  printf("%s: hasErrors=%d valid=%d solids=%d volume=%.10g\n", label, s.HasErrors(),
         BRepCheck_Analyzer(s.Shape()).IsValid(), solids.Extent(), p.Mass());
}

int main()
{
  TopoDS_Shape box1 = BRepPrimAPI_MakeBox(gp_Pnt(-10, -10, -10), 20, 20, 20).Shape();
  run("splitBoxes", box1, BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 20, 20, 20).Shape());
  run("splitProducesMultipleSolids", box1, BRepPrimAPI_MakeBox(gp_Pnt(0, -10, -10), 20, 20, 20).Shape());
  return 0;
}
