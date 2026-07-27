// OCCTSwift#430/#432 reproducer, part 2 of 3: the uncatchable SIGSEGV.
//
// Adds a curved boundary edge through BRepFill_Filling's FACE-LESS
// Add(edge, order) overload with GeomAbs_G1. This is the exact call the bridge
// makes from OCCTFillingAddEdge (OCCTBridge_Modeling.mm), which backs
// FillingSurface.add(edge:continuity:) and is still live after PR #435 (#432).
//
// Expected on stock OCCT 8.0.0p1: SIGSEGV inside Plate_Plate::UVBox, reached
// from the GeomPlate_MakeApprox constructor in
// GeomPlate_BuildPlateSurface::Perform's projection-failure recovery branch.
// The signal is raised inside OCCT, so the bridge's catch(...) cannot save it.
//
// Build:
//   clang++ -std=c++17 -w -g -O0 \
//     -I Libraries/OCCT.xcframework/macos-arm64/Headers \
//     -L Libraries/OCCT.xcframework/macos-arm64 \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/430-fill-untrimmed-pcurve/occt_432_curved_sigsegv.cpp \
//     -o /tmp/occt_432_curved

#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Curve.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>

#include <cmath>
#include <csignal>
#include <cstdio>
#include <execinfo.h>
#include <unistd.h>

static void onFatal(int sig)
{
  const char* name = (sig == SIGSEGV) ? "SIGSEGV" : (sig == SIGBUS ? "SIGBUS" : "?");
  fprintf(stderr, "\n*** CRASH: %s, uncatchable, kills the host process ***\n", name);
  void* frames[64];
  int   n = backtrace(frames, 64);
  backtrace_symbols_fd(frames, n, STDERR_FILENO);
  _exit(sig);
}

// The rim of a truncated sphere: the closed edge with the greatest z.
// Same fixture as FillingSupportFaceTests.bowl() in OCCTSurfaceTests.
static TopoDS_Edge rimOfTruncatedSphere(const TopoDS_Shape& bowl, double& outZ)
{
  TopoDS_Edge rim;
  double      bestZ = -1e100;
  for (TopExp_Explorer e(bowl, TopAbs_EDGE); e.More(); e.Next())
  {
    TopoDS_Edge        edge = TopoDS::Edge(e.Current());
    double             f, l;
    Handle(Geom_Curve) c = BRep_Tool::Curve(edge, f, l);
    if (c.IsNull())
      continue;
    if (c->Value(f).Distance(c->Value(l)) > 1e-7)
      continue; // not a closed edge
    if (c->Value(f).Z() > bestZ)
    {
      bestZ = c->Value(f).Z();
      rim   = edge;
    }
  }
  outZ = bestZ;
  return rim;
}

int main()
{
  signal(SIGSEGV, onFatal);
  signal(SIGBUS, onFatal);

  TopoDS_Shape bowl =
    BRepPrimAPI_MakeSphere(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10.0, -M_PI / 2.0,
                           50.0 * M_PI / 180.0)
      .Shape();

  double      rimZ = 0.0;
  TopoDS_Edge rim  = rimOfTruncatedSphere(bowl, rimZ);
  if (rim.IsNull())
  {
    printf("FIXTURE FAIL: no closed rim edge found\n");
    return 2;
  }
  printf("Rim edge found at z = %.4f\n", rimZ);
  printf("Calling the face-less Add(edge, GeomAbs_G1), the path FillingSurface still uses...\n");
  fflush(stdout);

  try
  {
    BRepOffsetAPI_MakeFilling filling;
    filling.Add(rim, GeomAbs_G1, true);
    filling.Build();
    printf("RESULT: Build() returned, IsDone=%d\n", filling.IsDone() ? 1 : 0);
  }
  catch (Standard_Failure const& f)
  {
    printf("RESULT: threw Standard_Failure(\"%s\"), catchable\n",
           f.GetMessageString() ? f.GetMessageString() : "?");
  }
  catch (...)
  {
    printf("RESULT: threw an unknown exception, catchable\n");
  }

  printf("Process survived.\n");
  return 0;
}
