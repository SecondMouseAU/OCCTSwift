// Epic #766, Tests/OCCTModelingTests/MultiEdgeBlendTests.swift: kernel parity for all three tests.
// OCCTShapeBlendEdges runs occtShapeFilletEdgeList: BRepFilletAPI_MakeFillet, Add(radius_i, edge_i)
// for each (TopExp::MapShapes(EDGE) index, radius), Build(), nullptr unless IsDone(). An empty
// list is refused by Swift (and by the helper, edgeCount < 1) before any kernel call.
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void blend(const char* label, double s, std::initializer_list<std::pair<int, double>> er)
{
  TopoDS_Shape               b = BRepPrimAPI_MakeBox(gp_Pnt(-s / 2, -s / 2, -s / 2), s, s, s).Shape();
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(b, TopAbs_EDGE, edges);
  BRepFilletAPI_MakeFillet mf(b);
  for (auto& p : er)
    mf.Add(p.second, TopoDS::Edge(edges(p.first + 1)));
  mf.Build();
  printf("%s: done=%d", label, mf.IsDone());
  if (mf.IsDone())
  {
    TopTools_IndexedMapOfShape f;
    TopExp::MapShapes(mf.Shape(), TopAbs_FACE, f);
    GProp_GProps p;
    BRepGProp::VolumeProperties(mf.Shape(), p);
    printf(" valid=%d faces=%d volume=%.10g", BRepCheck_Analyzer(mf.Shape()).IsValid(), f.Extent(), p.Mass());
  }
  printf("\n");
}

int main()
{
  blend("blendMultipleEdges", 20, {{0, 1.0}, {1, 2.0}, {2, 1.5}});
  blend("blendSingleEdge", 10, {{0, 1.0}});
  printf("blendEmptyArray: no kernel call (Swift and the bridge helper both refuse an empty list)\n");
  return 0;
}
