// Epic #766 evidence correction for PR #2694 (Tests/OCCTModelingTests/FilletBuilderV121Tests.swift).
// probe.mm printed the kernel side under the OCCT member names (NbContours, IsConstant, Radius, ...)
// and as prose ("done, valid") while the bridge side used the Swift names. The parity records now
// carry the same keys and types on both sides, so this probe repeats the same calls under those
// keys, every flag as true/false and every double at %.17g, one `label: key=value ...` line per test.
// Mapping: edges = the box's TopExp::MapShapes edge count, contourCount = NbContours(), isConstant =
// IsConstant(1), radius = Radius(1), buildValid = Build() IsDone and BRepCheck_Analyzer valid,
// added = the number of Add calls that did not throw (what FilletBuilder.addEdge returns),
// edgeCount = NbEdges(1), length = Length(1), faultyContours/faultyVertices = NbFaultyContours/
// NbFaultyVertices, contourCountBefore/After = NbContours() around Reset() or Remove(),
// removed = Remove did not throw (what FilletBuilder.removeEdge returns).
// 20 mm box centred at the origin, edges in TopExp::MapShapes order, as Shape.edges() gives them.
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static const char* tf(bool b) { return b ? "true" : "false"; }

static TopoDS_Shape               B;
static TopTools_IndexedMapOfShape E;

static void reset()
{
  B = BRepPrimAPI_MakeBox(gp_Pnt(-10, -10, -10), 20, 20, 20).Shape();
  E.Clear();
  TopExp::MapShapes(B, TopAbs_EDGE, E);
}

static bool buildValid(BRepFilletAPI_MakeFillet& f)
{
  f.Build();
  return f.IsDone() && BRepCheck_Analyzer(f.Shape()).IsValid();
}

int main()
{
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    f.Add(2.0, TopoDS::Edge(E(1)));
    printf("filletBuilderConstantRadius: edges=%d contourCount=%d isConstant=%s radius=%.17g", E.Extent(),
           f.NbContours(), tf(f.IsConstant(1)), f.Radius(1));
    printf(" buildValid=%s\n", tf(buildValid(f)));
  }
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    f.Add(1.0, 3.0, TopoDS::Edge(E(1)));
    printf("filletBuilderEvolvingRadius: contourCount=%d isConstant=%s", f.NbContours(), tf(f.IsConstant(1)));
    printf(" buildValid=%s\n", tf(buildValid(f)));
  }
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    int                      added = 0;
    for (int i = 1; i <= 3; i++)
    {
      try
      {
        f.Add(1.5, TopoDS::Edge(E(i)));
        added++;
      }
      catch (Standard_Failure&)
      {
      }
    }
    printf("filletBuilderMultipleEdges: added=%d contourCount=%d", added, f.NbContours());
    printf(" buildValid=%s\n", tf(buildValid(f)));
  }
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    f.Add(2.0, TopoDS::Edge(E(1)));
    printf("filletBuilderDiagnostics: edgeCount=%d length=%.17g faultyContours=%d faultyVertices=%d\n",
           f.NbEdges(1), f.Length(1), f.NbFaultyContours(), f.NbFaultyVertices());
  }
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    f.Add(2.0, TopoDS::Edge(E(1)));
    int before = f.NbContours();
    f.Reset();
    printf("filletBuilderReset: contourCountBefore=%d contourCountAfter=%d", before, f.NbContours());
    printf(" buildValid=%s\n", tf(buildValid(f)));
  }
  {
    reset();
    BRepFilletAPI_MakeFillet f(B);
    f.Add(2.0, TopoDS::Edge(E(1)));
    int  before  = f.NbContours();
    bool removed = true;
    try
    {
      f.Remove(TopoDS::Edge(E(1)));
    }
    catch (Standard_Failure&)
    {
      removed = false;
    }
    printf("filletBuilderRemoveEdge: removed=%s contourCountBefore=%d contourCountAfter=%d\n", tf(removed), before,
           f.NbContours());
  }
  return 0;
}
