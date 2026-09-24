// #766 kernel parity for KDTreeTests: NCollection_KDTree<gp_Pnt, 3>, built and queried as
// OCCTKDTree* in OCCTBridge_Spatial_SpatialQueries.mm does; indices printed 0-based as the bridge
// returns them.
#include <NCollection_Array1.hxx>
#include <NCollection_KDTree.hxx>
#include <gp_Pnt.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

int main()
{
  {
    std::vector<gp_Pnt> pts = {gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0), gp_Pnt(0, 1, 0), gp_Pnt(0, 0, 1),
                               gp_Pnt(1, 1, 1), gp_Pnt(5, 5, 5), gp_Pnt(10, 10, 10)};
    NCollection_KDTree<gp_Pnt, 3> tree;
    tree.Build(pts.data(), pts.size());
    double sq = 0;
    size_t i  = tree.NearestPoint(gp_Pnt(0, 0, 0), sq);
    printf("KDTree nearest to (0,0,0): index=%zu distance=%.17g\n", i - 1, std::sqrt(sq));
    i = tree.NearestPoint(gp_Pnt(0.9, 0.1, 0.1), sq);
    printf("KDTree nearest to (0.9,0.1,0.1): index=%zu distance=%.17g\n", i - 1, std::sqrt(sq));
    for (int k : {3, 1, 7})
    {
      NCollection_Array1<size_t> idx(1, k);
      NCollection_Array1<double> dist(1, k);
      size_t                     n = tree.KNearestPoints(gp_Pnt(0, 0, 0), (size_t)k, idx, dist);
      printf("KDTree %d-nearest to origin: found=%zu:", k, n);
      for (size_t j = 1; j <= n; j++)
        printf(" (%zu, %.17g)", idx(j) - 1, dist(j));
      printf("\n");
    }
    // Swift's kNearest(k: 100) asks the bridge for Sampling.capacity(100) = 100.
    {
      NCollection_Array1<size_t> idx(1, 100);
      NCollection_Array1<double> dist(1, 100);
      printf("KDTree 100-nearest to origin: found=%zu\n", tree.KNearestPoints(gp_Pnt(0, 0, 0), 100, idx, dist));
    }
    for (double r : {1.1, 0.1})
    {
      auto res = tree.RangeSearch(gp_Pnt(0, 0, 0), r);
      printf("KDTree range r=%g: count=%zu:", r, (size_t)res.Size());
      for (size_t j = 0; j < (size_t)res.Size(); j++)
        printf(" %zu", res[j] - 1);
      printf("\n");
    }
    auto b1 = tree.BoxSearch(gp_Pnt(-0.5, -0.5, -0.5), gp_Pnt(1.5, 1.5, 1.5));
    printf("KDTree box (-0.5..1.5): count=%zu:", (size_t)b1.Size());
    for (size_t j = 0; j < (size_t)b1.Size(); j++)
      printf(" %zu", b1[j] - 1);
    printf("\n");
    auto b2 = tree.BoxSearch(gp_Pnt(-100, -100, -100), gp_Pnt(100, 100, 100));
    printf("KDTree box (-100..100): count=%zu\n", (size_t)b2.Size());
  }
  {
    std::vector<gp_Pnt> pts;
    for (int i = 0; i < 1000; i++)
      pts.push_back(gp_Pnt(i % 10, (i / 10) % 10, i / 100));
    NCollection_KDTree<gp_Pnt, 3> tree;
    tree.Build(pts.data(), pts.size());
    double sq = 0;
    size_t i  = tree.NearestPoint(gp_Pnt(4.4, 4.4, 4.4), sq);
    printf("KDTree 1000-point grid, nearest to (4.4,4.4,4.4): index=%zu point=(%g, %g, %g) distance=%.17g\n",
           i - 1, pts[i - 1].X(), pts[i - 1].Y(), pts[i - 1].Z(), std::sqrt(sq));
    i = tree.NearestPoint(gp_Pnt(4.5, 4.5, 4.5), sq);
    printf("KDTree 1000-point grid, nearest to (4.5,4.5,4.5): index=%zu distance=%.17g (an 8-way tie)\n", i - 1,
           std::sqrt(sq));
  }
  return 0;
}
