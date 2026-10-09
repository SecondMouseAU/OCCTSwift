// Kernel-parity probe for #1986 (Epic #766): BRepGraphShapeReconstructionTests,
// BRepGraphShellExtendedTests, BRepGraphShellQueryTests, BRepGraphSolidExtendedTests,
// BRepGraphSolidQueryTests. Each block calls the OCCT API the named bridge function calls,
// on the same inputs the Swift test builds.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <Bnd_Box.hxx>
#include <BRepBndLib.hxx>
#include <TopoDS.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_RefsView.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_ReverseIterator.hxx>
#include <BRepGraphInc_Relations.hxx>
#include <cstdio>

static TopoDS_Shape box10()
{
  return BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(); // OCCTShapeCreateBox
}

static void build(BRepGraph& g, const TopoDS_Shape& s) // OCCTBRepGraphCreate
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  auto r                 = g.Shapes().Add(s, opts);
  printf("build ok=%d\n", r.IsOk() ? 1 : 0);
}

int main()
{
  TopoDS_Shape box = box10();
  BRepGraph    g;
  build(g, box);

  // OCCTBRepGraphShapeFromNode (face 0, solid 0)
  TopoDS_Shape face = g.Shapes().Shape(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 0));
  GProp_GProps fp;
  BRepGProp::SurfaceProperties(face, fp);
  printf("reconstructFace: null=%d type=%d area=%.6f\n", face.IsNull() ? 1 : 0,
         (int)face.ShapeType(), fp.Mass());
  TopoDS_Shape solid = g.Shapes().Shape(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0));
  GProp_GProps vp;
  BRepGProp::VolumeProperties(solid, vp);
  printf("reconstructSolid: null=%d type=%d volume=%.6f\n", solid.IsNull() ? 1 : 0,
         (int)solid.ShapeType(), vp.Mass());

  // OCCTBRepGraphHasNode / OCCTBRepGraphFindNode
  auto nid = g.Shapes().FindNode(box);
  printf("findNode: hasNode=%d kind=%d index=%d\n", g.Shapes().HasNode(box) ? 1 : 0,
         nid.IsValid() ? (int)nid.NodeKind : -1, nid.IsValid() ? (int)nid.Index : -1);
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5).Shape();
  printf("hasNodeFalseForUnrelated: hasNode(sphere)=%d\n", g.Shapes().HasNode(sphere) ? 1 : 0);

  // Occurrence placement: OCCTBRepGraphCreateEmptyProduct, ...LinkProductToTopology,
  // ...LinkProducts, ...ShapeFromNode(occurrence), ...GetOccurrenceRefLocalLocation.
  {
    BRepGraph og;
    build(og, box);
    auto parent = og.Editor().Products().Add();
    auto child  = og.Editor().Products().Add(
      BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0), TopLoc_Location());
    if (child.IsValid())
      og.Editor().Products().AppendDocumentRoot(child);
    gp_Trsf t;
    t.SetValues(1, 0, 0, 5, 0, 1, 0, 6, 0, 0, 1, 7);
    BRepGraph_OccurrenceRefId refId;
    auto oid = og.Editor().Products().Append(parent, child, TopLoc_Location(t),
                                             BRepGraph_OccurrenceId(), &refId);
    TopoDS_Shape occ = og.Shapes().Shape(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Occurrence,
                                                          oid.Index));
    Bnd_Box      bb;
    BRepBndLib::AddOptimal(occ, bb, false, false);
    double x0, y0, z0, x1, y1, z1;
    bb.Get(x0, y0, z0, x1, y1, z1);
    printf("occurrence: kernel Shape(occ) bbox=(%.6f,%.6f,%.6f)-(%.6f,%.6f,%.6f)\n", x0, y0, z0,
           x1, y1, z1);
    gp_Trsf lt = og.Refs().Gen().LocalLocation(
      BRepGraph_RefId(BRepGraph_RefId::Kind::Occurrence, refId.Index)).Transformation();
    printf("occurrence: ref local translation=(%.6f,%.6f,%.6f)\n", lt.TranslationPart().X(),
           lt.TranslationPart().Y(), lt.TranslationPart().Z());
    TopoDS_Shape placed = occ.Moved(TopLoc_Location(lt));
    Bnd_Box      pb;
    BRepBndLib::AddOptimal(placed, pb, false, false);
    pb.Get(x0, y0, z0, x1, y1, z1);
    printf("occurrence: Shape(occ) moved by ref location bbox=(%.6f,%.6f,%.6f)-(%.6f,%.6f,%.6f)\n",
           x0, y0, z0, x1, y1, z1);
  }

  // OCCTBRepGraphShellCompoundCount / OCCTBRepGraphShellIsClosed
  printf("shells=%d\n", (int)g.Topo().Shells().Nb());
  {
    const auto& refs =
      g.Topo().Gen().CompoundRefIds(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Shell, 0));
    int n = 0;
    for (BRepGraph_CompoundsOfShell it(g, refs); it.More(); it.Next())
      ++n;
    printf("shellCompoundCount(0)=%d\n", n);
  }
  printf("shellIsClosed(0)=%d\n", BRepGraph_Tool::Shell::IsClosed(g, BRepGraph_ShellId(0)) ? 1 : 0);

  // OCCTBRepGraphShellSolidCount / OCCTBRepGraphShellSolidIndices
  {
    const auto& rel = g.Topo().Shells().Relations(BRepGraph_ShellId(0));
    int         n   = 0;
    for (BRepGraph_SolidsOfShell it(g, rel.ParentShellRefIds); it.More(); it.Next())
    {
      printf("shellSolids(0)[%d]=%d\n", n, (int)it.CurrentId().Index);
      ++n;
    }
    printf("shellSolidCount(0)=%d\n", n);
  }

  // OCCTBRepGraphSolidCompoundCount / OCCTBRepGraphSolidCompSolidCount
  printf("solids=%d\n", (int)g.Topo().Solids().Nb());
  {
    const auto& refs =
      g.Topo().Gen().CompoundRefIds(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0));
    int n = 0;
    for (BRepGraph_CompoundsOfSolid it(g, refs); it.More(); it.Next())
      ++n;
    printf("solidCompoundCount(0)=%d\n", n);
    const auto& rel = g.Topo().Solids().Relations(BRepGraph_SolidId(0));
    int         m   = 0;
    for (BRepGraph_CompSolidsOfSolid it(g, rel.ParentSolidRefIds); it.More(); it.Next())
      ++m;
    printf("solidCompSolidCount(0)=%d\n", m);
  }
  return 0;
}
