// #1979 kernel parity for Geom2dEvalCircleInvolutePlacementTests, Geom2dEvalCircleInvoluteTests
// and Geom2dEvalLogSpiralTests: Geom2dEval_CircleInvoluteCurve and
// Geom2dEval_LogarithmicSpiralCurve evaluated with the placements and inputs the
// OCCTGeom2dEval* bridge functions use.
#include <Geom2dEval_CircleInvoluteCurve.hxx>
#include <Geom2dEval_LogarithmicSpiralCurve.hxx>
#include <gp_Ax2d.hxx>
#include <cstdio>

static void inv(const char* tag, double ox, double oy, double dx, double dy, double r, double u)
{
  Geom2dEval_CircleInvoluteCurve c(gp_Ax2d(gp_Pnt2d(ox, oy), gp_Dir2d(dx, dy)), r);
  gp_Pnt2d                       p;
  gp_Vec2d                       v;
  c.D1(u, p, v);
  printf("%s u=%g: P=(%.12g, %.12g) D1=(%.12g, %.12g)\n", tag, u, p.X(), p.Y(), v.X(), v.Y());
}

static void logs(const char* tag, double a, double b, double u)
{
  Geom2dEval_LogarithmicSpiralCurve c(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), a, b);
  gp_Pnt2d                          p;
  gp_Vec2d                          v;
  c.D1(u, p, v);
  printf("%s u=%g: P=(%.12g, %.12g) D1=(%.12g, %.12g)\n", tag, u, p.X(), p.Y(), v.X(), v.Y());
}

int main()
{
  inv("involute identity R2", 0, 0, 1, 0, 2, 0);
  inv("involute identity R2", 0, 0, 1, 0, 2, 1);
  inv("involute identity R2", 0, 0, 1, 0, 2, 5);
  inv("involute (10,20) +x R2", 10, 20, 1, 0, 2, 0);
  inv("involute (10,20) +x R2", 10, 20, 1, 0, 2, 1);
  inv("involute origin +y R2", 0, 0, 0, 1, 2, 0);
  inv("involute (5,5) +y R2", 5, 5, 0, 1, 2, 1);
  logs("log spiral a1 b0.2", 1, 0.2, 0);
  logs("log spiral a1 b0.2", 1, 0.2, 1);
  logs("log spiral a1 b0.2", 1, 0.2, 10);
  return 0;
}
