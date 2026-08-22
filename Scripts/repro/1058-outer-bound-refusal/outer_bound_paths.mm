// #1058: where OCCTWireCheckOuterBound's `false` actually comes from, and what the tri-state
// return changes.
//
// The bridge answered `false` both for "this wire is the face's outer bound" and from three
// refusal paths (null argument, !IsReady(), catch (...)). This probe runs each reachable scenario
// and reports the mechanism rather than only the verdict:
//
//   threw:    TopoDS::Wire / TopoDS::Face raised, so the bridge's catch (...) produced the false
//   ready:    ShapeAnalysis_Wire::IsReady(), false when the loaded wire has no edges
//   pcurves:  how many of the wire's edges have a pcurve on the face, counted on the same
//             EmptyCopied face CheckOuterBound builds, from the same WireAPIMake wire
//   raw:      the same count taken against the original face and the wire as passed, to show the
//             two constructions agree
//   totcross: the signed 2D area ShapeAnalysis::TotCross2D returns, which IsOuterBound signs.
//             Printed at full precision deliberately: one row's area cancels to -1.7802...e-15 and
//             the verdict is still taken from its sign, which the pcurve guard does not catch
//             (#1058 review, #1073).
//   today:    what the bridge returned before #1058
//   fixed:    what it returns after: 1 problem, 0 no problem, -1 could not check
//
// Pass --crash to add the one scenario the default run leaves out, a wire of two disconnected
// edges. WireAPIMake() is null for it and BRep_Builder::Add dereferences its component with no
// null test, so the pre-#1058 bridge takes an uncatchable SIGSEGV there and would end the run.
//
// Build and run: see README.md in this directory.

#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <Geom_Plane.hxx>
#include <Precision.hxx>
#include <ShapeAnalysis.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeExtend_WireData.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Pln.hxx>

#include <cstdio>
#include <string>

// The bridge function as it stood on main before #1058, copied verbatim apart from taking a
// TopoDS_Shape instead of an OCCTShapeRef.
static bool bridgeToday(const TopoDS_Shape& wire, const TopoDS_Shape& face)
{
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire), TopoDS::Face(face), Precision::Confusion());
    if (!saw.IsReady())
      return false;
    return saw.CheckOuterBound();
  }
  catch (...)
  {
    return false;
  }
}

// The bridge function after #1058, same transcription. occtShapeIsType is inlined rather than
// included, since it takes the bridge's own wrapper pointer; the two lines below are what it
// expands to for a wire and a face.
static int32_t bridgeFixed(const TopoDS_Shape& wire, const TopoDS_Shape& face)
{
  if (wire.IsNull() || wire.ShapeType() != TopAbs_WIRE)
    return -1;
  if (face.IsNull() || face.ShapeType() != TopAbs_FACE)
    return -1;
  try
  {
    ShapeAnalysis_Wire saw;
    saw.Init(TopoDS::Wire(wire), TopoDS::Face(face), Precision::Confusion());
    if (!saw.IsReady())
      return -1;
    TopoDS_Wire aBuilt = saw.WireData()->WireAPIMake();
    if (aBuilt.IsNull())
      return -1;
    TopoDS_Shape anEmpty = TopoDS::Face(face).EmptyCopied();
    TopoDS_Face  aProbe  = TopoDS::Face(anEmpty);
    BRep_Builder aBuilder;
    aBuilder.Add(aProbe, aBuilt);
    bool hasPCurve = false;
    for (TopExp_Explorer anIt(aProbe, TopAbs_EDGE); anIt.More() && !hasPCurve; anIt.Next())
    {
      double aFirst, aLast;
      hasPCurve =
        !BRep_Tool::CurveOnSurface(TopoDS::Edge(anIt.Current()), aProbe, aFirst, aLast).IsNull();
    }
    if (!hasPCurve)
      return -1;
    return saw.CheckOuterBound() ? 1 : 0;
  }
  catch (...)
  {
    return -1;
  }
}

static TopoDS_Wire rectangle(double x0, double y0, double x1, double y1, double z)
{
  BRepBuilderAPI_MakePolygon poly;
  poly.Add(gp_Pnt(x0, y0, z));
  poly.Add(gp_Pnt(x1, y0, z));
  poly.Add(gp_Pnt(x1, y1, z));
  poly.Add(gp_Pnt(x0, y1, z));
  poly.Close();
  return poly.Wire();
}

