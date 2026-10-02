// Epic #766 kernel-parity probe for OCCTBRepGraphTests, files:
//   BRepGraphEdgeDefTests, BRepGraphEdgeGeometryTests.
// Mirrors OCCTBRepGraphEdge{StartVertex,EndVertex} (Tool::Edge::Start/EndVertexId resolved
// through Refs().Vertices().Entry(ref).ChildVertexId), OCCTBRepGraphEdgeIsClosed,
// IsDegenerated, Tolerance, Range, HasCurve, IsClosedOnFace (Tool::Edge::IsSeamOnFace),
// EdgeFaceIndices (BRepGraph_FacesOfEdge) and IsSameParameter / IsSameRange (the first coedge
// found by Tool::Edge::FindCoEdgeId over the faces, then Tool::CoEdge::SameParameter/Range).
// OCCTBRepGraphEdgeMaxContinuity has no kernel call: the bridge returns 0 unconditionally
// because BRepGraph_LayerRegularity is absent from the pinned libOCCT.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_RefsView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_ReverseIterator.hxx>
#include <cstdio>

static void build(BRepGraph& g, const TopoDS_Shape& s)
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  g.Shapes().Add(s, opts);
}

static int vdef(BRepGraph& g, BRepGraph_VertexRefId r)
{
  if (!r.IsValid())
    return -1;
  auto d = g.Refs().Vertices().Entry(r).ChildVertexId;
  return d.IsValid() ? (int)d.Index : -1;
}

static BRepGraph_CoEdgeId firstCoEdge(BRepGraph& g, int e)
{
  for (uint32_t f = 0; f < (uint32_t)g.Topo().Faces().Nb(); ++f)
  {
    auto c = BRepGraph_Tool::Edge::FindCoEdgeId(g, BRepGraph_EdgeId(e), BRepGraph_FaceId(f));
    if (c.IsValid())
      return c;
  }
  return BRepGraph_CoEdgeId();
}

static void dump(const char* label, BRepGraph& g)
{
  printf("%s: edges=%d vertices=%d\n", label, g.Topo().Edges().Nb(), g.Topo().Vertices().Nb());
  for (int e = 0; e < g.Topo().Edges().Nb(); ++e)
  {
    BRepGraph_EdgeId id(e);
    auto             r = BRepGraph_Tool::Edge::Range(g, id);
    auto             c = firstCoEdge(g, e);
    printf("  edge %2d: start=%d end=%d closed=%d degen=%d tol=%.17g range=(%.17g, %.17g) "
           "hasCurve=%d sameParam=%d sameRange=%d faces=[",
           e, vdef(g, BRepGraph_Tool::Edge::StartVertexId(g, id)),
           vdef(g, BRepGraph_Tool::Edge::EndVertexId(g, id)),
           (int)BRepGraph_Tool::Edge::IsClosed(g, id), (int)BRepGraph_Tool::Edge::Degenerated(g, id),
           BRepGraph_Tool::Edge::Tolerance(g, id), r.first, r.second,
           (int)BRepGraph_Tool::Edge::HasCurve(g, id),
           c.IsValid() ? (int)BRepGraph_Tool::CoEdge::SameParameter(g, c) : 1,
           c.IsValid() ? (int)BRepGraph_Tool::CoEdge::SameRange(g, c) : 1);
    for (BRepGraph_FacesOfEdge it(g, id); it.More(); it.Next())
    {
      int f = (int)it.CurrentId().Index;
      printf(" %d(seam=%d)", f,
             (int)BRepGraph_Tool::Edge::IsSeamOnFace(g, id, BRepGraph_FaceId(f)));
    }
    printf(" ]\n");
  }
}

int main()
{
  BRepGraph b;
  build(b, BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape());
  dump("box", b);
  BRepGraph s;
  build(s, BRepPrimAPI_MakeSphere(5).Shape());
  dump("sphere", s);
  return 0;
}
