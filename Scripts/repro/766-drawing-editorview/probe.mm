// Epic #766, OCCTDrawingTests: EditorViewAddRemoveTests, EditorViewProductOpsTests,
// EditorViewSettersTests, EditorViewV164Tests. The same BRepGraph calls the bridge makes
// (OCCTBridge_BRepGraph.mm), on a graph built from the same centred 10x10x10 box the way
// OCCTBRepGraphCreate builds it (Clear, then Shapes().Add with CreateAutoProduct = false).
// Kinds follow the bridge's kindFromInt: 0 Solid, 1 Shell, 2 Face, 3 Wire, 4 Edge.
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepGraph.hxx>
#include <BRepGraph_LayerTopoSupplement.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_MeshView.hxx>
#include <BRepGraph_RefsView.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_SupplementEditor.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <NCollection_Array1.hxx>
#include <Poly_Triangulation.hxx>
#include <gp_Trsf.hxx>
#include <cstdio>

static void build(BRepGraph& g)
{
  g.Clear();
  BRepGraph::ShapesView::Options opts;
  opts.Parallel          = false;
  opts.CreateAutoProduct = false;
  g.Shapes().Add(BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(), opts);
}

static TopLoc_Location translation(double x, double y, double z)
{
  gp_Trsf t;
  t.SetTranslation(gp_Vec(x, y, z));
  return TopLoc_Location(t);
}

static void printLoc(const char* tag, const TopLoc_Location& l)
{
  gp_XYZ v = l.Transformation().TranslationPart();
  printf("%s: translation=(%g, %g, %g)\n", tag, v.X(), v.Y(), v.Z());
}

static TopoDS_Vertex vertexShape(BRepGraph& g, int i)
{
  return BRepBuilderAPI_MakeVertex(BRepGraph_Tool::Vertex::Pnt(g, BRepGraph_VertexId(i))).Vertex();
}

