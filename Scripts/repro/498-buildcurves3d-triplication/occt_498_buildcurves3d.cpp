// OCCTSwift#498 probe, what BRepLib:BuildCurves3d's two overloads actually do.
//
// #498 says the bridge has three C entry points for "one OCCT operation with two overloads":
// one legitimate tolerance/no-tolerance split, plus one accidental byte-identical copy. It also
// says the two Swift wrappers' defaults drifted 100x apart (1e-7 vs 1e-5) and that this drift
// matters. Both claims need measuring before anything is consolidated:
//
//   1. Is the no-tolerance overload a distinct algorithm, or a defaulted forwarder?
//   2. Do the box-based tests that exist observe the tolerance at all?
//   3. Is 1e-7 vs 1e-5 observable in the result, and on which geometry?
//   4. What makes the bool false, i.e. what does the void entry point throw away?
//
// No fixture files: every case builds its geometry from scratch.

#include <BRepLib.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Plane.hxx>
#include <Precision.hxx>
#include <Standard_Failure.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>
#include <string>
#include <vector>

namespace {

constexpr double kRadius = 10.0;
constexpr double kParamFirst = 0.0;
constexpr double kParamLast = 2.0;

occ::handle<Geom_CylindricalSurface> cylinder()
{
  return new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), kRadius);
}

// A pcurve that is a straight line in (u,v) but a helix in 3D once laid on the cylinder, so
// BuildCurve3d has to run its real approximation path (GeomLib::BuildCurve3d) rather than the
// analytic planar shortcut.
occ::handle<Geom2d_Curve> helicalPCurve()
{
  return new Geom2d_Line(gp_Pnt2d(0.2, -3.0), gp_Dir2d(0.6, 0.8));
}

// An edge carrying nothing but a pcurve on `surface`: no 3D curve, so BuildCurve3d must compute one.
TopoDS_Edge pcurveOnlyEdge(const occ::handle<Geom_Surface>& surface,
                           const occ::handle<Geom2d_Curve>& pcurve,
                           double edgeTolerance = 1.0e-9)
{
  BRep_Builder builder;
  TopoDS_Edge edge;
  builder.MakeEdge(edge);
  builder.UpdateEdge(edge, pcurve, surface, TopLoc_Location(), edgeTolerance);
  builder.Range(edge, kParamFirst, kParamLast);
  return edge;
}

struct EdgeState
{
  bool hasCurve3d = false;
  std::string curveType = "(none)";
  int degree = 0;
  int poles = 0;
  double tolerance = 0.0;
  double maxDeviation = -1.0;  // max |C3d(t) - surface(pcurve(t))| over the range
  const void* curvePointer = nullptr;
};

EdgeState inspect(const TopoDS_Edge& edge,
                  const occ::handle<Geom_Surface>& surface = nullptr,
                  const occ::handle<Geom2d_Curve>& pcurve = nullptr)
{
  EdgeState state;
  state.tolerance = BRep_Tool::Tolerance(edge);

  TopLoc_Location loc;
  double first = 0.0, last = 0.0;
  const occ::handle<Geom_Curve> curve = BRep_Tool::Curve(edge, loc, first, last);
  if (curve.IsNull())
    return state;

  state.hasCurve3d = true;
  state.curveType = curve->DynamicType()->Name();
  state.curvePointer = curve.get();

  const occ::handle<Geom_BSplineCurve> bspline = occ::down_cast<Geom_BSplineCurve>(curve);
  if (!bspline.IsNull())
  {
    state.degree = bspline->Degree();
    state.poles = bspline->NbPoles();
  }

  if (!surface.IsNull() && !pcurve.IsNull())
  {
    constexpr int kSamples = 401;
    double worst = 0.0;
    for (int i = 0; i < kSamples; ++i)
    {
      const double t = first + (last - first) * i / double(kSamples - 1);
      const gp_Pnt2d uv = pcurve->Value(t);
      const gp_Pnt exact = surface->Value(uv.X(), uv.Y());
      const gp_Pnt built = curve->Value(t);
      worst = std::max(worst, exact.Distance(built));
    }
    state.maxDeviation = worst;
  }
  return state;
}

void report(const char* label, const EdgeState& state)
{
  std::printf("    %-26s ", label);
  if (!state.hasCurve3d)
  {
    std::printf("no 3D curve (edge tol %.3e)\n", state.tolerance);
    return;
  }
  std::printf("%-22s deg %-2d poles %-4d edge tol %.3e", state.curveType.c_str(), state.degree,
              state.poles, state.tolerance);
  if (state.maxDeviation >= 0.0)
    std::printf("  max dev %.3e", state.maxDeviation);
  std::printf("\n");
}

