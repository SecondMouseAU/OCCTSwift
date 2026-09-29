// #2835: how does OCCT itself tell two occurrences of one part apart, and what does that cost?
//
// #2650 established the lookup half: `ShapesView::FindNode` answers the DEFINITION node, so the
// two instances of one part in a compound both resolve to `Solid[0]`. That is the kernel's own
// aliasing and not a defect, and `BRepGraph/README.md:398` says why: "Keep occurrence-context
// metadata resolution out of the core storage model; resolve it through explorer usage paths or
// layer-side resolvers."
//
// So the occurrence is a PATH, not an id, and the class that produces it is
// `BRepGraph_ChildExplorer`:
//
//   BRepGraph_ChildExplorer.hxx:47   "visits each occurrence. If Edge[5] is reachable through
//                                    Face[0] and Face[1], it is visited twice with different
//                                    accumulated transforms."
//   BRepGraph_ChildExplorer.hxx:329  CurrentUsagePath() "Returns the explicit concrete traversal
//                                    path from the explorer root to Current()."
//   BRepGraph_UsagePath.hxx:33       "Paths are used to disambiguate multiple occurrences of the
//                                    same definition reachable through different references or
//                                    sibling positions."
//
// Four things this probe has to MEASURE rather than assume, because each one decides part of the
// bridge signature:
//
//   1. With `Options::CreateAutoProduct = false`, which is what `OCCTBRepGraphCreate` passes, does
//      the graph have any root Product at all? That decides whether a Swift-side default root can
//      be `rootProductIndices` or has to be the topology root.
//   2. Does a Recursive ChildExplorer from the topology root emit the same Face node once per
//      occurrence, with distinct usage paths and distinct composed locations?
//   3. What do the usage-path steps actually contain: which steps carry a RefId, and are two
//      sibling occurrences distinguished by the Ref, by the StepIndex, or by both? The bridge has
//      to emit whichever fields carry the distinction.
//   4. What does one per-node occurrence enumeration cost on an assembly big enough to matter,
//      per okf/policies/measure-dont-assume.md and the issue's own cost question.

#include <BRepGraph.hxx>
#include <BRepGraph_ChildExplorer.hxx>
#include <BRepGraph_NodeId.hxx>
#include <BRepGraph_RefId.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_UsagePath.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS_Compound.hxx>
#include <gp_Trsf.hxx>

#include <Standard_Failure.hxx>

#include <chrono>
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
    case BRepGraph_NodeId::Kind::Product:
      return "Product";
    case BRepGraph_NodeId::Kind::Occurrence:
      return "Occurrence";
    default:
      return "other";
  }
}

