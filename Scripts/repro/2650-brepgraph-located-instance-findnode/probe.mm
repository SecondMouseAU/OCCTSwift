// #2650: does BRepGraph::ShapesView::FindNode resolve a sub-shape of a LOCATED
// instance inside an ingested compound?
//
// Two header contracts settle what the answer is supposed to be.
//
//   BRepGraph_ShapesView.hxx:216  FindNode "uses OCCT IsSame() semantics
//                                 (TShape + Location, orientation ignored)".
//   BRepGraph_ShapesView.hxx:258  bindSourceShapeAliases exists to "keep
//                                 ShapesView::FindNode() usable with the original
//                                 TopoDS subshapes when root placement is stored
//                                 on a Product occurrence or Compound child ref".
//
// So a located sub-shape IS a different TopoDS_Shape from the definition, and the
// kernel nonetheless intends FindNode to resolve it, through an explicit alias
// binding. Two things follow that this probe has to measure rather than assume:
//
//   1. whether it resolves at all against the pinned kernel, and
//   2. whether it resolves under the options OCCTSwift's bridge actually passes.
//      OCCTBRepGraphCreate sets CreateAutoProduct = false, and in
//      BRepGraph_ShapesView.cxx:918-922 bindSourceShapeAliases runs only when
//      shouldStoreRootLocationInRef() is true, which for a parentless Add IS
//      theOptions.CreateAutoProduct. That is the one difference between the
//      bridge's call and the default one, so both are measured side by side.

#include <BRepGraph.hxx>
#include <BRepGraph_NodeId.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS_Compound.hxx>
#include <gp_Trsf.hxx>

#include <cstdio>
#include <string>

static const char* kindName(BRepGraph_NodeId::Kind theKind)
{
  switch (theKind)
  {
    case BRepGraph_NodeId::Kind::Vertex:
      return "Vertex";
    case BRepGraph_NodeId::Kind::Edge:
      return "Edge";
    case BRepGraph_NodeId::Kind::CoEdge:
      return "CoEdge";
    case BRepGraph_NodeId::Kind::Wire:
      return "Wire";
    case BRepGraph_NodeId::Kind::Face:
      return "Face";
    case BRepGraph_NodeId::Kind::Shell:
      return "Shell";
    case BRepGraph_NodeId::Kind::Solid:
      return "Solid";
    case BRepGraph_NodeId::Kind::CompSolid:
      return "CompSolid";
    case BRepGraph_NodeId::Kind::Compound:
      return "Compound";
    default:
      return "other";
  }
}

static std::string nodeText(const BRepGraph_NodeId& theNode)
{
  if (!theNode.IsValid())
  {
    return "INVALID";
  }
  return std::string(kindName(theNode.NodeKind)) + "[" + std::to_string(theNode.Index) + "]";
}

// Count how many sub-shapes of theQuery, of type theType, resolve through FindNode.
static void report(const char*         theLabel,
                   const BRepGraph&    theGraph,
                   const TopoDS_Shape& theQuery,
                   TopAbs_ShapeEnum    theType)
{
  TopTools_IndexedMapOfShape aMap;
  TopExp::MapShapes(theQuery, theType, aMap);
  int aFound = 0;
  for (int i = 1; i <= aMap.Extent(); ++i)
  {
    if (theGraph.Shapes().FindNode(aMap(i)).IsValid())
    {
      ++aFound;
    }
  }
  printf("    %-46s %3d of %3d resolve\n", theLabel, aFound, aMap.Extent());
}

// Build the graph exactly the way OCCTBRepGraphCreate does, except for the one
// option under test.
static BRepGraph::ShapesView::Options bridgeOptions(bool theCreateAutoProduct)
{
  BRepGraph::ShapesView::Options anOpts;
  anOpts.Parallel          = false;
  anOpts.CreateAutoProduct = theCreateAutoProduct;
  return anOpts;
}

struct Fixtures
{
  TopoDS_Shape    Box;   // unplaced definition
  TopoDS_Shape    Moved; // same TShape, non-identity Location
  TopoDS_Compound Pair;  // compound[box, moved]           -- issue case A
  TopoDS_Compound One;   // compound[moved]                -- issue case B
  TopoDS_Compound Outer; // compound[box, moved(compound[moved])] -- nested
};

