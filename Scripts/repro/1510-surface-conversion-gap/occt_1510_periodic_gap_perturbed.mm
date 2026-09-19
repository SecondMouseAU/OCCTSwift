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
  gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
  Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(ax, 5.0);
  Handle(Geom_RectangularTrimmedSurface) trimmed =
      new Geom_RectangularTrimmedSurface(cyl, 0.0, 2.0 * M_PI, 0.0, 10.0, true, true);

  Handle(Geom_BSplineSurface) bsp = GeomConvert::SurfaceToBSplineSurface(trimmed);
  if (bsp->IsUPeriodic()) {
    bsp->SetUNotPeriodic();
  }
  printf("NbUPoles=%d NbVPoles=%d UMult(1)=%d UMult(last)=%d UDeg=%d\n",
         bsp->NbUPoles(), bsp->NbVPoles(), bsp->UMultiplicity(1),
         bsp->UMultiplicity(bsp->NbUKnots()), bsp->UDegree());

  // Perturb the LAST U-column of poles by a tiny epsilon, well within
  // Precision::Confusion() (~1e-7), so the surface is "closed enough" for
  // IsUClosed()/SetUPeriodic() to accept it, but not EXACTLY closed.
  double eps = 3.0e-8;
  for (int v = 1; v <= bsp->NbVPoles(); v++) {
    gp_Pnt p = bsp->Pole(bsp->NbUPoles(), v);
    bsp->SetPole(bsp->NbUPoles(), v, gp_Pnt(p.X() + eps, p.Y(), p.Z()));
  }

  Handle(Geom_Surface) original = bsp;
  double u1,u2,v1,v2; original->Bounds(u1,u2,v1,v2);
  gp_Pnt firstPole = bsp->Pole(1, 1);
  gp_Pnt lastPole = bsp->Pole(bsp->NbUPoles(), 1);
  printf("first pole vs last pole distance: %.3e\n", firstPole.Distance(lastPole));

  ShapeCustom_Surface sc(original);
  Handle(Geom_Surface) periodic = sc.ConvertToPeriodic(Standard_False);
  if (periodic.IsNull()) {
    printf("ConvertToPeriodic returned NULL (surface not accepted as closed)\n");
    return 1;
  }
  printf("Converted OK. sc.Gap() after (should be 0, no ConvertToAnalytical call) = %.3e\n", sc.Gap());

  int N = 40;
  double maxDev = 0.0, maxU=0, maxV=0;
  for (int i = 0; i <= N; i++) {
    double u = u1 + (u2 - u1) * i / N;
    for (int j = 0; j <= N; j++) {
      double v = v1 + (v2 - v1) * j / N;
      gp_Pnt p1 = original->Value(u, v);
      gp_Pnt p2 = periodic->Value(u, v);
      double d = p1.Distance(p2);
      if (d > maxDev) { maxDev = d; maxU=u; maxV=v; }
    }
  }
  printf("Max sampled deviation over full grid: %.6e at u=%.6f (u2=%.6f) v=%.6f\n", maxDev, maxU, u2, maxV);
  // sample precisely AT u2 (the original last-column parameter) since interior sampling
  // may not land exactly on the dropped knot
  double maxAtSeam = 0.0;
  for (int j = 0; j <= N; j++) {
    double v = v1 + (v2 - v1) * j / N;
    gp_Pnt p1 = original->Value(u2, v);
    gp_Pnt p2 = periodic->Value(u2, v);
    double d = p1.Distance(p2);
    if (d > maxAtSeam) maxAtSeam = d;
  }
  printf("Max deviation AT u=u2 exactly: %.6e (perturbation was %.3e)\n", maxAtSeam, eps);
  return 0;
}
