// Kernel parity probe for Tests/OCCTAnalysisTests/ExtremaExtPElSConeTests.swift (#766).
//
// Same calls as OCCTExtremaExtPElSCone (OCCTBridge_Surface_Extrema.mm):
// gp_Cone(gp_Ax3(apex, axis), semiAngle, refRadius), Extrema_ExtPElS(p, cone, tolerance = 1e-6),
// IsDone, NbExt, SquareDistance(i), Point(i).Value().
//
// Note gp_Cone's location is the centre of the reference circle, not the apex: with
// refRadius = 5 and semiAngle = pi/4 the true apex sits at z = -5.
#include <Extrema_ExtPElS.hxx>
#include <Extrema_POnSurf.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cone.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  gp_Pnt          p(20, 0, 0);
  gp_Cone         cone(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 4, 5);
  gp_Pnt          apex = cone.Apex();
  Extrema_ExtPElS ext(p, cone, 1e-6);
  printf("pointToCone apex=(%.17g, %.17g, %.17g)\n", apex.X(), apex.Y(), apex.Z());
  printf("pointToCone isDone=%d nbExt=%d\n", (int)ext.IsDone(), ext.IsDone() ? ext.NbExt() : -1);
  for (int i = 1; ext.IsDone() && i <= ext.NbExt(); i++)
  {
    gp_Pnt q = ext.Point(i).Value();
    printf("pointToCone ext[%d] squareDistance=%.17g distance=%.17g point=(%.17g, %.17g, %.17g)\n",
           i - 1,
           ext.SquareDistance(i),
           std::sqrt(ext.SquareDistance(i)),
           q.X(),
           q.Y(),
           q.Z());
  }
  return 0;
}
