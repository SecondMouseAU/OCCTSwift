// #766 kernel parity for Tests/OCCTAnalysisTests/IntToolsEdgeEdgeTests.swift.
// Shape.edgeFromPoints -> OCCTBRepLibMakeEdgeFromPoints (BRepLib_MakeEdge(p1, p2));
// OCCTIntToolsEdgeEdge -> IntTools_EdgeEdge(e1, e2).Perform(), then each common part read the
// way fillCommonPart (OCCTBridge_Modeling_Boolean.mm) reads it.
#include <BRepLib_MakeEdge.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_EdgeEdge.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void run(const char* label, gp_Pnt a1, gp_Pnt a2, gp_Pnt b1, gp_Pnt b2)
{
  TopoDS_Edge       e1 = BRepLib_MakeEdge(a1, a2).Edge();
  TopoDS_Edge       e2 = BRepLib_MakeEdge(b1, b2).Edge();
  IntTools_EdgeEdge ee(e1, e2);
  ee.Perform();
  printf("%s: IsDone=%d", label, ee.IsDone() ? 1 : 0);
  if (!ee.IsDone())
  {
    printf("\n");
    return;
  }
  const NCollection_Sequence<IntTools_CommonPrt>& cps = ee.CommonParts();
  printf(" NbCommonParts=%d\n", cps.Length());
  for (int i = 1; i <= cps.Length(); i++)
  {
    const IntTools_CommonPrt& cp = cps(i);
    gp_Pnt                    p1, p2;
    cp.BoundingPoints(p1, p2);
    printf("  part %d: type=%s range1=(%.17g, %.17g) midpoint=(%.17g, %.17g, %.17g)\n", i,
           cp.Type() == TopAbs_VERTEX ? "VERTEX" : "EDGE", cp.Range1().First(), cp.Range1().Last(),
           (p1.X() + p2.X()) / 2, (p1.Y() + p2.Y()) / 2, (p1.Z() + p2.Z()) / 2);
    if (cp.Type() == TopAbs_VERTEX)
      printf("    VertexParameter1=%.17g VertexParameter2=%.17g\n", cp.VertexParameter1(),
             cp.VertexParameter2());
  }
}

int main()
{
  run("edgeEdgeVertex", gp_Pnt(-1, 0, 0), gp_Pnt(1, 0, 0), gp_Pnt(0, -1, 0), gp_Pnt(0, 1, 0));
  run("edgeEdgeOverlap", gp_Pnt(0, 0, 0), gp_Pnt(2, 0, 0), gp_Pnt(1, 0, 0), gp_Pnt(3, 0, 0));
  run("edgeEdgeNoIntersection", gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0), gp_Pnt(0, 5, 0), gp_Pnt(1, 5, 0));
  return 0;
}
