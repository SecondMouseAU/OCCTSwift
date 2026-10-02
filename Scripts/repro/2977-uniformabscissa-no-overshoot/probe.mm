// #2977: which GCPnts arc-length samplers still return more points than they were asked for?
//
// #501's bridge guards (occtSamplerKept / occtSamplerIndex) exist because
// GCPnts_UniformAbscissa::initialize sizes its own array at nbPoints + 5 and lets the walk fill it
// as far as it runs. `Curve2DTests.uniformDrawRespectsCount` pinned sixteen counts measured to
// overshoot on a 1e6 x 1e-3 ellipse. On the pinned kernel it reaches none of them.
//
// This probe settles whether that is "the 2D uniform path never overshot" or "the kernel moved":
// both samplers, 2D and 3D, over the test's own ellipse and its own sixteen counts, then over a
// sweep of counts, more ill-conditioned ellipses, and the Bezier branch that
// GCPnts_QuasiUniformAbscissa handles itself rather than forwarding to GCPnts_UniformAbscissa.
//
// Measured answer: the kernel moved, by our own carried patch `0018`, and it moved for both
// samplers and both dimensions alike. `0018` accepts a step within `theTol` of the end in 3D as
// well as within the parametric epsilon, which settles the 1e6 ellipse. It does not close the
// hole: a 1e8 or 1e10 major still overshoots, because the same relative shortfall is that much
// further in model space. Each row below therefore DECLARES whether it expects an overshoot, and
// the run fails if the pattern changes in either direction.
//
// A note on cost. On this kernel a single `GCPnts_UniformAbscissa` on the 1e6 x 1e-3 ellipse takes
// about 1.2 s, and about 2.9 s on the 1e6 x 1e-6 one, because carried patch `0021` made the CPnts
// arc-length integration adaptive. The sweeps below are sized against that, not against what the
// same sweeps cost when #501 measured them.
//
// Compile line (from the repo root; the xcframework is the SwiftPM-resolved one when the worktree
// has no Libraries/ of its own):
//
//   XC=.build/artifacts/<pkg>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/Headers" -L"$XC" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2977-uniformabscissa-no-overshoot/probe.mm -o /tmp/probe_2977
//
// Exit status is 1 if any row disagrees with its declared expectation, so the run is the
// assertion rather than a table somebody has to read.

#include <GCPnts_QuasiUniformAbscissa.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Line.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Ellipse.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <gp_Elips.hxx>
#include <gp_Elips2d.hxx>

#include <chrono>
#include <cstdio>
#include <string>
#include <vector>

static int gMismatches = 0;

template <class Adaptor>
static void measure(const char*            label,
                    const Adaptor&         a,
                    const std::vector<int>& counts,
                    bool                   expectOvershoot)
{
  std::string uniformOver, quasiOver;
  auto        t0 = std::chrono::steady_clock::now();
  for (int c : counts)
  {
    GCPnts_UniformAbscissa u(a, c);
    if (u.IsDone() && u.NbPoints() > c)
      uniformOver += " " + std::to_string(c) + "(+" + std::to_string(u.NbPoints() - c) + ")";
    GCPnts_QuasiUniformAbscissa q(a, c);
    if (q.IsDone() && q.NbPoints() > c)
      quasiOver += " " + std::to_string(c) + "(+" + std::to_string(q.NbPoints() - c) + ")";
  }
  auto       t1       = std::chrono::steady_clock::now();
  const bool agreesU  = uniformOver.empty() != expectOvershoot;
  const bool agreesQ  = quasiOver.empty() != expectOvershoot;
  printf("%-44s %-9s uniform: %-26s quasi: %-26s %s [%.0f s]\n",
         label,
         expectOvershoot ? "EXPECT +" : "expect 0",
         uniformOver.empty() ? "none" : uniformOver.c_str(),
         quasiOver.empty() ? "none" : quasiOver.c_str(),
         (agreesU && agreesQ) ? "ok" : "MISMATCH",
         std::chrono::duration<double>(t1 - t0).count());
  fflush(stdout);
  if (!agreesU)
    gMismatches++;
  if (!agreesQ)
    gMismatches++;
}

