// Epic #766, ExtremaElSSPlanePlaneTests.swift: kernel parity for the two tests #1878 and #1879
// cover (parallelPlanesReportTheSquareDistance, crossingPlanesReportNoDistance).
// Same inputs as the Swift tests, straight to Extrema_ExtElSS(gp_Pln, gp_Pln), which is what
// OCCTExtremaElSSPlanePlane constructs, and Extrema_ExtPElS::Perform(gp_Pnt, gp_Pln, tol), which is
// what OCCTExtremaExtPElSPlane runs for the second construction in the parallel test.
// Points() is never read on the plane/plane result: see OCCTExtremaElSSPlanePlane and #1632.
#include <Extrema_ExtElSS.hxx>
#include <Extrema_ExtPElS.hxx>
#include <cstdio>
#include <gp_Pln.hxx>

static void planes(const char* name, gp_Pln a, gp_Pln b)
{
  Extrema_ExtElSS e(a, b);
  printf("%s: done=%d parallel=%d nbExt=%d", name, e.IsDone(), e.IsParallel(),
         e.IsParallel() ? 1 : e.NbExt());
  if (e.IsParallel())
    printf(" squareDistance=%.17g", e.SquareDistance(1));
  printf("\n");
}

int main()
{
  planes("parallelPlanesReportTheSquareDistance",
         gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)),
         gp_Pln(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1)));

  Extrema_ExtPElS p;
  p.Perform(gp_Pnt(3, -7, 0), gp_Pln(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1)), 1e-6);
  printf("parallelPlanesReportTheSquareDistance (via Extrema_ExtPElS): done=%d nbExt=%d", p.IsDone(),
         p.NbExt());
  for (int i = 1; i <= p.NbExt(); ++i)
    printf(" squareDistance[%d]=%.17g", i, p.SquareDistance(i));
  printf("\n");

  planes("crossingPlanesReportNoDistance",
         gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)),
         gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)));
  return 0;
}
