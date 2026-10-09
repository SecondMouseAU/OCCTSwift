// Epic #766 kernel-parity probe for Tests/OCCTMathTests/GeomLibInterpolateTests.swift,
// GeomLibIsPlanarSurfaceTests.swift and GeomLibToolTests.swift. Same OCCT calls and inputs as
// OCCTGeomLibInterpolate, OCCTGeomLibIsPlanarSurface, OCCTGeomLibPlanarSurfacePlane,
// OCCTGeomLibToolParameter3D / Parameter2D / ParametersSurface (maxDist 1.0, tolerance 1e-7).
#include <GC_MakePlane.hxx>
#include <Geom2d_Line.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <GeomLib_Interpolate.hxx>
#include <GeomLib_IsPlanarSurface.hxx>
#include <GeomLib_Tool.hxx>
#include <NCollection_Array1.hxx>
#include <gp_Ax3.hxx>
#include <cstdio>

static void interp(const char* name, int degree, int n, const double (*p)[3], const double* t)
{
  NCollection_Array1<gp_Pnt> pts(1, n);
  NCollection_Array1<double> params(1, n);
  for (int i = 0; i < n; i++)
  {
    pts(i + 1)    = gp_Pnt(p[i][0], p[i][1], p[i][2]);
    params(i + 1) = t[i];
  }
  GeomLib_Interpolate gi(degree, n, pts, params);
  printf("%s: isDone=%d", name, gi.IsDone() ? 1 : 0);
  if (!gi.IsDone())
  {
    printf("\n");
    return;
  }
  Handle(Geom_BSplineCurve) c = gi.Curve();
  printf(" degree=%d poles=%d domain=[%.10g, %.10g]\n",
         c->Degree(),
         c->NbPoles(),
         c->FirstParameter(),
         c->LastParameter());
  for (int i = 0; i < n; i++)
  {
    gp_Pnt q = c->Value(t[i]);
    printf("  C(%.4g) = (%.10g, %.10g, %.10g)\n", t[i], q.X(), q.Y(), q.Z());
  }
}

int main()
{
  const double p5[5][3] = {{0, 0, 0}, {1, 1, 0}, {2, 0, 0}, {3, -1, 0}, {4, 0, 0}};
  const double t5[5]    = {0.0, 0.25, 0.5, 0.75, 1.0};
  interp("interpolate", 3, 5, p5, t5);
  const double p3[3][3] = {{0, 0, 0}, {2, 2, 0}, {4, 0, 0}};
  const double t3[3]    = {0.0, 0.5, 1.0};
  interp("endpoints", 3, 3, p3, t3);

  Handle(Geom_Plane) plane = GC_MakePlane(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1)).Value();
  {
    GeomLib_IsPlanarSurface k(plane, 1e-7);
    printf("planeIsPlanar: IsPlanar=%d\n", k.IsPlanar() ? 1 : 0);
    if (k.IsPlanar())
    {
      const gp_Pln& pl = k.Plan();
      printf("getPlane: origin=(%.10g, %.10g, %.10g) normal=(%.10g, %.10g, %.10g) x=(%.10g, %.10g, %.10g)\n",
             pl.Location().X(), pl.Location().Y(), pl.Location().Z(),
             pl.Axis().Direction().X(), pl.Axis().Direction().Y(), pl.Axis().Direction().Z(),
             pl.XAxis().Direction().X(), pl.XAxis().Direction().Y(), pl.XAxis().Direction().Z());
    }
  }
  {
    Handle(Geom_CylindricalSurface) cyl =
      new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    GeomLib_IsPlanarSurface k(cyl, 1e-7);
    printf("cylinderNotPlanar: IsPlanar=%d\n", k.IsPlanar() ? 1 : 0);
  }
  {
    Handle(Geom_Line) l = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
    double            u = 0;
    bool              ok = GeomLib_Tool::Parameter(l, gp_Pnt(5, 0, 0), 1.0, u);
    printf("parameterOn3DLine: ok=%d param=%.10g\n", ok ? 1 : 0, u);
  }
  {
    Handle(Geom_Plane) pl = GC_MakePlane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)).Value();
    double             u = 0, v = 0;
    bool               ok = GeomLib_Tool::Parameters(pl, gp_Pnt(3, 4, 0), 1.0, u, v);
    printf("parametersOnSurface: ok=%d u=%.10g v=%.10g\n", ok ? 1 : 0, u, v);
  }
  {
    Handle(Geom2d_Line) l = new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0));
    double              u = 0;
    bool                ok = GeomLib_Tool::Parameter(l, gp_Pnt2d(7, 0), 1.0, u);
    printf("parameterOn2DLine: ok=%d param=%.10g\n", ok ? 1 : 0, u);
  }
  return 0;
}
