// Epic #766, Issue562SurfaceKnotSplitDuplicateTests.swift, Issue571PlateApproxTests.swift,
// Issue619SurfaceContinuityEncodingTests.swift and Issue623ContinuityFloorTests.swift: kernel parity.
//  - GeomConvert_BSplineSurfaceKnotSplitting on the BSpline of a radius-5 sphere
//    (GeomConvert::SurfaceToBSplineSurface), split indices and the knots they name.
//  - The #571 plate: GeomPlate_BuildPlateSurface(3, 15, 2) through the 5x5 wavy grid, then
//    GeomPlate_MakeApprox(plate, tol, 20, 8, tol * 0.1, 0, GeomAbs_C1) as occtPlateApproxSurface
//    calls it, and the worst distance from each grid point to the fit.
//  - Geom_Surface::Continuity() on the #619/#623 fixtures, and Geom_BezierSurface::Continuity().
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_BSplineSurfaceKnotSplitting.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static Handle(Geom_BSplineSurface) fixture(int mult, int uPoles)
{
  TColgp_Array2OfPnt p(1, uPoles, 1, 4);
  for (int i = 1; i <= uPoles; i++)
    for (int j = 1; j <= 4; j++)
      p(i, j) = gp_Pnt(i, j, (i + j) % 2);
  TColStd_Array1OfReal    ku(1, 3), kv(1, 2);
  TColStd_Array1OfInteger mu(1, 3), mv(1, 2);
  ku(1) = 0;
  ku(2) = 0.5;
  ku(3) = 1;
  mu(1) = 4;
  mu(2) = mult;
  mu(3) = 4;
  kv(1) = 0;
  kv(2) = 1;
  mv(1) = 4;
  mv(2) = 4;
  return new Geom_BSplineSurface(p, ku, kv, mu, mv, 3, 3);
}

int main()
{
  Handle(Geom_BSplineSurface) sph =
    GeomConvert::SurfaceToBSplineSurface(new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5));
  printf("562 sphere BSpline: NbUKnots=%d NbVKnots=%d\n", sph->NbUKnots(), sph->NbVKnots());
  for (int c = 0; c <= 3; c++)
  {
    GeomConvert_BSplineSurfaceKnotSplitting s(sph, c, c);
    printf("562 C%d: U indices=", c);
    for (int i = 1; i <= s.NbUSplits(); i++)
      printf("%d(%.6g) ", s.USplitValue(i), sph->UKnot(s.USplitValue(i)));
    printf("V indices=");
    for (int i = 1; i <= s.NbVSplits(); i++)
      printf("%d(%.6g) ", s.VSplitValue(i), sph->VKnot(s.VSplitValue(i)));
    printf("\n");
  }

  std::vector<gp_Pnt> pts;
  for (int i = 0; i < 5; i++)
    for (int j = 0; j < 5; j++)
      pts.push_back(gp_Pnt(i * 4.0, j * 4.0, 4.0 * sin(i * 1.3) * cos(j * 1.1)));
  for (double tol : {0.1, 0.01, 0.0005})
  {
    GeomPlate_BuildPlateSurface b(3, 15, 2);
    for (auto& p : pts)
      b.Add(new GeomPlate_PointConstraint(p, 0));
    b.Perform();
    for (int nb : {20, 1})
    {
      GeomPlate_MakeApprox        ap(b.Surface(), tol, nb, 8, tol * 0.1, 0, GeomAbs_C1);
      Handle(Geom_BSplineSurface) s     = ap.Surface();
      double                      worst = 0;
      for (auto& p : pts)
      {
        GeomAPI_ProjectPointOnSurf pr(p, s);
        if (pr.NbPoints() > 0)
          worst = std::max(worst, pr.LowerDistance());
      }
      printf("571 plate tol %g Nbmax %d: poles=%dx%d worst point deviation=%.3g\n", tol, nb, s->NbUPoles(), s->NbVPoles(), worst);
    }
  }
  printf("619/623 continuity: mult1=%d mult2=%d mult3(7 poles)=%d\n", (int)fixture(1, 5)->Continuity(), (int)fixture(2, 6)->Continuity(),
         (int)fixture(3, 7)->Continuity());
  TColgp_Array2OfPnt bp(1, 3, 1, 3);
  for (int i = 0; i < 3; i++)
    for (int j = 0; j < 3; j++)
      bp(i + 1, j + 1) = gp_Pnt(i, j, (i + j) % 2);
  printf("619 Bezier 3x3 Continuity()=%d\n", (int)Handle(Geom_BezierSurface)(new Geom_BezierSurface(bp))->Continuity());
  return 0;
}
