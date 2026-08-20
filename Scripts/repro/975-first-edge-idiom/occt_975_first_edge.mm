// #975: is the copy-pasted "first edge of a shape" idiom the same answer as occtEdgeAt(shape, 0)?
//
// The idiom, verbatim from OCCTBridge_Modeling.mm and OCCTBridge_Topology.mm:
//
//   if (s.ShapeType() == TopAbs_EDGE) { e = TopoDS::Edge(s); }
//   else { for (TopExp_Explorer exp(s, TopAbs_EDGE); exp.More(); exp.Next()) { e = ...; break; } }
//
// occtEdgeAt(shape, 0) resolves index 0 of TopExp::MapShapes(shape, TopAbs_EDGE), which is a
// deduplicated indexed map rather than a raw explorer walk. Three things have to hold before the
// idiom can be replaced by the existing helper:
//
//   1. TopExp::MapShapes on a shape that IS an edge contains that edge. If it does not, the
//      helper answers null where the idiom answers the edge itself, and every ChFi2d call taking
//      a bare edge would start returning failure.
//   2. Index 0 of the map is the same edge the explorer stops on first. Deduplication only ever
//      removes a LATER duplicate, so this should hold, but a shared edge in a compound is exactly
//      the fixture #541 measured a divergence on for faces, so measure it rather than assume.
//   3. Orientation survives. ChFi2d_FilletAlgo and BRepExtrema_ExtCC both read the edge's own
//      range, so an edge handed over REVERSED where the idiom handed it FORWARD would be a
//      different input, not a cosmetic difference.
//
// Build:
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/975-first-edge-idiom/occt_975_first_edge.mm -o /tmp/occt_975

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>

// The idiom, transcribed unchanged from the seven bridge sites.
static TopoDS_Edge idiomFirstEdge(const TopoDS_Shape& s)
{
  TopoDS_Edge e;
  if (s.ShapeType() == TopAbs_EDGE)
  {
    e = TopoDS::Edge(s);
  }
  else
  {
    for (TopExp_Explorer exp(s, TopAbs_EDGE); exp.More(); exp.Next())
    {
      e = TopoDS::Edge(exp.Current());
      break;
    }
  }
  return e;
}

// occtEdgeAt(shape, 0), transcribed from OCCTBridge_Internal.h (occtEdgeAt over occtSubShapeAt
// over occtMapSubShapes; the type-range and negative-index guards are unreachable at index 0
// with a literal TopAbs_EDGE, so they are dropped here).
static TopoDS_Edge helperFirstEdge(const TopoDS_Shape& s)
{
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes(s, TopAbs_EDGE, map);
  if (map.Extent() < 1)
    return TopoDS_Edge();
  TopoDS_Shape sub = map(1);
  if (sub.IsNull() || sub.ShapeType() != TopAbs_EDGE)
    return TopoDS_Edge();
  return TopoDS::Edge(sub);
}

static int failures = 0;

static const char* oriName(const TopoDS_Shape& s)
{
  if (s.IsNull())
    return "-";
  switch (s.Orientation())
  {
    case TopAbs_FORWARD:
      return "FWD";
    case TopAbs_REVERSED:
      return "REV";
    case TopAbs_INTERNAL:
      return "INT";
    default:
      return "EXT";
  }
}

static void compare(const char* label, const TopoDS_Shape& s)
{
  TopoDS_Edge a = idiomFirstEdge(s);
  TopoDS_Edge b = helperFirstEdge(s);

  bool bothNull = a.IsNull() && b.IsNull();
  bool same     = bothNull || (!a.IsNull() && !b.IsNull() && a.IsSame(b));
  bool sameOri  = bothNull || (same && a.Orientation() == b.Orientation());

  printf("%-46s idiom=%s(%s) helper=%s(%s)  IsSame=%s  sameOrientation=%s%s\n",
         label,
         a.IsNull() ? "null" : "edge",
         oriName(a),
         b.IsNull() ? "null" : "edge",
         oriName(b),
         same ? "yes" : "NO",
         sameOri ? "yes" : "NO",
         (same && sameOri) ? "" : "   <-- DIVERGENCE");
  if (!same || !sameOri)
    failures++;
}

int main()
{
  // 1. The shape IS an edge. This is the branch the helper has to reproduce through MapShapes.
  TopoDS_Edge bare = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge();
  compare("bare edge", bare);

  // 2. A reversed bare edge: the map stores what it is handed, so orientation must survive.
  compare("bare edge, reversed", bare.Reversed());

  // 3. A wire of three distinct edges.
  BRepBuilderAPI_MakePolygon poly(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), true);
  compare("closed triangular wire", poly.Wire());

  // 4. The same wire reversed, so the walk meets REVERSED occurrences.
  compare("closed triangular wire, reversed", poly.Wire().Reversed());

  // 5. A face, whose edges are enumerated the same way.
  TopoDS_Shape    box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopExp_Explorer fexp(box, TopAbs_FACE);
  compare("first face of a box", fexp.Current());

  // 6. A whole solid: 12 edges, each shared by two faces, so the explorer walk yields 24
  //    occurrences over 12 distinct edges and the map collapses them. #541's face divergence
  //    appeared from index 10 onwards; index 0 is the case under test here.
  compare("box solid (24 occurrences, 12 edges)", box);

  // 7. A compound holding the same edge twice, the deduplication case at index 0 itself.
  {
    TopoDS_Compound comp;
    BRep_Builder    builder;
    builder.MakeCompound(comp);
    builder.Add(comp, bare);
    builder.Add(comp, bare);
    compare("compound of one edge, added twice", comp);
  }

  // 8. A compound whose first member is an edge and whose second is a wire.
  {
    TopoDS_Compound comp;
    BRep_Builder    builder;
    builder.MakeCompound(comp);
    builder.Add(comp, bare);
    builder.Add(comp, poly.Wire());
    compare("compound: edge then wire", comp);
  }

  // 9. The same two members the other way round, so "first" has to mean the wire's first edge
  //    rather than the loose edge.
  {
    TopoDS_Compound comp;
    BRep_Builder    builder;
    builder.MakeCompound(comp);
    builder.Add(comp, poly.Wire());
    builder.Add(comp, bare);
    compare("compound: wire then edge", comp);
  }

  // 10. A shape with no edges at all: both must answer null.
  {
    TopoDS_Compound comp;
    BRep_Builder    builder;
    builder.MakeCompound(comp);
    compare("empty compound (no edges)", comp);
  }

  // 11. A vertex: not an edge, contains no edge.
  {
    TopExp_Explorer vexp(box, TopAbs_VERTEX);
    compare("a vertex", vexp.Current());
  }

  printf("\n%s: %d divergence(s)\n", failures == 0 ? "AGREE" : "DISAGREE", failures);
  return failures == 0 ? 0 : 1;
}
