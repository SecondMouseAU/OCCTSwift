// Epic #766 kernel-parity probe: PlaneGeometryTests. Same gp_Pln calls and inputs as
// OCCTPlaneDistanceToPoint, OCCTPlaneDistanceToLine and OCCTPlaneContainsPoint.
#include <gp_Pln.hxx>
#include <gp_Lin.hxx>
#include <gp_Pnt.hxx>
#include <gp_Dir.hxx>
#include <cstdio>

int main()
{
  gp_Pln pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  printf("distanceToPointOnPlane: %.17g\n", pln.Distance(gp_Pnt(5, 5, 0)));
  printf("distanceToPointAbovePlane: %.17g\n", pln.Distance(gp_Pnt(0, 0, 7)));
  printf("distanceToParallelLine: %.17g\n", pln.Distance(gp_Lin(gp_Pnt(0, 0, 5), gp_Dir(1, 0, 0))));
  printf("distanceToIntersectingLine: %.17g\n", pln.Distance(gp_Lin(gp_Pnt(0, 0, 5), gp_Dir(0, 0, 1))));
  printf("containsPointTrue: %d\n", (int)pln.Contains(gp_Pnt(100, 200, 0), 1e-7));
  printf("containsPointFalse: %d\n", (int)pln.Contains(gp_Pnt(0, 0, 1), 1e-7));
  return 0;
}
