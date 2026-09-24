// #766 kernel parity for Tests/OCCTAnalysisTests/LProp3dCurveTests.swift.
// OCCTCurve3DCreateCircle builds a Geom_Circle on gp_Ax2(center, normal); OCCTCurve3DLocalTangent,
// LocalNormal and LocalCentreOfCurvature read GeomLProp_CLProps(curve, u, order,
// Precision::Confusion()) (occtCurveLocalProps in OCCTBridge_Internal.h).
#include <GeomLProp_CLProps.hxx>
#include <Geom_Circle.hxx>
#include <Precision.hxx>
#include <gp_Ax2.hxx>
#include <cstdio>

int main()
{
  Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);

  GeomLProp_CLProps p1(c, 0.0, 1, Precision::Confusion());
  printf("tangentOfCircle u=0: IsTangentDefined=%d", p1.IsTangentDefined() ? 1 : 0);
  if (p1.IsTangentDefined())
  {
    gp_Dir t;
    p1.Tangent(t);
    printf(" tangent=(%.17g, %.17g, %.17g)", t.X(), t.Y(), t.Z());
  }
  printf("\n");

  GeomLProp_CLProps p2(c, 0.0, 2, Precision::Confusion());
  printf("normalOfCircle u=0: IsTangentDefined=%d curvature=%.17g", p2.IsTangentDefined() ? 1 : 0,
         p2.Curvature());
  gp_Dir n;
  p2.Normal(n);
  printf(" normal=(%.17g, %.17g, %.17g)\n", n.X(), n.Y(), n.Z());

  gp_Pnt cc;
  p2.CentreOfCurvature(cc);
  printf("centreOfCurvature u=0: centre=(%.17g, %.17g, %.17g)\n", cc.X(), cc.Y(), cc.Z());
  return 0;
}
