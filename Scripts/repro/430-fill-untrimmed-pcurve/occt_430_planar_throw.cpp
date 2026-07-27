// OCCTSwift#430/#432 reproducer, part 1 of 3: the non-fatal face of the same defect.
//
// Same face-less BRepFill_Filling::Add(edge, GeomAbs_G1) call as part 2, but on
// PLANAR boundary edges (a box face's wire). This is the geometry the documented
// FillingSurface recipe in docs/reference/GeometrySolvers.md uses.
//
// Expected on stock OCCT 8.0.0p1: a catchable Standard_Failure,
// "Geom_RectangularTrimmedSurface::U parameters out of range". That message IS
// the untrimmed-pcurve defect surfacing: BRepFill_Filling::AddConstraints fetches
// the edge's [f, l] range and then builds Geom2dAdaptor_Curve(C2d) without it, so
// a Geom2d_Line pcurve spans +/-2e100 instead of the edge's own range.
//
// The point of keeping this alongside part 2: the same public API call is a silent
// nil on planar input and a process kill on curved input. Testing only planar
// geometry hides the crash entirely.
//
// Build:
//   clang++ -std=c++17 -w -g -O0 \
//     -I Libraries/OCCT.xcframework/macos-arm64/Headers \
//     -L Libraries/OCCT.xcframework/macos-arm64 \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/430-fill-untrimmed-pcurve/occt_430_planar_throw.cpp \
//     -o /tmp/occt_430_planar

#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>

#include <csignal>
#include <cstdio>
#include <execinfo.h>
#include <unistd.h>

static void onFatal(int sig)
{
  fprintf(stderr, "\n*** CRASH: signal %d ***\n", sig);
  void* frames[64];
  int   n = backtrace(frames, 64);
  backtrace_symbols_fd(frames, n, STDERR_FILENO);
  _exit(sig);
}

int main()
{
  signal(SIGSEGV, onFatal);
  signal(SIGBUS, onFatal);

  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();

  TopExp_Explorer faceExp(box, TopAbs_FACE);
  TopoDS_Face     face = TopoDS::Face(faceExp.Current());

  printf("Adding the 4 edges of one box face with GeomAbs_G1 (FillingContinuity.c1)...\n");
  fflush(stdout);

  try
  {
    BRepOffsetAPI_MakeFilling filling; // FillingSurface()'s defaults
    int                       added = 0;
    for (TopExp_Explorer e(face, TopAbs_EDGE); e.More(); e.Next())
    {
      filling.Add(TopoDS::Edge(e.Current()), GeomAbs_G1, true);
      added++;
    }
    printf("  added %d edge constraints, calling Build()...\n", added);
    fflush(stdout);

    filling.Build();
    printf("RESULT: Build() returned, IsDone=%d\n", filling.IsDone() ? 1 : 0);
  }
  catch (Standard_Failure const& f)
  {
    printf("RESULT: threw Standard_Failure(\"%s\"), catchable, so a clean nil\n",
           f.GetMessageString() ? f.GetMessageString() : "?");
  }
  catch (...)
  {
    printf("RESULT: threw an unknown exception, catchable\n");
  }

  printf("Process survived.\n");
  return 0;
}
