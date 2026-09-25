// Kernel-parity probe for Tests/OCCTAnalysisTests/ExtremaElCSLinSphereTests.swift (#766
// execution, issue #1810). Mirrors OCCTExtremaElCSLinSphere: Extrema_ExtElCS(gp_Lin, gp_Sphere)
// with the sphere built on gp_Ax3(center, +Z).

#include <Extrema_ExtElCS.hxx>
#include <Extrema_POnCurv.hxx>
#include <Extrema_POnSurf.hxx>
#include <gp_Lin.hxx>
#include <gp_Sphere.hxx>
#include <gp_Ax3.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  gp_Lin          l(gp_Pnt(0, 0, 20), gp_Dir(1, 0, 0));
  gp_Sphere       sp(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  Extrema_ExtElCS ext(l, sp);
  printf("lineSphereDistance: isDone=%d", (int)ext.IsDone());
  if (!ext.IsDone())
  {
    printf("\n");
    return 0;
  }
  printf(" nbExt=%d\n", ext.NbExt());
  for (int i = 1; i <= ext.NbExt(); ++i)
  {
    Extrema_POnCurv pc;
    Extrema_POnSurf ps;
    ext.Points(i, pc, ps);
    printf("  [%d] sqDist=%.12f dist=%.12f p1=(%.9g, %.9g, %.9g) p2=(%.9g, %.9g, %.9g)\n",
           i, ext.SquareDistance(i), std::sqrt(ext.SquareDistance(i)),
           pc.Value().X(), pc.Value().Y(), pc.Value().Z(),
           ps.Value().X(), ps.Value().Y(), ps.Value().Z());
  }
  return 0;
}
