// Kernel-parity probe for Tests/OCCTAnalysisTests/SelfIntersectionPairTests.swift (#766
// execution, issues #1757, #1758). Mirrors OCCTShapeSelfIntersectionPairs:
// BRepMesh_IncrementalMesh(shape, deflection) then BRepExtrema_SelfIntersection(shape, tol),
// reporting each overlap pair once (faceIdx2 > faceIdx1).

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRep_Builder.hxx>
#include <TopoDS_Compound.hxx>
#include <TColStd_PackedMapOfInteger.hxx>
#include <cstdio>

static void run(const char* name, const TopoDS_Shape& s, double tol)
{
  BRepMesh_IncrementalMesh mesher(s, 0.1);
  BRepExtrema_SelfIntersection si(s, tol);
  si.Perform();
  printf("%s: isDone=%d", name, (int)si.IsDone());
  if (!si.IsDone())
  {
    printf("\n");
    return;
  }
  int count = 0;
  printf(" pairs=[");
  for (NCollection_DataMap<int, TColStd_PackedMapOfInteger>::Iterator it(si.OverlapElements());
       it.More();
       it.Next())
  {
    for (TColStd_PackedMapOfInteger::Iterator mit(it.Value()); mit.More(); mit.Next())
    {
      if (mit.Key() > it.Key())
      {
        printf("%s(%d,%d)", count ? " " : "", it.Key(), mit.Key());
        ++count;
      }
    }
  }
  printf("] count=%d\n", count);
}

int main()
{
  run("noSelfIntersectionOnBox", BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(), 0.0);
  run("selfIntersectionReturnsArray (sphere r=5)", BRepPrimAPI_MakeSphere(5).Shape(), 0.0);

  // Positive case: two interpenetrating boxes in one compound, never fused, so their faces
  // cross each other. Box A spans -5..5, box B spans 0..10 on every axis.
  TopoDS_Compound c;
  BRep_Builder    b;
  b.MakeCompound(c);
  b.Add(c, BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape());
  b.Add(c, BRepPrimAPI_MakeBox(gp_Pnt(0, 0, 0), 10, 10, 10).Shape());
  run("overlapping two-box compound", c, 0.0);
  return 0;
}
