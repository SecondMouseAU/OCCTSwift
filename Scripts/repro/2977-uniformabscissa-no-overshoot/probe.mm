// #2977: does any GCPnts arc-length sampler still return more points than it was asked for?
//
// #501's bridge guards (occtSamplerKept / occtSamplerIndex) exist because
// GCPnts_UniformAbscissa::initialize sizes its own array at nbPoints + 5 and lets the walk fill it
// as far as it runs. `Curve2DTests.uniformDrawRespectsCount` pins sixteen counts that were measured
// to overshoot on a 1e6 x 1e-3 ellipse. On the pinned kernel it reaches none of them.
//
// This probe settles whether that is "the 2D uniform path never overshot" or "the kernel moved":
// both samplers, 2D and 3D, over the test's own ellipse and its own sixteen counts, then over a
// sweep of counts, more ill-conditioned ellipses, and the Bezier branch that
// GCPnts_QuasiUniformAbscissa handles itself rather than forwarding to GCPnts_UniformAbscissa.
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
// Exit status is 1 if anything overshoots, so the run itself is the assertion.

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

static int gOvershoots = 0;

template <class Adaptor>
static void measure(const char* label, const Adaptor& a, const std::vector<int>& counts)
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
  auto t1 = std::chrono::steady_clock::now();
  printf("%-44s uniform: %-22s quasi: %-22s [%.0f s]\n",
         label,
         uniformOver.empty() ? "none" : uniformOver.c_str(),
         quasiOver.empty() ? "none" : quasiOver.c_str(),
         std::chrono::duration<double>(t1 - t0).count());
  fflush(stdout);
  if (!uniformOver.empty())
    gOvershoots++;
  if (!quasiOver.empty())
    gOvershoots++;
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
  printf("%-44s %-31s %s\n", "curve", "GCPnts_UniformAbscissa", "GCPnts_QuasiUniformAbscissa");
  printf("%s\n", std::string(130, '-').c_str());
  fflush(stdout);

  // --- #501's own triggering geometry, 2D and 3D ---
  {
    gp_Ax2d                ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom2d_Ellipse) e = new Geom2d_Ellipse(gp_Elips2d(ax, 1e6, 1e-3));
    Geom2dAdaptor_Curve    a(e);
    measure("2D ellipse 1e6 x 1e-3, the test's 16 counts", a, testCounts);
    measure("2D ellipse 1e6 x 1e-3, counts 2..60", a, sweep60);
  }
  {
    gp_Ax2               ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Elips(ax, 1e6, 1e-3));
    GeomAdaptor_Curve    a(e);
    measure("3D ellipse 1e6 x 1e-3, the test's 16 counts", a, testCounts);
    measure("3D ellipse 1e6 x 1e-3, counts 2..60", a, sweep60);
  }

  // --- more ill-conditioned ellipses, in case the fix only moved the threshold ---
  for (double minor : {1e-2, 1e-4, 1e-6})
  {
    gp_Ax2d                ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom2d_Ellipse) e = new Geom2d_Ellipse(gp_Elips2d(ax, 1e6, minor));
    Geom2dAdaptor_Curve    a(e);
    char                   label[96];
    snprintf(label, sizeof(label), "2D ellipse 1e6 x %g, 8 spot counts", minor);
    measure(label, a, spot);
  }
  for (double major : {1e8, 1e10})
  {
    gp_Ax2d                ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    Handle(Geom2d_Ellipse) e = new Geom2d_Ellipse(gp_Elips2d(ax, major, major * 1e-9));
    Geom2dAdaptor_Curve    a(e);
    char                   label[96];
    snprintf(label, sizeof(label), "2D ellipse %g x %g, 8 spot counts", major, major * 1e-9);
    measure(label, a, spot);
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
    measure("2D 4-pole Bezier, 1e9 aspect, counts 2..60", a, sweep60);
  }
  {
    TColgp_Array1OfPnt poles(1, 4);
    poles.SetValue(1, gp_Pnt(0, 0, 0));
    poles.SetValue(2, gp_Pnt(1e6, 0, 0));
    poles.SetValue(3, gp_Pnt(1e6, 1e-3, 0));
    poles.SetValue(4, gp_Pnt(0, 1e-3, 0));
    Handle(Geom_BezierCurve) b = new Geom_BezierCurve(poles);
    GeomAdaptor_Curve        a(b);
    measure("3D 4-pole Bezier, 1e9 aspect, counts 2..60", a, sweep60);
  }

  // --- well-conditioned controls, which #501 measured clean and which should stay clean ---
  {
    Handle(Geom2d_Circle) c = new Geom2d_Circle(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5);
    Geom2dAdaptor_Curve   a(c);
    measure("2D circle r=5, counts 2..60", a, sweep60);
  }
  {
    Handle(Geom2d_Line) l = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 1));
    Geom2dAdaptor_Curve a(l, 0, 10);
    measure("2D line, counts 2..60", a, sweep60);
  }

  printf("\n%s\n",
         gOvershoots == 0 ? "PASS: nothing overshoots on the pinned kernel."
                          : "FAIL: at least one sampler returned more points than requested.");
  fflush(stdout);
  return gOvershoots == 0 ? 0 : 1;
}
