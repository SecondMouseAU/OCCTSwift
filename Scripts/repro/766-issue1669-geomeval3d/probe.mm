// Epic #766, Issue1669GeomEval3DRefusalTests.swift: kernel parity. The same GeomEval evaluators the
// bridge wraps, on the same arguments, printing the raw EvalD0/D1/D2 results. For a NaN or
// infinite argument the kernel does not throw: it constructs and evaluates to a non-finite point,
// which is why the bridge's success flag is read off the outputs (#1669).
#include <GeomEval_CircularHelixCurve.hxx>
#include <GeomEval_EllipsoidSurface.hxx>
#include <GeomEval_SineWaveCurve.hxx>
#include <GeomEval_ParaboloidSurface.hxx>
#include <Standard_Failure.hxx>
#include <cmath>
#include <cstdio>

static void p3(const char* tag, const gp_Pnt& p)
{
  printf("%s=(%.12g, %.12g, %.12g) finite=%d\n", tag, p.X(), p.Y(), p.Z(),
         std::isfinite(p.X()) && std::isfinite(p.Y()) && std::isfinite(p.Z()));
}

int main()
{
  const gp_Ax2 ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  const gp_Ax3 ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  const double nan = std::nan(""), inf = INFINITY;
  p3("helix(5, 2) D0(0)", GeomEval_CircularHelixCurve(ax2, 5, 2).EvalD0(0));
  p3("ellipsoid(3, 4, 5) D0(0, 0)", GeomEval_EllipsoidSurface(ax3, 3, 4, 5).EvalD0(0, 0));
  p3("sineWave(2, 3, 0) D0(0)", GeomEval_SineWaveCurve(ax2, 2, 3, 0).EvalD0(0));
  auto d2 = GeomEval_CircularHelixCurve(ax2, 5, 2).EvalD2(0);
  p3("helix(5, 2) D2(0) point", d2.Point);
  printf("helix(5, 2) D2(0) D1=(%.12g, %.12g, %.12g) D2=(%.12g, %.12g, %.12g)\n", d2.D1.X(), d2.D1.Y(), d2.D1.Z(),
         d2.D2.X(), d2.D2.Y(), d2.D2.Z());
  try
  {
    p3("helix(NaN, 2) D0(0)", GeomEval_CircularHelixCurve(ax2, nan, 2).EvalD0(0));
    p3("helix(5, 2) D0(NaN)", GeomEval_CircularHelixCurve(ax2, 5, 2).EvalD0(nan));
    p3("helix(inf, 2) D0(0)", GeomEval_CircularHelixCurve(ax2, inf, 2).EvalD0(0));
    p3("sineWave(NaN, 3, 0) D0(0)", GeomEval_SineWaveCurve(ax2, nan, 3, 0).EvalD0(0));
    p3("sineWave(inf, 3, 0) D0(0)", GeomEval_SineWaveCurve(ax2, inf, 3, 0).EvalD0(0));
    p3("ellipsoid(NaN, 4, 5) D0(0, 0)", GeomEval_EllipsoidSurface(ax3, nan, 4, 5).EvalD0(0, 0));
    p3("ellipsoid(3, 4, 5) D0(NaN, 0)", GeomEval_EllipsoidSurface(ax3, 3, 4, 5).EvalD0(nan, 0));
    p3("paraboloid(1) D0(inf, 0)", GeomEval_ParaboloidSurface(ax3, 1).EvalD0(inf, 0));
  }
  catch (Standard_Failure& e)
  {
    printf("threw %s\n", e.GetMessageString());
  }
  return 0;
}
