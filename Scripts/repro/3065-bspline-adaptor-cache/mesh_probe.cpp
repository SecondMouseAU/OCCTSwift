// #3065: macro cost of the 0031 locks. Meshes and integrates a BSpline-surface face, single
// threaded, and prints wall seconds. Link once against the shipped kernel (0031 locking on) and
// once with the four lock-free adaptor objects ahead of it (same class layout), then compare.
#include <chrono>
#include <cstdio>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRep_Tool.hxx>
#include <GProp_GProps.hxx>
#include <Geom_BSplineSurface.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <Poly_Triangulation.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS_Face.hxx>
#include <cmath>

int main() {
  const int n = 24;
  TColgp_Array2OfPnt pts(1, n, 1, n);
  for (int i = 1; i <= n; ++i)
    for (int j = 1; j <= n; ++j)
      pts(i, j) = gp_Pnt(i, j, 3 * std::sin(i * 0.4) * std::cos(j * 0.35));
  GeomAPI_PointsToBSplineSurface b(pts, 3, 5);
  TopoDS_Face f = BRepBuilderAPI_MakeFace(b.Surface(), 1e-6);
  auto t0 = std::chrono::steady_clock::now();
  BRepMesh_IncrementalMesh m(f, 0.05, false, 0.5, false);
  auto t1 = std::chrono::steady_clock::now();
  GProp_GProps props;
  BRepGProp::SurfaceProperties(f, props, 1e-6);
  auto t2 = std::chrono::steady_clock::now();
  TopLoc_Location loc;
  auto tri = BRep_Tool::Triangulation(f, loc);
  printf("mesh_s=%.4f gprop_s=%.4f tris=%d area=%.6f\n", std::chrono::duration<double>(t1 - t0).count(),
         std::chrono::duration<double>(t2 - t1).count(), tri ? tri->NbTriangles() : -1, props.Mass());
}
