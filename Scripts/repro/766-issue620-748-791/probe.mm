// Epic #766, Issue620DrawMeshCountContractTests.swift, Issue748NetworkSurfaceCornersTests.swift and
// Issue791ConvertSphereHelperTests.swift: kernel parity.
//  - The OCCTSurfaceDrawMesh sweep (uniform over Bounds, infinite bounds clamped to +-100) at one
//    sample per direction, on a radius-10 sphere and the z = 0 plane.
//  - Geom_BezierSurface with a single row or column of poles (the #620 two-pole minimum).
//  - GeomAPI_ExtremaCurveCurve contacts between the #748 profiles and guides, the grid
//    OCCTGeomFillNetworkSurface feeds GeomFill_NetworkSurface.
//  - Convert_SphereToBSplineSurface on the two #791 spheres: pole counts, a sample of poles and
//    weights, and the knots.
#include <Convert_SphereToBSplineSurface.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomAPI_ExtremaCurveCurve.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Standard_Failure.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <cstdio>
#include <gp_Sphere.hxx>
#include <vector>

int main()
{
  Handle(Geom_SphericalSurface) s = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
  double                        u1, u2, v1, v2;
  s->Bounds(u1, u2, v1, v2);
  gp_Pnt a = s->Value(u1, v1), b = s->Value(u1, v2);
  printf("620 sphere bounds=[%g, %g]x[%g, %g] single u-row at uMin: first=(%g,%g,%g) last=(%g,%g,%g)\n", u1, u2, v1, v2,
         a.X(), a.Y(), a.Z(), b.X(), b.Y(), b.Z());
  Handle(Geom_Plane) pl = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  gp_Pnt             pf = pl->Value(-100, -100), plast = pl->Value(-100, 100);
  printf("620 plane clamped single u-row: first=(%g,%g,%g) last=(%g,%g,%g)\n", pf.X(), pf.Y(), pf.Z(), plast.X(), plast.Y(),
         plast.Z());
  for (int rows : {1, 2})
  {
    try
    {
      TColgp_Array2OfPnt p(1, rows, 1, rows == 1 ? 3 : 1);
      p.Init(gp_Pnt(0, 0, 0));
      Handle(Geom_BezierSurface) bz = new Geom_BezierSurface(p);
      printf("620 Geom_BezierSurface %dx%d: accepted\n", p.ColLength(), p.RowLength());
    }
    catch (Standard_Failure& e)
    {
      printf("620 Geom_BezierSurface with a single row/column: threw %s\n", e.GetMessageString());
    }
  }
  auto seg = [](gp_Pnt a, gp_Pnt b) { return Handle(Geom_TrimmedCurve)(GC_MakeSegment(a, b).Value()); };
  std::vector<Handle(Geom_TrimmedCurve)> prof = {seg(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)), seg(gp_Pnt(0, 10, 0), gp_Pnt(10, 10, 0))};
  std::vector<Handle(Geom_TrimmedCurve)> gd = {seg(gp_Pnt(0, 0, 0), gp_Pnt(0, 10, 0)), seg(gp_Pnt(5, 0, 0), gp_Pnt(5, 10, 0)),
                                               seg(gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0))};
  printf("748 contact grid (profile i, guide j):");
  for (size_t i = 0; i < prof.size(); i++)
    for (size_t j = 0; j < gd.size(); j++)
    {
      GeomAPI_ExtremaCurveCurve ex(prof[i], gd[j]);
      gp_Pnt                    pp, gp;
      ex.NearestPoints(pp, gp);
      printf(" (%zu,%zu)=(%g,%g,%g)", i, j, pp.X(), pp.Y(), pp.Z());
    }
  printf("\n");
  struct Cfg
  {
    gp_Pnt o;
    gp_Dir d;
    double r;
  } cfgs[2] = {{gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1), 5}, {gp_Pnt(3, -2, 7), gp_Dir(1, 1, 1), 2.5}};
  for (auto& c : cfgs)
  {
    Convert_SphereToBSplineSurface cv(gp_Sphere(gp_Ax3(c.o, c.d), c.r));
    gp_Pnt                         p22 = cv.Pole(2, 2), p11 = cv.Pole(1, 1);
    printf("791 sphere r=%g: poles=%dx%d degree=(%d,%d) Pole(1,1)=(%.17g,%.17g,%.17g) Pole(2,2)=(%.17g,%.17g,%.17g) Weight(2,2)=%.17g "
           "UKnots=",
           c.r, cv.NbUPoles(), cv.NbVPoles(), cv.UDegree(), cv.VDegree(), p11.X(), p11.Y(), p11.Z(), p22.X(), p22.Y(), p22.Z(),
           cv.Weight(2, 2));
    for (int i = 1; i <= cv.NbUKnots(); i++)
      printf("%.17g ", cv.UKnot(i));
    printf("VKnots=");
    for (int i = 1; i <= cv.NbVKnots(); i++)
      printf("%.17g ", cv.VKnot(i));
    printf("\n");
  }
  return 0;
}