int main()
{
  // The sixteen counts Curve2DTests.uniformDrawRespectsCount walks, every one of which #501
  // measured to overshoot by exactly one.
  const std::vector<int> testCounts = {4, 5, 8, 12, 14, 18, 20, 22, 25, 26, 31, 33, 34, 35, 39, 40};
  std::vector<int>       sweep60;
  for (int i = 2; i <= 60; i++)
    sweep60.push_back(i);
  const std::vector<int> spot = {3, 7, 13, 19, 27, 41, 57, 100};

  printf("GCPnts overshoot on the pinned kernel. Listed counts are those where NbPoints() > "
         "request.\n");
  printf("%-44s %-9s %-35s %s\n",
         "curve",
         "declared",
         "GCPnts_UniformAbscissa",
         "GCPnts_QuasiUniformAbscissa");
  printf("%s\n", std::string(130, '-').c_str());
  fflush(stdout);

  // --- #501's own triggering geometry, 2D and 3D ---
  {
    gp_Ax2d                ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom2d_Ellipse) e = new Geom2d_Ellipse(gp_Elips2d(ax, 1e6, 1e-3));
    Geom2dAdaptor_Curve    a(e);
    measure("2D ellipse 1e6 x 1e-3, the test's 16 counts", a, testCounts, false);
    measure("2D ellipse 1e6 x 1e-3, counts 2..60", a, sweep60, false);
  }
  {
    gp_Ax2               ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Elips(ax, 1e6, 1e-3));
    GeomAdaptor_Curve    a(e);
    measure("3D ellipse 1e6 x 1e-3, the test's 16 counts", a, testCounts, false);
    measure("3D ellipse 1e6 x 1e-3, counts 2..60", a, sweep60, false);
  }

  // --- more ill-conditioned ellipses, in case the fix only moved the threshold ---
  for (double minor : {1e-2, 1e-4, 1e-6})
  {
    gp_Ax2d                ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom2d_Ellipse) e = new Geom2d_Ellipse(gp_Elips2d(ax, 1e6, minor));
    Geom2dAdaptor_Curve    a(e);
    char                   label[96];
    snprintf(label, sizeof(label), "2D ellipse 1e6 x %g, 8 spot counts", minor);
    // A smaller minor radius does not reopen it: the shortfall scales with the MAJOR radius.
    measure(label, a, spot, false);
  }
  for (double major : {1e8, 1e10})
  {
    gp_Ax2d                ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom2d_Ellipse) e = new Geom2d_Ellipse(gp_Elips2d(ax, major, major * 1e-9));
    Geom2dAdaptor_Curve    a(e);
    char                   label[96];
    snprintf(label, sizeof(label), "2D ellipse %g x %g, 8 spot counts", major, major * 1e-9);
    // 0018's 3D acceptance test is absolute, so a large enough major radius still overshoots.
    measure(label, a, spot, true);
  }

  // --- the Bezier branch QuasiUniformAbscissa handles itself rather than forwarding ---
  {
    TColgp_Array1OfPnt2d poles(1, 4);
    poles.SetValue(1, gp_Pnt2d(0, 0));
    poles.SetValue(2, gp_Pnt2d(1e6, 0));
    poles.SetValue(3, gp_Pnt2d(1e6, 1e-3));
    poles.SetValue(4, gp_Pnt2d(0, 1e-3));
    Handle(Geom2d_BezierCurve) b = new Geom2d_BezierCurve(poles);
    Geom2dAdaptor_Curve        a(b);
    measure("2D 4-pole Bezier, 1e9 aspect, counts 2..60", a, sweep60, false);
  }
  {
    TColgp_Array1OfPnt poles(1, 4);
    poles.SetValue(1, gp_Pnt(0, 0, 0));
    poles.SetValue(2, gp_Pnt(1e6, 0, 0));
    poles.SetValue(3, gp_Pnt(1e6, 1e-3, 0));
    poles.SetValue(4, gp_Pnt(0, 1e-3, 0));
    Handle(Geom_BezierCurve) b = new Geom_BezierCurve(poles);
    GeomAdaptor_Curve        a(b);
    measure("3D 4-pole Bezier, 1e9 aspect, counts 2..60", a, sweep60, false);
  }

  // --- well-conditioned controls, which #501 measured clean and which should stay clean ---
  {
    Handle(Geom2d_Circle) c = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Geom2dAdaptor_Curve   a(c);
    measure("2D circle r=5, counts 2..60", a, sweep60, false);
  }
  {
    Handle(Geom2d_Line) l = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 1));
    Geom2dAdaptor_Curve a(l, 0, 10);
    measure("2D line, counts 2..60", a, sweep60, false);
  }

  printf("\n%s\n",
         gMismatches == 0
           ? "PASS: every row matches its declared expectation. 0018 settles the 1e6 ellipse and "
             "the 1e8 and 1e10 ones still overshoot."
           : "FAIL: a row disagrees with its declared expectation; the kernel moved again.");
  fflush(stdout);
  return gMismatches == 0 ? 0 : 1;
}
