// #1979 kernel parity for Issue1646EvaluatorContractTests: the Geom2dEval_* constructors and
// EvalD0/EvalD1 calls the OCCTGeom2dEval* bridge functions make, on the test's own arguments.
#include <Geom2dEval_SineWaveCurve.hxx>
#include <Geom2dEval_CircleInvoluteCurve.hxx>
#include <Geom2dEval_ArchimedeanSpiralCurve.hxx>
#include <Geom2dEval_LogarithmicSpiralCurve.hxx>
#include <Standard_Failure.hxx>
#include <cmath>
#include <cstdio>
#include <limits>

static const gp_Ax2d AX(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));

template <class F> static void d0(const char* tag, F make, double u)
{
  try
  {
    auto     c = make();
    gp_Pnt2d p = c.EvalD0(u);
    printf("%s D0(%g) = (%.12g, %.12g)\n", tag, u, p.X(), p.Y());
  }
  catch (Standard_Failure& e)
  {
    printf("%s: throws %s\n", tag, e.what());
  }
}

template <class F> static void d1(const char* tag, F make, double u)
{
  try
  {
    auto                      c = make();
    Geom2d_Curve::ResD1       r = c.EvalD1(u);
    printf("%s D1(%g): P=(%.12g, %.12g) D1=(%.12g, %.12g)\n", tag, u, r.Point.X(), r.Point.Y(), r.D1.X(), r.D1.Y());
  }
  catch (Standard_Failure& e)
  {
    printf("%s: throws %s\n", tag, e.what());
  }
}

int main()
{
  const double nan = std::numeric_limits<double>::quiet_NaN();
  // Constructor rejections.
  d0("sine A0", [] { return Geom2dEval_SineWaveCurve(AX, 0, 1, 0); }, 0.5);
  d0("sine omega 0", [] { return Geom2dEval_SineWaveCurve(AX, 1, 0, 0); }, 0.5);
  d0("involute R0", [] { return Geom2dEval_CircleInvoluteCurve(AX, 0); }, 0.5);
  d0("archimedean growth 0", [] { return Geom2dEval_ArchimedeanSpiralCurve(AX, 1, 0); }, 0.5);
  d0("archimedean r0 -1", [] { return Geom2dEval_ArchimedeanSpiralCurve(AX, -1, 0.1); }, 0.5);
  d0("log scale 0", [] { return Geom2dEval_LogarithmicSpiralCurve(AX, 0, 0.2); }, 0.5);
  d0("log growth 0", [] { return Geom2dEval_LogarithmicSpiralCurve(AX, 1, 0); }, 0.5);
  // Accepted neighbours.
  d0("sine 1,1,0", [] { return Geom2dEval_SineWaveCurve(AX, 1, 1, 0); }, 0.5);
  d0("sine 1,1,0", [] { return Geom2dEval_SineWaveCurve(AX, 1, 1, 0); }, 0.0);
  d0("involute R1", [] { return Geom2dEval_CircleInvoluteCurve(AX, 1); }, 0.5);
  d0("archimedean 1, 0.1", [] { return Geom2dEval_ArchimedeanSpiralCurve(AX, 1, 0.1); }, 0.5);
  d0("log 1, 0.2", [] { return Geom2dEval_LogarithmicSpiralCurve(AX, 1, 0.2); }, 0.5);
  d1("sine 1,1,0", [] { return Geom2dEval_SineWaveCurve(AX, 1, 1, 0); }, 0.5);
  // Non-finite arguments and parameters.
  d0("sine A NaN", [&] { return Geom2dEval_SineWaveCurve(AX, nan, 1, 0); }, 0.5);
  d0("sine omega NaN", [&] { return Geom2dEval_SineWaveCurve(AX, 1, nan, 0); }, 0.5);
  d0("sine A inf", [&] { return Geom2dEval_SineWaveCurve(AX, INFINITY, 1, 0); }, 0.5);
  d0("involute R NaN", [&] { return Geom2dEval_CircleInvoluteCurve(AX, nan); }, 0.5);
  d0("archimedean r0 NaN", [&] { return Geom2dEval_ArchimedeanSpiralCurve(AX, nan, 0.1); }, 0.5);
  d0("log scale NaN", [&] { return Geom2dEval_LogarithmicSpiralCurve(AX, nan, 0.2); }, 0.5);
  d1("sine A NaN", [&] { return Geom2dEval_SineWaveCurve(AX, nan, 1, 0); }, 0.5);
  d0("sine u NaN", [] { return Geom2dEval_SineWaveCurve(AX, 1, 1, 0); }, nan);
  d0("sine u inf", [] { return Geom2dEval_SineWaveCurve(AX, 1, 1, 0); }, INFINITY);
  d1("involute R1 u NaN", [] { return Geom2dEval_CircleInvoluteCurve(AX, 1); }, nan);
  // Overflow.
  d0("log 1, 1", [] { return Geom2dEval_LogarithmicSpiralCurve(AX, 1, 1); }, 1000);
  d0("log 1, 1", [] { return Geom2dEval_LogarithmicSpiralCurve(AX, 1, 1); }, 1);
  // Placement.
  gp_Ax2d pl(gp_Pnt2d(10, 20), gp_Dir2d(1, 0));
  d0("placed involute R2 at (10,20)", [&] { return Geom2dEval_CircleInvoluteCurve(pl, 2); }, 0);
  d1("placed involute R2 at (10,20)", [&] { return Geom2dEval_CircleInvoluteCurve(pl, 2); }, 1);
  d0("involute R2 radius NaN placed", [&] { return Geom2dEval_CircleInvoluteCurve(AX, nan); }, 1);
  return 0;
}
