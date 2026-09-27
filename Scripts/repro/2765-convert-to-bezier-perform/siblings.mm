// #2765/#2769 sweep: every wrapper in Sources/OCCTBridge/src/OCCTBridge_Healing_Upgrade.mm that
// runs a ShapeUpgrade_ShapeDivide-family Perform(), each with that wrapper's own configuration,
// against an input that gives it nothing to do.
//
// Only ShapeUpgrade_ShapeDivide and ShapeUpgrade_ShapeConvertToBezier declare Perform() at all
// (grep "Perform" over ShapeUpgrade_Shape*.hxx in the pinned occt-src), and the override forwards
// the base's return value unchanged, so every wrapper inherits the same semantics.
//
// #2765 asked the first question: how often is a false Perform() reachable, and is Result() usable
// when it is. #2769 added the second, which is the one that decides the fix: what does
// Status(ShapeExtend_FAIL) say at the same moment. OCCT's own production caller reads the two
// together and nothing else (ShapeProcess_OperLibrary.cxx, five call sites at lines 228, 438, 525,
// 577 and 926):
//
//   if (!tool.Perform() && tool.Status(ShapeExtend_FAIL))
//     return false;                    // the failure path
//   ctx->SetResult(tool.Result());     // success, including when Perform() returned false
//
// so the columns below are exactly the inputs to that test. A row with perform=false and
// status-fail=false is a no-op, not a failure.
//
// Compile line: Scripts/repro/2765-convert-to-bezier-perform/README.md

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <GC_MakeSegment.hxx>
#include <ShapeExtend_Status.hxx>
#include <ShapeUpgrade_FaceDivideArea.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_ShapeDivideAngle.hxx>
#include <ShapeUpgrade_ShapeDivideArea.hxx>
#include <ShapeUpgrade_ShapeDivideClosed.hxx>
#include <ShapeUpgrade_ShapeDivideClosedEdges.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Pnt.hxx>

#include <cstdio>

static int countFaces(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    n++;
  return n;
}

// kind: "A" for a wrapper that gated on Perform() alone before #2769, "B" for one that ignored the
// return value entirely. The last two columns are what each kind got wrong: "was" is the answer
// before #2769, "now" is OCCT's two-part test.
static void report(const char*         label,
                   const char*         kind,
                   bool                perform,
                   bool                statusFail,
                   const TopoDS_Shape& in,
                   const TopoDS_Shape& out)
{
  const bool nilBefore = (kind[0] == 'A' && !perform) || out.IsNull();
  const bool nilNow    = (!perform && statusFail) || out.IsNull();
  printf("%-52s %s perform=%-5s status-fail=%-5s result-null=%-5s differs=%-5s faces=%-3d"
         "  was: %-5s now: %s\n",
         label,
         kind,
         perform ? "true" : "false",
         statusFail ? "true" : "false",
         out.IsNull() ? "true" : "false",
         (out.IsNull() || out.IsSame(in)) ? "false" : "true",
         out.IsNull() ? -1 : countFaces(out),
         nilBefore ? "nil" : "shape",
         nilNow ? "nil" : "shape");
}

// The exact mode set of OCCTShapeConvertToBezier.
static void configureAllModes(ShapeUpgrade_ShapeConvertToBezier& c)
{
  c.Set2dConversion(true);
  c.Set3dConversion(true);
  c.SetSurfaceConversion(true);
  c.Set3dLineConversion(true);
  c.Set3dCircleConversion(true);
  c.Set3dConicConversion(true);
  c.SetPlaneMode(true);
  c.SetRevolutionMode(true);
  c.SetExtrusionMode(true);
  c.SetBSplineMode(true);
}

