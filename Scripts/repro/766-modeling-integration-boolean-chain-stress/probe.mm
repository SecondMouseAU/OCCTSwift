// Epic #766, Tests/OCCTModelingTests/IntegrationBooleanChainStressTests.swift: kernel parity for
// its one test. Shape.subtracting is OCCTShapeSubtractEx -> BRepAlgoAPI_Cut; twenty r=5 spheres on a
// radius-30 ring at z=0 are cut in turn from a 100 mm box centred at the origin. Validity is
// BRepCheck_Analyzer (OCCTShapeIsValid), volume BRepGProp::VolumeProperties.
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GProp_GProps.hxx>
#include <cmath>
#include <cstdio>

static double volume(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}

int main()
{
  TopoDS_Shape shape = BRepPrimAPI_MakeBox(gp_Pnt(-50, -50, -50), 100, 100, 100).Shape();
  printf("start: volume=%.10g\n", volume(shape));
  int failures = 0;
  for (int i = 0; i < 20; i++)
  {
    double  a = i * (2.0 * M_PI / 20.0);
    gp_Trsf t;
    t.SetTranslation(gp_Vec(30.0 * std::cos(a), 30.0 * std::sin(a), 0));
    TopoDS_Shape    sphere = BRepBuilderAPI_Transform(BRepPrimAPI_MakeSphere(5).Shape(), t, Standard_True).Shape();
    BRepAlgoAPI_Cut cut(shape, sphere);
    if (cut.IsDone() && !cut.Shape().IsNull())
      shape = cut.Shape();
    else
      failures++;
    if ((i + 1) % 5 == 0)
      printf("after %d: valid=%d volume=%.10g\n", i + 1, BRepCheck_Analyzer(shape).IsValid(), volume(shape));
  }
  printf("final: failures=%d valid=%d volume=%.10g removed=%.10g (20 disjoint spheres would remove %.10g)\n",
         failures, BRepCheck_Analyzer(shape).IsValid(), volume(shape), 1e6 - volume(shape),
         20 * 4.0 / 3.0 * M_PI * 125);
  return 0;
}
