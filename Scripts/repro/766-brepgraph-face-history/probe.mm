// Epic #766 kernel-parity probe for OCCTBRepGraphTests, files:
//   BRepGraphFaceQueryTests, BRepGraphFaceShellTests, BRepGraphHistoryTests,
//   BRepGraphHistoryReadbackTests.
// Mirrors OCCTBRepGraphFaceAdjacentIndices / FaceSharedEdgeIndices (faces sharing an edge via
// BRepGraph_FacesOfEdge over the face's edges), FaceOuterWire (Tool::Face::OuterWire),
// FaceShellIndices (BRepGraph_ShellsOfFace over the face's parent refs), FaceCompoundCount
// (BRepGraph_CompoundsOfFace), and the BRepGraph_LayerHistory calls behind
// OCCTBRepGraphHistory{IsEnabled,SetEnabled,Clear,NbRecords,Record,GetRecordInfo,FindDerived,
// FindOriginal}. Node kinds are cast from the Swift raw value exactly as the bridge does
// ((BRepGraph_NodeId::Kind)raw): face = 2, edge = 4.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_ReverseIterator.hxx>
#include <BRepGraph_LayerRegistry.hxx>
#include <BRepGraph_LayerHistory.hxx>
#include <NCollection_Array1.hxx>
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

static BRepGraph_NodeId N(int kind, int idx)
{
  return BRepGraph_NodeId((BRepGraph_NodeId::Kind)kind, idx);
}

static void rec(occ::handle<BRepGraph_LayerHistory>& h, const char* op, BRepGraph_NodeId o,
                std::initializer_list<BRepGraph_NodeId> r)
{
  NCollection_Array1<BRepGraph_NodeId> a(0, std::max<int>(0, (int)r.size()) - 1);
  int                                  i = 0;
  for (auto& n : r)
    a.SetValue(i++, n);
  h->Record(TCollection_AsciiString(op), o, a);
}

static void derived(occ::handle<BRepGraph_LayerHistory>& h, const char* label, BRepGraph_NodeId o)
{
  auto d = h->FindDerived(o);
  printf("%s: FindDerived(kind %d, %d) = [", label, (int)o.NodeKind, (int)o.Index);
  for (size_t i = 0; i < d.Size(); ++i)
    printf(" (%d,%d)", (int)d.Value(i).NodeKind, (int)d.Value(i).Index);
  printf(" ]\n");
}

