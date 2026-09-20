// Ground truth for #1652: what does OCCT 8.0.1's BRepGraph actually do for the fourteen
// BRepGraph entry points the bridge implements as silent no-ops or unconditional failures?
//
// Build (from the repo root, per CLAUDE.md's "Compile a Ground Truth C++ Test"):
//
//   clang++ -std=c++17 -ObjC++ -w \
//     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
//     -L"Libraries/OCCT.xcframework/macos-arm64" \
//     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/1652-brepgraph-noop-setters/probe.mm -o /tmp/occt_probe_1652
//   /tmp/occt_probe_1652
//
// The transcript of the run that decided the issue is in transcript.txt next to this file.

#include <cstdio>

#include <Standard_Version.hxx>
#include <cstring>
#include <type_traits>
#include <utility>

#include <BRepGraph.hxx>
#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_MeshView.hxx>
#include <BRepGraph_NodeId.hxx>
#include <BRepGraph_RefId.hxx>
#include <BRepGraph_RefsView.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraphInc_Definition.hxx>
#include <BRepGraphInc_Reference.hxx>
#include <BRepGraphInc_Representation.hxx>

#include <BRepPrimAPI_MakeBox.hxx>
#include <Geom2d_Line.hxx>
#include <NCollection_Array1.hxx>
#include <Poly_PolygonOnTriangulation.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Trsf.hxx>

// ---------------------------------------------------------------------------
// Compile-time storage facts. A member that is not there cannot be written.
// ---------------------------------------------------------------------------

#define DETECT_MEMBER(NAME)                                                                        \
  template <typename T, typename = void>                                                           \
  struct has_##NAME : std::false_type                                                               \
  {                                                                                                \
  };                                                                                               \
  template <typename T>                                                                            \
  struct has_##NAME<T, decltype((void)std::declval<T&>().NAME, void())> : std::true_type            \
  {                                                                                                \
  };

DETECT_MEMBER(LocalLocation)
DETECT_MEMBER(UVBox)
DETECT_MEMBER(UV1)
DETECT_MEMBER(UVFirst)
DETECT_MEMBER(UVPoints)
DETECT_MEMBER(TriangulationRepId)
DETECT_MEMBER(TriangulationId)

static const char* yn(bool b)
{
  return b ? "YES" : "no";
}

static void section(const char* title)
{
  printf("\n=== %s ===\n", title);
}

// ---------------------------------------------------------------------------

static void reportLocation(const char* label, const TopLoc_Location& loc)
{
  const gp_Trsf& t = loc.Transformation();
  printf("  %-46s identity=%-3s translation=(%.3f, %.3f, %.3f)\n",
         label,
         yn(loc.IsIdentity()),
         t.Value(1, 4),
         t.Value(2, 4),
         t.Value(3, 4));
}

static const char* kindName(BRepGraph_RefId::Kind k)
{
  switch (k)
  {
    case BRepGraph_RefId::Kind::Shell:
      return "Shell";
    case BRepGraph_RefId::Kind::Face:
      return "Face";
    case BRepGraph_RefId::Kind::Wire:
      return "Wire";
    case BRepGraph_RefId::Kind::Vertex:
      return "Vertex";
    case BRepGraph_RefId::Kind::Solid:
      return "Solid";
    case BRepGraph_RefId::Kind::Child:
      return "Child";
    case BRepGraph_RefId::Kind::Occurrence:
      return "Occurrence";
  }
  return "?";
}

