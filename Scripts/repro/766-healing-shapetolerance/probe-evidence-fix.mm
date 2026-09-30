// Epic #766, PR #2500 evidence fix. probe.mm printed the box's tolerances at %.3e and only the
// Tolerance(average) reading of a null shape. The eleven ShapeToleranceTests records each need their own
// value, so this probe prints, at %.17g, every reading a test asserts, through the same calls the bridge
// makes (OCCTShapeToleranceValue / OverCount / InRangeCount: ShapeAnalysis_ShapeTolerance::Tolerance,
// OverTolerance, InTolerance), and the null-shape readings of all three.
//
// Swift default sub-shape type 8 is TopAbs_SHAPE; 7 is TopAbs_VERTEX and 6 is TopAbs_EDGE. The Swift
// ToleranceMode raw values are average 0, maximum 1, minimum -1 (Tolerance(shape, mode, type): mode 0 is the
// average, 1 the maximum, anything else the minimum).
//
// For a null shape the bridge returns 0 from its occtShapeIsPresent guard before OCCT is called (#1438).
// The null readings below are the kernel's own answer to a null TopoDS_Shape, which is the value that guard
// has to agree with.
#include <BRepPrimAPI_MakeBox.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <TopoDS_Shape.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape                 b = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
  ShapeAnalysis_ShapeTolerance sat;
  double                       avg = sat.Tolerance(b, 0, TopAbs_SHAPE);
  double                       mx  = sat.Tolerance(b, 1, TopAbs_SHAPE);
  double                       mn  = sat.Tolerance(b, -1, TopAbs_SHAPE);
  printf("average=%.17g\n", avg);
  printf("maximum=%.17g\n", mx);
  printf("minimum=%.17g\n", mn);
  printf("ordering min=%.17g avg=%.17g max=%.17g minLeAvg=%d avgLeMax=%d\n", mn, avg, mx, (int)(mn <= avg), (int)(avg <= mx));
  auto over = sat.OverTolerance(b, 1e-3, TopAbs_SHAPE);
  auto in   = sat.InTolerance(b, 0, 1e-3, TopAbs_SHAPE);
  printf("overToleranceCount=%d\n", over.IsNull() ? 0 : (int)over->Length());
  printf("inToleranceRangeCount=%d\n", in.IsNull() ? 0 : (int)in->Length());
  printf("vertexAverage=%.17g\n", sat.Tolerance(b, 0, TopAbs_VERTEX));
  printf("edgeAverage=%.17g\n", sat.Tolerance(b, 0, TopAbs_EDGE));
  TopoDS_Shape nul;
  auto         nover = sat.OverTolerance(nul, 1e-3, TopAbs_SHAPE);
  auto         nin   = sat.InTolerance(nul, 0, 1e-3, TopAbs_SHAPE);
  printf("nullAverage=%.17g\n", sat.Tolerance(nul, 0, TopAbs_SHAPE));
  printf("nullOverToleranceCount=%d\n", nover.IsNull() ? 0 : (int)nover->Length());
  printf("nullInToleranceRangeCount=%d\n", nin.IsNull() ? 0 : (int)nin->Length());
  return 0;
}
