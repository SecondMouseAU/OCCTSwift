// Epic #766 evidence fix, Tests/OCCTModelingTests/IntegrationBooleanChainStressTests.swift.
// probe.mm printed the volumes at %.10g and never counted the cuts that failed. This probe repeats the same
// chain (Shape.subtracting is OCCTShapeSubtractEx -> BRepAlgoAPI_Cut; twenty r=5 spheres on a radius-30 ring
// at z=0 cut in turn from the centred 100 mm box) and prints, at %.17g, the volume before the first cut and
// after the 5th, 10th, 15th and 20th, whether the shape was valid at each of those and at the end, and how
// many of the twenty cuts did not produce a shape (the Swift test drops such a cut without noting it).
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
  printf("start: volume=%.17g\n", volume(shape));
  int  failures = 0;
  bool allValid = true;
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
    {
      bool valid = BRepCheck_Analyzer(shape).IsValid();
      allValid   = allValid && valid;
      printf("after %d: valid=%d volume=%.17g\n", i + 1, valid, volume(shape));
    }
  }
  bool valid = BRepCheck_Analyzer(shape).IsValid();
  allValid   = allValid && valid;
  printf("final: failures=%d allValid=%d volume=%.17g\n", failures, allValid, volume(shape));
  return 0;
}
