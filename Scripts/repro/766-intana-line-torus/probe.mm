// Epic #766, IntAnaLineTorusTests.swift: kernel parity for lineThroughTorus.
// IntAna_IntLinTorus(gp_Lin, gp_Torus), what OCCTIntAnaLineTorus constructs, with the test's inputs:
// the x axis against a torus centred on the origin, axis z, R = 20, r = 5.
#include <IntAna_IntLinTorus.hxx>
#include <cstdio>
#include <gp_Ax3.hxx>
#include <gp_Lin.hxx>
#include <gp_Torus.hxx>

int main()
{
  gp_Lin             line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  gp_Torus           torus(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 20, 5);
  IntAna_IntLinTorus inter(line, torus);
  printf("lineThroughTorus: done=%d nbPoints=%d\n", inter.IsDone(), inter.NbPoints());
  for (int i = 1; i <= inter.NbPoints(); ++i)
  {
    gp_Pnt p = inter.Value(i);
    printf("  [%d] (%.17g, %.17g, %.17g)\n", i - 1, p.X(), p.Y(), p.Z());
  }
  return 0;
}
