// #766 kernel parity for Tests/OCCTAnalysisTests/IntToolsEdgeFaceTests.swift
// (edgeFaceIntersection). Same construction as OCCTIntToolsEdgeFace
// (OCCTBridge_Modeling_Boolean.mm), including the SetRange #1631 added. Shape.subShapes(ofType:
// .face) enumerates faces in TopExp::MapShapes order (occtMapSubShapes).
#include <BRepLib_MakeEdge.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_EdgeFace.hxx>
#include <IntTools_Range.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cstdio>

static void run(const char* label, const TopTools_IndexedMapOfShape& faces, const TopoDS_Edge& edge)
{
  for (int i = 1; i <= faces.Extent(); i++)
  {
    const TopoDS_Face& f = TopoDS::Face(faces(i));
    IntTools_EdgeFace  ef;
    ef.SetEdge(edge);
    ef.SetFace(f);
    double first = 0, last = 0;
    BRep_Tool::Range(edge, first, last);
    ef.SetRange(IntTools_Range(first, last));
    ef.Perform();
    printf("%s vs faces()[%d]: IsDone=%d", label, i - 1, ef.IsDone() ? 1 : 0);
    if (!ef.IsDone())
    {
      printf("\n");
      continue;
    }
    const NCollection_Sequence<IntTools_CommonPrt>& cps = ef.CommonParts();
    printf(" NbCommonParts=%d\n", cps.Length());
    for (int k = 1; k <= cps.Length(); k++)
    {
      gp_Pnt p1, p2;
      cps(k).BoundingPoints(p1, p2);
      printf("  part %d: type=%s range1=(%.17g, %.17g) midpoint=(%.17g, %.17g, %.17g)\n", k,
             cps(k).Type() == TopAbs_VERTEX ? "VERTEX" : "EDGE", cps(k).Range1().First(),
             cps(k).Range1().Last(), (p1.X() + p2.X()) / 2, (p1.Y() + p2.Y()) / 2,
             (p1.Z() + p2.Z()) / 2);
    }
  }
}

int main()
{
  // Shape.box(width:10,height:10,depth:10) is centred on the origin (OCCTShapeCreateBox).
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape faces;
  TopExp::MapShapes(box, TopAbs_FACE, faces);
  run("edge (5,5,-1)-(5,5,11) [the test's original fixture]", faces,
      BRepLib_MakeEdge(gp_Pnt(5, 5, -1), gp_Pnt(5, 5, 11)).Edge());
  run("edge (-10,1,2)-(0,1,2) [the rewritten fixture]", faces,
      BRepLib_MakeEdge(gp_Pnt(-10, 1, 2), gp_Pnt(0, 1, 2)).Edge());
  return 0;
}
