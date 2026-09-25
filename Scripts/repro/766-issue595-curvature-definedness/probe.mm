// Kernel parity probe for Tests/OCCTAnalysisTests/Issue595CurvatureDefinednessTests.swift,
// curve3DCurvatureSeparatesZeroFromAbsent (#1946). Mirrors OCCTCurve3DGetCurvature:
// GeomLProp_CLProps(curve, u, 2, Precision::Confusion()), reporting nothing when
// IsTangentDefined() is false and Curvature() otherwise.
#include <GeomLProp_CLProps.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <NCollection_Array1.hxx>
#include <Precision.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <cstdio>

static void report(const char* label, const Handle(Geom_Curve)& c, double u)
{
  GeomLProp_CLProps p(c, u, 2, Precision::Confusion());
  if (!p.IsTangentDefined())
    printf("%s at u=%g: IsTangentDefined=0 -> curvature(at:) == nil\n", label, u);
  else
    printf("%s at u=%g: IsTangentDefined=1 curvature=%.17g\n", label, u, p.Curvature());
}

int main()
{
  Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  report("line through origin along +X", line, 3);

  NCollection_Array1<gp_Pnt> poles(1, 4);
  for (int i = 1; i <= 4; ++i)
    poles(i) = gp_Pnt(0, 0, 0);
  Handle(Geom_BezierCurve) dead = new Geom_BezierCurve(poles);
  report("Bezier with four coincident poles", dead, 0.5);

  Handle(Geom_Circle) circle =
    new Geom_Circle(gp_Circ(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4));
  report("circle r=4", circle, 1);
  return 0;
}
