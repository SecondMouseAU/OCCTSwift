// Scratch: find a closed 4-edge wire, built the way Wire.wireFromEdges (BRepLib_MakeWire::Add,
// one edge at a time, OCCTWireMakeWireFromEdgeRefs) does, whose TopExp::MapShapes insertion order
// diverges from its true BRepTools_WireExplorer connection order -- issue #1478 Finding 2's own
// shape. Prints both orders, then simulates the OLD (TopExp::MapShapes-pairing) and NEW
// (BRepTools_WireExplorer-pairing) OCCTWireChamferAll2D logic on the same wire so the divergence
// in outcome can be transcribed into the real Swift regression test.
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepTools.hxx>
#include <BRepTools_WireExplorer.hxx>
#include <ChFi2d_Builder.hxx>
#include <ChFi2d_ConstructionError.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>
#include <vector>

static const char* statusName(ChFi2d_ConstructionError s)
{
  switch (s)
  {
    case ChFi2d_IsDone:
      return "IsDone";
    case ChFi2d_ComputationError:
      return "ComputationError";
    default:
      return "other";
  }
}

static void label(char* buf, const TopoDS_Edge& e)
{
  gp_Pnt p1 = BRep_Tool::Pnt(TopExp::FirstVertex(e));
  gp_Pnt p2 = BRep_Tool::Pnt(TopExp::LastVertex(e));
  snprintf(buf, 64, "(%.0f,%.0f)-(%.0f,%.0f)", p1.X(), p1.Y(), p2.X(), p2.Y());
}

int main()
{
  gp_Pnt A(0, 0, 0), B(10, 0, 0), C(10, 10, 0), D(0, 10, 0);

  TopoDS_Edge eAB = BRepBuilderAPI_MakeEdge(A, B);
  TopoDS_Edge eBC = BRepBuilderAPI_MakeEdge(B, C);
  TopoDS_Edge eCD = BRepBuilderAPI_MakeEdge(C, D);
  TopoDS_Edge eDA = BRepBuilderAPI_MakeEdge(D, A);

  // Add order deliberately NOT sequential: eBC first, then eAB attaches to eBC's free START
  // (vertex B), then eCD extends the free END (vertex C), then eDA closes both remaining free
  // ends. Matches issue #1478's own "a later edge attaches to the free start of the chain" shape.
  BRepBuilderAPI_MakeWire wireMaker;
  wireMaker.Add(eBC);
  wireMaker.Add(eAB);
  wireMaker.Add(eCD);
  wireMaker.Add(eDA);
  TopoDS_Wire wire = wireMaker.Wire();
  printf("wire.Closed()=%d\n", wire.Closed());

  TopTools_IndexedMapOfShape edgeMap;
  TopExp::MapShapes(wire, TopAbs_EDGE, edgeMap);
  printf("TopExp::MapShapes order (insertion order):\n");
  for (int i = 1; i <= edgeMap.Extent(); i++)
  {
    char buf[64];
    label(buf, TopoDS::Edge(edgeMap(i)));
    printf("  [%d] %s\n", i, buf);
  }

  printf("BRepTools_WireExplorer order (true connection order):\n");
  {
    int i = 1;
    for (BRepTools_WireExplorer exp(wire); exp.More(); exp.Next(), i++)
    {
      char buf[64];
      label(buf, exp.Current());
      printf("  [%d] %s\n", i, buf);
    }
  }

  BRepBuilderAPI_MakeFace makeFace(wire, true);
  if (!makeFace.IsDone())
  {
    printf("face construction failed\n");
    return 1;
  }
  TopoDS_Face face = makeFace.Face();

  const double distance = 1.0;

  // --- OLD logic: TopExp::MapShapes index pairing (i, i%N + 1) + shares-vertex guard ---
  {
    ChFi2d_Builder chamfer2d(face);
    int            nAttempted = 0, nOk = 0;
    for (int i = 1; i <= edgeMap.Extent(); i++)
    {
      TopoDS_Edge edge1   = TopoDS::Edge(edgeMap(i));
      int         nextIdx = (i % edgeMap.Extent()) + 1;
      TopoDS_Edge edge2   = TopoDS::Edge(edgeMap(nextIdx));

      TopoDS_Vertex v1_1, v1_2, v2_1, v2_2;
      TopExp::Vertices(edge1, v1_1, v1_2);
      TopExp::Vertices(edge2, v2_1, v2_2);
      bool sharesVertex =
        v1_1.IsSame(v2_1) || v1_1.IsSame(v2_2) || v1_2.IsSame(v2_1) || v1_2.IsSame(v2_2);
      if (sharesVertex)
      {
        nAttempted++;
        chamfer2d.AddChamfer(edge1, edge2, distance, distance);
        if (chamfer2d.Status() == ChFi2d_IsDone)
          nOk++;
      }
    }
    TopoDS_Wire resultWire;
    if (chamfer2d.Status() != ChFi2d_IsDone)
      resultWire = wire;
    else
      resultWire = BRepTools::OuterWire(TopoDS::Face(chamfer2d.Result()));
    TopTools_IndexedMapOfShape resultEdges;
    TopExp::MapShapes(resultWire, TopAbs_EDGE, resultEdges);
    printf(
      "OLD chamfer logic: attempted=%d ok=%d finalStatus=%s resultEdgeCount=%d "
      "(origEdges=%d)\n",
      nAttempted, nOk, statusName(chamfer2d.Status()), resultEdges.Extent(), edgeMap.Extent());
  }

  // --- NEW logic: BRepTools_WireExplorer order pairing + anyFailed tracking ---
  {
    std::vector<TopoDS_Edge> edges;
    for (BRepTools_WireExplorer exp(wire); exp.More(); exp.Next())
      edges.push_back(exp.Current());

    ChFi2d_Builder chamfer2d(face);
    bool           anyFailed = false;
    for (size_t i = 0; i < edges.size(); i++)
    {
      const TopoDS_Edge& edge1 = edges[i];
      const TopoDS_Edge& edge2 = edges[(i + 1) % edges.size()];
      chamfer2d.AddChamfer(edge1, edge2, distance, distance);
      if (chamfer2d.Status() != ChFi2d_IsDone)
        anyFailed = true;
    }
    TopoDS_Wire resultWire;
    if (anyFailed)
      resultWire = wire;
    else
      resultWire = BRepTools::OuterWire(TopoDS::Face(chamfer2d.Result()));
    TopTools_IndexedMapOfShape resultEdges;
    TopExp::MapShapes(resultWire, TopAbs_EDGE, resultEdges);
    printf("NEW chamfer logic: anyFailed=%d resultEdgeCount=%d (origEdges=%zu)\n", anyFailed,
           resultEdges.Extent(), edges.size());
  }

  return 0;
}
