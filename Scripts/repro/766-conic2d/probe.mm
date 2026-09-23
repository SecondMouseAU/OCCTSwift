// #766 kernel parity for Tests/OCCTAnalysisTests/Conic2DTests.swift: IntAna2d_Conic::Coefficients
// (OCCTConic2dFromCircle/Line/Ellipse) and IntAna2d_AnaIntersection(gp_Lin2d, IntAna2d_Conic(gp_Circ2d))
// (OCCTConic2dLineCircleIntersect) on the suite's inputs.
#include <IntAna2d_AnaIntersection.hxx>
#include <IntAna2d_Conic.hxx>
#include <IntAna2d_IntPoint.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Lin2d.hxx>
#include <cstdio>

static void coeffs(const char* label, const IntAna2d_Conic& c)
{
  double a, b, cc, d, e, f;
  c.Coefficients(a, b, cc, d, e, f);
  printf("%s: a=%.17g b=%.17g c=%.17g d=%.17g e=%.17g f=%.17g\n", label, a, b, cc, d, e, f);
}

int main()
{
  gp_Ax2d ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
  coeffs("fromCircle r=5", IntAna2d_Conic(gp_Circ2d(ax, 5)));
  coeffs("fromLine (0,0) dir (1,0)", IntAna2d_Conic(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0))));
  coeffs("fromEllipse 5 x 3", IntAna2d_Conic(gp_Elips2d(ax, 5, 3)));

  IntAna2d_AnaIntersection inter(gp_Lin2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)),
                                 IntAna2d_Conic(gp_Circ2d(ax, 5)));
  printf("lineCircleIntersection: done=%d n=%d\n", (int)inter.IsDone(), inter.NbPoints());
  for (int i = 1; i <= inter.NbPoints(); ++i)
    printf("  point %d = (%.17g, %.17g)\n", i, inter.Point(i).Value().X(),
           inter.Point(i).Value().Y());
  return 0;
}
