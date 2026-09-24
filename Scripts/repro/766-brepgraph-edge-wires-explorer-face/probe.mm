// Epic #766 kernel-parity probe for OCCTBRepGraphTests, files:
//   BRepGraphEdgeWiresCoEdgesTests, BRepGraphExplorerTests, BRepGraphFaceDefTests,
//   BRepGraphFaceGeometryTests.
// Mirrors OCCTBRepGraphEdgeWireIndices (BRepGraph_WiresOfEdge), EdgeCoEdgeIndices
// (Topo().Edges().CoEdges), EdgeFindCoEdge (Tool::Edge::FindCoEdgeId), LinkProductToTopology
// (Editor().Products().Add + AppendDocumentRoot), RootNodes (RootProductIds), ChildCount
// (BRepGraph_ChildExplorer), ParentCount (BRepGraph_ParentExplorer), FaceNbWires
// (Tool::Face::NbWires), FaceNbVertexRefs (supplement FaceDirectVertex attachments, added by
// OCCTBRepGraphFaceAddVertex via Editor().Supplement().AttachToFace), FaceTolerance,
// FaceHasSurface, FaceIsNaturalRestriction (NbWires == 0) and FaceHasTriangulation
// (Mesh().Effective().Faces().Has).
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_MeshView.hxx>
#include <BRepGraph_ReverseIterator.hxx>
#include <BRepGraph_ChildExplorer.hxx>
#include <BRepGraph_ParentExplorer.hxx>
#include <BRepGraph_SupplementEditor.hxx>
#include <BRepGraph_SupplementIterator.hxx>
#include <BRepGraph_LayerTopoSupplement.hxx>
#include <cstdio>

static TopoDS_Shape box10()
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
}

static void build(BRepGraph& g, const TopoDS_Shape& s)
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  g.Shapes().Add(s, opts);
}

static int nFaceVertexRefs(BRepGraph& g, int f)
{
  int n = 0;
  for (BRepGraph_SupplementIterator it(g, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, f));
       it.More(); it.Next())
    if (it.Value().Kind == BRepGraph_LayerTopoSupplement::AttachmentKind::FaceDirectVertex)
      ++n;
  return n;
}

int main()
{
  BRepGraph g;
  build(g, box10());
  printf("box edges:\n");
  for (int e = 0; e < g.Topo().Edges().Nb(); ++e)
  {
    BRepGraph_EdgeId id(e);
    printf("  edge %2d wires=[", e);
    for (BRepGraph_WiresOfEdge it(g, id); it.More(); it.Next())
      printf(" %d", (int)it.CurrentId().Index);
    printf(" ] coedges=[");
    const auto& ce = g.Topo().Edges().CoEdges(id);
    for (size_t i = 0; i < ce.Size(); ++i)
      printf(" %d", (int)ce.Value(i).Index);
    printf(" ] findCoEdge(firstFace)=");
    BRepGraph_FacesOfEdge fit(g, id);
    int                   f0 = fit.More() ? (int)fit.CurrentId().Index : -1;
    auto c = BRepGraph_Tool::Edge::FindCoEdgeId(g, id, BRepGraph_FaceId(f0));
    printf("%d (face %d)\n", c.IsValid() ? (int)c.Index : -1, f0);
  }
  {
    BRepGraph p;
    build(p, box10());
    auto pid = p.Editor().Products().Add(
      BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0), TopLoc_Location());
    if (pid.IsValid())
      p.Editor().Products().AppendDocumentRoot(pid);
    const auto& roots = p.RootProductIds();
    printf("childExplorer: product=%d roots=%d", (int)pid.Index, (int)roots.Size());
    if (roots.Size() > 0)
    {
      BRepGraph_NodeId root(BRepGraph_NodeId::Kind::Product, roots(0).Index);
      int              faces = 0, edges = 0, vertices = 0;
      for (BRepGraph_ChildExplorer ex(p, root, BRepGraph_NodeId::Kind::Face); ex.More(); ex.Next())
        ++faces;
      for (BRepGraph_ChildExplorer ex(p, root, BRepGraph_NodeId::Kind::Edge); ex.More(); ex.Next())
        ++edges;
      for (BRepGraph_ChildExplorer ex(p, root, BRepGraph_NodeId::Kind::Vertex); ex.More();
           ex.Next())
        ++vertices;
      printf(" root0=(kind %d, index %d) faces=%d edges=%d vertices=%d",
             (int)BRepGraph_NodeId::Kind::Product, (int)roots(0).Index, faces, edges, vertices);
    }
    printf("\n");
  }
  {
    int n = 0;
    for (BRepGraph_ParentExplorer ex(g, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 0));
         ex.More(); ex.Next())
      ++n;
    printf("parentExplorer face0: %d\n", n);
  }
  printf("faces:");
  for (int f = 0; f < g.Topo().Faces().Nb(); ++f)
  {
    BRepGraph_FaceId id(f);
    printf(" [%d wires=%d vrefs=%d tol=%.17g surf=%d natural=%d tri=%d]", f,
           (int)BRepGraph_Tool::Face::NbWires(g, id), nFaceVertexRefs(g, f),
           BRepGraph_Tool::Face::Tolerance(g, id), (int)BRepGraph_Tool::Face::HasSurface(g, id),
           (int)(BRepGraph_Tool::Face::NbWires(g, id) == 0), (int)g.Mesh().Effective().Faces().Has(id));
  }
  printf("\n");
  {
    gp_Pnt   p0 = BRepGraph_Tool::Vertex::Pnt(g, BRepGraph_VertexId(0));
    uint64_t uid = g.Editor().Supplement().AttachToFace(
      BRepGraph_FaceId(0), BRepBuilderAPI_MakeVertex(p0).Vertex(),
      BRepGraph_LayerTopoSupplement::AttachmentKind::FaceDirectVertex);
    printf("faceAddVertex(face 0, vertex 0): uid=%llu vrefs face0=%d face1=%d\n",
           (unsigned long long)uid, nFaceVertexRefs(g, 0), nFaceVertexRefs(g, 1));
  }
  {
    TopoDS_Shape             b = box10();
    BRepMesh_IncrementalMesh m(b, 0.1, Standard_False, 0.5);
    BRepGraph                mg;
    build(mg, b);
    printf("meshed box: tri face0=%d\n", (int)mg.Mesh().Effective().Faces().Has(BRepGraph_FaceId(0)));
  }
  {
    BRepGraph s;
    build(s, BRepPrimAPI_MakeSphere(5).Shape());
    printf("sphere face0: wires=%d natural=%d\n",
           (int)BRepGraph_Tool::Face::NbWires(s, BRepGraph_FaceId(0)),
           (int)(BRepGraph_Tool::Face::NbWires(s, BRepGraph_FaceId(0)) == 0));
  }
  return 0;
}
