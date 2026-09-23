// Epic #766, Tests/OCCTAnalysisTests/ExtremaElCLinCircTests.swift: kernel parity probe.
// OCCTExtremaElCLinCirc builds Extrema_ExtElC(gp_Lin, gp_Circ(gp_Ax2(c, n), r), tol) and reports
// SquareDistance(i) with both points for each extremum, in the kernel's own order.
#include <Extrema_ExtElC.hxx>
#include <Extrema_POnCurv.hxx>
#include <gp_Circ.hxx>
#include <gp_Lin.hxx>
#include <cstdio>

static void run(const char* name, gp_Pnt lp, gp_Dir ld)
{
  gp_Lin         l(lp, ld);
  gp_Circ        c(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  Extrema_ExtElC ext(l, c, 1e-6);
  printf("%s IsDone=%d", name, ext.IsDone());
  if (!ext.IsDone())
  {
    printf("\n");
    return;
  }
  printf(" IsParallel=%d", ext.IsParallel());
  if (ext.IsParallel())
  {
    printf(" SquareDistance(1)=%.17g\n", ext.SquareDistance(1));
    return;
  }
  printf(" NbExt=%d\n", ext.NbExt());
  for (int i = 1; i <= ext.NbExt(); ++i)
  {
    Extrema_POnCurv p1, p2;
    ext.Points(i, p1, p2);
    printf("  [%d] SquareDistance=%.17g onLine=(%.17g, %.17g, %.17g) onCircle=(%.17g, %.17g, %.17g)\n",
           i, ext.SquareDistance(i),
           p1.Value().X(), p1.Value().Y(), p1.Value().Z(),
           p2.Value().X(), p2.Value().Y(), p2.Value().Z());
  }
}

int main()
{
  run("lineCircleDistance", gp_Pnt(0, 0, 10), gp_Dir(1, 0, 0));
  run("lineCircleCoplanar", gp_Pnt(10, 0, 0), gp_Dir(0, 1, 0));
  return 0;
}
