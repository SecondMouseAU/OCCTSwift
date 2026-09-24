// Epic #766 kernel-parity probe for OCCTBRepGraphTests, files:
//   BRepGraphBuilderValidateMutationTests, BRepGraphBuildTests, BRepGraphCoEdgeQueryTests.
// Mirrors the bridge: OCCTShapeCreateBox/Sphere/Cylinder, OCCTShapeUnion (BRepAlgoAPI_Fuse),
// OCCTBRepGraphCreate (Clear() then Shapes().Add, CreateAutoProduct = false), and the calls
// behind OCCTBRepGraphNb*, OCCTBRepGraphValidate, OCCTBRepGraphBuilderValidateMutation and
// OCCTBRepGraphCoEdge{Edge,Face,SeamPair,HasPCurve,Range}.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_Validate.hxx>
#include <cstdio>

static TopoDS_Shape box(double w, double h, double d)
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-w / 2, -h / 2, -d / 2), w, h, d).Shape();
}

static void build(BRepGraph& g, const TopoDS_Shape& s, bool parallel = false)
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = parallel;
  opts.CreateAutoProduct = false;
  g.Shapes().Add(s, opts);
}

static void counts(const char* label, BRepGraph& g)
{
  printf("%s: faces=%d edges=%d vertices=%d wires=%d shells=%d solids=%d compounds=%d "
         "coedges=%d nodes=%d valid=%d\n",
         label, g.Topo().Faces().Nb(), g.Topo().Edges().Nb(), g.Topo().Vertices().Nb(),
         g.Topo().Wires().Nb(), g.Topo().Shells().Nb(), g.Topo().Solids().Nb(),
         g.Topo().Compounds().Nb(), g.Topo().CoEdges().Nb(), g.Topo().Gen().NbNodes(),
         (int)BRepGraph_Validate::Perform(g).IsValid());
}

int main()
{
  {
    BRepGraph g;
    build(g, box(10, 10, 10));
    printf("validateCleanGraph: %d\n", (int)g.Editor().ValidateMutationBoundary());
  }
  {
    BRepGraph g;
    build(g, box(10, 10, 10));
    g.Editor().Vertices().Add(gp_Pnt(0, 0, 0), 0.01);
    g.Editor().CommitMutation();
    printf("validateAfterAddVertex: %d\n", (int)g.Editor().ValidateMutationBoundary());
  }
  {
    BRepGraph g;
    build(g, box(10, 20, 30));
    counts("buildFromBox", g);
  }
  {
    BRepGraph g;
    build(g, box(10, 20, 30), true);
    counts("buildParallel", g);
  }
  {
    BRepGraph g;
    build(g, BRepPrimAPI_MakeSphere(5).Shape());
    counts("buildFromSphere", g);
  }
  {
    BRepAlgoAPI_Fuse fuser(box(20, 20, 20), BRepPrimAPI_MakeCylinder(5, 30).Shape());
    fuser.Build();
    BRepGraph g;
    build(g, fuser.Shape());
    counts("buildFromComplex", g);
  }
  {
    BRepGraph g;
    build(g, box(10, 10, 10));
    BRepGraph_CoEdgeId c0(0);
    auto               r = BRepGraph_Tool::CoEdge::Range(g, c0);
    auto               p = BRepGraph_Tool::CoEdge::SeamPair(g, c0);
    int nPC = 0, nSeam = 0;
    for (int i = 0; i < g.Topo().CoEdges().Nb(); ++i)
    {
      nPC += BRepGraph_Tool::CoEdge::HasPCurve(g, BRepGraph_CoEdgeId(i)) ? 1 : 0;
      nSeam += BRepGraph_Tool::CoEdge::SeamPair(g, BRepGraph_CoEdgeId(i)).IsValid() ? 1 : 0;
    }
    printf("box coedge0: edge=%d face=%d seamPair=%d hasPCurve=%d range=(%.17g, %.17g)\n",
           (int)g.Topo().CoEdges().Edge(c0).Index, (int)g.Topo().CoEdges().Face(c0).Index,
           p.IsValid() ? (int)p.Index : -1, (int)BRepGraph_Tool::CoEdge::HasPCurve(g, c0),
           r.first, r.second);
    printf("box coedges: total=%d withPCurve=%d withSeamPair=%d\n", g.Topo().CoEdges().Nb(),
           nPC, nSeam);
  }
  {
    BRepGraph g;
    build(g, BRepPrimAPI_MakeSphere(5).Shape());
    printf("sphere coedges: total=%d", g.Topo().CoEdges().Nb());
    for (int i = 0; i < g.Topo().CoEdges().Nb(); ++i)
    {
      auto p = BRepGraph_Tool::CoEdge::SeamPair(g, BRepGraph_CoEdgeId(i));
      printf(" [%d edge=%d pair=%d]", i, (int)g.Topo().CoEdges().Edge(BRepGraph_CoEdgeId(i)).Index,
             p.IsValid() ? (int)p.Index : -1);
    }
    printf("\n");
  }
  return 0;
}
