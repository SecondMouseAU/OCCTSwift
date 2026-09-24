// Epic #766 kernel-parity probe for OCCTBRepGraphTests, file: BRepGraphDurableUIDTests.
// Mirrors OCCTBRepGraphNodeUID / NodeFromUID / HasNodeUID / RefUID / RefFromUID /
// ItemUIDOfNode / ItemFromUID (BRepGraph::UIDs()), OCCTBRepGraphCopy (BRepGraph_Copy::Perform),
// OCCTBRepGraphTransformTranslation (BRepGraph_Transform::Perform), OCCTBRepGraphCopyFace
// (Clear() then BRepGraph_Copy::CopyNode) and OCCTBRepGraphCompact.
//
// The graph-provenance check (GraphUID.graphID == instanceID) lives in the Swift layer, not the
// kernel, so the kernel lines below show what the kernel alone answers for a foreign UID: it
// resolves it, to whatever node holds that counter. That is the #295 behaviour the Swift check
// exists to reject.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_UIDsView.hxx>
#include <BRepGraph_Copy.hxx>
#include <BRepGraph_Transform.hxx>
#include <BRepGraph_Compact.hxx>
#include <BRepGraphInc_RepId.hxx>
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

static BRepGraph_NodeId face(int i)
{
  return BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, (uint32_t)i);
}

