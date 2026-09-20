// #1646: what does a REFUSED Geom2dEval_* evaluation actually look like, and is the constructor
// the only thing that can refuse?
//
// #1399's probe (Scripts/repro/1399-geometry/probe_geom2deval_throws.mm) established that the
// constructors throw on ordinary caller values. PR #1629 caught those throws, which left the ten
// bridge entry points writing zeros into the caller's out-parameters and returning void, so a
// refusal is spelled exactly like a real answer at the origin. #1646 gives them a success flag,
// and this probe answers the three questions that flag's contract needs:
//
//   1. Can EvalD0/EvalD1 throw for a parameter value, separately from the constructor? If they
//      can, the flag has to cover the evaluation and not only the construction.
//   2. What happens on a non-finite argument? OCCT's validation is written as `<= 0`, and every
//      comparison against NaN is false, so a NaN may sail through a check that rejects 0.
//   3. Does a curve constructed from finite arguments ever evaluate to a non-finite point? The
//      logarithmic spiral is exp(b*t) and overflows for large t.
//
// Build (from the repo root):
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1646-evaluator-contract/probe_geom2deval_contract.mm -o /tmp/occt_probe_1646
//   /tmp/occt_probe_1646

#include <Geom2dEval_ArchimedeanSpiralCurve.hxx>
#include <Geom2dEval_CircleInvoluteCurve.hxx>
#include <Geom2dEval_LogarithmicSpiralCurve.hxx>
#include <Geom2dEval_SineWaveCurve.hxx>
#include <Standard_Failure.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Dir2d.hxx>

#include <cmath>
#include <cstdio>
#include <limits>

static const gp_Ax2d AX(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
static const double  NAN_D = std::numeric_limits<double>::quiet_NaN();
static const double  INF_D = std::numeric_limits<double>::infinity();

template <typename Fn>
static void probe(const char* label, Fn body)
{
  try
  {
    body();
  }
  catch (const Standard_Failure& e)
  {
    printf("  %-56s THREW: %s\n", label,
           e.GetMessageString() ? e.GetMessageString() : "(no message)");
  }
  catch (...)
  {
    printf("  %-56s THREW (non-Standard_Failure)\n", label);
  }
}

static void say(const char* label, const gp_Pnt2d& p)
{
  printf("  %-56s (%g, %g)%s\n", label, p.X(), p.Y(),
         (std::isfinite(p.X()) && std::isfinite(p.Y())) ? "" : "   <- NOT FINITE");
}

int main()
{
  printf("1. Can EvalD0/EvalD1 refuse a parameter the constructor accepted?\n");
  {
    Geom2dEval_SineWaveCurve sw(AX, 1.0, 1.0, 0.0);
    probe("SineWave(1,1,0).EvalD0(u = 0)", [&] { say("  u = 0", sw.EvalD0(0.0)); });
    probe("SineWave(1,1,0).EvalD0(u = 1e300)", [&] { say("  u = 1e300", sw.EvalD0(1e300)); });
    probe("SineWave(1,1,0).EvalD0(u = NaN)", [&] { say("  u = NaN", sw.EvalD0(NAN_D)); });
    probe("SineWave(1,1,0).EvalD0(u = +inf)", [&] { say("  u = +inf", sw.EvalD0(INF_D)); });
    probe("SineWave(1,1,0).EvalD1(u = NaN)",
          [&] { auto r = sw.EvalD1(NAN_D); say("  u = NaN, point", r.Point); });

    Geom2dEval_CircleInvoluteCurve inv(AX, 5.0);
    probe("CircleInvolute(5).EvalD0(u = -1e6)", [&] { say("  u = -1e6", inv.EvalD0(-1e6)); });
  }

  printf("\n2. Does a non-finite ARGUMENT get past the constructor's own validation?\n");
  probe("SineWaveCurve(amplitude = NaN, omega = 1)", [] {
    Geom2dEval_SineWaveCurve c(AX, NAN_D, 1.0, 0.0);
    say("  constructed, EvalD0(0.5)", c.EvalD0(0.5));
  });
  probe("SineWaveCurve(amplitude = 1, omega = NaN)", [] {
    Geom2dEval_SineWaveCurve c(AX, 1.0, NAN_D, 0.0);
    say("  constructed, EvalD0(0.5)", c.EvalD0(0.5));
  });
  probe("SineWaveCurve(amplitude = +inf, omega = 1)", [] {
    Geom2dEval_SineWaveCurve c(AX, INF_D, 1.0, 0.0);
    say("  constructed, EvalD0(0.5)", c.EvalD0(0.5));
  });
  probe("CircleInvoluteCurve(radius = NaN)", [] {
    Geom2dEval_CircleInvoluteCurve c(AX, NAN_D);
    say("  constructed, EvalD0(0.5)", c.EvalD0(0.5));
  });
  probe("ArchimedeanSpiralCurve(initialRadius = NaN, growthRate = 0.1)", [] {
    Geom2dEval_ArchimedeanSpiralCurve c(AX, NAN_D, 0.1);
    say("  constructed, EvalD0(0.5)", c.EvalD0(0.5));
  });
  probe("LogarithmicSpiralCurve(scale = NaN, growthExponent = 0.2)", [] {
    Geom2dEval_LogarithmicSpiralCurve c(AX, NAN_D, 0.2);
    say("  constructed, EvalD0(0.5)", c.EvalD0(0.5));
  });

  printf("\n3. Does a curve built from finite arguments ever evaluate to a non-finite point?\n");
  probe("LogarithmicSpiral(scale = 1, growth = 1).EvalD0(u = 1000)", [] {
    Geom2dEval_LogarithmicSpiralCurve c(AX, 1.0, 1.0);
    say("  u = 1000", c.EvalD0(1000.0));
  });
  probe("ArchimedeanSpiral(1, 1).EvalD0(u = 1e308)", [] {
    Geom2dEval_ArchimedeanSpiralCurve c(AX, 1.0, 1.0);
    say("  u = 1e308", c.EvalD0(1e308));
  });

  printf("\n4. gp_Dir2d from a NaN direction, which the placement overloads normalise first.\n");
  printf("   hypot(NaN, NaN) = %g; NaN < 1e-12 is %s, so a length guard written as a comparison\n"
         "   lets it through.\n",
         std::hypot(NAN_D, NAN_D), (std::hypot(NAN_D, NAN_D) < 1.0e-12) ? "true" : "false");
  probe("gp_Dir2d(NaN, NaN)", [] {
    gp_Dir2d d(NAN_D, NAN_D);
    printf("  %-56s (%g, %g)\n", "  constructed", d.X(), d.Y());
  });

  return 0;
}
