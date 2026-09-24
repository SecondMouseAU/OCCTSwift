// Epic #766, SurfaceApproximateDefaultsParityTests.swift and SurfaceAxisAccessorsTests.swift:
// kernel parity for the six tests. Surface.approximated() goes through occtApproxSurface:
// GeomConvert_ApproxSurface(surface, tol, C2, C2, maxDeg, maxDeg, maxSeg = 100, 0), defaults
// tol 1e-3 and maxDeg 8. The inputs are the same surfaces the tests build: the radius-5 sphere,
// the (10, 3) torus, trimmedCylinder / trimmedCone, and a Geom_OffsetSurface(0.3) of the
// fromPointGrid fit (GeomAPI_PointsToBSplineSurface, degree 3..7, C2, 1e-3) of the 8x8 grid
// z = 1.5 sin(0.7u) cos(0.7v). The axis tests read Geom_ToroidalSurface::Axis().
#include <GC_MakeConicalSurface.hxx>
#include <GC_MakeTrimmedCone.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <cmath>
#include <cstdio>

static Handle(Geom_BSplineSurface) approx(const Handle(Geom_Surface)& s, double tol, int deg)
{
  try
  {
    GeomConvert_ApproxSurface a(s, tol, GeomAbs_C2, GeomAbs_C2, deg, deg, 100, 0);
    if (!a.HasResult())
      return nullptr;
    return a.Surface();
  }
  catch (Standard_Failure&)
  {
    return nullptr;
  }
}

static void desc(const char* name, const Handle(Geom_BSplineSurface)& b)
{
  if (b.IsNull())
  {
    printf("%s: nil\n", name);
    return;
  }
  printf("%s: degree %dx%d poles %dx%d\n", name, b->UDegree(), b->VDegree(), b->NbUPoles(), b->NbVPoles());
}

int main()
{
  gp_Ax3               ax(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_Surface) sphere = new Geom_SphericalSurface(ax, 5);
  desc("sphere tol 1e-3 deg 8 (default)", approx(sphere, 1e-3, 8));
  desc("sphere tol 1e-2 deg 10 (pre-#406 default)", approx(sphere, 1e-2, 10));
  desc("sphere tol 1e-2 deg 8", approx(sphere, 1e-2, 8));
  desc("torus", approx(new Geom_ToroidalSurface(ax, 10, 3), 1e-3, 8));
  desc("trimmedCylinder", approx(GC_MakeTrimmedCylinder(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5, 20).Value(), 1e-3, 8));
  desc("trimmedCone", approx(GC_MakeTrimmedCone(gp_Pnt(0, 0, 0), gp_Pnt(0, 0, 10), 5, 2).Value(), 1e-3, 8));

  // The test appends its grid u-major (point k = i * 8 + j), but fromPointGrid reads point
  // k = v * uCount + u into pts(u + 1, v + 1) (OCCTPointsToSurfaceBSpline), so the grid lands
  // transposed: pts(a + 1, b + 1) is the test's point (i = b, j = a).
  TColgp_Array2OfPnt pts(1, 8, 1, 8);
  for (int a = 0; a < 8; a++)
    for (int b = 0; b < 8; b++)
    {
      double u = b / 7.0 * 10, v = a / 7.0 * 10;
      pts(a + 1, b + 1) = gp_Pnt(u, v, std::sin(u * 0.7) * std::cos(v * 0.7) * 1.5);
    }
  Handle(Geom_BSplineSurface) base = GeomAPI_PointsToBSplineSurface(pts, 3, 7, GeomAbs_C2, 1e-3).Surface();
  Handle(Geom_OffsetSurface)  off  = new Geom_OffsetSurface(base, 0.3);
  for (int k = 0; k < 2; k++)
  {
    Handle(Geom_BSplineSurface) a = approx(k == 0 ? Handle(Geom_Surface)(off) : Handle(Geom_Surface)(base), 1e-3, 8);
    desc(k == 0 ? "offset approx" : "base approx (the gross regression the test names)", a);
    double u1, u2, v1, v2, worst = 0;
    a->Bounds(u1, u2, v1, v2);
    for (int i = 0; i <= 4; i++)
      for (int j = 0; j <= 4; j++)
      {
        double u = u1 + (u2 - u1) * i / 4, v = v1 + (v2 - v1) * j / 4;
        worst    = std::max(worst, a->Value(u, v).Distance(off->Value(u, v)));
      }
    printf("  max deviation from the offset surface on the 5x5 grid = %.17g\n", worst);
  }

  Handle(Geom_ToroidalSurface) t = new Geom_ToroidalSurface(gp_Ax3(gp_Pnt(1, 2, 3), gp_Dir(0, 0, 1)), 20, 5);
  printf("torusSurfaceAxis: location=(%g,%g,%g) direction=(%g,%g,%g)\n", t->Axis().Location().X(), t->Axis().Location().Y(),
         t->Axis().Location().Z(), t->Axis().Direction().X(), t->Axis().Direction().Y(), t->Axis().Direction().Z());
  return 0;
}
