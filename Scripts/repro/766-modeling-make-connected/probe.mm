// Epic #766, Tests/OCCTModelingTests/MakeConnectedTests.swift: kernel parity for connectBoxes.
// OCCTShapeMakeConnected is BOPAlgo_MakeConnected, AddArgument per shape, Perform(), nullptr on
// HasErrors(). Inputs: the centred 10 mm box and a copy translated by (10, 0, 0).
#include <BOPAlgo_MakeConnected.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

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
  printf("connectBoxes: hasErrors=%d", mc.HasErrors());
  if (!mc.HasErrors())
  {
    TopTools_IndexedMapOfShape s, f;
    TopExp::MapShapes(mc.Shape(), TopAbs_SOLID, s);
    TopExp::MapShapes(mc.Shape(), TopAbs_FACE, f);
    GProp_GProps p;
    BRepGProp::VolumeProperties(mc.Shape(), p);
    printf(" type=%d solids=%d faces=%d valid=%d volume=%.10g", (int)mc.Shape().ShapeType(), s.Extent(),
           f.Extent(), BRepCheck_Analyzer(mc.Shape()).IsValid(), p.Mass());
  }
  printf("\n");
  return 0;
}
