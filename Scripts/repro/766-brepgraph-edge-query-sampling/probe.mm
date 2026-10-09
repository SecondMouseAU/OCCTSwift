// Epic #766 kernel-parity probe for OCCTBRepGraphTests, files:
//   BRepGraphEdgeQueryTests, BRepGraphEdgeSamplingTests.
// Mirrors OCCTBRepGraphEdgeNbFaces (Topo().Edges().NbFaces), EdgeFaceIndices
// (BRepGraph_FacesOfEdge), EdgeIsBoundary / EdgeIsManifold (Tool::Edge::IsBoundary /
// IsManifold), EdgeAdjacentIndices (edges sharing a vertex, via Topo().Vertices().Edges),
// OCCTBRepGraphCopyFace (Clear() + BRepGraph_Copy::CopyNode) and OCCTBRepGraphSampleEdgeCurve
// (Tool::Edge::Curve evaluated at count evenly spaced parameters over Tool::Edge::Range).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_ReverseIterator.hxx>
#include <BRepGraph_Copy.hxx>
#include <Geom_Curve.hxx>
#include <Standard_Failure.hxx>
#include <set>
#include <cstdio>

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static void build(BRepGraph& g, const TopoDS_Shape& s)
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  g.Shapes().Add(s, opts);
}

static void sample(BRepGraph& g, int e, int count)
{
  BRepGraph_EdgeId id(e);
  if (!BRepGraph_Tool::Edge::HasCurve(g, id))
  {
    printf("  edge %d count %d: no curve -> 0 points\n", e, count);
    return;
  }
  const auto& c     = BRepGraph_Tool::Edge::Curve(g, id);
  auto        r     = BRepGraph_Tool::Edge::Range(g, id);
  double      step  = count > 1 ? (r.second - r.first) / (count - 1) : 0.0;
  double      maxDr = 0;
  printf("  edge %d count %d:", e, count);
  for (int i = 0; i < count; ++i)
  {
    gp_Pnt p = c->Value(r.first + i * step);
    maxDr    = std::max(maxDr, std::abs(p.Distance(gp_Pnt(0, 0, 0)) - 5.0));
    if (i == 0 || i == count - 1)
      printf(" p[%d]=(%.17g, %.17g, %.17g)", i, p.X(), p.Y(), p.Z());
  }
  printf(" max|r-5|=%.3g\n", maxDr);
}

int main()
{
  {
    BRepGraph g;
    build(g, box(10, 20, 30));
    printf("edgeFaceCount/edgeFaces (box 10x20x30): nbFaces=%d faces=[",
           g.Topo().Edges().NbFaces(BRepGraph_EdgeId(0)));
    for (BRepGraph_FacesOfEdge it(g, BRepGraph_EdgeId(0)); it.More(); it.Next())
      printf(" %d", (int)it.CurrentId().Index);
    printf(" ]\n");
  }
  BRepGraph b;
  build(b, box(10, 10, 10));
  int nb = 0, nm = 0;
  for (int e = 0; e < b.Topo().Edges().Nb(); ++e)
  {
    nb += BRepGraph_Tool::Edge::IsBoundary(b, BRepGraph_EdgeId(e)) ? 1 : 0;
    nm += BRepGraph_Tool::Edge::IsManifold(b, BRepGraph_EdgeId(e)) ? 1 : 0;
  }
  printf("box: edges=%d boundary=%d manifold=%d\n", b.Topo().Edges().Nb(), nb, nm);
  {
    BRepGraph f;
    f.Clear();
    BRepGraph_Copy::CopyNode(b, f, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 0),
                             BRepGraph_Copy::GeomPolicy::Copy);
    printf("copyFace(0): edges=%d boundary=[", f.Topo().Edges().Nb());
    for (int e = 0; e < f.Topo().Edges().Nb(); ++e)
      printf(" %d", (int)BRepGraph_Tool::Edge::IsBoundary(f, BRepGraph_EdgeId(e)));
    printf(" ] manifold=[");
    for (int e = 0; e < f.Topo().Edges().Nb(); ++e)
      printf(" %d", (int)BRepGraph_Tool::Edge::IsManifold(f, BRepGraph_EdgeId(e)));
    printf(" ]\n");
  }
  {
    std::set<int> adj;
    for (int v = 0; v < b.Topo().Vertices().Nb(); ++v)
    {
      const auto& edges = b.Topo().Vertices().Edges(BRepGraph_VertexId(v));
      bool        has   = false;
      for (int i = 0; i < edges.Size(); ++i)
        has = has || (int)edges(i).Index == 0;
      if (has)
        for (int i = 0; i < edges.Size(); ++i)
          if ((int)edges(i).Index != 0)
            adj.insert((int)edges(i).Index);
    }
    printf("edgeAdjacency(0): [");
    for (int e : adj)
      printf(" %d", e);
    printf(" ]\n");
  }
  printf("sampling box:\n");
  sample(b, 0, 10);
  sample(b, 0, 1);
  try
  {
    printf("  edge 999: hasCurve=%d\n",
           (int)BRepGraph_Tool::Edge::HasCurve(b, BRepGraph_EdgeId(999)));
  }
  catch (const std::exception& e)
  {
    printf("  edge 999: HasCurve throws %s -> bridge catch returns 0 points\n",
           e.what());
  }
  BRepGraph s;
  build(s, BRepPrimAPI_MakeSphere(5).Shape());
  printf("sampling sphere:\n");
  for (int e = 0; e < s.Topo().Edges().Nb(); ++e)
    sample(s, e, 20);
  return 0;
}