int main()
{
  setvbuf(stdout, nullptr, _IOLBF, 0);

  const TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();
  const TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape();
  const TopoDS_Shape sph = BRepPrimAPI_MakeSphere(5.0).Shape();
  const TopoDS_Shape tor = BRepPrimAPI_MakeTorus(10.0, 3.0).Shape();
  const TopoDS_Shape lineEdge =
    BRepBuilderAPI_MakeEdge(GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0)).Value()).Shape();

  printf("#2765/#2769 sweep: ShapeUpgrade_ShapeDivide-family wrappers with nothing to do\n");
  printf("fixtures: box 10x20x30 (%d faces), cylinder r5 h10 (%d faces), sphere r5 (%d), "
         "torus 10/3 (%d), one straight edge (%d)\n\n",
         countFaces(box),
         countFaces(cyl),
         countFaces(sph),
         countFaces(tor),
         countFaces(lineEdge));

  printf("== Group A: gated on Perform() alone, so a no-op input returned nil (#2766)\n\n");

  // OCCTShapeDivide: ShapeUpgrade_ShapeDivideContinuity at C0 on an all-planar box.
  {
    ShapeUpgrade_ShapeDivideContinuity d(box);
    d.SetBoundaryCriterion(GeomAbs_C0);
    d.SetPCurveCriterion(GeomAbs_C0);
    d.SetSurfaceCriterion(GeomAbs_C0);
    d.SetTolerance(1e-7);
    d.SetSurfaceSegmentMode(Standard_True);
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeDivide (Continuity C0, box)", "A", p, d.Status(ShapeExtend_FAIL), box, r);
  }

  // OCCTShapeSplitByAngle and OCCTShapeUpgradeSplitSurfaceAngle are the same construction twice,
  // so one row covers both: nothing angular on a box.
  {
    ShapeUpgrade_ShapeDivideAngle d(M_PI / 2.0, box);
    const bool                    p = d.Perform();
    const TopoDS_Shape            r = d.Result();
    report("OCCTShapeSplitByAngle (90 deg, box)", "A", p, d.Status(ShapeExtend_FAIL), box, r);
  }
  {
    ShapeUpgrade_ShapeDivideAngle d(M_PI / 4.0, cyl);
    const bool                    p = d.Perform();
    const TopoDS_Shape            r = d.Result();
    report("  ... same class, cylinder at 45 deg (control)",
           "A",
           p,
           d.Status(ShapeExtend_FAIL),
           cyl,
           r);
  }

  // OCCTShapeDivideClosedEdges: a box has no closed edge.
  {
    ShapeUpgrade_ShapeDivideClosedEdges d(box);
    d.SetNbSplitPoints(1);
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeDivideClosedEdges (box)", "A", p, d.Status(ShapeExtend_FAIL), box, r);
  }

  // OCCTShapeUpgradeDivideClosed: a box has no closed face.
  {
    ShapeUpgrade_ShapeDivideClosed d(box);
    d.SetNbSplitPoints(1);
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeUpgradeDivideClosed (box)", "A", p, d.Status(ShapeExtend_FAIL), box, r);
  }
  {
    ShapeUpgrade_ShapeDivideClosed d(cyl);
    d.SetNbSplitPoints(1);
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("  ... same class, cylinder (control)", "A", p, d.Status(ShapeExtend_FAIL), cyl, r);
  }

  // OCCTShapeDivideByNumber with nbU = nbV = 1 is no split at all. Swift's dividedByNumber(_:)
  // refuses parts <= 1, so the case it actually reaches is a face-less shape: one straight edge.
  {
    ShapeUpgrade_ShapeDivide            d(box);
    Handle(ShapeUpgrade_FaceDivideArea) fd = new ShapeUpgrade_FaceDivideArea();
    fd->SetSplittingByNumber(true);
    fd->NbParts() = 1;
    fd->MaxArea() = -1;
    fd->SetNumbersUVSplits(1, 1);
    d.SetSplitFaceTool(fd);
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeDivideByNumber (nbU=nbV=1, box)", "A", p, d.Status(ShapeExtend_FAIL), box, r);
  }
  {
    ShapeUpgrade_ShapeDivide            d(lineEdge);
    Handle(ShapeUpgrade_FaceDivideArea) fd = new ShapeUpgrade_FaceDivideArea();
    fd->SetSplittingByNumber(true);
    fd->NbParts() = 2;
    fd->MaxArea() = -1;
    fd->SetNumbersUVSplits(2, 1);
    d.SetSplitFaceTool(fd);
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeDivideByNumber (nbU=2, one edge)",
           "A",
           p,
           d.Status(ShapeExtend_FAIL),
           lineEdge,
           r);
  }

  // OCCTShapeDivideByParts with nbParts = 1.
  {
    ShapeUpgrade_ShapeDivideArea d(box);
    d.SetSplittingByNumber(true);
    d.NbParts()          = 1;
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeDivideByParts (nbParts=1, box)", "A", p, d.Status(ShapeExtend_FAIL), box, r);
  }

  printf("\n== Group B: ignored Perform() entirely, so a FAIL came back as a result (#2769)\n\n");

  // OCCTShapeDivideByArea with a max area larger than any face.
  {
    ShapeUpgrade_ShapeDivideArea d(box);
    d.MaxArea()          = 1.0e6;
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeDivideByArea (maxArea=1e6, box)", "B", p, d.Status(ShapeExtend_FAIL), box, r);
  }

  // OCCTShapeConvertToBezier: all modes on, on a shape with nothing left to convert (an edge whose
  // curve one pass has already made a Bezier).
  {
    ShapeUpgrade_ShapeConvertToBezier c(lineEdge);
    configureAllModes(c);
    c.Perform();
    const TopoDS_Shape once = c.Result();

    ShapeUpgrade_ShapeConvertToBezier c2(once);
    configureAllModes(c2);
    const bool         p = c2.Perform();
    const TopoDS_Shape r = c2.Result();
    report("OCCTShapeConvertToBezier (already-Bezier edge)",
           "B",
           p,
           c2.Status(ShapeExtend_FAIL),
           once,
           r);
  }

  // OCCTShapeUpgradeConvertCurves3dToBezier with every per-kind mode off: nothing matches.
  {
    ShapeUpgrade_ShapeConvertToBezier c(box);
    c.Set3dConversion(true);
    c.Set3dLineConversion(Standard_False);
    c.Set3dCircleConversion(Standard_False);
    c.Set3dConicConversion(Standard_False);
    c.SetSurfaceSegmentMode(Standard_False);
    const bool         p = c.Perform();
    const TopoDS_Shape r = c.Result();
    report("OCCTShapeUpgradeConvertCurves3dToBezier (all modes off, box)",
           "B",
           p,
           c.Status(ShapeExtend_FAIL),
           box,
           r);
  }

  // OCCTShapeUpgradeConvertSurfaceToBezier with every per-kind mode off.
  {
    ShapeUpgrade_ShapeConvertToBezier c(box);
    c.SetSurfaceConversion(true);
    c.SetPlaneMode(Standard_False);
    c.SetRevolutionMode(Standard_False);
    c.SetExtrusionMode(Standard_False);
    c.SetBSplineMode(Standard_False);
    c.SetSurfaceSegmentMode(Standard_True);
    const bool         p = c.Perform();
    const TopoDS_Shape r = c.Result();
    report("OCCTShapeUpgradeConvertSurfaceToBezier (all modes off, box)",
           "B",
           p,
           c.Status(ShapeExtend_FAIL),
           box,
           r);
  }

  printf("\n== Hunting a genuine Status(ShapeExtend_FAIL), which is the outcome group B lost\n\n");

  // FAIL1 is the myShape.IsNull() guard at the top of Perform(), which every bridge wrapper
  // already covers with its own null check. It is the only FAIL these wrappers can reach from a
  // parameter alone; FAIL2 and FAIL3 need the split-face or split-wire tool to fail or throw on a
  // sub-shape, which is a property of the input geometry, not of anything a caller passes.
  {
    const TopoDS_Shape                 nullShape;
    ShapeUpgrade_ShapeDivideContinuity d(nullShape);
    const bool                         p = d.Perform();
    const TopoDS_Shape                 r = d.Result();
    report("null shape (FAIL1, unreachable through the bridge)",
           "A",
           p,
           d.Status(ShapeExtend_FAIL),
           nullShape,
           r);
  }

  // FAIL2 and FAIL3 need the split-face or split-wire tool to fail or throw on a sub-shape, which
  // is a property of the input geometry rather than of anything a caller passes. The cheapest
  // attempt at FAIL2 was a compound holding a face hand-built with BRep_Builder and no surface at
  // all. It does not set FAIL: it SIGSEGVs (exit 139) inside Perform()'s TopAbs_FACE loop, whose
  // try/catch only catches Standard_Failure, so the process dies before any status is written.
  // That case is therefore not kept in this probe, since it takes the rest of the transcript with
  // it; see README.md. The Swift API cannot build such a face anyway.

  // Parameter values a caller can actually pass, at the edges of their ranges. None of these is
  // expected to set FAIL; the point is to record that they do not.
  struct AngleCase
  {
    const char*         label;
    double              radians;
    const TopoDS_Shape& in;
  };
  // maxAngle 0 is left out on purpose: it asks for infinitely many angular splits and runs out of
  // time rather than reporting a failure, which is a different finding from the one being hunted.
  const AngleCase angles[] = {
    {"SplitByAngle -30 deg, cylinder", -M_PI / 6.0, cyl},
    {"SplitByAngle 720 deg, sphere", 4.0 * M_PI, sph},
    {"SplitByAngle 1 deg, torus", M_PI / 180.0, tor},
  };
  for (const AngleCase& c : angles)
  {
    ShapeUpgrade_ShapeDivideAngle d(c.radians, c.in);
    const bool                    p = d.Perform();
    const TopoDS_Shape            r = d.Result();
    report(c.label, "A", p, d.Status(ShapeExtend_FAIL), c.in, r);
  }

  const double tolerances[] = {0.0, -1.0, 1.0e12};
  for (double tol : tolerances)
  {
    ShapeUpgrade_ShapeDivideContinuity d(sph);
    d.SetBoundaryCriterion(GeomAbs_C3);
    d.SetPCurveCriterion(GeomAbs_C3);
    d.SetSurfaceCriterion(GeomAbs_C3);
    d.SetTolerance(tol);
    d.SetSurfaceSegmentMode(Standard_True);
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    char               label[96];
    snprintf(label, sizeof(label), "Divide C3 on sphere, tolerance %g", tol);
    report(label, "A", p, d.Status(ShapeExtend_FAIL), sph, r);
  }

  const int splitPoints[] = {0, -5, 64};
  for (int n : splitPoints)
  {
    ShapeUpgrade_ShapeDivideClosed d(cyl);
    d.SetNbSplitPoints(n);
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    char               label[96];
    snprintf(label, sizeof(label), "DivideClosed on cylinder, nbSplitPoints %d", n);
    report(label, "A", p, d.Status(ShapeExtend_FAIL), cyl, r);
  }

  // Small but finite: maxArea 1e-6 on a 314-unit cylinder wall asks for ~3e8 faces and never
  // returns, so the smallest value measured here is the smallest one that finishes.
  const double areas[] = {10.0, 1.0};
  for (double a : areas)
  {
    ShapeUpgrade_ShapeDivideArea d(cyl);
    d.MaxArea()          = a;
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    char               label[96];
    snprintf(label, sizeof(label), "DivideByArea on cylinder, maxArea %g", a);
    report(label, "B", p, d.Status(ShapeExtend_FAIL), cyl, r);
  }

  return 0;
}
