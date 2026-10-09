// #766 kernel parity for Tests/OCCTAnalysisTests/MassProperties/GPropCylConeTests.swift.
// Same construction as OCCTGPropCylinderSurface / CylinderVolume / ConeSurface / ConeVolume
// (OCCTBridge_Properties.mm).
//
// The cone half of this probe is also the evidence for the two kernel defects the tests pin
// around: GProp_SelGProps::Perform(gp_Cone) returns cos(semiAngle) times the lateral area, and
// GProp_VelGProps::Perform(gp_Cone) returns a quantity that does not reduce to the cylinder as
// the semi-angle goes to zero. Both are checked below against closed forms and against the
// cylinder limit, which is the case where the right answer is not in dispute.
#include <GProp_SelGProps.hxx>
#include <GProp_VelGProps.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <Standard_Failure.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  gp_Ax3 ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));

  gp_Cylinder     cyl(ax, 5);
  GProp_SelGProps cs(cyl, 0, 2 * M_PI, 0, 10, gp_Pnt(0, 0, 0));
  GProp_VelGProps cv(cyl, 0, 2 * M_PI, 0, 10, gp_Pnt(0, 0, 0));
  printf("cylinderSurfaceArea(r=5, h=10): %.17g  (2*pi*5*10 = %.17g)\n",
         cs.Mass(),
         2 * M_PI * 5 * 10);
  printf("cylinderVolume(r=5, h=10): %.17g  (pi*25*10 = %.17g)\n", cv.Mass(), M_PI * 25 * 10);

  // The v range of gp_Cone runs along the generatrix, so "height" 10 is a slant length.
  gp_Cone         cone(ax, M_PI / 6, 5);
  GProp_SelGProps ks(cone, 0, 2 * M_PI, 0, 10, gp_Pnt(0, 0, 0));
  GProp_VelGProps kv(cone, 0, 2 * M_PI, 0, 10, gp_Pnt(0, 0, 0));
  double          a = M_PI / 6, R = 5, L = 10;
  printf("coneSurfaceArea(semiAngle=pi/6, refRadius=5, height=10): %.17g\n", ks.Mass());
  double trueArea = 2 * M_PI * (R * L + L * L * sin(a) / 2);
  printf("  closed form, v as slant length: 2*pi*(R*L + L^2*sin(a)/2) = %.17g\n", trueArea);
  printf("  kernel / closed form = %.17g   cos(a) = %.17g\n", ks.Mass() / trueArea, cos(a));
  printf("coneVolume(semiAngle=pi/6, refRadius=5, height=10): %.17g\n", kv.Mass());
  double h = L * cos(a), R2 = R + L * sin(a);
  double trueVol = M_PI * h / 3 * (R * R + R * R2 + R2 * R2);
  printf("  closed form, frustum of axial height L*cos(a): pi*h/3*(R^2+R*R2+R2^2) = %.17g\n",
         trueVol);

  // The cylinder limit. A cone of semi-angle a -> 0 IS the cylinder of radius R and height L,
  // and both GProp_SelGProps and GProp_VelGProps answer the cylinder correctly, so this is the
  // case that says which of the two cone formulas is wrong rather than merely different.
  for (int i = 0; i < 3; i++)
  {
    double t = (i == 0) ? 1e-3 : (i == 1) ? 1e-6 : 0.0;
    try
    {
      gp_Cone         c2(ax, t, R);
      GProp_SelGProps s2(c2, 0, 2 * M_PI, 0, L, gp_Pnt(0, 0, 0));
      GProp_VelGProps v2(c2, 0, 2 * M_PI, 0, L, gp_Pnt(0, 0, 0));
      printf("cone semiAngle=%.17g: area=%.17g volume=%.17g  (cylinder: area=%.17g volume=%.17g)\n",
             t,
             s2.Mass(),
             v2.Mass(),
             cs.Mass(),
             cv.Mass());
    }
    catch (const Standard_Failure& e)
    {
      printf("cone semiAngle=%.17g: %s\n", t, e.GetMessageString());
    }
  }
  return 0;
}
