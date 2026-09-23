// #1979 kernel parity for Issue514Conic2dDegenerateTests: Convert_*ToBSplineCurve on the accepted
// and the degenerate dimensions (what the bridge guards now refuse), IntAna2d_Conic coefficients,
// and IntAna2d_AnaIntersection of a line with a radius-0 and a radius-5 circle.
#include <Convert_CircleToBSplineCurve.hxx>
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

static const gp_Ax22d AX(gp_Pnt2d(0, 0), gp_Dir2d(1, 0), gp_Dir2d(0, 1));

static void conv(const char* tag, const Convert_ConicToBSplineCurve& c)
{
  gp_Pnt2d a = c.Pole(1), b = c.Pole(c.NbPoles());
  printf("%s: degree=%d poles=%d first pole=(%.12g, %.12g) last pole=(%.12g, %.12g)\n", tag, c.Degree(), c.NbPoles(),
         a.X(), a.Y(), b.X(), b.Y());
}

template <class F> static void guarded(const char* tag, F f)
{
  try
  {
    f();
  }
  catch (Standard_Failure& e)
  {
    printf("%s: throws %s\n", tag, e.what());
  }
}

static void coeffs(const char* tag, const IntAna2d_Conic& c)
{
  double A, B, C, D, E, F;
  c.Coefficients(A, B, C, D, E, F);
  printf("%s: A=%.12g B=%.12g C=%.12g D=%.12g E=%.12g F=%.12g\n", tag, A, B, C, D, E, F);
}

int main()
{
  guarded("ellipse 5x3 [0,pi]", [] { conv("ellipse 5x3 [0,pi]", Convert_EllipseToBSplineCurve(gp_Elips2d(AX, 5, 3), 0, M_PI)); });
  guarded("ellipse 4x4 [0,pi]", [] { conv("ellipse 4x4 [0,pi]", Convert_EllipseToBSplineCurve(gp_Elips2d(AX, 4, 4), 0, M_PI)); });
  guarded("ellipse 0x0 [0,pi]", [] { conv("ellipse 0x0 [0,pi]", Convert_EllipseToBSplineCurve(gp_Elips2d(AX, 0, 0), 0, M_PI)); });
  guarded("ellipse 5x0 [0,pi]", [] { conv("ellipse 5x0 [0,pi]", Convert_EllipseToBSplineCurve(gp_Elips2d(AX, 5, 0), 0, M_PI)); });
  guarded("ellipse 5x-3", [] { gp_Elips2d(AX, 5, -3); printf("ellipse 5x-3 constructed\n"); });
  guarded("ellipse 3x5", [] { gp_Elips2d(AX, 3, 5); printf("ellipse 3x5 constructed\n"); });
  guarded("hyperbola 3x5 [0,1]", [] { conv("hyperbola 3x5 [0,1]", Convert_HyperbolaToBSplineCurve(gp_Hypr2d(AX, 3, 5), 0, 1)); });
  guarded("hyperbola 0x0 [0,1]", [] { conv("hyperbola 0x0 [0,1]", Convert_HyperbolaToBSplineCurve(gp_Hypr2d(AX, 0, 0), 0, 1)); });
  guarded("parabola f2 [0,1]", [] { conv("parabola f2 [0,1]", Convert_ParabolaToBSplineCurve(gp_Parab2d(AX, 2), 0, 1)); });
  guarded("parabola f0 [0,1]", [] { conv("parabola f0 [0,1]", Convert_ParabolaToBSplineCurve(gp_Parab2d(AX, 0), 0, 1)); });
  guarded("circle r3 [0,pi]", [] { conv("circle r3 [0,pi]", Convert_CircleToBSplineCurve(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 3), 0, M_PI)); });
  guarded("circle r0 [0,pi]", [] { conv("circle r0 [0,pi]", Convert_CircleToBSplineCurve(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 0), 0, M_PI)); });

  coeffs("conic circle r5", IntAna2d_Conic(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5)));
  coeffs("conic ellipse 5x3", IntAna2d_Conic(gp_Elips2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5, 3)));
  coeffs("conic ellipse 0x0", IntAna2d_Conic(gp_Elips2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 0, 0)));
  coeffs("conic line (0,0)+x", IntAna2d_Conic(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0))));
  guarded("gp_Dir2d(0,0)", [] { gp_Dir2d d(0, 0); printf("gp_Dir2d(0,0) constructed\n"); });

  for (double r : {0.0, 5.0})
  {
    IntAna2d_AnaIntersection in(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)),
                                IntAna2d_Conic(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), r)));
    printf("x-axis vs circle r%g: done=%d n=%d", r, in.IsDone(), in.IsDone() ? in.NbPoints() : -1);
    for (int i = 1; in.IsDone() && i <= in.NbPoints(); i++)
      printf(" (%.12g, %.12g)", in.Point(i).Value().X(), in.Point(i).Value().Y());
    printf("\n");
  }
  return 0;
}
