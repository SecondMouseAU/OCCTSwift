// Epic #766, Issue485SurfaceContinuityTests.swift, Issue486SurfaceGridTests.swift and
// Issue495AnalysisOrderTests.swift: kernel parity.
//  - Geom_Surface::Continuity() on the #485 fixtures (a bicubic BSpline with an interior U knot of
//    multiplicity 1, 2, 3; a plane; a sphere), as OCCTSurfaceGetContinuity returns it.
//  - GeomGridEval_Surface::EvaluateGridD1 against Geom_Surface::D1 on the #486 sphere grid.
//  - LocalAnalysis_SurfaceContinuity on the #495 fixtures at each order the bridge maps to
//    (occtGeomAbsFromAnalysisOrder: 0 C0, 1 G1, 2 C1, 3 G2, 4 and above C2).
#include <GeomAbs_Shape.hxx>
#include <GeomGridEval_Surface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <LocalAnalysis_SurfaceContinuity.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <Standard_Failure.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <cstdio>

static Handle(Geom_BSplineSurface) fixture(int mult)
{
  int                     uCount = 4 + mult;
  TColgp_Array2OfPnt      p(1, uCount, 1, 4);
  for (int i = 1; i <= uCount; i++)
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

static const char* names[] = {"C0", "G1", "C1", "G2", "C2", "C3", "CN"};

static void la(const char* tag, const Handle(Geom_Surface)& a, const Handle(Geom_Surface)& b, double u, double v,
               GeomAbs_Shape order)
{
  try
  {
    LocalAnalysis_SurfaceContinuity sc(a, u, v, b, u, v, order);
    printf("%s %s: IsDone=%d", tag, names[order], sc.IsDone());
    if (sc.IsDone())
    {
      printf(" status=%s IsC0=%d", names[sc.ContinuityStatus()], sc.IsC0());
      if (order == GeomAbs_G1 || order == GeomAbs_G2)
        printf(" IsG1=%d G1Angle=%.3g", sc.IsG1(), sc.G1Angle());
      if (order == GeomAbs_C1 || order == GeomAbs_C2)
        printf(" IsC1=%d", sc.IsC1());
      if (order == GeomAbs_G2)
        printf(" IsG2=%d", sc.IsG2());
      if (order == GeomAbs_C2)
        printf(" IsC2=%d", sc.IsC2());
    }
    printf("\n");
  }
  catch (Standard_Failure& e)
  {
    printf("%s %s: threw %s\n", tag, names[order], e.GetMessageString());
  }
}

int main()
{
  for (int m : {1, 2, 3})
    printf("485 bicubic, interior U multiplicity %d: Continuity()=%d\n", m, (int)fixture(m)->Continuity());
  Handle(Geom_Plane)            plane  = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_SphericalSurface) sphere = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  printf("485 plane Continuity()=%d sphere Continuity()=%d\n", (int)plane->Continuity(), (int)sphere->Continuity());

  {
    double                     us[5] = {0.0, 0.4, 1.1, 2.0, 3.5}, vs[3] = {-1.2, 0.0, 1.2};
    NCollection_Array1<double> ua(1, 5), va(1, 3);
    for (int i = 0; i < 5; i++)
      ua(i + 1) = us[i];
    for (int j = 0; j < 3; j++)
      va(j + 1) = vs[j];
    GeomGridEval_Surface                     ev(sphere);
    NCollection_Array2<GeomGridEval::SurfD1> r   = ev.EvaluateGridD1(ua, va);
    double                                   max = 0;
    for (int i = 0; i < 5; i++)
      for (int j = 0; j < 3; j++)
      {
        gp_Pnt p;
        gp_Vec du, dv;
        sphere->D1(us[i], vs[j], p, du, dv);
        const GeomGridEval::SurfD1& g = r.Value(i + 1, j + 1);
        max = std::max({max, g.Point.Distance(p), (g.D1U - du).Magnitude(), (g.D1V - dv).Magnitude()});
      }
    printf("486 sphere EvaluateGridD1 %dx%d: max |grid - D1| over point, D1U, D1V = %.3g\n", r.NbRows(), r.NbColumns(), max);
  }

  for (GeomAbs_Shape o : {GeomAbs_C0, GeomAbs_G1, GeomAbs_C1, GeomAbs_G2, GeomAbs_C2})
    la("495 identical spheres at (0.5, 0.5)", sphere, sphere, 0.5, 0.5, o);
  Handle(Geom_Plane) plane2 = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 1, 0));
  for (GeomAbs_Shape o : {GeomAbs_C0, GeomAbs_G1, GeomAbs_C1, GeomAbs_C2})
    la("495 perpendicular planes at (0, 0)", plane, plane2, 0, 0, o);
  Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  for (GeomAbs_Shape o : {GeomAbs_G2, GeomAbs_C2})
    la("495 identical cylinders at (0.5, 1)", cyl, cyl, 0.5, 1, o);
  return 0;
}
