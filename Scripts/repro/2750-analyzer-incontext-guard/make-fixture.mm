// #2750: writes the .brep fixture the Swift regression test loads, and verifies that what comes
// back off disk is still the shape that crashes BRepCheck_Analyzer.
//
// The construction is #2746's, narrowed to the one case a consumer can actually reach:
//
//   1. Build a box and take an edge two faces share.
//   2. BRep_Builder::UpdateEdge(edge, occ::handle<Geom_Curve>(), tol) nulls the 3D curve in place
//      while the edge stays attached to both faces. UpdateCurves nulls the curve INSIDE the
//      existing BRep_Curve3D record rather than removing it, so the edge still answers
//      IsCurve3D().
//   3. BRepTools::Write drops that null record on the way out, so the file, and every shape read
//      back from it, has no curve-3D representation at all and one pcurve per owning face.
//
// That reloaded shape is the realistic consumer path: no BRep_Builder call anywhere, just a file.
// It is also why the obvious guard predicate does not work, and this probe prints both so the
// difference is on the record next to the fixture it writes.
//
// Usage: make-fixture <output.brep>      (run.sh compiles and drives it)
//
// The probe never constructs a BRepCheck_Analyzer: doing so is the crash. What it prints is the
// guard's own predicate, evaluated the way OCCTBridge_Internal.h's occtShapePCurveOnlyEdgeCount
// evaluates it, over the shape it just read back.

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <BRep_CurveRepresentation.hxx>
#include <BRep_TEdge.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Curve.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <NCollection_List.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>

namespace
{

//! The obvious predicate, the one that does not work: "some edge has a curve-3D representation
//! whose curve is null". True before the round trip, false after it, crashing either way.
bool hasNullCurve3DRepresentation(const TopoDS_Shape& theShape)
{
  for (TopExp_Explorer anExp(theShape, TopAbs_EDGE); anExp.More(); anExp.Next())
  {
    const TopoDS_Edge& anEdge = TopoDS::Edge(anExp.Current());
    const BRep_TEdge*  aTEdge = static_cast<const BRep_TEdge*>(anEdge.TShape().get());
    for (NCollection_List<occ::handle<BRep_CurveRepresentation>>::Iterator anIt(aTEdge->Curves());
         anIt.More();
         anIt.Next())
    {
      if (anIt.Value()->IsCurve3D() && anIt.Value()->Curve3D().IsNull())
      {
        return true;
      }
    }
  }
  return false;
}

//! The guard's predicate, in the same shape as occtShapePCurveOnlyEdgeCount: an edge of a face,
//! not degenerated, with no curve-3D representation holding a non-null curve, and with at least
//! one curve-on-surface representation.
int pcurveOnlyFaceEdgeCount(const TopoDS_Shape& theShape)
{
  TopTools_IndexedMapOfShape aFaceEdges;
  for (TopExp_Explorer aFaceExp(theShape, TopAbs_FACE); aFaceExp.More(); aFaceExp.Next())
  {
    TopExp::MapShapes(aFaceExp.Current(), TopAbs_EDGE, aFaceEdges);
  }

  int aCount = 0;
  for (int anIndex = 1; anIndex <= aFaceEdges.Extent(); ++anIndex)
  {
    const TopoDS_Edge& anEdge = TopoDS::Edge(aFaceEdges.FindKey(anIndex));
    if (BRep_Tool::Degenerated(anEdge))
    {
      continue;
    }
    const BRep_TEdge* aTEdge      = static_cast<const BRep_TEdge*>(anEdge.TShape().get());
    bool              aHasCurve3D = false;
    bool              aHasPCurve  = false;
    for (NCollection_List<occ::handle<BRep_CurveRepresentation>>::Iterator anIt(aTEdge->Curves());
         anIt.More();
         anIt.Next())
    {
      const occ::handle<BRep_CurveRepresentation>& aRep = anIt.Value();
      if (aRep->IsCurve3D())
      {
        if (!aRep->Curve3D().IsNull())
        {
          aHasCurve3D = true;
          break;
        }
      }
      else if (aRep->IsCurveOnSurface())
      {
        aHasPCurve = true;
      }
    }
    if (!aHasCurve3D && aHasPCurve)
    {
      ++aCount;
    }
  }
  return aCount;
}

void report(const char* theLabel, const TopoDS_Shape& theShape)
{
  std::printf("  %-24s nullCurve3DRep = %-5s  pcurveOnlyFaceEdges = %d\n",
              theLabel,
              hasNullCurve3DRepresentation(theShape) ? "true" : "false",
              pcurveOnlyFaceEdgeCount(theShape));
}

} // namespace

int main(int argc, char** argv)
{
  if (argc < 2)
  {
    std::printf("usage: make-fixture <output.brep>\n");
    return 2;
  }

  const TopoDS_Shape aBox = BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();
  report("healthy box", aBox);

  NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>, TopTools_ShapeMapHasher>
    aMap;
  TopExp::MapShapesAndAncestors(aBox, TopAbs_EDGE, TopAbs_FACE, aMap);

  TopoDS_Edge anEdge;
  for (int anIndex = 1; anIndex <= aMap.Extent(); ++anIndex)
  {
    if (aMap.FindFromIndex(anIndex).Extent() == 2)
    {
      anEdge = TopoDS::Edge(aMap.FindKey(anIndex));
      break;
    }
  }
  if (anEdge.IsNull())
  {
    std::printf("no shared edge found\n");
    return 1;
  }

  BRep_Builder aBuilder;
  aBuilder.UpdateEdge(anEdge, occ::handle<Geom_Curve>(), BRep_Tool::Tolerance(anEdge));
  report("box, 3D curve nulled", aBox);

  if (!BRepTools::Write(aBox, argv[1]))
  {
    std::printf("BRepTools::Write failed\n");
    return 1;
  }

  TopoDS_Shape aReloaded;
  BRep_Builder aReadBuilder;
  if (!BRepTools::Read(aReloaded, argv[1], aReadBuilder) || aReloaded.IsNull())
  {
    std::printf("BRepTools::Read failed\n");
    return 1;
  }
  report("same shape off disk", aReloaded);

  const int aCount = pcurveOnlyFaceEdgeCount(aReloaded);
  std::printf("\n  wrote %s\n", argv[1]);
  std::printf("  the reloaded shape is the fixture: %d pcurve-only face edge(s), while the\n",
              aCount);
  std::printf("  obvious \"null curve-3D representation\" predicate reads false on it.\n");
  return aCount > 0 ? 0 : 1;
}
