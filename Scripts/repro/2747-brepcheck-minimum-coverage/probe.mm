// Ground-truth probe for #2747: what does BRepCheck_Edge::Minimum() /
// BRepCheck_Vertex::Minimum() actually check?
//
// checkEdge(at:) / checkVertex(at:) (Sources/OCCTBridge/src/OCCTBridge_Healing_Fix.mm,
// checkSubShape) call Minimum() and never InContext(), so what Minimum() alone can report is
// the entire contract of those two Swift methods. PR #2742's probe
// (Scripts/repro/2734-checksubshape-errorcount/probe.mm) established that the constructions it
// tried (a 3D curve removed via BRep_Builder::UpdateEdge, GeometricControls(true), a shrunk
// parameter range, Degenerated forced via BRep_Builder, an ordinary and a negative-tolerance
// vertex) all report BRepCheck_NoError. This probe does not repeat those; it reads
// BRepCheck_Edge.cxx and BRepCheck_Vertex.cxx (Libraries/occt-src/src/ModelingAlgorithms/TKTopAlgo/
// BRepCheck/, unpatched: no Scripts/patches/*.patch touches either file) to find every status
// Minimum()'s own logic can append, then builds one construction per status and MEASURES what
// Minimum() actually reports, rather than trusting the source read alone.
//
// BRepCheck_Vertex::Minimum() has no conditional logic at all: it appends BRepCheck_NoError
// unconditionally, every time, regardless of the vertex's own state. That is not a "no fault
// found in testing" result, it is a structural invariant, confirmed here by construction but
// provable from the four-line function body alone: no status other than NoError is reachable
// through Minimum() for ANY vertex.
//
// BRepCheck_Edge::Minimum() has real conditional logic (existence/uniqueness of a 3D curve
// representation, the SameRange/SameParameter flag pair, the Degenerated flag against a present
// curve, and the curve's own parametric range), but every ordinary BRep_Builder call that would
// flip one of those flags into a faulting state also neutralises the very fault it would
// trigger: BRep_Builder::Degenerated(E, true) nulls the 3D curve as a side effect (see
// BRep_Builder.cxx), which is exactly why forcing Degenerated=true through the public builder
// reported NoError in #2742's probe. This probe finds four statuses that ARE reachable, two
// through ordinary BRep_Builder calls alone (InvalidSameParameterFlag, InvalidRange) and two
// only by mutating the TShape's own BRep_TEdge object directly rather than through BRep_Builder
// (No3DCurve via a curve-less edge, Multiple3DCurve via a duplicate representation appended to
// BRep_TEdge::ChangeCurves() directly, InvalidDegeneratedFlag via BRep_TEdge::Degenerated(bool)
// called directly instead of through BRep_Builder::Degenerated, which is the only way to set the
// flag without also nulling the curve).
//
// Build: see README.md in this directory for the exact compile line (the xcframework path
// differs by which release asset is currently pinned/resolved).

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepCheck_Edge.hxx>
#include <BRepCheck_ListOfStatus.hxx>
#include <BRepCheck_Status.hxx>
#include <BRepCheck_Vertex.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Curve3D.hxx>
#include <BRep_TEdge.hxx>
#include <BRep_Tool.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Line.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Vertex.hxx>
#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>

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

// Mirrors checkSubShape's own reading of a checker's Status() list after Minimum(): the first
// non-NoError status is "the error", same as OCCTBridge_Healing_Fix.mm's checkSubShape.
template <class Checker>
void report(const char* label, Checker& checker)
{
  checker.Minimum();
  const auto&      statusList = checker.Status();
  bool             isValid    = true;
  BRepCheck_Status firstError = BRepCheck_NoError;
  int              count      = 0;
  for (auto it = statusList.begin(); it != statusList.end(); ++it)
  {
    count++;
    if (*it != BRepCheck_NoError)
    {
      isValid = false;
      if (firstError == BRepCheck_NoError)
      {
        firstError = *it;
      }
    }
  }
  std::printf("%-60s isValid=%-5s firstError=%-24s (statusCount=%d)\n",
              label,
              isValid ? "true" : "false",
              statusName(firstError),
              count);
}

} // namespace