static Fixtures makeFixtures()
{
  Fixtures aF;
  // A corner box is fine: the property under test is the Location, not the geometry.
  aF.Box = BRepPrimAPI_MakeBox(10.0, 8.0, 6.0).Shape();

  gp_Trsf aTr;
  aTr.SetTranslation(gp_Vec(50.0, 0.0, 0.0));
  aF.Moved = aF.Box.Moved(TopLoc_Location(aTr));

  BRep_Builder aB;
  aB.MakeCompound(aF.Pair);
  aB.Add(aF.Pair, aF.Box);
  aB.Add(aF.Pair, aF.Moved);

  aB.MakeCompound(aF.One);
  aB.Add(aF.One, aF.Moved);

  TopoDS_Compound anInner;
  aB.MakeCompound(anInner);
  aB.Add(anInner, aF.Moved);
  gp_Trsf aTr2;
  aTr2.SetTranslation(gp_Vec(0.0, 30.0, 0.0));
  TopoDS_Shape anInnerMoved = anInner.Moved(TopLoc_Location(aTr2));
  aB.MakeCompound(aF.Outer);
  aB.Add(aF.Outer, aF.Box);
  aB.Add(aF.Outer, anInnerMoved);
  return aF;
}

static void runAll(bool theCreateAutoProduct)
{
  const Fixtures aF = makeFixtures();
  printf("================ CreateAutoProduct = %s %s================\n",
         theCreateAutoProduct ? "true " : "false",
         theCreateAutoProduct ? "(OCCT default)      " : "(what the bridge passes) ");

  // ---- Case A: two instances of one part in a compound -----------------------
  {
    BRepGraph aGraph;
    aGraph.Clear();
    auto aRes = aGraph.Shapes().Add(aF.Pair, bridgeOptions(theCreateAutoProduct));
    printf("  A: compound[box, moved]  ok=%s solids=%d faces=%d products=%d occurrences=%d\n",
           aRes.IsOk() ? "true" : "false",
           aGraph.Topo().Solids().Nb(),
           aGraph.Topo().Faces().Nb(),
           aGraph.Topo().Products().Nb(),
           aGraph.Topo().Occurrences().Nb());
    report("solids of the compound", aGraph, aF.Pair, TopAbs_SOLID);
    report("faces of the compound", aGraph, aF.Pair, TopAbs_FACE);
    report("edges of the compound", aGraph, aF.Pair, TopAbs_EDGE);
    report("vertices of the compound", aGraph, aF.Pair, TopAbs_VERTEX);
    report("faces of the UNPLACED box alone", aGraph, aF.Box, TopAbs_FACE);
    report("faces of the PLACED moved alone", aGraph, aF.Moved, TopAbs_FACE);
    printf("    FindNode(moved)    -> %s\n", nodeText(aGraph.Shapes().FindNode(aF.Moved)).c_str());
    printf("    FindNode(box)      -> %s\n", nodeText(aGraph.Shapes().FindNode(aF.Box)).c_str());
    printf("    FindNode(compound) -> %s\n", nodeText(aGraph.Shapes().FindNode(aF.Pair)).c_str());
  }

  // ---- Case B: a single placed instance inside a compound --------------------
  {
    BRepGraph aGraph;
    aGraph.Clear();
    auto aRes = aGraph.Shapes().Add(aF.One, bridgeOptions(theCreateAutoProduct));
    printf("  B: compound[moved]       ok=%s solids=%d faces=%d\n",
           aRes.IsOk() ? "true" : "false",
           aGraph.Topo().Solids().Nb(),
           aGraph.Topo().Faces().Nb());
    report("faces of the compound", aGraph, aF.One, TopAbs_FACE);
    report("faces of the PLACED moved alone", aGraph, aF.Moved, TopAbs_FACE);
    report("faces of the UNPLACED box alone", aGraph, aF.Box, TopAbs_FACE);
  }

  // ---- Case C: the placed solid as the graph root ----------------------------
  {
    BRepGraph aGraph;
    aGraph.Clear();
    auto aRes = aGraph.Shapes().Add(aF.Moved, bridgeOptions(theCreateAutoProduct));
    printf("  C: root = moved          ok=%s solids=%d faces=%d\n",
           aRes.IsOk() ? "true" : "false",
           aGraph.Topo().Solids().Nb(),
           aGraph.Topo().Faces().Nb());
    report("faces of the PLACED moved", aGraph, aF.Moved, TopAbs_FACE);
    report("faces of the UNPLACED box", aGraph, aF.Box, TopAbs_FACE);
  }

  // ---- Case D: nested compound, the located instance one level deeper --------
  {
    BRepGraph aGraph;
    aGraph.Clear();
    auto aRes = aGraph.Shapes().Add(aF.Outer, bridgeOptions(theCreateAutoProduct));
    printf("  D: compound[box, moved(compound[moved])] ok=%s solids=%d faces=%d\n",
           aRes.IsOk() ? "true" : "false",
           aGraph.Topo().Solids().Nb(),
           aGraph.Topo().Faces().Nb());
    report("faces of the outer compound", aGraph, aF.Outer, TopAbs_FACE);
    report("solids of the outer compound", aGraph, aF.Outer, TopAbs_SOLID);
  }

  // ---- Case E: do the two occurrences collapse onto one node? ----------------
  {
    BRepGraph aGraph;
    aGraph.Clear();
    auto aRes = aGraph.Shapes().Add(aF.Pair, bridgeOptions(theCreateAutoProduct));
    (void)aRes;
    TopTools_IndexedMapOfShape aMap;
    TopExp::MapShapes(aF.Pair, TopAbs_SOLID, aMap);
    printf("  E: node identity for the %d solid occurrences of one definition\n", aMap.Extent());
    for (int i = 1; i <= aMap.Extent(); ++i)
    {
      printf("     solid %d  loc-identity=%s  node=%s\n",
             i,
             aMap(i).Location().IsIdentity() ? "yes" : "no ",
             nodeText(aGraph.Shapes().FindNode(aMap(i))).c_str());
    }
    printf("     Solids().Nb()=%d Occurrences=%d Products=%d\n",
           aGraph.Topo().Solids().Nb(),
           aGraph.Topo().Occurrences().Nb(),
           aGraph.Topo().Products().Nb());
  }
  printf("\n");
}

