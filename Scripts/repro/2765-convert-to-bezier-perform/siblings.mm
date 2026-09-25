// #2765 sweep: every other ShapeUpgrade_ShapeDivide subclass wrapped in
// Sources/OCCTBridge/src/OCCTBridge_Healing_Upgrade.mm, run with that wrapper's own
// configuration against an input that gives it nothing to split.
//
// None of the subclasses declares Perform() at all (grep "Perform" over
// ShapeUpgrade_ShapeDivide*.hxx in the pinned occt-src: only the base and
// ShapeUpgrade_ShapeConvertToBezier do), so every one of them inherits
// ShapeUpgrade_ShapeDivide::Perform()'s "false means nothing changed" semantics. This probe
// measures how often that false is reachable in practice, and whether Result() is usable when
// it is.
//
// Compile line: Scripts/repro/2765-convert-to-bezier-perform/README.md

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <ShapeUpgrade_FaceDivideArea.hxx>
#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_ShapeDivideAngle.hxx>
#include <ShapeUpgrade_ShapeDivideArea.hxx>
#include <ShapeUpgrade_ShapeDivideClosed.hxx>
#include <ShapeUpgrade_ShapeDivideClosedEdges.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS_Shape.hxx>

#include <cstdio>

static int countFaces(const TopoDS_Shape& s)
{
  int n = 0;
  for (TopExp_Explorer e(s, TopAbs_FACE); e.More(); e.Next())
    n++;
  return n;
}

// bridgeChecksPerform: whether the wrapper gates on Perform()'s return value today. Only
// OCCTShapeDivideByArea does not.
static void report(const char*         label,
                   bool                perform,
                   const TopoDS_Shape& in,
                   const TopoDS_Shape& out,
                   bool                bridgeChecksPerform = true)
{
  const bool nilToday = (bridgeChecksPerform && !perform) || out.IsNull();
  printf("%-52s perform=%-5s result-null=%-5s differs=%-5s faces=%d  -> bridge today: %s\n",
         label,
         perform ? "true" : "false",
         out.IsNull() ? "true" : "false",
         (out.IsNull() || out.IsSame(in)) ? "false" : "true",
         out.IsNull() ? -1 : countFaces(out),
         nilToday ? "nil" : "shape");
}

int main()
{
  const TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 20.0, 30.0).Shape();
  const TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(5.0, 10.0).Shape();

  printf("#2765 sweep: ShapeUpgrade_ShapeDivide subclasses with nothing to split\n");
  printf("fixtures: box 10x20x30 (%d faces), cylinder r5 h10 (%d faces)\n\n",
         countFaces(box),
         countFaces(cyl));

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
    report("OCCTShapeDivide (Continuity C0, box)", p, box, r);
  }

  // OCCTShapeSplitByAngle / OCCTShapeUpgradeSplitSurfaceAngle: nothing angular on a box.
  {
    ShapeUpgrade_ShapeDivideAngle d(M_PI / 2.0, box);
    const bool                    p = d.Perform();
    const TopoDS_Shape            r = d.Result();
    report("OCCTShapeSplitByAngle (90 deg, box)", p, box, r);
  }

  // OCCTShapeDivideClosedEdges: a box has no closed edge.
  {
    ShapeUpgrade_ShapeDivideClosedEdges d(box);
    d.SetNbSplitPoints(1);
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeDivideClosedEdges (box)", p, box, r);
  }

  // OCCTShapeUpgradeDivideClosed: a box has no closed face.
  {
    ShapeUpgrade_ShapeDivideClosed d(box);
    d.SetNbSplitPoints(1);
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeUpgradeDivideClosed (box)", p, box, r);
  }

  // ...and the same class on a cylinder, which does have a closed face, as the control.
  {
    ShapeUpgrade_ShapeDivideClosed d(cyl);
    d.SetNbSplitPoints(1);
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeUpgradeDivideClosed (cylinder, control)", p, cyl, r);
  }

  // OCCTShapeDivideByNumber with nbU = nbV = 1: one part per axis is no split at all.
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
    report("OCCTShapeDivideByNumber (nbU=nbV=1, box)", p, box, r);
  }

  // OCCTShapeDivideByParts with nbParts = 1.
  {
    ShapeUpgrade_ShapeDivideArea d(box);
    d.SetSplittingByNumber(true);
    d.NbParts()          = 1;
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeDivideByParts (nbParts=1, box)", p, box, r);
  }

  // OCCTShapeDivideByArea with a max area larger than any face: the one wrapper in the file that
  // already ignores Perform()'s return value, kept here as the shape of the correct handling.
  {
    ShapeUpgrade_ShapeDivideArea d(box);
    d.MaxArea()          = 1.0e6;
    const bool         p = d.Perform();
    const TopoDS_Shape r = d.Result();
    report("OCCTShapeDivideByArea (maxArea=1e6, box)", p, box, r, false);
  }

  return 0;
}