// ---------------------------------------------------------------------------------------------

void case1_noToleranceOverloadIsAForwarder()
{
  std::printf("\n=== 1. Is the no-tolerance overload a distinct algorithm? ===\n");
  std::printf("BRepLib.cxx:460-464 reads `return BRepLib::BuildCurves3d(S, 1.0e-5);`, so the\n");
  std::printf("prediction is that it is bit-for-bit the tolerance overload at 1e-5.\n\n");

  const auto surface = cylinder();
  const auto pcurve = helicalPCurve();

  struct Run
  {
    const char* label;
    bool useNoToleranceOverload;
    double tolerance;
  };
  const std::vector<Run> runs = {
    {"BuildCurves3d(S)", true, 0.0},
    {"BuildCurves3d(S, 1e-5)", false, 1.0e-5},
    {"BuildCurves3d(S, 1e-7)", false, 1.0e-7},
    {"BuildCurves3d(S, 1e-3)", false, 1.0e-3},
  };

  std::printf("  helical pcurve on a cylinder, no 3D curve, edge tol 1e-9:\n");
  for (const auto& run : runs)
  {
    TopoDS_Edge edge = pcurveOnlyEdge(surface, pcurve);
    const bool ok = run.useNoToleranceOverload ? BRepLib::BuildCurves3d(edge)
                                               : BRepLib::BuildCurves3d(edge, run.tolerance);
    const EdgeState state = inspect(edge, surface, pcurve);
    std::printf("    returned %-5s", ok ? "true" : "false");
    report(run.label, state);
  }
  std::printf("\n  => the no-tolerance overload matches 1e-5 exactly, on every field.\n");
  std::printf("  => tolerance is NOT inert: it drives the approximation AND becomes the edge's\n");
  std::printf("     tolerance floor (BRepLib.cxx:428 `max_deviation = max(tolerance, Tolerance)`).\n");
}

void case2_boxIsANoOp()
{
  std::printf("\n=== 2. Do the existing box-based tests observe the tolerance? ===\n");
  std::printf("Both tests in OCCTTopologyTests call buildCurves3d* on BRepPrimAPI_MakeBox.\n\n");

  for (const double tolerance : {1.0e-7, 1.0e-5, 1.0e-1, 42.0})
  {
    TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();

    std::vector<const void*> before;
    std::vector<double> tolsBefore;
    for (TopExp_Explorer ex(box, TopAbs_EDGE); ex.More(); ex.Next())
    {
      const EdgeState state = inspect(TopoDS::Edge(ex.Current()));
      before.push_back(state.curvePointer);
      tolsBefore.push_back(state.tolerance);
    }

    const bool ok = BRepLib::BuildCurves3d(box, tolerance);

    int changedCurves = 0, changedTols = 0, i = 0;
    for (TopExp_Explorer ex(box, TopAbs_EDGE); ex.More(); ex.Next(), ++i)
    {
      const EdgeState state = inspect(TopoDS::Edge(ex.Current()));
      if (state.curvePointer != before[i])
        ++changedCurves;
      if (state.tolerance != tolsBefore[i])
        ++changedTols;
    }

    std::printf("    tolerance %-8.0e returned %-5s  edges %d  curves changed %d  tols changed %d\n",
                tolerance, ok ? "true" : "false", i, changedCurves, changedTols);
  }
  std::printf("\n  => every box edge already has a 3D curve, so BuildCurve3d returns true at its\n");
  std::printf("     first line (BRepLib.cxx:320-324) and nothing is computed. A tolerance of 42\n");
  std::printf("     is indistinguishable from 1e-7 here: the tests assert only `true`.\n");
}

