// Epic #766 evidence fix, Tests/OCCTModelingTests/LocOpeSplitShapeTests.swift.
// probe.mm printed the split point at %g and only counted the vertices. This probe repeats the bridge's
// call (OCCTLocOpeSplitShapeByVertex: edge 0 of TopExp::MapShapes(EDGE), the normalized parameter 0.5
// mapped onto BRep_Tool::Range, LocOpe_SplitShape::Add(vertex, param, edge), DescendantShapes(edge)
// gathered into a compound) and prints, at %.17g, the descendant count and every vertex of the compound in
// TopExp::MapShapes order, which is the order Shape.vertices() reports.
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Curve.hxx>
#include <LocOpe_SplitShape.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape edges;
  TopExp::MapShapes(box, TopAbs_EDGE, edges);
  TopoDS_Edge e = TopoDS::Edge(edges(1));
  double      f, l;
  BRep_Tool::Range(e, f, l);
  double             u = f + 0.5 * (l - f);
  Handle(Geom_Curve) c = BRep_Tool::Curve(e, f, l);
  gp_Pnt             p;
  c->D0(u, p);
  LocOpe_SplitShape sp(box);
  sp.Add(BRepBuilderAPI_MakeVertex(p), u, e);
  const auto&     d = sp.DescendantShapes(e);
  BRep_Builder    b;
  TopoDS_Compound comp;
  b.MakeCompound(comp);
  for (auto it = d.begin(); it != d.end(); ++it)
    b.Add(comp, *it);
  TopTools_IndexedMapOfShape ce, cv;
  TopExp::MapShapes(comp, TopAbs_EDGE, ce);
  TopExp::MapShapes(comp, TopAbs_VERTEX, cv);
  printf("splitEdge: range=[%.17g, %.17g] parameter=%.17g splitPoint=(%.17g, %.17g, %.17g)\n", f, l, u, p.X(), p.Y(), p.Z());
  printf("splitEdge: descendants=%d edges=%d vertices=%d\n", (int)d.Size(), ce.Extent(), cv.Extent());
  for (int i = 1; i <= cv.Extent(); i++)
  {
    gp_Pnt q = BRep_Tool::Pnt(TopoDS::Vertex(cv(i)));
    printf("splitEdge: vertex %d = (%.17g, %.17g, %.17g)\n", i - 1, q.X(), q.Y(), q.Z());
  }
  return 0;
}
