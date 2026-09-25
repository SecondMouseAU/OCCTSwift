// Ground-truth probe for #2734: checkSubShape (Sources/OCCTBridge/src/OCCTBridge_Healing_Fix.mm)
// sets isValid and firstError from BRepCheck_Edge/Wire/Shell/Vertex's Status() list but never
// increments errorCount, so an invalid sub-shape reports isValid == false with errorCount == 0
// and firstError == nil on the Swift side (Shape+Topology.swift derives firstError from
// errorCount > 0).
//
// This probe does not link OCCTBridge; it re-implements checkSubShape's counting loop verbatim,
// once as it reads today (buggy: never increments errorCount) and once with the fix (count the
// non-BRepCheck_NoError statuses, matching the sibling functions in
// OCCTBridge_Healing_Analysis.mm: OCCTCheckFace / OCCTCheckSolid / OCCTCheckShape), and runs both
// against BRepCheck_Edge/Wire/Shell/Vertex on sub-shapes built to be genuinely invalid, not
// assumed invalid. This is a MEASUREMENT of what OCCT's checker actually reports, not a re-read
// of the diff.
//
// Build: see Scripts/repro/2734-checksubshape-errorcount/README.md for the exact compile line
// (the xcframework path differs by which release asset is currently pinned/resolved).

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepCheck_Edge.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <BRepCheck_Shell.hxx>
#include <BRepCheck_Status.hxx>
#include <BRepCheck_Vertex.hxx>
#include <BRepCheck_Wire.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Curve.hxx>
#include <Precision.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>
#include <vector>

namespace
{

const char* statusName(BRepCheck_Status s)
{
  switch (s)
  {
    case BRepCheck_NoError:
      return "NoError";
    case BRepCheck_InvalidPointOnCurve:
      return "InvalidPointOnCurve";
    case BRepCheck_InvalidPointOnCurveOnSurface:
      return "InvalidPointOnCurveOnSurface";
    case BRepCheck_InvalidPointOnSurface:
      return "InvalidPointOnSurface";
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
    case BRepCheck_FreeEdge:
      return "FreeEdge";
    case BRepCheck_InvalidMultiConnexity:
      return "InvalidMultiConnexity";
    case BRepCheck_InvalidRange:
      return "InvalidRange";
    case BRepCheck_EmptyWire:
      return "EmptyWire";
    case BRepCheck_RedundantEdge:
      return "RedundantEdge";
    case BRepCheck_SelfIntersectingWire:
      return "SelfIntersectingWire";
    case BRepCheck_NoSurface:
      return "NoSurface";
    case BRepCheck_InvalidWire:
      return "InvalidWire";
    case BRepCheck_RedundantWire:
      return "RedundantWire";
    case BRepCheck_IntersectingWires:
      return "IntersectingWires";
    case BRepCheck_InvalidImbricationOfWires:
      return "InvalidImbricationOfWires";
    case BRepCheck_EmptyShell:
      return "EmptyShell";
    case BRepCheck_RedundantFace:
      return "RedundantFace";
    case BRepCheck_InvalidImbricationOfShells:
      return "InvalidImbricationOfShells";
    case BRepCheck_UnorientableShape:
      return "UnorientableShape";
    case BRepCheck_NotClosed:
      return "NotClosed";
    case BRepCheck_NotConnected:
      return "NotConnected";
    case BRepCheck_SubshapeNotInShape:
      return "SubshapeNotInShape";
    case BRepCheck_BadOrientation:
      return "BadOrientation";
    case BRepCheck_BadOrientationOfSubshape:
      return "BadOrientationOfSubshape";
    case BRepCheck_InvalidPolygonOnTriangulation:
      return "InvalidPolygonOnTriangulation";
    case BRepCheck_InvalidToleranceValue:
      return "InvalidToleranceValue";
    case BRepCheck_EnclosedRegion:
      return "EnclosedRegion";
    case BRepCheck_CheckFail:
      return "CheckFail";
    default:
      return "?";
  }
}

struct Result
{
  bool              isValid;
  int               errorCountBuggy;  // today's checkSubShape: never incremented
  int               errorCountFixed;  // this PR's checkSubShape: counts every non-NoError status
  BRepCheck_Status  firstError;
  bool              hadAnyStatus;
};

// Mirrors checkSubShape's loop body exactly, both ways, over one already-built
// BRepCheck_Result-derived checker's Status() list.
template <class Checker>
Result runCheck(Checker& checker)
{
  Result r{true, 0, 0, BRepCheck_NoError, false};
  checker.Minimum();
  const auto& statusList = checker.Status();
  for (auto it = statusList.begin(); it != statusList.end(); ++it)
  {
    r.hadAnyStatus = true;
    if (*it != BRepCheck_NoError)
    {
      r.isValid = false;
      // Buggy (today's) behaviour: firstError set, errorCount left untouched.
      if (r.firstError == BRepCheck_NoError)
        r.firstError = *it;
      // Fixed behaviour: count it too, guarding on errorCount like the sibling
      // functions in OCCTBridge_Healing_Analysis.mm (OCCTCheckFace/Solid/Shape) do.
      r.errorCountFixed++;
    }
  }
  return r;
}

} // namespace

