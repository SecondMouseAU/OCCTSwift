// #766 kernel parity for Tests/OCCTAnalysisTests/GPropCylConeTests.swift.
// Same construction as OCCTGPropCylinderSurface / CylinderVolume / ConeSurface / ConeVolume
// (OCCTBridge_Properties.mm).
#include <GProp_SelGProps.hxx>
#include <GProp_VelGProps.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  gp_Ax3 ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

  gp_Cylinder     cyl(ax, 5);
  GProp_SelGProps cs(cyl, 0, 2 * M_PI, 0, 10, gp_Pnt(0, 0, 0));
  GProp_VelGProps cv(cyl, 0, 2 * M_PI, 0, 10, gp_Pnt(0, 0, 0));
  printf("cylinderSurfaceArea(r=5, h=10): %.17g  (2*pi*5*10 = %.17g)\n", cs.Mass(), 2 * M_PI * 5 * 10);
  printf("cylinderVolume(r=5, h=10): %.17g  (pi*25*10 = %.17g)\n", cv.Mass(), M_PI * 25 * 10);

  // The v range of gp_Cone runs along the generatrix, so "height" 10 is a slant length.
  gp_Cone         cone(ax, M_PI / 6, 5);
  GProp_SelGProps ks(cone, 0, 2 * M_PI, 0, 10, gp_Pnt(0, 0, 0));
  GProp_VelGProps kv(cone, 0, 2 * M_PI, 0, 10, gp_Pnt(0, 0, 0));
  double          a = M_PI / 6, R = 5, L = 10;
  printf("coneSurfaceArea(semiAngle=pi/6, refRadius=5, height=10): %.17g\n", ks.Mass());
  printf("  closed form, v as slant length: 2*pi*(R*L + L^2*sin(a)/2) = %.17g\n",
         2 * M_PI * (R * L + L * L * sin(a) / 2));
  printf("coneVolume(semiAngle=pi/6, refRadius=5, height=10): %.17g\n", kv.Mass());
  double h = L * cos(a), R2 = R + L * sin(a);
  printf("  closed form, frustum of axial height L*cos(a): pi*h/3*(R^2+R*R2+R2^2) = %.17g\n",
         M_PI * h / 3 * (R * R + R * R2 + R2 * R2));
  return 0;
}