int main()
{
  printf("OCCT %s, BRepGraph reference-location / coedge-UV / polygon-on-tri ground truth (#1652)\n",
         OCC_VERSION_COMPLETE);

  // -------------------------------------------------------------------------
  section("A. Reference storage structs: which carry a LocalLocation field?");
  // -------------------------------------------------------------------------
  printf("  BRepGraphInc::ShellRef      LocalLocation: %s\n",
         yn(has_LocalLocation<BRepGraphInc::ShellRef>::value));
  printf("  BRepGraphInc::FaceRef       LocalLocation: %s\n",
         yn(has_LocalLocation<BRepGraphInc::FaceRef>::value));
  printf("  BRepGraphInc::WireRef       LocalLocation: %s\n",
         yn(has_LocalLocation<BRepGraphInc::WireRef>::value));
  printf("  BRepGraphInc::VertexRef     LocalLocation: %s\n",
         yn(has_LocalLocation<BRepGraphInc::VertexRef>::value));
  printf("  BRepGraphInc::SolidRef      LocalLocation: %s\n",
         yn(has_LocalLocation<BRepGraphInc::SolidRef>::value));
  printf("  BRepGraphInc::ChildRef      LocalLocation: %s\n",
         yn(has_LocalLocation<BRepGraphInc::ChildRef>::value));
  printf("  BRepGraphInc::OccurrenceRef LocalLocation: %s\n",
         yn(has_LocalLocation<BRepGraphInc::OccurrenceRef>::value));
  printf("  BRepGraphInc::CoEdgeRef: does not exist as a type; BRepGraph_RefId::Kind has no\n"
         "    CoEdge member, so there is no coedge reference to carry a location at all.\n");

  printf("\n  Reference kinds BRepGraph_RefId::IsValidKind accepts:\n   ");
  for (int i = -1; i < 10; ++i)
  {
    if (BRepGraph_RefId::IsValidKind((BRepGraph_RefId::Kind)i))
    {
      printf(" %d=%s", i, kindName((BRepGraph_RefId::Kind)i));
    }
  }
  printf("\n");

  // -------------------------------------------------------------------------
  section("B. CoEdge definition: is there a UV box to set?");
  // -------------------------------------------------------------------------
  printf("  BRepGraphInc::CoEdgeDef UVBox:   %s\n", yn(has_UVBox<BRepGraphInc::CoEdgeDef>::value));
  printf("  BRepGraphInc::CoEdgeDef UV1:     %s\n", yn(has_UV1<BRepGraphInc::CoEdgeDef>::value));
  printf("  BRepGraphInc::CoEdgeDef UVFirst: %s\n",
         yn(has_UVFirst<BRepGraphInc::CoEdgeDef>::value));
  printf("  BRepGraphInc::CoEdgeDef UVPoints:%s\n",
         yn(has_UVPoints<BRepGraphInc::CoEdgeDef>::value));

  // -------------------------------------------------------------------------
  section("C. Polygon-on-triangulation rep: is there a triangulation id to rebind?");
  // -------------------------------------------------------------------------
  printf("  BRepGraphInc::CoEdgePolygonOnTriRep TriangulationRepId: %s\n",
         yn(has_TriangulationRepId<BRepGraphInc::CoEdgePolygonOnTriRep>::value));
  printf("  BRepGraphInc::CoEdgePolygonOnTriRep TriangulationId:    %s\n",
         yn(has_TriangulationId<BRepGraphInc::CoEdgePolygonOnTriRep>::value));
  printf("  (For contrast, BRepGraphInc::FaceDef TriangulationRepId: %s. Faces own the\n"
         "   triangulation, and SetPersistentPolygonOnTri resolves it through\n"
         "   CoEdgeDef.FaceId -> FaceDef.TriangulationRepId.)\n",
         yn(has_TriangulationRepId<BRepGraphInc::FaceDef>::value));

  // -------------------------------------------------------------------------
  section("D. Runtime: a box graph's references, read back through Refs().Gen()");
  // -------------------------------------------------------------------------
  TopoDS_Shape aBox = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();

  BRepGraph aGraph;
  aGraph.Clear();
  BRepGraph::ShapesView::Options anOpts;
  anOpts.Parallel          = false;
  anOpts.CreateAutoProduct = false;
  if (!aGraph.Shapes().Add(aBox, anOpts).IsOk())
  {
    printf("  ShapesView::Add failed; aborting\n");
    return 1;
  }
  printf("  graph: solids=%u shells=%u faces=%u wires=%u edges=%u coedges=%u vertices=%u\n",
         aGraph.Topo().Solids().Nb(),
         aGraph.Topo().Shells().Nb(),
         aGraph.Topo().Faces().Nb(),
         aGraph.Topo().Wires().Nb(),
         aGraph.Topo().Edges().Nb(),
         aGraph.Topo().CoEdges().Nb(),
         aGraph.Topo().Vertices().Nb());

  const BRepGraph_RefId::Kind aKinds[] = {BRepGraph_RefId::Kind::Shell,
                                          BRepGraph_RefId::Kind::Face,
                                          BRepGraph_RefId::Kind::Wire,
                                          BRepGraph_RefId::Kind::Vertex,
                                          BRepGraph_RefId::Kind::Solid,
                                          BRepGraph_RefId::Kind::Child,
                                          BRepGraph_RefId::Kind::Occurrence};
  for (BRepGraph_RefId::Kind k : aKinds)
  {
    const uint32_t n = aGraph.Refs().Gen().Nb(k);
    printf("  %-11s refs: %u\n", kindName(k), n);
    if (n > 0)
    {
      char aLabel[128];
      snprintf(aLabel, sizeof(aLabel), "Gen().LocalLocation(%s, 0)", kindName(k));
      reportLocation(aLabel, aGraph.Refs().Gen().LocalLocation(BRepGraph_RefId(k, 0)));
    }
  }

  // -------------------------------------------------------------------------
  section("E. Occurrence reference: does the one real per-topology-shaped writer round-trip?");
  // -------------------------------------------------------------------------
  const BRepGraph_ProductId aParent = aGraph.Editor().Products().Add();
  gp_Trsf                   aChildTrsf; // identity
  const BRepGraph_ProductId aChild =
    aGraph.Editor().Products().Add(BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0),
                                   TopLoc_Location(aChildTrsf));
  printf("  parent product valid=%s  child product valid=%s\n",
         yn(aParent.IsValid()),
         yn(aChild.IsValid()));

  gp_Trsf aLinkTrsf;
  aLinkTrsf.SetValues(1, 0, 0, 5, 0, 1, 0, 6, 0, 0, 1, 7);
  BRepGraph_OccurrenceRefId anOccRef;
  const BRepGraph_OccurrenceId anOcc = aGraph.Editor().Products().Append(
    aParent, aChild, TopLoc_Location(aLinkTrsf), BRepGraph_OccurrenceId(), &anOccRef);
  printf("  Products().Append -> occurrence valid=%s  occurrenceRef valid=%s (index %u)\n",
         yn(anOcc.IsValid()),
         yn(anOccRef.IsValid()),
         anOccRef.Index);

  if (anOccRef.IsValid())
  {
    printf("  after Append with translation (5, 6, 7):\n");
    reportLocation("Refs().Occurrences().Entry().LocalLocation",
                   aGraph.Refs().Occurrences().Entry(anOccRef).LocalLocation);
    reportLocation("Refs().Gen().LocalLocation(Occurrence)",
                   aGraph.Refs().Gen().LocalLocation(
                     BRepGraph_RefId(BRepGraph_RefId::Kind::Occurrence, anOccRef.Index)));

    gp_Trsf aSetTrsf;
    aSetTrsf.SetValues(1, 0, 0, 11, 0, 1, 0, 12, 0, 0, 1, 13);
    aGraph.Editor().Occurrences().SetRefLocalLocation(anOccRef, TopLoc_Location(aSetTrsf));
    printf("  after Occurrences().SetRefLocalLocation with translation (11, 12, 13):\n");
    reportLocation("Refs().Occurrences().Entry().LocalLocation",
                   aGraph.Refs().Occurrences().Entry(anOccRef).LocalLocation);
    reportLocation("Refs().Gen().LocalLocation(Occurrence)",
                   aGraph.Refs().Gen().LocalLocation(
                     BRepGraph_RefId(BRepGraph_RefId::Kind::Occurrence, anOccRef.Index)));
    reportLocation("Topo().Occurrences().OccurrenceLocation(def)",
                   aGraph.Topo().Occurrences().OccurrenceLocation(anOcc));
  }

  // -------------------------------------------------------------------------
  section("F. Child reference: the other real writer, for comparison");
  // -------------------------------------------------------------------------
  NCollection_Array1<BRepGraph_NodeId> aChildren(1, 1);
  aChildren.SetValue(1, BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, 0));
  const BRepGraph_CompoundId aCompound = aGraph.Editor().Compounds().Add(aChildren);
  printf("  compound valid=%s\n", yn(aCompound.IsValid()));
  const BRepGraph_ChildRefId aChildRef =
    aGraph.Editor().Compounds().Append(aCompound,
                                       BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, 0),
                                       TopAbs_FORWARD);
  printf("  childRef valid=%s (index %u)\n", yn(aChildRef.IsValid()), aChildRef.Index);
  if (aChildRef.IsValid())
  {
    gp_Trsf aChildSet;
    aChildSet.SetValues(1, 0, 0, 1, 0, 1, 0, 2, 0, 0, 1, 3);
    aGraph.Editor().Gen().SetChildRefLocalLocation(aChildRef, TopLoc_Location(aChildSet));
    printf("  after Gen().SetChildRefLocalLocation with translation (1, 2, 3):\n");
    reportLocation("Refs().Children().Entry().LocalLocation",
                   aGraph.Refs().Children().Entry(aChildRef).LocalLocation);
    reportLocation("Refs().Gen().LocalLocation(Child)",
                   aGraph.Refs().Gen().LocalLocation(
                     BRepGraph_RefId(BRepGraph_RefId::Kind::Child, aChildRef.Index)));
  }

  // -------------------------------------------------------------------------
  section("G. CoEdge UV endpoints: derived from the PCurve, or stored?");
  // -------------------------------------------------------------------------
  if (aGraph.Topo().CoEdges().Nb() > 0)
  {
    const BRepGraph_CoEdgeId aCoEdge = BRepGraph_CoEdgeId(0u);
    std::pair<gp_Pnt2d, gp_Pnt2d> aUV = BRepGraph_Tool::CoEdge::UVPoints(aGraph, aCoEdge);
    std::pair<double, double>     aRange = BRepGraph_Tool::CoEdge::Range(aGraph, aCoEdge);
    printf("  coedge 0 before: UV1=(%.3f, %.3f) UV2=(%.3f, %.3f) range=(%.3f, %.3f)\n",
           aUV.first.X(),
           aUV.first.Y(),
           aUV.second.X(),
           aUV.second.Y(),
           aRange.first,
           aRange.second);

    // Rebind the PCurve; if UV endpoints are derived, they must follow it.
    occ::handle<Geom2d_Line> aLine = new Geom2d_Line(gp_Pnt2d(2.0, 3.0), gp_Dir2d(1.0, 0.0));
    aGraph.Editor().CoEdges().SetPCurve(aCoEdge, aLine, 0.0, 4.0);
    aUV    = BRepGraph_Tool::CoEdge::UVPoints(aGraph, aCoEdge);
    aRange = BRepGraph_Tool::CoEdge::Range(aGraph, aCoEdge);
    printf("  coedge 0 after SetPCurve(line through (2,3) along +u, 0..4):\n");
    printf("                   UV1=(%.3f, %.3f) UV2=(%.3f, %.3f) range=(%.3f, %.3f)\n",
           aUV.first.X(),
           aUV.first.Y(),
           aUV.second.X(),
           aUV.second.Y(),
           aRange.first,
           aRange.second);
    printf("  -> the UV endpoints track the PCurve, so a per-coedge UV box would have nothing\n"
           "     to store and no reader that would consult it.\n");
  }

  // -------------------------------------------------------------------------
  section("H. Polygon-on-triangulation: how is the triangulation bound?");
  // -------------------------------------------------------------------------
  if (aGraph.Topo().CoEdges().Nb() > 0)
  {
    const BRepGraph_CoEdgeId aCoEdge = BRepGraph_CoEdgeId(0u);
    printf("  before: Mesh().Persistent().CoEdges().HasPolygonOnTriangulation = %s\n",
           yn(aGraph.Mesh().Persistent().CoEdges().HasPolygonOnTriangulation(aCoEdge)));

    NCollection_Array1<int> aNodes(1, 2);
    aNodes.SetValue(1, 1);
    aNodes.SetValue(2, 2);
    occ::handle<Poly_PolygonOnTriangulation> aPoly = new Poly_PolygonOnTriangulation(aNodes);
    aGraph.Editor().CoEdges().SetPersistentPolygonOnTri(aCoEdge, aPoly);
    const bool aHas = aGraph.Mesh().Persistent().CoEdges().HasPolygonOnTriangulation(aCoEdge);
    printf("  after SetPersistentPolygonOnTri(handle): Has... = %s", yn(aHas));
    if (aHas)
    {
      const occ::handle<Poly_PolygonOnTriangulation>& aBack =
        aGraph.Mesh().Persistent().CoEdges().PolygonOnTriangulation(aCoEdge);
      printf("  same handle back = %s", yn(aBack == aPoly));
    }
    printf("\n");
    printf("  -> binding is by handle on the coedge. The rep record (CoEdgePolygonOnTriRep) is\n"
           "     {ParentCoEdgeId, Polygon}; there is no triangulation id on it to rebind.\n");
  }

  // -------------------------------------------------------------------------
  section("I. Which coedge PCurve transitions are observable, for the replacement test");
  // -------------------------------------------------------------------------
  // A test asserting HasPCurve after a bind would pass against a no-op bridge, because a freshly
  // ingested box already reports true. Clearing first is what makes both directions real.
  if (aGraph.Topo().CoEdges().Nb() > 0)
  {
    const BRepGraph_CoEdgeId aCoEdge = BRepGraph_CoEdgeId(0u);
    printf("  HasPCurve(coedge 0) on a freshly ingested box: %s\n",
           yn(BRepGraph_Tool::CoEdge::HasPCurve(aGraph, aCoEdge)));
    aGraph.Editor().CoEdges().SetPCurve(aCoEdge, occ::handle<Geom2d_Curve>());
    printf("  HasPCurve after SetPCurve(null):               %s\n",
           yn(BRepGraph_Tool::CoEdge::HasPCurve(aGraph, aCoEdge)));
    occ::handle<Geom2d_Line> aLine2 = new Geom2d_Line(gp_Pnt2d(2.0, 3.0), gp_Dir2d(1.0, 0.0));
    aGraph.Editor().CoEdges().SetPCurve(aCoEdge, aLine2);
    printf("  HasPCurve after SetPCurve(line):               %s\n",
           yn(BRepGraph_Tool::CoEdge::HasPCurve(aGraph, aCoEdge)));

    const uint32_t           aBefore = aGraph.Topo().CoEdges().Nb();
    const BRepGraph_CoEdgeId anAdded = aGraph.Editor().CoEdges().Add(BRepGraph_EdgeId(0u),
                                                                     BRepGraph_FaceId(0u),
                                                                     aLine2,
                                                                     0.0,
                                                                     4.0,
                                                                     TopAbs_FORWARD);
    printf("  CoEdges().Add(edge 0, face 0, line, 0..4): valid=%s index=%u, coedges %u -> %u\n",
           yn(anAdded.IsValid()),
           anAdded.Index,
           aBefore,
           aGraph.Topo().CoEdges().Nb());
    if (anAdded.IsValid())
    {
      std::pair<double, double> anAddedRange = BRepGraph_Tool::CoEdge::Range(aGraph, anAdded);
      printf("  Range(added) = (%.3f, %.3f), distinct from the ingested coedges' (0, 10)\n",
             anAddedRange.first,
             anAddedRange.second);
    }
  }

  printf("\nDone.\n");
  return 0;
}
