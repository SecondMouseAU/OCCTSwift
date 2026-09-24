// Kernel-parity probe for #1986 (Epic #766): GraphHistoryAbsorbTests,
// Issue336ChainedHistoryTests, Issue1078HistoryRecordOpNameLengthTests, and the history
// inputs TopologyRefResolverTests / ContainedInTests resolve against. Mirrors
// OCCTBooleanSubtractWithHistory (BRepAlgoAPI_Cut + BRepTools_History(args, op)),
// OCCTBRepGraphAddWithHistory (ShapesView::AddWithHistory into BRepGraph_LayerHistory),
// OCCTBRepGraphHistoryRecord / ...GetRecordInfo / ...FindDerived / ...IsDeleted.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepTools_History.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <NCollection_List.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_LayerRegistry.hxx>
#include <BRepGraph_LayerHistory.hxx>
#include <cstdio>
#include <string>

static void build(BRepGraph& g, const TopoDS_Shape& s) // OCCTBRepGraphCreate
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  (void)g.Shapes().Add(s, opts);
}

static double faceArea(const BRepGraph& g, const BRepGraph_NodeId& n)
{
  TopoDS_Shape s = g.Shapes().Shape(n);
  double       a = 0;
  for (TopExp_Explorer ex(s, TopAbs_FACE); ex.More(); ex.Next())
  {
    GProp_GProps p;
    BRepGProp::SurfaceProperties(ex.Current(), p);
    a += p.Mass();
  }
  return a;
}

static Handle(BRepTools_History) cutHistory(const TopoDS_Shape& a, const TopoDS_Shape& b,
                                            TopoDS_Shape& result)
{
  BRepAlgoAPI_Cut          op(a, b);
  NCollection_List<TopoDS_Shape> args;
  args.Append(a);
  args.Append(b);
  result = op.Shape();
  return new BRepTools_History(args, op);
}

