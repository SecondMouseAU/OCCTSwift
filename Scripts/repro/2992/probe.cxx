// Override-link probe for patches 0050/0051: GProp_SelGProps / GProp_VelGProps on gp_Cone.
#include <GProp_SelGProps.hxx>
#include <GProp_VelGProps.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  const double a = M_PI / 6.0, R = 5.0, Z1 = 0.0, Z2 = 10.0;
  const double A1 = 0.0, A2 = 2.0 * M_PI;

  gp_Cone     cone(gp_Ax3(gp::XOY()), a, R);
  gp_Cylinder cyl(gp_Ax3(gp::XOY()), R);

  GProp_SelGProps sel;
  sel.Perform(cone, A1, A2, Z1, Z2);
  GProp_VelGProps vel;
  vel.Perform(cone, A1, A2, Z1, Z2);

  const double areaTrue = A2 * (Z2 - Z1) * (R + (Z2 + Z1) * std::sin(a) / 2.0);
  const double H        = (Z2 - Z1) * std::cos(a);
  const double R1 = R + Z1 * std::sin(a), R2 = R + Z2 * std::sin(a);
  const double volTrue = M_PI * H / 3.0 * (R1 * R1 + R1 * R2 + R2 * R2);

  std::printf("cone area    = %.17g   closed form = %.17g   delta = %.3g\n",
              sel.Mass(),
              areaTrue,
              std::abs(sel.Mass() - areaTrue));
  std::printf("cone volume  = %.17g   frustum     = %.17g   delta = %.3g\n",
              vel.Mass(),
              volTrue,
              std::abs(vel.Mass() - volTrue));

  gp_Pnt gc = sel.CentreOfMass();
  std::printf("cone area centroid = (%.12g, %.12g, %.12g)\n", gc.X(), gc.Y(), gc.Z());

  // Cylinder limit: gp_Cone refuses semiAngle 0, so approach it.
  GProp_SelGProps selCyl;
  selCyl.Perform(cyl, A1, A2, Z1, Z2);
  GProp_VelGProps velCyl;
  velCyl.Perform(cyl, A1, A2, Z1, Z2);
  std::printf("cylinder r=5 h=10: area = %.17g  volume = %.17g\n", selCyl.Mass(), velCyl.Mass());

  for (double sa : {1e-3, 1e-6, 1e-9})
  {
    gp_Cone         thin(gp_Ax3(gp::XOY()), sa, R);
    GProp_SelGProps s2;
    s2.Perform(thin, A1, A2, Z1, Z2);
    GProp_VelGProps v2;
    v2.Perform(thin, A1, A2, Z1, Z2);
    std::printf("cone semiAngle=%-6g area = %.11f  volume = %.11f\n", sa, s2.Mass(), v2.Mass());
  }
  return 0;
}
