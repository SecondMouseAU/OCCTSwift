// Epic #766 kernel-parity probe for Tests/OCCTMathTests/GpDirExtrasTests.swift and
// GpVecExtrasTests.swift. Same gp_Dir / gp_Vec calls and inputs as OCCTDirIsOpposite,
// OCCTDirIsNormal, OCCTVecCrossMagnitude and OCCTVecCrossSquareMagnitude.
#include <gp_Dir.hxx>
#include <gp_Vec.hxx>
#include <cstdio>

int main()
{
  printf("isOpposite: %d\n", gp_Dir(1, 0, 0).IsOpposite(gp_Dir(-1, 0, 0), 0.01) ? 1 : 0);
  printf("isNotOpposite: %d\n", gp_Dir(1, 0, 0).IsOpposite(gp_Dir(0, 1, 0), 0.01) ? 1 : 0);
  printf("isNormal: %d\n", gp_Dir(1, 0, 0).IsNormal(gp_Dir(0, 1, 0), 0.01) ? 1 : 0);
  printf("isNotNormal: %d\n", gp_Dir(1, 0, 0).IsNormal(gp_Dir(1, 0, 0), 0.01) ? 1 : 0);
  printf("isNormalDiagonal: %d\n", gp_Dir(1, 1, 0).IsNormal(gp_Dir(1, -1, 0), 0.01) ? 1 : 0);
  printf("crossMagnitude: %.10g\n", gp_Vec(1, 0, 0).CrossMagnitude(gp_Vec(0, 1, 0)));
  printf("crossMagnitudeParallel: %.10g\n", gp_Vec(1, 0, 0).CrossMagnitude(gp_Vec(2, 0, 0)));
  printf("crossSquareMagnitude: %.10g\n", gp_Vec(1, 0, 0).CrossSquareMagnitude(gp_Vec(0, 1, 0)));
  printf("crossMagnitudeScaled: %.10g\n", gp_Vec(3, 0, 0).CrossMagnitude(gp_Vec(0, 4, 0)));
  return 0;
}