int main()
{
  BRepGraph b;
  build(b, box(10, 10, 10));
  printf("nodeUIDRoundTrip:");
  for (int i = 0; i < b.Topo().Faces().Nb(); ++i)
  {
    BRepGraph_UID    u = b.UIDs().Of(face(i));
    BRepGraph_NodeId n = b.UIDs().NodeIdFrom(u);
    printf(" [face %d kind=%d counter=%u -> kind=%d index=%d]", i, (int)u.Kind, (unsigned)u.Counter,
           (int)n.NodeKind, (int)n.Index);
  }
  printf("\n");

  BRepGraph c;
  build(c, BRepPrimAPI_MakeCylinder(3, 7).Shape());
  BRepGraph_UID    u2 = b.UIDs().Of(face(2));
  BRepGraph_NodeId inC = c.UIDs().NodeIdFrom(u2);
  printf("uidFromAnotherGraph (kernel, no provenance): boxFace2 counter=%u cylFaces=%d "
         "resolvesInCyl=%d cylIndex=%d cylHas=%d\n",
         (unsigned)u2.Counter, c.Topo().Faces().Nb(), (int)inC.IsValid(), (int)inC.Index,
         (int)c.UIDs().Has(u2));

  BRepGraph b2;
  build(b2, box(10, 10, 10));
  BRepGraph_UID    u1 = b.UIDs().Of(face(1));
  BRepGraph_NodeId inB2 = b2.UIDs().NodeIdFrom(u1);
  printf("uidDoesNotCrossIdenticallyBuiltGraphs (kernel): face1 counter=%u resolvesInTwin=%d "
         "twinIndex=%d\n",
         (unsigned)u1.Counter, (int)inB2.IsValid(), (int)inB2.Index);

  BRepGraph s;
  build(s, box(10, 20, 30));
  BRepGraph cp;
  bool      okc = BRepGraph_Copy::Perform(s, cp, BRepGraph_Copy::GeomPolicy::Copy);
  printf("uidSurvivesAFullCopy: ok=%d", (int)okc);
  for (int i = 0; i < s.Topo().Faces().Nb(); ++i)
  {
    BRepGraph_NodeId n = cp.UIDs().NodeIdFrom(s.UIDs().Of(face(i)));
    printf(" %d->%d", i, n.IsValid() ? (int)n.Index : -1);
  }
  printf("\n");

  gp_Trsf t;
  t.SetTranslation(gp_Vec(100, 200, 300));
  BRepGraph mv;
  bool      okt = BRepGraph_Transform::Perform(s, mv, t, BRepGraph_Copy::GeomPolicy::Copy);
  printf("uidSurvivesATranslation: ok=%d", (int)okt);
  for (int i = 0; i < s.Topo().Faces().Nb(); ++i)
  {
    BRepGraph_NodeId n = mv.UIDs().NodeIdFrom(s.UIDs().Of(face(i)));
    printf(" %d->%d", i, n.IsValid() ? (int)n.Index : -1);
  }
  printf("\n");

  BRepGraph lf;
  lf.Clear();
  BRepGraph_Copy::CopyNode(s, lf, face(3), BRepGraph_Copy::GeomPolicy::Copy);
  BRepGraph_UID    s0  = s.UIDs().Of(face(0));
  BRepGraph_NodeId inL = lf.UIDs().NodeIdFrom(s0);
  printf("uidDoesNotCrossACopiedOutFace (kernel): liftedFaces=%d face0Counter=%u "
         "resolvesInLifted=%d liftedIndex=%d\n",
         lf.Topo().Faces().Nb(), (unsigned)s0.Counter, (int)inL.IsValid(), (int)inL.Index);

  BRepGraph_UID bogus(BRepGraph_NodeId::Kind::Face, 999999);
  BRepGraph_UID zero(BRepGraph_NodeId::Kind::Face, 0);
  printf("outOfRangeCounter: has999999=%d resolves=%d zeroValid=%d hasZero=%d\n",
         (int)b.UIDs().Has(bogus), (int)b.UIDs().NodeIdFrom(bogus).IsValid(), (int)zero.IsValid(),
         (int)b.UIDs().Has(zero));

  BRepGraph k;
  build(k, box(10, 10, 10));
  BRepGraph_UID u3 = k.UIDs().Of(face(3));
  BRepGraph_Compact::Perform(k);
  BRepGraph_NodeId after = k.UIDs().NodeIdFrom(u3);
  printf("uidSurvivesCompaction: counter=%u has=%d index=%d\n", (unsigned)u3.Counter,
         (int)k.UIDs().Has(u3), (int)after.Index);

  BRepGraph_RefId  r0(BRepGraph_RefId::Kind::Face, 0);
  BRepGraph_RefUID ru = b.UIDs().Of(r0);
  BRepGraph_RefId  rb = b.UIDs().RefIdFrom(ru);
  BRepGraph_RefId  rc = c.UIDs().RefIdFrom(ru);
  printf("refUID: kind=%d counter=%u resolvesInBox=%d boxIndex=%d resolvesInCyl(kernel)=%d\n",
         (int)ru.Kind, (unsigned)ru.Counter, (int)rb.IsValid(), (int)rb.Index, (int)rc.IsValid());

  BRepGraph_ItemUID iu = b.UIDs().Of(BRepGraph_ItemId(face(2)));
  BRepGraph_ItemId  ib = b.UIDs().ItemIdFrom(iu);
  printf("itemUID face2: domain=%d kind=%d counter=%u -> domain=%d kind=%d index=%d "
         "resolvesInCyl(kernel)=%d\n",
         (int)iu.ItemDomain(), (int)iu.RawKind(), (unsigned)iu.Counter(), (int)ib.ItemDomain(),
         (int)ib.RawKind(), (int)ib.Index(), (int)c.UIDs().ItemIdFrom(iu).IsValid());
  BRepGraph_ItemUID i0 = b.UIDs().Of(BRepGraph_ItemId(face(0)));
  BRepGraph_ItemId  j0 = b.UIDs().ItemIdFrom(i0);
  printf("itemUIDOfNode face0: domain=%d kind=%d counter=%u -> domain=%d kind=%d index=%d\n",
         (int)i0.ItemDomain(), (int)i0.RawKind(), (unsigned)i0.Counter(), (int)j0.ItemDomain(),
         (int)j0.RawKind(), (int)j0.Index());
  return 0;
}
