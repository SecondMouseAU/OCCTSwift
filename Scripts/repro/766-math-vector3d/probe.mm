// Epic #766 kernel-parity probe for Vector3DMathTests.swift. Same OCCT calls, same inputs, as
// OCCTXYZModulus, OCCTXYZCrossed, OCCTXYZDot, OCCTXYZDotCross and OCCTXYZNormalize
// (Sources/OCCTBridge/src/OCCTBridge_Spatial_GeometryUtils.mm).
#include <gp_XYZ.hxx>
#include <cstdio>

int main()
{
  printf("modulus (1,2,2): %.17g\n", gp_XYZ(1, 2, 2).Modulus());
  gp_XYZ c = gp_XYZ(1, 0, 0).Crossed(gp_XYZ(0, 1, 0));
  printf("cross (1,0,0)x(0,1,0): (%.17g, %.17g, %.17g)\n", c.X(), c.Y(), c.Z());
  printf("dot (1,2,3).(4,5,6): %.17g\n", gp_XYZ(1, 2, 3).Dot(gp_XYZ(4, 5, 6)));
  printf("dotCross (1,0,0).((0,1,0)x(0,0,1)): %.17g\n",
         gp_XYZ(1, 0, 0).DotCross(gp_XYZ(0, 1, 0), gp_XYZ(0, 0, 1)));
  gp_XYZ n = gp_XYZ(1, 2, 2).Normalized();
  printf("normalize (1,2,2): (%.17g, %.17g, %.17g) modulus %.17g\n", n.X(), n.Y(), n.Z(),
         n.Modulus());
  return 0;
}
