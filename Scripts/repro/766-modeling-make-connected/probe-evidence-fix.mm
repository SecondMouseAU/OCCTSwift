// Epic #766 evidence fix, Tests/OCCTModelingTests/MakeConnectedTests.swift.
// probe.mm printed the volume at %.10g and the shape type as an integer. This probe repeats the bridge's call
// (OCCTShapeMakeConnected: BOPAlgo_MakeConnected, AddArgument per shape, Perform(), nothing on HasErrors())
// on the centred 10 mm box and a copy translated by (10, 0, 0), and prints whether a shape came back, its
// type (as Shape.shapeTypeString spells it), solid and face counts, validity and volume at %.17g.
#include <BOPAlgo_MakeConnected.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
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

int main()
{
  TopoDS_Shape b1 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  gp_Trsf      t;
  t.SetTranslation(gp_Vec(10, 0, 0));
  TopoDS_Shape          b2 = BRepBuilderAPI_Transform(b1, t, Standard_True).Shape();
  BOPAlgo_MakeConnected mc;
  mc.AddArgument(b1);
  mc.AddArgument(b2);
  mc.Perform();
  printf("connectBoxes: produced=%d", !mc.HasErrors());
  if (!mc.HasErrors())
  {
    TopTools_IndexedMapOfShape s, f;
    TopExp::MapShapes(mc.Shape(), TopAbs_SOLID, s);
    TopExp::MapShapes(mc.Shape(), TopAbs_FACE, f);
    GProp_GProps p;
    BRepGProp::VolumeProperties(mc.Shape(), p);
    printf(" type=%s solids=%d faces=%d valid=%d volume=%.17g", lower(TopAbs::ShapeTypeToString(mc.Shape().ShapeType())).c_str(),
           s.Extent(), f.Extent(), BRepCheck_Analyzer(mc.Shape()).IsValid(), p.Mass());
  }
  printf("\n");
  return 0;
}
