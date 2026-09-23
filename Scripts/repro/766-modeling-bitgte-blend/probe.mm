// Epic #766, Tests/OCCTModelingTests/BiTgteBlendTests.swift: kernel parity for both tests.
// OCCTBiTgteBlend is BiTgte_Blend(shape, radius, tol=1e-3, nubs=false), SetEdge per index into
// the TopExp::MapShapes edge enumeration, Perform(true). Same inputs here.
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BiTgte_Blend.hxx>
#include <GProp_GProps.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void blend(const char* label, double w, double h, double d, std::initializer_list<int> idx, double r)
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), w, h, d).Shape();
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  BiTgte_Blend b(box, r, 1e-3, false);
  for (int i : idx)
    b.SetEdge(TopoDS::Edge(edges(i + 1)));
  b.Perform(true);
  printf("%s: done=%d", label, b.IsDone());
  if (b.IsDone() && !b.Shape().IsNull())
  {
    GProp_GProps p;
    BRepGProp::VolumeProperties(b.Shape(), p);
    int faces = 0;
    for (TopExp_Explorer ex(b.Shape(), TopAbs_FACE); ex.More(); ex.Next())
      faces++;
    printf(" type=%d faces=%d valid=%d volume=%.10g boxVolume=%.10g", (int)b.Shape().ShapeType(), faces,
           BRepCheck_Analyzer(b.Shape()).IsValid(), p.Mass(), w * h * d);
  }
  printf("\n");
}

int main()
{
  blend("blendBoxEdge", 100, 80, 60, {0}, 5);
  blend("blendMultipleEdges", 50, 50, 50, {0, 1}, 3);
  return 0;
}
