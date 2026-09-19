#include <ShapeCustom_Surface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <GeomConvert.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>
#include <cmath>

int main() {
  // Build a full 2*pi cylindrical surface, trimmed in V (the unbounded
  // direction) but full-period in U, then force-convert it to a clamped
  // (non-periodic) BSpline via GeomConvert, to get a U-closed, non-periodic
  // BSpline surface - exactly the shape ConvertToPeriodic is meant to consume.
  gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
  Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(ax, 5.0);
  Handle(Geom_RectangularTrimmedSurface) trimmed =
      new Geom_RectangularTrimmedSurface(cyl, 0.0, 2.0 * M_PI, 0.0, 10.0, true, true);

  Handle(Geom_BSplineSurface) bsp = GeomConvert::SurfaceToBSplineSurface(trimmed);
  if (bsp->IsUPeriodic()) {
    bsp->SetUNotPeriodic(); // force clamped (non-periodic) form so ConvertToPeriodic has work to do
  }
  printf("IsUPeriodic before: %d\n", bsp->IsUPeriodic());
  printf("IsVPeriodic before: %d\n", bsp->IsVPeriodic());
  printf("NbUPoles: %d NbVPoles: %d\n", bsp->NbUPoles(), bsp->NbVPoles());
  printf("UMultiplicity(1)=%d UDegree=%d\n", bsp->UMultiplicity(1), bsp->UDegree());
  printf("UMultiplicity(last)=%d\n", bsp->UMultiplicity(bsp->NbUKnots()));

  Handle(Geom_Surface) original = bsp;

  ShapeCustom_Surface sc(original);
  Handle(Geom_Surface) periodic = sc.ConvertToPeriodic(Standard_False);
  if (periodic.IsNull()) {
    printf("ConvertToPeriodic returned NULL\n");
    return 1;
  }
  printf("Converted OK. Gap() immediately after = %.12f\n", sc.Gap());

  Handle(Geom_BSplineSurface) periodicBsp = Handle(Geom_BSplineSurface)::DownCast(periodic);
  printf("IsUPeriodic after: %d\n", periodicBsp->IsUPeriodic());

  // Sample both surfaces at a grid of matching (u,v) parameters within the
  // ORIGINAL surface's own parametric domain and measure max deviation.
  double u1, u2, v1, v2;
  original->Bounds(u1, u2, v1, v2);
  printf("Original bounds: u[%.6f,%.6f] v[%.6f,%.6f]\n", u1, u2, v1, v2);

  double pu1, pu2, pv1, pv2;
  periodic->Bounds(pu1, pu2, pv1, pv2);
  printf("Periodic bounds: u[%.6f,%.6f] v[%.6f,%.6f]\n", pu1, pu2, pv1, pv2);

  int N = 25;
  double maxDev = 0.0;
  double maxDevU = 0, maxDevV = 0;
  for (int i = 0; i <= N; i++) {
    double u = u1 + (u2 - u1) * i / N;
    for (int j = 0; j <= N; j++) {
      double v = v1 + (v2 - v1) * j / N;
      gp_Pnt p1 = original->Value(u, v);
      gp_Pnt p2 = periodic->Value(u, v);
      double d = p1.Distance(p2);
      if (d > maxDev) { maxDev = d; maxDevU = u; maxDevV = v; }
    }
  }
  printf("Max sampled deviation (25x25 grid over original bounds): %.12e at u=%.6f v=%.6f\n", maxDev, maxDevU, maxDevV);

  // Also try a much finer grid concentrated near the seam u1/u2
  double maxDevSeam = 0.0;
  for (int i = 0; i <= 200; i++) {
    double u = u2 - (u2 - u1) * 0.001 * i / 200.0; // last 0.1% near u2
    for (int j = 0; j <= 20; j++) {
      double v = v1 + (v2 - v1) * j / 20.0;
      gp_Pnt p1 = original->Value(u, v);
      gp_Pnt p2 = periodic->Value(u, v);
      double d = p1.Distance(p2);
      if (d > maxDevSeam) maxDevSeam = d;
    }
  }
  printf("Max sampled deviation near seam: %.12e\n", maxDevSeam);

  return 0;
}