static int pcurveCount(const TopoDS_Shape& wire, const TopoDS_Face& face)
{
  int n = 0;
  for (TopExp_Explorer anIt(wire, TopAbs_EDGE); anIt.More(); anIt.Next())
  {
    double aFirst, aLast;
    if (!BRep_Tool::CurveOnSurface(TopoDS::Edge(anIt.Current()), face, aFirst, aLast).IsNull())
      n++;
  }
  return n;
}

static const char* tri(int32_t v)
{
  return v > 0 ? "1 " : (v == 0 ? "0 " : "-1");
}

static void report(const char* name, const TopoDS_Shape& wire, const TopoDS_Shape& face)
{
  bool   threw    = false;
  bool   ready    = false;
  int    pcurves  = -1;
  int    raw      = -1;
  double totcross = 0.0;
  try
  {
    TopoDS_Wire        w = TopoDS::Wire(wire);
    TopoDS_Face        f = TopoDS::Face(face);
    ShapeAnalysis_Wire saw;
    saw.Init(w, f, Precision::Confusion());
    ready = saw.IsReady();
    if (ready)
    {
      // Rebuild exactly what CheckOuterBound hands to ShapeAnalysis::IsOuterBound.
      TopoDS_Shape anEmpty = f.EmptyCopied();
      TopoDS_Face  aProbe  = TopoDS::Face(anEmpty);
      BRep_Builder aBuilder;
      aBuilder.Add(aProbe, saw.WireData()->WireAPIMake());
      pcurves = pcurveCount(aProbe, aProbe);
      raw     = pcurveCount(w, f);
      occ::handle<ShapeExtend_WireData> sewd =
        new ShapeExtend_WireData(saw.WireData()->WireAPIMake());
      totcross = ShapeAnalysis::TotCross2D(sewd, aProbe);
    }
  }
  catch (...)
  {
    threw = true;
  }

  std::printf("%-40s threw=%d ready=%d pcurves=%2d raw=%2d totcross=%+-24.17g today=%s fixed=%s\n",
              name,
              threw ? 1 : 0,
              ready ? 1 : 0,
              pcurves,
              raw,
              totcross,
              bridgeToday(wire, face) ? "true " : "false",
              tri(bridgeFixed(wire, face)));
}

// The ten whole-wire SAWireAnalysis siblings that share checkOuterBound's
// `catch (...) { return false; }` shape, measured on the same scenarios so a follow-up issue starts
// from data (#1058, #1074). The family is fourteen: checkConnectedEdge, checkSmallEdge,
// checkDegeneratedEdge and checkGap3dEdge have the identical bridge shape and are left out only
// because each needs an edge index this loop has no place for.
static void siblings(const char* name, const TopoDS_Shape& wire, const TopoDS_Shape& face)
{
  const char* labels[] = {"Order",
                          "Connected",
                          "Small",
                          "Degenerated",
                          "Closed",
                          "SelfIntersection",
                          "Gaps3d",
                          "Gaps2d",
                          "EdgeCurves",
                          "Lacking"};
  std::printf("%s\n", name);
  for (int i = 0; i < 10; i++)
  {
    bool        verdict = false;
    const char* how     = "computed";
    try
    {
      ShapeAnalysis_Wire saw;
      saw.Init(TopoDS::Wire(wire), TopoDS::Face(face), 1e-6);
      if (!saw.IsReady())
      {
        how = "!IsReady";
      }
      else
      {
        switch (i)
        {
          case 0: verdict = saw.CheckOrder(); break;
          case 1: verdict = saw.CheckConnected(); break;
          case 2: verdict = saw.CheckSmall(); break;
          case 3: verdict = saw.CheckDegenerated(); break;
          case 4: verdict = saw.CheckClosed(); break;
          case 5: verdict = saw.CheckSelfIntersection(); break;
          case 6: verdict = saw.CheckGaps3d(); break;
          case 7: verdict = saw.CheckGaps2d(); break;
          case 8: verdict = saw.CheckEdgeCurves(); break;
          case 9: verdict = saw.CheckLacking(); break;
        }
      }
    }
    catch (...)
    {
      how = "threw";
    }
    std::printf("    %-18s %-9s -> %s\n", labels[i], how, verdict ? "true" : "false");
  }
}

