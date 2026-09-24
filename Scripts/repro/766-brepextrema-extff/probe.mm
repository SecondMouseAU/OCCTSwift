// Kernel parity probe for Tests/OCCTAnalysisTests/BRepExtremaExtFFTests.swift (#766).
//
// Same calls as OCCTBRepExtremaExtFF (OCCTBridge_Topology_Extrema.mm): the faces at 0-based
// index i/j of TopExp::MapShapes (occtFaceAt), BRepExtrema_ExtFF(f1, f2), IsDone, NbExt, and for
// the first solution sqrt(SquareDistance(1)), ParameterOnFace1/2(1), PointOnFace1/2(1).
// Inputs: Shape.box(5, 5, 5) is centred, corner (-2.5, -2.5, -2.5); Shape.box(origin: (10, 0, 0))
// puts its corner at (10, 0, 0). All 36 face pairs are reported, since the original test walked
// them looking for any result.
#include <BRepExtrema_ExtFF.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <Standard_Failure.hxx>
#include <cmath>
#include <cstdio>

int main()
{
  setvbuf(stdout, nullptr, _IONBF, 0);
  TopoDS_Shape               b1 = BRepPrimAPI_MakeBox(gp_Pnt(-2.5, -2.5, -2.5), 5, 5, 5).Shape();
  TopoDS_Shape               b2 = BRepPrimAPI_MakeBox(gp_Pnt(10, 0, 0), 5, 5, 5).Shape();
  TopTools_IndexedMapOfShape m1, m2;
  TopExp::MapShapes(b1, TopAbs_FACE, m1);
  TopExp::MapShapes(b2, TopAbs_FACE, m2);
  for (int i = 1; i <= 6; i++)
  {
    for (int j = 1; j <= 6; j++)
    {
      const char* stage = "construct";
      try
      {
      BRepExtrema_ExtFF ext(TopoDS::Face(m1(i)), TopoDS::Face(m2(j)));
      stage = "IsDone/NbExt";
      if (!ext.IsDone())
      {
        printf("pair(%d,%d) not done\n", i - 1, j - 1);
        continue;
      }
      int n = ext.NbExt();
      if (n < 1)
      {
        printf("pair(%d,%d) isDone=1 nbExt=%d\n", i - 1, j - 1, n);
        continue;
      }
      // The bridge reads SquareDistance(1) before the points. For parallel faces NbExt() is 1
      // (mySqDist holds the plane-to-plane distance) while myPointsOnS1/S2 stay empty, so the
      // ParameterOnFace1(1) below throws Standard_OutOfRange.
      printf("pair(%d,%d) nbExt=%d isParallel=%d distance=%.17g\n", i - 1, j - 1, n, (int)ext.IsParallel(), std::sqrt(ext.SquareDistance(1)));
      double u1, v1, u2, v2;
      stage = "ParameterOnFace1";
      ext.ParameterOnFace1(1, u1, v1);
      stage = "ParameterOnFace2";
      ext.ParameterOnFace2(1, u2, v2);
      stage = "PointOnFace";
      gp_Pnt p1 = ext.PointOnFace1(1);
      gp_Pnt p2 = ext.PointOnFace2(1);
      printf("pair(%d,%d) nbExt=%d distance=%.17g p1=(%.17g, %.17g, %.17g) p2=(%.17g, %.17g, %.17g) uv1=(%.17g, %.17g) uv2=(%.17g, %.17g)\n",
             i - 1,
             j - 1,
             n,
             std::sqrt(ext.SquareDistance(1)),
             p1.X(),
             p1.Y(),
             p1.Z(),
             p2.X(),
             p2.Y(),
             p2.Z(),
             u1,
             v1,
             u2,
             v2);
      }
      catch (const Standard_Failure& e)
      {
        printf("pair(%d,%d) threw %s at %s\n", i - 1, j - 1, e.what(), stage);
      }
    }
  }
  return 0;
}
