#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepOffsetAPI_MakeEvolved.hxx>
#include <gp_Circ.hxx>
#include <gp_Ax2.hxx>
#include <TopoDS.hxx>
#include <cstdio>
#include <cstdlib>
#include <csignal>
#include <execinfo.h>
#include <unistd.h>

static void onSegv(int)
{
  void* b[40];
  int   n = backtrace(b, 40);
  backtrace_symbols_fd(b, n, 2);
  _exit(139);
}

int main(int argc, char** argv)
{
  signal(SIGSEGV, onSegv);
  signal(SIGBUS, onSegv);
  double px   = argc > 1 ? atof(argv[1]) : 0;
  double py   = argc > 2 ? atof(argv[2]) : 0;
  bool   face = argc > 3 && atoi(argv[3]) == 1;
  double cx   = argc > 4 ? atof(argv[4]) : 0;
  double cy   = argc > 5 ? atof(argv[5]) : 0;
  int    mode = argc > 6 ? atoi(argv[6]) : 0;
  TopoDS_Wire spine =
    BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(gp_Circ(gp_Ax2(gp_Pnt(cx, cy, 0), gp::DZ()), 20.0)))
      .Wire();
  TopoDS_Shape sp = spine;
  if (face)
    sp = BRepBuilderAPI_MakeFace(spine, true).Face();
  double dx = argc > 7 ? atof(argv[7]) : 0, dy = argc > 8 ? atof(argv[8]) : 2,
         dz = argc > 9 ? atof(argv[9]) : 3;
  bool axeProf = argc > 10 && atoi(argv[10]) == 1;
  gp_Pnt c(px, py, 0), a(px + dx, py + dy, dz), b(px - dx, py - dy, dz);
  BRepBuilderAPI_MakeWire mw;
  if (mode == 0)
    mw.Add(BRepBuilderAPI_MakeEdge(c, a));
  else if (mode == 1)
    mw.Add(BRepBuilderAPI_MakeEdge(a, c));
  else
  {
    mw.Add(BRepBuilderAPI_MakeEdge(a, c));
    mw.Add(BRepBuilderAPI_MakeEdge(c, b));
  }
  TopoDS_Wire prof = mw.Wire();
  try
  {
    BRepOffsetAPI_MakeEvolved
      ev(sp, prof, GeomAbs_Arc, axeProf, false, false, 1e-4, false, false);
    printf("done=%d\n", (int)ev.IsDone());
  }
  catch (Standard_Failure const& e)
  {
    printf("caught %s\n", e.GetMessageString());
  }
  catch (...)
  {
    printf("caught unknown\n");
  }
  return 0;
}
