// #1979 evidence-fix pass for the seven Issue514Conic2dDegenerateTests parity records whose bridge and
// kernel sides carried different keys. Lines starting "EF " are `EF <record>.<key> = <json>`, read by the
// record generator. Each measurement makes the OCCT calls the bridge function makes, with the test's inputs:
//   OCCTConvertEllipse/Hyperbola/ParabolaToBSpline2D: Convert_*ToBSplineCurve on a gp_Elips2d / gp_Hypr2d /
//     gp_Parab2d built on a gp_Ax22d;
//   OCCTConic2dFromCircle / FromLine / FromEllipse: IntAna2d_Conic on a gp_Circ2d / gp_Lin2d / gp_Elips2d built on a
//     gp_Ax2d with the caller's direction;
//   OCCTConic2dLineCircleIntersect: IntAna2d_AnaIntersection(line, IntAna2d_Conic(circle)).
#include <Convert_EllipseToBSplineCurve.hxx>
#include <Convert_HyperbolaToBSplineCurve.hxx>
#include <Convert_ParabolaToBSplineCurve.hxx>
#include <IntAna2d_AnaIntersection.hxx>
#include <IntAna2d_Conic.hxx>
#include <IntAna2d_IntPoint.hxx>
#include <Standard_Failure.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Hypr2d.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Parab2d.hxx>
#include <cmath>
#include <cstdio>
#include <string>

static const gp_Ax22d AX22(gp_Pnt2d(0, 0), gp_Dir2d(1, 0), gp_Dir2d(0, 1));

static void ef(const char* rec, const char* key, bool v)
{
  printf("EF %s.%s = %s\n", rec, key, v ? "true" : "false");
}
static void efn(const char* rec, const char* key, int v)
{
  printf("EF %s.%s = %d\n", rec, key, v);
}

// Runs one construction; returns "yields" or "raised", and prints how it ended.
template <class F> static bool run(const char* tag, F f)
{
  try
  {
    std::string what = f();
    printf("%s: yields (%s)\n", tag, what.c_str());
    return true;
  }
  catch (Standard_Failure& e)
  {
    printf("%s: raised %s\n", tag, e.what());
    return false;
  }
}

static std::string poles(const Convert_ConicToBSplineCurve& c)
{
  char b[200];
  gp_Pnt2d a = c.Pole(1), z = c.Pole(c.NbPoles());
  snprintf(b, sizeof b, "degree %d, %d poles, first (%.6g, %.6g), last (%.6g, %.6g)", c.Degree(), c.NbPoles(), a.X(), a.Y(), z.X(), z.Y());
  return b;
}

static std::string coeffs(const IntAna2d_Conic& c)
{
  double A, B, C, D, E, F;
  c.Coefficients(A, B, C, D, E, F);
  char b[200];
  snprintf(b, sizeof b, "A=%.6g B=%.6g C=%.6g D=%.6g E=%.6g F=%.6g", A, B, C, D, E, F);
  return b;
}

int main()
{
  // ---- A: ellipse arc [0, pi] with a zero radius (OCCTConvertEllipseToBSpline2D, guard removed) ----
  ef("A1", "ellipse_0x0", run("A ellipse 0x0", [] { return poles(Convert_EllipseToBSplineCurve(gp_Elips2d(AX22, 0, 0), 0, M_PI)); }));
  ef("A1", "ellipse_5x0", run("A ellipse 5x0", [] { return poles(Convert_EllipseToBSplineCurve(gp_Elips2d(AX22, 5, 0), 0, M_PI)); }));
  // ---- B: negative and inverted radii -------------------------------------------------------------
  ef("A2", "ellipse_5x_minus3", run("B ellipse 5x-3", [] { return poles(Convert_EllipseToBSplineCurve(gp_Elips2d(AX22, 5, -3), 0, M_PI)); }));
  ef("A2", "ellipse_3x5", run("B ellipse 3x5", [] { return poles(Convert_EllipseToBSplineCurve(gp_Elips2d(AX22, 3, 5), 0, M_PI)); }));
  // ---- C: hyperbola arc [0, 1] with a zero radius --------------------------------------------------
  ef("A3", "hyperbola_0x0", run("C hyperbola 0x0", [] { return poles(Convert_HyperbolaToBSplineCurve(gp_Hypr2d(AX22, 0, 0), 0, 1)); }));
  ef("A3", "hyperbola_5x0", run("C hyperbola 5x0", [] { return poles(Convert_HyperbolaToBSplineCurve(gp_Hypr2d(AX22, 5, 0), 0, 1)); }));
  ef("A3", "hyperbola_0x3", run("C hyperbola 0x3", [] { return poles(Convert_HyperbolaToBSplineCurve(gp_Hypr2d(AX22, 0, 3), 0, 1)); }));
  // ---- D: parabola arc [0, 1] with focal 0 ---------------------------------------------------------
  ef("A4", "parabola_focal_0", run("D parabola focal 0", [] { return poles(Convert_ParabolaToBSplineCurve(gp_Parab2d(AX22, 0), 0, 1)); }));
  // ---- E: IntAna2d_Conic of a zero-radius ellipse --------------------------------------------------
  auto ax = [](double dx, double dy) { return gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(dx, dy)); };
  ef("A5", "ellipse_0x0", run("E conic ellipse 0x0", [&] { return coeffs(IntAna2d_Conic(gp_Elips2d(ax(1, 0), 0, 0))); }));
  ef("A5", "ellipse_5x0", run("E conic ellipse 5x0", [&] { return coeffs(IntAna2d_Conic(gp_Elips2d(ax(1, 0), 5, 0))); }));
  // ---- F: a zero direction -------------------------------------------------------------------------
  ef("A6", "circle", run("F conic circle, direction (0,0)", [&] { return coeffs(IntAna2d_Conic(gp_Circ2d(ax(0, 0), 5))); }));
  ef("A6", "line", run("F conic line, direction (0,0)", [&] { return coeffs(IntAna2d_Conic(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(0, 0)))); }));
  ef("A6", "ellipse", run("F conic ellipse, direction (0,0)", [&] { return coeffs(IntAna2d_Conic(gp_Elips2d(ax(0, 0), 5, 3))); }));
  // ---- G: x-axis against a circle centred (0,0) of radius r ----------------------------------------
  for (double r : {0.0, 5.0})
  {
    IntAna2d_AnaIntersection in(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), IntAna2d_Conic(gp_Circ2d(ax(1, 0), r)));
    int                      n = in.IsDone() ? in.NbPoints() : 0;
    printf("G x-axis vs circle radius %g: IsDone=%d points=%d", r, in.IsDone(), n);
    for (int i = 1; i <= n; i++)
      printf(" (%.6g, %.6g)", in.Point(i).Value().X(), in.Point(i).Value().Y());
    printf("\n");
    efn("A7", r == 0 ? "r0_points" : "r5_points", n);
  }
  return 0;
}
