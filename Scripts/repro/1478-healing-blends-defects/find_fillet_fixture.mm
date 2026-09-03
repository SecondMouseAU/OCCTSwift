// Scratch: find a 5-vertex polygon + radius where AddFillet fails at a MIDDLE vertex (not last),
// matching issue #1478's own reproducer shape. Builds the wire exactly the way
// OCCTWireCreatePolygon (OCCTBridge_Modeling_WireEdgeFaceBuilders.mm, backing Wire.polygon)
// does -- BRepBuilderAPI_MakeWire fed one BRepBuilderAPI_MakeEdge(p_i, p_i+1) at a time -- so the
// vertex ordering matches what the real Swift regression test will see. Prints per-vertex
// Status() so the parameters can be transcribed into the real test.
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepTools.hxx>
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
    case ChFi2d_NotPlanar:
      return "NotPlanar";
    case ChFi2d_ParametersError:
      return "ParametersError";
    case ChFi2d_ConnexionError:
      return "ConnexionError";
    case ChFi2d_TangencyError:
      return "TangencyError";
    default:
      return "unknown";
  }
}

static void tryPolygon(const char* label, const std::vector<gp_Pnt>& pts, double radius)
{
  BRepBuilderAPI_MakeWire wireMaker;
  for (size_t i = 0; i + 1 < pts.size(); i++)
  {
    TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(pts[i], pts[i + 1]);
    wireMaker.Add(edge);
  }
  TopoDS_Edge closing = BRepBuilderAPI_MakeEdge(pts.back(), pts.front());
  wireMaker.Add(closing);

  TopoDS_Wire wire = wireMaker.Wire();
  BRepBuilderAPI_MakeFace makeFace(wire, true);
  if (!makeFace.IsDone())
  {
    printf("%s: face construction failed\n", label);
    return;
  }
  TopoDS_Face face = makeFace.Face();

  TopTools_IndexedMapOfShape vertexMap;
  TopExp::MapShapes(wire, TopAbs_VERTEX, vertexMap);
  printf("%s: vertexMap.Extent()=%d radius=%.3f\n", label, vertexMap.Extent(), radius);

  ChFi2d_Builder fillet2d(face);
  int            nFail = 0;
  for (int v = 1; v <= vertexMap.Extent(); v++)
  {
    TopoDS_Vertex            vertex     = TopoDS::Vertex(vertexMap(v));
    gp_Pnt                   p          = BRep_Tool::Pnt(vertex);
    TopoDS_Edge              filletEdge = fillet2d.AddFillet(vertex, radius);
    ChFi2d_ConstructionError s          = fillet2d.Status();
    printf("  vertex %d (%.2f,%.2f): filletEdge.IsNull=%d status=%s\n", v, p.X(), p.Y(),
           filletEdge.IsNull(), statusName(s));
    if (s != ChFi2d_IsDone)
      nFail++;
  }
  ChFi2d_ConstructionError finalStatus = fillet2d.Status();
  printf("  FINAL Status() after loop: %s, nFail=%d, NbFillet()=%d\n", statusName(finalStatus),
         nFail, fillet2d.NbFillet());
}