static const char* refKindName(BRepGraph_RefId::Kind theKind)
{
  switch (theKind)
  {
    case BRepGraph_RefId::Kind::Shell:
      return "ShellRef";
    case BRepGraph_RefId::Kind::Face:
      return "FaceRef";
    case BRepGraph_RefId::Kind::Wire:
      return "WireRef";
    case BRepGraph_RefId::Kind::Vertex:
      return "VertexRef";
    case BRepGraph_RefId::Kind::Solid:
      return "SolidRef";
    case BRepGraph_RefId::Kind::Child:
      return "ChildRef";
    case BRepGraph_RefId::Kind::Occurrence:
      return "OccurrenceRef";
    default:
      return "otherRef";
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

static std::string refText(const BRepGraph_RefId& theRef)
{
  if (!theRef.IsValid())
  {
    return "-";
  }
  return std::string(refKindName(theRef.RefKind)) + "[" + std::to_string(theRef.Index) + "]";
}

static std::string pathText(const BRepGraph_UsagePath& thePath)
{
  std::string aText;
  for (size_t i = 0; i < thePath.Size(); ++i)
  {
    const BRepGraph_UsagePath::Step& aStep = thePath.Value(i);
    if (i > 0)
    {
      aText += " / ";
    }
    aText += nodeText(aStep.Node) + "(" + refText(aStep.Ref) + ",step="
             + std::to_string(aStep.StepIndex) + ")";
  }
  return aText;
}

// Build the graph exactly the way OCCTBRepGraphCreate does: Clear() first, then
// ShapesView::Add with CreateAutoProduct = false.
static void buildLikeBridge(BRepGraph& theGraph, const TopoDS_Shape& theShape)
{
  theGraph.Clear();
  BRepGraph::ShapesView::Options anOpts;
  anOpts.Parallel          = false;
  anOpts.CreateAutoProduct = false;
  theGraph.Shapes().Add(theShape, anOpts);
}

int main()
{
  // ---------------------------------------------------------------------------
  // Fixture: ONE box solid placed twice inside one compound. This is the shape the
  // issue is about, "two instances of one part", and #2650 measured that both
  // occurrences resolve to Solid[0] with Solids().Nb() == 1.
  // ---------------------------------------------------------------------------
  TopoDS_Shape aBox = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();

  gp_Trsf aT1;
  aT1.SetTranslation(gp_Vec(0.0, 0.0, 0.0));
  gp_Trsf aT2;
  aT2.SetTranslation(gp_Vec(100.0, 0.0, 0.0));

  TopoDS_Shape anInstA = aBox.Located(TopLoc_Location(aT1));
  TopoDS_Shape anInstB = aBox.Located(TopLoc_Location(aT2));

  BRep_Builder    aBuilder;
  TopoDS_Compound aCompound;
  aBuilder.MakeCompound(aCompound);
  aBuilder.Add(aCompound, anInstA);
  aBuilder.Add(aCompound, anInstB);

  BRepGraph aGraph;
  buildLikeBridge(aGraph, aCompound);

  printf("=== A. the graph the bridge builds from a two-instance compound ===\n");
  printf("Compounds=%d Solids=%d Shells=%d Faces=%d Edges=%d Vertices=%d\n",
         aGraph.Topo().Compounds().Nb(),
         aGraph.Topo().Solids().Nb(),
         aGraph.Topo().Shells().Nb(),
         aGraph.Topo().Faces().Nb(),
         aGraph.Topo().Edges().Nb(),
         aGraph.Topo().Vertices().Nb());
  printf("Products=%d Occurrences=%d RootProductIds().Size()=%d\n",
         aGraph.Topo().Products().Nb(),
         aGraph.Topo().Occurrences().Nb(),
         (int)aGraph.RootProductIds().Size());
  printf("  => QUESTION 1: is there a root Product to start a traversal from?\n\n");

  // ---------------------------------------------------------------------------
  // B. the explorer, from the topology root, for Solid and Face target kinds.
  // ---------------------------------------------------------------------------
  const BRepGraph_NodeId aRoot(BRepGraph_NodeId::Kind::Compound, 0);

  printf("=== B. ChildExplorer from %s, Recursive, TargetKind=Solid ===\n",
         nodeText(aRoot).c_str());
  {
    int aCount = 0;
    for (BRepGraph_ChildExplorer anExp(aGraph, aRoot, BRepGraph_NodeId::Kind::Solid);
         anExp.More();
         anExp.Next())
    {
      const BRepGraphInc::NodeInstance anInst = anExp.Current();
      const gp_XYZ aTr = anInst.Location.Transformation().TranslationPart();
      printf("  [%d] %s loc=(%.1f,%.1f,%.1f) ori=%d\n",
             aCount,
             nodeText(anInst.DefId).c_str(),
             aTr.X(),
             aTr.Y(),
             aTr.Z(),
             (int)anInst.Orientation);
      printf("      parent=%s linkKind=%d ref=%s\n",
             nodeText(anExp.CurrentParent()).c_str(),
             (int)anExp.CurrentLinkKind(),
             refText(anExp.CurrentRef()).c_str());
      printf("      usagePath = %s\n", pathText(anExp.CurrentUsagePath()).c_str());
      ++aCount;
    }
    printf("  emitted %d solid occurrence(s) for Solids().Nb()=%d definition(s)\n\n",
           aCount,
           aGraph.Topo().Solids().Nb());
  }

  printf("=== C. same explorer, TargetKind=Face, grouped by definition node ===\n");
  {
    int aCount                         = 0;
    int aPerDefinition[64]             = {0};
    for (BRepGraph_ChildExplorer anExp(aGraph, aRoot, BRepGraph_NodeId::Kind::Face);
         anExp.More();
         anExp.Next())
    {
      const BRepGraphInc::NodeInstance anInst = anExp.Current();
      if (anInst.DefId.Index < 64)
      {
        ++aPerDefinition[anInst.DefId.Index];
      }
      if (anInst.DefId.Index == 0)
      {
        const gp_XYZ aTr = anInst.Location.Transformation().TranslationPart();
        printf("  Face[0] occurrence: loc=(%.1f,%.1f,%.1f) ori=%d\n",
               aTr.X(),
               aTr.Y(),
               aTr.Z(),
               (int)anInst.Orientation);
        printf("      usagePath = %s\n", pathText(anExp.CurrentUsagePath()).c_str());
      }
      ++aCount;
    }
    printf("  emitted %d face occurrence(s) for Faces().Nb()=%d definition(s)\n",
           aCount,
           aGraph.Topo().Faces().Nb());
    printf("  Face[0] emitted %d time(s)\n", aPerDefinition[0]);
    printf("  => QUESTION 2/3: distinct paths? distinct locations? which field differs?\n\n");
  }

  // ---------------------------------------------------------------------------
  // D. UsagePath equality: does the kernel's own == separate the two occurrences?
  // ---------------------------------------------------------------------------
  printf("=== D. UsagePath equality between the two Face[0] occurrences ===\n");
  {
    BRepGraph_UsagePath aFirst;
    BRepGraph_UsagePath aSecond;
    int                 aSeen = 0;
    for (BRepGraph_ChildExplorer anExp(aGraph, aRoot, BRepGraph_NodeId::Kind::Face);
         anExp.More();
         anExp.Next())
    {
      if (anExp.Current().DefId.Index != 0)
      {
        continue;
      }
      if (aSeen == 0)
      {
        aFirst = anExp.CurrentUsagePath();
      }
      else if (aSeen == 1)
      {
        aSecond = anExp.CurrentUsagePath();
      }
      ++aSeen;
    }
    if (aSeen >= 2)
    {
      printf("  first  = %s\n", pathText(aFirst).c_str());
      printf("  second = %s\n", pathText(aSecond).c_str());
      printf("  IsEqual = %s   HashCode equal = %s\n",
             aFirst.IsEqual(aSecond) ? "true" : "false",
             aFirst.HashCode() == aSecond.HashCode() ? "true" : "false");
    }
    else
    {
      printf("  only %d Face[0] occurrence(s) seen, nothing to compare\n", aSeen);
    }
    printf("\n");
  }

  // ---------------------------------------------------------------------------
  // E. a nested assembly: compound of compounds, same part four times.
  // ---------------------------------------------------------------------------
  printf("=== E. nested compound, same box four times ===\n");
  {
    TopoDS_Compound anInner1;
    TopoDS_Compound anInner2;
    TopoDS_Compound anOuter;
    aBuilder.MakeCompound(anInner1);
    aBuilder.MakeCompound(anInner2);
    aBuilder.MakeCompound(anOuter);
    gp_Trsf aT3;
    aT3.SetTranslation(gp_Vec(0.0, 50.0, 0.0));
    gp_Trsf aT4;
    aT4.SetTranslation(gp_Vec(100.0, 50.0, 0.0));
    aBuilder.Add(anInner1, aBox.Located(TopLoc_Location(aT1)));
    aBuilder.Add(anInner1, aBox.Located(TopLoc_Location(aT2)));
    aBuilder.Add(anInner2, aBox.Located(TopLoc_Location(aT3)));
    aBuilder.Add(anInner2, aBox.Located(TopLoc_Location(aT4)));
    aBuilder.Add(anOuter, anInner1);
    aBuilder.Add(anOuter, anInner2);

    BRepGraph aNested;
    buildLikeBridge(aNested, anOuter);
    printf("  Compounds=%d Solids=%d Faces=%d\n",
           aNested.Topo().Compounds().Nb(),
           aNested.Topo().Solids().Nb(),
           aNested.Topo().Faces().Nb());

    const BRepGraph_NodeId aNestedRoot = aNested.Shapes().FindNode(anOuter);
    printf("  FindNode(outer) = %s\n", nodeText(aNestedRoot).c_str());
    int aSolidOcc = 0;
    for (BRepGraph_ChildExplorer anExp(aNested, aNestedRoot, BRepGraph_NodeId::Kind::Solid);
         anExp.More();
         anExp.Next())
    {
      const BRepGraphInc::NodeInstance anInst = anExp.Current();
      const gp_XYZ aTr = anInst.Location.Transformation().TranslationPart();
      printf("  [%d] %s loc=(%.1f,%.1f,%.1f)  path=%s\n",
             aSolidOcc,
             nodeText(anInst.DefId).c_str(),
             aTr.X(),
             aTr.Y(),
             aTr.Z(),
             pathText(anExp.CurrentUsagePath()).c_str());
      ++aSolidOcc;
    }
    printf("  emitted %d solid occurrence(s)\n\n", aSolidOcc);
  }

  // ---------------------------------------------------------------------------
  // F. cost. The issue asks for it: a per-pick occurrence resolution is a traversal,
  // not a map lookup, so measure the traversal on an assembly big enough to matter.
  // ---------------------------------------------------------------------------
  printf("=== F. cost of one occurrence enumeration ===\n");
  {
    const int       aN = 200;
    TopoDS_Compound aBig;
    aBuilder.MakeCompound(aBig);
    for (int i = 0; i < aN; ++i)
    {
      gp_Trsf aT;
      aT.SetTranslation(gp_Vec(20.0 * i, 0.0, 0.0));
      aBuilder.Add(aBig, aBox.Located(TopLoc_Location(aT)));
    }
    BRepGraph aBigGraph;
    buildLikeBridge(aBigGraph, aBig);
    const BRepGraph_NodeId aBigRoot = aBigGraph.Shapes().FindNode(aBig);
    printf("  %d instances of one box: Solids=%d Faces=%d Vertices=%d\n",
           aN,
           aBigGraph.Topo().Solids().Nb(),
           aBigGraph.Topo().Faces().Nb(),
           aBigGraph.Topo().Vertices().Nb());

    // One enumeration of every occurrence of ONE face definition, the per-pick cost.
    const int  aReps  = 20;
    const auto aStart = std::chrono::steady_clock::now();
    int        aHits  = 0;
    for (int r = 0; r < aReps; ++r)
    {
      for (BRepGraph_ChildExplorer anExp(aBigGraph, aBigRoot, BRepGraph_NodeId::Kind::Face);
           anExp.More();
           anExp.Next())
      {
        if (anExp.Current().DefId.Index == 0)
        {
          (void)anExp.CurrentUsagePath();
          ++aHits;
        }
      }
    }
    const auto aEnd = std::chrono::steady_clock::now();
    const double aMs =
      std::chrono::duration<double, std::milli>(aEnd - aStart).count() / (double)aReps;
    printf("  occurrences of Face[0] = %d, one enumeration = %.3f ms\n", aHits / aReps, aMs);

    // And the whole-kind sweep, which is what a downstream identity table would build once.
    const auto aStart2 = std::chrono::steady_clock::now();
    int        aAll    = 0;
    for (BRepGraph_ChildExplorer anExp(aBigGraph, aBigRoot, BRepGraph_NodeId::Kind::Face);
         anExp.More();
         anExp.Next())
    {
      (void)anExp.CurrentUsagePath();
      ++aAll;
    }
    const auto aEnd2 = std::chrono::steady_clock::now();
    printf("  all %d face occurrences in one sweep = %.3f ms\n",
           aAll,
           std::chrono::duration<double, std::milli>(aEnd2 - aStart2).count());
  }

  // ---------------------------------------------------------------------------
  // G. the edge cases the bridge signature has to answer for: a self match, an
  // out-of-range target, an invalid root, and the unplaced single-part base case.
  // ---------------------------------------------------------------------------
  printf("=== G. edge cases ===\n");
  {
    // G1. root == target: does the explorer emit the root itself, and with what path?
    int aSelf = 0;
    for (BRepGraph_ChildExplorer anExp(aGraph, aRoot, BRepGraph_NodeId::Kind::Compound);
         anExp.More();
         anExp.Next())
    {
      printf("  G1 self match: %s path=%s parent=%s\n",
             nodeText(anExp.Current().DefId).c_str(),
             pathText(anExp.CurrentUsagePath()).c_str(),
             nodeText(anExp.CurrentParent()).c_str());
      ++aSelf;
    }
    printf("  G1 emitted %d\n", aSelf);

    // G2. a target index the graph does not have.
    int aMissing = 0;
    for (BRepGraph_ChildExplorer anExp(aGraph, aRoot, BRepGraph_NodeId::Kind::Face);
         anExp.More();
         anExp.Next())
    {
      if (anExp.Current().DefId.Index == 99)
      {
        ++aMissing;
      }
    }
    printf("  G2 occurrences of Face[99] = %d\n", aMissing);

    // G3. an out-of-range ROOT. This is the one that could be an uncatchable signal
    // rather than an exception, so the bridge needs to know which it is.
    try
    {
      const BRepGraph_NodeId aBadRoot(BRepGraph_NodeId::Kind::Face, 999);
      int                    aN = 0;
      for (BRepGraph_ChildExplorer anExp(aGraph, aBadRoot, BRepGraph_NodeId::Kind::Vertex);
           anExp.More();
           anExp.Next())
      {
        ++aN;
      }
      printf("  G3 explorer from Face[999] emitted %d, no throw\n", aN);
    }
    catch (const Standard_Failure& aFail)
    {
      printf("  G3 explorer from Face[999] threw %s\n", aFail.GetMessageString());
    }
    catch (...)
    {
      printf("  G3 explorer from Face[999] threw something\n");
    }

    // G4. the unplaced single-part base case: one box, no compound.
    BRepGraph aPlain;
    buildLikeBridge(aPlain, aBox);
    const BRepGraph_NodeId aPlainRoot = aPlain.Shapes().FindNode(aBox);
    printf("  G4 plain box root = %s\n", nodeText(aPlainRoot).c_str());
    int aPlainOcc = 0;
    for (BRepGraph_ChildExplorer anExp(aPlain, aPlainRoot, BRepGraph_NodeId::Kind::Face);
         anExp.More();
         anExp.Next())
    {
      if (anExp.Current().DefId.Index != 0)
      {
        continue;
      }
      const gp_XYZ aTr = anExp.Current().Location.Transformation().TranslationPart();
      printf("  G4 Face[0] occurrence loc=(%.1f,%.1f,%.1f) identity=%s path=%s\n",
             aTr.X(),
             aTr.Y(),
             aTr.Z(),
             anExp.Current().Location.IsIdentity() ? "true" : "false",
             pathText(anExp.CurrentUsagePath()).c_str());
      ++aPlainOcc;
    }
    printf("  G4 Face[0] occurrences on an unplaced single part = %d\n\n", aPlainOcc);
  }

  printf("\ndone\n");
  return 0;
}
