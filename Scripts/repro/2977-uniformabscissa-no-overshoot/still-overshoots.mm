// #2977: which inputs still overshoot on the pinned kernel, and by how much?
//
// `probe.mm` finds none on #501's own 1e6 x 1e-3 ellipse and two on a 1e8 x 0.1 one. Carried patch
// `0018` does not stop the walk falling short of the end; it adds a second acceptance test, that
// the step is within `theTol` of the end **in 3D**. On a 1e6 major the leftover gap is inside that
// tolerance and the walk stops; on a 1e8 major the same relative gap is a hundred times larger in
// model space, so the sampler takes its extra step and `NbPoints()` is request + 1 again.
//
// This enumerates the overshooting counts on that ellipse, 2D and 3D, both samplers, so the
// regression test can be re-pointed at an input that still reaches the surplus-point path. It also
// prints the last two parameters, which is what makes the surplus visible as "the end of the curve
// arriving in an extra slot" rather than as a bare count.
//
//   XC=.build/artifacts/<pkg>/OCCT/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$XC/Headers" -L"$XC" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/2977-uniformabscissa-no-overshoot/still-overshoots.mm -o /tmp/probe_2977b

#include <GCPnts_QuasiUniformAbscissa.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2d_Ellipse.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom_Ellipse.hxx>
#include <gp_Elips.hxx>
#include <gp_Elips2d.hxx>

#include <cstdio>
#include <string>
#include <vector>

template <class Adaptor>
static void enumerate(const char* label, const Adaptor& a, int lo, int hi)
{
  printf("\n%s, counts %d..%d\n", label, lo, hi);
  fflush(stdout);
  std::string uni, qua;
  for (int c = lo; c <= hi; c++)
  {
    GCPnts_UniformAbscissa u(a, c);
    if (u.IsDone() && u.NbPoints() > c)
    {
      uni += " " + std::to_string(c);
      printf("  uniform count=%-4d NbPoints=%-4d last two params %.17g %.17g  end %.17g\n",
             c,
             u.NbPoints(),
             u.Parameter(u.NbPoints() - 1),
             u.Parameter(u.NbPoints()),
             a.LastParameter());
      fflush(stdout);
    }
    GCPnts_QuasiUniformAbscissa q(a, c);
    if (q.IsDone() && q.NbPoints() > c)
      qua += " " + std::to_string(c);
  }
  printf("  uniform overshoots:%s\n", uni.empty() ? " none" : uni.c_str());
  printf("  quasi   overshoots:%s\n", qua.empty() ? " none" : qua.c_str());
  fflush(stdout);
}

int main()
{
  {
    Handle(Geom2d_Ellipse) e =
      new Geom2d_Ellipse(gp_Elips2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 1e8, 0.1));
    Geom2dAdaptor_Curve a(e);
    enumerate("2D ellipse 1e8 x 0.1", a, 2, 60);
  }
  {
    gp_Ax2               ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), gp_Dir(1, 0, 0));
    Handle(Geom_Ellipse) e = new Geom_Ellipse(gp_Elips(ax, 1e8, 0.1));
    GeomAdaptor_Curve    a(e);
    enumerate("3D ellipse 1e8 x 0.1", a, 2, 60);
  }
  return 0;
}
