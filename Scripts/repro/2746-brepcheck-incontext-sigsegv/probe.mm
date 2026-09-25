// Ground-truth probe for #2746: BRepCheck_Edge::InContext(face) raises an uncatchable SIGSEGV on
// an edge whose 3D curve was removed in place with BRep_Builder::UpdateEdge(edge,
// Handle(Geom_Curve)(), tol).
//
// Each case runs in its own process (see run.sh), because a case that faults takes the process
// with it: OCC_CATCH_SIGNALS is inert in this build, so the signal cannot be caught in process
// and a surviving case cannot be sequenced after a faulting one. The SIGSEGV handler installed
// below prints a backtrace before the process dies, which is what names the faulting frame in the
// absence of a debugger.
//
// Build and run: see README.md in this directory for the exact compile line and the transcript.
//
// The cases, and what each one is for:
//
//   healthy-edge-incontext         control: an untouched box edge, both owning faces.
//   nulled-edge-incontext-face0    the reported crash, first owning face.
//   nulled-edge-incontext-face1    the same edge against the OTHER owning face.
//   nulled-edge-no-minimum         InContext() with no explicit Minimum() call.
//   nulled-edge-gctrl-off          GeometricControls(false) before InContext().
//   nulled-edge-cylindrical-face   the same removal on a NON-planar owning face.
//   removed-rep-edge-incontext     the Curve3D REPRESENTATION dropped, not just its curve.
//   fresh-edge-zero-reps           an edge that never had a curve, zero representations.
//   nulled-edge-detached           the nulled edge checked against a face it is not part of.
//   nulled-edge-vertex-incontext   BRepCheck_Vertex::InContext on the same construction (#2747).
//   nulled-edge-wire-incontext     BRepCheck_Wire::InContext on the same construction.
//   nulled-edge-analyzer           BRepCheck_Analyzer, which is what the bridge actually calls.
//   brep-roundtrip-analyzer        the same, after a .brep write and read.
//   healthy-edge-analyzer          control for the line above.
//   downcast-corroboration         second construction: the failing down_cast, built by hand.
//   guard-predicate                the predicate a bridge-side guard would use, both ways.

#include <Adaptor3d_CurveOnSurface.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Edge.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <BRepCheck_Status.hxx>
#include <BRepCheck_Vertex.hxx>
#include <BRepCheck_Wire.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Builder.hxx>
#include <BRep_CurveRepresentation.hxx>
#include <BRep_TEdge.hxx>
#include <BRep_Tool.hxx>
#include <BRepTools.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Plane.hxx>
#include <Geom_Surface.hxx>
#include <Precision.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>

#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <execinfo.h>
#include <unistd.h>