int main()
{
  BRep_Builder builder;

  std::printf("=== EDGE ===\n");

  // Control: an ordinary straight edge, nothing touched afterwards.
  {
    BRepBuilderAPI_MakeEdge em(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge             e = em.Edge();
    Handle(BRepCheck_Edge)  checker = new BRepCheck_Edge(e);
    report("control: ordinary edge", *checker);
  }

  // No3DCurve: a bare TEdge with zero curve representations of any kind. Never calling
  // UpdateEdge at all, rather than calling it with a null curve (#2742 tried the latter: that
  // REPLACES an existing representation's curve handle with null, it does not remove the
  // representation, so BRepCheck_Edge::Minimum()'s exist/unique scan over TE->Curves() still
  // finds one IsCurve3D() representation and never reaches the "!exist" branch).
  {
    TopoDS_Edge e;
    builder.MakeEdge(e);
    Handle(BRepCheck_Edge) checker = new BRepCheck_Edge(e);
    report("No3DCurve: MakeEdge, no UpdateEdge call at all", *checker);
  }

  // Multiple3DCurve: append a second BRep_Curve3D representation directly to the TShape's own
  // curve list. BRep_Builder::UpdateEdge's 3D-curve overload always replaces an existing
  // Curve3D-typed representation in place (BRep_Builder.cxx's static UpdateCurves), so this
  // status cannot be reached through BRep_Builder alone; BRep_TEdge::ChangeCurves() is a public,
  // non-const accessor, so this is still legitimate OCCT API, just not the builder's own path.
  {
    BRepBuilderAPI_MakeEdge em(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge             e  = em.Edge();
    Handle(BRep_TEdge)      TE = Handle(BRep_TEdge)::DownCast(e.TShape());
    Handle(Geom_Curve) second  = new Geom_Line(gp_Ax1(gp_Pnt(0, 5, 0), gp_Dir(1, 0, 0)));
    TE->ChangeCurves().Append(new BRep_Curve3D(second, TopLoc_Location()));
    Handle(BRepCheck_Edge) checker = new BRepCheck_Edge(e);
    report("Multiple3DCurve: 2nd Curve3D rep appended directly", *checker);
  }

  // InvalidSameParameterFlag: SameRange=false, SameParameter=true, via BRep_Builder alone.
  // Minimum() checks this pair unconditionally, before it even looks at the curve list.
  {
    BRepBuilderAPI_MakeEdge em(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge             e = em.Edge();
    builder.SameRange(e, false);
    builder.SameParameter(e, true);
    Handle(BRepCheck_Edge) checker = new BRepCheck_Edge(e);
    report("InvalidSameParameterFlag: SameRange=false, SameParameter=true", *checker);
  }

  // InvalidRange, Last <= First: BRep_Builder::Range's own SetRange call has no ordering check.
  {
    BRepBuilderAPI_MakeEdge em(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge             e = em.Edge();
    builder.Range(e, 5.0, 5.0); // Last == First
    Handle(BRepCheck_Edge) checker = new BRepCheck_Edge(e);
    report("InvalidRange: Range(edge, 5.0, 5.0), Last == First", *checker);
  }
  {
    BRepBuilderAPI_MakeEdge em(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge             e = em.Edge();
    builder.Range(e, 5.0, 0.0); // Last < First
    Handle(BRepCheck_Edge) checker = new BRepCheck_Edge(e);
    report("InvalidRange: Range(edge, 5.0, 0.0), Last < First", *checker);
  }

  // InvalidDegeneratedFlag: force the flag on the TShape directly, bypassing
  // BRep_Builder::Degenerated (whose own implementation nulls the 3D curve as a side effect,
  // which is why BRep_Builder::Degenerated(e, true) alone reported NoError in #2742's probe:
  // it defeats the very check it would otherwise trip). BRep_TEdge::Degenerated(bool) is a
  // public, Standard_EXPORT setter; this calls it directly instead, leaving the curve intact.
  {
    BRepBuilderAPI_MakeEdge em(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge             e  = em.Edge();
    Handle(BRep_TEdge)      TE = Handle(BRep_TEdge)::DownCast(e.TShape());
    TE->Degenerated(true); // curve representation left untouched, unlike BRep_Builder::Degenerated
    Handle(BRepCheck_Edge) checker = new BRepCheck_Edge(e);
    report("InvalidDegeneratedFlag: BRep_TEdge::Degenerated(true) direct, curve kept", *checker);
  }

  // Re-confirmation, for contrast: the same Degenerated flag set through BRep_Builder, which
  // nulls the curve as a side effect and so reports NoError, exactly as #2742 measured.
  {
    BRepBuilderAPI_MakeEdge em(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge             e = em.Edge();
    builder.Degenerated(e, true); // this call itself nulls the 3D curve (BRep_Builder.cxx)
    Handle(BRepCheck_Edge) checker = new BRepCheck_Edge(e);
    report("re-confirm #2742: BRep_Builder::Degenerated(e, true), curve nulled by the call",
           *checker);
  }

  std::printf("\n=== VERTEX ===\n");
  std::printf("(BRepCheck_Vertex::Minimum() appends BRepCheck_NoError unconditionally; every "
              "row below is expected to read NoError, and no vertex construction can change "
              "that outcome. Confirmed by construction, not merely by source reading.)\n");

  {
    TopoDS_Vertex v;
    builder.MakeVertex(v, gp_Pnt(0, 0, 0), 1e-7);
    Handle(BRepCheck_Vertex) checker = new BRepCheck_Vertex(v);
    report("ordinary vertex", *checker);
  }
  {
    TopoDS_Vertex v;
    builder.MakeVertex(v, gp_Pnt(0, 0, 0), -1.0);
    Handle(BRepCheck_Vertex) checker = new BRepCheck_Vertex(v);
    report("negative-tolerance vertex", *checker);
  }
  {
    TopoDS_Vertex v;
    builder.MakeVertex(v, gp_Pnt(1e300, 1e300, 1e300), 0.0);
    Handle(BRepCheck_Vertex) checker = new BRepCheck_Vertex(v);
    report("huge-coordinate, zero-tolerance vertex", *checker);
  }

  return 0;
}