// Mirrors OCCTWireFilletAll2D as it existed BEFORE #1478's fix: only the post-loop Status() is
// checked, so a mid-loop failure masked by a later success is missed and the (wrong) partial
// result is returned. Prints the resulting outer wire's edge count so the Swift regression test's
// assertion can be shown to actually distinguish old vs. new behavior.
static void tryOldBridgeLogic(const char* label, const std::vector<gp_Pnt>& pts, double radius)
{
  BRepBuilderAPI_MakeWire wireMaker;
  for (size_t i = 0; i + 1 < pts.size(); i++)
    wireMaker.Add(BRepBuilderAPI_MakeEdge(pts[i], pts[i + 1]));
  wireMaker.Add(BRepBuilderAPI_MakeEdge(pts.back(), pts.front()));
  TopoDS_Wire originalWire = wireMaker.Wire();

  TopTools_IndexedMapOfShape origEdgeMap;
  TopExp::MapShapes(originalWire, TopAbs_EDGE, origEdgeMap);

  BRepBuilderAPI_MakeFace makeFace(originalWire, true);
  TopoDS_Face             face = makeFace.Face();

  TopTools_IndexedMapOfShape vertexMap;
  TopExp::MapShapes(originalWire, TopAbs_VERTEX, vertexMap);

  ChFi2d_Builder fillet2d(face);
  for (int v = 1; v <= vertexMap.Extent(); v++)
  {
    TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(v));
    fillet2d.AddFillet(vertex, radius);
  }

  TopoDS_Wire resultWire;
  bool        fellBackToOriginal;
  if (fillet2d.Status() != ChFi2d_IsDone)
  {
    resultWire         = originalWire;
    fellBackToOriginal = true;
  }
  else
  {
    TopoDS_Face resultFace = TopoDS::Face(fillet2d.Result());
    resultWire             = BRepTools::OuterWire(resultFace);
    fellBackToOriginal     = false;
  }

  TopTools_IndexedMapOfShape resultEdgeMap;
  TopExp::MapShapes(resultWire, TopAbs_EDGE, resultEdgeMap);

  printf(
    "%s (OLD bridge logic): originalEdges=%d resultEdges=%d fellBackToOriginal=%d "
    "(BUG: should have fallen back, since a mid-loop vertex failed, but didn't)\n",
    label, origEdgeMap.Extent(), resultEdgeMap.Extent(), fellBackToOriginal);
}

// Mirrors OCCTWireFilletAll2D as it exists AFTER #1478's fix: anyFailed is tracked across the
// whole loop, so the mid-loop failure is caught and the fallback fires correctly.
static void tryNewBridgeLogic(const char* label, const std::vector<gp_Pnt>& pts, double radius)
{
  BRepBuilderAPI_MakeWire wireMaker;
  for (size_t i = 0; i + 1 < pts.size(); i++)
    wireMaker.Add(BRepBuilderAPI_MakeEdge(pts[i], pts[i + 1]));
  wireMaker.Add(BRepBuilderAPI_MakeEdge(pts.back(), pts.front()));
  TopoDS_Wire originalWire = wireMaker.Wire();

  TopTools_IndexedMapOfShape origEdgeMap;
  TopExp::MapShapes(originalWire, TopAbs_EDGE, origEdgeMap);

  BRepBuilderAPI_MakeFace makeFace(originalWire, true);
  TopoDS_Face             face = makeFace.Face();

  TopTools_IndexedMapOfShape vertexMap;
  TopExp::MapShapes(originalWire, TopAbs_VERTEX, vertexMap);

  ChFi2d_Builder fillet2d(face);
  bool           anyFailed = false;
  for (int v = 1; v <= vertexMap.Extent(); v++)
  {
    TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(v));
    fillet2d.AddFillet(vertex, radius);
    if (fillet2d.Status() != ChFi2d_IsDone)
      anyFailed = true;
  }

  TopoDS_Wire resultWire;
  if (anyFailed)
  {
    resultWire = originalWire;
  }
  else
  {
    TopoDS_Face resultFace = TopoDS::Face(fillet2d.Result());
    resultWire             = BRepTools::OuterWire(resultFace);
  }

  TopTools_IndexedMapOfShape resultEdgeMap;
  TopExp::MapShapes(resultWire, TopAbs_EDGE, resultEdgeMap);

  printf("%s (NEW bridge logic): originalEdges=%d resultEdges=%d anyFailed=%d\n", label,
         origEdgeMap.Extent(), resultEdgeMap.Extent(), anyFailed);
}

int main()
{
  // Irregular pentagon with a very short edge near the 3rd vertex, forcing AddFillet to fail
  // there for a radius the other four corners tolerate.
  std::vector<gp_Pnt> pentagon = {gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10.2, 0.3, 0),
                                   gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0)};
  tryPolygon("pentagonA-r1.0", pentagon, 1.0);
  tryOldBridgeLogic("pentagonA-r1.0", pentagon, 1.0);
  tryNewBridgeLogic("pentagonA-r1.0", pentagon, 1.0);
  return 0;
}