// The candidate bridge-side fix: on a miss, retry with the shape's own Location
// stripped. That is the same key transformation OCCT's own alias binder applies
// (BRepGraph_ShapesView.cxx:526-527, `aLookup.Location(theDefinitionLocation)`,
// where a Compound child's definition location is TopLoc_Location(), set at
// BRepGraph_ShapesView.cxx:570-579).
static BRepGraph_NodeId findNodeWithRetry(const BRepGraph& theGraph, const TopoDS_Shape& theShape)
{
  const BRepGraph_NodeId aDirect = theGraph.Shapes().FindNode(theShape);
  if (aDirect.IsValid() || theShape.Location().IsIdentity())
  {
    return aDirect;
  }
  TopoDS_Shape aStripped = theShape;
  aStripped.Location(TopLoc_Location());
  return theGraph.Shapes().FindNode(aStripped);
}

// Second construction: does the retry against a CreateAutoProduct = false graph
// give, element for element, the same node OCCT's own aliasing gives against a
// CreateAutoProduct = true graph? Agreement on every element is the claim; a
// count alone would not be.
static void compareRetryAgainstOcctAliasing(const char*         theLabel,
                                            const TopoDS_Shape& theIngest,
                                            const TopoDS_Shape& theQuery,
                                            TopAbs_ShapeEnum    theType)
{
  BRepGraph aNoProduct;
  aNoProduct.Clear();
  auto aR1 = aNoProduct.Shapes().Add(theIngest, bridgeOptions(false));
  (void)aR1;
  BRepGraph aWithProduct;
  aWithProduct.Clear();
  auto aR2 = aWithProduct.Shapes().Add(theIngest, bridgeOptions(true));
  (void)aR2;

  TopTools_IndexedMapOfShape aMap;
  TopExp::MapShapes(theQuery, theType, aMap);
  int aAgree = 0;
  int aRetryResolved = 0;
  int aOcctResolved  = 0;
  for (int i = 1; i <= aMap.Extent(); ++i)
  {
    const BRepGraph_NodeId aRetry = findNodeWithRetry(aNoProduct, aMap(i));
    const BRepGraph_NodeId aOcct  = aWithProduct.Shapes().FindNode(aMap(i));
    aRetryResolved += aRetry.IsValid() ? 1 : 0;
    aOcctResolved += aOcct.IsValid() ? 1 : 0;
    const bool isSame = aRetry.IsValid() == aOcct.IsValid()
                        && (!aRetry.IsValid()
                            || (aRetry.NodeKind == aOcct.NodeKind && aRetry.Index == aOcct.Index));
    aAgree += isSame ? 1 : 0;
    if (!isSame)
    {
      printf("    MISMATCH at %d: retry=%s occt=%s\n",
             i,
             nodeText(aRetry).c_str(),
             nodeText(aOcct).c_str());
    }
  }
  printf("  %-44s retry %3d/%3d, OCCT aliasing %3d/%3d, agree %3d/%3d\n",
         theLabel,
         aRetryResolved,
         aMap.Extent(),
         aOcctResolved,
         aMap.Extent(),
         aAgree,
         aMap.Extent());
}

