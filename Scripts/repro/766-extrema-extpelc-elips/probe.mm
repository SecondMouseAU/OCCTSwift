// Kernel parity probe for Tests/OCCTAnalysisTests/ExtremaExtPElCElipsTests.swift (#1767).
// Mirrors OCCTExtremaExtPElCElips: Extrema_ExtPElC(point, gp_Elips, tol, 0, 2 pi) for the point
// (10, 0, 0) and the ellipse a = 5, b = 3 centred at the origin in the XY plane.
#include <Extrema_ExtPElC.hxx>
#include <Extrema_POnCurv.hxx>
#include <gp_Ax2.hxx>
#include <gp_Elips.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  gp_Elips        e(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0)), 5, 3);
  Extrema_ExtPElC ext(gp_Pnt(10, 0, 0), e, 1e-6, 0, 2 * M_PI);
  printf("IsDone=%d NbExt=%d\n", (int)ext.IsDone(), ext.NbExt());
  for (int i = 1; i <= ext.NbExt(); ++i)
  {
    gp_Pnt p = ext.Point(i).Value();
    printf("  [%d] squareDistance=%.12g point=(%.12g, %.12g, %.12g) param=%.12g\n", i,
           ext.SquareDistance(i), p.X(), p.Y(), p.Z(), ext.Point(i).Parameter());
  }
  return 0;
}
