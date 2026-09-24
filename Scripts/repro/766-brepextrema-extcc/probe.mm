// Kernel-parity probe for Tests/OCCTAnalysisTests/BRepExtremaExtCCTests.swift (#1920, #1921).
// Box 1 is OCCTShapeCreateBox(10,10,10), centred on the origin; box 2 is
// OCCTShapeCreateBoxAt(20,0,0, 10,10,10). Edges are enumerated the way occtEdgeAt does
// (TopExp::MapShapes into an indexed map, 0-based index + 1), and each pair runs the
// BRepExtrema_ExtCC(e1, e2) that OCCTBRepExtremaExtCC and OCCTBRepExtremaExtCCEdges run.
#include <BRep_Tool.hxx>
#include <BRepExtrema_ExtCC.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cmath>
#include <cstdio>

static void ends(const char* tag, int i, const TopoDS_Edge& e)
{
  TopoDS_Vertex a, b;
  TopExp::Vertices(e, a, b);
  gp_Pnt p = BRep_Tool::Pnt(a), q = BRep_Tool::Pnt(b);
  printf("%s edge %d: (%g, %g, %g) -> (%g, %g, %g)\n", tag, i, p.X(), p.Y(), p.Z(), q.X(), q.Y(),
         q.Z());
}

static void extcc(int i, int j, const TopoDS_Edge& e1, const TopoDS_Edge& e2)
{
  BRepExtrema_ExtCC ext(e1, e2);
  printf("ExtCC(box1 edge %d, box2 edge %d): IsDone=%d IsParallel=%d", i, j, ext.IsDone(),
         ext.IsDone() ? ext.IsParallel() : -1);
  if (ext.IsDone() && !ext.IsParallel())
  {
    printf(" NbExt=%d", ext.NbExt());
    if (ext.NbExt() >= 1)
    {
      gp_Pnt p1 = ext.PointOnE1(1), p2 = ext.PointOnE2(1);
      printf(" dist(1)=%.17g paramE1=%.17g paramE2=%.17g p1=(%.17g, %.17g, %.17g) "
             "p2=(%.17g, %.17g, %.17g)",
             std::sqrt(ext.SquareDistance(1)), ext.ParameterOnE1(1), ext.ParameterOnE2(1),
             p1.X(), p1.Y(), p1.Z(), p2.X(), p2.Y(), p2.Z());
    }
  }
  else if (ext.IsDone())
  {
    // IsParallel: the bridge returns solutionCount 0 without reading NbExt.
    printf(" (bridge reports solutionCount 0)");
  }
  printf("\n");
}

int main()
{
  TopoDS_Shape b1 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape b2 = BRepPrimAPI_MakeBox(gp_Pnt(20, 0, 0), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape m1, m2;
  TopExp::MapShapes(b1, TopAbs_EDGE, m1);
  TopExp::MapShapes(b2, TopAbs_EDGE, m2);
  for (int i = 0; i < 3; i++)
    ends("box1", i, TopoDS::Edge(m1(i + 1)));
  for (int i = 0; i < 3; i++)
    ends("box2", i, TopoDS::Edge(m2(i + 1)));

  // Both tests' original pair: the first edge of each box.
  extcc(0, 0, TopoDS::Edge(m1(1)), TopoDS::Edge(m2(1)));
  // Candidate non-parallel pairs.
  extcc(0, 1, TopoDS::Edge(m1(1)), TopoDS::Edge(m2(2)));
  extcc(1, 0, TopoDS::Edge(m1(2)), TopoDS::Edge(m2(1)));
  extcc(0, 2, TopoDS::Edge(m1(1)), TopoDS::Edge(m2(3)));
  return 0;
}