namespace
{

//=================================================================================================
// SIGSEGV reporting. lldb is unavailable in this environment, so the backtrace has to come from
// the faulting process itself.
//=================================================================================================

void segvHandler(int theSignal)
{
  const char* aMessage = "\n*** SIGSEGV (uncatchable in this build) ***\n";
  write(STDERR_FILENO, aMessage, std::strlen(aMessage));
  void* aFrames[64];
  int   aCount = backtrace(aFrames, 64);
  backtrace_symbols_fd(aFrames, aCount, STDERR_FILENO);
  std::signal(theSignal, SIG_DFL);
  raise(theSignal);
}

const char* statusName(BRepCheck_Status theStatus)
{
  switch (theStatus)
  {
    case BRepCheck_NoError:
      return "NoError";
    case BRepCheck_No3DCurve:
      return "No3DCurve";
    case BRepCheck_Multiple3DCurve:
      return "Multiple3DCurve";
    case BRepCheck_Invalid3DCurve:
      return "Invalid3DCurve";
    case BRepCheck_NoCurveOnSurface:
      return "NoCurveOnSurface";
    case BRepCheck_InvalidCurveOnSurface:
      return "InvalidCurveOnSurface";
    case BRepCheck_InvalidCurveOnClosedSurface:
      return "InvalidCurveOnClosedSurface";
    case BRepCheck_InvalidSameRangeFlag:
      return "InvalidSameRangeFlag";
    case BRepCheck_InvalidSameParameterFlag:
      return "InvalidSameParameterFlag";
    case BRepCheck_InvalidDegeneratedFlag:
      return "InvalidDegeneratedFlag";
    case BRepCheck_InvalidRange:
      return "InvalidRange";
    case BRepCheck_InvalidPointOnCurve:
      return "InvalidPointOnCurve";
    case BRepCheck_InvalidPointOnCurveOnSurface:
      return "InvalidPointOnCurveOnSurface";
    case BRepCheck_InvalidPointOnSurface:
      return "InvalidPointOnSurface";
    case BRepCheck_SubshapeNotInShape:
      return "SubshapeNotInShape";
    case BRepCheck_FreeEdge:
      return "FreeEdge";
    case BRepCheck_InvalidMultiConnexity:
      return "InvalidMultiConnexity";
    case BRepCheck_CheckFail:
      return "CheckFail";
    default:
      return "other";
  }
}

void printStatuses(const char* theLabel, BRepCheck_Result& theResult, const TopoDS_Shape& theContext)
{
  std::printf("  %s: ", theLabel);
  if (!theResult.IsStatusOnShape(theContext))
  {
    std::printf("(no status recorded)\n");
    return;
  }
  const NCollection_List<BRepCheck_Status>& aList = theResult.StatusOnShape(theContext);
  if (aList.IsEmpty())
  {
    std::printf("(empty)\n");
    return;
  }
  for (NCollection_List<BRepCheck_Status>::Iterator anIt(aList); anIt.More(); anIt.Next())
  {
    std::printf("%s ", statusName(anIt.Value()));
  }
  std::printf("\n");
}

//=================================================================================================
// Fixtures. Each is built fresh per process, so no case can be contaminated by another's
// in-place mutation of a shared TShape.
//=================================================================================================

struct BoxFixture
{
  TopoDS_Shape box;
  TopoDS_Edge  edge;
  TopoDS_Face  face0;
  TopoDS_Face  face1;
};

//! Builds a box and picks the first edge that two faces share, plus both of those faces.
BoxFixture makeBox()
{
  BoxFixture aFixture;
  aFixture.box = BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();

  NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>, TopTools_ShapeMapHasher>
    aMap;
  TopExp::MapShapesAndAncestors(aFixture.box, TopAbs_EDGE, TopAbs_FACE, aMap);

  for (int anIndex = 1; anIndex <= aMap.Extent(); ++anIndex)
  {
    if (aMap.FindFromIndex(anIndex).Extent() == 2)
    {
      aFixture.edge  = TopoDS::Edge(aMap.FindKey(anIndex));
      aFixture.face0 = TopoDS::Face(aMap.FindFromIndex(anIndex).First());
      aFixture.face1 = TopoDS::Face(aMap.FindFromIndex(anIndex).Last());
      break;
    }
  }
  return aFixture;
}

//! Removes the edge's 3D curve in place, leaving it attached to its faces. This is the issue's
//! construction verbatim.
void removeCurve3D(const TopoDS_Edge& theEdge)
{
  BRep_Builder aBuilder;
  aBuilder.UpdateEdge(theEdge, occ::handle<Geom_Curve>(), Precision::Confusion());
}

//! Reports what the edge's curve representation list looks like, which is the state Minimum()
//! reads. The distinction that matters for #2746 is a retained Curve3D representation holding a
//! null curve, versus no representation at all.
void describeRepresentations(const TopoDS_Edge& theEdge)
{
  const occ::handle<BRep_TEdge>& aTEdge = *((occ::handle<BRep_TEdge>*)&theEdge.TShape());
  int                            aCurve3dCount = 0, aNullCurve3dCount = 0, aPCurveCount = 0;
  for (NCollection_List<occ::handle<BRep_CurveRepresentation>>::Iterator anIt(aTEdge->Curves());
       anIt.More();
       anIt.Next())
  {
    if (anIt.Value()->IsCurve3D())
    {
      ++aCurve3dCount;
      if (anIt.Value()->Curve3D().IsNull())
      {
        ++aNullCurve3dCount;
      }
    }
    else if (anIt.Value()->IsCurveOnSurface())
    {
      ++aPCurveCount;
    }
  }
  std::printf("  representations: total=%d curve3d=%d (null=%d) pcurve=%d\n",
              aTEdge->Curves().Extent(),
              aCurve3dCount,
              aNullCurve3dCount,
              aPCurveCount);
}

//! The predicate a bridge-side guard would use: a Curve3D representation whose curve is null.
//! That is the exact state BRep_Builder::UpdateEdge leaves behind, and the one Minimum() does not
//! report, because the representation still answers true to IsCurve3D().
bool hasNullCurve3DRepresentation(const TopoDS_Shape& theShape)
{
  for (TopExp_Explorer anExp(theShape, TopAbs_EDGE); anExp.More(); anExp.Next())
  {
    const TopoDS_Edge&             anEdge = TopoDS::Edge(anExp.Current());
    const occ::handle<BRep_TEdge>& aTEdge = *((occ::handle<BRep_TEdge>*)&anEdge.TShape());
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

//=================================================================================================
// Cases.
//=================================================================================================

int caseHealthyEdgeInContext()
{
  BoxFixture aFixture = makeBox();
  describeRepresentations(aFixture.edge);
  {
    BRepCheck_Edge aChecker(aFixture.edge);
    aChecker.Minimum();
    printStatuses("Minimum", aChecker, aFixture.edge);
    aChecker.InContext(aFixture.face0);
    printStatuses("InContext(face0)", aChecker, aFixture.face0);
    aChecker.InContext(aFixture.face1);
    printStatuses("InContext(face1)", aChecker, aFixture.face1);
  }
  std::printf("  survived\n");
  return 0;
}

int caseNulledEdgeInContext(bool theUseFace1)
{
  BoxFixture aFixture = makeBox();
  removeCurve3D(aFixture.edge);
  describeRepresentations(aFixture.edge);

  const TopoDS_Face& aFace = theUseFace1 ? aFixture.face1 : aFixture.face0;
  BRepCheck_Edge     aChecker(aFixture.edge);
  aChecker.Minimum();
  printStatuses("Minimum", aChecker, aFixture.edge);
  std::printf("  calling InContext(%s)...\n", theUseFace1 ? "face1" : "face0");
  std::fflush(stdout);
  aChecker.InContext(aFace);
  printStatuses("InContext", aChecker, aFace);
  std::printf("  survived\n");
  return 0;
}

//! There is no such thing as skipping Minimum(): BRepCheck_Result::Init, which the
//! BRepCheck_Edge constructor calls, runs Minimum() itself. This case exists to record that,
//! because "only call InContext after you have inspected Minimum's statuses" would otherwise
//! read as a usable mitigation.
int caseNulledEdgeNoMinimum()
{
  BoxFixture aFixture = makeBox();
  removeCurve3D(aFixture.edge);
  BRepCheck_Edge aChecker(aFixture.edge);
  std::printf("  calling InContext(face0) with no explicit Minimum() call...\n");
  std::fflush(stdout);
  aChecker.InContext(aFixture.face0);
  printStatuses("InContext", aChecker, aFixture.face0);
  std::printf("  survived\n");
  return 0;
}

int caseNulledEdgeGctrlOff()
{
  BoxFixture aFixture = makeBox();
  removeCurve3D(aFixture.edge);
  BRepCheck_Edge aChecker(aFixture.edge);
  aChecker.GeometricControls(false);
  aChecker.Minimum();
  printStatuses("Minimum", aChecker, aFixture.edge);
  std::printf("  calling InContext(face0) with GeometricControls(false)...\n");
  std::fflush(stdout);
  aChecker.InContext(aFixture.face0);
  printStatuses("InContext", aChecker, aFixture.face0);
  std::printf("  survived\n");
  return 0;
}

//! The same removal, but on an edge whose owning face is a cylinder rather than a plane. The
//! faulting branch in BRepCheck_Edge::InContext is the planar on-the-fly projection, so a
//! non-planar support should take the BRepCheck_NoCurveOnSurface branch instead and survive.
int caseNulledEdgeCylindricalFace()
{
  TopoDS_Shape aCylinder = BRepPrimAPI_MakeCylinder(5.0, 20.0).Shape();

  NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>, TopTools_ShapeMapHasher>
    aMap;
  TopExp::MapShapesAndAncestors(aCylinder, TopAbs_EDGE, TopAbs_FACE, aMap);

  TopoDS_Edge anEdge;
  TopoDS_Face aCylindricalFace;
  for (int anIndex = 1; anIndex <= aMap.Extent() && aCylindricalFace.IsNull(); ++anIndex)
  {
    for (NCollection_List<TopoDS_Shape>::Iterator anIt(aMap.FindFromIndex(anIndex)); anIt.More();
         anIt.Next())
    {
      const TopoDS_Face&               aFace    = TopoDS::Face(anIt.Value());
      TopLoc_Location                  aLoc;
      const occ::handle<Geom_Surface>& aSurface = BRep_Tool::Surface(aFace, aLoc);
      if (!aSurface.IsNull()
          && std::strstr(aSurface->DynamicType()->Name(), "Geom_CylindricalSurface") != nullptr)
      {
        anEdge           = TopoDS::Edge(aMap.FindKey(anIndex));
        aCylindricalFace = aFace;
        break;
      }
    }
  }
  if (aCylindricalFace.IsNull())
  {
    std::printf("  FIXTURE FAILURE: no cylindrical face found\n");
    return 2;
  }

  removeCurve3D(anEdge);
  describeRepresentations(anEdge);
  BRepCheck_Edge aChecker(anEdge);
  aChecker.Minimum();
  printStatuses("Minimum", aChecker, anEdge);
  std::printf("  calling InContext(cylindrical face)...\n");
  std::fflush(stdout);
  aChecker.InContext(aCylindricalFace);
  printStatuses("InContext", aChecker, aCylindricalFace);
  std::printf("  survived\n");
  return 0;
}

//! Drops the Curve3D REPRESENTATION from the edge altogether, rather than nulling the curve it
//! holds. The two states differ in what Minimum() reports: BRep_Builder::UpdateEdge leaves the
//! representation in place, so the representation still answers true to IsCurve3D() and
//! Minimum() stays silent, whereas dropping it makes Minimum() report No3DCurve. If both crash,
//! the fault is myCref's fallback to a pcurve and not UpdateEdge's bookkeeping.
int caseRemovedRepEdgeInContext()
{
  BoxFixture                     aFixture = makeBox();
  const occ::handle<BRep_TEdge>& aTEdge = *((occ::handle<BRep_TEdge>*)&aFixture.edge.TShape());
  for (NCollection_List<occ::handle<BRep_CurveRepresentation>>::Iterator anIt(
         aTEdge->ChangeCurves());
       anIt.More();)
  {
    if (anIt.Value()->IsCurve3D())
    {
      aTEdge->ChangeCurves().Remove(anIt);
    }
    else
    {
      anIt.Next();
    }
  }
  describeRepresentations(aFixture.edge);

  BRepCheck_Edge aChecker(aFixture.edge);
  printStatuses("Minimum", aChecker, aFixture.edge);
  std::printf("  calling InContext(face0)...\n");
  std::fflush(stdout);
  aChecker.InContext(aFixture.face0);
  printStatuses("InContext", aChecker, aFixture.face0);
  std::printf("  survived\n");
  return 0;
}

//! An edge that never had a curve at all: BRep_Builder::MakeEdge and nothing else, so the
//! representation list is empty. It is spliced into a planar face built here rather than into one
//! of the box's own wires, because a wire already owned by a face is frozen and
//! TopoDS_Builder::Add throws TopoDS_FrozenShape on it.
int caseFreshEdgeZeroReps()
{
  BRep_Builder aBuilder;

  TopoDS_Edge aFreshEdge;
  aBuilder.MakeEdge(aFreshEdge);
  describeRepresentations(aFreshEdge);

  BRepBuilderAPI_MakeEdge anEdge0(gp_Pnt(0.0, 0.0, 0.0), gp_Pnt(10.0, 0.0, 0.0));
  BRepBuilderAPI_MakeEdge anEdge1(gp_Pnt(10.0, 0.0, 0.0), gp_Pnt(10.0, 10.0, 0.0));
  BRepBuilderAPI_MakeEdge anEdge2(gp_Pnt(10.0, 10.0, 0.0), gp_Pnt(0.0, 10.0, 0.0));
  BRepBuilderAPI_MakeEdge anEdge3(gp_Pnt(0.0, 10.0, 0.0), gp_Pnt(0.0, 0.0, 0.0));

  TopoDS_Wire aWire;
  aBuilder.MakeWire(aWire);
  aBuilder.Add(aWire, anEdge0.Edge());
  aBuilder.Add(aWire, anEdge1.Edge());
  aBuilder.Add(aWire, anEdge2.Edge());
  aBuilder.Add(aWire, anEdge3.Edge());
  aBuilder.Add(aWire, aFreshEdge);

  TopoDS_Face aFace;
  aBuilder.MakeFace(aFace,
                    new Geom_Plane(gp_Pln(gp_Pnt(0.0, 0.0, 0.0), gp_Dir(0.0, 0.0, 1.0))),
                    Precision::Confusion());
  aBuilder.Add(aFace, aWire);

  bool aFound = false;
  for (TopExp_Explorer anExp(aFace, TopAbs_EDGE); anExp.More(); anExp.Next())
  {
    if (anExp.Current().IsSame(aFreshEdge))
    {
      aFound = true;
      break;
    }
  }
  std::printf("  fresh edge is part of the face: %s\n", aFound ? "yes" : "no");

  BRepCheck_Edge aChecker(aFreshEdge);
  printStatuses("Minimum", aChecker, aFreshEdge);
  std::printf("  calling InContext(face)...\n");
  std::fflush(stdout);
  aChecker.InContext(aFace);
  printStatuses("InContext", aChecker, aFace);
  std::printf("  survived\n");
  return 0;
}

//! The nulled edge checked against a face of a different box, so the early
//! BRepCheck_SubshapeNotInShape return fires before any geometry is touched.
int caseNulledEdgeDetached()
{
  BoxFixture aFixture = makeBox();
  removeCurve3D(aFixture.edge);

  BoxFixture anOtherBox = makeBox();

  BRepCheck_Edge aChecker(aFixture.edge);
  aChecker.Minimum();
  std::printf("  calling InContext(face of an unrelated box)...\n");
  std::fflush(stdout);
  aChecker.InContext(anOtherBox.face0);
  printStatuses("InContext", aChecker, anOtherBox.face0);
  std::printf("  survived\n");
  return 0;
}

//! #2747's question: does BRepCheck_Vertex::InContext share the fault on the same construction?
int caseNulledEdgeVertexInContext()
{
  BoxFixture aFixture = makeBox();
  removeCurve3D(aFixture.edge);

  TopoDS_Vertex aVertex;
  for (TopExp_Explorer anExp(aFixture.edge, TopAbs_VERTEX); anExp.More(); anExp.Next())
  {
    aVertex = TopoDS::Vertex(anExp.Current());
    break;
  }
  if (aVertex.IsNull())
  {
    std::printf("  FIXTURE FAILURE: edge has no vertex\n");
    return 2;
  }

  BRepCheck_Vertex aChecker(aVertex);
  aChecker.Minimum();
  printStatuses("Minimum", aChecker, aVertex);
  std::printf("  calling BRepCheck_Vertex::InContext(nulled edge)...\n");
  std::fflush(stdout);
  aChecker.InContext(aFixture.edge);
  printStatuses("InContext(edge)", aChecker, aFixture.edge);
  std::printf("  calling BRepCheck_Vertex::InContext(face0)...\n");
  std::fflush(stdout);
  aChecker.InContext(aFixture.face0);
  printStatuses("InContext(face0)", aChecker, aFixture.face0);
  std::printf("  survived\n");
  return 0;
}

int caseNulledEdgeWireInContext()
{
  BoxFixture aFixture = makeBox();
  removeCurve3D(aFixture.edge);

  TopoDS_Wire aWire;
  for (TopExp_Explorer anExp(aFixture.face0, TopAbs_WIRE); anExp.More(); anExp.Next())
  {
    aWire = TopoDS::Wire(anExp.Current());
    break;
  }
  if (aWire.IsNull())
  {
    std::printf("  FIXTURE FAILURE: face0 has no wire\n");
    return 2;
  }

  BRepCheck_Wire aChecker(aWire);
  aChecker.Minimum();
  printStatuses("Minimum", aChecker, aWire);
  std::printf("  calling BRepCheck_Wire::InContext(face0)...\n");
  std::fflush(stdout);
  aChecker.InContext(aFixture.face0);
  printStatuses("InContext(face0)", aChecker, aFixture.face0);
  std::printf("  survived\n");
  return 0;
}

//! BRepCheck_Analyzer is what the bridge calls. Its Perform() walks every face and calls
//! BRepCheck_Edge::InContext(face) for each of that face's edges, inside a try/OCC_CATCH_SIGNALS
//! block that is inert in this build.
int caseAnalyzer(bool theNullTheCurve)
{
  BoxFixture aFixture = makeBox();
  if (theNullTheCurve)
  {
    removeCurve3D(aFixture.edge);
  }
  describeRepresentations(aFixture.edge);
  std::printf("  calling BRepCheck_Analyzer(box).IsValid()...\n");
  std::fflush(stdout);
  BRepCheck_Analyzer anAnalyzer(aFixture.box);
  std::printf("  IsValid() = %s\n", anAnalyzer.IsValid() ? "true" : "false");
  std::printf("  survived\n");
  return 0;
}

//! Reachability from the shipped API. The bridge never removes a 3D curve, so the question is
//! whether such an edge can arrive from outside: write the nulled box to a .brep file, read it
//! back through the same BRepTools entry points the bridge's BREP loader uses, and run the
//! analyzer on what comes back.
int caseBrepRoundtripAnalyzer()
{
  BoxFixture aFixture = makeBox();
  removeCurve3D(aFixture.edge);

  const char* aPath = "/tmp/occt_probe_2746_nulled.brep";
  if (!BRepTools::Write(aFixture.box, aPath))
  {
    std::printf("  BRepTools::Write refused the nulled shape\n");
    return 0;
  }
  std::printf("  BRepTools::Write accepted the nulled shape\n");

  TopoDS_Shape aReloaded;
  BRep_Builder aBuilder;
  if (!BRepTools::Read(aReloaded, aPath, aBuilder))
  {
    std::printf("  BRepTools::Read refused the file\n");
    return 0;
  }
  std::printf("  BRepTools::Read accepted the file\n");
  std::printf("  reloaded shape has a null-3D-curve edge: %s\n",
              hasNullCurve3DRepresentation(aReloaded) ? "yes" : "no");

  std::printf("  calling BRepCheck_Analyzer(reloaded).IsValid()...\n");
  std::fflush(stdout);
  BRepCheck_Analyzer anAnalyzer(aReloaded);
  std::printf("  IsValid() = %s\n", anAnalyzer.IsValid() ? "true" : "false");
  std::printf("  survived\n");
  return 0;
}

//! The precondition for the fault, stated as a predicate over a shape: a non-degenerated edge
//! with no valid 3D curve but at least one pcurve. That is exactly when
//! BRepCheck_Edge::Minimum() falls back to a pcurve for myCref and leaves myHCurve as an
//! Adaptor3d_CurveOnSurface. Both crashing constructions satisfy it; a healthy box, a cylinder
//! (whose seam and degenerated edges are the obvious false-positive risk) and an edge with no
//! representations at all do not.
bool hasPCurveOnlyEdge(const TopoDS_Shape& theShape)
{
  for (TopExp_Explorer anExp(theShape, TopAbs_EDGE); anExp.More(); anExp.Next())
  {
    const TopoDS_Edge& anEdge = TopoDS::Edge(anExp.Current());
    if (BRep_Tool::Degenerated(anEdge))
    {
      continue;
    }
    double                  aFirst = 0.0, aLast = 0.0;
    occ::handle<Geom_Curve> aCurve = BRep_Tool::Curve(anEdge, aFirst, aLast);
    if (!aCurve.IsNull())
    {
      continue;
    }
    const occ::handle<BRep_TEdge>& aTEdge = *((occ::handle<BRep_TEdge>*)&anEdge.TShape());
    for (NCollection_List<occ::handle<BRep_CurveRepresentation>>::Iterator anIt(aTEdge->Curves());
         anIt.More();
         anIt.Next())
    {
      if (anIt.Value()->IsCurveOnSurface())
      {
        return true;
      }
    }
  }
  return false;
}

//! Second construction. BRepCheck_Edge::Minimum() sets myHCurve to a GeomAdaptor_Curve when
//! myCref is a 3D curve representation, and to an Adaptor3d_CurveOnSurface when it had to fall
//! back to a pcurve. InContext's planar projection branch does an unchecked
//! down_cast<GeomAdaptor_Curve> on it. Build both adaptors here and show which down_cast
//! survives, without going anywhere near BRepCheck.
int caseDowncastCorroboration()
{
  BoxFixture aFixture = makeBox();

  double                  aFirst = 0.0, aLast = 0.0;
  occ::handle<Geom_Curve> aCurve3d = BRep_Tool::Curve(aFixture.edge, aFirst, aLast);
  occ::handle<Adaptor3d_Curve> aFromCurve3d = new GeomAdaptor_Curve(aCurve3d, aFirst, aLast);

  double                    aPFirst = 0.0, aPLast = 0.0;
  occ::handle<Geom2d_Curve> aPCurve =
    BRep_Tool::CurveOnSurface(aFixture.edge, aFixture.face0, aPFirst, aPLast);
  TopLoc_Location                  aLoc;
  const occ::handle<Geom_Surface>& aSurface = BRep_Tool::Surface(aFixture.face0, aLoc);
  occ::handle<Geom2dAdaptor_Curve> aPAdaptor = new Geom2dAdaptor_Curve(aPCurve, aPFirst, aPLast);
  occ::handle<GeomAdaptor_Surface> aSAdaptor = new GeomAdaptor_Surface(aSurface);
  occ::handle<Adaptor3d_Curve>     aFromPCurve = new Adaptor3d_CurveOnSurface(aPAdaptor, aSAdaptor);

  std::printf("  myHCurve built from a 3D curve      -> dynamic type %s, "
              "down_cast<GeomAdaptor_Curve> %s\n",
              aFromCurve3d->DynamicType()->Name(),
              occ::down_cast<GeomAdaptor_Curve>(aFromCurve3d).IsNull() ? "IS NULL" : "succeeds");
  std::printf("  myHCurve built from a pcurve        -> dynamic type %s, "
              "down_cast<GeomAdaptor_Curve> %s\n",
              aFromPCurve->DynamicType()->Name(),
              occ::down_cast<GeomAdaptor_Curve>(aFromPCurve).IsNull() ? "IS NULL" : "succeeds");
  std::printf("  survived\n");
  return 0;
}

int caseGuardPredicate()
{
  BoxFixture aHealthy = makeBox();
  std::printf("  healthy box: hasNullCurve3DRepresentation = %s\n",
              hasNullCurve3DRepresentation(aHealthy.box) ? "true" : "false");

  BoxFixture aNulled = makeBox();
  removeCurve3D(aNulled.edge);
  std::printf("  nulled box:  hasNullCurve3DRepresentation = %s\n",
              hasNullCurve3DRepresentation(aNulled.box) ? "true" : "false");

  BoxFixture aRemoved = makeBox();
  {
    const occ::handle<BRep_TEdge>& aTEdge = *((occ::handle<BRep_TEdge>*)&aRemoved.edge.TShape());
    for (NCollection_List<occ::handle<BRep_CurveRepresentation>>::Iterator anIt(
           aTEdge->ChangeCurves());
         anIt.More();)
    {
      if (anIt.Value()->IsCurve3D())
      {
        aTEdge->ChangeCurves().Remove(anIt);
      }
      else
      {
        anIt.Next();
      }
    }
  }
  std::printf("  box with the Curve3D representation dropped: "
              "hasNullCurve3DRepresentation = %s\n",
              hasNullCurve3DRepresentation(aRemoved.box) ? "true" : "false");

  TopoDS_Shape aCylinder = BRepPrimAPI_MakeCylinder(5.0, 20.0).Shape();
  std::printf("  cylinder (seam plus degenerated edges): hasNullCurve3DRepresentation = %s\n",
              hasNullCurve3DRepresentation(aCylinder) ? "true" : "false");

  std::printf("\n  the precondition predicate, which covers both crashing constructions:\n");
  std::printf("  healthy box:                      hasPCurveOnlyEdge = %s\n",
              hasPCurveOnlyEdge(aHealthy.box) ? "true" : "false");
  std::printf("  nulled-curve box:                 hasPCurveOnlyEdge = %s\n",
              hasPCurveOnlyEdge(aNulled.box) ? "true" : "false");
  std::printf("  dropped-representation box:       hasPCurveOnlyEdge = %s\n",
              hasPCurveOnlyEdge(aRemoved.box) ? "true" : "false");
  std::printf("  cylinder (seam plus degenerated): hasPCurveOnlyEdge = %s\n",
              hasPCurveOnlyEdge(aCylinder) ? "true" : "false");
  std::printf("  survived\n");
  return 0;
}

} // namespace

int main(int argc, const char* argv[])
{
  std::signal(SIGSEGV, segvHandler);
  std::signal(SIGBUS, segvHandler);

  if (argc < 2)
  {
    std::printf("usage: probe <case>\n");
    return 2;
  }
  const char* aCase = argv[1];
  std::printf("=== case: %s ===\n", aCase);
  std::fflush(stdout);

  if (std::strcmp(aCase, "healthy-edge-incontext") == 0)
  {
    return caseHealthyEdgeInContext();
  }
  if (std::strcmp(aCase, "nulled-edge-incontext-face0") == 0)
  {
    return caseNulledEdgeInContext(false);
  }
  if (std::strcmp(aCase, "nulled-edge-incontext-face1") == 0)
  {
    return caseNulledEdgeInContext(true);
  }
  if (std::strcmp(aCase, "nulled-edge-no-minimum") == 0)
  {
    return caseNulledEdgeNoMinimum();
  }
  if (std::strcmp(aCase, "nulled-edge-gctrl-off") == 0)
  {
    return caseNulledEdgeGctrlOff();
  }
  if (std::strcmp(aCase, "nulled-edge-cylindrical-face") == 0)
  {
    return caseNulledEdgeCylindricalFace();
  }
  if (std::strcmp(aCase, "removed-rep-edge-incontext") == 0)
  {
    return caseRemovedRepEdgeInContext();
  }
  if (std::strcmp(aCase, "fresh-edge-zero-reps") == 0)
  {
    return caseFreshEdgeZeroReps();
  }
  if (std::strcmp(aCase, "nulled-edge-detached") == 0)
  {
    return caseNulledEdgeDetached();
  }
  if (std::strcmp(aCase, "nulled-edge-vertex-incontext") == 0)
  {
    return caseNulledEdgeVertexInContext();
  }
  if (std::strcmp(aCase, "nulled-edge-wire-incontext") == 0)
  {
    return caseNulledEdgeWireInContext();
  }
  if (std::strcmp(aCase, "nulled-edge-analyzer") == 0)
  {
    return caseAnalyzer(true);
  }
  if (std::strcmp(aCase, "healthy-edge-analyzer") == 0)
  {
    return caseAnalyzer(false);
  }
  if (std::strcmp(aCase, "brep-roundtrip-analyzer") == 0)
  {
    return caseBrepRoundtripAnalyzer();
  }
  if (std::strcmp(aCase, "downcast-corroboration") == 0)
  {
    return caseDowncastCorroboration();
  }
  if (std::strcmp(aCase, "guard-predicate") == 0)
  {
    return caseGuardPredicate();
  }

  std::printf("unknown case: %s\n", aCase);
  return 2;
}
