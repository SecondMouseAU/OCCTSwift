// Epic #766 evidence fix, Tests/OCCTModelingTests/LocOpeDPrismTests.swift.
// probe.mm printed volume at %.10g and the shape type as an integer. This probe repeats the same two
// bridge calls (OCCTLocOpeDPrism = LocOpe_DPrism(face, h1, h2, angle); OCCTLocOpeDPrismSingleHeight =
// LocOpe_DPrism(face, h, angle); IsDone(), then Shape()) on face(at: 0) of the centred 10 x 10 x 1 box,
// at %.17g and with the type spelled the way Shape.shapeTypeString spells it (lower case).
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <LocOpe_DPrism.hxx>
#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
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

static void report(const char* label, LocOpe_DPrism& p)
{
  bool produced = p.IsDone() && !p.Shape().IsNull();
  printf("%s: produced=%d", label, produced);
  if (produced)
  {
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(p.Shape(), TopAbs_FACE, faces);
    GProp_GProps g;
    BRepGProp::VolumeProperties(p.Shape(), g);
    printf(" type=%s faces=%d valid=%d volume=%.17g", lower(TopAbs::ShapeTypeToString(p.Shape().ShapeType())).c_str(),
           faces.Extent(), BRepCheck_Analyzer(p.Shape()).IsValid(), g.Mass());
  }
  printf("\n");
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -0.5), 10, 10, 1).Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  TopoDS_Face face = TopoDS::Face(faces(1));
  {
    LocOpe_DPrism p(face, 5, 3, 0.1);
    report("draftPrismTwoHeights / draftPrismHasFaces", p);
  }
  {
    LocOpe_DPrism p(face, 5, 0.1);
    report("draftPrismSingleHeight", p);
  }
  return 0;
}
