// Epic #766 evidence fix, Tests/OCCTModelingTests/Issue633BlendedEdgesDuplicateReportTests.swift.
// probe.mm printed volumes at %.9f, gave the declined edges of the distinct and closed-box requests as a count
// and did not compute the declined list of the duplicated-edge request. This probe repeats OCCTShapeBlendEdges
// for every request the tests make (BRepFilletAPI_MakeFillet::Add(R, E) per entry in request order, declined
// edges read back as Contour(E) == 0 before Build, then Build; a result only when IsDone()) and prints, at
// %.17g, whether a shape came back, the declined edge indices in request order, and the volume or area.
// overwrittenDuplicateIndices is Swift bookkeeping over the request list, with no kernel counterpart, so it is
// not measured here. The open shell is the test fixture: the 10 mm box's faces 2 to 6 sewn at 1e-6.
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

using Request = std::vector<std::pair<int, double>>;

static void blend(const char* label, const TopoDS_Shape& s, const Request& req, bool useArea)
{
  TopTools_IndexedMapOfShape e;
  TopExp::MapShapes(s, TopAbs_EDGE, e);
  BRepFilletAPI_MakeFillet f(s);
  for (auto& r : req)
    f.Add(r.second, TopoDS::Edge(e(r.first + 1)));
  std::vector<int> declined;
  for (auto& r : req)
    if (f.Contour(TopoDS::Edge(e(r.first + 1))) == 0)
      declined.push_back(r.first);
  f.Build();
  bool produced = f.IsDone() && !f.Shape().IsNull();
  printf("%s: produced=%d declined=[", label, produced);
  for (size_t i = 0; i < declined.size(); i++)
    printf("%s%d", i ? "," : "", declined[i]);
  printf("]");
  if (produced)
    printf(" %s=%.17g", useArea ? "area" : "volume", useArea ? area(f.Shape()) : vol(f.Shape()));
  printf("\n");
}

int main()
{
  // Shape.box(width:height:depth:) is centred on the origin.
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  blend("t1 duplicated edge 0 (2 then 5)", box, {{0, 2}, {0, 5}}, false);
  blend("t1 edge 0 at 5 only", box, {{0, 5}}, false);
  blend("t1 edge 0 at 2 only", box, {{0, 2}}, false);
  blend("t2 triple edge 0 (2, 3, 5)", box, {{0, 2}, {0, 3}, {0, 5}}, false);
  blend("t3 distinct (0,1), (1,2), (2,0.5)", box, {{0, 1}, {1, 2}, {2, 0.5}}, false);

  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  BRepBuilderAPI_Sewing sew(1e-6);
  for (int i = 2; i <= 6; i++)
    sew.Add(faces(i));
  sew.Perform();
  TopoDS_Shape               shell = sew.SewedShape();
  TopTools_IndexedMapOfShape se;
  TopExp::MapShapes(shell, TopAbs_EDGE, se);
  printf("open shell: edges=%d\n", se.Extent());
  Request all;
  for (int i = 0; i < se.Extent(); i++)
    all.push_back({i, 1.0});
  blend("t4 open shell, every edge r=1", shell, all, true);

  // t5: the first accepted edge twice, then every declined edge once.
  TopTools_IndexedMapOfShape sh;
  TopExp::MapShapes(shell, TopAbs_EDGE, sh);
  BRepFilletAPI_MakeFillet probe(shell);
  for (auto& r : all)
    probe.Add(r.second, TopoDS::Edge(sh(r.first + 1)));
  std::vector<int> dec;
  for (auto& r : all)
    if (probe.Contour(TopoDS::Edge(sh(r.first + 1))) == 0)
      dec.push_back(r.first);
  int accepted = 0;
  while (std::find(dec.begin(), dec.end(), accepted) != dec.end())
    accepted++;
  Request mix = {{accepted, 1.0}, {accepted, 2.0}};
  for (int i : dec)
    mix.push_back({i, 1.0});
  printf("t5 accepted edge index=%d\n", accepted);
  blend("t5 accepted edge twice + the declined ones", shell, mix, true);

  Request boxAll;
  for (int i = 0; i < 12; i++)
    boxAll.push_back({i, 1.0});
  blend("t7 closed box, every edge r=1", box, boxAll, false);
  return 0;
}
