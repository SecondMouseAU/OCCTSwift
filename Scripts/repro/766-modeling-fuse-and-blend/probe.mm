// Epic #766, Tests/OCCTModelingTests/FuseAndBlendTests.swift: kernel parity for all three tests.
// OCCTShapeFuseAndBlend / OCCTShapeCutAndBlend: BRepAlgoAPI_Fuse (or _Cut), then
// BRepFilletAPI_MakeFillet with the radius on every SectionEdges() edge and every edge
// Generated() from either argument's faces; the boolean result is returned as is when no contour
// was added. Reproduced here with the same inputs.
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Shape move(const TopoDS_Shape& s, double x, double y, double z)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(x, y, z));
  return BRepBuilderAPI_Transform(s, t, Standard_True).Shape();
}

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

template <class Op>
static void blend(const char* label, const TopoDS_Shape& a, const TopoDS_Shape& b, double r)
{
  Op op(a, b);
  printf("%s: booleanDone=%d", label, op.IsDone());
  if (!op.IsDone())
  {
    printf("\n");
    return;
  }
  BRepFilletAPI_MakeFillet f(op.Shape());
  TopTools_ListOfShape sec = op.SectionEdges();
  for (auto it = sec.cbegin(); it != sec.cend(); ++it)
    if (it->ShapeType() == TopAbs_EDGE)
      f.Add(r, TopoDS::Edge(*it));
  for (const TopoDS_Shape* arg : {&a, &b})
    for (TopExp_Explorer ex(*arg, TopAbs_FACE); ex.More(); ex.Next())
    {
      TopTools_ListOfShape gen = op.Generated(ex.Current()); // copy: the list is reused per call
      for (auto it = gen.cbegin(); it != gen.cend(); ++it)
        if (it->ShapeType() == TopAbs_EDGE)
          f.Add(r, TopoDS::Edge(*it));
    }
  GProp_GProps p0;
  BRepGProp::VolumeProperties(op.Shape(), p0);
  printf(" booleanVolume=%.10g contours=%d", p0.Mass(), f.NbContours());
  TopoDS_Shape res = op.Shape();
  if (f.NbContours() > 0)
  {
    f.Build();
    printf(" filletDone=%d", f.IsDone());
    if (!f.IsDone())
    {
      printf("\n");
      return;
    }
    res = f.Shape();
  }
  GProp_GProps p;
  BRepGProp::VolumeProperties(res, p);
  printf(" valid=%d volume=%.10g\n", BRepCheck_Analyzer(res).IsValid(), p.Mass());
}

int main()
{
  blend<BRepAlgoAPI_Fuse>("fuseBlendBoxes", box(10, 10, 10), move(box(10, 10, 10), 5, 0, 0), 1.0);
  blend<BRepAlgoAPI_Fuse>("fuseBlendBoxCylinder", move(box(20, 20, 10), -10, -10, 0),
                          BRepPrimAPI_MakeCylinder(5, 15).Shape(), 1.0);
  blend<BRepAlgoAPI_Cut>("cutBlend", move(box(20, 20, 20), -10, -10, 0), BRepPrimAPI_MakeCylinder(5, 25).Shape(),
                         1.0);
  return 0;
}
