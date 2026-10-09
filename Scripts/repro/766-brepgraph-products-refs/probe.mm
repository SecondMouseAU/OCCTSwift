// Epic #766 kernel-parity probe for OCCTBRepGraphTests, files:
//   BRepGraph{NodeStatus,Occurrence,PolyCount,Product,RefCount,RefEntry,RootNode,SameDomain}Tests.
// Mirrors OCCTBRepGraphIsRemoved (Topo().Gen().IsRemoved), NbOccurrences, NbTriangulations /
// NbPolygons3D (Mesh().Poly()), NbProducts, Product{IsPart,IsAssembly,ShapeRootNode,
// NbComponents}, RootProductIds, the Refs().*().Nb() counters (coedge "refs" are the coedge
// definitions, Topo().CoEdges().Nb(), as the bridge reads them), Refs().Gen().ChildNode /
// Orientation / IsRemoved, LinkProductToTopology (Products().Add + AppendDocumentRoot) and the
// bridge's same-domain derivation: adjacent faces (shared edge) whose Geom_Plane surfaces are
// coplanar within Precision::Confusion / Precision::Angular.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_RefsView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_MeshView.hxx>
#include <BRepGraph_ReverseIterator.hxx>
#include <Geom_Plane.hxx>
#include <Precision.hxx>
#include <set>
#include <cstdio>

static void build(BRepGraph& g, const TopoDS_Shape& s)
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  g.Shapes().Add(s, opts);
}

static std::set<int> sameDomain(BRepGraph& g, int f)
{
  std::set<int> adj, out;
  for (int e = 0; e < g.Topo().Edges().Nb(); ++e)
  {
    std::set<int> fs;
    for (BRepGraph_FacesOfEdge it(g, BRepGraph_EdgeId(e)); it.More(); it.Next())
      fs.insert((int)it.CurrentId().Index);
    if (fs.count(f))
      for (int o : fs)
        if (o != f)
          adj.insert(o);
  }
  auto pa = occ::handle<Geom_Plane>::DownCast(BRepGraph_Tool::Face::Surface(g, BRepGraph_FaceId(f)));
  for (int o : adj)
  {
    auto pb = occ::handle<Geom_Plane>::DownCast(BRepGraph_Tool::Face::Surface(g, BRepGraph_FaceId(o)));
    if (pa.IsNull() || pb.IsNull())
      continue;
    gp_Pln A = pa->Pln(), B = pb->Pln();
    if (A.Axis().Direction().IsParallel(B.Axis().Direction(), Precision::Angular())
        && A.Distance(B.Location()) <= Precision::Confusion())
      out.insert(o);
  }
  return out;
}

int main()
{
  BRepGraph g;
  build(g, BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape());
  int removed = 0;
  for (int f = 0; f < g.Topo().Faces().Nb(); ++f)
    removed += g.Topo().Gen().IsRemoved(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, f)) ? 1 : 0;
  printf("noRemovedNodes: faces=%d removed=%d\n", g.Topo().Faces().Nb(), removed);
  printf("box products=%d occurrences=%d rootProducts=%d triangulations=%d polygons3d=%d\n",
         g.Topo().Products().Nb(), g.Topo().Occurrences().Nb(), (int)g.RootProductIds().Size(),
         g.Mesh().Poly().NbFaceTriangulations(), g.Mesh().Poly().NbEdgePolygons3D());
  printf("box refs: shell=%d face=%d wire=%d coedge(defs)=%d vertex=%d solid=%d child=%d "
         "occurrence=%d faces=%d wires=%d\n",
         g.Refs().Shells().Nb(), g.Refs().Faces().Nb(), g.Refs().Wires().Nb(),
         g.Topo().CoEdges().Nb(), g.Refs().Vertices().Nb(), g.Refs().Solids().Nb(),
         g.Refs().Children().Nb(), g.Refs().Occurrences().Nb(), g.Topo().Faces().Nb(),
         g.Topo().Wires().Nb());
  {
    BRepGraph_RefId r(BRepGraph_RefId::Kind::Face, 0), s(BRepGraph_RefId::Kind::Shell, 0);
    auto            c = g.Refs().Gen().ChildNode(r);
    printf("faceRef0: childKind=%d childIndex=%d orientation=%d removed=%d; shellRef0 removed=%d\n",
           (int)c.NodeKind, (int)c.Index, (int)g.Refs().Gen().Orientation(r),
           (int)g.Refs().Gen().IsRemoved(r), (int)g.Refs().Gen().IsRemoved(s));
    printf("faceRef orientations:");
    for (int i = 0; i < g.Refs().Faces().Nb(); ++i)
      printf(" %d", (int)g.Refs().Gen().Orientation(BRepGraph_RefId(BRepGraph_RefId::Kind::Face, i)));
    printf("\n");
  }
  {
    TopoDS_Shape             b = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
    BRepMesh_IncrementalMesh m(b, 0.1, Standard_False, 0.5);
    BRepGraph                mg;
    build(mg, b);
    printf("meshed box: triangulations=%d polygons3d=%d\n", mg.Mesh().Poly().NbFaceTriangulations(),
           mg.Mesh().Poly().NbEdgePolygons3D());
  }
  {
    BRepGraph p;
    build(p, BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape());
    auto pid = p.Editor().Products().Add(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0),
                                         TopLoc_Location());
    if (pid.IsValid())
      p.Editor().Products().AppendDocumentRoot(pid);
    auto rn = p.Topo().Products().ShapeRootNode(pid);
    printf("linked product: index=%d products=%d roots=%d isPart=%d isAssembly=%d components=%d "
           "shapeRoot=(kind %d, %d) occurrences=%d\n",
           (int)pid.Index, p.Topo().Products().Nb(), (int)p.RootProductIds().Size(),
           (int)p.Topo().Products().IsPart(pid), (int)p.Topo().Products().IsAssembly(pid),
           (int)p.Topo().Products().NbComponents(pid), (int)rn.NodeKind, (int)rn.Index,
           p.Topo().Occurrences().Nb());
  }
  {
    BRepGraph s;
    build(s, BRepPrimAPI_MakeSphere(5).Shape());
    printf("sphere products=%d occurrences=%d\n", s.Topo().Products().Nb(), s.Topo().Occurrences().Nb());
    auto pid = s.Editor().Products().Add(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0),
                                         TopLoc_Location());
    if (pid.IsValid())
      s.Editor().Products().AppendDocumentRoot(pid);
    printf("sphere linked product: products=%d isPart=%d components=%d\n", s.Topo().Products().Nb(),
           (int)s.Topo().Products().IsPart(pid), (int)s.Topo().Products().NbComponents(pid));
  }
  printf("box sameDomain(0): %d\n", (int)sameDomain(g, 0).size());
  {
    BRepAlgoAPI_Fuse fu(BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape(),
                        BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 10, 10, 10).Shape());
    fu.Build();
    BRepGraph f;
    build(f, fu.Shape());
    printf("fused boxes: faces=%d sameDomain:", f.Topo().Faces().Nb());
    for (int i = 0; i < f.Topo().Faces().Nb(); ++i)
    {
      auto sd = sameDomain(f, i);
      printf(" %d[", i);
      for (int o : sd)
        printf(" %d", o);
      printf(" ]");
    }
    printf("\n");
  }
  return 0;
}
