// #1036: IsDeleted on edges and vertices of a filleted/chamfered box
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <NCollection_IndexedMap.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <cstdio>
template <class M> void run(const char* name, M& mk, const TopoDS_Shape& box, const TopoDS_Shape& e0)
{
  mk.Build();
  const TopoDS_Shape& r = mk.Shape();
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> inRes[3];
  TopAbs_ShapeEnum T[3] = {TopAbs_VERTEX, TopAbs_EDGE, TopAbs_FACE};
  for (int k = 0; k < 3; ++k) TopExp::MapShapes(r, T[k], inRes[k]);
  for (int k = 0; k < 3; ++k)
  {
    NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> orig; TopExp::MapShapes(box, T[k], orig);
    int wrong = 0, kept = 0;
    for (int i = 1; i <= orig.Extent(); ++i)
    {
      if (inRes[k].Contains(orig(i))) { ++kept; if (mk.IsDeleted(orig(i))) ++wrong; }
    }
    printf("%s %s: original %d, present unchanged in the result %d, of those IsDeleted()==true: %d\n", name, k == 0 ? "vertices" : k == 1 ? "edges" : "faces", orig.Extent(), kept, wrong);
  }
}
int main()
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10, 10, 10).Shape();
  NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher> E; TopExp::MapShapes(box, TopAbs_EDGE, E);
  { BRepFilletAPI_MakeFillet f(box); f.Add(1.0, TopoDS::Edge(E(1))); run("fillet", f, box, E(1)); }
  { BRepFilletAPI_MakeChamfer c(box); c.Add(1.0, TopoDS::Edge(E(1))); run("chamfer", c, box, E(1)); }
}
