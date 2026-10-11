// Epic #766 kernel-parity probe for OCCTBRepGraphTests, files:
//   BRepGraph{Compact,Compound,CompSolidCount,Copy,Count,Deduplicate}Tests.
// Mirrors the bridge: OCCTShapeCreateBox / BoxAt, OCCTShapeCreateCompound (BRep_Builder),
// OCCTBRepGraphCreate (Clear() then Shapes().Add, CreateAutoProduct = false), and the calls
// behind OCCTBRepGraphCompact, OCCTBRepGraphDeduplicate, OCCTBRepGraphCopy / CopyFace,
// OCCTBRepGraphCompound{Child,Parent}Count and the OCCTBRepGraphNb* counters.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <TopoDS_Compound.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_Compact.hxx>
#include <BRepGraph_Deduplicate.hxx>
#include <BRepGraph_Copy.hxx>
#include <BRepGraph_ReverseIterator.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraphInc_Relations.hxx>
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

int main()
{
  {
    BRepGraph g;
    build(g, box10());
    int  before = g.Topo().Gen().NbNodes();
    auto r      = BRepGraph_Compact::Perform(g);
    printf("compactBox: nodesBefore=%d removedVertices=%d removedEdges=%d removedFaces=%d "
           "nodesAfter=%d\n",
           before, r.NbRemovedVertices, r.NbRemovedEdges, r.NbRemovedFaces, r.NbNodesAfter);
  }
  {
    BRepGraph g;
    build(g, box10());
    g.Editor().Gen().RemoveNode(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Vertex, 7));
    auto r = BRepGraph_Compact::Perform(g);
    printf("compactAfterRemove: removedVertices=%d removedEdges=%d removedFaces=%d "
           "nodesAfter=%d vertices=%d\n",
           r.NbRemovedVertices, r.NbRemovedEdges, r.NbRemovedFaces, r.NbNodesAfter,
           g.Topo().Vertices().Nb());
  }
  {
    // Shape.box(origin:) -> OCCTShapeCreateBoxAt, whose corner is the origin argument.
    TopoDS_Shape    b1 = box10();
    TopoDS_Shape    b2 = BRepPrimAPI_MakeBox(gp_Pnt(20, 0, 0), 10, 10, 10).Shape();
    BRep_Builder    bb;
    TopoDS_Compound c;
    bb.MakeCompound(c);
    bb.Add(c, b1);
    bb.Add(c, b2);
    BRepGraph g;
    build(g, c);
    int nParents = 0;
    const auto& refs = g.Topo().Gen().CompoundRefIds(
      BRepGraph_NodeId(BRepGraph_NodeId::Kind::Compound, 0));
    for (BRepGraph_CompoundsOfCompound it(g, refs); it.More(); it.Next())
      ++nParents;
    printf("compoundQueriesOnCompound: compounds=%d solids=%d children=%d parents=%d\n",
           g.Topo().Compounds().Nb(), g.Topo().Solids().Nb(),
           (int)g.Topo().Compounds().Relations(BRepGraph_CompoundId(0)).ChildRefIds.Size(),
           nParents);
  }
  {
    BRepGraph g;
    build(g, box10());
    printf("compSolidCount: %d\n", g.Topo().CompSolids().Nb());
  }
  {
    BRepGraph g;
    build(g, box10());
    BRepGraph c1, c2;
    bool      ok1 = BRepGraph_Copy::Perform(g, c1, BRepGraph_Copy::GeomPolicy::Copy);
    bool      ok2 = BRepGraph_Copy::Perform(g, c2, BRepGraph_Copy::GeomPolicy::Share);
    printf("deepCopy: ok=%d faces=%d edges=%d vertices=%d surfaces=%d\n", (int)ok1,
           c1.Topo().Faces().Nb(), c1.Topo().Edges().Nb(), c1.Topo().Vertices().Nb(),
           c1.Topo().Geometry().NbFaceSurfaces());
    printf("lightCopy: ok=%d faces=%d edges=%d vertices=%d\n", (int)ok2, c2.Topo().Faces().Nb(),
           c2.Topo().Edges().Nb(), c2.Topo().Vertices().Nb());
    BRepGraph f;
    f.Clear();
    auto m = BRepGraph_Copy::CopyNode(g, f, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 0),
                                      BRepGraph_Copy::GeomPolicy::Copy);
    printf("copyFace: valid=%d faces=%d edges=%d vertices=%d wires=%d\n", (int)m.IsValid(),
           f.Topo().Faces().Nb(), f.Topo().Edges().Nb(), f.Topo().Vertices().Nb(),
           f.Topo().Wires().Nb());
  }
  {
    BRepGraph g;
    build(g, box10());
    printf("activeCounts: faces=%d edges=%d vertices=%d\n", g.Topo().Faces().NbActive(),
           g.Topo().Edges().NbActive(), g.Topo().Vertices().NbActive());
    printf("geometryCounts: surfaces=%d curves3d=%d curves2d=%d\n",
           g.Topo().Geometry().NbFaceSurfaces(), g.Topo().Geometry().NbEdgeCurves3D(),
           g.Topo().Geometry().NbCoEdgeCurves2D());
    printf("coedgeCounts: %d\n", g.Topo().CoEdges().Nb());
  }
  {
    BRepGraph g;
    build(g, box10());
    auto r = BRepGraph_Deduplicate::Perform(g);
    printf("deduplicateBox: canonicalSurfaces=%d canonicalCurves=%d surfaceRewrites=%d "
           "curveRewrites=%d\n",
           r.NbCanonicalSurfaces, r.NbCanonicalCurves, r.NbSurfaceRewrites, r.NbCurveRewrites);
  }
  return 0;
}
