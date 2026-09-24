// Kernel-parity probe for Tests/OCCTAnalysisTests/ExtremaExtPElCCircTests.swift (#1704).
// The same Extrema_ExtPElC(p, gp_Circ(gp_Ax2(center, normal), r), tol, 0, 2*pi) that
// OCCTExtremaExtPElCCirc runs, for pointToCircle's inputs and for pointOnCircle's.
#include <Extrema_ExtPElC.hxx>
#include <Extrema_POnCurv.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <cmath>
#include <cstdio>

static void run(const char* tag, double px, double py, double pz)
{
  gp_Circ         c(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  Extrema_ExtPElC ext(gp_Pnt(px, py, pz), c, 1e-6, 0, 2 * M_PI);
  printf("%s: IsDone=%d NbExt=%d\n", tag, ext.IsDone(), ext.IsDone() ? ext.NbExt() : -1);
  for (int i = 1; ext.IsDone() && i <= ext.NbExt(); i++)
  {
    gp_Pnt q = ext.Point(i).Value();
    printf("  ext %d: SquareDistance=%.17g point=(%.17g, %.17g, %.17g) param=%.17g\n",
           i, ext.SquareDistance(i), q.X(), q.Y(), q.Z(), ext.Point(i).Parameter());
  }
}

int main()
{
  run("pointToCircle point=(10,0,0)", 10, 0, 0);
  run("pointOnCircle point=(5,0,0)", 5, 0, 0);
  return 0;
}