int main()
{
  const Fixtures aF = makeFixtures();
  printf("box.IsSame(moved)                = %s\n", aF.Box.IsSame(aF.Moved) ? "true" : "false");
  printf("box.TShape() == moved.TShape()   = %s\n",
         aF.Box.TShape() == aF.Moved.TShape() ? "true" : "false");
  printf("moved.Location().IsIdentity()    = %s\n\n",
         aF.Moved.Location().IsIdentity() ? "true" : "false");

  runAll(false); // what OCCTBRepGraphCreate passes today
  runAll(true);  // OCCT's own default

  printf("================ location-stripped retry vs OCCT's own aliasing ================\n");
  compareRetryAgainstOcctAliasing("A solids", aF.Pair, aF.Pair, TopAbs_SOLID);
  compareRetryAgainstOcctAliasing("A faces", aF.Pair, aF.Pair, TopAbs_FACE);
  compareRetryAgainstOcctAliasing("A edges", aF.Pair, aF.Pair, TopAbs_EDGE);
  compareRetryAgainstOcctAliasing("A vertices", aF.Pair, aF.Pair, TopAbs_VERTEX);
  compareRetryAgainstOcctAliasing("B faces", aF.One, aF.One, TopAbs_FACE);
  compareRetryAgainstOcctAliasing("B edges", aF.One, aF.One, TopAbs_EDGE);
  compareRetryAgainstOcctAliasing("D faces (nested)", aF.Outer, aF.Outer, TopAbs_FACE);
  compareRetryAgainstOcctAliasing("D solids (nested)", aF.Outer, aF.Outer, TopAbs_SOLID);
  compareRetryAgainstOcctAliasing("D edges (nested)", aF.Outer, aF.Outer, TopAbs_EDGE);
  // C is the one case the two graphs are NOT expected to agree on: with
  // CreateAutoProduct = false the located root keeps its own Location in the
  // definition, so the definition is the PLACED solid and the unplaced box has
  // no node; with true the root location moves onto the Product occurrence and
  // both keys alias. Printed rather than hidden.
  compareRetryAgainstOcctAliasing("C faces (located root)", aF.Moved, aF.Moved, TopAbs_FACE);
  compareRetryAgainstOcctAliasing("C faces of the unplaced box", aF.Moved, aF.Box, TopAbs_FACE);

  // F: the one place the retry is WIDER than OCCT's aliasing. OCCT binds an alias
  // only for a source sub-shape it actually walked, so a located shape the graph
  // never ingested stays unresolved there. The stripped retry answers with the
  // definition node instead. Measured rather than argued.
  printf("\n================ F: a located shape the graph never ingested ================\n");
  {
    BRep_Builder    aB;
    TopoDS_Compound aBoxOnly;
    aB.MakeCompound(aBoxOnly);
    aB.Add(aBoxOnly, aF.Box);

    BRepGraph aNoProduct;
    aNoProduct.Clear();
    auto aR1 = aNoProduct.Shapes().Add(aBoxOnly, bridgeOptions(false));
    (void)aR1;
    BRepGraph aWithProduct;
    aWithProduct.Clear();
    auto aR2 = aWithProduct.Shapes().Add(aBoxOnly, bridgeOptions(true));
    (void)aR2;

    TopTools_IndexedMapOfShape aMap;
    TopExp::MapShapes(aF.Moved, TopAbs_FACE, aMap);
    int aRetry = 0;
    int aOcct  = 0;
    for (int i = 1; i <= aMap.Extent(); ++i)
    {
      aRetry += findNodeWithRetry(aNoProduct, aMap(i)).IsValid() ? 1 : 0;
      aOcct += aWithProduct.Shapes().FindNode(aMap(i)).IsValid() ? 1 : 0;
    }
    printf("  graph ingested compound[box]; query faces of moved (never ingested)\n");
    printf("  stripped retry resolves %d of %d; OCCT aliasing resolves %d of %d\n",
           aRetry,
           aMap.Extent(),
           aOcct,
           aMap.Extent());
  }

  // What the definition node reconstructs to, which is the reason not to flip
  // CreateAutoProduct: with true the root's own location is stripped into the
  // Product occurrence, so Shape(root) comes back unplaced.
  printf("\n================ Shape(root) for a LOCATED root ================\n");
  for (int aFlag = 0; aFlag <= 1; ++aFlag)
  {
    BRepGraph aGraph;
    aGraph.Clear();
    auto aRes = aGraph.Shapes().Add(aF.Moved, bridgeOptions(aFlag == 1));
    const TopoDS_Shape aRoot = aGraph.Shapes().Shape(aRes.TopologyRoot);
    printf("  CreateAutoProduct=%-5s root=%s  Shape(root).Location().IsIdentity()=%s\n",
           aFlag == 1 ? "true" : "false",
           nodeText(aRes.TopologyRoot).c_str(),
           aRoot.IsNull() ? "null" : (aRoot.Location().IsIdentity() ? "true" : "false"));
  }
  return 0;
}
