// Kernel parity probe for Tests/OCCTAnalysisTests/ExtremaExtPElSPlaneTests.swift (#766).
//
// The same Extrema_ExtPElS(gp_Pnt, gp_Pln, tolerance) that OCCTExtremaExtPElSPlane builds,
// with the test's inputs.
#include <Extrema_ExtPElS.hxx>
#include <Extrema_POnSurf.hxx>
#include <gp_Pln.hxx>
#include <cstdio>

int main()
{
  Extrema_ExtPElS ext(gp_Pnt(0, 0, 10), gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 1e-6);
  printf("pointToPlane: IsDone=%d", ext.IsDone());
  if (!ext.IsDone())
  {
    printf("\n");
    return 0;
  }
  printf(" NbExt=%d\n", ext.NbExt());
  for (int i = 1; i <= ext.NbExt(); i++)
  {
    gp_Pnt p = ext.Point(i).Value();
    printf("  [%d] squareDistance=%.17g point=(%.17g, %.17g, %.17g)\n", i, ext.SquareDistance(i),
           p.X(), p.Y(), p.Z());
  }
  return 0;
}
