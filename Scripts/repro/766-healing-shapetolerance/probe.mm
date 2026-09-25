// #766 kernel parity: ShapeToleranceTests. ShapeAnalysis_ShapeTolerance::Tolerance / OverTolerance /
// InTolerance (OCCTShapeToleranceValue / OverCount / InRangeCount) on the 10 x 20 x 30 box, with
// the Swift default sub-shape type 8 (TopAbs_SHAPE: every vertex, edge and face).
#include <BRepPrimAPI_MakeBox.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <cstdio>

int main()
{
  TopoDS_Shape                 b = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape();
  ShapeAnalysis_ShapeTolerance sat;
  printf("avg=%.3e max=%.3e min=%.3e vertexAvg=%.3e edgeAvg=%.3e\n", sat.Tolerance(b, 0, TopAbs_SHAPE),
         sat.Tolerance(b, 1, TopAbs_SHAPE), sat.Tolerance(b, -1, TopAbs_SHAPE), sat.Tolerance(b, 0, TopAbs_VERTEX),
         sat.Tolerance(b, 0, TopAbs_EDGE));
  auto over = sat.OverTolerance(b, 1e-3, TopAbs_SHAPE);
  auto in   = sat.InTolerance(b, 0, 1e-3, TopAbs_SHAPE);
  printf("OverTolerance(1e-3)=%d InTolerance(0, 1e-3)=%d\n", over.IsNull() ? 0 : over->Length(),
         in.IsNull() ? 0 : in->Length());
  TopoDS_Shape nul;
  printf("null shape: Tolerance(avg)=%.3e\n", sat.Tolerance(nul, 0, TopAbs_SHAPE));
  return 0;
}
