// Epic #766 evidence fix, Tests/OCCTModelingTests/FuseAndBlendTests.swift.
// probe.mm printed volume at %.10g and did not report the shape type or the face count. This probe
// repeats the bridge's OCCTShapeFuseAndBlend / OCCTShapeCutAndBlend on the same inputs: the boolean
// (BRepAlgoAPI_Fuse or _Cut), then BRepFilletAPI_MakeFillet with the radius on every SectionEdges() edge
// and every edge Generated() from either argument's faces, the boolean result returned unblended when no
// contour was added. It prints the returned shape's type (as Shape.shapeTypeString spells it), face
// count, validity and volume at %.17g.
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <GProp_GProps.hxx>
#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopoDS.hxx>
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

static TopoDS_Shape move(const TopoDS_Shape& s, double x, double y, double z)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(x, y, z));
  return BRepBuilderAPI_Transform(s, t, Standard_True).Shape();
}

// Shape.box(width:height:depth:) is centred on the origin (OCCTShapeCreateBox).
static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

template <class Op>
static void blend(const char* label, const TopoDS_Shape& a, const TopoDS_Shape& b, double r)
{
  Op op(a, b);
  if (!op.IsDone())
  {
    printf("%s: booleanDone=0\n", label);
    return;
  }
  BRepFilletAPI_MakeFillet f(op.Shape());
  TopTools_ListOfShape     sec = op.SectionEdges();
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
  TopoDS_Shape res      = op.Shape();
  int          contours = f.NbContours();
  bool         filletOk = true;
  if (contours > 0)
  {
    f.Build();
    filletOk = f.IsDone();
    if (filletOk)
      res = f.Shape();
  }
  if (!filletOk)
  {
    printf("%s: booleanDone=1 contours=%d filletDone=0\n", label, contours);
    return;
  }
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(res, TopAbs_FACE, faces);
  GProp_GProps p;
  BRepGProp::VolumeProperties(res, p);
  printf("%s: produced=1 contours=%d type=%s faces=%d valid=%d volume=%.17g\n", label, contours,
         lower(TopAbs::ShapeTypeToString(res.ShapeType())).c_str(), faces.Extent(), BRepCheck_Analyzer(res).IsValid(),
         p.Mass());
}

int main()
{
  blend<BRepAlgoAPI_Fuse>("fuseBlendBoxes", box(10, 10, 10), move(box(10, 10, 10), 5, 0, 0), 1.0);
  blend<BRepAlgoAPI_Fuse>("fuseBlendBoxCylinder", move(box(20, 20, 10), -10, -10, 0), BRepPrimAPI_MakeCylinder(5, 15).Shape(), 1.0);
  blend<BRepAlgoAPI_Cut>("cutBlend", move(box(20, 20, 20), -10, -10, 0), BRepPrimAPI_MakeCylinder(5, 25).Shape(), 1.0);
  return 0;
}
