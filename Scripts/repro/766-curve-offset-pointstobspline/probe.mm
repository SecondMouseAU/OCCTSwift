// Epic #766 (#1978), kernel parity for OffsetCurveBasisTests and PointsToBSplineExpansionTests:
// Geom_OffsetCurve over the x-axis line (offset 2, reference direction +Z) and its BasisCurve at
// parameter 3; GeomAPI_PointsToBSpline end points on the five-point fixture, and the three-point
// explicit-parameter fit at 0.3.
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Line.hxx>
#include <Geom_OffsetCurve.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <cstdio>

int main()
{
  Handle(Geom_Line)        line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
  Handle(Geom_OffsetCurve) off  = new Geom_OffsetCurve(line, 2.0, gp_Dir(0, 0, 1));
  gp_Pnt                   b = off->BasisCurve()->Value(3), o = off->Value(3);
  printf("offset basis at 3: (%g, %g, %g); offset at 3: (%g, %g, %g)\n", b.X(), b.Y(), b.Z(), o.X(), o.Y(), o.Z());
  TColgp_Array1OfPnt p(1, 5);
  p(1) = gp_Pnt(0, 0, 0); p(2) = gp_Pnt(2, 3, 0); p(3) = gp_Pnt(5, 1, 0); p(4) = gp_Pnt(8, 4, 0); p(5) = gp_Pnt(10, 0, 0);
  Handle(Geom_BSplineCurve) c = GeomAPI_PointsToBSpline(p, 3, 8, GeomAbs_C2, 1e-3).Curve();
  gp_Pnt s = c->Value(c->FirstParameter()), e = c->Value(c->LastParameter());
  printf("5-point fit: start (%.12g, %.12g) end (%.12g, %.12g)\n", s.X(), s.Y(), e.X(), e.Y());
  TColgp_Array1OfPnt   q(1, 3);
  TColStd_Array1OfReal t(1, 3);
  q(1) = gp_Pnt(0, 0, 0); q(2) = gp_Pnt(3, 5, 0); q(3) = gp_Pnt(10, 0, 0);
  t(1) = 0; t(2) = 0.3; t(3) = 1;
  Handle(Geom_BSplineCurve) d = GeomAPI_PointsToBSpline(q, t, 2, 6, GeomAbs_C2, 1e-3).Curve();
  gp_Pnt m = d->Value(0.3);
  printf("3-point fit with parameters: at 0.3 (%.12g, %.12g)\n", m.X(), m.Y());
  return 0;
}
