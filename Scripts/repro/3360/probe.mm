// #3360: BRepBuilderAPI_MakeShell on an infinite Geom_CylindricalSurface.
// Prints Bounds, then builds the shell with a SIGSEGV/SIGBUS handler that dumps a backtrace.
//
//   A=.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -g -I"$A/Headers" -L"$A" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ Scripts/repro/3360/probe.mm -o probe
//   ./probe cyl | cone | plane | sphere
#include <execinfo.h>
#include <signal.h>
#include <unistd.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include <BRepBuilderAPI_MakeShell.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pnt.hxx>
#include <gp_Dir.hxx>
#include <Standard_Failure.hxx>

static void onSignal(int sig)
{
  void* frames[48];
  int   n = backtrace(frames, 48);
  fprintf(stderr, "SIGNAL %d, backtrace:\n", sig);
  backtrace_symbols_fd(frames, n, 2);
  _exit(139);
}

int main(int argc, char** argv)
{
  signal(SIGSEGV, onSignal);
  signal(SIGBUS, onSignal);
  signal(SIGABRT, onSignal);
  const char*               which = argc > 1 ? argv[1] : "cyl";
  occ::handle<Geom_Surface> s;
  gp_Ax3                    ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  if (!strcmp(which, "cyl"))
    s = new Geom_CylindricalSurface(ax, 3.0);
  else if (!strcmp(which, "cone"))
    s = new Geom_ConicalSurface(ax, 0.3, 1.0);
  else if (!strcmp(which, "plane"))
    s = new Geom_Plane(ax);
  else
    s = new Geom_SphericalSurface(ax, 5.0);
  double u0, u1, v0, v1;
  s->Bounds(u0, u1, v0, v1);
  printf("%s bounds u[%g, %g] v[%g, %g]\n", which, u0, u1, v0, v1);
  fflush(stdout);
  try
  {
    BRepBuilderAPI_MakeShell mk(s);
    printf("IsDone=%d\n", (int)mk.IsDone());
  }
  catch (Standard_Failure const& e)
  {
    printf("Standard_Failure %s\n", e.GetMessageString());
  }
  return 0;
}
