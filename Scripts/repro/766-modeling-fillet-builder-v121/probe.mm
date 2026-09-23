// Epic #766, Tests/OCCTModelingTests/FilletBuilderV121Tests.swift: kernel parity for all six
// tests. FilletBuilder is one BRepFilletAPI_MakeFillet: Add (OCCTFilletBuilderAddEdge /
// ...AddEdgeEvolving), NbContours, IsConstant, Radius (OCCTFilletBuilderGetRadius), NbEdges,
// Length (...GetLength), NbFaultyContours/Vertices, Reset, Remove (...RemoveEdge), Build.
// 20 mm box centred at the origin, edges in TopExp::MapShapes order, as Shape.edges() gives them.
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static TopoDS_Shape               B;
static TopTools_IndexedMapOfShape E;

static void reset()
{
  B = BRepPrimAPI_MakeBox(gp_Pnt(-10, -10, -10), 20, 20, 20).Shape();
  E.Clear();
  TopExp::MapShapes(B, TopAbs_EDGE, E);
}

static const char* built(BRepFilletAPI_MakeFillet& f)
{
  f.Build();
  if (!f.IsDone())
    return "notDone";
  return BRepCheck_Analyzer(f.Shape()).IsValid() ? "done,valid" : "done,INVALID";
}

int main()
{
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    f.Add(2.0, TopoDS::Edge(E(1)));
    printf("constant: edges=%d contours=%d isConstant=%d radius=%.17g ", E.Extent(), f.NbContours(),
           f.IsConstant(1), f.Radius(1));
    printf("build=%s\n", built(f));
  }
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    f.Add(1.0, 3.0, TopoDS::Edge(E(1)));
    printf("evolving: contours=%d isConstant=%d ", f.NbContours(), f.IsConstant(1));
    printf("build=%s\n", built(f));
  }
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    for (int i = 1; i <= 3; i++)
      f.Add(1.5, TopoDS::Edge(E(i)));
    printf("multiple: contours=%d ", f.NbContours());
    printf("build=%s\n", built(f));
  }
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    f.Add(2.0, TopoDS::Edge(E(1)));
    printf("diagnostics: nbEdges(1)=%d length(1)=%.17g faultyContours=%d faultyVertices=%d\n",
           f.NbEdges(1), f.Length(1), f.NbFaultyContours(), f.NbFaultyVertices());
  }
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    f.Add(2.0, TopoDS::Edge(E(1)));
    int before = f.NbContours();
    f.Reset();
    printf("reset: contoursBefore=%d contoursAfter=%d ", before, f.NbContours());
    printf("build=%s\n", built(f));
  }
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    f.Add(2.0, TopoDS::Edge(E(1)));
    int before = f.NbContours();
    f.Remove(TopoDS::Edge(E(1)));
    printf("remove: contoursBefore=%d contoursAfter=%d\n", before, f.NbContours());
  }
  return 0;
}
