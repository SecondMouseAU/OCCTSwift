// OCCT tests/bugs/modalg_7/bug25478_1 and _2 ("Fillets can not touch", both carry a TODO that expects
// the failure) transcribed: `blend` on `explode`d edges. Prints the outcome for each.
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_MapOfShape.hxx>
#include <Standard_Failure.hxx>
#include <gp_Trsf.hxx>
#include <vector>
#include <cstdio>
static std::vector<TopoDS_Edge> explodeEdges(const TopoDS_Shape& s)
{
  std::vector<TopoDS_Edge> v; TopTools_MapOfShape seen;
  for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
    if (seen.Add(e.Current())) v.push_back(TopoDS::Edge(e.Current()));
  return v;
}
static void run(const char* t, const TopoDS_Shape& s, double r, std::vector<int> idx)
{
  try {
    auto e = explodeEdges(s);
    BRepFilletAPI_MakeFillet mk(s);
    for (int i : idx) mk.Add(r, e[i - 1]);
    mk.Build();
    if (!mk.IsDone()) { printf("RESULT %s done=0\n", t); return; }
    GProp_GProps p; BRepGProp::VolumeProperties(mk.Shape(), p);
    printf("RESULT %s done=1 valid=%d vol=%.6f\n", t, (int)BRepCheck_Analyzer(mk.Shape()).IsValid(), p.Mass());
  } catch (Standard_Failure& f) { printf("RESULT %s exception %s\n", t, f.GetMessageString()); }
}
int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
  run("bug25478_1", box, 5, {1, 3});
  // OCCT#1177 samples: `blend result box 5 box_10 5 box_9` (two sides, meeting) and `blend result box 10 box_10` (one side, r = w)
  run("1177_two_sides_r5", box, 5, {10, 9});
  run("1177_one_side_r10", box, 10, {10});
  run("1177_two_sides_r4.99", box, 4.99, {10, 9});
  TopoDS_Shape b2 = BRepPrimAPI_MakeBox(10, 10, 12).Shape();
  gp_Trsf t; t.SetTranslation(gp_Vec(5, 5, -1));
  b2 = BRepBuilderAPI_Transform(b2, t, true).Shape();
  TopoDS_Shape cut = BRepAlgoAPI_Cut(box, b2).Shape();
  run("bug25478_2", cut, 2.5, {13, 17, 18});
}