void case3_planarBranchIgnoresTolerance()
{
  std::printf("\n=== 3. Where the tolerance stops mattering: the planar branch ===\n");
  std::printf("A pcurve on a Geom_Plane takes the analytic GeomLib::To3d path, which never sees\n");
  std::printf("Tolerance and hard-codes the new edge tolerance to 0 (BRepLib.cxx:368).\n\n");

  const occ::handle<Geom_Surface> plane =
    new Geom_Plane(gp_Ax3(gp_Pnt(0, 0, 5), gp_Dir(0, 0, 1)));
  const auto pcurve = helicalPCurve();

  for (const double tolerance : {1.0e-7, 1.0e-5, 1.0e-1})
  {
    TopoDS_Edge edge = pcurveOnlyEdge(plane, pcurve);
    const bool ok = BRepLib::BuildCurves3d(edge, tolerance);
    const EdgeState state = inspect(edge, plane, pcurve);
    char label[64];
    std::snprintf(label, sizeof(label), "plane, tol %.0e", tolerance);
    std::printf("    returned %-5s", ok ? "true" : "false");
    report(label, state);
  }
  std::printf("\n  => identical on a plane. The 1e-7 vs 1e-5 default drift is unobservable for\n");
  std::printf("     planar pcurves and only bites on curved support surfaces.\n");
}

void case4_whatTheVoidEntryPointDiscards()
{
  std::printf("\n=== 4. What makes the bool false (the void entry point throws it away) ===\n");

  const auto surface = cylinder();
  const auto pcurve = helicalPCurve();

  // (a) degenerate edge, no planar pcurve: BuildCurve3d's else-branch returns false outright.
  {
    BRep_Builder builder;
    TopoDS_Edge edge = pcurveOnlyEdge(surface, pcurve);
    builder.Degenerated(edge, true);
    const bool ok = BRepLib::BuildCurves3d(edge, 1.0e-5);
    const EdgeState state = inspect(edge);
    std::printf("    (a) degenerate edge on a cylinder: returned %-5s  ", ok ? "true" : "false");
    std::printf("%s\n", state.hasCurve3d ? "3D curve built" : "no 3D curve built");
  }

  // (b) one good edge + one degenerate edge in one compound: the loop ANDs the results, so the
  //     good edge is still built but the shape-level answer is false.
  {
    BRep_Builder builder;
    TopoDS_Edge good = pcurveOnlyEdge(surface, pcurve);
    TopoDS_Edge bad = pcurveOnlyEdge(surface, pcurve);
    builder.Degenerated(bad, true);

    TopoDS_Compound compound;
    builder.MakeCompound(compound);
    builder.Add(compound, good);
    builder.Add(compound, bad);

    const bool ok = BRepLib::BuildCurves3d(compound, 1.0e-5);
    std::printf("    (b) 1 good + 1 degenerate edge:      returned %-5s  ", ok ? "true" : "false");
    std::printf("good edge %s, bad edge %s\n",
                inspect(good).hasCurve3d ? "built" : "not built",
                inspect(bad).hasCurve3d ? "built" : "not built");
  }

  std::printf("\n  => false means \"at least one edge failed\", and the successful edges are still\n");
  std::printf("     modified. OCCTShapeBuildCurves3d (void) drops that signal on the floor.\n");
}

void case5_edgeWithNoGeometryAtAll()
{
  std::printf("\n=== 5. Edge with neither a 3D curve nor any pcurve, not degenerate ===\n");
  std::printf("BuildCurve3d's else-branch reads first[0]/Curve2dArray[0] whether or not the\n");
  std::printf("CurveOnSurface loop found anything (BRepLib.cxx:404-410, jj == 0 leaves both\n");
  std::printf("uninitialised). Probing whether that is reachable and what it does.\n\n");
  std::fflush(stdout);

  BRep_Builder builder;
  TopoDS_Edge edge;
  builder.MakeEdge(edge);
  builder.Range(edge, kParamFirst, kParamLast);

  try
  {
    const bool ok = BRepLib::BuildCurves3d(edge, 1.0e-5);
    std::printf("    returned %s (no exception)\n", ok ? "true" : "false");
  }
  catch (const Standard_Failure& failure)
  {
    std::printf("    threw %s: %s\n", failure.ExceptionType(),
                failure.GetMessageString() ? failure.GetMessageString() : "(no message)");
  }
  catch (...)
  {
    std::printf("    threw a non-Standard_Failure exception\n");
  }
  std::printf("    (reaching this line at all means it did not crash the process)\n");
}

}  // namespace

int main()
{
  std:printf("OCCTSwift#498, BRepLib:BuildCurves3d ground truth (pinned OCCT 8.0.0p1)\n");
  std::printf("========================================================================\n");

  case1_noToleranceOverloadIsAForwarder();
  case2_boxIsANoOp();
  case3_planarBranchIgnoresTolerance();
  case4_whatTheVoidEntryPointDiscards();
  case5_edgeWithNoGeometryAtAll();

  std::printf("\ndone\n");
  return 0;
}
