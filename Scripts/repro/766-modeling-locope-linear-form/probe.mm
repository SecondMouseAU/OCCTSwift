// Epic #766, Tests/OCCTModelingTests/LocOpeLinearFormTests.swift: kernel parity for linearForm.
// OCCTLocOpeLinearForm is LocOpe_LinearForm::Perform(shape, vec, p1, p2) then Shape(), nullptr on
// a null shape. The "face" is the centred 5x5x0.1 box solid, as in the test.
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <LocOpe_LinearForm.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape      box = BRepPrimAPI_MakeBox(gp_Pnt(-2.5, -2.5, -0.05), 5, 5, 0.1).Shape();
  LocOpe_LinearForm lf;
  lf.Perform(box, gp_Vec(0, 0, 10), gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10));
  const TopoDS_Shape& r = lf.Shape();
  printf("linearForm: null=%d", r.IsNull());
  if (!r.IsNull())
  {
    TopTools_IndexedMapOfShape f;
    TopExp::MapShapes(r, TopAbs_FACE, f);
    GProp_GProps p;
    BRepGProp::VolumeProperties(r, p);
    printf(" type=%d faces=%d valid=%d volume=%.10g", (int)r.ShapeType(), f.Extent(),
           BRepCheck_Analyzer(r).IsValid(), p.Mass());
  }
  printf("\n");
  return 0;
}
