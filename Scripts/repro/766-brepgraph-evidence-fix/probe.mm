// Kernel side of the #1986 evidence correction pass (Epic #766). The parity records this probe
// backs compare the quantity the test observes with the quantity the kernel reports, so each
// block here reads the kernel's own store directly, the way the bridge entry point does:
//
//   OCCTBRepGraphHistoryRecord           Ensure<BRepGraph_LayerHistory>() then Record(op, orig, Array1)
//   OCCTBRepGraphHistoryGetRecordMapping Record(i).Mapping lookup of one original
//   OCCTBRepGraphHistoryFindDerived      FindDerived(orig)
//   OCCTBRepGraphBuilderRemoveRef /
//   OCCTBRepGraphRefIsRemoved            Editor().Gen().RemoveRef / Refs().Gen().IsRemoved
//
// Node kinds print as the BRepGraph_NodeId::Kind ordinal the bridge casts to: solid 0, shell 1,
// face 2, wire 3, edge 4, vertex 5.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_RefsView.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_LayerRegistry.hxx>
#include <BRepGraph_LayerHistory.hxx>
#include <NCollection_Array1.hxx>
#include <cstdio>
#include <initializer_list>

static void build(BRepGraph& g, const TopoDS_Shape& s) // OCCTBRepGraphCreate
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  (void)g.Shapes().Add(s, opts);
}

static BRepGraph_NodeId N(BRepGraph_NodeId::Kind k, int i)
{
  return BRepGraph_NodeId(k, i);
}

// OCCTBRepGraphHistoryRecord
static void record(occ::handle<BRepGraph_LayerHistory>& h, const char* op, BRepGraph_NodeId orig,
                   std::initializer_list<BRepGraph_NodeId> repls)
{
  NCollection_Array1<BRepGraph_NodeId> a(0, (int)repls.size() - 1);
  int                                  i = 0;
  for (const auto& r : repls)
    a.SetValue(i++, r);
  h->Record(TCollection_AsciiString(op), orig, a);
}

// OCCTBRepGraphHistoryGetRecordMapping: replacements the record (i) holds for orig, or -1 if unbound.
static void mapping(const char* label, occ::handle<BRepGraph_LayerHistory>& h, size_t rec,
                    BRepGraph_NodeId orig)
{
  const auto* v = h->Record(rec).Mapping.Seek(orig);
  if (v == nullptr)
  {
    printf("%s: record %zu Mapping[(%d,%d)] unbound\n", label, rec, (int)orig.NodeKind,
           (int)orig.Index);
    return;
  }
  printf("%s: record %zu Mapping[(%d,%d)] size=%d [", label, rec, (int)orig.NodeKind,
         (int)orig.Index, (int)v->Size());
  for (size_t i = 0; i < v->Size(); ++i)
    printf(" (%d,%d)", (int)v->Value(i).NodeKind, (int)v->Value(i).Index);
  printf(" ]\n");
}

static bool namedInAnyRecord(occ::handle<BRepGraph_LayerHistory>& h, BRepGraph_NodeId n)
{
  for (size_t i = 0; i < h->NbRecords(); ++i)
    if (h->Record(i).Mapping.Seek(n) != nullptr)
      return true;
  return false;
}

int main()
{
  const TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  const auto         SOL = BRepGraph_NodeId::Kind::Solid;
  const auto         FAC = BRepGraph_NodeId::Kind::Face;
  const auto         EDG = BRepGraph_NodeId::Kind::Edge;

  { // TopologyRefResolverTests.createdByOutOfRange: sentinel "Op" -> [face 100]
    BRepGraph g;
    build(g, box);
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    h->Clear();
    record(h, "Op", N(SOL, -1), {N(FAC, 100)});
    mapping("createdByOutOfRange", h, 0, N(SOL, -1));
  }
  { // TopologyRefResolverTests.splitOf / splitOfOutOfRange: edge 3 -> [edge 30, edge 31]
    BRepGraph g;
    build(g, box);
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    h->Clear();
    record(h, "SplitEdge", N(EDG, 3), {N(EDG, 30), N(EDG, 31)});
    mapping("splitOf", h, 0, N(EDG, 3));
  }
  { // BRepGraphHistoryReadbackTests.splitMapping: edge 3 -> [edge 100, 101, 102]
    BRepGraph g;
    build(g, box);
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    h->Clear();
    record(h, "SplitEdge", N(EDG, 3), {N(EDG, 100), N(EDG, 101), N(EDG, 102)});
    mapping("splitMapping", h, 0, N(EDG, 3));
  }
  { // BRepGraphHistoryReadbackTests.deletionMapping: face 5 -> [] (bridge builds Array1(0, -1))
    BRepGraph g;
    build(g, box);
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    h->Clear();
    NCollection_Array1<BRepGraph_NodeId> none(0, -1);
    h->Record(TCollection_AsciiString("RemoveFace"), N(FAC, 5), none);
    mapping("deletionMapping", h, 0, N(FAC, 5));
  }
  { // BRepGraphHistoryReadbackTests.hasHistoryRecordDistinguishesNamedFromUntouched
    BRepGraph g;
    build(g, box);
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    h->Clear();
    record(h, "ModifyFace", N(FAC, 0), {N(FAC, 100)});
    NCollection_Array1<BRepGraph_NodeId> none(0, -1);
    h->Record(TCollection_AsciiString("DeleteFace"), N(FAC, 1), none);
    printf("hasHistoryRecord: records=%d modified(face 0)=%d deleted(face 1)=%d untouched(face 2)=%d\n",
           (int)h->NbRecords(), (int)namedInAnyRecord(h, N(FAC, 0)),
           (int)namedInAnyRecord(h, N(FAC, 1)), (int)namedInAnyRecord(h, N(FAC, 2)));
  }
  { // BRepGraphRefEntryTests.refNotRemoved: a fresh box, then RemoveRef on face ref 0
    BRepGraph g;
    build(g, box);
    BRepGraph_RefId face0(BRepGraph_RefId::Kind::Face, 0), shell0(BRepGraph_RefId::Kind::Shell, 0);
    int             f0 = g.Refs().Gen().IsRemoved(face0), s0 = g.Refs().Gen().IsRemoved(shell0);
    bool            removed = g.Editor().Gen().RemoveRef(face0);
    printf("refNotRemoved: face0=%d shell0=%d RemoveRef(face0)=%d face0 after=%d\n", f0, s0,
           (int)removed, (int)g.Refs().Gen().IsRemoved(face0));
  }
  { // BRepGraphRootNodeTests.hasRoots: OCCTBRepGraphLinkProductToTopology, then OCCTBRepGraphRootNodes
    BRepGraph g;
    build(g, box);
    int before = (int)g.RootProductIds().Size();
    auto pid = g.Editor().Products().Add(N(SOL, 0), TopLoc_Location());
    if (pid.IsValid())
      g.Editor().Products().AppendDocumentRoot(pid);
    const auto& roots = g.RootProductIds();
    printf("hasRoots: roots before=%d after=%d", before, (int)roots.Size());
    for (int i = 0; i < (int)roots.Size(); ++i)
      printf(" root[%d]=product %d", i, (int)roots(i).Index);
    printf("\n");
  }
  return 0;
}
