// OCCTSwift#705 kernel-level reproducer: BRepFilletAPI_MakeFillet2d::AddChamfer(E1, E2, D1, D2)
// SIGSEGVs on the second call naming the same edge pair. Bypasses OCCTBridge entirely: exercises
// the OCCT C++ API this bridge wraps, directly, so the result speaks to the upstream defect on
// its own terms, independent of anything the bridge guard now does.
//
// Compile and run against the pinned kernel:
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     Scripts/repro/705-chamfer2d-duplicate-pair/occt_705_chamfer_dup.mm -o /tmp/occt_705_stock \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++
//   /tmp/occt_705_stock
//
// Crashes (SIGSEGV, exit 139) on the second AddChamfer call against the stock kernel. See this
// directory's README.md for the override-link "after" verification against
// Scripts/patches/0022-ChFi2d_Builder-AddChamfer-connexion-error-check-705.patch.

#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepFilletAPI_MakeFillet2d.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Pnt.hxx>
#include <vector>
#include <cstdio>

int main() {
  BRepBuilderAPI_MakePolygon poly;
  poly.Add(gp_Pnt(0, 0, 0));
  poly.Add(gp_Pnt(10, 0, 0));
  poly.Add(gp_Pnt(10, 10, 0));
  poly.Add(gp_Pnt(0, 10, 0));
  poly.Close();
  BRepBuilderAPI_MakeFace faceMaker(poly.Wire());
  TopoDS_Face face = faceMaker.Face();

  std::vector<TopoDS_Edge> edges;
  for (TopExp_Explorer ex(face, TopAbs_EDGE); ex.More(); ex.Next()) {
    edges.push_back(TopoDS::Edge(ex.Current()));
  }
  printf("edge count: %zu\n", edges.size());
  if (edges.size() < 2) {
    printf("FAIL: fewer than 2 edges\n");
    return 2;
  }

  BRepFilletAPI_MakeFillet2d chamfer(face);
  printf("about to call AddChamfer the FIRST time on edges (0,1)\n");
  fflush(stdout);
  TopoDS_Edge c1 = chamfer.AddChamfer(edges[0], edges[1], 1.0, 2.0);
  printf("first call returned, IsNull=%d, status=%d\n", c1.IsNull(), (int)chamfer.Status());
  fflush(stdout);

  printf("about to call AddChamfer the SECOND time on the SAME pair (0,1)\n");
  fflush(stdout);
  TopoDS_Edge c2 = chamfer.AddChamfer(edges[0], edges[1], 1.0, 2.0);
  printf("second call returned, IsNull=%d, status=%d\n", c2.IsNull(), (int)chamfer.Status());
  fflush(stdout);

  printf("PROBE: completed without crashing\n");
  return 0;
}
