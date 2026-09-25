// Epic #766 evidence fix, Tests/OCCTModelingTests/LocOpeLinearFormTests.swift.
// probe.mm printed volume at %.10g and the shape type as an integer. This probe repeats the bridge's
// call (OCCTLocOpeLinearForm: LocOpe_LinearForm::Perform(shape, vec, p1, p2), then Shape()) on the
// centred 5 x 5 x 0.1 box, at %.17g and with the type spelled the way Shape.shapeTypeString spells it.
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <LocOpe_LinearForm.hxx>
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
  TopoDS_Shape      box = BRepPrimAPI_MakeBox(gp_Pnt(-2.5, -2.5, -0.05), 5, 5, 0.1).Shape();
  LocOpe_LinearForm lf;
  lf.Perform(box, gp_Vec(0, 0, 10), gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10));
  const TopoDS_Shape& r = lf.Shape();
  printf("linearForm: produced=%d", !r.IsNull());
  if (!r.IsNull())
  {
    TopTools_IndexedMapOfShape f;
    TopExp::MapShapes(r, TopAbs_FACE, f);
    GProp_GProps p;
    BRepGProp::VolumeProperties(r, p);
    printf(" type=%s faces=%d valid=%d volume=%.17g", lower(TopAbs::ShapeTypeToString(r.ShapeType())).c_str(), f.Extent(),
           BRepCheck_Analyzer(r).IsValid(), p.Mass());
  }
  printf("\n");
  return 0;
}
