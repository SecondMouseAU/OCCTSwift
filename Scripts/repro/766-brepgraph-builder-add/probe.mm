// Epic #766 kernel-parity probe for OCCTBRepGraphTests, files:
//   BRepGraphActiveGeometryTests, BRepGraphBuilderAdd{Compound,CompSolid,FaceToShell,Shell,
//   ShellToSolid,Solid,Vertex}Tests.
// Mirrors the bridge: OCCTShapeCreateBox (BRepPrimAPI_MakeBox from (-w/2,-h/2,-d/2)),
// OCCTBRepGraphCreate (Clear() then Shapes().Add with CreateAutoProduct = false), and the
// EditorView calls in OCCTBRepGraphBuilderAdd*.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_EditorView.hxx>
#include <NCollection_Array1.hxx>
#include <cstdio>

static void build(BRepGraph& g)
{
  TopoDS_Shape box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  g.Shapes().Add(box, opts);
}

int main()
{
  {
    BRepGraph g;
    build(g);
    printf("activeGeometryCounts: surfaces=%d curves3d=%d curves2d=%d\n",
           g.Topo().Geometry().NbActiveFaceSurfaces(),
           g.Topo().Geometry().NbActiveEdgeCurves3D(),
           g.Topo().Geometry().NbActiveCoEdgeCurves2D());
  }
  {
    BRepGraph g;
    build(g);
    int before = g.Topo().Compounds().Nb();
    NCollection_Array1<BRepGraph_NodeId> ch(0, 0);
    ch.SetValue(0, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0));
    auto cid = g.Editor().Compounds().Add(ch);
    printf("addCompoundFromSolids: before=%d idx=%d after=%d\n",
           before, cid.IsValid() ? (int)cid.Index : -1, g.Topo().Compounds().Nb());
  }
  {
    BRepGraph g;
    build(g);
    int before = g.Topo().CompSolids().Nb();
    NCollection_Array1<BRepGraph_SolidId> s(0, 0);
    s.SetValue(0, BRepGraph_SolidId(0));
    auto id = g.Editor().CompSolids().Add(s);
    printf("addCompSolidFromSolids: before=%d idx=%d after=%d\n",
           before, id.IsValid() ? (int)id.Index : -1, g.Topo().CompSolids().Nb());
  }
  {
    BRepGraph g;
    build(g);
    auto sid = g.Editor().Shells().Add();
    auto rid = g.Editor().Shells().Append(sid, BRepGraph_FaceId(0), TopAbs_FORWARD);
    printf("linkFaceToShell: shell=%d ref=%d\n",
           sid.IsValid() ? (int)sid.Index : -1, rid.IsValid() ? (int)rid.Index : -1);
  }
  {
    BRepGraph g;
    build(g);
    int before = g.Topo().Shells().Nb();
    auto sid = g.Editor().Shells().Add();
    printf("addEmptyShell: before=%d idx=%d after=%d\n",
           before, sid.IsValid() ? (int)sid.Index : -1, g.Topo().Shells().Nb());
  }
  {
    BRepGraph g;
    build(g);
    auto solid = g.Editor().Solids().Add();
    auto shell = g.Editor().Shells().Add();
    auto rid   = g.Editor().Solids().Append(solid, shell, TopAbs_FORWARD);
    printf("linkShellToSolid: solid=%d shell=%d ref=%d\n",
           solid.IsValid() ? (int)solid.Index : -1, shell.IsValid() ? (int)shell.Index : -1,
           rid.IsValid() ? (int)rid.Index : -1);
  }
  {
    BRepGraph g;
    build(g);
    int before = g.Topo().Solids().Nb();
    auto sid = g.Editor().Solids().Add();
    printf("addEmptySolid: before=%d idx=%d after=%d\n",
           before, sid.IsValid() ? (int)sid.Index : -1, g.Topo().Solids().Nb());
  }
  {
    BRepGraph g;
    build(g);
    int before = g.Topo().Vertices().Nb();
    auto vid = g.Editor().Vertices().Add(gp_Pnt(5, 5, 5), 1e-7);
    gp_Pnt p = BRepGraph_Tool::Vertex::Pnt(g, vid);
    printf("addVertexToGraph: before=%d idx=%d after=%d pnt=(%.17g, %.17g, %.17g) tol=%.17g\n",
           before, vid.IsValid() ? (int)vid.Index : -1, g.Topo().Vertices().Nb(),
           p.X(), p.Y(), p.Z(), BRepGraph_Tool::Vertex::Tolerance(g, vid));
  }
  {
    BRepGraph g;
    build(g);
    int before = g.Topo().Vertices().Nb();
    auto v1 = g.Editor().Vertices().Add(gp_Pnt(0, 0, 0), 0.01);
    auto v2 = g.Editor().Vertices().Add(gp_Pnt(1, 2, 3), 0.02);
    printf("addMultipleVertices: before=%d v1=%d v2=%d after=%d\n",
           before, v1.IsValid() ? (int)v1.Index : -1, v2.IsValid() ? (int)v2.Index : -1,
           g.Topo().Vertices().Nb());
  }
  return 0;
}
