// Epic #766, Tests/OCCTModelingTests/Issue633BlendedEdgesDuplicateReportTests.swift: kernel parity
// for all seven tests. blendedEdges / blendedEdgesWithReport are OCCTShapeBlendEdges:
// BRepFilletAPI_MakeFillet::Add(R, E) per entry, declined edges read back as Contour(E) == 0
// (occtFilletDeclinedIndices), Build. overwrittenDuplicateIndices is pure Swift bookkeeping over the
// request list and has no kernel counterpart; what the kernel does own is the geometry of a repeated
// edge (last Add wins), printed here.
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <algorithm>
#include <cstdio>
#include <utility>
#include <vector>

static double vol(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::VolumeProperties(s, p);
  return p.Mass();
}
static double area(const TopoDS_Shape& s)
{
  GProp_GProps p;
  BRepGProp::SurfaceProperties(s, p);
  return p.Mass();
}

static TopoDS_Shape blend(const TopoDS_Shape& s, std::vector<std::pair<int, double>> req, std::vector<int>* declined = nullptr)
{
  TopTools_IndexedMapOfShape e;
  TopExp::MapShapes(s, TopAbs_EDGE, e);
  BRepFilletAPI_MakeFillet f(s);
  for (auto& r : req)
    f.Add(r.second, TopoDS::Edge(e(r.first + 1)));
  if (declined)
    for (auto& r : req)
      if (f.Contour(TopoDS::Edge(e(r.first + 1))) == 0)
        declined->push_back(r.first);
  f.Build();
  return f.IsDone() ? f.Shape() : TopoDS_Shape();
}

int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  printf("duplicated edge 0 (2 then 5): volume=%.9f; edge 0 at 5 only: %.9f; at 2 only: %.9f\n", vol(blend(box, {{0, 2}, {0, 5}})),
         vol(blend(box, {{0, 5}})), vol(blend(box, {{0, 2}})));
  printf("triple edge 0 (2, 3, 5): volume=%.9f\n", vol(blend(box, {{0, 2}, {0, 3}, {0, 5}})));
  std::vector<int> d;
  TopoDS_Shape     distinct = blend(box, {{0, 1}, {1, 2}, {2, 0.5}}, &d);
  printf("distinct (0,1),(1,2),(2,0.5): done=%d declined=%zu\n", !distinct.IsNull(), d.size());

  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  BRepBuilderAPI_Sewing sew(1e-6);
  for (int i = 2; i <= 6; i++)
    sew.Add(faces(i));
  sew.Perform();
  TopoDS_Shape                        shell = sew.SewedShape();
  TopTools_IndexedMapOfShape          se;
  TopExp::MapShapes(shell, TopAbs_EDGE, se);
  std::vector<std::pair<int, double>> all;
  for (int i = 0; i < se.Extent(); i++)
    all.push_back({i, 1.0});
  std::vector<int> dec;
  TopoDS_Shape     r = blend(shell, all, &dec);
  printf("open shell: edges=%d declined=[", se.Extent());
  for (size_t i = 0; i < dec.size(); i++)
    printf("%s%d", i ? "," : "", dec[i]);
  printf("] area=%.9f\n", area(r));
  int accepted = 0;
  while (std::find(dec.begin(), dec.end(), accepted) != dec.end())
    accepted++;
  std::vector<std::pair<int, double>> mix = {{accepted, 1.0}, {accepted, 2.0}};
  for (int i : dec)
    mix.push_back({i, 1.0});
  std::vector<int> dec2;
  blend(shell, mix, &dec2);
  printf("duplicate accepted edge %d + the declined ones: declined=[", accepted);
  for (size_t i = 0; i < dec2.size(); i++)
    printf("%s%d", i ? "," : "", dec2[i]);
  printf("]\n");

  std::vector<std::pair<int, double>> boxAll;
  for (int i = 0; i < 12; i++)
    boxAll.push_back({i, 1.0});
  std::vector<int> dec3;
  TopoDS_Shape     rb = blend(box, boxAll, &dec3);
  printf("closed box, all 12 edges r=1: done=%d declined=%zu\n", !rb.IsNull(), dec3.size());
  return 0;
}
