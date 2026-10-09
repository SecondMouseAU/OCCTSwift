// OCCT tests/bugs/moddata_1/bug119 transcribed: `blend` on `explode`d edges of a 100 box.
//   bug119                (the test as written: stage 1 then stage 2)
// The Draw script passes if stage 1 throws; otherwise it checks stage 1, then runs stage 2 and checkshape.
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_MapOfShape.hxx>
#include <Standard_Failure.hxx>
#include <vector>
#include <cstdio>
static std::vector<TopoDS_Edge> explodeEdges(const TopoDS_Shape& s)
{
  std::vector<TopoDS_Edge> v; TopTools_MapOfShape seen;
  for (TopExp_Explorer e(s, TopAbs_EDGE); e.More(); e.Next())
    if (seen.Add(e.Current())) v.push_back(TopoDS::Edge(e.Current()));
  return v;
}
static void rep(const char* t, BRepFilletAPI_MakeFillet& mk)
{
  if (!mk.IsDone()) { printf("RESULT %s done=0\n", t); return; }
  GProp_GProps p; BRepGProp::VolumeProperties(mk.Shape(), p);
  printf("RESULT %s done=1 valid=%d vol=%.6f\n", t, (int)BRepCheck_Analyzer(mk.Shape()).IsValid(), p.Mass());
}
int main()
{
  try {
    TopoDS_Shape a = BRepPrimAPI_MakeBox(100, 100, 100).Shape();
    auto e = explodeEdges(a);
    BRepFilletAPI_MakeFillet m1(a);
    for (int i : {10, 5, 12, 3}) m1.Add(50, e[i - 1]);
    m1.Build(); rep("stage1", m1);
    if (!m1.IsDone()) return 0;
    TopoDS_Shape r1 = m1.Shape();
    auto e2 = explodeEdges(r1);
    BRepFilletAPI_MakeFillet m2(r1);
    for (int i : {20, 22, 10}) m2.Add(50, e2[i - 1]);
    m2.Build(); rep("stage2", m2);
  } catch (Standard_Failure& f) { printf("RESULT exception %s\n", f.GetMessageString()); }
}