int main()
{
  // --- GraphHistoryAbsorb: 10x10x10 box at the origin, bar Y in [4,6] across its top.
  {
    TopoDS_Shape base = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape();
    BRepGraph    g;
    build(g, base);
    auto root = g.Shapes().FindNode(base);
    // top face: highest centroid z
    TopoDS_Shape top;
    double       bestZ = -1e9;
    for (TopExp_Explorer ex(base, TopAbs_FACE); ex.More(); ex.Next())
    {
      GProp_GProps p;
      BRepGProp::SurfaceProperties(ex.Current(), p);
      if (p.CentreOfMass().Z() > bestZ)
      {
        bestZ = p.CentreOfMass().Z();
        top   = ex.Current();
      }
    }
    auto         topNode = g.Shapes().FindNode(top);
    TopoDS_Shape tool    = BRepPrimAPI_MakeBox(gp_Pnt(-1, 4, 8), 12, 2, 4).Shape();
    TopoDS_Shape result;
    auto         hist = cutHistory(base, tool, result);
    printf("absorb: records before=%d\n",
           g.LayerRegistry().FindLayer<BRepGraph_LayerHistory>().IsNull()
             ? 0
             : (int)g.LayerRegistry().FindLayer<BRepGraph_LayerHistory>()->NbRecords());
    // Without the absorb: FindDerived(top) on the empty log.
    {
      auto h0 = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
      printf("absorb: without absorb, FindDerived(top).Size()=%d IsDeleted(top)=%d\n",
             (int)h0->FindDerived(topNode).Size(), h0->IsDeleted(topNode) ? 1 : 0);
    }
    NCollection_Array1<BRepGraph_NodeId> roots(0, 0);
    roots.SetValue(0, root);
    auto r = g.Shapes().AddWithHistory(result, roots, hist, TCollection_AsciiString("channel-cut"));
    auto h = g.LayerRegistry().FindLayer<BRepGraph_LayerHistory>();
    printf("absorb: ok=%d records after=%d\n", r.IsOk() ? 1 : 0, (int)h->NbRecords());
    auto derived = h->FindDerived(topNode);
    int  faces   = 0;
    for (int i = 0; i < (int)derived.Size(); ++i)
      if (derived.Value(i).NodeKind == BRepGraph_NodeId::Kind::Face)
      {
        ++faces;
        printf("absorb: derived face %d area=%.6f\n", (int)derived.Value(i).Index,
               faceArea(g, derived.Value(i)));
      }
    printf("absorb: FindDerived(top) size=%d faces=%d\n", (int)derived.Size(), faces);
    // bottom face (lowest z) untouched
    TopoDS_Shape bottom;
    double       lowZ = 1e9;
    for (TopExp_Explorer ex(base, TopAbs_FACE); ex.More(); ex.Next())
    {
      GProp_GProps p;
      BRepGProp::SurfaceProperties(ex.Current(), p);
      if (p.CentreOfMass().Z() < lowZ)
      {
        lowZ   = p.CentreOfMass().Z();
        bottom = ex.Current();
      }
    }
    printf("absorb: IsDeleted(bottom)=%d\n", h->IsDeleted(g.Shapes().FindNode(bottom)) ? 1 : 0);
    int labelled = 0;
    for (size_t i = 0; i < h->NbRecords(); ++i)
      if (h->Record(i).OperationName == "channel-cut")
        ++labelled;
    printf("absorb: records labelled channel-cut=%d\n", labelled);
  }

  // --- Issue336: centered box 10x20x30, two corner clips, then a non-intersecting cut.
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
    BRepGraph    g;
    build(g, box);
    auto         root0 = g.Shapes().FindNode(box);
    TopoDS_Shape out1, out2;
    auto h1 = cutHistory(box, BRepPrimAPI_MakeBox(gp_Pnt(4, 9, 14), 3, 3, 3).Shape(), out1);
    NCollection_Array1<BRepGraph_NodeId> r0(0, 0);
    r0.SetValue(0, root0);
    (void)g.Shapes().AddWithHistory(out1, r0, h1, TCollection_AsciiString("hop1"));
    auto hl = g.LayerRegistry().FindLayer<BRepGraph_LayerHistory>();
    printf("336 chained: after hop1 records=%d\n", (int)hl->NbRecords());
    TopExp_Explorer sx(out1, TopAbs_SOLID);
    auto            root1 = g.Shapes().FindNode(sx.Current());
    auto h2 = cutHistory(out1, BRepPrimAPI_MakeBox(gp_Pnt(-6, -11, -16), 3, 3, 3).Shape(), out2);
    GProp_GProps v1, v2;
    BRepGProp::VolumeProperties(out1, v1);
    BRepGProp::VolumeProperties(out2, v2);
    size_t before2 = hl->NbRecords();
    NCollection_Array1<BRepGraph_NodeId> r1(0, 0);
    r1.SetValue(0, root1);
    (void)g.Shapes().AddWithHistory(out2, r1, h2, TCollection_AsciiString("hop2"));
    printf("336 chained: volumes %.3f -> %.3f, hop2 records %d -> %d\n", v1.Mass(), v2.Mass(),
           (int)before2, (int)hl->NbRecords());
  }
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
    BRepGraph    g;
    build(g, box);
    auto         root0 = g.Shapes().FindNode(box);
    TopoDS_Shape out1, out2;
    auto h1 = cutHistory(box, BRepPrimAPI_MakeBox(gp_Pnt(-2.5, -2.5, -2.5), 3, 3, 3).Shape(), out1);
    NCollection_Array1<BRepGraph_NodeId> r0(0, 0);
    r0.SetValue(0, root0);
    (void)g.Shapes().AddWithHistory(out1, r0, h1, TCollection_AsciiString("hop1"));
    auto            hl = g.LayerRegistry().FindLayer<BRepGraph_LayerHistory>();
    TopExp_Explorer sx(out1, TopAbs_SOLID);
    auto            root1 = g.Shapes().FindNode(sx.Current());
    auto h2 = cutHistory(out1, BRepPrimAPI_MakeBox(gp_Pnt(6.5, 16.5, 26.5), 3, 3, 3).Shape(), out2);
    GProp_GProps v1, v2;
    BRepGProp::VolumeProperties(out1, v1);
    BRepGProp::VolumeProperties(out2, v2);
    size_t before2 = hl->NbRecords();
    NCollection_Array1<BRepGraph_NodeId> r1(0, 0);
    r1.SetValue(0, root1);
    (void)g.Shapes().AddWithHistory(out2, r1, h2, TCollection_AsciiString("hop2"));
    printf("336 non-intersecting: volumes %.3f -> %.3f, hop2 records %d -> %d, "
           "FindDerived(root1).Size()=%d\n",
           v1.Mass(), v2.Mass(), (int)before2, (int)hl->NbRecords(),
           (int)hl->FindDerived(root1).Size());
  }

  // --- Issue1078 and TopologyRef: records written by OCCTBRepGraphHistoryRecord, read back.
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    BRepGraph    g;
    build(g, box);
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    NCollection_Array1<BRepGraph_NodeId> one(0, 0);
    one.SetValue(0, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 1));
    h->Record(TCollection_AsciiString(std::string(300, 'O').c_str()),
              BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 0), one);
    h->Record(TCollection_AsciiString("TestOp"), BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 0),
              one);
    printf("1078: records=%d len[0]=%d len[1]=%d\n", (int)h->NbRecords(),
           h->Record(0).OperationName.Length(), h->Record(1).OperationName.Length());
  }
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    BRepGraph    g;
    build(g, box);
    auto h = g.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
    // createdByForwardWalk: Create sentinel -> face 10, Modify face 10 -> face 11.
    NCollection_Array1<BRepGraph_NodeId> c(0, 0), m(0, 0), s(0, 1);
    c.SetValue(0, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 10));
    m.SetValue(0, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 11));
    h->Record(TCollection_AsciiString("Create"), BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, -1), c);
    h->Record(TCollection_AsciiString("Modify"), BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 10), m);
    auto d = h->FindDerived(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 10));
    printf("topologyref forward walk: FindDerived(face 10) size=%d first=(%d,%d)\n", (int)d.Size(),
           d.Size() ? (int)d.Value(0).NodeKind : -1, d.Size() ? (int)d.Value(0).Index : -1);
    // splitOf: edge 3 -> [edge 30, edge 31]
    s.SetValue(0, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Edge, 30));
    s.SetValue(1, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Edge, 31));
    h->Record(TCollection_AsciiString("SplitEdge"), BRepGraph_NodeId(BRepGraph_NodeId::Kind::Edge, 3), s);
    auto e = h->FindDerived(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Edge, 3));
    printf("topologyref splitOf: FindDerived(edge 3) size=%d\n", (int)e.Size());
    for (int i = 0; i < (int)e.Size(); ++i)
      printf("  [%d] = (%d,%d)\n", i, (int)e.Value(i).NodeKind, (int)e.Value(i).Index);
    printf("topologyref: records=%d\n", (int)h->NbRecords());
  }
  return 0;
}