int main()
{
  {
    BRepGraph g;
    build(g, box(10, 20, 30));
    // Faces adjacent to face 0 = faces sharing any of its edges.
    std::set<int> adj;
    int           shared02 = 0, firstAdj = -1;
    for (int e = 0; e < g.Topo().Edges().Nb(); ++e)
    {
      std::set<int> fs;
      for (BRepGraph_FacesOfEdge it(g, BRepGraph_EdgeId(e)); it.More(); it.Next())
        fs.insert((int)it.CurrentId().Index);
      if (fs.count(0))
        for (int f : fs)
          if (f != 0)
            adj.insert(f);
    }
    firstAdj = adj.empty() ? -1 : *adj.begin();
    std::set<int> shared;
    for (int e = 0; e < g.Topo().Edges().Nb(); ++e)
    {
      std::set<int> fs;
      for (BRepGraph_FacesOfEdge it(g, BRepGraph_EdgeId(e)); it.More(); it.Next())
        fs.insert((int)it.CurrentId().Index);
      if (fs.count(0) && fs.count(firstAdj))
        shared.insert(e);
    }
    shared02 = (int)shared.size();
    printf("faceAdjacency(0): [");
    for (int f : adj)
      printf(" %d", f);
    printf(" ] sharedEdges(0,%d): [", firstAdj);
    for (int e : shared)
      printf(" %d", e);
    printf(" ] (%d)\n", shared02);
  }
  BRepGraph b;
  build(b, box(10, 10, 10));
  printf("outerWire:");
  for (int f = 0; f < b.Topo().Faces().Nb(); ++f)
  {
    auto w = BRepGraph_Tool::Face::OuterWire(b, BRepGraph_FaceId(f));
    printf(" %d", w.IsValid() ? (int)w.Index : -1);
  }
  printf("\nfaceShells:");
  for (int f = 0; f < b.Topo().Faces().Nb(); ++f)
  {
    const auto& rel = b.Topo().Faces().Relations(BRepGraph_FaceId(f));
    printf(" [");
    for (BRepGraph_ShellsOfFace it(b, rel.ParentFaceRefIds); it.More(); it.Next())
      printf(" %d", (int)it.CurrentId().Index);
    int nc = 0;
    for (BRepGraph_CompoundsOfFace it(b, b.Topo().Gen().CompoundRefIds(N(2, f))); it.More(); it.Next())
      ++nc;
    printf(" | compounds %d ]", nc);
  }
  printf("\n");

  {
    BRepGraph g;
    build(g, box(10, 10, 10));
    auto h = g.LayerRegistry().FindLayer<BRepGraph_LayerHistory>();
    printf("historyDefaults: layer=%d enabled=%d records=%d\n", (int)!h.IsNull(),
           h.IsNull() ? 0 : (int)h->IsEnabled(), h.IsNull() ? 0 : (int)h->NbRecords());
    h->SetEnabled(false);
    int off = h->IsEnabled();
    h->SetEnabled(true);
    printf("historyToggle: afterDisable=%d afterEnable=%d\n", off, (int)h->IsEnabled());
    rec(h, "Op", N(2, 0), {N(2, 42)});
    int before = (int)h->NbRecords();
    h->Clear();
    printf("historyClear: recordsBefore=%d after=%d\n", before, (int)h->NbRecords());
  }
  {
    BRepGraph g;
    build(g, box(10, 10, 10));
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    h->SetEnabled(true);
    h->Clear();
    rec(h, "TestFillet", N(2, 0), {N(2, 42)});
    const auto& r = h->Record(0);
    printf("oneToOneReadback: records=%d op=%s\n", (int)h->NbRecords(), r.OperationName.ToCString());
  }
  {
    BRepGraph g;
    build(g, box(10, 10, 10));
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    h->Clear();
    rec(h, "SplitEdge", N(4, 3), {N(4, 100), N(4, 101), N(4, 102)});
    derived(h, "splitMapping", N(4, 3));
    h->Clear();
    rec(h, "RemoveFace", N(2, 5), {});
    derived(h, "deletionMapping", N(2, 5));
    printf("deletionMapping: records=%d\n", (int)h->NbRecords());
  }
  {
    BRepGraph g;
    build(g, box(10, 10, 10));
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    h->Clear();
    rec(h, "Op1", N(4, 1), {N(4, 10)});
    rec(h, "Op2", N(4, 10), {N(4, 20), N(4, 21)});
    derived(h, "findDerivedWalksForward", N(4, 1));
  }
  {
    BRepGraph g;
    build(g, box(10, 10, 10));
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    h->Clear();
    rec(h, "ModifyFace", N(2, 0), {N(2, 100)});
    rec(h, "DeleteFace", N(2, 1), {});
    derived(h, "modified", N(2, 0));
    derived(h, "deleted", N(2, 1));
    derived(h, "untouched", N(2, 2));
  }
  {
    BRepGraph g;
    build(g, box(10, 10, 10));
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    h->Clear();
    rec(h, "A", N(2, 7), {N(2, 70)});
    rec(h, "B", N(2, 70), {N(2, 700)});
    auto o = h->FindOriginal(N(2, 700));
    auto p = h->FindOriginal(N(2, 3));
    printf("findOriginal(700) = (%d,%d); unrecorded findOriginal(3) = (%d,%d)\n", (int)o.NodeKind,
           (int)o.Index, (int)p.NodeKind, (int)p.Index);
  }
  return 0;
}
