// Epic #766 kernel-parity probe for OCCTBRepGraphTests, files:
//   BRepGraphBuilder{AppendShape,ClearMesh,CommitMutation,Deferred,RemoveNode,RemoveRef}Tests.
// Mirrors the bridge: OCCTShapeCreateBox/Sphere/Cylinder, OCCTShapeCreateMesh
// (BRepMesh_IncrementalMesh in place), OCCTBRepGraphCreate (Clear() then Shapes().Add with
// CreateAutoProduct = false), and the EditorView / MeshView / RefsView calls of the
// OCCTBRepGraphBuilder* entry points.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_RefsView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_MeshView.hxx>
#include <Poly_Triangulation.hxx>
#include <Poly_Polygon3D.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <cstdio>

static TopoDS_Shape makeBox()
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

int main()
{
  {
    BRepGraph g;
    build(g, makeBox());
    int before = g.Topo().Faces().Nb();
    BRepGraph::ShapesView::Options opts;
    opts.Parallel          = false;
    opts.CreateAutoProduct = false;
    opts.Flatten           = true;
    g.Shapes().Add(BRepPrimAPI_MakeSphere(5).Shape(), opts);
    printf("appendFlattenedShape: faces before=%d after=%d\n", before, g.Topo().Faces().Nb());
  }
  {
    BRepGraph g;
    build(g, makeBox());
    int before = g.Topo().Faces().Nb();
    BRepGraph::ShapesView::Options opts;
    opts.Parallel          = false;
    opts.CreateAutoProduct = false;
    g.Shapes().Add(BRepPrimAPI_MakeCylinder(3, 8).Shape(), opts);
    printf("appendFullShape: faces before=%d after=%d\n", before, g.Topo().Faces().Nb());
  }
  {
    TopoDS_Shape box = makeBox();
    BRepMesh_IncrementalMesh mesher(box, 0.1, Standard_False, 0.5);
    BRepGraph g;
    build(g, box);
    BRepGraph_FaceId f0(0);
    printf("clearFaceMesh: before effective=%d cache=%d\n",
           (int)g.Mesh().Effective().Faces().Has(f0), (int)g.Mesh().Cache().Faces().Has(f0));
    // The test seeds the cache tier the way OCCTBRepGraphMeshAppendCachedTriangulation does,
    // since Clear() only touches the cache and the in-place mesh lands in the persistent tier.
    occ::handle<Poly_Triangulation> tri = new Poly_Triangulation(4, 2, Standard_False);
    tri->SetNode(1, gp_Pnt(0, 0, 0));
    tri->SetNode(2, gp_Pnt(1, 0, 0));
    tri->SetNode(3, gp_Pnt(0, 1, 0));
    tri->SetNode(4, gp_Pnt(1, 1, 0));
    tri->SetTriangle(1, Poly_Triangle(1, 2, 3));
    tri->SetTriangle(2, Poly_Triangle(2, 4, 3));
    g.Mesh().Editor().Faces().SetCachedTriangulation(f0, tri);
    printf("clearFaceMesh: seeded effective=%d cache=%d\n",
           (int)g.Mesh().Effective().Faces().Has(f0), (int)g.Mesh().Cache().Faces().Has(f0));
    g.Mesh().Editor().Faces().Clear(f0);
    printf("clearFaceMesh: after  effective=%d cache=%d\n",
           (int)g.Mesh().Effective().Faces().Has(f0), (int)g.Mesh().Cache().Faces().Has(f0));
  }
  {
    TopoDS_Shape box = makeBox();
    BRepMesh_IncrementalMesh mesher(box, 0.1, Standard_False, 0.5);
    BRepGraph g;
    build(g, box);
    BRepGraph_EdgeId e0(0);
    printf("clearEdgePolygon3D: before effective=%d cache=%d\n",
           (int)g.Mesh().Effective().Edges().Has(e0), (int)g.Mesh().Cache().Edges().Has(e0));
    TColgp_Array1OfPnt pts(1, 3);
    pts.SetValue(1, gp_Pnt(0, 0, 0));
    pts.SetValue(2, gp_Pnt(1, 0, 0));
    pts.SetValue(3, gp_Pnt(2, 0, 0));
    occ::handle<Poly_Polygon3D> poly = new Poly_Polygon3D(pts);
    g.Mesh().Editor().Edges().SetCachedPolygon3D(e0, poly);
    printf("clearEdgePolygon3D: seeded effective=%d cache=%d\n",
           (int)g.Mesh().Effective().Edges().Has(e0), (int)g.Mesh().Cache().Edges().Has(e0));
    g.Mesh().Editor().Edges().Clear(e0);
    printf("clearEdgePolygon3D: after  effective=%d cache=%d\n",
           (int)g.Mesh().Effective().Edges().Has(e0), (int)g.Mesh().Cache().Edges().Has(e0));
  }
  {
    BRepGraph g;
    build(g, makeBox());
    auto v = g.Editor().Vertices().Add(gp_Pnt(0, 0, 0), 0.01);
    g.Editor().CommitMutation();
    printf("commitAfterAdd: v=%d vertices=%d active=%d deferred=%d\n", (int)v.Index,
           g.Topo().Vertices().Nb(), g.Topo().Vertices().NbActive(),
           (int)g.Editor().IsDeferredMode());
  }
  {
    BRepGraph g;
    build(g, makeBox());
    int d0 = g.Editor().IsDeferredMode();
    g.Editor().BeginDeferredInvalidation();
    int d1 = g.Editor().IsDeferredMode();
    g.Editor().EndDeferredInvalidation();
    int d2 = g.Editor().IsDeferredMode();
    printf("deferredModeToggle: initial=%d afterBegin=%d afterEnd=%d\n", d0, d1, d2);
  }
  {
    BRepGraph g;
    build(g, makeBox());
    g.Editor().BeginDeferredInvalidation();
    int  d1 = g.Editor().IsDeferredMode();
    auto a  = g.Editor().Vertices().Add(gp_Pnt(1, 2, 3), 0.001);
    auto b  = g.Editor().Vertices().Add(gp_Pnt(4, 5, 6), 0.001);
    g.Editor().EndDeferredInvalidation();
    int d2 = g.Editor().IsDeferredMode();
    g.Editor().CommitMutation();
    gp_Pnt pb = BRepGraph_Tool::Vertex::Pnt(g, b);
    printf("deferredModeWithMutations: duringDeferred=%d a=%d b=%d afterEnd=%d afterCommit=%d "
           "vertices=%d b=(%g, %g, %g)\n",
           d1, (int)a.Index, (int)b.Index, d2, (int)g.Editor().IsDeferredMode(),
           g.Topo().Vertices().Nb(), pb.X(), pb.Y(), pb.Z());
  }
  {
    BRepGraph g;
    build(g, makeBox());
    int              last = g.Topo().Vertices().Nb() - 1;
    BRepGraph_NodeId nid(BRepGraph_NodeId::Kind::Vertex, last);
    int              r0 = g.Topo().Gen().IsRemoved(nid);
    g.Editor().Gen().RemoveNode(nid);
    printf("removeVertex: index=%d removedBefore=%d removedAfter=%d activeVertices=%d\n", last,
           r0, (int)g.Topo().Gen().IsRemoved(nid), g.Topo().Vertices().NbActive());
  }
  {
    BRepGraph g;
    build(g, makeBox());
    int              last = g.Topo().Faces().Nb() - 1;
    BRepGraph_NodeId nid(BRepGraph_NodeId::Kind::Face, last);
    g.Editor().Gen().RemoveSubgraph(nid);
    printf("removeSubgraph: index=%d removedAfter=%d activeFaces=%d\n", last,
           (int)g.Topo().Gen().IsRemoved(nid), g.Topo().Faces().NbActive());
  }
  {
    BRepGraph g;
    build(g, makeBox());
    int             n = g.Refs().Shells().Nb();
    BRepGraph_RefId rid(BRepGraph_RefId::Kind::Shell, 0);
    int             before = g.Refs().Gen().IsRemoved(rid);
    bool            ok     = g.Editor().Gen().RemoveRef(rid);
    printf("removeShellRef: shellRefs=%d removedBefore=%d returned=%d removedAfter=%d "
           "shellRefsAfter=%d secondRemove=%d\n",
           n, before, (int)ok, (int)g.Refs().Gen().IsRemoved(rid), g.Refs().Shells().Nb(),
           (int)g.Editor().Gen().RemoveRef(rid));
  }
  return 0;
}
