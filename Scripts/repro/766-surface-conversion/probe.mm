// Epic #766, SurfaceConversionTests.swift and SurfaceCurvatureParityTests.swift: kernel parity for
// the eight tests. The radius-5 Geom_SphericalSurface: GeomConvert::SurfaceToBSplineSurface,
// GeomConvert_ApproxSurface(1e-3, C2, C2, 8, 8, 100, 0) (occtApproxSurface), UIso(0) / VIso(0);
// and the apex cone (Geom_ConicalSurface, radius 0, 30 degrees): GeomLProp_SLProps curvature at
// Precision::Confusion() (occtSurfaceLocalProps) against the old hardcoded 1e-6 resolution.
#include <GeomConvert.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_Curve.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Precision.hxx>
#include <cstdio>

int main()
{
  gp_Ax3               ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_Surface) sphere = new Geom_SphericalSurface(ax, 5);
  Handle(Geom_BSplineSurface) b = GeomConvert::SurfaceToBSplineSurface(sphere);
  gp_Pnt                      m = b->Value(M_PI, 0), o = sphere->Value(M_PI, 0);
  printf("sphereToBSpline: degree %dx%d, S(pi,0) bspline=(%.17g,%.17g,%.17g) sphere=(%.17g,%.17g,%.17g)\n", b->UDegree(), b->VDegree(),
         m.X(), m.Y(), m.Z(), o.X(), o.Y(), o.Z());
  GeomConvert_ApproxSurface   a(sphere, 1e-3, GeomAbs_C2, GeomAbs_C2, 8, 8, 100, 0);
  Handle(Geom_BSplineSurface) s = a.Surface();
  printf("approximateSurface: degree %dx%d poles %dx%d\n", s->UDegree(), s->VDegree(), s->NbUPoles(), s->NbVPoles());
  Handle(Geom_Curve) ui = sphere->UIso(0), vi = sphere->VIso(0);
  gp_Pnt             us = ui->Value(ui->FirstParameter()), u0 = ui->Value(0), vq = vi->Value(M_PI / 2);
  printf("uIsoCurve: start=(%g,%g,%g) at 0=(%g,%g,%g)\n", us.X(), us.Y(), us.Z(), u0.X(), u0.Y(), u0.Z());
  printf("vIsoCurve: closed=%d at pi/2=(%.3g,%.3g,%.3g)\n", vi->IsClosed(), vq.X(), vq.Y(), vq.Z());
  Handle(Geom_Surface) cone = new Geom_ConicalSurface(ax, M_PI / 6, 0);
  for (double res : {Precision::Confusion(), 1e-6})
  {
    GeomLProp_SLProps p(cone, 0, 1e-6, 2, res);
    bool              d = p.IsCurvatureDefined();
    printf("toleranceWindowAgrees: cone v=1e-6 resolution %g defined=%d mean=%.17g\n", res, d, d ? p.MeanCurvature() : 0.0);
  }
  GeomLProp_SLProps apex(cone, 0, 0, 2, Precision::Confusion());
  printf("undefinedPointsAgree: apex defined=%d\n", apex.IsCurvatureDefined());
  return 0;
}
