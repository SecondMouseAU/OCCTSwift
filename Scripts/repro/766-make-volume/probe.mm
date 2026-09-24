// Epic #766, MakeVolumeTests.swift: kernel parity for "Make volume from faces".
// BOPAlgo_MakerVolume, AddArgument per shape, Perform, HasErrors: what OCCTShapeMakeVolume runs.
// Case A is the test's original input, two coincident 10 x 10 faces from Wire.rectangle
// (centred on the origin in z = 0, OCCTWireCreateRectangle). Case B is the six faces of
// Shape.box(width: 10, height: 10, depth: 10), centred on the origin (OCCTShapeCreateBox).
#include <BOPAlgo_MakerVolume.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void run(const char* name, const NCollection_List<TopoDS_Shape>& args)
{
  BOPAlgo_MakerVolume mv;
  for (NCollection_List<TopoDS_Shape>::Iterator it(args); it.More(); it.Next())
    mv.AddArgument(it.Value());
  mv.Perform();
  printf("%s: hasErrors=%d", name, mv.HasErrors());
  if (!mv.HasErrors())
  {
    const TopoDS_Shape& r      = mv.Shape();
    int                 solids = 0;
    for (TopExp_Explorer ex(r, TopAbs_SOLID); ex.More(); ex.Next())
      ++solids;
    GProp_GProps g;
    BRepGProp::VolumeProperties(r, g);
    printf(" isNull=%d shapeType=%d solids=%d volume=%.17g", r.IsNull(), (int)r.ShapeType(), solids,
           g.Mass());
  }
  printf("\n");
}

int main()
{
  NCollection_List<TopoDS_Shape> a;
  for (int i = 0; i < 2; ++i)
  {
    BRepBuilderAPI_MakePolygon poly(gp_Pnt(-5, -5, 0), gp_Pnt(5, -5, 0), gp_Pnt(5, 5, 0),
                                    gp_Pnt(-5, 5, 0), true);
    a.Append(BRepBuilderAPI_MakeFace(poly.Wire(), true).Face());
  }
  run("A two coincident rectangles", a);

  NCollection_List<TopoDS_Shape> b;
  TopoDS_Shape         box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  for (TopExp_Explorer ex(box, TopAbs_FACE); ex.More(); ex.Next())
    b.Append(ex.Current());
  run("B six faces of a 10 box", b);
  return 0;
}
