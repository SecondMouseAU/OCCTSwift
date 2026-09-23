// Epic #766, Tests/OCCTModelingTests/LocOpeDPrismTests.swift: kernel parity for all three tests.
// OCCTLocOpeDPrism / OCCTLocOpeDPrismSingleHeight are LocOpe_DPrism(face, h1, h2, angle) and
// LocOpe_DPrism(face, h, angle), IsDone() then Shape(). The spine face is face(at: 0) of the
// centred 10x10x1 box: the first face of TopExp::MapShapes(FACE).
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <LocOpe_DPrism.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void report(const char* label, LocOpe_DPrism& p)
{
  printf("%s: done=%d", label, p.IsDone());
  if (p.IsDone() && !p.Shape().IsNull())
  {
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(p.Shape(), TopAbs_FACE, faces);
    GProp_GProps g;
    BRepGProp::VolumeProperties(p.Shape(), g);
    printf(" type=%d faces=%d valid=%d volume=%.10g", (int)p.Shape().ShapeType(), faces.Extent(),
           BRepCheck_Analyzer(p.Shape()).IsValid(), g.Mass());
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