// The disconnected-edge scenario, kept out of the default run because the pre-#1058 bridge does not
// survive it. Prints the three facts that explain the crash, then the fixed bridge's verdict.
static void reportDisconnected(const TopoDS_Face& face, bool alsoCrash)
{
  TopoDS_Wire  loose;
  BRep_Builder aBuilder;
  aBuilder.MakeWire(loose);
  aBuilder.Add(loose, BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0)).Edge());
  aBuilder.Add(loose, BRepBuilderAPI_MakeEdge(gp_Pnt(5, 5, 0), gp_Pnt(6, 5, 0)).Edge());

  ShapeAnalysis_Wire saw;
  saw.Init(loose, face, Precision::Confusion());
  std::printf("two disconnected edges on panel        ready=%d nbEdges=%d apiMakeNull=%d fixed=%s\n",
              saw.IsReady() ? 1 : 0,
              saw.WireData()->NbEdges(),
              saw.WireData()->WireAPIMake().IsNull() ? 1 : 0,
              tri(bridgeFixed(loose, face)));
  if (alsoCrash)
  {
    std::printf("  calling the pre-#1058 bridge, expect signal 11 rather than a return\n");
    std::fflush(stdout);
    std::printf("  returned %s\n", bridgeToday(loose, face) ? "true" : "false");
  }
}

int main(int argc, char** argv)
{
  const bool alsoCrash = (argc > 1 && std::string(argv[1]) == "--crash");
  occ::handle<Geom_Plane> plane = new Geom_Plane(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));

  TopoDS_Wire outer = rectangle(0, 0, 10, 10, 0);
  TopoDS_Wire hole  = rectangle(3, 3, 7, 7, 0);
  TopoDS_Face panel = BRepBuilderAPI_MakeFace(plane, outer, true);
  panel             = BRepBuilderAPI_MakeFace(panel, TopoDS::Wire(hole.Reversed()));

  // A second panel 500 units away, so its wire is a real wire belonging to a different face.
  occ::handle<Geom_Plane> far      = new Geom_Plane(gp_Pln(gp_Pnt(0, 0, 500), gp_Dir(0, 0, 1)));
  TopoDS_Wire             farOuter = rectangle(0, 0, 10, 10, 500);
  TopoDS_Face             farPanel = BRepBuilderAPI_MakeFace(far, farOuter, true);

  TopoDS_Wire panelOuter, panelHole;
  {
    int n = 0;
    for (TopExp_Explorer exp(panel, TopAbs_WIRE); exp.More(); exp.Next(), n++)
    {
      if (n == 0)
        panelOuter = TopoDS::Wire(exp.Current());
      else
        panelHole = TopoDS::Wire(exp.Current());
    }
  }
  TopoDS_Wire farWire;
  for (TopExp_Explorer exp(farPanel, TopAbs_WIRE); exp.More(); exp.Next())
    farWire = TopoDS::Wire(exp.Current());

  // A cylindrical face, so BRep_Tool::CurveOnSurface has no plane fallback to compute a pcurve
  // with and a foreign wire contributes no 2D curve at all.
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5.0, 20.0).Shape();
  TopoDS_Face  lateral;
  for (TopExp_Explorer exp(cyl, TopAbs_FACE); exp.More(); exp.Next())
  {
    BRepAdaptor_Surface ads(TopoDS::Face(exp.Current()), false);
    if (ads.GetType() == GeomAbs_Cylinder)
    {
      lateral = TopoDS::Face(exp.Current());
      break;
    }
  }
  TopoDS_Wire lateralWire;
  for (TopExp_Explorer exp(lateral, TopAbs_WIRE); exp.More(); exp.Next())
  {
    lateralWire = TopoDS::Wire(exp.Current());
    break;
  }

  TopoDS_Shape box = BRepPrimAPI_MakeBox(1.0, 1.0, 1.0).Shape();

  TopoDS_Wire emptyWire;
  {
    BRep_Builder aBuilder;
    aBuilder.MakeWire(emptyWire);
  }

  std::printf("== OCCTWireCheckOuterBound ==\n");
  report("panel outer wire on panel", panelOuter, panel);
  report("panel hole wire on panel", panelHole, panel);
  report("distant panel's wire on panel", farWire, panel);
  report("distant panel's wire on its own face", farWire, farPanel);
  report("cylinder's own wire on the cylinder", lateralWire, lateral);
  report("panel outer wire on the cylinder", panelOuter, lateral);
  report("cylinder's wire on the panel", lateralWire, panel);
  report("box passed as the wire", box, panel);
  report("box passed as the face", panelOuter, box);
  report("empty wire on panel", emptyWire, panel);
  reportDisconnected(panel, alsoCrash);

  std::printf("\n== the ten siblings, same scenarios ==\n");
  siblings("panel outer wire on panel (the answerable control)", panelOuter, panel);
  siblings("panel outer wire on the cylinder (no pcurve on the face)", panelOuter, lateral);
  siblings("box passed as the wire (type mismatch)", box, panel);
  siblings("empty wire on panel (!IsReady)", emptyWire, panel);
  return 0;
}
