// Epic #766, ExtremaExtPElCCircTests.swift: kernel parity for both tests.
// ExtremaPointCurve.pointToCircle reaches OCCTExtremaExtPElCCirc, which builds
// gp_Circ(gp_Ax2(centre, normal), r) and runs Extrema_ExtPElC(p, c, tol, 0, 2*pi).
#include <Extrema_ExtPElC.hxx>
#include <Extrema_POnCurv.hxx>
#include <cmath>
#include <cstdio>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>

static void run(const char* tag, gp_Pnt p)
{
  gp_Circ         c(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  Extrema_ExtPElC ext(p, c, 1e-6, 0, 2 * M_PI);
  printf("%s: point=(%g, %g, %g) done=%d nbExt=%d\n", tag, p.X(), p.Y(), p.Z(), ext.IsDone(),
         ext.IsDone() ? ext.NbExt() : -1);
  if (!ext.IsDone())
    return;
  for (int i = 1; i <= ext.NbExt(); i++)
  {
    gp_Pnt q = ext.Point(i).Value();
    printf("  [%d] squareDistance=%.17g isMin=%d point=(%.17g, %.17g, %.17g)\n", i,
           ext.SquareDistance(i), ext.IsMin(i), q.X(), q.Y(), q.Z());
  }
}

int main()
{
  run("pointToCircle", gp_Pnt(10, 0, 0));
  run("pointOnCircle", gp_Pnt(5, 0, 0));
  return 0;
}
