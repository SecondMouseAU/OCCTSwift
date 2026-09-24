// #766 kernel parity for Tests/OCCTAnalysisTests/ExtremaElCSLinCylTests.swift.
// Same construction as OCCTExtremaElCSLinCylinder (OCCTBridge_Curve3D_Extrema.mm). The parallel
// case is run in a child process because the bridge's comment records an uncatchable SIGSEGV for
// it on 8.0.0p1, and the probe has to report that rather than die of it.
#include <Extrema_ExtElCS.hxx>
#include <Extrema_POnCurv.hxx>
#include <Extrema_POnSurf.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Lin.hxx>
#include <cstdio>
#include <typeinfo>
#include <sys/wait.h>
#include <unistd.h>

static void run(const char* label, gp_Pnt lp, gp_Dir ld)
{
  gp_Lin          l(lp, ld);
  gp_Cylinder     cyl(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  Extrema_ExtElCS ext(l, cyl);
  printf("%s: IsDone=%d", label, ext.IsDone() ? 1 : 0);
  if (!ext.IsDone())
  {
    printf("\n");
    return;
  }
  printf(" IsParallel=%d", ext.IsParallel() ? 1 : 0);
  fflush(stdout);
  int n = ext.NbExt();
  printf(" NbExt=%d\n", n);
  for (int i = 1; i <= n; i++)
  {
    Extrema_POnCurv pc;
    Extrema_POnSurf ps;
    ext.Points(i, pc, ps);
    printf("  ext %d: SquareDistance=%.17g onLine=(%.17g, %.17g, %.17g) onCyl=(%.17g, %.17g, %.17g)\n",
           i, ext.SquareDistance(i), pc.Value().X(), pc.Value().Y(), pc.Value().Z(),
           ps.Value().X(), ps.Value().Y(), ps.Value().Z());
  }
  fflush(stdout);
}

int main()
{
  // The test's own geometry: a line parallel to the cylinder axis, 20 from it.
  fflush(stdout);
  pid_t pid = fork();
  if (pid == 0)
  {
    try
    {
      run("lineCylinderDistance parallel line (20,0,0)+t(0,0,1)", gp_Pnt(20, 0, 0), gp_Dir(0, 0, 1));
    }
    catch (Standard_Failure& e)
    {
      printf("  raised %s: %s\n", typeid(e).name(), e.what());
    }
    fflush(stdout);
    _exit(0);
  }
  int status = 0;
  waitpid(pid, &status, 0);
  if (WIFSIGNALED(status))
    printf("  child terminated by signal %d\n", WTERMSIG(status));

  // A perpendicular line 20 from the axis: the case with a single measurable answer.
  run("lineCylinderDistance perpendicular line (20,0,0)+t(0,1,0)", gp_Pnt(20, 0, 0), gp_Dir(0, 1, 0));
  return 0;
}
