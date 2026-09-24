// Kernel parity probe for Tests/OCCTAnalysisTests/GPropTorusTests.swift (#1791, #1792).
// Mirrors OCCTGPropTorusSurface / OCCTGPropTorusVolume: a gp_Torus (R = 10, r = 3) at the origin,
// integrated over u, v in [0, 2 pi] by GProp_SelGProps (area) and GProp_VelGProps (volume).
#include <GProp_SelGProps.hxx>
#include <GProp_VelGProps.hxx>
#include <gp_Ax3.hxx>
#include <gp_Torus.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  gp_Torus        torus(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10, 3);
  GProp_SelGProps s(torus, 0, 2 * M_PI, 0, 2 * M_PI, gp_Pnt(0, 0, 0));
  GProp_VelGProps v(torus, 0, 2 * M_PI, 0, 2 * M_PI, gp_Pnt(0, 0, 0));
  double          area = 4 * M_PI * M_PI * 10 * 3, vol = 2 * M_PI * M_PI * 10 * 3 * 3;
  printf("torusSurfaceArea: GProp_SelGProps=%.12f closed form 4 pi^2 R r=%.12f diff=%.3g\n",
         s.Mass(), area, s.Mass() - area);
  printf("torusVolume: GProp_VelGProps=%.12f closed form 2 pi^2 R r^2=%.12f diff=%.3g\n", v.Mass(),
         vol, v.Mass() - vol);
  return 0;
}
