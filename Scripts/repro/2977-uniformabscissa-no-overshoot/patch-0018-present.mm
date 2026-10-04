// #2977: is carried patch `0018` in the pinned kernel?
//
// `check-pinned-asset-patches.py` reports `0018` as NOT DERIVABLE: it adds no header line, no
// string literal, no `thread_local` wrapper and no new name, so there is no symbol to look for.
// Its other half is observable at runtime, which is what this probe reads.
//
// `0018` replaces `GCPnts_QuasiUniformAbscissa::initialize`'s
// `Standard_ConstructionError_Raise_if(theNbPoints <= 1, ...)`, which the Release kernel compiles
// out under `No_Exception` (#487), with an explicit `myDone = false; myNbPoints = 0; return;`.
// `Scripts/repro/501-quasiuniform-buffer-overflow/README.md` recorded the UNPATCHED behaviour for
// `nbPoints == 0`:
//
//   | curve                       | GCPnts_QuasiUniformAbscissa |
//   | line, circle                | IsDone(), 1 point           |
//   | ellipse                     | IsDone(), 5 points          |
//   | 4-pole Bezier               | SIGSEGV                     |
//   | all-coincident-pole Bezier  | SIGSEGV                     |
//
// So "not done, 0 points" on the ellipse, and a Bezier that returns at all, is the patch. The
// Bezier case is last and every line is flushed, because without the patch it takes the process
// down and the output up to that point is the evidence.
//
//   XC=.build/artifacts/<pkg>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/Headers" -L"$XC" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2977-uniformabscissa-no-overshoot/patch-0018-present.mm -o /tmp/probe_0018

#include <GCPnts_QuasiUniformAbscissa.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <gp_Elips2d.hxx>

#include <cstdio>

static void report(const char* label, const Geom2dAdaptor_Curve& a, int nbPoints)
{
  GCPnts_QuasiUniformAbscissa q(a, nbPoints);
  printf("  %-34s nbPoints=%d -> IsDone=%d NbPoints=%d\n",
         label,
         nbPoints,
         (int)q.IsDone(),
         q.IsDone() ? q.NbPoints() : -1);
  fflush(stdout);
}

int main()
{
  printf("GCPnts_QuasiUniformAbscissa at a degenerate count, pinned kernel.\n");
  printf("Patched (0018): not done, 0 points, and no crash on a Bezier.\n");
  printf("Unpatched: IsDone with 1 point on a circle, 5 on an ellipse, SIGSEGV on a Bezier.\n\n");
  fflush(stdout);

  {
    Handle(Geom2d_Circle) c = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Geom2dAdaptor_Curve   a(c);
    report("circle r=5", a, 0);
    report("circle r=5", a, 1);
  }
  {
    Handle(Geom2d_Ellipse) e =
      new Geom2d_Ellipse(gp_Elips2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10, 5));
    Geom2dAdaptor_Curve a(e);
    report("ellipse 10 x 5", a, 0);
  }
  printf("  (the Bezier is next; no further output means the kernel lacks 0018)\n");
  fflush(stdout);
  {
    TColgp_Array1OfPnt2d poles(1, 4);
    poles.SetValue(1, gp_Pnt2d(0, 0));
    poles.SetValue(2, gp_Pnt2d(1, 2));
    poles.SetValue(3, gp_Pnt2d(3, 2));
    poles.SetValue(4, gp_Pnt2d(4, 0));
    Handle(Geom2d_BezierCurve) b = new Geom2d_BezierCurve(poles);
    Geom2dAdaptor_Curve        a(b);
    report("4-pole Bezier", a, 0);
  }
  printf("\nSurvived. 0018 is in the pinned kernel.\n");
  fflush(stdout);
  return 0;
}
