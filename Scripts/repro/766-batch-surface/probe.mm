// Epic #766, BatchSurfaceTests.swift: kernel parity for the four tests. The same grids go through
// GeomGridEval_Surface::EvaluateGrid (OCCTSurfaceEvaluateGrid) and, for drawMesh, the uniform D0
// sweep OCCTSurfaceDrawMesh does over Geom_Surface::Bounds; each is compared with Geom_Surface::D0
// at the same (u, v) and, on the sphere, with the radius.
#include <GeomGridEval_Surface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_Array2.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static NCollection_Array1<double> arr(const std::vector<double>& v)
{
  NCollection_Array1<double> a(1, (int)v.size());
  for (size_t i = 0; i < v.size(); i++)
    a((int)i + 1) = v[i];
  return a;
}

static void grid(const char* name, const Handle(Geom_Surface)& s, const std::vector<double>& u, const std::vector<double>& v)
{
  GeomGridEval_Surface       ev(s);
  NCollection_Array2<gp_Pnt> r = ev.EvaluateGrid(arr(u), arr(v));
  double                     maxZ = 0, maxR = 0, maxD0 = 0;
  for (size_t i = 0; i < u.size(); i++)
    for (size_t j = 0; j < v.size(); j++)
    {
      gp_Pnt p = r.Value((int)i + 1, (int)j + 1);
      maxZ     = std::max(maxZ, std::abs(p.Z()));
      maxR     = std::max(maxR, std::abs(p.XYZ().Modulus() - 5.0));
      maxD0    = std::max(maxD0, p.Distance(s->Value(u[i], v[j])));
    }
  printf("%s: rows=%d cols=%d max|z|=%.3g max|r-5|=%.3g max|grid-D0|=%.3g\n", name, r.NbRows(), r.NbColumns(),
         maxZ, maxR, maxD0);
}

int main()
{
  Handle(Geom_Plane)            plane  = new Geom_Plane(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
  Handle(Geom_SphericalSurface) sphere = new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
  grid("evalGridPlane", plane, {0, 1, 2}, {0, 1});
  std::vector<double> su, sv;
  for (double a = 0; a < 2 * M_PI; a += M_PI / 4)
    su.push_back(a);
  for (double a = -M_PI / 2; a < M_PI / 2; a += M_PI / 4)
    sv.push_back(a);
  grid("evalGridSphere", sphere, su, sv);
  grid("evalGridAsymmetricMatchesDirectEvaluation", sphere, {0.0, 0.4, 1.1, 2.0, 3.5}, {-1.2, 0.0, 1.2});

  // drawMesh(5, 3): uniform over Bounds, u outer, v inner, against the same grid via EvaluateGrid.
  double u1, u2, v1, v2;
  sphere->Bounds(u1, u2, v1, v2);
  std::vector<double> du, dv;
  for (int i = 0; i < 5; i++)
    du.push_back(u1 + (u2 - u1) * i / 4.0);
  for (int j = 0; j < 3; j++)
    dv.push_back(v1 + (v2 - v1) * j / 2.0);
  GeomGridEval_Surface       ev(sphere);
  NCollection_Array2<gp_Pnt> r   = ev.EvaluateGrid(arr(du), arr(dv));
  double                     max = 0;
  for (int i = 0; i < 5; i++)
    for (int j = 0; j < 3; j++)
      max = std::max(max, r.Value(i + 1, j + 1).Distance(sphere->Value(du[i], dv[j])));
  printf("drawMeshAndEvaluateGridAgree: bounds=[%.17g, %.17g]x[%.17g, %.17g] max|D0 sweep - EvaluateGrid|=%.3g\n", u1,
         u2, v1, v2, max);
  return 0;
}
