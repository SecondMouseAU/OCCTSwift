// Epic #766, Tests/OCCTModelingTests/MultiFuseTests.swift: kernel parity for all four tests.
// OCCTShapeFuseMulti is BRepAlgoAPI_BuilderAlgo (General Fuse) over all arguments, serial,
// nullptr unless IsDone(); Swift fuseAll refuses fewer than 2 shapes before the bridge.
#include <BRepAlgoAPI_BuilderAlgo.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <cstdio>
#include <vector>

static TopoDS_Shape moved(const TopoDS_Shape& b, double dx, double dy, double dz)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(dx, dy, dz));
  return BRepBuilderAPI_Transform(b, t, Standard_True).Shape();
}

static void gf(const char* label, std::vector<TopoDS_Shape> v)
{
  TopTools_ListOfShape args;
  for (auto& s : v)
    args.Append(s);
  BRepAlgoAPI_BuilderAlgo b;
  b.SetArguments(args);
  b.Build();
  if (!b.IsDone())
  {
    printf("%s: not done\n", label);
    return;
  }
  TopTools_IndexedMapOfShape solids;
  TopExp::MapShapes(b.Shape(), TopAbs_SOLID, solids);
  GProp_GProps p;
  BRepGProp::VolumeProperties(b.Shape(), p);
  printf("%s: type=%d solids=%d volume=%.10g\n", label, (int)b.Shape().ShapeType(), solids.Extent(), p.Mass());
}

int main()
{
  TopoDS_Shape b10 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  gf("fuseThreeBoxes", {b10, moved(b10, 5, 0, 0), moved(b10, 0, 5, 0)});
  TopoDS_Shape s = BRepPrimAPI_MakeSphere(5).Shape();
  gf("fuseFourSpheres", {s, moved(s, 4, 0, 0), moved(s, 0, 4, 0), moved(s, 4, 4, 0)});
  TopoDS_Shape b5 = BRepPrimAPI_MakeBox(gp_Pnt(-2.5, -2.5, -2.5), 5, 5, 5).Shape();
  gf("fuseNonOverlapping", {b5, moved(b5, 20, 20, 20)});
  return 0;
}
