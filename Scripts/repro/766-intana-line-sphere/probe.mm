// Kernel parity probe for Tests/OCCTAnalysisTests/IntAnaLineSphereTests.swift (#766).
//
// The same IntAna_IntConicQuad(gp_Lin, IntAna_Quadric(gp_Sphere)) that OCCTIntAnaLineSphere
// builds, with the tests' inputs.
#include <IntAna_IntConicQuad.hxx>
#include <IntAna_Quadric.hxx>
#include <gp_Lin.hxx>
#include <gp_Sphere.hxx>
#include <gp_Ax3.hxx>
#include <cstdio>

static void run(const char* name, gp_Pnt lo, gp_Dir ld)
{
  gp_Lin         line(lo, ld);
  IntAna_Quadric quad;
  quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5));
  IntAna_IntConicQuad inter(line, quad);
  printf("%s: IsDone=%d", name, inter.IsDone());
  if (!inter.IsDone())
  {
    printf("\n");
    return;
  }
  printf(" IsParallel=%d NbPoints=%d\n", inter.IsParallel(), inter.NbPoints());
  for (int i = 1; i <= inter.NbPoints(); i++)
  {
    gp_Pnt p = inter.Point(i);
    printf("  [%d] point=(%.17g, %.17g, %.17g) paramOnConic=%.17g\n", i, p.X(), p.Y(), p.Z(),
           inter.ParamOnConic(i));
  }
}

int main()
{
  run("lineThroughSphere", gp_Pnt(-10, 0, 0), gp_Dir(1, 0, 0));
  run("lineMissesSphere", gp_Pnt(0, 100, 0), gp_Dir(1, 0, 0));
  return 0;
}
