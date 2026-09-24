// Kernel parity probe for Tests/OCCTAnalysisTests/BRepExtremaExtCFTests.swift (#766).
//
// Builds the tests' shapes the way the bridge does (OCCTShapeCreateBox centres the box on the
// origin; OCCTShapeCreateBoxAt puts its corner at the given origin; OCCTShapeCreateSphere is
// BRepPrimAPI_MakeSphere(r)), indexes edges and faces through TopExp::MapShapes as
// occtEdgeAt/occtFaceAt do, and runs BRepExtrema_ExtCF on every pair the tests visit, reporting
// what OCCTBRepExtremaExtCF would: IsDone, IsParallel, NbExt and the minimum-distance extremum.
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepExtrema_ExtCF.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>

static void run(const char* name, const TopoDS_Shape& a, int nEdges, const TopoDS_Shape& b,
                int nFaces)
{
  TopTools_IndexedMapOfShape edges, faces;
  TopExp::MapShapes(a, TopAbs_EDGE, edges);
  TopExp::MapShapes(b, TopAbs_FACE, faces);
  printf("%s: %d edges, %d faces\n", name, edges.Extent(), faces.Extent());
  for (int i = 0; i < nEdges && i < edges.Extent(); i++)
  {
    for (int j = 0; j < nFaces && j < faces.Extent(); j++)
    {
      BRepExtrema_ExtCF ext(TopoDS::Edge(edges(i + 1)), TopoDS::Face(faces(j + 1)));
      printf("  edge %d face %d: IsDone=%d", i, j, ext.IsDone());
      if (!ext.IsDone())
      {
        printf("\n");
        continue;
      }
      printf(" IsParallel=%d", ext.IsParallel());
      if (ext.IsParallel())
      {
        printf("\n");
        continue;
      }
      printf(" NbExt=%d", ext.NbExt());
      if (ext.NbExt() < 1)
      {
        printf("\n");
        continue;
      }
      int    minIdx = 1;
      double min2   = ext.SquareDistance(1);
      for (int k = 2; k <= ext.NbExt(); k++)
        if (ext.SquareDistance(k) < min2)
        {
          min2   = ext.SquareDistance(k);
          minIdx = k;
        }
      gp_Pnt pe = ext.PointOnEdge(minIdx), pf = ext.PointOnFace(minIdx);
      printf(" minDist=%.17g paramOnEdge=%.17g pe=(%.17g, %.17g, %.17g) pf=(%.17g, %.17g, "
             "%.17g)\n",
             std::sqrt(min2), ext.ParameterOnEdge(minIdx), pe.X(), pe.Y(), pe.Z(), pf.X(), pf.Y(),
             pf.Z());
    }
  }
}

int main()
{
  TopoDS_Shape box    = BRepPrimAPI_MakeBox(gp_Pnt(-10, -0.5, -0.5), 20, 1, 1).Shape();
  TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(3).Shape();
  run("Edge to sphere face distance", box, 12, sphere, 1);

  TopoDS_Shape box1 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape();
  TopoDS_Shape box2 = BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 20), 10, 10, 10).Shape();
  run("Box edge to box face", box1, 4, box2, 4);
  return 0;
}
