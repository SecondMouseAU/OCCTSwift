// Epic #766, BSplineSurfaceKnotTests.swift and BSplineSurfaceLocalEvalTests.swift: kernel parity
// for the fourteen tests. All of them query GeomConvert::SurfaceToBSplineSurface of a radius-5
// Geom_SphericalSurface (OCCTSurfaceToBSpline) with the Geom_BSplineSurface calls the matching
// OCCTSurfaceBSpline* bridge functions make, at the domain midpoint (pi, 0).
#include <GeomConvert.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <cstdio>

static void p(const char* tag, const gp_XYZ& v)
{
  printf(" %s=(%.17g, %.17g, %.17g)", tag, v.X(), v.Y(), v.Z());
}

int main()
{
  Handle(Geom_BSplineSurface) bs =
    GeomConvert::SurfaceToBSplineSurface(new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp::DZ()), 5));
  double u1, u2, v1, v2;
  bs->Bounds(u1, u2, v1, v2);
  printf("bounds: [%.17g, %.17g]x[%.17g, %.17g]\n", u1, u2, v1, v2);
  double um = (u1 + u2) / 2, vm = (v1 + v2) / 2;
  int    i1, i2, j1, j2;
  bs->LocateU(um, 1e-10, i1, i2);
  bs->LocateV(vm, 1e-10, j1, j2);
  printf("locateU: u=%.17g I1=%d I2=%d\nlocateV: v=%.17g I1=%d I2=%d\n", um, i1, i2, vm, j1, j2);
  printf("knotValues: UKnot(1)=%.17g VKnot(1)=%.17g\n", bs->UKnot(1), bs->VKnot(1));
  printf("multiplicity: UMultiplicity(1)=%d VMultiplicity(1)=%d\n", bs->UMultiplicity(1), bs->VMultiplicity(1));
  printf("knotDistribution: U=%d V=%d (NonUniform=0 Uniform=1 QuasiUniform=2 PiecewiseBezier=3)\n",
         (int)bs->UKnotDistribution(), (int)bs->VKnotDistribution());
  printf("closedQueries: IsUClosed=%d IsVClosed=%d\n", bs->IsUClosed(), bs->IsVClosed());
  printf("getPoles: %dx%d first pole=(%.17g, %.17g, %.17g)\n", bs->NbUPoles(), bs->NbVPoles(), bs->Pole(1, 1).X(),
         bs->Pole(1, 1).Y(), bs->Pole(1, 1).Z());

  gp_Pnt P, G = bs->Value(um, vm);
  gp_Vec d1u, d1v, d2u, d2v, d2uv, d3u, d3v, d3uuv, d3uvv;
  bs->LocalD0(um, vm, i1, i2, j1, j2, P);
  printf("localD0:");
  p("LocalD0", P.XYZ());
  p("global", G.XYZ());
  printf("\n");
  bs->LocalD1(um, vm, i1, i2, j1, j2, P, d1u, d1v);
  printf("localD1:");
  p("P", P.XYZ());
  p("D1U", d1u.XYZ());
  p("D1V", d1v.XYZ());
  printf("\n");
  bs->LocalD2(um, vm, i1, i2, j1, j2, P, d1u, d1v, d2u, d2v, d2uv);
  printf("localD2:");
  p("P", P.XYZ());
  p("D2U", d2u.XYZ());
  p("D2V", d2v.XYZ());
  p("D2UV", d2uv.XYZ());
  printf("\n");
  bs->LocalD3(um, vm, i1, i2, j1, j2, P, d1u, d1v, d2u, d2v, d2uv, d3u, d3v, d3uuv, d3uvv);
  printf("localD3:");
  p("P", P.XYZ());
  p("D3U", d3u.XYZ());
  p("D3V", d3v.XYZ());
  printf("\n");
  gp_Vec dn = bs->LocalDN(um, vm, i1, i2, j1, j2, 1, 0);
  printf("localDN:");
  p("LocalDN(1,0)", dn.XYZ());
  printf("\n");
  gp_Pnt lv = bs->LocalValue(um, vm, i1, i2, j1, j2);
  printf("localValue:");
  p("LocalValue", lv.XYZ());
  printf("\n");
  return 0;
}