int main()
{
  BRep_Builder builder;

  // --- EDGE: issue's own suggested repro, a standalone edge with its 3D curve removed. ---
  // Built independently of any box/solid so stripping the curve cannot mutate shared TShape data
  // belonging to another test fixture.
  gp_Pnt p1(0.0, 0.0, 0.0);
  gp_Pnt p2(10.0, 0.0, 0.0);

  BRepBuilderAPI_MakeEdge edgeMaker(p1, p2);
  TopoDS_Edge             validEdge = edgeMaker.Edge();

  // Independent construction, not a copy of validEdge, so UpdateEdge below mutates only this
  // edge's own TShape.
  BRepBuilderAPI_MakeEdge edgeMaker2(p1, p2);
  TopoDS_Edge             brokenEdge = edgeMaker2.Edge();
  builder.UpdateEdge(brokenEdge, Handle(Geom_Curve)(), Precision::Confusion());

  std::printf("=== EDGE ===\n");
  {
    Handle(BRepCheck_Edge) checker = new BRepCheck_Edge(validEdge);
    Result                 r       = runCheck(*checker);
    std::printf("valid edge:   isValid=%s errorCount(buggy)=%d errorCount(fixed)=%d "
                "firstError=%s\n",
                r.isValid ? "true" : "false",
                r.errorCountBuggy,
                r.errorCountFixed,
                statusName(r.firstError));
  }
  {
    Handle(BRepCheck_Edge) checker = new BRepCheck_Edge(brokenEdge);
    Result                 r       = runCheck(*checker);
    std::printf("no-3D-curve edge: isValid=%s errorCount(buggy)=%d errorCount(fixed)=%d "
                "firstError=%s  <-- #2734\n",
                r.isValid ? "true" : "false",
                r.errorCountBuggy,
                r.errorCountFixed,
                statusName(r.firstError));
  }

  // --- WIRE: two edges that do not share an endpoint. BRep_Builder::Add bypasses
  // BRepBuilderAPI_MakeWire's own connectivity enforcement, so this reaches BRepCheck_Wire
  // genuinely disconnected rather than merely built oddly. ---
  std::printf("\n=== WIRE ===\n");
  {
    BRepBuilderAPI_MakeEdge e1(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0));
    BRepBuilderAPI_MakeEdge e2(gp_Pnt(5, 5, 5), gp_Pnt(6, 5, 5)); // far away, no shared vertex
    TopoDS_Wire             wire;
    builder.MakeWire(wire);
    builder.Add(wire, e1.Edge());
    builder.Add(wire, e2.Edge());

    Handle(BRepCheck_Wire) checker = new BRepCheck_Wire(wire);
    Result                 r       = runCheck(*checker);
    std::printf("disconnected wire: isValid=%s errorCount(buggy)=%d errorCount(fixed)=%d "
                "firstError=%s  (hadAnyStatus=%s)\n",
                r.isValid ? "true" : "false",
                r.errorCountBuggy,
                r.errorCountFixed,
                statusName(r.firstError),
                r.hadAnyStatus ? "true" : "false");
  }

  // --- SHELL: an empty shell (no faces), the one thing BRepCheck_Shell::Minimum() is
  // documented-by-sibling-class-pattern to catch without a context shape. ---
  std::printf("\n=== SHELL ===\n");
  {
    TopoDS_Shell shell;
    builder.MakeShell(shell);

    Handle(BRepCheck_Shell) checker = new BRepCheck_Shell(shell);
    Result                  r       = runCheck(*checker);
    std::printf("empty shell: isValid=%s errorCount(buggy)=%d errorCount(fixed)=%d "
                "firstError=%s  (hadAnyStatus=%s)\n",
                r.isValid ? "true" : "false",
                r.errorCountBuggy,
                r.errorCountFixed,
                statusName(r.firstError),
                r.hadAnyStatus ? "true" : "false");
  }

  // --- VERTEX: BRepCheck_Vertex's own per-vertex faults (InvalidPointOnCurve etc.) are raised by
  // InContext(), which checkSubShape never calls (it only calls Minimum()). Try an ordinary
  // vertex and a negative-tolerance vertex to see what Minimum() alone can be made to report. ---
  std::printf("\n=== VERTEX ===\n");
  {
    TopoDS_Vertex v;
    builder.MakeVertex(v, gp_Pnt(0, 0, 0), 1e-7);
    Handle(BRepCheck_Vertex) checker = new BRepCheck_Vertex(v);
    Result                   r       = runCheck(*checker);
    std::printf("ordinary vertex: isValid=%s errorCount(buggy)=%d errorCount(fixed)=%d "
                "firstError=%s  (hadAnyStatus=%s)\n",
                r.isValid ? "true" : "false",
                r.errorCountBuggy,
                r.errorCountFixed,
                statusName(r.firstError),
                r.hadAnyStatus ? "true" : "false");
  }
  {
    TopoDS_Vertex v;
    builder.MakeVertex(v, gp_Pnt(0, 0, 0), -1.0); // negative tolerance: try to trip a self-check
    Handle(BRepCheck_Vertex) checker = new BRepCheck_Vertex(v);
    Result                   r       = runCheck(*checker);
    std::printf("negative-tolerance vertex: isValid=%s errorCount(buggy)=%d "
                "errorCount(fixed)=%d firstError=%s  (hadAnyStatus=%s)\n",
                r.isValid ? "true" : "false",
                r.errorCountBuggy,
                r.errorCountFixed,
                statusName(r.firstError),
                r.hadAnyStatus ? "true" : "false");
  }

  return 0;
}
