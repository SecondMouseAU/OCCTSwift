// #766 kernel parity for Issue885TotalAreaDivergenceTests, on Shape.sphere(radius: 10).
// surfaceArea is BRepGProp::SurfaceProperties(shape, props) (OCCTShapeGetSurfaceArea);
// surfaceInertia and surfaceInertiaProperties read the same call through
// occtSurfaceMassProperties; measure(linearTolerance:).totalFaceArea sums
// BRepGProp::SurfaceProperties(face, props, eps) per face (OCCTFaceGetArea).
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static double faceTotal(const TopoDS_Shape& s, double eps)
{
  double total = 0;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    GProp_GProps p;
    BRepGProp::SurfaceProperties(TopoDS::Face(ex.Current()), p, eps);
    total += p.Mass();
  }
  return total;
}

int main()
{
  {
    TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(10).Shape();
    GProp_GProps agg;
    BRepGProp::SurfaceProperties(sphere, agg);
    printf("#885 aggregate SurfaceProperties(shape)=%.17g (4*pi*100=%.17g)\n", agg.Mass(), 4 * M_PI * 100);
    double d = faceTotal(sphere, 1e-6), l = faceTotal(sphere, 0.5), t = faceTotal(sphere, 1e-9);
    printf("#885 per-face total eps=1e-6: %.17g (|diff| %.3g)\n", d, std::fabs(d - agg.Mass()));
    printf("#885 per-face total eps=0.5: %.17g (|diff| %.17g)\n", l, std::fabs(l - agg.Mass()));
    printf("#885 per-face total eps=1e-9: %.17g (tight != loose: %d)\n", t, t != l);
  }
  return 0;
}