int main()
{
  {
    BRepGraph g;
    build(g);
    // addOpsSafe, in the test's order on one graph.
    uint64_t e = g.Editor().Supplement().AttachToEdge(
      BRepGraph_EdgeId(0), vertexShape(g, 0),
      BRepGraph_LayerTopoSupplement::AttachmentKind::EdgeInternalVertex);
    uint64_t f = g.Editor().Supplement().AttachToFace(
      BRepGraph_FaceId(0), vertexShape(g, 0),
      BRepGraph_LayerTopoSupplement::AttachmentKind::FaceDirectVertex);
    printf("addOpsSafe: edgeInternalVertex uid=%llu faceVertex uid=%llu\n", (unsigned long long)e,
           (unsigned long long)f);
    // shellAddChild/solidAddChild with childKind 4 (Edge) fail the bridge's kind check before any
    // OCCT call; compoundAddChild / compSolidAddSolid reach the editor.
    auto c = g.Editor().Compounds().Append(BRepGraph_CompoundId(0),
                                           BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0),
                                           TopAbs_FORWARD);
    auto cs = g.Editor().CompSolids().Append(BRepGraph_CompSolidId(0), BRepGraph_SolidId(0),
                                             TopAbs_FORWARD);
    printf("addOpsSafe: compoundAppend valid=%d compSolidAppend valid=%d\n", c.IsValid(),
           cs.IsValid());
  }
  {
    BRepGraph g;
    build(g);
    printf("removeOpsSafe: edgeRemoveVertex=%d edgeReplaceVertex valid=%d wireRemoveCoEdge=%d "
           "removeAttachment=%d faceRemoveWire=%d shellRemoveFace=%d\n",
           g.Editor().Edges().RemoveVertex(BRepGraph_EdgeId(0), BRepGraph_VertexRefId(99999)),
           g.Editor()
             .Edges()
             .ReplaceVertex(BRepGraph_EdgeId(0), BRepGraph_VertexRefId(99999), BRepGraph_VertexId(0))
             .IsValid(),
           g.Editor().Wires().RemoveCoEdge(BRepGraph_WireId(0), BRepGraph_CoEdgeId(99999)),
           g.Editor().Supplement().RemoveAttachment(99999),
           g.Editor().Faces().RemoveWire(BRepGraph_FaceId(0), BRepGraph_WireRefId(99999)),
           g.Editor().Shells().RemoveFace(BRepGraph_ShellId(0), BRepGraph_FaceRefId(99999)));
  }
  {
    BRepGraph g;
    build(g);
    g.Editor().Vertices().SetPoint(BRepGraph_VertexId(0), gp_Pnt(1.5, 2.5, 3.5));
    g.Editor().Vertices().SetTolerance(BRepGraph_VertexId(0), 0.0001);
    gp_Pnt p = BRepGraph_Tool::Vertex::Pnt(g, BRepGraph_VertexId(0));
    printf("vertexFieldSetters: point=(%.17g, %.17g, %.17g) tolerance=%.17g\n", p.X(), p.Y(), p.Z(),
           BRepGraph_Tool::Vertex::Tolerance(g, BRepGraph_VertexId(0)));
    g.Editor().Edges().SetTolerance(BRepGraph_EdgeId(0), 0.001);
    g.Editor().Edges().SetParamRange(BRepGraph_EdgeId(0), 0.25, 7.5);
    auto r = BRepGraph_Tool::Edge::Range(g, BRepGraph_EdgeId(0));
    printf("edgeFieldSetters: tolerance=%.17g range=(%.17g, %.17g)\n",
           BRepGraph_Tool::Edge::Tolerance(g, BRepGraph_EdgeId(0)), r.first, r.second);
    g.Editor().Faces().SetTolerance(BRepGraph_FaceId(0), 0.005);
    printf("faceFieldSetters: tolerance=%.17g\n", BRepGraph_Tool::Face::Tolerance(g, BRepGraph_FaceId(0)));
  }
  {
    BRepGraph g;
    build(g);
    printf("closure: edge0=%d wire0=%d shell0=%d\n",
           BRepGraph_Tool::Edge::IsClosed(g, BRepGraph_EdgeId(0)),
           BRepGraph_Tool::Wire::IsClosed(g, BRepGraph_WireId(0)),
           BRepGraph_Tool::Shell::IsClosed(g, BRepGraph_ShellId(0)));
    printf("refSetters: coedge0 before edge=%u face=%u\n", g.Topo().CoEdges().Edge(BRepGraph_CoEdgeId(0)).Index,
           g.Topo().CoEdges().Face(BRepGraph_CoEdgeId(0)).Index);
    g.Editor().CoEdges().SetChildEdgeId(BRepGraph_CoEdgeId(0), BRepGraph_EdgeId(5));
    g.Editor().CoEdges().SetFaceId(BRepGraph_CoEdgeId(0), BRepGraph_FaceId(3));
    printf("refSetters: coedge0 after SetChildEdgeId(5)/SetFaceId(3) edge=%u face=%u\n",
           g.Topo().CoEdges().Edge(BRepGraph_CoEdgeId(0)).Index,
           g.Topo().CoEdges().Face(BRepGraph_CoEdgeId(0)).Index);
  }
  {
    BRepGraph g;
    build(g);
    printf("cachedMesh fresh: face=%d edge=%d coedge=%d\n",
           g.Mesh().Cache().Faces().Has(BRepGraph_FaceId(0)),
           g.Mesh().Cache().Edges().Has(BRepGraph_EdgeId(0)),
           g.Mesh().Cache().CoEdges().Has(BRepGraph_CoEdgeId(0)));
    NCollection_Array1<gp_Pnt> nodes(1, 3);
    nodes(1) = gp_Pnt(0, 0, 0);
    nodes(2) = gp_Pnt(1, 0, 0);
    nodes(3) = gp_Pnt(0, 1, 0);
    NCollection_Array1<Poly_Triangle> tris(1, 1);
    tris(1) = Poly_Triangle(1, 2, 3);
    Handle(Poly_Triangulation) tri = new Poly_Triangulation(nodes, tris);
    g.Mesh().Editor().Faces().SetCachedTriangulation(BRepGraph_FaceId(0), tri);
    printf("cachedMesh after SetCachedTriangulation: face=%d\n",
           g.Mesh().Cache().Faces().Has(BRepGraph_FaceId(0)));
  }
  {
    BRepGraph g;
    build(g);
    auto parent = g.Editor().Products().Add();
    auto child  = g.Editor().Products().Add(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0),
                                           TopLoc_Location());
    if (child.IsValid())
      g.Editor().Products().AppendDocumentRoot(child);
    BRepGraph_OccurrenceRefId ref;
    auto occ = g.Editor().Products().Append(parent, child, translation(5, 6, 7),
                                            BRepGraph_OccurrenceId(), &ref);
    printf("products: parent=%u child=%u occurrence=%u occurrenceRef=%u\n", parent.Index,
           child.Index, occ.Index, ref.Index);
    BRepGraph_RefId rid(BRepGraph_RefId::Kind::Occurrence, ref.Index);
    printLoc("occurrenceRef after link", g.Refs().Gen().LocalLocation(rid));
    g.Editor().Occurrences().SetRefLocalLocation(ref, translation(11, 12, 13));
    printLoc("occurrenceRef after set", g.Refs().Gen().LocalLocation(rid));
    printf("productRemoveOccurrence(99999, 99999)=%d\n",
           g.Editor().Products().RemoveOccurrence(BRepGraph_ProductId(99999),
                                                  BRepGraph_OccurrenceRefId(99999)));
  }
  {
    BRepGraph                            g;
    NCollection_Array1<BRepGraph_NodeId> kids(0, 0);
    build(g);
    kids.SetValue(0, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0));
    auto comp = g.Editor().Compounds().Add(kids);
    auto cr   = g.Editor().Compounds().Append(comp, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 0),
                                            TopAbs_FORWARD);
    printf("childRef: compound=%u childRef=%u\n", comp.Index, cr.Index);
    BRepGraph_RefId rid(BRepGraph_RefId::Kind::Child, cr.Index);
    g.Editor().Gen().SetChildRefLocalLocation(BRepGraph_ChildRefId(cr.Index), translation(1, 2, 3));
    printLoc("childRef first", g.Refs().Gen().LocalLocation(rid));
    g.Editor().Gen().SetChildRefLocalLocation(BRepGraph_ChildRefId(cr.Index), translation(-4, -5, -6));
    printLoc("childRef second", g.Refs().Gen().LocalLocation(rid));
  }
  return 0;
}
