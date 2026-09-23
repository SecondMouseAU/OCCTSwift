// #766 kernel parity for Tests/OCCTAnalysisTests/InertiaPropertiesTests.swift.
// Mirrors OCCTShapeInertiaProperties (BRepGProp::VolumeProperties, OnlyClosed = true) and
// OCCTShapeSurfaceInertiaProperties (BRepGProp::SurfaceProperties) in OCCTBridge_Properties.mm,
// on the shapes OCCTShapeCreateBox (centred), OCCTShapeCreateSphere and OCCTShapeCreateCylinder
// build.
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <GProp_GProps.hxx>
#include <GProp_PrincipalProps.hxx>
#include <gp_Mat.hxx>
#include <cmath>
#include <cstdio>

static void dump(const char* name, const GProp_GProps& g)
{
  gp_Pnt cm = g.CentreOfMass();
  gp_Mat m  = g.MatrixOfInertia();
  printf("%s: mass=%.17g centre=(%.17g, %.17g, %.17g)\n", name, g.Mass(), cm.X(), cm.Y(), cm.Z());
  printf("  matrix diag=(%.17g, %.17g, %.17g) offdiag=(%.17g, %.17g, %.17g)\n", m(1, 1), m(2, 2),
         m(3, 3), m(1, 2), m(1, 3), m(2, 3));
  GProp_PrincipalProps pp = g.PrincipalProperties();
  double               ix, iy, iz;
  pp.Moments(ix, iy, iz);
  printf("  principal moments=(%.17g, %.17g, %.17g) symmetryAxis=%d symmetryPoint=%d\n", ix, iy,
         iz, (int)pp.HasSymmetryAxis(), (int)pp.HasSymmetryPoint());
}

int main()
{
  {
    TopoDS_Shape s = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
    GProp_GProps g;
    BRepGProp::VolumeProperties(s, g, true);
    dump("boxInertia (10x20x30)", g);
    printf("  analytic: m(b^2+c^2)/12=%.17g m(a^2+c^2)/12=%.17g m(a^2+b^2)/12=%.17g\n",
           6000.0 * (400 + 900) / 12, 6000.0 * (100 + 900) / 12, 6000.0 * (100 + 400) / 12);
  }
  {
    TopoDS_Shape s = BRepPrimAPI_MakeSphere(10).Shape();
    GProp_GProps g;
    BRepGProp::VolumeProperties(s, g, true);
    dump("sphereSymmetry (r=10)", g);
    printf("  analytic volume=%.17g\n", 4.0 / 3.0 * M_PI * 1000.0);
  }
  {
    TopoDS_Shape s = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    GProp_GProps g;
    BRepGProp::SurfaceProperties(s, g);
    dump("surfaceInertia (10x10x10 surface)", g);
  }
  {
    TopoDS_Shape s = BRepPrimAPI_MakeCylinder(5, 20).Shape();
    GProp_GProps g;
    BRepGProp::VolumeProperties(s, g, true);
    dump("cylinderPrincipal (r=5, h=20)", g);
    double m = M_PI * 25 * 20;
    printf("  analytic: mass=%.17g I_axis=m r^2/2=%.17g I_transverse(centroid)=m(3r^2+h^2)/12=%.17g\n",
           m, m * 25 / 2, m * (75 + 400) / 12);
  }
  return 0;
}
