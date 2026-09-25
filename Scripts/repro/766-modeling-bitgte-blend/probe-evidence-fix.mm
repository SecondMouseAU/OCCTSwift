// Epic #766 evidence correction for PR #2666 (Tests/OCCTModelingTests/BiTgteBlendTests.swift).
// probe.mm printed the kernel side at %.10g; the parity records now carry the same keys on both
// sides, so this probe repeats the same OCCT calls and prints every flag as true/false, the shape
// type by its OCCT name and every double at %.17g, one `label: key=value ...` line per test.
// OCCTBiTgteBlend is BiTgte_Blend(shape, radius, tol=1e-3, nubs=false), SetEdge per index into
// the TopExp::MapShapes edge enumeration, Perform(true). Same inputs as the Swift tests.
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BiTgte_Blend.hxx>
#include <GProp_GProps.hxx>
#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static const char* tf(bool b) { return b ? "true" : "false"; }

static void blend(const char* label, double w, double h, double d, std::initializer_list<int> idx, double r)
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), w, h, d).Shape();
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  BiTgte_Blend b(box, r, 1e-3, false);
  for (int i : idx)
    b.SetEdge(TopoDS::Edge(edges(i + 1)));
  b.Perform(true);
  bool done = b.IsDone() && !b.Shape().IsNull();
  printf("%s: done=%s", label, tf(done));
  if (done)
  {
    GProp_GProps p;
    BRepGProp::VolumeProperties(b.Shape(), p);
    int faces = 0;
    for (TopExp_Explorer ex(b.Shape(), TopAbs_FACE); ex.More(); ex.Next())
      faces++;
    printf(" type=\"%s\" faces=%d valid=%s volume=%.17g", TopAbs::ShapeTypeToString(b.Shape().ShapeType()), faces,
           tf(BRepCheck_Analyzer(b.Shape()).IsValid()), p.Mass());
  }
  printf("\n");
}

int main()
{
  blend("blendBoxEdge", 100, 80, 60, {0}, 5);
  blend("blendMultipleEdges", 50, 50, 50, {0, 1}, 3);
  return 0;
}
