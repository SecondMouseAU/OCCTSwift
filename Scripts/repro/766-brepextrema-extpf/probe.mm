// Epic #766, Tests/OCCTAnalysisTests/BRepExtremaExtPFTests.swift: kernel parity probe.
// OCCTBRepExtremaExtPF runs BRepExtrema_ExtPF(vertex, face) on the face at occtFaceAt(shape, i)
// and reports NbExt, sqrt(SquareDistance(1)), Point(1) and Parameter(1). Same calls here, over
// every face of Shape.box(width: 10, height: 10, depth: 10), which OCCTShapeCreateBox centres.
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepExtrema_ExtPF.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <cmath>
#include <cstdio>

static void run(const char* name, const gp_Pnt& p)
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes(box, TopAbs_FACE, map);
  for (int i = 1; i <= map.Extent(); ++i)
  {
    BRepExtrema_ExtPF ext(BRepBuilderAPI_MakeVertex(p), TopoDS::Face(map(i)));
    printf("%s point=(%g, %g, %g) face[%d] IsDone=%d", name, p.X(), p.Y(), p.Z(), i - 1, ext.IsDone());
    if (ext.IsDone())
    {
      printf(" NbExt=%d", ext.NbExt());
      if (ext.NbExt() >= 1)
      {
        gp_Pnt q = ext.Point(1);
        double u, v;
        ext.Parameter(1, u, v);
        printf(" distance=%.17g point=(%.17g, %.17g, %.17g) uv=(%.17g, %.17g)",
               std::sqrt(ext.SquareDistance(1)), q.X(), q.Y(), q.Z(), u, v);
      }
    }
    printf("\n");
  }
}

int main()
{
  run("pointFaceDistance", gp_Pnt(5, 5, 15));
  run("pointFaceDistance", gp_Pnt(0, 0, 15));
  return 0;
}
